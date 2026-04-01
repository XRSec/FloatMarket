import CoreFoundation
import Foundation

extension MarketDataClient {
    func fetchSinaGlobalIndices(
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings,
        existingSnapshots: [UUID: QuoteSnapshot]
    ) async -> SourceFetchResult {
        guard !items.isEmpty else { return SourceFetchResult() }

        let refreshableItems = items.filter { item in
            let hasSnapshot = existingSnapshots[item.id] != nil
            guard let schedule = IndexMarketSchedule.forSymbol(item.symbol) else { return true }
            return schedule.timing(
                now: Date(),
                hasSnapshot: hasSnapshot,
                customOpenTime: item.customOpenTime,
                customCloseTime: item.customCloseTime
            ).shouldRefresh || !hasSnapshot
        }

        guard !refreshableItems.isEmpty else {
            return SourceFetchResult()
        }

        let codePairs = refreshableItems.compactMap { item -> (WatchItem, String)? in
            guard let code = WatchItemTemplateCatalog.sinaQuoteListCode(for: item.symbol) else { return nil }
            return (item, code)
        }

        let unresolvedItems = refreshableItems.filter { item in
            WatchItemTemplateCatalog.sinaQuoteListCode(for: item.symbol) == nil
        }

        guard !codePairs.isEmpty else {
            let logs = unresolvedItems.map {
                LogEntry(level: .warning, message: String(format: NSLocalizedString("Sina Finance Does Not Support %@ (%@).", comment: ""), $0.displayName, $0.symbol))
            }
            return SourceFetchResult(logs: logs)
        }

        let symbolMap = Dictionary(uniqueKeysWithValues: codePairs.map { ($0.1, $0.0) })

        let attempt = await request(
            sourceName: NSLocalizedString("Sina Finance", comment: ""),
            path: "",
            queryItems: [
                URLQueryItem(name: "list", value: codePairs.map(\.1).joined(separator: ","))
            ],
            config: config,
            settings: settings,
            headers: [
                "Accept": "*/*",
                "Referer": "https://finance.sina.com.cn",
                "User-Agent": "Mozilla/5.0 FloatMarket"
            ]
        )

        switch attempt {
        case let .failure(logs):
            return SourceFetchResult(logs: logs)

        case let .success(data, baseURL):
            guard let text = Self.decodeSinaResponseText(data) else {
                return SourceFetchResult(
                    logs: [LogEntry(level: .error, message: NSLocalizedString("Sina Finance Response Decode Failed.", comment: ""))]
                )
            }

            let parsedQuotes = Self.parseSinaQuotes(text)
            let snapshots = parsedQuotes.compactMap { rawCode, fields -> QuoteSnapshot? in
                guard let item = symbolMap[rawCode], fields.count > 3 else { return nil }

                return QuoteSnapshot(
                    id: item.id,
                    item: item,
                    price: Double(fields[safe: 1] ?? ""),
                    change: Double(fields[safe: 2] ?? ""),
                    changePercent: Self.cleanPercent(fields[safe: 3] ?? ""),
                    sourceLabel: item.sourceKind.title,
                    marketStatus: nil,
                    fetchedAt: Date(),
                    usedBaseURL: baseURL
                )
            }

            var logs = [LogEntry(level: .info, message: String(format: NSLocalizedString("Sina Finance Refresh Succeeded, Matched %d Items.", comment: ""), snapshots.count))]
            let missingSymbols = symbolMap.values.filter { item in
                !snapshots.contains(where: { $0.item.id == item.id })
            }
            logs.append(contentsOf: missingSymbols.map {
                LogEntry(level: .warning, message: String(format: NSLocalizedString("Sina Finance Did Not Return %@ (%@).", comment: ""), $0.displayName, $0.symbol))
            })
            logs.append(contentsOf: unresolvedItems.map {
                LogEntry(level: .warning, message: String(format: NSLocalizedString("Sina Finance Does Not Support %@ (%@).", comment: ""), $0.displayName, $0.symbol))
            })
            return SourceFetchResult(snapshots: snapshots, logs: logs)
        }
    }

    private static func decodeSinaResponseText(_ data: Data) -> String? {
        if let utf8Text = String(data: data, encoding: .utf8), utf8Text.contains("hq_str_") {
            return utf8Text
        }

        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: encoding))
    }

    private static func parseSinaQuotes(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]

        for line in text.split(separator: "\n") {
            guard let prefixRange = line.range(of: "var hq_str_"),
                  let equalsRange = line.range(of: "=\""),
                  let suffixRange = line.range(of: "\";", options: .backwards)
            else {
                continue
            }

            let codeStart = prefixRange.upperBound
            let code = String(line[codeStart..<equalsRange.lowerBound])
            let rawPayload = String(line[equalsRange.upperBound..<suffixRange.lowerBound])
            result[code] = rawPayload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }

        return result
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        indices.contains(index) ? self[index] : nil
    }
}
