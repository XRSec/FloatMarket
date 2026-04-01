import SwiftUI

struct AboutCommand: Commands {
    @ObservedObject var settingsStore: SettingsStore

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button {
                AboutWindow.show(settingsStore: settingsStore)
            } label: {
                Text(String(format: NSLocalizedString("About FloatMarket", comment: ""), Bundle.main.name))
            }
        }
    }
}
