import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ControlCenterScrollPane {
            GroupBox {
                Toggle(NSLocalizedString("Auto Refresh", comment: ""), isOn: settingsStore.draftBinding(for: \.autoRefresh))
                Toggle(NSLocalizedString("Keep Floating", comment: ""), isOn: settingsStore.draftBinding(for: \.keepWindowFloating))

                Text(NSLocalizedString("Auto refresh only polls indices and HTTP snapshot feeds. WebSocket feeds only resync after disconnects or reconnects.", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ControlCenterSliderRow(
                    title: NSLocalizedString("Refresh Interval", comment: ""),
                    subtitle: NSLocalizedString("Choose how often polled sources are checked. This does not force timer-based refreshes on WebSocket feeds.", comment: ""),
                    valueText: "\(Int(settingsStore.draftSettings.refreshInterval)) s",
                    value: settingsStore.draftBinding(for: \.refreshInterval),
                    range: 3...60,
                    step: 1
                )

            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Runtime", comment: ""),
                    subtitle: NSLocalizedString("Polling controls live here. WebSocket feeds recover with snapshot syncs after disconnects and reconnects.", comment: "")
                )
            }

            GroupBox {
                let selectedCode = Binding<String>(
                    get: { AppLocalizationCatalog.currentSelectedCode },
                    set: { code in
                        guard code != AppLocalizationCatalog.currentSelectedCode else { return }
                        AppActions.switchLanguage(to: code)
                    }
                )
                Picker(NSLocalizedString("Language", comment: ""), selection: selectedCode) {
                    Text(NSLocalizedString("Follow System", comment: "")).tag("auto")
                    ForEach(AppLocalizationCatalog.availableOptions) { option in
                        Text(option.displayName).tag(option.code)
                    }
                }
                Text(NSLocalizedString("Language change takes effect after relaunch.", comment: ""))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Language & Display", comment: ""),
                    subtitle: NSLocalizedString("Settings that affect global text and base presentation.", comment: "")
                )
            }

            GroupBox {
                Toggle(NSLocalizedString("Enable Proxy", comment: ""), isOn: settingsStore.draftBinding(for: \.proxyEnabled))

                HStack(alignment: .top, spacing: 12) {
                    Picker(NSLocalizedString("Proxy Type", comment: ""), selection: settingsStore.draftBinding(for: \.proxyType)) {
                        ForEach(ProxyType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .frame(maxWidth: 180)

                    TextField(NSLocalizedString("Proxy Host", comment: ""), text: settingsStore.draftBinding(for: \.proxyHost))
                        .textFieldStyle(.roundedBorder)

                    TextField(NSLocalizedString("Port", comment: ""), text: proxyPortBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                
                TextField(NSLocalizedString("Test URL", comment: ""), text: settingsStore.draftBinding(for: \.proxyTestURL))
                    .textFieldStyle(.roundedBorder)
                    

                HStack(spacing: 10) {
                    Button(store.isTestingProxy ? NSLocalizedString("Testing...", comment: "") : NSLocalizedString("Test Proxy", comment: "")) {
                        Task {
                            await store.testProxy()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isTestingProxy)

                    if let proxyTestMessage = store.proxyTestMessage {
                        Text(proxyTestMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Network Proxy", comment: ""),
                    subtitle: NSLocalizedString("Keep the most useful proxy knobs and connectivity checks.", comment: "")
                )
            }

            GroupBox {
                HStack(spacing: 12) {
                    Button(NSLocalizedString("Refresh Now", comment: "")) {
                        Task {
                            await store.refreshNow(reason: "control-center-general")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(
                        store.isTickerWindowVisible
                        ? NSLocalizedString("Hide Floating", comment: "")
                        : NSLocalizedString("Show Floating", comment: "")
                    ) {
                        if store.isTickerWindowVisible {
                            store.hideTickerWindow()
                        } else {
                            store.showTickerWindow()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Quick Actions", comment: ""),
                    subtitle: NSLocalizedString("Refresh Now only polls indices and HTTP snapshot feeds.", comment: "")
                )
            }
        }
    }

    private var proxyPortBinding: Binding<String> {
        Binding(
            get: { String(settingsStore.draftSettings.proxyPort) },
            set: { newValue in
                let digitsOnly = newValue.filter(\.isNumber)
                if let port = Int(digitsOnly) {
                    settingsStore.draftSettings.proxyPort = port
                } else if digitsOnly.isEmpty {
                    settingsStore.draftSettings.proxyPort = 0
                }
            }
        )
    }
}

struct ControlCenterScrollPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.top, 26)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .groupBoxStyle(ControlCenterGroupBoxStyle())
    }
}

struct ControlCenterSectionLabel: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ControlCenterGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
            configuration.content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct ControlCenterSliderRow: View {
    let title: String
    let subtitle: String?
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(valueText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
        }
    }
}

struct ControlCenterEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
    }
}
