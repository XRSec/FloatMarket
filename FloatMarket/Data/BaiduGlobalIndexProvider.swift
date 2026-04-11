/*
 * BaiduGlobalIndexProvider.swift
 * 百度股市通全球指数数据提供者
 *
 * 功能说明：
 * 1. HTTP 轮询：通过 REST API 获取全球指数行情数据
 * 2. WebSocket 实时流：订阅实时行情推送（仅在交易时段）
 * 3. 交易时间判断：根据市场时区和交易时段智能控制数据获取
 * 4. 调试日志：记录详细的请求和响应信息到本地文件
 *
 * 支持的市场：
 * - 美洲市场（美股指数）
 * - 亚洲市场（港股、A股、日韩指数）
 * - 欧非市场（欧洲指数）
 * - 外汇市场（货币对）
 */

import Foundation

// 百度探测日志记录器（Actor 保证线程安全）
private actor BaiduProbeFileLogger {
    static let shared = BaiduProbeFileLogger()
    static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("FloatMarket", isDirectory: true)
            .appendingPathComponent("baidu-index-probe.log")
    }()

    private var didWriteSessionHeader = false

    func append(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        writeIfNeededSessionHeader(timestamp: timestamp)
        writeLine("[\(timestamp)] \(message)")
    }

    private func writeIfNeededSessionHeader(timestamp: String) {
        guard !didWriteSessionHeader else { return }
        didWriteSessionHeader = true
        writeLine("")
        writeLine("===== FloatMarket Baidu Probe Session \(timestamp) =====")
    }

    private func writeLine(_ line: String) {
        let url = Self.fileURL
        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        guard let data = (line + "\n").data(using: .utf8) else { return }
        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            try? data.write(to: url, options: [.atomic])
        }
    }
}

private enum BaiduProbeLog {
    static var fileURL: URL { BaiduProbeFileLogger.fileURL }

    static func record(_ message: String) {
        Task {
            await BaiduProbeFileLogger.shared.append(message)
        }
    }
}

// WebSocket 连接状态
private enum BaiduWebSocketStatus: String {
    case connecting  // 连接中
    case connected   // 已连接
    case disconnect  // 已断开
    case disabled    // 已禁用
}

// WebSocket 消息状态
private enum BaiduWebSocketMessageStatus: String {
    case connected   // 连接成功
    case disconnect  // 断开连接
    case reconnect   // 重新连接
    case msg         // 普通消息
    case error       // 错误
    case noTrading = "no_trading"  // 非交易时段
}

// WebSocket 产品类型
private enum BaiduWebSocketProduct: String {
    case snapshot  // 快照数据
    case tick      // 逐笔数据
    case adr       // ADR 数据
}

// WebSocket 方法类型
private enum BaiduWebSocketMethod: String {
    case subscribe    // 订阅
    case unsubscribe  // 取消订阅
    case patch        // 更新
    case ping         // 心跳
}

// 百度交易状态
// 只有这些状态下才会推送 WebSocket 数据
private enum BaiduTradeStatus: String {
    case trade = "TRADE"          // 交易中
    case postMarket = "POSMT"     // 盘后交易
    case preMarket = "PRETR"      // 盘前交易
    case openCall = "OCALL"       // 集合竞价

    // 符合 WebSocket 推送条件的交易状态
    static let wsEligibleCases: Set<String> = [
        BaiduTradeStatus.trade.rawValue,
        BaiduTradeStatus.postMarket.rawValue,
        BaiduTradeStatus.preMarket.rawValue,
        BaiduTradeStatus.openCall.rawValue
    ]
}

// 百度 WebSocket 订阅信息
// 用于构建订阅请求和匹配返回数据
struct BaiduStreamSubscription: Hashable {
    let code: String         // 股票代码（如 IXIC）
    let market: String       // 市场代码（如 us, hk, ab）
    let financeType: String  // 金融类型（如 index）
    let name: String         // 显示名称

    // 生成唯一标识符，用于匹配订阅和数据
    var key: String {
        Self.key(code: code, market: market, financeType: financeType)
    }

    // 生成订阅请求的 payload
    var payload: [String: String] {
        [
            "code": code,
            "name": name,
            "market": market,
            "financeType": financeType
        ]
    }

    // 根据代码、市场、类型生成唯一 key
    static func key(code: String, market: String, financeType: String) -> String {
        "\(financeType.lowercased())_\(market.lowercased())_\(code.uppercased())"
    }
}

extension WatchItem {
    // 获取百度 WebSocket 订阅信息
    var baiduStreamSubscription: BaiduStreamSubscription? {
        guard sourceKind == .baiduGlobalIndex else { return nil }
        guard area != .foreign else { return nil }
        guard let market = baiduResolvedMarket, ["us", "hk", "ab"].contains(market) else { return nil }

        let label = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return BaiduStreamSubscription(
            code: symbol.uppercased(),
            market: market,
            financeType: "index",
            name: label.isEmpty ? symbol.uppercased() : label
        )
    }

    // 判断当前是否应该使用 WebSocket 实时流
    // 只有在交易时段内才使用 WebSocket，避免不必要的连接
    var baiduShouldUseStreamNow: Bool {
        guard baiduStreamSubscription != nil else { return false }
        guard let schedule = IndexMarketSchedule.forSymbol(symbol) else { return false }
        return schedule.timing(
            now: Date(),
            hasSnapshot: true,
            customOpenTime: customOpenTime,
            customCloseTime: customCloseTime
        ).isTrading
    }
    
    // 判断当前是否在交易时段（用于 HTTP 轮询判断）
    var baiduIsTradingNow: Bool {
        guard let schedule = IndexMarketSchedule.forSymbol(symbol) else { return true }
        return schedule.timing(
            now: Date(),
            hasSnapshot: true,
            customOpenTime: customOpenTime,
            customCloseTime: customCloseTime
        ).isTrading
    }

    // 解析市场代码（从 quickLink URL 或 symbol 推断）
    // 返回值：us（美股）、hk（港股）、ab（A股+B股）
    private var baiduResolvedMarket: String? {
        // 优先从 quickLink URL 中提取市场代码
        let candidateURLs = [
            resolvedQuickLinkURL,
            Self.defaultQuickLinkURL(sourceKind: sourceKind, symbol: symbol, area: area)
        ]

        for candidateURL in candidateURLs.compactMap({ $0 }) {
            guard let url = URL(string: candidateURL) else { continue }
            // 从 URL 路径中提取市场代码
            // 例如：https://gushitong.baidu.com/index/us-IXIC -> "us"
            let lastComponent = url.path.split(separator: "/").last.map(String.init) ?? ""
            let market = lastComponent.split(separator: "-").first.map(String.init)?.lowercased()
            if let market, !market.isEmpty {
                return market
            }
        }

        // 如果 URL 中没有，根据 symbol 推断
        let uppercased = symbol.uppercased()
        if ["IXIC", "DJI", "SPX"].contains(uppercased) {
            return "us"  // 美股三大指数
        }
        if uppercased == "HSI" {
            return "hk"  // 恒生指数
        }
        if symbol.count == 6, symbol.allSatisfy(\.isNumber) {
            return "ab"  // A股指数（6位数字）
        }
        return nil
    }
}

extension MarketDataClient {
    // 获取百度股市通数据（HTTP 方式）
    // 根据交易时间智能判断是否需要刷新，避免收盘后不必要的轮询
    func fetchBaidu(
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings,
        existingSnapshots: [UUID: QuoteSnapshot]
    ) async -> SourceFetchResult {
        guard !items.isEmpty else { return SourceFetchResult() }
        BaiduProbeLog.record("HTTP candidate items: \(items.map { "\($0.symbol.uppercased())[\($0.displayName)]" }.joined(separator: ", "))")

        // 过滤出需要刷新的项目
        // 1. 如果没有快照，总是刷新
        // 2. 如果有快照，根据交易时间判断是否需要刷新
        let refreshableItems = items.filter { item in
            let hasSnapshot = existingSnapshots[item.id] != nil
            guard let schedule = IndexMarketSchedule.forSymbol(item.symbol) else { return true }
            let timing = schedule.timing(
                now: Date(),
                hasSnapshot: hasSnapshot,
                customOpenTime: item.customOpenTime,
                customCloseTime: item.customCloseTime
            )
            // 只有在 shouldRefresh 为 true 或没有快照时才刷新
            return timing.shouldRefresh || !hasSnapshot
        }

        guard !refreshableItems.isEmpty else {
            BaiduProbeLog.record("HTTP skipped: all items are outside trading hours and have snapshots")
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

    // 按区域获取百度股市通数据
    // area: 市场区域（美洲、亚洲、欧非、外汇等）
    private func fetchBaiduArea(
        area: BaiduArea,
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings
    ) async -> SourceFetchResult {
        // 外汇市场使用不同的 API
        if area == .foreign {
            return await fetchBaiduForeign(items: items, config: config, settings: settings)
        }

        BaiduProbeLog.record("HTTP request area=\(area.rawValue) symbols=\(items.map { $0.symbol.uppercased() }.joined(separator: ","))")

        // 请求百度股市通 API
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
                // 解析 JSON 响应
                let response = try JSONDecoder().decode(BaiduGlobalIndexResponse.self, from: data)
                let quotes = response.Result.body
                
                // 构建 symbol -> quote 的映射表（不区分大小写）
                let mapped = Dictionary(uniqueKeysWithValues: quotes.map { ($0.code.uppercased(), $0) })
                
                // 为每个监控项生成快照
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

                // 生成日志：成功和缺失的项目
                var logs = [LogEntry(level: .info, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Refresh Succeeded, Matched %d Items.", comment: ""), area.title, snapshots.count))]
                let missing = items.filter { item in
                    !snapshots.contains(where: { $0.item.id == item.id })
                }
                logs.append(contentsOf: missing.map {
                    LogEntry(level: .warning, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Did Not Return %@ (%@).", comment: ""), area.title, $0.displayName, $0.symbol))
                })
                
                // 记录探测日志
                BaiduProbeLog.record("HTTP response area=\(area.rawValue) matched=\(snapshots.map { "\($0.item.symbol.uppercased())@\($0.priceText)" }.joined(separator: ", "))")
                if !missing.isEmpty {
                    BaiduProbeLog.record("HTTP response area=\(area.rawValue) missing=\(missing.map { $0.symbol.uppercased() }.joined(separator: ","))")
                }
                return SourceFetchResult(snapshots: snapshots, logs: logs)
            } catch {
                BaiduProbeLog.record("HTTP decode failed area=\(area.rawValue) error=\(error.localizedDescription)")
                return SourceFetchResult(
                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Decode Failed: %@", comment: ""), area.title, error.localizedDescription))]
                )
            }
        }
    }

    // 获取外汇市场数据（使用不同的 API 端点）
    private func fetchBaiduForeign(
        items: [WatchItem],
        config: EndpointConfiguration,
        settings: AppSettings
    ) async -> SourceFetchResult {
        BaiduProbeLog.record("HTTP request area=foreign symbols=\(items.map { $0.symbol.uppercased() }.joined(separator: ","))")
        
        // 外汇市场使用 /api/getbanner 接口
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
                // 解析外汇市场的 JSON 响应（结构与指数不同）
                let response = try JSONDecoder().decode(BaiduBannerResponse.self, from: data)
                let mapped = Dictionary(uniqueKeysWithValues: response.Result.list.map { ($0.code.uppercased(), $0) })
                
                // 为每个监控项生成快照
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

                // 生成日志
                var logs = [LogEntry(level: .info, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Refresh Succeeded, Matched %d Items.", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), snapshots.count))]
                let missing = items.filter { item in
                    !snapshots.contains(where: { $0.item.id == item.id })
                }
                logs.append(contentsOf: missing.map {
                    LogEntry(level: .warning, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Did Not Return %@ (%@).", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), $0.displayName, $0.symbol))
                })
                
                // 记录探测日志
                BaiduProbeLog.record("HTTP response area=foreign matched=\(snapshots.map { "\($0.item.symbol.uppercased())@\($0.priceText)" }.joined(separator: ", "))")
                if !missing.isEmpty {
                    BaiduProbeLog.record("HTTP response area=foreign missing=\(missing.map { $0.symbol.uppercased() }.joined(separator: ","))")
                }
                return SourceFetchResult(snapshots: snapshots, logs: logs)
            } catch {
                BaiduProbeLog.record("HTTP decode failed area=foreign error=\(error.localizedDescription)")
                return SourceFetchResult(
                    logs: [LogEntry(level: .error, message: String(format: NSLocalizedString("Baidu Gushitong [%@] Decode Failed: %@", comment: ""), NSLocalizedString("Foreign Exchange", comment: ""), error.localizedDescription))]
                )
            }
        }
    }
}

// 百度全球指数 API 响应结构
private struct BaiduGlobalIndexResponse: Decodable {
    struct ResultBody: Decodable {
        let body: [BaiduQuote]
    }

    struct BaiduQuote: Decodable {
        let name: String           // 指数名称
        let code: String           // 指数代码
        let last_px: String        // 最新价格
        let px_change: String      // 涨跌额
        let px_change_rate: String // 涨跌幅
    }

    let Result: ResultBody
}

// 百度外汇市场 API 响应结构
private struct BaiduBannerResponse: Decodable {
    struct ResultBody: Decodable {
        let list: [BannerItem]
    }

    struct BannerItem: Decodable {
        let code: String      // 货币对代码
        let name: String      // 货币对名称
        let lastPrice: String // 最新价格
        let increase: String  // 涨跌额
        let ratio: String     // 涨跌幅
    }

    let Result: ResultBody
}

extension MarketStreamController {
    // 运行百度股市通 WebSocket 实时流
    // 只在交易时段内订阅 WebSocket，避免不必要的连接
    static func runBaiduStream(
        items: [WatchItem],
        config: EndpointConfiguration,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async {
        let urls = config.candidateWebSocketURLs
        await stateHandler(.baiduGlobalIndex, .connecting)
        BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.connecting.rawValue)")
        
        // 检查是否配置了 WebSocket URL
        guard !urls.isEmpty else {
            await stateHandler(.baiduGlobalIndex, .disconnected)
            BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.disabled.rawValue)")
            await snapshotHandler([], [LogEntry(level: .error, message: NSLocalizedString("Baidu Gushitong WebSocket URL Is Missing. Falling Back To HTTP.", comment: ""))])
            return
        }

        // 构建订阅列表
        // 只订阅支持 WebSocket 且当前在交易时段的指数
        var subscriptionByKey: [String: BaiduStreamSubscription] = [:]
        var itemMap: [String: [WatchItem]] = [:]
        for item in items {
            // 检查是否支持 WebSocket 订阅
            guard let subscription = item.baiduStreamSubscription else {
                BaiduProbeLog.record("WSS skipped symbol=\(item.symbol.uppercased()) name=\(item.displayName) reason=unsupported_by_subscribeJudge_market quickLink=\(item.resolvedQuickLinkURL ?? "-")")
                continue
            }
            // 检查当前是否在交易时段
            guard item.baiduShouldUseStreamNow else {
                BaiduProbeLog.record("WSS skipped symbol=\(item.symbol.uppercased()) name=\(item.displayName) reason=not_trading_now market=\(subscription.market)")
                continue
            }
            subscriptionByKey[subscription.key] = subscription
            itemMap[subscription.key, default: []].append(item)
            BaiduProbeLog.record("WSS candidate symbol=\(subscription.code) market=\(subscription.market) financeType=\(subscription.financeType)")
        }

        let subscriptions = subscriptionByKey
            .keys
            .sorted()
            .compactMap { subscriptionByKey[$0] }

        guard !subscriptions.isEmpty else {
            await stateHandler(.baiduGlobalIndex, .disconnected)
            return
        }

        var index = 0
        while !Task.isCancelled {
            let currentURL = urls[index % urls.count]
            index += 1

            do {
                try await connectBaidu(
                    urlString: currentURL,
                    subscriptions: subscriptions,
                    itemMap: itemMap,
                    useProxy: config.useProxy,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            } catch {
                if Task.isCancelled { break }
                await stateHandler(.baiduGlobalIndex, .disconnected)
                BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.disconnect.rawValue) msgStatus=\(BaiduWebSocketMessageStatus.error.rawValue) error=\(error.localizedDescription)")
                await snapshotHandler([], [LogEntry(level: .error, message: NetworkLogFormatter.webSocketDisconnectedMessage(sourceName: NSLocalizedString("Baidu Gushitong", comment: ""), error: error))])
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        if !Task.isCancelled {
            await stateHandler(.baiduGlobalIndex, .disconnected)
            BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.disconnect.rawValue)")
        }
    }

    // 连接百度股市通 WebSocket
    // 订阅实时行情数据，处理心跳和重连逻辑
    static func connectBaidu(
        urlString: String,
        subscriptions: [BaiduStreamSubscription],
        itemMap: [String: [WatchItem]],
        useProxy: Bool,
        snapshotHandler: @escaping SnapshotHandler,
        stateHandler: @escaping StateHandler,
        settings: AppSettings
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw StreamError.invalidURL(urlString)
        }

        await stateHandler(.baiduGlobalIndex, .connecting)
        BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.connecting.rawValue)")
        await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Connecting To Baidu Gushitong WebSocket: %@", comment: ""), urlString))])
        BaiduProbeLog.record("WSS connect url=\(urlString) subscriptions=\(subscriptions.map { "\($0.code):\($0.market)" }.joined(separator: ","))")

        let session = NetworkSessionFactory.makeSession(settings: settings, useProxy: useProxy)
        let task = session.webSocketTask(with: url)
        task.resume()
        var acknowledged = false

        // 发送订阅消息
        let subscribePayload: [String: Any] = [
            "method": BaiduWebSocketMethod.subscribe.rawValue,
            "source": "pc-web",
            "product": BaiduWebSocketProduct.snapshot.rawValue,
            "items": subscriptions.map(\.payload)
        ]
        BaiduProbeLog.record("WSS send subscribe payload=\(String(data: (try? JSONSerialization.data(withJSONObject: subscribePayload, options: [.sortedKeys])) ?? Data(), encoding: .utf8) ?? "{}")")
        try await task.send(.string(try jsonString(subscribePayload)))

        // 启动心跳任务，每 6 秒发送一次 ping
        let heartbeat = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                let pingPayload: [String: Any] = [
                    "method": BaiduWebSocketMethod.ping.rawValue,
                    "source": "pc-web"
                ]
                try? await task.send(.string(try jsonString(pingPayload)))
                BaiduProbeLog.record("WSS send ping")
            }
        }
        defer {
            heartbeat.cancel()
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        // 接收并处理 WebSocket 消息
        while !Task.isCancelled {
            let message = try await task.receive()
            guard let text = Self.string(from: message) else { continue }
            guard let payload = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                continue
            }

            // 处理重连请求（resultCode = 70010001）
            if let resultCode = payload["resultCode"] as? String, resultCode == "70010001" {
                BaiduProbeLog.record("WSS msgStatus=\(BaiduWebSocketMessageStatus.reconnect.rawValue) resultCode=70010001 resubscribe")
                try await task.send(.string(try jsonString(subscribePayload)))
                continue
            }

            if let resultCodeNumber = payload["resultCode"] as? NSNumber, resultCodeNumber.intValue == 70010001 {
                BaiduProbeLog.record("WSS msgStatus=\(BaiduWebSocketMessageStatus.reconnect.rawValue) resultCode=70010001 resubscribe")
                try await task.send(.string(try jsonString(subscribePayload)))
                continue
            }

            // 处理心跳消息
            if let data = payload["data"] as? String {
                if data == "ping" || data == "pong" {
                    BaiduProbeLog.record("WSS recv heartbeat=\(data)")
                    continue
                }
            }

            // 检查返回码
            guard let resultCode = payload["resultCode"] else { continue }
            let resultCodeText = String(describing: resultCode)
            if resultCodeText != "0" {
                BaiduProbeLog.record("WSS recv nonzero resultCode=\(resultCodeText) payload=\(text)")
                continue
            }

            // 解析行情数据
            guard let data = payload["data"] as? [String: Any],
                  let code = (data["code"] as? String)?.uppercased(),
                  let market = (data["market"] as? String)?.lowercased()
            else {
                BaiduProbeLog.record("WSS recv resultCode=0 but no quote payload raw=\(text)")
                continue
            }

            let financeType = ((data["financeType"] as? String) ?? (data["type"] as? String) ?? "index").lowercased()
            let key = BaiduStreamSubscription.key(code: code, market: market, financeType: financeType)
            guard let watchItems = itemMap[key] else {
                BaiduProbeLog.record("WSS recv quote for unsubscribed key=\(key) raw=\(text)")
                continue
            }

            // 生成快照数据
            let snapshots = watchItems.compactMap { item in
                makeBaiduStreamSnapshot(data: data, item: item, baseURL: url.host ?? urlString)
            }
            let update = data["update"] as? [String: Any]
            let tradeStatus = (update?["tradeStatus"] as? String) ?? "-"
            let priceText = snapshots.first.map(\.priceText) ?? "--"
            // 检查交易状态是否符合 WebSocket 推送条件
            let scriptEligible = BaiduTradeStatus.wsEligibleCases.contains(tradeStatus)
            BaiduProbeLog.record("WSS msgStatus=\(BaiduWebSocketMessageStatus.msg.rawValue) recv quote symbol=\(code) market=\(market) tradeStatus=\(tradeStatus) scriptEligible=\(scriptEligible) price=\(priceText) matchedItems=\(watchItems.count)")

            // 首次收到数据时标记为已连接
            if !acknowledged {
                acknowledged = true
                await stateHandler(.baiduGlobalIndex, .connected)
                BaiduProbeLog.record("WSS state=\(BaiduWebSocketStatus.connected.rawValue) msgStatus=\(BaiduWebSocketMessageStatus.connected.rawValue)")
                await snapshotHandler([], [LogEntry(level: .info, message: String(format: NSLocalizedString("Baidu Gushitong WebSocket Subscribed %d Symbols.", comment: ""), subscriptions.count))])
            }

            // 推送快照数据
            if !snapshots.isEmpty {
                await snapshotHandler(snapshots, [])
            }
        }
    }

    // 从 WebSocket 数据构建快照
    // 解析百度返回的实时行情数据，提取价格、涨跌幅等信息
    private static func makeBaiduStreamSnapshot(
        data: [String: Any],
        item: WatchItem,
        baseURL: String
    ) -> QuoteSnapshot? {
        // 百度的数据结构：
        // - cur: 当前价格信息
        // - point: 涨跌点数信息
        // - update: 交易状态信息
        let current = data["cur"] as? [String: Any]
        let point = data["point"] as? [String: Any]
        let update = data["update"] as? [String: Any]

        // 尝试从不同字段获取价格数据
        let price = baiduStreamNumber(current?["price"]) ?? baiduStreamNumber(point?["price"])
        let change = baiduStreamNumber(current?["increase"]) ?? baiduStreamNumber(point?["range"])
        let changePercent = baiduStreamNumber(point?["ratio"]) ?? baiduStreamNumber(current?["ratio"])

        // 至少需要有一个有效数据
        guard price != nil || change != nil || changePercent != nil else {
            return nil
        }

        // 获取市场状态（中文描述）
        let marketStatus = (update?["tradeStatusCN"] as? String)
            ?? (update?["stockStatus"] as? String)

        return QuoteSnapshot(
            id: item.id,
            item: item,
            price: price,
            change: change,
            changePercent: changePercent,
            sourceLabel: item.sourceKind.title,
            marketStatus: marketStatus,
            fetchedAt: Date(),
            usedBaseURL: baseURL
        )
    }

    // 解析百度返回的数字（支持字符串和数字类型）
    // 处理各种格式：数字、带逗号的数字、百分号、正负号等
    private static func baiduStreamNumber(_ rawValue: Any?) -> Double? {
        // 如果已经是数字类型，直接返回
        if let number = rawValue as? NSNumber {
            return number.doubleValue
        }

        // 处理字符串类型
        guard let rawText = rawValue as? String else { return nil }
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "--" else { return nil }

        // 清理格式：移除千分位逗号、百分号、正号
        let sanitized = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "+", with: "")

        return Double(sanitized)
    }
}
