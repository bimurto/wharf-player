import XCTest
@testable import Core

/// A fake server: folders map to entries, `delays` slow chosen paths, `failing` makes a path error.
private final class FakeLister: DirectoryLister, @unchecked Sendable {
    var folders: [String: [RemoteEntry]]
    var delays: [String: Duration] = [:]
    var failing: [String: Failure] = [:]
    private(set) var requested: [String] = []
    private let lock = NSLock()

    init(_ folders: [String: [RemoteEntry]]) { self.folders = folders }

    func list(_ path: String) async -> Result<Listing, Failure> {
        let real = path == "." ? "/home/reader" : path
        lock.lock(); requested.append(path); lock.unlock()
        if let delay = delays[real] { try? await Task.sleep(for: delay) }
        if let failure = failing[real] { return .failure(failure) }
        return .success(Listing(path: real, entries: folders[real] ?? []))
    }
}

final class LibraryModelTests: XCTestCase {
    private func dir(_ n: String) -> RemoteEntry { RemoteEntry(name: n, isDirectory: true) }
    private func file(_ n: String) -> RemoteEntry { RemoteEntry(name: n, isDirectory: false) }
    private let serverA = SFTPTarget(host: "a.invalid", user: "reader")
    private let serverB = SFTPTarget(host: "b.invalid", user: "reader")

    private func fixture() -> FakeLister {
        FakeLister([
            "/home/reader": [dir("shows"), file("notes.txt")],
            "/home/reader/shows": [file("ep10.mkv"), file("ep2.mkv"), dir("extras")],
        ])
    }

    func testFirstLoadUsesHomeAndReportsAbsolutePath() async {
        let lib = LibraryModel()
        lib.attach(lister: fixture(), target: serverA)
        await lib.loadIfNeeded()
        XCTAssertEqual(lib.path, "/home/reader")
        XCTAssertEqual(lib.breadcrumbs.map(\.name), ["/", "home", "reader"])
    }

    func testSortAndSearchSurviveNavigation() async {
        let lib = LibraryModel()
        lib.attach(lister: fixture(), target: serverA)
        await lib.load("/home/reader/shows")
        lib.sort = .nameDescending
        lib.query = "ep"
        XCTAssertEqual(lib.visibleEntries.map(\.name), ["ep10.mkv", "ep2.mkv"], "Z–A, natural numbers, folders (filtered out here) first")
        await lib.reload()
        XCTAssertEqual(lib.sort, .nameDescending)
        XCTAssertEqual(lib.query, "ep")
    }

    func testReattachingSameServerKeepsFolderAndListing() async {
        let lib = LibraryModel()
        let lister = fixture()
        lib.attach(lister: lister, target: serverA)
        await lib.load("/home/reader/shows")
        lib.attach(lister: lister, target: serverA.with(path: "/home/reader/shows/ep2.mkv"))
        await lib.loadIfNeeded()
        XCTAssertEqual(lib.path, "/home/reader/shows")
        XCTAssertFalse(lib.entries.isEmpty)
        XCTAssertEqual(lister.requested, ["/home/reader/shows"], "reattaching must not trigger another listing")
    }

    func testDifferentServerStartsEmptyAndSwitchingBackRestoresFolder() async {
        let lib = LibraryModel()
        let lister = fixture()
        lib.attach(lister: lister, target: serverA)
        await lib.load("/home/reader/shows")
        lib.attach(lister: lister, target: serverB)
        XCTAssertEqual(lib.path, "")
        XCTAssertTrue(lib.entries.isEmpty)
        await lib.loadIfNeeded()
        XCTAssertEqual(lib.path, "/home/reader", "a new server starts at home")
        lib.attach(lister: lister, target: serverA)
        await lib.loadIfNeeded()
        XCTAssertEqual(lib.path, "/home/reader/shows", "switching back restores its last folder")
    }

    func testSlowOlderResponseNeverOverwritesNewerOne() async {
        let lib = LibraryModel()
        let lister = fixture()
        lister.delays["/home/reader/shows"] = .milliseconds(300)
        lib.attach(lister: lister, target: serverA)
        async let slow: () = lib.load("/home/reader/shows")
        try? await Task.sleep(for: .milliseconds(30))
        await lib.load("/home/reader")
        await slow
        XCTAssertEqual(lib.path, "/home/reader", "the later request must win")
        XCTAssertTrue(lib.entries.contains { $0.name == "notes.txt" })
    }

    func testFailureKeepsHostKeyIssueAndMessage() async {
        let lib = LibraryModel()
        let lister = fixture()
        let fp = HostKeyFingerprint(host: "a.invalid", port: 22, keyType: "ssh-ed25519", sha256: "SHA256:fixture")
        lister.failing["/home/reader"] = Failure("The server a.invalid is not trusted yet.", hostKey: .unknown(fp), retryable: false)
        lib.attach(lister: lister, target: serverA)
        await lib.loadIfNeeded()
        XCTAssertEqual(lib.hostKeyIssue, .unknown(fp))
        XCTAssertNotNil(lib.errorMessage)
        XCTAssertFalse(lib.isLoading)
    }

    func testChildPathJoinsWithoutDoubleSlash() async {
        let lib = LibraryModel()
        let lister = FakeLister(["/": [dir("home")]])
        lib.attach(lister: lister, target: serverA)
        await lib.load("/")
        XCTAssertEqual(lib.childPath("home"), "/home")
        await lib.load("/home/reader")
        XCTAssertEqual(lib.childPath("shows"), "/home/reader/shows")
    }
}
