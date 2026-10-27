import Foundation

/// A subtitle file found on the server beside a video.
public struct ExternalSubtitle: Equatable, Identifiable, Sendable {
    /// Absolute remote path.
    public let path: String
    public let name: String
    /// True when the file name starts with the video's name (without extension).
    public let matchesVideo: Bool
    public var id: String { path }
}

public enum ExternalSubtitles {
    /// Subtitle file extensions (lowercase) used for server listings and the local open panel.
    public static let extensions: Set<String> = ["srt", "vtt", "ass", "ssa"]
    static let folderNames: [String] = ["subs", "subtitles", "sub"]

    /// Subtitle files among `entries` (in `folder`), ranked against `videoName`: prefix matches first,
    /// then the rest; the video's own folder before subfolders, then natural name order.
    /// Pure: no listing happens here.
    public static func rank(videoName: String, folders: [(path: String, entries: [RemoteEntry])]) -> [ExternalSubtitle] {
        let stem = (videoName as NSString).deletingPathExtension.lowercased()
        var found: [(sub: ExternalSubtitle, folderIndex: Int)] = []
        for (index, folder) in folders.enumerated() {
            for entry in folder.entries where !entry.isDirectory {
                guard extensions.contains((entry.name as NSString).pathExtension.lowercased()) else { continue }
                let prefix = !stem.isEmpty && entry.name.lowercased().hasPrefix(stem)
                let path = folder.path == "/" ? "/" + entry.name : folder.path + "/" + entry.name
                found.append((ExternalSubtitle(path: path, name: entry.name, matchesVideo: prefix), index))
            }
        }
        return found.sorted { a, b in
            if a.sub.matchesVideo != b.sub.matchesVideo { return a.sub.matchesVideo }
            if a.folderIndex != b.folderIndex { return a.folderIndex < b.folderIndex }
            return a.sub.name.compare(b.sub.name, options: [.numeric, .caseInsensitive]) == .orderedAscending
        }.map(\.sub)
    }

    /// `subs` that are not yet among mpv's external `tracks` (matched by file name).
    public static func notLoaded(_ subs: [ExternalSubtitle], tracks: [SubtitleTrack]) -> [ExternalSubtitle] {
        let loaded = Set(tracks.compactMap(\.externalName))
        return subs.filter { !loaded.contains($0.name) }
    }

    /// Lists the video's folder and its `Subs`, `Subtitles` and `Sub` subfolders (any letter case) and
    /// ranks the subtitle files found. A folder that is missing or fails to list is skipped; if the
    /// video's own folder cannot be listed the result is empty. Never throws.
    public static func discover(videoPath: String, lister: DirectoryLister) async -> [ExternalSubtitle] {
        let videoName = (videoPath as NSString).lastPathComponent
        let parent = (videoPath as NSString).deletingLastPathComponent
        let folder = parent.isEmpty ? "/" : parent
        guard case .success(let own) = await lister.list(folder) else { return [] }
        var folders = [(path: own.path, entries: own.entries)]
        for name in folderNames {
            guard let dir = own.entries.first(where: { $0.isDirectory && $0.name.lowercased() == name }) else { continue }
            let path = own.path == "/" ? "/" + dir.name : own.path + "/" + dir.name
            if case .success(let listing) = await lister.list(path) { folders.append((listing.path, listing.entries)) }
        }
        return rank(videoName: videoName, folders: folders)
    }
}
