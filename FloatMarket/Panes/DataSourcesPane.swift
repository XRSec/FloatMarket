import SwiftUI

// Status badges subscribe to the store separately so live quote updates do not redraw the form below.
private struct DataSourceStateLabel: View {
    @EnvironmentObject private var store: MarketStore
    let source: DataSourceKind

    var body: some View {
        DataSourceStateBadge(title: statusText, tint: statusColor)
    }

    private var statusText: String {
        switch store.streamStates[source] ?? .disconnected {
        case .standby:      return NSLocalizedString("Standby", comment: "")
        case .connected:    return NSLocalizedString("Connected", comment: "")
        case .connecting:   return NSLocalizedString("Connecting", comment: "")
        case .disconnected: return NSLocalizedString("Disconnected", comment: "")
        }
    }

    private var statusColor: Color {
        switch store.streamStates[source] ?? .disconnected {
        case .standby:      return Color(nsColor: .secondaryLabelColor)
        case .connected:    return Color(red: 0.27, green: 0.83, blue: 0.54)
        case .connecting:   return Color(red: 0.34, green: 0.73, blue: 0.98)
        case .disconnected: return Color(red: 0.96, green: 0.37, blue: 0.35)
        }
    }
}

// DataSourcesPane reads only settingsStore and stays isolated from quote refresh updates.
struct DataSourcesPane: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private var baiduHasActiveRealtimeItems: Bool {
        settingsStore.draftSettings.watchlist.contains { item in
            item.enabled && item.baiduShouldUseStreamNow
        }
    }

    private var baiduStatusLabel: AnyView {
        if baiduHasActiveRealtimeItems {
            return AnyView(DataSourceStateLabel(source: .baiduGlobalIndex))
        }

        return AnyView(DataSourceStateBadge(
            title: NSLocalizedString("HTTP polling", comment: ""),
            tint: Color.accentColor
        ))
    }

    private var baiduBDUSSBinding: Binding<String> {
        Binding(
            get: { settingsStore.draftSettings.baiduConfig.bduss },
            set: { settingsStore.draftSettings.baiduConfig.bduss = $0 }
        )
    }

    var body: some View {
        ControlCenterScrollPane {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    endpointPanel(
                        title: NSLocalizedString("FinScope", comment: ""),
                        subtitle: NSLocalizedString("Global index polling endpoint", comment: ""),
                        statusLabel: baiduStatusLabel,
                        configuration: settingsStore.draftBinding(for: \.baiduConfig),
                        showsWebSocket: true,
                        extraContent: AnyView(
                            VStack(alignment: .leading, spacing: 10) {
                                Divider()
                                    .padding(.vertical, 4)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(NSLocalizedString("BDUSS", comment: ""))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)

                                    SecureField("BDUSS=", text: baiduBDUSSBinding)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))

                                    Text(NSLocalizedString("Baidu self-select requests now rely on your BDUSS session cookie. Leave it empty to disable the cookie-authenticated lane.", comment: ""))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        )
                    )

                    endpointPanel(
                        title: NSLocalizedString("Sina Finance", comment: ""),
                        subtitle: NSLocalizedString("Global index polling endpoint", comment: ""),
                        statusLabel: AnyView(DataSourceStateBadge(
                            title: NSLocalizedString("HTTP polling", comment: ""),
                            tint: Color(red: 0.93, green: 0.33, blue: 0.24)
                        )),
                        configuration: settingsStore.draftBinding(for: \.sinaConfig),
                        showsWebSocket: false
                    )
                }

                HStack(alignment: .top, spacing: 16) {
                    endpointPanel(
                        title: "OKX",
                        subtitle: NSLocalizedString("Spot and perpetual market data lane", comment: ""),
                        statusLabel: AnyView(DataSourceStateLabel(source: .okxSpot)),
                        configuration: settingsStore.draftBinding(for: \.okxConfig),
                        showsWebSocket: true
                    )

                    endpointPanel(
                        title: "Gate",
                        subtitle: NSLocalizedString("Spot and perpetual market data lane", comment: ""),
                        statusLabel: AnyView(DataSourceStateLabel(source: .gateSpot)),
                        configuration: settingsStore.draftBinding(for: \.gateConfig),
                        showsWebSocket: true
                    )

                    endpointPanel(
                        title: NSLocalizedString("Binance", comment: ""),
                        subtitle: NSLocalizedString("Spot and perpetual market data lane", comment: ""),
                        statusLabel: AnyView(DataSourceStateLabel(source: .binancePerp)),
                        configuration: settingsStore.draftBinding(for: \.binanceConfig),
                        showsWebSocket: true
                    )
                }
            }
        }
    }

    private func endpointPanel(
        title: String,
        subtitle: String,
        statusLabel: AnyView,
        configuration: Binding<EndpointConfiguration>,
        showsWebSocket: Bool,
        extraContent: AnyView? = nil
    ) -> some View {
        GroupBox {
            Toggle(NSLocalizedString("Use Proxy", comment: ""), isOn: endpointBoolBinding(configuration, \.useProxy))

            endpointField(
                title: NSLocalizedString("Primary URL", comment: ""),
                placeholder: "https://",
                text: endpointStringBinding(configuration, \.primaryURL)
            )

            endpointField(
                title: NSLocalizedString("Backup URL", comment: ""),
                placeholder: "https://",
                text: endpointStringBinding(configuration, \.backupURL)
            )

            if showsWebSocket {
                endpointField(
                    title: NSLocalizedString("Primary WebSocket", comment: ""),
                    placeholder: "wss://",
                    text: endpointStringBinding(configuration, \.primaryWebSocketURL)
                )

                endpointField(
                    title: NSLocalizedString("Backup WebSocket", comment: ""),
                    placeholder: "wss://",
                    text: endpointStringBinding(configuration, \.backupWebSocketURL)
                )
            }

            ControlCenterSliderRow(
                title: NSLocalizedString("Timeout", comment: ""),
                subtitle: NSLocalizedString("Timeout triggers fallback to backup endpoints.", comment: ""),
                valueText: "\(Int(configuration.wrappedValue.timeout)) s",
                value: endpointDoubleBinding(configuration, \.timeout),
                range: 3...20,
                step: 1
            )

            if let extraContent {
                extraContent
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ControlCenterSectionLabel(title: title, subtitle: subtitle)
                Spacer()
                statusLabel
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func endpointField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }

    private func endpointStringBinding(
        _ configuration: Binding<EndpointConfiguration>,
        _ keyPath: WritableKeyPath<EndpointConfiguration, String>
    ) -> Binding<String> {
        Binding(
            get: { configuration.wrappedValue[keyPath: keyPath] },
            set: { configuration.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    private func endpointDoubleBinding(
        _ configuration: Binding<EndpointConfiguration>,
        _ keyPath: WritableKeyPath<EndpointConfiguration, Double>
    ) -> Binding<Double> {
        Binding(
            get: { configuration.wrappedValue[keyPath: keyPath] },
            set: { configuration.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    private func endpointBoolBinding(
        _ configuration: Binding<EndpointConfiguration>,
        _ keyPath: WritableKeyPath<EndpointConfiguration, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { configuration.wrappedValue[keyPath: keyPath] },
            set: { configuration.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

private struct DataSourceStateBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

struct WatchlistPane: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selection: UUID?
    @State private var showResetAlert = false

    private var pinnedCount: Int {
        settingsStore.draftSettings.miniWindowItemIDs.count
    }

    private var sortedWatchlist: [WatchItem] {
        settingsStore.draftSettings.watchlist
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.enabled != rhs.element.enabled {
                    return lhs.element.enabled && !rhs.element.enabled
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private var selectedIndex: Int? {
        guard let selection else { return nil }
        let index = settingsStore.draftSettings.watchlist.firstIndex(where: { $0.id == selection })
        // 确保索引有效
        if let index, index < settingsStore.draftSettings.watchlist.count {
            return index
        }
        return nil
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                watchlistToolbar
                Divider()

                List(selection: $selection) {
                    ForEach(sortedWatchlist) { item in
                        WatchlistListRow(item: item)
                            .tag(item.id)
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 280, maxHeight: .infinity)

            Group {
                if let selectedIndex, selectedIndex < settingsStore.draftSettings.watchlist.count {
                    WatchItemDetailEditor(
                        item: settingsStore.draftWatchItemBinding(at: selectedIndex),
                        canMoveUp: selectedIndex > 0,
                        canMoveDown: selectedIndex < settingsStore.draftSettings.watchlist.count - 1,
                        onMoveUp: { moveSelected(by: -1) },
                        onMoveDown: { moveSelected(by: 1) },
                        onDelete: deleteSelected
                    )
                    .id(settingsStore.draftSettings.watchlist[selectedIndex].id)
                } else {
                    ControlCenterScrollPane {
                        ControlCenterEmptyState(
                            systemImage: "square.and.pencil",
                            title: NSLocalizedString("Select an item to edit", comment: ""),
                            message: NSLocalizedString("Choose an item from the left list to view its detailed settings here.", comment: "")
                        )
                    }
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            reconcileSelection(with: settingsStore.draftSettings.watchlist.map(\.id))
        }
        .onChange(of: settingsStore.draftSettings.watchlist.map(\.id)) { ids in
            reconcileSelection(with: ids)
        }
        .alert(
            NSLocalizedString("Reset Watchlist?", comment: ""),
            isPresented: $showResetAlert,
            actions: {
                Button(NSLocalizedString("Reset", comment: ""), role: .destructive) {
                    settingsStore.resetDraftWatchlistToDefaults()
                    selection = settingsStore.draftSettings.watchlist.first?.id
                }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { }
            },
            message: {
                Text(NSLocalizedString("This restores the default watchlist and clears pinned mini-window items.", comment: ""))
            }
        )
    }

    private var watchlistToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Watchlist", comment: ""))
                        .font(.system(size: 17, weight: .bold))
                }

                Spacer()

                Menu {
                    presetMenu(for: .baiduGlobalIndex)
                    presetMenu(for: .sinaGlobalIndex)
                    Divider()
                    presetMenu(for: .okxSpotMarket)
                    presetMenu(for: .okxSpot)
                    presetMenu(for: .gateSpotMarket)
                    presetMenu(for: .gateSpot)
                    presetMenu(for: .binanceSpot)
                    presetMenu(for: .binancePerp)
                } label: {
                    Label(NSLocalizedString("Add", comment: ""), systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Text(NSLocalizedString("The floating window automatically groups and sorts items by market state.", comment: ""))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                summaryBadge(
                    title: NSLocalizedString("Total", comment: ""),
                    value: "\(settingsStore.draftSettings.watchlist.count)"
                )
                summaryBadge(
                    title: NSLocalizedString("Pinned", comment: ""),
                    value: "\(pinnedCount)"
                )
            }

            HStack(spacing: 8) {
                Button(NSLocalizedString("Duplicate", comment: "")) {
                    duplicateSelected()
                }
                .buttonStyle(.bordered)
                .disabled(selection == nil)

                Button(NSLocalizedString("Reset Defaults", comment: "")) {
                    showResetAlert = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(16)
    }

    private func summaryBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private func presetMenu(for source: DataSourceKind) -> some View {
        Menu(source.title) {
            ForEach(WatchItemTemplateCatalog.templates(for: source)) { template in
                Button(template.displayName) {
                    addItem(template)
                }
            }
        }
    }

    private func addItem(_ template: WatchItemTemplate) {
        settingsStore.addWatchItem(from: template)
        selection = settingsStore.draftSettings.watchlist.last?.id
    }

    private func duplicateSelected() {
        guard let selection else { return }
        self.selection = settingsStore.duplicateWatchItem(selection)
    }

    private func moveSelected(by direction: Int) {
        guard let selection else { return }
        settingsStore.moveWatchItem(id: selection, direction: direction)
        self.selection = selection
    }

    private func deleteSelected() {
        guard let selection else { return }
        settingsStore.removeWatchItem(selection)
        self.selection = nil
    }

    private func reconcileSelection(with ids: [UUID]) {
        guard !ids.isEmpty else {
            selection = nil
            return
        }
        if let selection, ids.contains(selection) {
            return
        }
        selection = ids.first
    }
}

private struct WatchlistListRow: View {
    @EnvironmentObject private var store: MarketStore
    let item: WatchItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.enabled ? tintColor : Color.secondary.opacity(0.22))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(item.sourceKind.title) · \(item.symbol)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if item.sourceKind == .baiduGlobalIndex, let area = item.area {
                Text(NSLocalizedString(area.title, comment: ""))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var tintColor: Color {
        switch item.sourceKind {
        case .baiduGlobalIndex:
            return Color.accentColor
        case .sinaGlobalIndex:
            return Color(red: 0.93, green: 0.33, blue: 0.24)
        case .okxSpotMarket, .okxSpot:
            return Color(red: 0.34, green: 0.73, blue: 0.98)
        case .gateSpotMarket, .gateSpot:
            return Color(red: 0.47, green: 0.79, blue: 0.58)
        case .binanceSpot, .binancePerp:
            return Color(red: 0.98, green: 0.72, blue: 0.25)
        }
    }
}

private struct WatchItemDetailEditor: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Binding var item: WatchItem
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ControlCenterScrollPane {
            GroupBox {
                Toggle(NSLocalizedString("Enable This Item", comment: ""), isOn: $item.enabled)

                if !availableTemplates.isEmpty {
                    Picker(NSLocalizedString("Preset", comment: ""), selection: selectedTemplateID) {
                        Text(NSLocalizedString("Custom", comment: "")).tag(customTemplateID)
                        ForEach(availableTemplates) { template in
                            Text(template.displayName).tag(template.id)
                        }
                    }
                }

                TextField(NSLocalizedString("Display Name", comment: ""), text: $item.displayName)
                    .textFieldStyle(.roundedBorder)

                HStack(alignment: .top, spacing: 12) {
                    Picker(NSLocalizedString("Source", comment: ""), selection: $item.sourceKind) {
                        ForEach(DataSourceKind.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }.frame(maxWidth: 300)

                    TextField(NSLocalizedString("Symbol / Contract", comment: ""), text: $item.symbol)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))

                    if item.sourceKind == .baiduGlobalIndex {
                        Picker(NSLocalizedString("Region", comment: ""), selection: Binding(
                            get: { item.area ?? .america },
                            set: { item.area = $0 }
                        )) {
                            ForEach(BaiduArea.allCases) { area in
                                Text(NSLocalizedString(area.title, comment: "")).tag(area)
                            }
                        }
                        .frame(maxWidth: 100)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Quick Link URL", comment: ""))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField(
                        "https://",
                        text: Binding(
                            get: { item.customURL ?? "" },
                            set: { item.customURL = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                    Text(NSLocalizedString("Double-click this item in the floating window to open the link.", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Basics", comment: ""),
                    subtitle: NSLocalizedString("Only the fields that directly affect fetching and display stay here.", comment: "")
                )
            }

            GroupBox {
                Toggle(
                    NSLocalizedString("Pin This Item In The Mini Window", comment: ""),
                    isOn: miniWindowSelection
                )

                Text(
                    item.enabled
                    ? NSLocalizedString("Enabled items can participate in the mini-window selection.", comment: "")
                    : NSLocalizedString("This item is disabled and will not appear in the main board after saving.", comment: "")
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Mini Window", comment: ""),
                    subtitle: NSLocalizedString("Pin mini-window items here instead of hunting through the appearance page.", comment: "")
                )
            }

            if item.sourceKind.instrumentKind == .globalIndex, IndexMarketSchedule.forSymbol(item.symbol) != nil {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("Custom Open Time", comment: ""))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Picker(NSLocalizedString("Custom Open Time", comment: ""), selection: customOpenTimeSelection) {
                                    Text("Default \(defaultOpenTimeText)")
                                        .tag(String?.none)

                                    ForEach(openTimeOptions, id: \.self) { option in
                                        Text(option).tag(Optional(option))
                                    }
                                }
                                .frame(maxWidth: 250)

                                Button(NSLocalizedString("Reset", comment: "")) {
                                    item.customOpenTime = nil
                                }
                                .buttonStyle(.bordered)
                                .disabled(item.customOpenTime == nil)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("Custom Close Time", comment: ""))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Picker(NSLocalizedString("Custom Close Time", comment: ""), selection: customCloseTimeSelection) {
                                    Text("Default \(defaultCloseTimeText)")
                                        .tag(String?.none)

                                    ForEach(closeTimeOptions, id: \.self) { option in
                                        Text(option).tag(Optional(option))
                                    }
                                }
                                .frame(maxWidth: 250)

                                Button(NSLocalizedString("Reset", comment: "")) {
                                    item.customCloseTime = nil
                                }
                                .buttonStyle(.bordered)
                                .disabled(item.customCloseTime == nil)
                            }
                        }

                        Text(NSLocalizedString("Times follow exchange local time with hour and half-hour options.", comment: ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if !isCustomTradingTimeValid {
                            Text(NSLocalizedString("Open or close time is invalid or conflicts with the default market session.", comment: ""))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                        }
                    }
                } label: {
                    ControlCenterSectionLabel(
                        title: NSLocalizedString("Trading Session", comment: ""),
                        subtitle: NSLocalizedString("Custom open and close times are available for global indices only.", comment: "")
                    )
                }
            }

            GroupBox {
                HStack(spacing: 10) {
                    Button(NSLocalizedString("Move Up", comment: ""), action: onMoveUp)
                        .buttonStyle(.bordered)
                        .disabled(!canMoveUp)

                    Button(NSLocalizedString("Move Down", comment: ""), action: onMoveDown)
                        .buttonStyle(.bordered)
                        .disabled(!canMoveDown)

                    Spacer()

                    Button(NSLocalizedString("Delete Item", comment: ""), role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Ordering", comment: ""),
                    subtitle: NSLocalizedString("These actions only affect the currently selected item.", comment: "")
                )
            }
        }
        .onAppear {
            sanitizeCustomTradingTimes()
        }
        .onChange(of: item.sourceKind) { sourceKind in
            switch sourceKind {
            case .baiduGlobalIndex:
                item.area = item.area ?? .america
                applyFirstTemplate(for: sourceKind)
            case .sinaGlobalIndex:
                item.area = nil
                applyFirstTemplate(for: sourceKind)
            case .okxSpotMarket, .okxSpot:
                item.area = nil
                item.customOpenTime = nil
                item.customCloseTime = nil
                applyFirstTemplate(for: sourceKind)
            case .gateSpotMarket, .gateSpot:
                item.area = nil
                item.customOpenTime = nil
                item.customCloseTime = nil
                applyFirstTemplate(for: sourceKind)
            case .binanceSpot, .binancePerp:
                item.area = nil
                item.customOpenTime = nil
                item.customCloseTime = nil
                applyFirstTemplate(for: sourceKind)
            }
        }
        .onChange(of: item.symbol) { _ in
            sanitizeCustomTradingTimes()
        }
    }

    private var availableTemplates: [WatchItemTemplate] {
        WatchItemTemplateCatalog.templates(for: item.sourceKind)
    }

    private var customTemplateID: String { "__custom__" }

    private var selectedTemplateID: Binding<String> {
        Binding(
            get: {
                WatchItemTemplateCatalog.template(for: item.sourceKind, symbol: item.symbol, area: item.area)?.id ?? customTemplateID
            },
            set: { newValue in
                guard newValue != customTemplateID,
                      let template = availableTemplates.first(where: { $0.id == newValue })
                else {
                    return
                }
                applyTemplate(template)
            }
        )
    }

    private var miniWindowSelection: Binding<Bool> {
        Binding(
            get: { settingsStore.draftSettings.miniWindowItemIDs.contains(item.id) },
            set: { isSelected in
                settingsStore.setDraftMiniWindowItem(item.id, isSelected: isSelected)
            }
        )
    }

    private var customOpenTimeSelection: Binding<String?> {
        Binding(
            get: { pickerTimeValue(item.customOpenTime) },
            set: { item.customOpenTime = $0 }
        )
    }

    private var customCloseTimeSelection: Binding<String?> {
        Binding(
            get: { pickerTimeValue(item.customCloseTime) },
            set: { item.customCloseTime = $0 }
        )
    }

    private var defaultOpenTimeText: String {
        guard let schedule = IndexMarketSchedule.forSymbol(item.symbol) else {
            return "--:--"
        }
        return schedule.defaultOpenTimeText
    }

    private var defaultCloseTimeText: String {
        guard let schedule = IndexMarketSchedule.forSymbol(item.symbol) else {
            return "--:--"
        }
        return schedule.defaultCloseTimeText
    }

    private var openTimeOptions: [String] {
        Self.halfHourTimeOptions
    }

    private var closeTimeOptions: [String] {
        Self.halfHourTimeOptions
    }

    private var isCustomTradingTimeValid: Bool {
        guard let schedule = IndexMarketSchedule.forSymbol(item.symbol) else {
            return true
        }
        return schedule.isValid(
            customOpenTime: item.customOpenTime,
            customCloseTime: item.customCloseTime
        )
    }

    private func pickerTimeValue(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        return Self.halfHourTimeOptions.contains(rawValue) ? rawValue : nil
    }

    private func sanitizeCustomTradingTimes() {
        if item.customOpenTime != nil, pickerTimeValue(item.customOpenTime) == nil {
            item.customOpenTime = nil
        }

        if item.customCloseTime != nil, pickerTimeValue(item.customCloseTime) == nil {
            item.customCloseTime = nil
        }
    }

    private func applyFirstTemplate(for sourceKind: DataSourceKind) {
        guard let template = WatchItemTemplateCatalog.templates(for: sourceKind).first else { return }
        applyTemplate(template)
    }

    private func applyTemplate(_ template: WatchItemTemplate) {
        item.displayName = template.displayName
        item.symbol = template.symbol
        item.area = template.area
        item.customURL = template.defaultURL
    }

    private static let halfHourTimeOptions: [String] = (0..<48).map { index in
        String(format: "%02d:%02d", index / 2, index.isMultiple(of: 2) ? 0 : 30)
    }
}
