import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case dataSources
    case watchlist
    case appearance
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return NSLocalizedString("General", comment: "")
        case .dataSources:
            return NSLocalizedString("Data Sources", comment: "")
        case .watchlist:
            return NSLocalizedString("Watchlist", comment: "")
        case .appearance:
            return NSLocalizedString("Appearance", comment: "")
        case .logs:
            return NSLocalizedString("Logs", comment: "")
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .dataSources:
            return "point.3.connected.trianglepath.dotted"
        case .watchlist:
            return "list.bullet.rectangle.portrait"
        case .appearance:
            return "paintpalette"
        case .logs:
            return "terminal"
        }
    }

    var supportsEditing: Bool {
        self != .logs
    }
}
