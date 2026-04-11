import Foundation

extension MarketDataClient {
    func fetchGate(items: [WatchItem], config: EndpointConfiguration, settings: AppSettings) async -> SourceFetchResult {
        guard !items.isEmpty else { return SourceFetchResult() }

        var combined = SourceFetchResult()

        await withTaskGroup(of: SourceFetchResult.self) { group in
            for item in items {
                group.addTask {
                    let isSpot = item.sourceKind == .gateSpotMarket
                    let tickerResult = await request(
                        sourceName: "Gate",
                        path: isSpot ? "/api/v4/spot/tickers" : "/api/v4/futures/usdt/tickers",
                        queryItems: [URLQueryItem(name: isSpot ? "currency_pair" : "contract", value: item.symbol)],
                        config: config,
                        settings: settings
                    )

                    switch tickerResult {
                    case let .failure(logs):
                        return SourceFetchResult(logs: logs)

                    case let .success(data, baseURL):
                        do {
                            let (lastStr, percentStr) = try Self.decodeGateTicker(data: data, isSpot: isSpot)
                            guard let lastStr, let percentStr else {
                                return SourceFetchResult(
                                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Gate Returned Empty Data: %@.", comment: ""), item.symbol))]
                                )
                            }

                            let last = Double(lastStr)
                            let percent = Double(percentStr)
                            let previous = (percent ?? 0) == -100 ? nil : (last ?? 0) / (1 + (percent ?? 0) / 100)
                            let change = (last ?? 0) - (previous ?? 0)

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
                            return SourceFetchResult(snapshots: [snapshot])
                        } catch {
                            return SourceFetchResult(
                                logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Gate Decode Failed [%@]: %@", comment: ""), item.symbol, error.localizedDescription))]
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

    private static func decodeGateTicker(data: Data, isSpot: Bool) throws -> (last: String?, changePercent: String?) {
        if isSpot {
            let tickers = try JSONDecoder().decode([GateSpotTicker].self, from: data)
            return (tickers.first?.last, tickers.first?.change_percentage)
        } else {
            let tickers = try JSONDecoder().decode([GateFuturesTicker].self, from: data)
            return (tickers.first?.last, tickers.first?.change_percentage)
        }
    }
}

private struct GateFuturesTicker: Decodable {
    let contract: String
    let last: String
    let change_percentage: String
}

private struct GateSpotTicker: Decodable {
    let currency_pair: String
    let last: String
    let change_percentage: String
}

extension MarketStreamController {
    static func runGateStream(
        items: [WatchItem],
        config: EndpointConfiguration,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async {
        let urls = config.candidateWebSocketURLs
        await stateHandler(.gateSpot, .connecting)
        guard !urls.isEmpty else {
            await stateHandler(.gateSpot, .disconnected)
            await snapshotHandler([], [LogEntry(level: .error, message: NSLocalizedString("Gate WebSocket URL Is Missing. Falling Back To HTTP.", comment: ""))])
            return
        }

        let symbolMap = Dictionary(grouping: items) { $0.symbol.uppercased() }
        var index = 0

        while !Task.isCancelled {
            let currentURL = urls[index % urls.count]
            index += 1

            do {
                try await connectGate(
                    urlString: currentURL,
                    symbolMap: symbolMap,
                    useProxy: config.useProxy,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            } catch {
                if Task.isCancelled { break }
                await stateHandler(.gateSpot, .disconnected)
                await snapshotHandler([], [LogEntry(level: .error, message: NetworkLogFormatter.webSocketDisconnectedMessage(sourceName: "Gate", error: error))])
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        if !Task.isCancelled {
            await stateHandler(.gateSpot, .disconnected)
        }
    }

    static func connectGate(
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

        await stateHandler(.gateSpot, .connecting)
        await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Connecting To Gate WebSocket: %@", comment: ""), urlString))])

        let session = NetworkSessionFactory.makeSession(settings: settings, useProxy: useProxy)
        let task = session.webSocketTask(with: url)
        task.resume()

        let subscribePayload: [String: Any] = [
            "time": Int(Date().timeIntervalSince1970),
            "channel": "futures.tickers",
            "event": "subscribe",
            "payload": symbolMap.keys.sorted()
        ]
        try await task.send(.string(try jsonString(subscribePayload)))

        let heartbeat = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                let pingPayload: [String: Any] = [
                    "time": Int(Date().timeIntervalSince1970),
                    "channel": "futures.ping"
                ]
                try? await task.send(.string(try jsonString(pingPayload)))
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
            guard let payload = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                continue
            }

            if let type = payload["type"] as? String, type == "upgrade" {
                let message = payload["msg"] as? String ?? NSLocalizedString("Service Upgrade", comment: "")
                throw StreamError.server(message)
            }

            let channel = payload["channel"] as? String
            let event = payload["event"] as? String

            if channel == "futures.pong" {
                continue
            }

            if let errorObject = payload["error"] as? [String: Any], !errorObject.isEmpty {
                let message = errorObject["message"] as? String ?? NSLocalizedString("Unknown Subscription Error", comment: "")
                throw StreamError.server(message)
            }

            if event == "subscribe" {
                if !acknowledged {
                    acknowledged = true
                    await stateHandler(.gateSpot, .connected)
                    await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Gate WebSocket Subscribed %d Symbols.", comment: ""), symbolMap.count))])
                }
                continue
            }

            guard channel == "futures.tickers", event == "update",
                  let result = payload["result"] as? [[String: Any]]
            else {
                continue
            }

            if !acknowledged {
                acknowledged = true
                await stateHandler(.gateSpot, .connected)
            }

            let snapshots = result.flatMap { ticker -> [QuoteSnapshot] in
                guard let contract = (ticker["contract"] as? String)?.uppercased(),
                      let items = symbolMap[contract]
                else {
                    return []
                }

                let lastValue = Double(ticker["last"] as? String ?? "")
                let percent = Double(ticker["change_percentage"] as? String ?? "")
                let previous = (percent ?? 0) == -100 ? nil : (lastValue ?? 0) / (1 + (percent ?? 0) / 100)
                let change = (lastValue ?? 0) - (previous ?? 0)

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
