import AppKit
import Foundation
import SwiftUI

enum FloatMarketWindowProfile {
    case ticker
    case controlCenter
}

extension NSWindow {
    private static var floatMarketTickerLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
    }

    fileprivate static var floatMarketTickerCollectionBehavior: NSWindow.CollectionBehavior {
        // .canJoinAllSpaces + .fullScreenAuxiliary: 跨所有桌面显示，包括全屏 App 上层
        // 不加 .stationary: 允许窗口跟随 Space 切换移动（由 scheduleSpaceRecovery 在延迟后拉回）
        return [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    var alwaysOnTop: Bool {
        get { level == .floating }
        set { level = newValue ? .floating : .normal }
    }

    func applyFloatMarketStyle(
        profile: FloatMarketWindowProfile,
        keepFloating: Bool,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        identifier: String
    ) {
        self.identifier = NSUserInterfaceItemIdentifier(identifier)

        switch profile {
        case .ticker:
            styleMask.insert(.fullSizeContentView)
            titleVisibility = .hidden
            titlebarAppearsTransparent = true
            titlebarSeparatorStyle = .none
            toolbar = nil
            isMovableByWindowBackground = true
            isOpaque = false
            backgroundColor = .clear
            hasShadow = true
            collectionBehavior = Self.floatMarketTickerCollectionBehavior
            level = keepFloating ? Self.floatMarketTickerLevel : .normal

            standardWindowButton(.closeButton)?.isHidden = true
            standardWindowButton(.miniaturizeButton)?.isHidden = true
            standardWindowButton(.zoomButton)?.isHidden = true

            let lockedSize = NSSize(width: width, height: height)
            contentMinSize = lockedSize
            contentMaxSize = lockedSize
            setContentSize(NSSize(width: width, height: height))
            applyRoundedMask(cornerRadius: cornerRadius)

        case .controlCenter:
            level = .normal
            styleMask.remove(.fullSizeContentView)
            titleVisibility = .visible
            titlebarAppearsTransparent = false
            isMovableByWindowBackground = false

            standardWindowButton(.closeButton)?.isHidden = false
            standardWindowButton(.miniaturizeButton)?.isHidden = false
            standardWindowButton(.zoomButton)?.isHidden = false
        }
    }

    private func applyRoundedMask(cornerRadius: CGFloat) {
        let views = [contentView, contentView?.superview]
        for view in views.compactMap({ $0 }) {
            view.wantsLayer = true
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
        invalidateShadow()
    }
}

@MainActor
final class FloatingTickerWindowManager: NSObject, NSWindowDelegate {
    static let shared = FloatingTickerWindowManager()

    private weak var store: MarketStore?
    private weak var settingsStore: SettingsStore?
    private var window: FloatingTickerPanel?

    func show(store: MarketStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore

        if window == nil {
            window = makeWindow(store: store, settingsStore: settingsStore)
        } else {
            window?.contentView = NSHostingView(rootView: tickerRootView(store: store, settingsStore: settingsStore))
        }

        guard let window else { return }
        store.updateTickerWindowVisibility(true)
        window.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        store?.updateTickerWindowVisibility(false)
    }

    private func makeWindow(store: MarketStore, settingsStore: SettingsStore) -> FloatingTickerPanel {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let windowWidth = store.expandedFloatingWidth
        let windowHeight = store.expandedFloatingHeight
        // Default launch position: top-right, 60pt below the menu bar and 20pt from the right edge.
        let originX = visibleFrame.maxX - windowWidth - 20
        let originY = visibleFrame.maxY - windowHeight - 60
        let contentRect = NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight)

        let window = FloatingTickerPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier(SceneID.ticker)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.collectionBehavior = NSWindow.floatMarketTickerCollectionBehavior
        window.contentView = NSHostingView(rootView: tickerRootView(store: store, settingsStore: settingsStore))
        return window
    }

    private func tickerRootView(store: MarketStore, settingsStore: SettingsStore) -> some View {
        MainView()
            .background(AlwaysOnTop(profile: .ticker, windowID: SceneID.ticker))
            .environmentObject(store)
            .environmentObject(settingsStore)
    }
}

final class FloatingTickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
