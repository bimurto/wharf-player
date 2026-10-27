import Foundation

/// One-time copy of settings from the unbundled `swift run` defaults domain (`SFTPPlayer`) into the
/// bundled app's own domain. The legacy domain is only read, never changed. No values are logged.
public enum LegacyMigration {
    public static let legacyDomain = "SFTPPlayer"
    public static let flagKey = "migrated_from_SFTPPlayer_v1"
    static let recentsKey = "sftp_history"
    static let copiedKeys = ["sftp_profiles", "sidebar_width", "subtitle_scale", "subtitle_position"]

    /// Returns true when a migration ran. Does nothing when running in the legacy domain itself,
    /// when there is no legacy data, or when it already ran.
    @discardableResult
    public static func migrate(
        legacy: [String: Any]?,
        into defaults: UserDefaults,
        destinationDomain: String,
        legacyDomain: String = LegacyMigration.legacyDomain,
        flagKey: String = LegacyMigration.flagKey
    ) -> Bool {
        guard destinationDomain != legacyDomain, let legacy,
              !defaults.bool(forKey: flagKey) else { return false }

        for key in copiedKeys where defaults.object(forKey: key) == nil {
            if let value = legacy[key] { defaults.set(value, forKey: key) }
        }
        if let legacyData = legacy[recentsKey] as? Data,
           let legacyItems = try? JSONDecoder().decode([RecentItem].self, from: legacyData) {
            let current = defaults.data(forKey: recentsKey)
                .flatMap { try? JSONDecoder().decode([RecentItem].self, from: $0) } ?? []
            let items = RecentsStore.combined(current, legacyItems)
            if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: recentsKey) }
        }
        defaults.set(true, forKey: flagKey)
        return true
    }

    /// App entry point: reads the real legacy domain and migrates into `.standard`.
    public static func runAtStartup() {
        let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        migrate(legacy: UserDefaults.standard.persistentDomain(forName: legacyDomain),
                into: .standard, destinationDomain: domain)
    }
}
