import SwiftUI

struct MenuBarPopup: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 6) {
            settingsMenuItem
            menuButton(NSLocalizedString("Show Floating Window", comment: ""), systemImage: "rectangle.on.rectangle") {
                store.showTickerWindow()
            }

            Divider()

            menuButton(NSLocalizedString("Quit FloatMarket", comment: ""), systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 240)
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var settingsMenuItem: some View {
        menuButton(NSLocalizedString("Settings", comment: ""), systemImage: "slider.horizontal.3") {
            AppActions.openSettings(store: store, settingsStore: settingsStore)
        }
    }
}
