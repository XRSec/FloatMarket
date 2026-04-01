import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.colorScheme) private var systemColorScheme

    private var allIndexQuotes: [QuoteSnapshot] {
        store.orderedQuotes.filter { $0.item.sourceKind.instrumentKind == .globalIndex }
    }

    private var highlightedIndexQuotes: [QuoteSnapshot] {
        allIndexQuotes.filter { snapshot in
            let timing = store.timing(for: snapshot.item)
            return timing.isTrading || timing.isOpeningWithinHour || timing.isRecentlyClosedWithinHour
        }
    }

    private var hiddenIndexQuotes: [QuoteSnapshot] {
        store.showsAllGlobalIndices ? [] : allIndexQuotes.filter { snapshot in
            let timing = store.timing(for: snapshot.item)
            return !(timing.isTrading || timing.isOpeningWithinHour || timing.isRecentlyClosedWithinHour)
        }
    }

    private var displayedIndexQuotes: [QuoteSnapshot] {
        store.showsAllGlobalIndices ? allIndexQuotes : highlightedIndexQuotes
    }

    private var shouldShowIndexToggle: Bool {
        store.showsAllGlobalIndices || !hiddenIndexQuotes.isEmpty
    }

    private var cryptoQuotes: [QuoteSnapshot] {
        store.orderedQuotes.filter { $0.item.sourceKind.instrumentKind != .globalIndex }
    }

    private var spotQuotes: [QuoteSnapshot] {
        cryptoQuotes.filter { $0.item.sourceKind.instrumentKind == .spot }
    }

    private var perpetualQuotes: [QuoteSnapshot] {
        cryptoQuotes.filter { $0.item.sourceKind.instrumentKind == .perpetual }
    }

    private var resolvedFloatingColorScheme: ColorScheme {
        store.preferredFloatingColorScheme ?? systemColorScheme
    }

    private var floatingColors: [Color] {
        settingsStore.settings.floatingBackgroundStyle.gradientColors(
            for: resolvedFloatingColorScheme,
            isCollapsed: store.isFloatingCollapsed
        )
    }

    private var isDarkAppearance: Bool {
        resolvedFloatingColorScheme == .dark
    }

    private var primaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.primaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var secondaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.secondaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var tertiaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.tertiaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var cardFillColor: Color {
        isDarkAppearance ? Color.white.opacity(0.11) : Color.white.opacity(0.84)
    }

    private var cardStrokeColor: Color {
        return isDarkAppearance ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var iconFillColor: Color {
        isDarkAppearance ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var peekOutlineColor: Color {
        isDarkAppearance ? Color.white.opacity(0.28) : Color.black.opacity(0.18)
    }

    private var windowCornerRadius: CGFloat {
        store.isFloatingCollapsed ? 18 : 24
    }

    private var windowOutlineColor: Color {
        if store.isFloatingPeekThroughMode {
            return peekOutlineColor
        }

        return isDarkAppearance ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
    }

    private var floatingWindowWidth: CGFloat {
        store.isFloatingCollapsed ? store.collapsedFloatingWidth : store.expandedFloatingWidth
    }

    private var floatingWindowHeight: CGFloat {
        store.isFloatingCollapsed ? store.collapsedFloatingHeight : store.expandedFloatingHeight
    }

    private var currentBackgroundOpacity: Double {
        store.isFloatingCollapsed
            ? settingsStore.settings.miniWindowBackgroundOpacity
            : settingsStore.settings.backgroundOpacity
    }

    private var floatingBaseFontSize: CGFloat {
        CGFloat(settingsStore.settings.floatingFontSize)
    }

    private var floatingSectionFontSize: CGFloat {
        max(floatingBaseFontSize - 2, 11)
    }

    private var floatingMinorFontSize: CGFloat {
        max(floatingBaseFontSize - 3, 10)
    }

    private var floatingFooterFontSize: CGFloat {
        max(floatingBaseFontSize - 1, 11)
    }

    private var floatingEmptyTitleFontSize: CGFloat {
        max(floatingBaseFontSize + 4, 18)
    }

    private var floatingEmptyBodyFontSize: CGFloat {
        max(floatingBaseFontSize - 1, 12)
    }

    private var expandedGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
            count: store.expandedFloatingColumnCount
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: floatingColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(currentBackgroundOpacity)

            Group {
                if store.isFloatingCollapsed {
                    collapsedContent
                } else {
                    expandedContent
                }
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: windowCornerRadius,
                style: .continuous
            )
            .stroke(windowOutlineColor, lineWidth: 1)
        }
        .frame(width: floatingWindowWidth, height: floatingWindowHeight)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .windowToolbar)
        .preferredColorScheme(store.preferredFloatingColorScheme)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                floatingOverlayControls
                Spacer()
            }

            if store.orderedQuotes.isEmpty {
                Spacer(minLength: 0)
                emptyState
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    expandedSections
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            footer
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var expandedSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !allIndexQuotes.isEmpty {
                section(
                    title: NSLocalizedString("Global Indices", comment: ""),
                    items: displayedIndexQuotes,
                    trailing: shouldShowIndexToggle ? AnyView(
                        Button(store.showsAllGlobalIndices ? NSLocalizedString("Collapse", comment: "") : NSLocalizedString("Expand", comment: "")) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.setShowsAllGlobalIndices(!store.showsAllGlobalIndices)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: floatingMinorFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(tertiaryTextColor)
                    ) : nil
                )
            }

            if !spotQuotes.isEmpty {
                section(
                    title: NSLocalizedString("Spot", comment: ""),
                    items: spotQuotes,
                    trailing: nil
                )
            }

            if !perpetualQuotes.isEmpty {
                section(
                    title: NSLocalizedString("Perpetuals", comment: ""),
                    items: perpetualQuotes,
                    trailing: nil
                )
            }
        }
    }

    @ViewBuilder
    private func section(title: String, items: [QuoteSnapshot], trailing: AnyView?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: floatingSectionFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
                Spacer()
                trailing
            }

            LazyVGrid(columns: expandedGridColumns, alignment: .leading, spacing: 8) {
                ForEach(items) { snapshot in
                    QuoteRow(snapshot: snapshot)
                }
            }
        }
    }

    private var floatingOverlayControls: some View {
        HStack(spacing: 5) {
            headerButton(systemImage: "xmark", fillColor: Color(red: 1.0, green: 0.37, blue: 0.34), hoverIconColor: Color.black.opacity(0.72)) {
                closeFloatingWindow()
            }

            headerButton(systemImage: "minus", fillColor: Color(red: 1.0, green: 0.74, blue: 0.18), hoverIconColor: Color.black.opacity(0.68)) {
                store.setFloatingCollapsed(true)
            }

            settingsAccessButton
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(primaryTextColor.opacity(0.92))
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(iconFillColor.opacity(1.2))
                )

            VStack(spacing: 8) {
                Text(NSLocalizedString("Waiting For First Sync", comment: ""))
                    .font(.system(size: floatingEmptyTitleFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                Text(NSLocalizedString("Configured market feeds are ready. Quotes will appear here after the first sync.", comment: ""))
                    .font(.system(size: floatingEmptyBodyFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button(NSLocalizedString("Refresh Now", comment: "")) {
                    Task {
                        await store.refreshNow(reason: "empty-state")
                    }
                }
                .buttonStyle(FloatingActionButtonStyle())

                settingsTextButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFillColor)
        )
    }

    private var footer: some View {
        HStack {
            Text(store.footerStatusText)
                .font(.system(size: floatingFooterFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryTextColor)

            Spacer()

            Text("FloatMarket")
                .font(.system(size: floatingFooterFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(tertiaryTextColor)
        }
        .padding(.top, 2)
    }

    private var collapsedContent: some View {
        let metrics = store.miniWindowLayoutMetrics

        return Group {
            if !store.miniWindowSnapshots.isEmpty {
                VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                    ForEach(store.miniWindowSnapshots) { snapshot in
                        CollapsedQuoteRow(snapshot: snapshot)
                    }
                }
                .padding(.horizontal, metrics.outerHorizontalPadding)
                .padding(.vertical, metrics.outerVerticalPadding)
            } else {
                Text("--")
                    .font(.system(size: metrics.priceFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, metrics.outerHorizontalPadding)
                    .padding(.vertical, metrics.outerVerticalPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            store.setFloatingCollapsed(false)
        }
    }

    private func headerButton(
        systemImage: String,
        fillColor: Color,
        hoverIconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        FloatingWindowTrafficButton(
            systemImage: systemImage,
            fillColor: fillColor,
            hoverIconColor: hoverIconColor,
            action: action
        )
    }

    private func closeFloatingWindow() {
        store.hideTickerWindow()
    }

    private var settingsAccessButton: some View {
        headerButton(systemImage: "slider.horizontal.3", fillColor: iconFillColor, hoverIconColor: primaryTextColor) {
            AppActions.openSettings(store: store, settingsStore: settingsStore)
        }
    }

    private var settingsTextButton: some View {
        Button(NSLocalizedString("Settings", comment: "")) {
            AppActions.openSettings(store: store, settingsStore: settingsStore)
        }
        .buttonStyle(.plain)
        .foregroundStyle(secondaryTextColor)
    }
}

struct QuoteRow: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: QuoteSnapshot

    private var fontSize: CGFloat { CGFloat(settingsStore.settings.floatingFontSize) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    MarketIconView(snapshot: snapshot)

                    Text(snapshot.item.displayName)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.priceText)
                    .font(.system(size: fontSize + 3, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                HStack(spacing: 8) {
                    Text(snapshot.changeText)
                    Text(snapshot.percentText)
                }
                .font(.system(size: max(fontSize - 2, 10), weight: .semibold, design: .rounded))
                .foregroundStyle(store.quoteChangeColor(for: snapshot, colorScheme: colorScheme))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture(count: 2) {
            if let urlString = snapshot.item.resolvedQuickLinkURL,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private var isDarkAppearance: Bool {
        (store.preferredFloatingColorScheme ?? colorScheme) == .dark
    }

    private var resolvedFloatingColorScheme: ColorScheme {
        store.preferredFloatingColorScheme ?? colorScheme
    }

    private var primaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.primaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var cardFillColor: Color {
        guard snapshot.item.sourceKind.instrumentKind == .globalIndex else {
            return isDarkAppearance ? Color.white.opacity(0.10) : Color.white.opacity(0.82)
        }
        let timing = store.timing(for: snapshot.item)
        switch timing.phase {
        case .trading:
            return isDarkAppearance ? Color.green.opacity(0.10) : Color.green.opacity(0.06)
        case .openingSoon:
            return isDarkAppearance ? Color.yellow.opacity(0.10) : Color.yellow.opacity(0.07)
        case .recentlyClosed:
            return isDarkAppearance ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        case .waiting, .closed:
            return isDarkAppearance ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        }
    }

    private var cardStrokeColor: Color {
        return isDarkAppearance ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var borderColor: Color {
        guard snapshot.item.sourceKind.instrumentKind == .globalIndex else {
            return cardStrokeColor
        }

        let timing = store.timing(for: snapshot.item)
        switch timing.phase {
        case .trading:
            return Color.green.opacity(0.65)
        case .openingSoon:
            return Color.yellow.opacity(0.7)
        case .recentlyClosed:
            return Color.gray.opacity(0.7)
        case .waiting, .closed:
            return cardStrokeColor
        }
    }
}

private struct CollapsedQuoteRow: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: QuoteSnapshot

    var body: some View {
        let metrics = store.miniWindowLayoutMetrics

        HStack(spacing: metrics.columnSpacing) {
            if settingsStore.settings.collapsedDisplayMode == .symbolAndPrice {
                HStack(spacing: 6) {
                    MarketIconView(snapshot: snapshot)
                    Text(store.miniWindowCompactLabel(for: snapshot))
                        .font(.system(size: metrics.labelFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text(snapshot.priceText)
                .font(.system(size: metrics.priceFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: metrics.rowHeight, alignment: .leading)
    }

    private var secondaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.secondaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var primaryTextColor: Color {
        settingsStore.settings.floatingTextPalette.primaryTextColor(for: resolvedFloatingColorScheme)
    }

    private var resolvedFloatingColorScheme: ColorScheme {
        store.preferredFloatingColorScheme ?? colorScheme
    }
}

private struct MarketIconView: View {
    let snapshot: QuoteSnapshot

    var body: some View {
        if let assetName = assetName, let image = NSImage(named: assetName) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            fallbackBadge
        }
    }

    private var assetName: String? {
        switch snapshot.item.sourceKind {
        case .baiduGlobalIndex, .sinaGlobalIndex:
            switch snapshot.item.symbol.uppercased() {
            case "IXIC":
                return "IXICIcon"
            case "FTSE":
                return "FTSEIcon"
            case "NK225":
                return "NK225Icon"
            case "DAX":
                return "DAXIcon"
            default:
                return nil
            }
        case .okxSpotMarket, .okxSpot:
            return "OKXIcon"
        case .gateSpotMarket, .gateSpot:
            return "GateIcon"
        case .binanceSpot, .binancePerp:
            return "BinanceIcon"
        }
    }

    private var fallbackBadge: some View {
        Text(fallbackText)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(fallbackBackground))
    }

    private var fallbackText: String {
        switch snapshot.item.sourceKind.instrumentKind {
        case .globalIndex:
            return "B"
        case .spot, .perpetual:
            switch snapshot.item.sourceKind {
            case .okxSpotMarket, .okxSpot:
                return "O"
            case .gateSpotMarket, .gateSpot:
                return "G"
            case .binanceSpot, .binancePerp:
                return "N"
            case .baiduGlobalIndex, .sinaGlobalIndex:
                return "B"
            }
        }
    }

    private var fallbackBackground: Color {
        switch snapshot.item.sourceKind {
        case .baiduGlobalIndex:
            return Color(red: 0.28, green: 0.50, blue: 0.92)
        case .sinaGlobalIndex:
            return Color(red: 0.93, green: 0.33, blue: 0.24)
        case .okxSpotMarket, .okxSpot:
            return Color(red: 0.13, green: 0.14, blue: 0.18)
        case .gateSpotMarket, .gateSpot:
            return Color(red: 0.14, green: 0.63, blue: 0.95)
        case .binanceSpot, .binancePerp:
            return Color(red: 0.93, green: 0.72, blue: 0.16)
        }
    }
}

private struct FloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color(red: 0.24, green: 0.51, blue: 0.96))
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
    }
}

private struct FloatingWindowTrafficButton: View {
    let systemImage: String
    let fillColor: Color
    let hoverIconColor: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fillColor)

                if isHovering {
                    Image(systemName: systemImage)
                        .font(.system(size: 6.5, weight: .black))
                        .foregroundStyle(hoverIconColor)
                }
            }
            .frame(width: 11, height: 11)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
