import AppKit
import Observation
import Core

@Observable
final class AppModel {
    static let shared = AppModel()

    let player = MPVPlayer()
    var showOpenSheet = false
    var openError: String?
    private(set) var currentURL: String?

    @ObservationIgnored private let recents = RecentsStore()
    @ObservationIgnored private var proxy: SFTPProxy?
    @ObservationIgnored private var proxyKey: String?
    @ObservationIgnored private var lastSaved = Date.distantPast

    /// Key used when the Open sheet has none yet.
    var defaultKeyPath: String {
        let path = NSHomeDirectory() + "/.ssh/id_ed25519"
        return FileManager.default.fileExists(atPath: path) ? path : ""
    }

    /// Starts playback of an `sftp://user@host[:port]/path` URL. Returns false and sets `openError` on bad input.
    @discardableResult
    func open(urlString: String, keyPath: String) -> Bool {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keyPath.isEmpty ? nil : (keyPath as NSString).expandingTildeInPath
        guard let target = SFTPTarget(raw, keyPath: key) else {
            openError = "Enter a URL like sftp://user@host/path/to/video.mkv"
            return false
        }
        guard !target.user.contains(":") else {
            openError = "Passwords in URLs are not supported yet. Use a key file or ssh-agent."
            return false
        }
        saveProgress()
        let id = "\(target.user)@\(target.host):\(target.port)|\(key ?? "")"
        if proxyKey != id {
            guard let p = SFTPProxy(target: target) else {
                openError = "Could not start the local streaming proxy."
                return false
            }
            proxy = p
            proxyKey = id
        }
        guard let proxy else { return false }
        openError = nil
        currentURL = raw
        player.load(proxy.url(for: target.path), start: recents.resumePosition(for: raw))
        return true
    }

    /// Writes progress at most every 10 s while playing.
    func saveProgressThrottled() {
        guard Date().timeIntervalSince(lastSaved) >= 10 else { return }
        saveProgress()
    }

    func saveProgress() {
        guard let url = currentURL, player.duration > 0 else { return }
        lastSaved = Date()
        let title = player.title.isEmpty ? (url as NSString).lastPathComponent : player.title
        recents.record(url: url, title: title, position: player.position, duration: player.duration)
    }

    func shutdown() {
        saveProgress()
        player.shutdown()
        proxy = nil
    }
}
