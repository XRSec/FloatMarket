import SwiftUI

struct AppearancePane: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private var draftSettings: AppSettings {
        settingsStore.draftSettings
    }

    var body: some View {
        ControlCenterScrollPane {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    themeSection
                    miniWindowSection
                    snapSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 16) {
                    floatingWindowSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var themeSection: some View {
        GroupBox {
            Picker(NSLocalizedString("Theme", comment: ""), selection: settingsStore.draftBinding(for: \.floatingThemeMode)) {
                ForEach(FloatingThemeMode.allCases) { mode in
                    Text(localizedTheme(mode)).tag(mode)
                }
            }
        } label: {
            ControlCenterSectionLabel(
                title: NSLocalizedString("Theme", comment: ""),
                subtitle: nil
            )
        }
    }

    private var floatingWindowSection: some View {
        GroupBox {
            ControlCenterSliderRow(
                title: NSLocalizedString("Background Opacity", comment: ""),
                subtitle: NSLocalizedString("Lower values make the window more translucent; near zero keeps only the outline.", comment: ""),
                valueText: String(format: "%.0f%%", draftSettings.backgroundOpacity * 100),
                value: settingsStore.draftBinding(for: \.backgroundOpacity),
                range: 0.0...1.0,
                step: 0.01
            )

            Picker(NSLocalizedString("Background Style", comment: ""), selection: settingsStore.draftBinding(for: \.floatingBackgroundStyle)) {
                ForEach(FloatingBackgroundStyle.allCases) { style in
                    Text(localizedBackgroundStyle(style)).tag(style)
                }
            }

            Picker(NSLocalizedString("Text Palette", comment: ""), selection: settingsStore.draftBinding(for: \.floatingTextPalette)) {
                ForEach(FloatingTextPalette.allCases) { palette in
                    Text(localizedTextPalette(palette)).tag(palette)
                }
            }

            Picker(NSLocalizedString("Price Color Style", comment: ""), selection: settingsStore.draftBinding(for: \.priceColorStyle)) {
                ForEach(PriceColorStyle.allCases) { style in
                    Text(localizedPriceStyle(style)).tag(style)
                }
            }

            Divider()

            ControlCenterSliderRow(
                title: NSLocalizedString("Font Size", comment: ""),
                subtitle: NSLocalizedString("Controls quote rows and supporting labels in the floating window.", comment: ""),
                valueText: "\(Int(draftSettings.floatingFontSize)) pt",
                value: settingsStore.draftBinding(for: \.floatingFontSize),
                range: 11...80,
                step: 1
            )

            ControlCenterSliderRow(
                title: NSLocalizedString("Width", comment: ""),
                subtitle: NSLocalizedString("Floating window width.", comment: ""),
                valueText: "\(Int(draftSettings.floatingWidth))",
                value: settingsStore.draftBinding(for: \.floatingWidth),
                range: 160...800,
                step: 5
            )

            ControlCenterSliderRow(
                title: NSLocalizedString("Maximum Height", comment: ""),
                subtitle: NSLocalizedString("Height follows content until this limit, then the list begins to scroll.", comment: ""),
                valueText: "\(Int(draftSettings.floatingMaxHeight))",
                value: settingsStore.draftBinding(for: \.floatingMaxHeight),
                range: 200...1200,
                step: 5
            )
        } label: {
            ControlCenterSectionLabel(
                title: NSLocalizedString("Floating Window", comment: ""),
                subtitle: nil
            )
        }
    }

    private var miniWindowSection: some View {
        GroupBox {
            Picker(NSLocalizedString("Mini Window Display", comment: ""), selection: settingsStore.draftBinding(for: \.collapsedDisplayMode)) {
                ForEach(CollapsedDisplayMode.allCases) { mode in
                    Text(localizedCollapsedMode(mode)).tag(mode)
                }
            }

            ControlCenterSliderRow(
                title: NSLocalizedString("Background Opacity", comment: ""),
                subtitle: NSLocalizedString("Controls mini window translucency independently from the expanded floating window.", comment: ""),
                valueText: String(format: "%.0f%%", draftSettings.miniWindowBackgroundOpacity * 100),
                value: settingsStore.draftBinding(for: \.miniWindowBackgroundOpacity),
                range: 0.0...1.0,
                step: 0.01
            )

            ControlCenterSliderRow(
                title: NSLocalizedString("Font Size", comment: ""),
                subtitle: NSLocalizedString("Larger text also expands the mini window footprint.", comment: ""),
                valueText: "\(Int(draftSettings.miniWindowFontSize)) pt",
                value: settingsStore.draftBinding(for: \.miniWindowFontSize),
                range: 11...100,
                step: 1
            )
        } label: {
            ControlCenterSectionLabel(
                title: NSLocalizedString("Mini Window", comment: ""),
                subtitle: nil
            )
        }
    }

    private var snapSection: some View {
        GroupBox {
            Toggle(NSLocalizedString("Snap To Edge", comment: ""), isOn: settingsStore.draftBinding(for: \.snapToScreenEdge))

            if draftSettings.snapToScreenEdge {
                ControlCenterSliderRow(
                    title: NSLocalizedString("Snap Threshold", comment: ""),
                    subtitle: NSLocalizedString("Distance from edge that triggers snapping.", comment: ""),
                    valueText: "\(Int(draftSettings.snapThreshold))",
                    value: settingsStore.draftBinding(for: \.snapThreshold),
                    range: 40...800,
                    step: 10
                )

                ControlCenterSliderRow(
                    title: NSLocalizedString("Snap Margin", comment: ""),
                    subtitle: NSLocalizedString("Gap kept between the window and screen edge after snapping.", comment: ""),
                    valueText: "\(Int(draftSettings.snapMargin))",
                    value: settingsStore.draftBinding(for: \.snapMargin),
                    range: 0...40,
                    step: 1
                )
            }
        } label: {
            ControlCenterSectionLabel(
                title: NSLocalizedString("Snap To Edge", comment: ""),
                subtitle: nil
            )
        }
    }

    private func localizedTheme(_ mode: FloatingThemeMode) -> String {
        switch mode {
        case .system:
            return NSLocalizedString("Follow System", comment: "")
        case .dark:
            return NSLocalizedString("Dark", comment: "")
        case .light:
            return NSLocalizedString("Light", comment: "")
        }
    }

    private func localizedTextPalette(_ palette: FloatingTextPalette) -> String {
        switch palette {
        case .followTheme:
            return NSLocalizedString("Follow Theme", comment: "")
        case .ice:
            return NSLocalizedString("Ice", comment: "")
        case .amber:
            return NSLocalizedString("Amber", comment: "")
        case .mint:
            return NSLocalizedString("Mint", comment: "")
        case .rose:
            return NSLocalizedString("Rose", comment: "")
        case .lavender:
            return NSLocalizedString("Lavender", comment: "")
        case .gold:
            return NSLocalizedString("Gold", comment: "")
        case .sky:
            return NSLocalizedString("Sky", comment: "")
        case .coral:
            return NSLocalizedString("Coral", comment: "")
        }
    }

    private func localizedBackgroundStyle(_ style: FloatingBackgroundStyle) -> String {
        switch style {
        case .graphite:
            return NSLocalizedString("Graphite", comment: "")
        case .aurora:
            return NSLocalizedString("Aurora", comment: "")
        case .paper:
            return NSLocalizedString("Paper", comment: "")
        }
    }

    private func localizedPriceStyle(_ style: PriceColorStyle) -> String {
        switch style {
        case .redUpGreenDown:
            return NSLocalizedString("Red Up / Green Down", comment: "")
        case .greenUpRedDown:
            return NSLocalizedString("Green Up / Red Down", comment: "")
        }
    }

    private func localizedCollapsedMode(_ mode: CollapsedDisplayMode) -> String {
        switch mode {
        case .priceOnly:
            return NSLocalizedString("Price Only", comment: "")
        case .symbolAndPrice:
            return NSLocalizedString("Symbol + Price", comment: "")
        }
    }
}
