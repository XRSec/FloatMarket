import CFNetwork
import Foundation

enum NetworkSessionFactory {
    static func makeSession(settings: AppSettings, useProxy: Bool = false) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false

        if useProxy, let proxyDictionary = makeProxyDictionary(settings: settings) {
            configuration.connectionProxyDictionary = proxyDictionary
        }

        return URLSession(configuration: configuration)
    }

    private static func makeProxyDictionary(settings: AppSettings) -> [AnyHashable: Any]? {
        let host = settings.proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, settings.proxyPort > 0 else {
            return nil
        }

        switch settings.proxyType {
        case .http:
            return [
                kCFNetworkProxiesHTTPEnable as AnyHashable: 1,
                kCFNetworkProxiesHTTPProxy as AnyHashable: host,
                kCFNetworkProxiesHTTPPort as AnyHashable: settings.proxyPort,
                kCFNetworkProxiesHTTPSEnable as AnyHashable: 1,
                kCFNetworkProxiesHTTPSProxy as AnyHashable: host,
                kCFNetworkProxiesHTTPSPort as AnyHashable: settings.proxyPort
            ]
        case .socks5:
            return [
                kCFNetworkProxiesSOCKSEnable as AnyHashable: 1,
                kCFNetworkProxiesSOCKSProxy as AnyHashable: host,
                kCFNetworkProxiesSOCKSPort as AnyHashable: settings.proxyPort
            ]
        }
    }
}

enum NetworkLogFormatter {
    static func requestFailureMessage(sourceName: String, error: Error) -> String {
        String(
            format: NSLocalizedString("%@ Request Failed: %@", comment: ""),
            sourceName,
            summary(for: error)
        )
    }

    static func webSocketDisconnectedMessage(sourceName: String, error: Error) -> String {
        String(
            format: NSLocalizedString("%@ WebSocket Connection Failed: %@", comment: ""),
            sourceName,
            summary(for: error)
        )
    }

    static func summary(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            switch code {
            case .timedOut:
                return NSLocalizedString("Request Timed Out.", comment: "")
            case .cancelled:
                return NSLocalizedString("Request Cancelled.", comment: "")
            case .cannotFindHost, .dnsLookupFailed:
                return NSLocalizedString("Host Lookup Failed.", comment: "")
            case .cannotConnectToHost:
                return NSLocalizedString("Connection Failed.", comment: "")
            case .networkConnectionLost:
                return NSLocalizedString("Network Connection Was Lost.", comment: "")
            case .notConnectedToInternet:
                return NSLocalizedString("No Internet Connection.", comment: "")
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot,
                 .clientCertificateRejected,
                 .clientCertificateRequired:
                return NSLocalizedString("TLS Handshake Failed.", comment: "")
            case .appTransportSecurityRequiresSecureConnection:
                return NSLocalizedString("Blocked By App Transport Security.", comment: "")
            default:
                break
            }
        }

        return error.localizedDescription
    }
}

struct MarketDataClient {
    func refresh(
        items: [WatchItem],
        settings: AppSettings,
        existingSnapshots: [UUID: QuoteSnapshot] = [:]
    ) async -> MarketRefreshResult {
        let activeItems = items.filter(\.enabled)
        guard !activeItems.isEmpty else {
            return MarketRefreshResult(
                logs: [LogEntry(level: .warning, message: NSLocalizedString("No Watch Items Are Enabled.", comment: ""))]
            )
        }

        async let baidu = fetchBaidu(
            items: activeItems.filter { $0.sourceKind == .baiduGlobalIndex },
            config: settings.baiduConfig,
            settings: settings,
            existingSnapshots: existingSnapshots
        )
        async let sina = fetchSinaGlobalIndices(
            items: activeItems.filter { $0.sourceKind == .sinaGlobalIndex },
            config: settings.sinaConfig,
            settings: settings,
            existingSnapshots: existingSnapshots
        )
        async let okx = fetchOKX(
            items: activeItems.filter { $0.sourceKind == .okxSpotMarket || $0.sourceKind == .okxSpot },
            config: settings.okxConfig,
            settings: settings
        )
        async let gate = fetchGate(
            items: gateHTTPRefreshItems(from: activeItems),
            config: settings.gateConfig,
            settings: settings
        )
        async let binance = fetchBinance(
            items: activeItems.filter { $0.sourceKind == .binanceSpot || $0.sourceKind == .binancePerp },
            config: settings.binanceConfig,
            settings: settings
        )

        let baiduResult = await baidu
        let sinaResult = await sina
        let okxResult = await okx
        let gateResult = await gate
        let binanceResult = await binance

        return MarketRefreshResult(
            snapshots: baiduResult.snapshots + sinaResult.snapshots + okxResult.snapshots + gateResult.snapshots + binanceResult.snapshots,
            logs: baiduResult.logs + sinaResult.logs + okxResult.logs + gateResult.logs + binanceResult.logs
        )
    }

    private func gateHTTPRefreshItems(from items: [WatchItem]) -> [WatchItem] {
        guard items.allSatisfy({ $0.sourceKind == .gateSpot || $0.sourceKind == .gateSpotMarket }) else {
            return []
        }

        return items.filter {
            switch $0.sourceKind {
            case .gateSpot, .gateSpotMarket:
                return true
            default:
                return false
            }
        }
    }

    func request(
        sourceName: String,
        path: String,
        queryItems: [URLQueryItem],
        config: EndpointConfiguration,
        settings: AppSettings,
        headers: [String: String] = [:]
    ) async -> RequestAttemptResult {
        var errors: [LogEntry] = []

        for baseURL in config.candidateBaseURLs {
            do {
                let (data, responseURL) = try await performRequest(
                    baseURL: baseURL,
                    path: path,
                    queryItems: queryItems,
                    timeout: config.timeout,
                    settings: settings,
                    useProxy: config.useProxy,
                    headers: headers
                )
                return .success(data: data, baseURL: responseURL)
            } catch {
                errors.append(
                    LogEntry(
                        level: .error,
                        message: NetworkLogFormatter.requestFailureMessage(
                            sourceName: sourceName,
                            error: error
                        )
                    )
                )
            }
        }

        return .failure(logs: errors)
    }

    private func performRequest(
        baseURL: String,
        path: String,
        queryItems: [URLQueryItem],
        timeout: Double,
        settings: AppSettings,
        useProxy: Bool,
        headers: [String: String]
    ) async throws -> (Data, String) {
        guard let url = buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = max(timeout, 3)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FloatMarket/1.0", forHTTPHeaderField: "User-Agent")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let session = NetworkSessionFactory.makeSession(settings: settings, useProxy: useProxy)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return (data, url.host ?? baseURL)
    }

    private func buildURL(baseURL: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let extraPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let joinedPath = [basePath, extraPath].filter { !$0.isEmpty }.joined(separator: "/")
        components.path = "/" + joinedPath
        components.queryItems = queryItems
        return components.url
    }

    static func cleanPercent(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: "%", with: ""))
    }

}

enum RequestAttemptResult {
    case success(data: Data, baseURL: String)
    case failure(logs: [LogEntry])
}

final class MarketStreamController {
    typealias SnapshotHandler = @MainActor ([QuoteSnapshot], [LogEntry]) -> Void
    typealias StateHandler = @MainActor (DataSourceKind, StreamConnectionState) -> Void

    private let snapshotHandler: SnapshotHandler
    private let stateHandler: StateHandler

    private var baiduTask: Task<Void, Never>?
    private var okxTask: Task<Void, Never>?
    private var gateTask: Task<Void, Never>?
    private var binanceTask: Task<Void, Never>?

    init(snapshotHandler: @escaping SnapshotHandler, stateHandler: @escaping StateHandler) {
        self.snapshotHandler = snapshotHandler
        self.stateHandler = stateHandler
    }

    func update(with settings: AppSettings) {
        stop()

        let baiduItems = settings.watchlist.filter { $0.enabled && $0.sourceKind == .baiduGlobalIndex }
        let okxItems = settings.watchlist.filter { $0.enabled && $0.sourceKind == .okxSpot }
        let gateItems = settings.watchlist.filter {
            $0.enabled && ($0.sourceKind == .gateSpot || $0.sourceKind == .gateSpotMarket)
        }
        let binanceItems = settings.watchlist.filter { $0.enabled && $0.sourceKind == .binancePerp }

        if !baiduItems.isEmpty {
            baiduTask = Task {
                await Self.runBaiduStream(
                    items: baiduItems,
                    config: settings.baiduConfig,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            }
        } else {
            Task { await stateHandler(.baiduGlobalIndex, .disconnected) }
        }

        if !okxItems.isEmpty {
            okxTask = Task {
                await Self.runOKXStream(
                    items: okxItems,
                    config: settings.okxConfig,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            }
        } else {
            Task { await stateHandler(.okxSpot, .disconnected) }
        }

        if !gateItems.isEmpty {
            gateTask = Task {
                await Self.runGateStream(
                    items: gateItems,
                    config: settings.gateConfig,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            }
        } else {
            Task { await stateHandler(.gateSpot, .disconnected) }
        }

        if !binanceItems.isEmpty {
            binanceTask = Task {
                await Self.runBinanceStream(
                    items: binanceItems,
                    config: settings.binanceConfig,
                    snapshotHandler: snapshotHandler,
                    stateHandler: stateHandler,
                    settings: settings
                )
            }
        } else {
            Task { await stateHandler(.binancePerp, .disconnected) }
        }
    }

    func stop() {
        baiduTask?.cancel()
        okxTask?.cancel()
        gateTask?.cancel()
        binanceTask?.cancel()
        baiduTask = nil
        okxTask = nil
        gateTask = nil
        binanceTask = nil
    }
    static func requestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
    }

    static func string(from message: URLSessionWebSocketTask.Message) -> String? {
        switch message {
        case let .string(value):
            return value
        case let .data(data):
            return String(data: data, encoding: .utf8)
        @unknown default:
            return nil
        }
    }

    static func jsonString(_ payload: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw StreamError.server(NSLocalizedString("JSON Encoding Failed", comment: ""))
        }
        return text
    }
}

enum StreamError: LocalizedError {
    case invalidURL(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            return String(format: NSLocalizedString("Invalid URL: %@", comment: ""), url)
        case let .server(message):
            return message
        }
    }
}
