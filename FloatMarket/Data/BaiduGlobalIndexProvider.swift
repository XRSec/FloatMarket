import Foundation

extension MarketDataClient {
    func fetchBaidu(
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

        let grouped = Dictionary(grouping: refreshableItems) { $0.area ?? .all }
        var combined = SourceFetchResult()

        await withTaskGroup(of: SourceFetchResult.self) { group in
            for (area, areaItems) in grouped {
                group.addTask {
                    await fetchBaiduArea(area: area, items: areaItems, config: config, settings: settings)
                }
            }

            for await result in group {
                combined.snapshots.append(contentsOf: result.snapshots)
                combined.logs.append(contentsOf: result.logs)
            }
        }

        return combined
    }

    private func fetchBaiduArea(
        area: BaiduArea,
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings
    ) async -> SourceFetchResult {
        if area == .foreign {
            return await fetchBaiduForeign(items: items, config: config, settings: settings)
        }

        let attempt = await request(
            sourceName: NSLocalizedString("Baidu Gushitong", comment: ""),
            path: "/vapi/v1/globalindexrank",
            queryItems: [
                URLQueryItem(name: "pn", value: "0"),
                URLQueryItem(name: "rn", value: "120"),
                URLQueryItem(name: "area", value: area.rawValue)
            ],
            config: config,
            settings: settings
        )

        switch attempt {
        case let .failure(logs):
            return SourceFetchResult(logs: logs)

        case let .success(data, baseURL):
            do {
                let response = try JSONDecoder().decode(BaiduGlobalIndexResponse.self, from: data)
                let quotes = response.Result.body
                let mapped = Dictionary(uniqueKeysWithValues: quotes.map { ($0.code.uppercased(), $0) })
                let snapshots = items.compactMap { item -> QuoteSnapshot? in
                    guard let quote = mapped[item.symbol.uppercased()] else { return nil }
                    return QuoteSnapshot(
                        id: item.id,
                        item: item,
                        price: Double(quote.last_px),
                        change: Double(quote.px_change),
                        changePercent: Self.cleanPercent(quote.px_change_rate),
                        sourceLabel: item.sourceKind.title,
                        marketStatus: area.title,
                        fetchedAt: Date(),
                        usedBaseURL: baseURL
                    )
                }

                var logs = [LogEntry(level: .info, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Refresh Succeeded, Matched %d Items.", comment: ""), area.title, snapshots.count))]
                let missing = items.filter { item in
                    !snapshots.contains(where: { $0.item.id == item.id })
                }
                logs.append(contentsOf: missing.map {
                    LogEntry(level: .warning, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Did Not Return %@ (%@).", comment: ""), area.title, $0.displayName, $0.symbol))
                })
                return SourceFetchResult(snapshots: snapshots, logs: logs)
            } catch {
                return SourceFetchResult(
                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Decode Failed: %@", comment: ""), area.title, error.localizedDescription))]
                )
            }
        }
    }

    private func fetchBaiduForeign(
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings
    ) async -> SourceFetchResult {
        let attempt = await request(
            sourceName: NSLocalizedString("Baidu Gushitong", comment: ""),
            path: "/api/getbanner",
            queryItems: [
                URLQueryItem(name: "market", value: "foreign"),
                URLQueryItem(name: "finClientType", value: "pc")
            ],
            config: config,
            settings: settings
        )

        switch attempt {
        case let .failure(logs):
            return SourceFetchResult(logs: logs)

        case let .success(data, baseURL):
            do {
                let response = try JSONDecoder().decode(BaiduBannerResponse.self, from: data)
                let mapped = Dictionary(uniqueKeysWithValues: response.Result.list.map { ($0.code.uppercased(), $0) })
                let snapshots = items.compactMap { item -> QuoteSnapshot? in
                    guard let quote = mapped[item.symbol.uppercased()] else { return nil }
                    return QuoteSnapshot(
                        id: item.id,
                        item: item,
                        price: Double(quote.lastPrice),
                        change: Double(quote.increase),
                        changePercent: Self.cleanPercent(quote.ratio),
                        sourceLabel: item.sourceKind.title,
                        marketStatus: NSLocalizedString("Foreign Exchange", comment: ""),
                        fetchedAt: Date(),
                        usedBaseURL: baseURL
                    )
                }

                var logs = [LogEntry(level: .info, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Refresh Succeeded, Matched %d Items.", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), snapshots.count))]
                let missing = items.filter { item in
                    !snapshots.contains(where: { $0.item.id == item.id })
                }
                logs.append(contentsOf: missing.map {
                    LogEntry(level: .warning, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Did Not Return %@ (%@).", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), $0.displayName, $0.symbol))
                })
                return SourceFetchResult(snapshots: snapshots, logs: logs)
            } catch {
                return SourceFetchResult(
                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Decode Failed: %@", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), error.localizedDescription))]
                )
            }
        }
    }
}

private struct BaiduGlobalIndexResponse: Decodable {
    struct ResultBody: Decodable {
        let body: [BaiduQuote]
    }

    struct BaiduQuote: Decodable {
        let name: String
        let code: String
        let last_px: String
        let px_change: String
        let px_change_rate: String
    }

    let Result: ResultBody
}

private struct BaiduBannerResponse: Decodable {
    struct ResultBody: Decodable {
        let list: [BannerItem]
    }

    struct BannerItem: Decodable {
        let code: String
        let name: String
        let lastPrice: String
        let increase: String
        let ratio: String
    }

    let Result: ResultBody
}
