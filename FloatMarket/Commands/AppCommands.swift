import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var store: MarketStore
    @ObservedObject var settingsStore: SettingsStore

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(NSLocalizedString("Settings", comment: "")) {
                AppActions.openSettings(store: store, settingsStore: settingsStore)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
