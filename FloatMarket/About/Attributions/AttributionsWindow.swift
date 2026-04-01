import Cocoa
import SwiftUI

class AttributionsWindow: NSWindowController {
    
    static func show(settingsStore: SettingsStore) {
        AttributionsWindow(settingsStore: settingsStore).window?.makeKeyAndOrderFront(nil)
    }

    convenience init(settingsStore: SettingsStore) {
        
        let window = Self.makeWindow()
                
        window.backgroundColor = NSColor.controlBackgroundColor
                
        self.init(window: window)

        let contentView = AttributionsView()
            .frame(minWidth: 500, minHeight: 300)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(settingsStore)

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.title = NSLocalizedString("Attributions", comment: "")
        window.contentView = NSHostingView(rootView: contentView)
        window.alwaysOnTop = true
    }
    
    private static func makeWindow() -> NSWindow {
        let contentRect = NSRect(x: 0, y: 0, width: 500, height: 300)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .miniaturizable,
            .resizable,
            .closable,
            .fullSizeContentView
        ]
        return NSWindow(contentRect: contentRect,
                        styleMask: styleMask,
                        backing: .buffered,
                        defer: false)
    }
}
