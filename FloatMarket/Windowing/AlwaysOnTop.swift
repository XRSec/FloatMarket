import SwiftUI

struct AlwaysOnTop: View {
    let profile: FloatMarketWindowProfile
    let windowID: String

    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var window: NSWindow?
    @State private var snapWorkItem: DispatchWorkItem?
    @State private var spaceRecoveryTask: Task<Void, Never>?

    var body: some View {
        WindowReflection(window: $window)
            .task(id: window?.windowNumber ?? -1) {
                applyStyle()
            }
            .onAppear {
                if profile == .ticker {
                    store.updateTickerWindowVisibility(true)
                }
                applyStyle()
            }
            .onDisappear {
                if profile == .ticker {
                    store.updateTickerWindowVisibility(false)
                }
                spaceRecoveryTask?.cancel()
            }
            .onChange(of: settingsStore.settings.keepWindowFloating) { _ in
                applyStyle()
            }
            .onChange(of: store.expandedFloatingWidth) { _ in
                applyStyle()
            }
            .onChange(of: store.expandedFloatingHeight) { _ in
                applyStyle()
            }
            .onChange(of: store.miniWindowLayoutMetrics) { _ in
                applyStyle()
            }
            .onChange(of: store.isFloatingCollapsed) { _ in
                applyStyle()
            }
            .onChange(of: settingsStore.settings.snapToScreenEdge) { _ in
                scheduleSnap()
            }
            .onChange(of: settingsStore.settings.snapThreshold) { _ in
                scheduleSnap()
            }
            .onChange(of: settingsStore.settings.snapMargin) { _ in
                scheduleSnap()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { notification in
                guard profile == .ticker,
                      let movedWindow = notification.object as? NSWindow,
                      movedWindow == window
                else {
                    return
                }
                scheduleSnap()
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
                guard profile == .ticker,
                      let window
                else {
                    return
                }
                scheduleSpaceRecovery(for: window)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                guard profile == .ticker,
                      let closedWindow = notification.object as? NSWindow,
                      closedWindow == window
                else {
                    return
                }
                spaceRecoveryTask?.cancel()
                store.updateTickerWindowVisibility(false)
            }
    }

    private func applyStyle() {
        guard let window else { return }
        window.applyFloatMarketStyle(
            profile: profile,
            keepFloating: settingsStore.settings.keepWindowFloating,
            width: store.isFloatingCollapsed ? store.collapsedFloatingWidth : store.expandedFloatingWidth,
            height: store.isFloatingCollapsed ? store.collapsedFloatingHeight : store.expandedFloatingHeight,
            cornerRadius: store.isFloatingCollapsed ? 18 : 24,
            identifier: windowID
        )
        scheduleSnap()
    }

    private func scheduleSpaceRecovery(for window: NSWindow) {
        guard profile == .ticker else { return }
        let targetWindowNumber = window.windowNumber

        spaceRecoveryTask?.cancel()
        spaceRecoveryTask = Task { @MainActor in
            // 延迟 1 秒，让用户完成桌面切换后再跟随
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled,
                  let currentWindow = self.window,
                  currentWindow.windowNumber == targetWindowNumber
            else {
                return
            }

            // 将窗口拉到当前激活的 Space 并置于最前
            applyStyle()
            currentWindow.orderFrontRegardless()
        }
    }

    private func scheduleSnap() {
        guard profile == .ticker else { return }
        snapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [window] in
            guard let window else { return }
            snap(window: window)
        }

        snapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func snap(window: NSWindow) {
        guard settingsStore.settings.snapToScreenEdge else { return }
        guard let screenFrame = window.screen?.visibleFrame else { return }

        let threshold = CGFloat(settingsStore.settings.snapThreshold)
        let margin = CGFloat(settingsStore.settings.snapMargin)
        var frame = window.frame
        var changed = false
        var dockSide: FloatingDockSide = .none

        if abs(frame.minX - screenFrame.minX) <= threshold {
            frame.origin.x = screenFrame.minX + margin
            changed = true
            dockSide = .left
        } else if abs(frame.maxX - screenFrame.maxX) <= threshold {
            frame.origin.x = screenFrame.maxX - frame.width - margin
            changed = true
            dockSide = .right
        }

        store.updateFloatingWindowState(isCollapsed: store.isFloatingCollapsed, dockSide: dockSide)

        if changed {
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
