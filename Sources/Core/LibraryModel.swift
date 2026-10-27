import Foundation
import Observation

/// State of the remote Library panel for the current server.
@Observable
public final class LibraryModel {
    public private(set) var path = ""
    public private(set) var entries: [RemoteEntry] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var serverLabel: String?
    public var hostKeyIssue: HostKeyIssue?
    public var sort: LibrarySort = .nameAscending
    public var query = ""

    @ObservationIgnored public private(set) var target: SFTPTarget?
    @ObservationIgnored private var serverKey: String?
    @ObservationIgnored private var browser: DirectoryLister?
    /// Last folder shown per server for this session, so switching back restores it.
    @ObservationIgnored private var lastFolders: [String: String] = [:]
    /// Incremented per request so a slow, older response never overwrites a newer one.
    @ObservationIgnored private var requestID = 0

    public init() {}

    public var visibleEntries: [RemoteEntry] { Library.sorted(Library.filtered(entries, query: query), by: sort) }
    public var breadcrumbs: [Breadcrumb] { Breadcrumb.components(of: path) }
    public var hasServer: Bool { browser != nil }

    /// Points the Library at a server. The folder, listing and search are kept when it is the same server
    /// (for example after playback starts); a different server starts empty.
    public func attach(lister: DirectoryLister, target: SFTPTarget) {
        let key = "\(target.user)@\(target.host):\(target.port)"
        if key != serverKey {
            if let old = serverKey, !path.isEmpty { lastFolders[old] = path }
            serverKey = key
            serverLabel = key
            path = ""
            entries = []
            query = ""
            errorMessage = nil
            requestID += 1
            isLoading = false
        }
        self.target = target
        browser = lister
    }

    /// Loads the remembered folder, or the home directory, if nothing is loaded yet.
    public func loadIfNeeded() async {
        guard browser != nil, path.isEmpty, !isLoading else { return }
        await load(serverKey.flatMap { lastFolders[$0] } ?? ".")
    }

    public func reload() async { await load(path.isEmpty ? "." : path) }

    public func load(_ requested: String) async {
        guard let browser else { return }
        requestID += 1
        let id = requestID
        isLoading = true
        errorMessage = nil
        let result = await browser.list(requested)
        guard id == requestID else { return }
        isLoading = false
        switch result {
        case .success(let listing):
            path = listing.path
            entries = listing.entries
            if let serverKey { lastFolders[serverKey] = listing.path }
        case .failure(let failure):
            errorMessage = failure.description
            hostKeyIssue = failure.hostKey
        }
    }

    public func childPath(_ name: String) -> String { path == "/" ? "/" + name : path + "/" + name }
}
