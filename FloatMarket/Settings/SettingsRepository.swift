import Foundation

enum SettingsRepository {
    static func load() -> AppSettings? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    static func save(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: settingsURL, options: [.atomic])
    }

    private static let settingsURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("FloatMarket", isDirectory: true)
            .appendingPathComponent("settings.json")
    }()
}
