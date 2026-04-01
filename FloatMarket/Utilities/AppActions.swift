import AppKit

@MainActor
enum AppActions {
    static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("float-market-settings-window")

    static func openSettings(store: MarketStore, settingsStore: SettingsStore) {
        if focusExistingSettingsWindow() {
            return
        }

        SettingsWindowController.shared.show(store: store, settingsStore: settingsStore)
    }

    static func switchLanguage(to code: String) {
        if code == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [url.path]
        task.launch()
        NSApp.terminate(nil)
    }

    @discardableResult
    static func focusExistingSettingsWindow() -> Bool {
        guard let existingWindow = NSApp.windows.first(where: { $0.identifier == settingsWindowIdentifier }) else {
            return false
        }

        if existingWindow.isMiniaturized {
            existingWindow.deminiaturize(nil)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        existingWindow.orderFrontRegardless()
        existingWindow.makeKeyAndOrderFront(nil)
        return true
    }
}
