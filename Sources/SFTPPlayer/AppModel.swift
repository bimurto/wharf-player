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
    /// External subtitle files found for the current video, best match first.
    private(set) var externalSubtitles: [ExternalSubtitle] = []
    private let subtitleDiscovery = SubtitleDiscovery()
    /// The videos before and after the current one in its folder, in natural name order.
    private(set) var previousEntry: RemoteEntry?
    private(set) var nextEntry: RemoteEntry?
    var servers: [ConnectionProfile] = []
    var activeProfile: ConnectionProfile?
    var showSidebar = false
    var sidebarPanel: SidebarPanel = .library
    private(set) var recentItems: [RecentItem] = []
    let library = LibraryModel()

    enum SidebarPanel: String, CaseIterable { case library = "Library", servers = "Servers", recents = "Recents" }

    @ObservationIgnored let profiles = ProfileStore(secrets: KeychainSecretStore())
    @ObservationIgnored private let recents = RecentsStore()
    @ObservationIgnored let sidebarWidth = SidebarWidthStore()
    @ObservationIgnored private var proxy: SFTPProxy?
    @ObservationIgnored private var proxyKey: String?
    @ObservationIgnored private var lastSaved = Date.distantPast
    @ObservationIgnored private var currentTarget: SFTPTarget?
    /// Incremented per video so a slow sibling listing for an older video is dropped.
    @ObservationIgnored private var siblingRequest = 0

    init() {
        servers = profiles.all()
        recentItems = recents.all()
    }

    // MARK: Recents

    func clearRecents() {
        recents.clear()
        recentItems = []
    }

    // MARK: Sidebar

    /// Shows `panel`, or hides the sidebar when it is already showing that panel.
    func toggleSidebar(_ panel: SidebarPanel) {
        if showSidebar && sidebarPanel == panel { showSidebar = false } else { sidebarPanel = panel; showSidebar = true }
    }

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

    /// Makes `profile` the connection for opened URLs, then shows its default directory in the Library.
    func use(_ profile: ConnectionProfile) {
        activeProfile = profile
        let target = profile.target(secret: profiles.secret(for: profile))
        guard let proxy = connection(for: target) else { return }
        library.attach(lister: SFTPBrowser(pool: proxy.pool), target: target)
        sidebarPanel = .library
        showSidebar = true
        Task { await library.load(profile.defaultDirectory ?? ".") }
    }

    /// Key used when the Open sheet has none yet.
    var defaultKeyPath: String {
        let path = NSHomeDirectory() + "/.ssh/id_ed25519"
        return FileManager.default.fileExists(atPath: path) ? path : ""
    }

    // MARK: Playback

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
        // A URL for a saved server (the active one first) uses that server's credentials.
        let saved = ([activeProfile].compactMap { $0 } + servers)
            .first { $0.host == target.host && $0.port == target.port && $0.username == target.user }
        if let p = saved { target = p.target(path: target.path, secret: profiles.secret(for: p)) }
        return await play(target)
    }

    /// Plays `target.path`. The server also becomes the Library's server, keeping its current folder
    /// if it is already showing it.
    func play(_ target: SFTPTarget) async -> OpenOutcome {
        saveProgress()
        guard let proxy = connection(for: target) else {
            openError = "Could not start the local streaming proxy."
            return .failed
        }
        openError = nil
        if let failure = await proxy.preflight() {
            if let issue = failure.hostKey { return .hostKey(issue, target) }
            openError = failure.description
            return .failed
        }
        library.attach(lister: SFTPBrowser(pool: proxy.pool), target: target)
        currentURL = target.displayURL
        player.load(proxy.url(for: target.path), start: recents.resumePosition(for: target.displayURL),
                    audioTrack: recents.audioTrack(for: target.displayURL))
        externalSubtitles = []
        let lister = SFTPBrowser(pool: proxy.pool)
        let token = subtitleDiscovery.begin()
        Task {
            if let found = await subtitleDiscovery.discover(token, videoPath: target.path, lister: lister) {
                externalSubtitles = found
            }
        }
        let folder = (target.path as NSString).deletingLastPathComponent
        currentTarget = target
        previousEntry = nil
        nextEntry = nil
        siblingRequest += 1
        let request = siblingRequest
        Task {
            guard case .success(let listing) = await lister.list(folder.isEmpty ? "/" : folder),
                  request == siblingRequest else { return }
            let name = (target.path as NSString).lastPathComponent
            previousEntry = Library.neighbor(of: name, in: listing.entries, offset: -1)
            nextEntry = Library.neighbor(of: name, in: listing.entries, offset: 1)
        }
        if library.path.isEmpty {
            Task { await library.load(folder.isEmpty ? "/" : folder) }
        }
        return .started
    }

    /// Reads `sub` through the loopback proxy and shows it. Failure sets `player.subtitleError`.
    func loadExternalSubtitle(_ sub: ExternalSubtitle) {
        guard let proxy else {
            player.subtitleError = "Could not load \(sub.name): no connection."
            return
        }
        player.addSubtitle(url: proxy.url(for: sub.path), name: sub.name)
    }

    /// Plays a video chosen in the Library.
    func playFromLibrary(_ entry: RemoteEntry) {
        guard let base = library.target else { return }
        Task {
            if case .hostKey(let issue, _) = await play(base.with(path: library.childPath(entry.name))) {
                library.hostKeyIssue = issue
            }
        }
    }

    /// Plays the next (`offset` 1) or previous (-1) video in the current video's folder.
    func playSibling(_ offset: Int) {
        guard let target = currentTarget, let entry = offset > 0 ? nextEntry : previousEntry else { return }
        let folder = (target.path as NSString).deletingLastPathComponent
        let path = folder == "/" || folder.isEmpty ? "/" + entry.name : folder + "/" + entry.name
        Task {
            if case .hostKey(let issue, _) = await play(target.with(path: path)) {
                library.hostKeyIssue = issue
            }
        }
    }

    /// The streaming proxy for `target`'s server and credentials, created when they change.
    private func connection(for target: SFTPTarget) -> SFTPProxy? {
        let id = "\(target.user)@\(target.host):\(target.port)|\(target.keyPath ?? "")|\(target.password ?? "")|\(target.passphrase ?? "")"
        if proxyKey != id {
            guard let p = SFTPProxy(target: target) else { return nil }
            proxy = p
            proxyKey = id
        }
        return proxy
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
        recents.record(url: url, title: title, position: player.position, duration: player.duration,
                       audioTrack: player.audioTracks.first(where: \.selected)?.id)
        recentItems = recents.all()
    }

    func shutdown() {
        saveProgress()
        player.shutdown()
        proxy = nil
    }
}
