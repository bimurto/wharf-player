import Foundation

public struct RemoteEntry: Equatable, Sendable {
    public var name: String
    public var isDirectory: Bool
    public var size: UInt64
    public var modified: Date?

    public init(name: String, isDirectory: Bool, size: UInt64 = 0, modified: Date? = nil) {
        self.name = name; self.isDirectory = isDirectory; self.size = size; self.modified = modified
    }
}

public enum LibrarySort: String, CaseIterable, Sendable {
    case nameAscending, nameDescending, modifiedNewest, modifiedOldest
}

public enum Library {
    /// Folders first, then the chosen order. Names use natural number ordering ("ep2" before "ep10");
    /// entries without a timestamp sort last within their group.
    public static func sorted(_ entries: [RemoteEntry], by sort: LibrarySort) -> [RemoteEntry] {
        func name(_ a: RemoteEntry, _ b: RemoteEntry) -> ComparisonResult {
            a.name.compare(b.name, options: [.numeric, .caseInsensitive])
        }
        func before(_ a: RemoteEntry, _ b: RemoteEntry) -> Bool {
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            switch sort {
            case .nameAscending: return name(a, b) == .orderedAscending
            case .nameDescending: return name(a, b) == .orderedDescending
            case .modifiedNewest, .modifiedOldest:
                switch (a.modified, b.modified) {
                case let (x?, y?) where x != y: return sort == .modifiedNewest ? x > y : x < y
                case (nil, _?): return false
                case (_?, nil): return true
                default: return name(a, b) == .orderedAscending
                }
            }
        }
        return entries.sorted(by: before)
    }

    /// Case-insensitive substring match on the name; an empty query keeps everything.
    public static func filtered(_ entries: [RemoteEntry], query: String) -> [RemoteEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
}
