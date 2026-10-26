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
    var servers: [ConnectionProfile] = []
    var activeProfile: ConnectionProfile?
    var showSidebar = false
    /// URL the Open sheet starts with, set by Use on a saved server.
    var openPrefill: String?

    @ObservationIgnored let profiles = ProfileStore(secrets: KeychainSecretStore())
    @ObservationIgnored private let recents = RecentsStore()
    @ObservationIgnored private var proxy: SFTPProxy?
    @ObservationIgnored private var proxyKey: String?
    @ObservationIgnored private var lastSaved = Date.distantPast

    init() { servers = profiles.all() }

    // MARK: Servers

    func saveProfile(_ profile: ConnectionProfile, secret: String?) {
        profiles.save(profile, secret: secret)
        servers = profiles.all()
        if activeProfile?.id == profile.id { activeProfile = profile }
    }

    func deleteProfile(_ profile: ConnectionProfile) {
        profiles.delete(profile)
        servers = profiles.all()
        if activeProfile?.id == profile.id { activeProfile = nil }
    }

    /// Makes `profile` the connection for opened URLs and shows the Open sheet for it.
    func use(_ profile: ConnectionProfile) {
        activeProfile = profile
        openPrefill = profile.url()
        showOpenSheet = true
    }

    /// Key used when the Open sheet has none yet.
    var defaultKeyPath: String {
        let path = NSHomeDirectory() + "/.ssh/id_ed25519"
        return FileManager.default.fileExists(atPath: path) ? path : ""
    }

    enum OpenOutcome { case started, failed, hostKey(HostKeyIssue, SFTPTarget) }

    /// Starts playback of an `sftp://user@host[:port]/path` URL. On `.failed`, `openError` says why; on
    /// `.hostKey`, the caller asks the user whether to trust the server and then opens again.
    func open(urlString: String, keyPath: String) async -> OpenOutcome {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keyPath.isEmpty ? nil : (keyPath as NSString).expandingTildeInPath
        guard var target = SFTPTarget(raw, keyPath: key) else {
            openError = "Enter a URL like sftp://user@host/path/to/video.mkv"
            return .failed
        }
        guard !target.user.contains(":") else {
            openError = "Passwords in URLs are not supported yet. Use a key file or ssh-agent."
            return .failed
        }
        // A URL for the active saved server uses that server's credentials.
        if let p = activeProfile, p.host == target.host, p.port == target.port, p.username == target.user {
            target = p.target(path: target.path, secret: profiles.secret(for: p))
        }
        saveProgress()
        let id = "\(target.user)@\(target.host):\(target.port)|\(target.keyPath ?? "")|\(target.password ?? "")|\(target.passphrase ?? "")"
        if proxyKey != id {
            guard let p = SFTPProxy(target: target) else {
                openError = "Could not start the local streaming proxy."
                return .failed
            }
            proxy = p
            proxyKey = id
        }
        guard let proxy else { return .failed }
        openError = nil
        if let failure = await proxy.preflight() {
            if let issue = failure.hostKey { return .hostKey(issue, target) }
            openError = failure.description
            return .failed
        }
        currentURL = raw
        player.load(proxy.url(for: target.path), start: recents.resumePosition(for: raw))
        return .started
    }

    /// Saves the approved host key; returns why it failed, or nil on success.
    func trust(_ fingerprint: HostKeyFingerprint, target: SFTPTarget) async -> Failure? {
        await Task.detached {
            if case .failure(let failure) = KnownHosts.trust(fingerprint, target: target) { return failure }
            return nil
        }.value
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
