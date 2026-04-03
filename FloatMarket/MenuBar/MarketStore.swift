import AppKit
import Foundation
import SwiftUI

enum FloatingDockSide {
    case none
    case left
    case right
}

struct MiniWindowLayoutMetrics: Equatable {
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    let outerHorizontalPadding: CGFloat
    let outerVerticalPadding: CGFloat
    let rowSpacing: CGFloat
    let rowHeight: CGFloat
    let columnSpacing: CGFloat
    let priceFontSize: CGFloat
    let labelFontSize: CGFloat
}

private enum RefreshRequest: Equatable {
    case snapshot(reason: String)
    case streamFallback(kind: DataSourceKind, trigger: StreamSyncTrigger)
}

private enum StreamSyncTrigger: Equatable {
    case disconnected
    case connected
}

@MainActor
final class MarketStore: ObservableObject {
    let settingsStore: SettingsStore

    @Published private(set) var quotesByID: [UUID: QuoteSnapshot] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var logEntries: [LogEntry] = []
    @Published private(set) var streamStates: [DataSourceKind: StreamConnectionState] = [
        .okxSpot: .disconnected,
        .gateSpot: .disconnected,
        .binancePerp: .disconnected
    ]
    @Published private(set) var isTestingProxy = false
    @Published private(set) var proxyTestMessage: String?
    @Published private(set) var isFloatingCollapsed = false
    @Published private(set) var floatingDockSide: FloatingDockSide = .none
    @Published private(set) var isTickerWindowVisible = true
    @Published private(set) var showsAllGlobalIndices = false

    private let client = MarketDataClient()
    private var refreshTask: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var previousSettings: AppSettings
    private var pendingRefreshRequests: [RefreshRequest] = []
    private lazy var streams = MarketStreamController(
        snapshotHandler: { [weak self] snapshots, logs in
            guard let self else { return }
            self.mergeSnapshots(snapshots)
            self.append(logs: logs)
        },
        stateHandler: { [weak self] kind, state in
            self?.handleStreamStateChange(kind: kind, state: state)
        }
    )

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.previousSettings = settingsStore.settings

        restartStreamTasks()
        Task {
            await refreshNow(reason: "launch")
        }
        restartRefreshLoop()
        showTickerWindow()
        observeSettingsChanges()
    }

    // MARK: - Convenience accessors

    private var settings: AppSettings { settingsStore.settings }

    // MARK: - Ordered quotes

    var orderedQuotes: [QuoteSnapshot] {
        let sortedIndices = settings.watchlist
            .filter { $0.enabled && $0.sourceKind.instrumentKind == .globalIndex }
            .sorted { lhs, rhs in
                let lhsTiming = timing(for: lhs)
                let rhsTiming = timing(for: rhs)
                if lhsTiming.sortBucket != rhsTiming.sortBucket {
                    return lhsTiming.sortBucket < rhsTiming.sortBucket
                }
                if lhsTiming.sortMinutes != rhsTiming.sortMinutes {
                    return lhsTiming.sortMinutes < rhsTiming.sortMinutes
                }
                return lhs.displayName < rhs.displayName
            }
        let allIndices = sortedIndices.compactMap { quotesByID[$0.id] }

        let sortedOthers = settings.watchlist
            .filter { $0.enabled && $0.sourceKind.instrumentKind != .globalIndex }
            .compactMap { quotesByID[$0.id] }

        return allIndices + sortedOthers
    }

    // MARK: - Window state

    func updateFloatingWindowState(isCollapsed: Bool, dockSide: FloatingDockSide) {
        self.isFloatingCollapsed = isCollapsed
        self.floatingDockSide = dockSide
    }

    func setFloatingCollapsed(_ isCollapsed: Bool) {
        self.isFloatingCollapsed = isCollapsed
    }

    func setShowsAllGlobalIndices(_ showsAll: Bool) {
        guard showsAllGlobalIndices != showsAll else { return }
        showsAllGlobalIndices = showsAll
    }

    func updateTickerWindowVisibility(_ isVisible: Bool) {
        guard isTickerWindowVisible != isVisible else { return }
        isTickerWindowVisible = isVisible

        if isVisible {
            restartRefreshLoop()
            restartStreamTasks()
            Task {
                await refreshNow(reason: "ticker-reopened")
            }
        } else {
            refreshTask?.cancel()
            refreshTask = nil
            streams.stop()
            streamStates = Self.disconnectedStreamStates
            showsAllGlobalIndices = false
            updateFloatingWindowState(isCollapsed: false, dockSide: .none)
        }
    }

    func showTickerWindow() {
        FloatingTickerWindowManager.shared.show(store: self, settingsStore: settingsStore)
    }

    func hideTickerWindow() {
        FloatingTickerWindowManager.shared.close()
    }

    // MARK: - Status

    private var streamHealth: (activeKinds: [DataSourceKind], disconnectedCount: Int) {
        let active = activeStreamingKinds
        let disconnected = active.filter { streamStates[$0] != .connected }.count
        return (active, disconnected)
    }

    var statusSymbolName: String {
        if !isTickerWindowVisible { return "pause.circle.fill" }
        if isRefreshing { return "arrow.triangle.2.circlepath" }
        let (active, disconnected) = streamHealth
        guard !active.isEmpty else { return "circle.lefthalf.filled" }
        if disconnected == 0 { return "checkmark.circle.fill" }
        if disconnected < active.count { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    var statusSymbolColor: Color {
        if !isTickerWindowVisible { return Color(nsColor: .secondaryLabelColor) }
        if isRefreshing { return Color(red: 0.98, green: 0.72, blue: 0.25) }
        let (active, disconnected) = streamHealth
        guard !active.isEmpty else { return Color(nsColor: .secondaryLabelColor) }
        if disconnected == 0 { return Color(red: 0.27, green: 0.83, blue: 0.54) }
        if disconnected < active.count { return Color(red: 0.98, green: 0.72, blue: 0.25) }
        return Color(red: 0.96, green: 0.37, blue: 0.35)
    }

    var headerStatusText: String {
        if isRefreshing {
            return NSLocalizedString("Refreshing", comment: "")
        }
        guard let lastUpdated else {
            return NSLocalizedString("Waiting For First Sync", comment: "")
        }
        return "Updated \(Self.timeFormatter.string(from: lastUpdated))"
    }

    var popupStatusText: String {
        if !isTickerWindowVisible { return NSLocalizedString("Paused", comment: "") }
        if isRefreshing { return NSLocalizedString("Refreshing", comment: "") }
        let (active, disconnected) = streamHealth
        guard !active.isEmpty else { return NSLocalizedString("Running", comment: "") }
        return disconnected == 0 ? NSLocalizedString("Running", comment: "") : NSLocalizedString("Issue", comment: "")
    }

    var footerStatusText: String {
        let interval = Int(settings.refreshInterval)
        return settings.autoRefresh ? "Auto \(interval)s" : NSLocalizedString("Manual", comment: "")
    }

    var menuBarStatusText: String {
        if !isTickerWindowVisible { return NSLocalizedString("Paused", comment: "") }
        let (active, disconnected) = streamHealth
        guard !active.isEmpty else { return NSLocalizedString("Polling", comment: "") }
        if disconnected == 0 { return NSLocalizedString("Healthy", comment: "") }
        if disconnected < active.count { return NSLocalizedString("Degraded", comment: "") }
        return NSLocalizedString("Critical", comment: "")
    }

    var menuBarStatusDetail: String {
        if !isTickerWindowVisible {
            return NSLocalizedString("Floating window is closed. Active fetching is paused.", comment: "")
        }
        let (active, disconnected) = streamHealth
        guard !active.isEmpty else {
            return NSLocalizedString("No realtime stream is enabled.", comment: "")
        }
        let connectedCount = active.count - disconnected
        return "\(connectedCount) / \(active.count) streams connected"
    }

    // MARK: - Logs

    func clearLogs() {
        logEntries.removeAll()
    }

    // MARK: - Proxy test

    func testProxy() async {
        isTestingProxy = true
        proxyTestMessage = nil

        defer { isTestingProxy = false }

        let s = settingsStore.draftSettings
        let trimmedURL = s.proxyTestURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL) else {
            proxyTestMessage = NSLocalizedString("Invalid Test URL", comment: "")
            addLog(.error, NSLocalizedString("Proxy test failed: test URL is invalid.", comment: ""))
            return
        }

        guard url.scheme?.lowercased() == "https" else {
            proxyTestMessage = NSLocalizedString("Test URL Must Use HTTPS", comment: "")
            addLog(.error, NSLocalizedString("Proxy test failed: test URL must use HTTPS.", comment: ""))
            return
        }

        do {
            let session = NetworkSessionFactory.makeSession(settings: s)
            defer { session.invalidateAndCancel() }

            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (_, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...399).contains(statusCode) {
                proxyTestMessage = String(format: NSLocalizedString("Proxy Reachable, Status %d", comment: ""), statusCode)
                addLog(.info, String(format: NSLocalizedString("Proxy test succeeded [%@], status %d.", comment: ""), url.absoluteString, statusCode))
            } else {
                proxyTestMessage = String(format: NSLocalizedString("Test Failed, Status %d", comment: ""), statusCode)
                addLog(.warning, String(format: NSLocalizedString("Proxy test returned status %d.", comment: ""), statusCode))
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorAppTransportSecurityRequiresSecureConnection {
                let failingURL = (nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String) ?? url.absoluteString
                proxyTestMessage = NSLocalizedString("Test URL Must Use HTTPS", comment: "")
                addLog(.error, String(format: NSLocalizedString("Proxy test failed: App Transport Security blocked %@. Use HTTPS.", comment: ""), failingURL))
                return
            }

            proxyTestMessage = String(format: NSLocalizedString("Test Failed: %@", comment: ""), error.localizedDescription)
            addLog(.error, String(format: NSLocalizedString("Proxy test failed: %@", comment: ""), error.localizedDescription))
        }
    }

    // MARK: - Refresh

    func refreshNow(reason: String) async {
        await enqueueRefresh(.snapshot(reason: reason))
    }

    // MARK: - Mini window

    var miniWindowSnapshots: [QuoteSnapshot] {
        let selected = settings.miniWindowItemIDs.compactMap { quotesByID[$0] }
        if !selected.isEmpty {
            return selected
        }
        return orderedQuotes.prefix(1).map { $0 }
    }

    var miniWindowSelectionItems: [WatchItem] {
        settingsStore.draftSettings.watchlist.filter(\.enabled)
    }

    func miniWindowLabel(for snapshot: QuoteSnapshot) -> String {
        if snapshot.item.sourceKind.instrumentKind == .globalIndex {
            return snapshot.item.displayName
        }
        return "\(snapshot.sourceLabel) · \(snapshot.item.displayName)"
    }

    func miniWindowCompactLabel(for snapshot: QuoteSnapshot) -> String {
        switch snapshot.item.sourceKind {
        case .baiduGlobalIndex, .sinaGlobalIndex:
            return snapshot.item.displayName
        case .okxSpotMarket:
            return snapshot.item.symbol
                .replacingOccurrences(of: "-USDT", with: "")
                .replacingOccurrences(of: "-", with: "")
        case .okxSpot:
            return snapshot.item.symbol
                .replacingOccurrences(of: "-USDT-SWAP", with: "")
                .replacingOccurrences(of: "-SWAP", with: "")
                .replacingOccurrences(of: "-", with: "") + " " + NSLocalizedString("Perpetual", comment: "")
        case .gateSpotMarket:
            return snapshot.item.symbol
                .replacingOccurrences(of: "_USDT", with: "")
                .replacingOccurrences(of: "_", with: "")
        case .gateSpot:
            return snapshot.item.symbol
                .replacingOccurrences(of: "_USDT", with: "")
                .replacingOccurrences(of: "_", with: "") + " " + NSLocalizedString("Perpetual", comment: "")
        case .binanceSpot:
            return snapshot.item.symbol
                .replacingOccurrences(of: "USDT", with: "")
        case .binancePerp:
            return snapshot.item.symbol
                .replacingOccurrences(of: "USDT", with: "") + " " + NSLocalizedString("Perpetual", comment: "")
        }
    }

    var miniWindowLayoutMetrics: MiniWindowLayoutMetrics {
        let baseFontSize = CGFloat(settings.miniWindowFontSize)
        let priceFontSize = max(11, floor(baseFontSize))
        let labelFontSize = max(10, floor(priceFontSize * 0.78))
        let outerHorizontalPadding = max(8, floor(priceFontSize * 0.55))
        let outerVerticalPadding = max(6, floor(priceFontSize * 0.42))
        let rowSpacing = max(2, floor(priceFontSize * 0.20))
        let columnSpacing = max(8, floor(priceFontSize * 0.42))

        let priceFont = NSFont.monospacedDigitSystemFont(ofSize: priceFontSize, weight: .bold)
        let labelFont = NSFont.systemFont(ofSize: labelFontSize, weight: .bold)
        let rowHeight = ceil(max(Self.lineHeight(for: priceFont), Self.lineHeight(for: labelFont)))

        let rowWidths: [CGFloat]
        if miniWindowSnapshots.isEmpty {
            rowWidths = [Self.textWidth("--", font: priceFont)]
        } else {
            rowWidths = miniWindowSnapshots.map { snapshot in
                var width = Self.textWidth(snapshot.priceText, font: priceFont)
                if settings.collapsedDisplayMode == .symbolAndPrice {
                    width += 18 + 6
                    width += Self.textWidth(miniWindowCompactLabel(for: snapshot), font: labelFont) + columnSpacing
                }
                return ceil(width)
            }
        }

        let contentWidth = max(rowWidths.max() ?? 0, Self.textWidth("--", font: priceFont))
        let rowCount = max(miniWindowSnapshots.count, 1)
        let contentHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * rowSpacing

        return MiniWindowLayoutMetrics(
            windowWidth: ceil(contentWidth + outerHorizontalPadding * 2),
            windowHeight: ceil(contentHeight + outerVerticalPadding * 2),
            outerHorizontalPadding: outerHorizontalPadding,
            outerVerticalPadding: outerVerticalPadding,
            rowSpacing: rowSpacing,
            rowHeight: rowHeight,
            columnSpacing: columnSpacing,
            priceFontSize: priceFontSize,
            labelFontSize: labelFontSize
        )
    }

    // MARK: - Appearance helpers

    var preferredFloatingColorScheme: ColorScheme? {
        settings.floatingThemeMode.preferredColorScheme
    }

    var expandedFloatingColumnCount: Int {
        1
    }

    var expandedFloatingWidth: CGFloat {
        CGFloat(settings.floatingWidth)
    }

    var expandedFloatingHeight: CGFloat {
        let maxHeight = CGFloat(settings.floatingMaxHeight)
        let contentHeight = expandedContentIdealHeight
        return min(contentHeight, maxHeight)
    }

    var collapsedFloatingWidth: CGFloat { miniWindowLayoutMetrics.windowWidth }
    var collapsedFloatingHeight: CGFloat { miniWindowLayoutMetrics.windowHeight }
    var isFloatingPeekThroughMode: Bool {
        let activeOpacity = isFloatingCollapsed ? settings.miniWindowBackgroundOpacity : settings.backgroundOpacity
        return activeOpacity <= 0.05
    }

    func quoteChangeColor(for snapshot: QuoteSnapshot, colorScheme: ColorScheme? = nil) -> Color {
        let resolvedColorScheme = resolvedFloatingColorScheme(colorScheme)

        guard let change = snapshot.change else {
            return settings.priceColorStyle.neutralColor(for: resolvedColorScheme)
        }

        if change > 0 { return settings.priceColorStyle.upColor(for: resolvedColorScheme) }
        if change < 0 { return settings.priceColorStyle.downColor(for: resolvedColorScheme) }
        return settings.priceColorStyle.neutralColor(for: resolvedColorScheme)
    }

    // MARK: - Market timing

    func timing(for item: WatchItem) -> IndexMarketTiming {
        let hasSnapshot = quotesByID[item.id] != nil
        guard item.sourceKind.instrumentKind == .globalIndex,
              let schedule = IndexMarketSchedule.forSymbol(item.symbol)
        else {
            return IndexMarketTiming(phase: .closed, nextOpen: nil, shouldRefresh: true)
        }
        return schedule.timing(
            now: Date(),
            hasSnapshot: hasSnapshot,
            customOpenTime: item.customOpenTime,
            customCloseTime: item.customCloseTime
        )
    }

    // MARK: - Private

    private func observeSettingsChanges() {
        settingsObservation = Task { [weak self] in
            guard let self else { return }
            for await _ in self.settingsStore.$settings.values {
                let new = self.settingsStore.settings
                let old = self.previousSettings
                if self.shouldRestartNetworking(old: old, new: new) {
                    self.restartRefreshLoop()
                    self.restartStreamTasks()
                }
                self.previousSettings = new
                self.trimSnapshotsToWatchlist()
            }
        }
    }

    private func restartRefreshLoop() {
        refreshTask?.cancel()
        guard settings.autoRefresh, isTickerWindowVisible, hasPollingRefreshItems else { return }

        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let interval = self.settings.refreshInterval
                let nanoseconds = UInt64(max(interval, 5) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)

                if Task.isCancelled { break }
                await self.refreshNow(reason: "scheduled")
            }
        }
    }

    private func restartStreamTasks() {
        guard isTickerWindowVisible else {
            streams.stop()
            return
        }
        streams.update(with: settings)
    }

    private var activeStreamingKinds: [DataSourceKind] {
        Array(
            Set(
                settings.watchlist
                    .filter { $0.enabled && ($0.sourceKind == .okxSpot || $0.sourceKind == .gateSpot || $0.sourceKind == .binancePerp) }
                    .map(\.sourceKind)
            )
        ).sorted { $0.rawValue < $1.rawValue }
    }

    private var pollingRefreshItems: [WatchItem] {
        settings.watchlist.filter { $0.enabled && !Self.isStreamingSourceKind($0.sourceKind) }
    }

    private var hasPollingRefreshItems: Bool {
        !pollingRefreshItems.isEmpty
    }

    private func addLog(_ level: LogLevel, _ message: String) {
        append(logs: [LogEntry(level: level, message: message)])
    }

    private func append(logs: [LogEntry]) {
        guard !logs.isEmpty else { return }
        var merged = logs.reversed() + logEntries
        if merged.count > 300 {
            merged = Array(merged.prefix(300))
        }
        logEntries = merged
    }

    private func mergeSnapshots(_ snapshots: [QuoteSnapshot]) {
        guard !snapshots.isEmpty else { return }

        var merged = quotesByID
        let validIDs = Set(settings.watchlist.map(\.id))
        for snapshot in snapshots {
            merged[snapshot.id] = snapshot
        }
        merged = merged.filter { validIDs.contains($0.key) }
        quotesByID = merged
        lastUpdated = Date()
    }

    private func trimSnapshotsToWatchlist() {
        let validIDs = Set(settings.watchlist.map(\.id))
        quotesByID = quotesByID.filter { validIDs.contains($0.key) }
    }

    private func handleStreamStateChange(kind: DataSourceKind, state: StreamConnectionState) {
        let previous = streamStates[kind] ?? .disconnected
        guard previous != state else { return }

        streamStates[kind] = state

        switch state {
        case .connected:
            Task {
                await enqueueRefresh(.streamFallback(kind: kind, trigger: .connected))
            }

        case .disconnected:
            guard previous == .connecting || previous == .connected else { return }
            Task {
                await enqueueRefresh(.streamFallback(kind: kind, trigger: .disconnected))
            }

        case .connecting:
            break
        }
    }

    private func enqueueRefresh(_ request: RefreshRequest) async {
        if isRefreshing {
            if !pendingRefreshRequests.contains(request) {
                pendingRefreshRequests.append(request)
            }
            return
        }

        isRefreshing = true
        var currentRequest: RefreshRequest? = request

        while let request = currentRequest {
            await performRefresh(request)
            currentRequest = pendingRefreshRequests.isEmpty ? nil : pendingRefreshRequests.removeFirst()
        }

        isRefreshing = false
    }

    private func performRefresh(_ request: RefreshRequest) async {
        let items: [WatchItem]
        let label: String
        let shouldLogSkip: Bool
        let shouldLogLifecycle: Bool

        switch request {
        case let .snapshot(reason):
            items = pollingRefreshItems
            label = snapshotRefreshLabel(for: reason)
            shouldLogSkip = reason == "control-center-general" || reason == "empty-state"
            shouldLogLifecycle = false

        case let .streamFallback(kind, trigger):
            items = settings.watchlist.filter { $0.enabled && $0.sourceKind == kind }
            label = streamRefreshLabel(for: kind, trigger: trigger)
            shouldLogSkip = false
            shouldLogLifecycle = true
        }

        guard !items.isEmpty else {
            if shouldLogSkip {
                addLog(.info, String(format: NSLocalizedString("%@ skipped because no eligible items are enabled.", comment: ""), label))
            }
            return
        }

        if shouldLogLifecycle {
            addLog(.info, String(format: NSLocalizedString("%@ started for %d items.", comment: ""), label, items.count))
        }

        let result = await client.refresh(
            items: items,
            settings: settings,
            existingSnapshots: quotesByID
        )

        append(logs: result.logs)
        mergeSnapshots(result.snapshots)

        if result.snapshots.isEmpty, shouldLogLifecycle {
            addLog(.warning, String(format: NSLocalizedString("%@ finished with no quotes.", comment: ""), label))
        } else if shouldLogLifecycle {
            addLog(.info, String(format: NSLocalizedString("%@ finished, updated %d quotes.", comment: ""), label, result.snapshots.count))
        }
    }

    private func snapshotRefreshLabel(for reason: String) -> String {
        switch reason {
        case "launch":
            return NSLocalizedString("Launch snapshot sync", comment: "")
        case "ticker-reopened":
            return NSLocalizedString("Window reopen snapshot sync", comment: "")
        case "scheduled":
            return NSLocalizedString("Scheduled snapshot refresh", comment: "")
        case "control-center-general", "empty-state":
            return NSLocalizedString("Manual snapshot refresh", comment: "")
        default:
            return NSLocalizedString("Snapshot refresh", comment: "")
        }
    }

    private func streamRefreshLabel(for kind: DataSourceKind, trigger: StreamSyncTrigger) -> String {
        let sourceName = streamSourceName(for: kind)

        switch trigger {
        case .disconnected:
            return String(
                format: NSLocalizedString("%@ HTTP fallback sync after WebSocket disconnect", comment: ""),
                sourceName
            )
        case .connected:
            return String(
                format: NSLocalizedString("%@ HTTP resync after WebSocket reconnect", comment: ""),
                sourceName
            )
        }
    }

    private func streamSourceName(for kind: DataSourceKind) -> String {
        switch kind {
        case .okxSpot:
            return "OKX"
        case .gateSpot:
            return "Gate"
        case .binancePerp:
            return "Binance"
        default:
            return kind.title
        }
    }

    private static func isStreamingSourceKind(_ kind: DataSourceKind) -> Bool {
        switch kind {
        case .okxSpot, .gateSpot, .binancePerp:
            return true
        case .baiduGlobalIndex, .sinaGlobalIndex, .okxSpotMarket, .gateSpotMarket, .binanceSpot:
            return false
        }
    }

    private func resolvedFloatingColorScheme(_ fallback: ColorScheme?) -> ColorScheme {
        preferredFloatingColorScheme ?? fallback ?? .dark
    }

    private var expandedContentIdealHeight: CGFloat {
        guard !orderedQuotes.isEmpty else { return 284 }

        let fontSize = CGFloat(settings.floatingFontSize)
        let columnCount = CGFloat(expandedFloatingColumnCount)
        let nameFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let priceFont = NSFont.systemFont(ofSize: fontSize + 3, weight: .bold)
        let changeFont = NSFont.systemFont(ofSize: max(fontSize - 2, 10), weight: .semibold)
        let sectionFont = NSFont.systemFont(ofSize: max(fontSize - 2, 11), weight: .semibold)
        let footerFont = NSFont.systemFont(ofSize: max(fontSize - 1, 11), weight: .medium)

        let sectionHeaderHeight = Self.lineHeight(for: sectionFont)
        let footerHeight = Self.lineHeight(for: footerFont) + 2
        let rowLeadingHeight = max(18, Self.lineHeight(for: nameFont))
        let rowTrailingHeight = Self.lineHeight(for: priceFont) + 4 + Self.lineHeight(for: changeFont)
        let rowHeight = ceil(max(rowLeadingHeight, rowTrailingHeight) + 16)

        let controlsHeight: CGFloat = 24
        let outerVerticalPadding: CGFloat = 16
        let outerStackSpacing: CGFloat = 10
        let sectionSpacing: CGFloat = 10
        let headerBottomSpacing: CGFloat = 6
        let gridRowSpacing: CGFloat = 8

        let allIndexRows = orderedQuotes.filter { $0.item.sourceKind.instrumentKind == .globalIndex }
        let displayedIndexRows = showsAllGlobalIndices
            ? allIndexRows
            : allIndexRows.filter { snapshot in
                let timing = timing(for: snapshot.item)
                return timing.isTrading || timing.isOpeningWithinHour || timing.isRecentlyClosedWithinHour
            }
        let spotRows = orderedQuotes.filter { $0.item.sourceKind.instrumentKind == .spot }
        let perpetualRows = orderedQuotes.filter { $0.item.sourceKind.instrumentKind == .perpetual }

        var sectionHeights: [CGFloat] = []
        if !allIndexRows.isEmpty {
            let rowCount = ceil(CGFloat(displayedIndexRows.count) / columnCount)
            let gridHeight: CGFloat
            if displayedIndexRows.isEmpty {
                gridHeight = 0
            } else {
                gridHeight = rowCount * rowHeight + CGFloat(max(Int(rowCount) - 1, 0)) * gridRowSpacing
            }
            // The indices section stays visible with its header and toggle even when rows are collapsed away.
            sectionHeights.append(sectionHeaderHeight + headerBottomSpacing + gridHeight)
        }
        if !spotRows.isEmpty {
            let rowCount = ceil(CGFloat(spotRows.count) / columnCount)
            sectionHeights.append(sectionHeaderHeight + headerBottomSpacing + rowCount * rowHeight + CGFloat(max(Int(rowCount) - 1, 0)) * gridRowSpacing)
        }
        if !perpetualRows.isEmpty {
            let rowCount = ceil(CGFloat(perpetualRows.count) / columnCount)
            sectionHeights.append(sectionHeaderHeight + headerBottomSpacing + rowCount * rowHeight + CGFloat(max(Int(rowCount) - 1, 0)) * gridRowSpacing)
        }

        let sectionsHeight = sectionHeights.reduce(0, +) + CGFloat(max(sectionHeights.count - 1, 0)) * sectionSpacing
        return ceil(outerVerticalPadding + controlsHeight + outerStackSpacing + sectionsHeight + outerStackSpacing + footerHeight)
    }

    private func shouldRestartNetworking(old: AppSettings, new: AppSettings) -> Bool {
        old.autoRefresh != new.autoRefresh ||
        old.refreshInterval != new.refreshInterval ||
        old.proxyEnabled != new.proxyEnabled ||
        old.proxyType != new.proxyType ||
        old.proxyHost != new.proxyHost ||
        old.proxyPort != new.proxyPort ||
        old.baiduConfig != new.baiduConfig ||
        old.okxConfig != new.okxConfig ||
        old.gateConfig != new.gateConfig ||
        old.binanceConfig != new.binanceConfig ||
        old.watchlist != new.watchlist
    }

    private static let disconnectedStreamStates: [DataSourceKind: StreamConnectionState] = [
        .okxSpot: .disconnected,
        .gateSpot: .disconnected,
        .binancePerp: .disconnected
    ]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func lineHeight(for font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }
}
