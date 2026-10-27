import XCTest
@testable import Core

/// Lists instantly, except for paths in `gated`, which wait until `release()` is called.
private final class GatedLister: DirectoryLister, @unchecked Sendable {
    let folders: [String: [RemoteEntry]]
    private let gatedPaths: Set<String>
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private let lock = NSLock()
    init(_ folders: [String: [RemoteEntry]], gated: Set<String> = []) { self.folders = folders; gatedPaths = gated }

    func release() {
        lock.lock(); released = true; let waiting = continuations; continuations = []; lock.unlock()
        waiting.forEach { $0.resume() }
    }

    func list(_ path: String) async -> Result<Listing, Failure> {
        if gatedPaths.contains(path) {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                lock.lock()
                if released { lock.unlock(); c.resume() } else { continuations.append(c); lock.unlock() }
            }
        }
        guard let entries = folders[path] else { return .failure(Failure("no such folder")) }
        return .success(Listing(path: path, entries: entries))
    }
}

final class SubtitleDiscoveryTests: XCTestCase {
    private func file(_ n: String) -> RemoteEntry { RemoteEntry(name: n, isDirectory: false) }
    private let folders = ["/a": [RemoteEntry(name: "a.srt", isDirectory: false)],
                           "/b": [RemoteEntry(name: "b.srt", isDirectory: false)]]

    func testResultIsDeliveredWhenNothingNewerStarted() async {
        let discovery = SubtitleDiscovery()
        let token = discovery.begin()
        let found = await discovery.discover(token, videoPath: "/a/a.mkv", lister: GatedLister(folders))
        XCTAssertEqual(found?.map(\.path), ["/a/a.srt"])
    }

    func testResultFromVideoAIsIgnoredAfterVideoBStarts() async {
        let discovery = SubtitleDiscovery()
        let tokenA = discovery.begin()
        _ = discovery.begin()
        let found = await discovery.discover(tokenA, videoPath: "/a/a.mkv", lister: GatedLister(folders))
        XCTAssertNil(found)
    }

    func testLateResultDoesNotOverwriteNewerOne() async {
        let discovery = SubtitleDiscovery()
        let slow = GatedLister(folders, gated: ["/a"])
        let tokenA = discovery.begin()
        let taskA = Task { await discovery.discover(tokenA, videoPath: "/a/a.mkv", lister: slow) }
        await Task.yield()

        let tokenB = discovery.begin()
        let foundB = await discovery.discover(tokenB, videoPath: "/b/b.mkv", lister: GatedLister(folders))
        XCTAssertEqual(foundB?.map(\.path), ["/b/b.srt"])

        slow.release()
        let foundA = await taskA.value
        XCTAssertNil(foundA, "A's late result must be dropped")
    }

    func testUserChoiceDuringDiscoveryIsPreserved() async {
        // Discovery only reports what is on the server; it selects nothing. A track the user already
        // added stays untouched and is simply filtered out of the "On the server" list.
        let discovery = SubtitleDiscovery()
        let slow = GatedLister(folders, gated: ["/a"])
        let token = discovery.begin()
        let task = Task { await discovery.discover(token, videoPath: "/a/a.mkv", lister: slow) }
        await Task.yield()

        let chosen = SubtitleTrack.parse("""
        [{"id":2,"type":"sub","external":true,"selected":true,"external-filename":"http://127.0.0.1:1/t/a/a.srt"}]
        """)
        slow.release()
        let found = await task.value ?? []
        XCTAssertEqual(found.map(\.path), ["/a/a.srt"])
        XCTAssertTrue(chosen[0].selected)
        XCTAssertTrue(ExternalSubtitles.notLoaded(found, tracks: chosen).isEmpty)
    }
}
