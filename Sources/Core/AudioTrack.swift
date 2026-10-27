import Foundation

/// One audio track from mpv's `track-list`.
public struct AudioTrack: Equatable, Identifiable {
    /// mpv's per-type track id; the value `aid` takes.
    public let id: Int
    public let language: String?
    public let title: String?
    public let codec: String?
    /// mpv's `demux-channels`, e.g. "stereo" or "5.1(side)".
    public let channels: String?
    public let selected: Bool

    public init(id: Int, language: String?, title: String?, codec: String?, channels: String?, selected: Bool) {
        self.id = id; self.language = language; self.title = title; self.codec = codec
        self.channels = channels; self.selected = selected
    }

    /// "eng · Commentary (ac3 5.1(side))". Language and title come first, "Track 2" when mpv gives
    /// neither; codec and channels follow so tracks in the same language can be told apart.
    public var label: String {
        let names = [language, title].compactMap { $0 }.filter { !$0.isEmpty }
        let name = names.isEmpty ? "Track \(id)" : names.joined(separator: " · ")
        let format = [codec, channels].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return format.isEmpty ? name : "\(name) (\(format))"
    }

    /// The value for mpv's `aid`.
    public static func aidArgument(_ id: Int) -> String { String(id) }

    /// Audio tracks from the JSON mpv returns for `track-list`. Bad input gives no tracks.
    public static func parse(_ json: String) -> [AudioTrack] {
        guard let data = json.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard item["type"] as? String == "audio", let id = item["id"] as? Int else { return nil }
            return AudioTrack(id: id, language: item["lang"] as? String, title: item["title"] as? String,
                              codec: item["codec"] as? String, channels: item["demux-channels"] as? String,
                              selected: item["selected"] as? Bool ?? false)
        }
    }
}
