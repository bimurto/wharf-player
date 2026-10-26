import Foundation

public struct RecentItem: Codable, Equatable, Identifiable, Sendable {
    public var url: String
    public var title: String
    public var lastPlayed: Date
    public var position: TimeInterval
    public var duration: TimeInterval
    public var id: String { url }
}

/// Recently played media with playback progress, newest first, as JSON in `UserDefaults`.
public final class RecentsStore {
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    public init(defaults: UserDefaults = .standard, key: String = "sftp_history", limit: Int = 20) {
        self.defaults = defaults
        self.key = key
        self.limit = limit
    }

    public func all() -> [RecentItem] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentItem].self, from: data)) ?? []
    }

    /// Adds or updates the entry for `url` and moves it to the front. A password in the URL is dropped.
    public func record(url: String, title: String, position: TimeInterval, duration: TimeInterval, now: Date = Date()) {
        let clean = Self.withoutPassword(url)
        let item = RecentItem(url: clean, title: title, lastPlayed: now, position: position, duration: duration)
        var items = all().filter { $0.url != clean }
        items.insert(item, at: 0)
        write(Array(items.prefix(limit)))
    }

    /// Where to resume, or nil to start over: under 5 s in is not worth resuming, and within the last
    /// 10 s (or no known duration to compare against) counts as finished.
    public func resumePosition(for url: String) -> TimeInterval? {
        let clean = Self.withoutPassword(url)
        guard let item = all().first(where: { $0.url == clean }),
              item.position >= 5, item.duration > 0, item.position <= item.duration - 10 else { return nil }
        return item.position
    }

    public func clear() { defaults.removeObject(forKey: key) }

    /// `sftp://user:secret@host/x` becomes `sftp://user@host/x`.
    static func withoutPassword(_ url: String) -> String {
        url.replacingOccurrences(of: #"^(\w+://[^:@/]+):[^@/]*@"#, with: "$1@", options: .regularExpression)
    }

    private func write(_ items: [RecentItem]) {
        defaults.set(try? JSONEncoder().encode(items), forKey: key)
    }
}
