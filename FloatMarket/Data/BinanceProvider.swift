import Foundation

extension MarketDataClient {
    func fetchBinance(items: [WatchItem], config: EndpointConfiguration, settings: AppSettings) async -> SourceFetchResult {
        guard !items.isEmpty else { return SourceFetchResult() }

        var combined = SourceFetchResult()

        await withTaskGroup(of: SourceFetchResult.self) { group in
            for item in items {
                group.addTask {
                    let isSpot = item.sourceKind == .binanceSpot
                    let tickerResult = await request(
                        sourceName: "Binance",
                        path: isSpot ? "/api/v3/ticker/24hr" : "/fapi/v1/ticker/24hr",
                        queryItems: [URLQueryItem(name: "symbol", value: item.symbol.uppercased())],
                        config: config,
                        settings: settings
                    )

                    switch tickerResult {
                    case let .failure(logs):
                        return SourceFetchResult(logs: logs)

                    case let .success(data, baseURL):
                        do {
                            let ticker = try JSONDecoder().decode(BinanceTickerResponse.self, from: data)
                            let last = Double(ticker.lastPrice)
                            let open = Double(ticker.openPrice)
                            let change = Double(ticker.priceChange) ?? ((last ?? 0) - (open ?? 0))
                            let percent = Double(ticker.priceChangePercent)

                            let snapshot = QuoteSnapshot(
                                id: item.id,
                                item: item,
                                price: last,
                                change: change,
                                changePercent: percent,
                                sourceLabel: item.sourceKind.title,
                                marketStatus: isSpot ? nil : NSLocalizedString("Perpetual", comment: ""),
                                fetchedAt: Date(),
                                usedBaseURL: baseURL
                            )

                            return SourceFetchResult(
                                snapshots: [snapshot],
                                logs: [LogEntry(level: .info, message: String(format: NSLocalizedString("Binance Refresh Succeeded: %@.", comment: ""), item.symbol))]
                            )
                        } catch {
                            return SourceFetchResult(
                                logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Binance Decode Failed [%@]: %@", comment: ""), item.symbol, error.localizedDescription))]
                            )
                        }
                    }
                }
            }

            for await result in group {
                combined.snapshots.append(contentsOf: result.snapshots)
                combined.logs.append(contentsOf: result.logs)
            }
        }

        return combined
    }
}

private struct BinanceTickerResponse: Decodable {
    let symbol: String
    let priceChange: String
    let priceChangePercent: String
    let lastPrice: String
    let openPrice: String
}

extension MarketStreamController {
    static func runBinanceStream(
        items: [WatchItem],
        config: EndpointConfiguration,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async {
        let urls = config.candidateWebSocketURLs
        guard !urls.isEmpty else {
            await stateHandler(.binancePerp, .disconnected)
            await snapshotHandler([], [LogEntry(level: .error, message: NSLocalizedString("Binance WebSocket URL Is Missing. Falling Back To HTTP.", comment: ""))])
            return
        }

        let symbolMap = Dictionary(grouping: items) { $0.symbol.uppercased() }
        var index = 0

        while !Task.isCancelled {
            let currentURL = urls[index % urls.count]
            index += 1

            do {
                try await connectBinance(
                    urlString: currentURL,
                    symbolMap: symbolMap,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            } catch {
                await stateHandler(.binancePerp, .disconnected)
                await snapshotHandler([], [LogEntry(level: .error, message: NetworkLogFormatter.webSocketDisconnectedMessage(sourceName: "Binance", error: error))])
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        await stateHandler(.binancePerp, .disconnected)
    }

    static func connectBinance(
        urlString: String,
        symbolMap: [String: [WatchItem]],
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async throws {
        let lowerStreams = symbolMap.keys.map { "\($0.lowercased())@ticker" }.joined(separator: "/")
        guard var components = URLComponents(string: urlString) else {
            throw StreamError.invalidURL(urlString)
        }
        if components.path.isEmpty {
            components.path = "/stream"
        }
        components.queryItems = [URLQueryItem(name: "streams", value: lowerStreams)]
        guard let url = components.url else {
            throw StreamError.invalidURL(urlString)
        }

        await stateHandler(.binancePerp, .connecting)
        await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Connecting To Binance WebSocket: %@", comment: ""), url.absoluteString))])

        let session = NetworkSessionFactory.makeSession(settings: settings)
        let task = session.webSocketTask(with: url)
        task.resume()

        defer {
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        var acknowledged = false
        while !Task.isCancelled {
            let message = try await task.receive()
            guard let text = string(from: message),
                  let data = text.data(using: .utf8),
                  let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            if let payloadData = payload["data"] as? [String: Any],
               let symbol = (payloadData["s"] as? String)?.uppercased(),
               let items = symbolMap[symbol] {
                if !acknowledged {
                    acknowledged = true
                    await stateHandler(.binancePerp, .connected)
                    await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Binance WebSocket Subscribed %d Contracts.", comment: ""), symbolMap.count))])
                }

                let last = Double(payloadData["c"] as? String ?? "")
                let open = Double(payloadData["o"] as? String ?? "")
                let percent = Double(payloadData["P"] as? String ?? "")
                let change = (last ?? 0) - (open ?? 0)

                let snapshots = items.map { item in
                    QuoteSnapshot(
                        id: item.id,
                        item: item,
                        price: last,
                        change: change,
                        changePercent: percent,
                        sourceLabel: item.sourceKind.title,
                        marketStatus: NSLocalizedString("Perpetual", comment: ""),
                        fetchedAt: Date(),
                        usedBaseURL: url.host ?? urlString
                    )
                }

                await snapshotHandler(snapshots, [])
            }
        }
    }
}
