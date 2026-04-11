import Foundation

extension MarketDataClient {
    func fetchOKX(items: [WatchItem], config: EndpointConfiguration, settings: AppSettings) async -> SourceFetchResult {
        guard !items.isEmpty else { return SourceFetchResult() }

        var combined = SourceFetchResult()

        await withTaskGroup(of: SourceFetchResult.self) { group in
            for item in items {
                group.addTask {
                    let tickerResult = await request(
                        sourceName: "OKX",
                        path: "/api/v5/market/ticker",
                        queryItems: [URLQueryItem(name: "instId", value: item.symbol)],
                        config: config,
                        settings: settings
                    )

                    switch tickerResult {
                    case let .failure(logs):
                        return SourceFetchResult(logs: logs)

                    case let .success(data, baseURL):
                        do {
                            let response = try JSONDecoder().decode(OKXTickerResponse.self, from: data)
                            guard response.code == "0", let ticker = response.data.first else {
                                return SourceFetchResult(
                                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("OKX Response Was Invalid For %@.", comment: ""), item.symbol))]
                                )
                            }

                            let last = Double(ticker.last)
                            let open = Double(ticker.open24h)
                            let change = (last ?? 0) - (open ?? 0)
                            let percent = (open ?? 0) == 0 ? nil : (change / (open ?? 1)) * 100

                            let snapshot = QuoteSnapshot(
                                id: item.id,
                                item: item,
                                price: last,
                                change: change,
                                changePercent: percent,
                                sourceLabel: item.sourceKind.title,
                                marketStatus: item.sourceKind.instrumentKind == .spot
                                    ? nil
                                    : NSLocalizedString("Perpetual", comment: ""),
                                fetchedAt: Date(),
                                usedBaseURL: baseURL
                            )

                            return SourceFetchResult(snapshots: [snapshot])
                        } catch {
                            return SourceFetchResult(
                                logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("OKX Decode Failed [%@]: %@", comment: ""), item.symbol, error.localizedDescription))]
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

private struct OKXTickerResponse: Decodable {
    struct Ticker: Decodable {
        let last: String
        let open24h: String
    }

    let code: String
    let data: [Ticker]
}

extension MarketStreamController {
    static func runOKXStream(
        items: [WatchItem],
        config: EndpointConfiguration,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async {
        let urls = config.candidateWebSocketURLs
        await stateHandler(.okxSpot, .connecting)
        guard !urls.isEmpty else {
            await stateHandler(.okxSpot, .disconnected)
            await snapshotHandler([], [LogEntry(level: .error, message: NSLocalizedString("OKX WebSocket URL Is Missing. Falling Back To HTTP.", comment: ""))])
            return
        }

        let symbolMap = Dictionary(grouping: items) { $0.symbol.uppercased() }
        var index = 0

        while !Task.isCancelled {
            let currentURL = urls[index % urls.count]
            index += 1

            do {
                try await connectOKX(
                    urlString: currentURL,
                    symbolMap: symbolMap,
                    useProxy: config.useProxy,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            } catch {
                if Task.isCancelled { break }
                await stateHandler(.okxSpot, .disconnected)
                await snapshotHandler([], [LogEntry(level: .error, message: NetworkLogFormatter.webSocketDisconnectedMessage(sourceName: "OKX", error: error))])
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        if !Task.isCancelled {
            await stateHandler(.okxSpot, .disconnected)
        }
    }

    static func connectOKX(
        urlString: String,
        symbolMap: [String: [WatchItem]],
        useProxy: Bool,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw StreamError.invalidURL(urlString)
        }

        await stateHandler(.okxSpot, .connecting)
        await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Connecting To OKX WebSocket: %@", comment: ""), urlString))])

        let session = NetworkSessionFactory.makeSession(settings: settings, useProxy: useProxy)
        let task = session.webSocketTask(with: url)
        task.resume()

        let subscribePayload: [String: Any] = [
            "id": Self.requestID(),
            "op": "subscribe",
            "args": symbolMap.keys.sorted().map { ["channel": "tickers", "instId": $0] }
        ]
        try await task.send(.string(try jsonString(subscribePayload)))

        let heartbeat = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                try? await task.send(.string("ping"))
            }
        }
        defer {
            heartbeat.cancel()
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        var acknowledged = false

        while !Task.isCancelled {
            let message = try await task.receive()
            guard let text = Self.string(from: message) else { continue }

            if text == "pong" {
                continue
            }

            guard let payload = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                continue
            }

            if let event = payload["event"] as? String {
                if event == "subscribe" {
                    if !acknowledged {
                        acknowledged = true
                        await stateHandler(.okxSpot, .connected)
                        await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("OKX WebSocket Subscribed %d Symbols.", comment: ""), symbolMap.count))])
                    }
                    continue
                }

                if event == "error" {
                    let message = payload["msg"] as? String ?? NSLocalizedString("Unknown Subscription Error", comment: "")
                    throw StreamError.server(message)
                }

                continue
            }

            guard let data = payload["data"] as? [[String: Any]] else {
                continue
            }

            if !acknowledged {
                acknowledged = true
                await stateHandler(.okxSpot, .connected)
            }

            let snapshots = data.flatMap { ticker -> [QuoteSnapshot] in
                guard let instID = (ticker["instId"] as? String)?.uppercased(),
                      let items = symbolMap[instID]
                else {
                    return []
                }

                let last = ticker["last"] as? String
                let open24h = ticker["open24h"] as? String
                let lastValue = Double(last ?? "")
                let openValue = Double(open24h ?? "")
                let change = (lastValue ?? 0) - (openValue ?? 0)
                let percent = (openValue ?? 0) == 0 ? nil : (change / (openValue ?? 1)) * 100

                return items.map { item in
                    QuoteSnapshot(
                        id: item.id,
                        item: item,
                        price: lastValue,
                        change: change,
                        changePercent: percent,
                        sourceLabel: item.sourceKind.title,
                        marketStatus: NSLocalizedString("Live", comment: ""),
                        fetchedAt: Date(),
                        usedBaseURL: url.host ?? urlString
                    )
                }
            }

            if !snapshots.isEmpty {
                await snapshotHandler(snapshots, [])
            }
        }
    }
}
