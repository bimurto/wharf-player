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

public extension RemoteEntry {
    private static let videoExtensions: Set<String> = [
        "mkv", "mp4", "m4v", "mov", "avi", "webm", "ts", "m2ts", "mts", "wmv", "flv", "mpg", "mpeg", "ogv", "3gp",
    ]

    /// Playable media by file extension; folders are never videos.
    var isVideo: Bool {
        !isDirectory && Self.videoExtensions.contains((name as NSString).pathExtension.lowercased())
    }
}

/// A directory's absolute path (resolved by the server) and its entries.
public struct Listing: Sendable {
    public let path: String
    public let entries: [RemoteEntry]
}

public struct Breadcrumb: Equatable, Identifiable, Sendable {
    public let name: String
    public let path: String
    public var id: String { path }

    /// `/a/b` gives `/`, `a`, `b`, each with the absolute path it leads to.
    public static func components(of path: String) -> [Breadcrumb] {
        var crumbs = [Breadcrumb(name: "/", path: "/")]
        var current = ""
        for part in path.split(separator: "/") {
            current += "/" + part
            crumbs.append(Breadcrumb(name: String(part), path: current))
        }
        return crumbs
    }
}

extension RemoteEntry: Identifiable {
    /// Names are unique within one folder listing.
    public var id: String { name }
    /// `modified`, or the distant past when the server gave no date; for sortable table columns.
    public var modifiedSortKey: Date { modified ?? .distantPast }
}

public enum LibrarySort: String, CaseIterable, Sendable {
    case nameAscending, nameDescending, modifiedNewest, modifiedOldest, sizeAscending, sizeDescending
}

/// A sortable Library column.
public enum LibraryColumn: Sendable { case name, size, modified }

public extension LibrarySort {
    /// The sort for a column header and direction. Oldest-first counts as ascending.
    init(column: LibraryColumn, ascending: Bool) {
        switch column {
        case .name: self = ascending ? .nameAscending : .nameDescending
        case .size: self = ascending ? .sizeAscending : .sizeDescending
        case .modified: self = ascending ? .modifiedOldest : .modifiedNewest
        }
    }

    var column: LibraryColumn {
        switch self {
        case .nameAscending, .nameDescending: .name
        case .sizeAscending, .sizeDescending: .size
        case .modifiedNewest, .modifiedOldest: .modified
        }
    }

    var ascending: Bool { [.nameAscending, .sizeAscending, .modifiedOldest].contains(self) }
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
            case .sizeAscending, .sizeDescending:
                if a.size != b.size { return sort == .sizeAscending ? a.size < b.size : a.size > b.size }
                return name(a, b) == .orderedAscending
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

    /// The video `offset` places from `name` among the videos in `entries`, in natural name order
    /// ("ep2" before "ep10"). Nil past either end or when `name` is not among them.
    public static func neighbor(of name: String, in entries: [RemoteEntry], offset: Int) -> RemoteEntry? {
        let videos = sorted(entries.filter(\.isVideo), by: .nameAscending)
        guard let index = videos.firstIndex(where: { $0.name == name }) else { return nil }
        let target = index + offset
        return videos.indices.contains(target) ? videos[target] : nil
    }

    /// Case-insensitive substring match on the name; an empty query keeps everything.
    public static func filtered(_ entries: [RemoteEntry], query: String) -> [RemoteEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
}
