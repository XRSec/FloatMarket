import AppKit
import SwiftUI

struct SettingsWindow: View {
    @EnvironmentObject private var store: MarketStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selection: SettingsSection = .general
    @State private var pendingSelection: SettingsSection?
    @State private var showUnsavedAlert = false
    @State private var window: NSWindow?

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: sidebarSelection)
                .frame(width: 200)

            Divider()

            ZStack(alignment: .bottom) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom) {
                        if selection.supportsEditing && settingsStore.hasUnsavedSettings {
                            settingsActionBar
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WindowReflection(window: $window))
        .frame(minWidth: 980, minHeight: 720)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(.hidden, for: .windowToolbar)
        .preferredColorScheme(store.preferredFloatingColorScheme)
        .task(id: window?.windowNumber ?? -1) {
            applyWindowChrome()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow,
                  closingWindow == window
            else {
                return
            }
            NSApp.setActivationPolicy(.accessory)
        }
        .alert(
            NSLocalizedString("Save Before Leaving?", comment: ""),
            isPresented: $showUnsavedAlert,
            actions: {
                Button(NSLocalizedString("Save & Continue", comment: "")) {
                    settingsStore.applyDraftSettings()
                    commitPendingSelection()
                }
                Button(NSLocalizedString("Discard", comment: ""), role: .destructive) {
                    settingsStore.discardDraftSettings()
                    commitPendingSelection()
                }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                    pendingSelection = nil
                }
            },
            message: {
                Text(NSLocalizedString("This page has unsaved changes. Save them before leaving?", comment: ""))
            }
        )
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .dataSources:
            DataSourcesPane()
        case .watchlist:
            WatchlistPane()
        case .appearance:
            AppearancePane()
        case .logs:
            LogsPane()
        }
    }

    private var settingsActionBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button(NSLocalizedString("Discard", comment: "")) {
                settingsStore.discardDraftSettings()
            }
            .buttonStyle(.bordered)

            Button(NSLocalizedString("Save", comment: "")) {
                settingsStore.applyDraftSettings()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var sidebarSelection: Binding<SettingsSection> {
        Binding(
            get: { selection },
            set: { newSelection in
                guard newSelection != selection else { return }

                if selection.supportsEditing && settingsStore.hasUnsavedSettings {
                    pendingSelection = newSelection
                    showUnsavedAlert = true
                } else {
                    selection = newSelection
                }
            }
        )
    }

    private func commitPendingSelection() {
        guard let pendingSelection else { return }
        selection = pendingSelection
        self.pendingSelection = nil
    }

    private func applyWindowChrome() {
        guard let window else { return }
        window.identifier = AppActions.settingsWindowIdentifier
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(store: MarketStore, settingsStore: SettingsStore) {
        if window == nil {
            window = makeWindow(store: store, settingsStore: settingsStore)
        }

        guard let window else { return }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(store: MarketStore, settingsStore: SettingsStore) -> NSWindow {
        let contentRect = NSRect(x: 0, y: 0, width: 1100, height: 760)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.identifier = AppActions.settingsWindowIdentifier
        window.isReleasedWhenClosed = false
        window.title = NSLocalizedString("Settings", comment: "")
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsWindow()
                .environmentObject(store)
                .environmentObject(settingsStore)
        )
        return window
    }
}
