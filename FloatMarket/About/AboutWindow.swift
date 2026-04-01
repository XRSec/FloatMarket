import AppKit
import SwiftUI

class AboutWindow: NSWindowController {
    
    static func show(settingsStore: SettingsStore) {
        AboutWindow(settingsStore: settingsStore).window?.makeKeyAndOrderFront(nil)
    }

    convenience init(settingsStore: SettingsStore) {
        
        let window = Self.makeWindow()
                
        window.backgroundColor = NSColor.controlBackgroundColor
                
        self.init(window: window)

        let contentView = makeAboutView(settingsStore: settingsStore)
            
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.title = NSLocalizedString("About FloatMarket", comment: "")
        window.contentView = NSHostingView(rootView: contentView)
        window.alwaysOnTop = true
    }
    
    private static func makeWindow() -> NSWindow {
        let contentRect = NSRect(x: 0, y: 0, width: 560, height: 330)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .fullSizeContentView
        ]
        return NSWindow(contentRect: contentRect,
                        styleMask: styleMask,
                        backing: .buffered,
                        defer: false)
    }

    private func makeAboutView(settingsStore: SettingsStore) -> some View {
        AboutView(
            icon: NSApp.applicationIconImage ?? NSImage(),
            name: NSLocalizedString("FloatMarket", comment: ""),
            version: Bundle.main.version,
            build: Bundle.main.buildVersion,
            copyright: Bundle.main.copyright,
            developerName: "XRSec")
            .frame(width: 560, height: 330)
            .environmentObject(settingsStore)
    }
}
