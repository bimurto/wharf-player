import Foundation

/// One subtitle track from mpv's `track-list`, embedded or added with `sub-add`.
public struct SubtitleTrack: Equatable, Identifiable {
    /// mpv's per-type track id; the value `sid` takes.
    public let id: Int
    public let language: String?
    public let title: String?
    public let codec: String?
    public let selected: Bool
    /// True for a file added with `sub-add` rather than a track inside the video.
    public let external: Bool
    /// File name of an external track, taken from mpv's `external-filename` (a proxy or file URL).
    public let externalName: String?

    public init(id: Int, language: String?, title: String?, codec: String?, selected: Bool,
                external: Bool = false, externalName: String? = nil) {
        self.id = id; self.language = language; self.title = title; self.codec = codec
        self.selected = selected; self.external = external; self.externalName = externalName
    }

    /// "eng · Full", the language or title alone, or "Track 3" when mpv gives neither.
    public var label: String {
        let parts = [language, title].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Track \(id)" : parts.joined(separator: " · ")
    }

    /// The value for mpv's `sid`: the track id, or "no" for Off.
    public static func sidArgument(_ id: Int?) -> String { id.map(String.init) ?? "no" }

    /// True when no track is selected, so the menu marks Off.
    public static func isOff(_ tracks: [SubtitleTrack]) -> Bool { !tracks.contains { $0.selected } }

    /// mpv command that adds the subtitle at `url` and selects it; `name` becomes the track title.
    public static func subAddArguments(url: String, name: String) -> [String] { ["sub-add", url, "select", name] }

    /// Subtitle tracks from the JSON mpv returns for `track-list`. Bad input gives no tracks.
    public static func parse(_ json: String) -> [SubtitleTrack] {
        guard let data = json.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard item["type"] as? String == "sub", let id = item["id"] as? Int else { return nil }
            return SubtitleTrack(id: id, language: item["lang"] as? String, title: item["title"] as? String,
                                 codec: item["codec"] as? String, selected: item["selected"] as? Bool ?? false,
                                 external: item["external"] as? Bool ?? false,
                                 externalName: (item["external-filename"] as? String).flatMap(fileName))
        }
    }

    private static func fileName(_ location: String) -> String? {
        let last = location.split(separator: "/").last.map(String.init) ?? ""
        let decoded = last.removingPercentEncoding ?? last
        return decoded.isEmpty ? nil : decoded
    }
}
