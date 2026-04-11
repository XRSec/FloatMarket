import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            if !isApplyingDraft {
                draftSettings = settings
            }
            schedulePersist()
        }
    }
    @Published var draftSettings: AppSettings

    private var isApplyingDraft = false
    private var persistTask: Task<Void, Never>?

    init() {
        let initial = SettingsRepository.load() ?? .default
        self.settings = initial
        self.draftSettings = initial
    }

    // MARK: - Draft lifecycle

    var hasUnsavedSettings: Bool {
        draftSettings != settings
    }

    func applyDraftSettings() {
        guard hasUnsavedSettings else { return }
        isApplyingDraft = true
        settings = draftSettings
        isApplyingDraft = false
    }

    func discardDraftSettings() {
        draftSettings = settings
    }

    // MARK: - Bindings

    func binding<Value>(for keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { self.settings[keyPath: keyPath] = $0 }
        )
    }

    func draftBinding<Value>(for keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.draftSettings[keyPath: keyPath] },
            set: { self.draftSettings[keyPath: keyPath] = $0 }
        )
    }

    func draftWatchItemBinding(at index: Int) -> Binding<WatchItem> {
        Binding(
            get: {
                guard self.draftSettings.watchlist.indices.contains(index) else {
                    // 返回第一个项目作为后备（如果列表不为空）
                    // 这种情况理论上不应该发生，因为视图层应该已经做了检查
                    return self.draftSettings.watchlist.first!
                }
                return self.draftSettings.watchlist[index]
            },
            set: {
                guard self.draftSettings.watchlist.indices.contains(index) else { return }
                self.draftSettings.watchlist[index] = $0
            }
        )
    }

    // MARK: - Watchlist editing

    func addWatchItem(from template: WatchItemTemplate) {
        draftSettings.watchlist.append(WatchItem(template: template))
    }

    @discardableResult
    func duplicateWatchItem(_ itemID: UUID) -> UUID? {
        guard let index = draftSettings.watchlist.firstIndex(where: { $0.id == itemID }) else { return nil }
        var duplicated = draftSettings.watchlist[index]
        duplicated.id = UUID()
        duplicated.displayName += NSLocalizedString(" Copy", comment: "")
        draftSettings.watchlist.insert(duplicated, at: index + 1)
        return duplicated.id
    }

    func resetDraftWatchlistToDefaults() {
        draftSettings.watchlist = WatchItem.defaults
        draftSettings.miniWindowItemIDs = []
    }

    func removeWatchItem(_ itemID: UUID) {
        draftSettings.watchlist.removeAll { $0.id == itemID }
        draftSettings.miniWindowItemIDs.removeAll { $0 == itemID }
    }

    func moveWatchItem(id: UUID, direction: Int) {
        guard let index = draftSettings.watchlist.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = index + direction
        guard draftSettings.watchlist.indices.contains(newIndex) else { return }
        let item = draftSettings.watchlist.remove(at: index)
        draftSettings.watchlist.insert(item, at: newIndex)
    }

    func clearDraftMiniWindowSelection() {
        draftSettings.miniWindowItemIDs = []
    }

    func setDraftMiniWindowItem(_ itemID: UUID, isSelected: Bool) {
        if isSelected {
            if !draftSettings.miniWindowItemIDs.contains(itemID) {
                draftSettings.miniWindowItemIDs.append(itemID)
            }
        } else {
            draftSettings.miniWindowItemIDs.removeAll { $0 == itemID }
        }
    }

    // MARK: - Persistence

    private func schedulePersist() {
        persistTask?.cancel()
        let snapshot = settings
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard self != nil, !Task.isCancelled else { return }
            do {
                try SettingsRepository.save(snapshot)
            } catch {
                // persistence failure is non-fatal; MarketStore logs errors
            }
        }
    }
}
