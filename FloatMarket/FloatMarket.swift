import AppKit
import SwiftUI

@main
struct FloatMarket: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var store: MarketStore

    init() {
        SingleInstanceGuard.exitIfNeeded()
        NSApplication.shared.setActivationPolicy(.accessory)
        let settings = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: MarketStore(settingsStore: settings))
    }

    var body: some Scene {
        MainScene(store: store, settingsStore: settingsStore)
    }
}

private enum SingleInstanceGuard {
    static func exitIfNeeded() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existingApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

        guard let existingApp = existingApps.first else { return }

        existingApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        exit(EXIT_SUCCESS)
    }
}
