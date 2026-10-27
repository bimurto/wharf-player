import Foundation

public struct RecentItem: Codable, Equatable, Identifiable, Sendable {
    public var url: String
    public var title: String
    public var lastPlayed: Date
    public var position: TimeInterval
    public var duration: TimeInterval
    public var id: String { url }

    /// Watched fraction from 0 to 1; 0 when the duration is unknown.
    public var fraction: Double { duration > 0 ? min(max(position / duration, 0), 1) : 0 }

    /// Within the last 10 s of the file; the same cut-off `RecentsStore.resumePosition` uses.
    public var isFinished: Bool { duration > 0 && position > duration - 10 }
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
        let items = (try? JSONDecoder().decode([RecentItem].self, from: data)) ?? []
        return Self.merged(items)
    }

    /// Adds or updates the entry for `url` and moves it to the front. A password in the URL is dropped.
    public func record(url: String, title: String, position: TimeInterval, duration: TimeInterval, now: Date = Date()) {
        let clean = Self.normalized(url)
        let item = RecentItem(url: clean, title: title, lastPlayed: now, position: position, duration: duration)
        var items = all().filter { $0.url != clean }
        items.insert(item, at: 0)
        write(Array(items.prefix(limit)))
    }

    /// Where to resume, or nil to start over: under 5 s in is not worth resuming, and within the last
    /// 10 s (or no known duration to compare against) counts as finished.
    public func resumePosition(for url: String) -> TimeInterval? {
        let clean = Self.normalized(url)
        guard let item = all().first(where: { $0.url == clean }),
              item.position >= 5, item.duration > 0, !item.isFinished else { return nil }
        return item.position
    }

    public func clear() { defaults.removeObject(forKey: key) }

    /// `sftp://user:secret@host/x` becomes `sftp://user@host/x`.
    static func withoutPassword(_ url: String) -> String {
        url.replacingOccurrences(of: #"^(\w+://[^:@/]+):[^@/]*@"#, with: "$1@", options: .regularExpression)
    }

    /// Also drops the default `:22`, so an entry stored by an older build matches the portless URL.
    static func normalized(_ url: String) -> String {
        withoutPassword(url).replacingOccurrences(of: #"^(\w+://(?:[^@/]*@)?[^:@/]+):22(?=/|$)"#, with: "$1", options: .regularExpression)
    }

    /// Collapses entries that normalize to the same URL, keeping the newest one in the position of the first.
    private static func merged(_ items: [RecentItem]) -> [RecentItem] {
        var result: [RecentItem] = []
        var index: [String: Int] = [:]
        for var item in items {
            item.url = normalized(item.url)
            if let i = index[item.url] {
                if item.lastPlayed > result[i].lastPlayed { result[i] = item }
            } else {
                index[item.url] = result.count
                result.append(item)
            }
        }
        return result
    }

    private func write(_ items: [RecentItem]) {
        defaults.set(try? JSONEncoder().encode(items), forKey: key)
    }
}
