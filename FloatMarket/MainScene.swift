import SwiftUI

enum SceneID {
    static let ticker = "float-market-ticker"
}

struct MainScene: Scene {
    @ObservedObject var store: MarketStore
    @ObservedObject var settingsStore: SettingsStore

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopup()
                .environmentObject(store)
                .environmentObject(settingsStore)
        } label: {
            MenuBarAppIcon()
                .accessibilityLabel(store.menuBarStatusText)
        }
        .commands {
            AboutCommand(settingsStore: settingsStore)
            AppCommands(store: store, settingsStore: settingsStore)
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct MenuBarAppIcon: View {
    var body: some View {
        if let iconImage = menuBarImage {
            Image(nsImage: iconImage)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
    }

    private var menuBarImage: NSImage? {
        guard let image = NSApp.applicationIconImage.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
