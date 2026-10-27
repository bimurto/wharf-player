import XCTest
@testable import Core

final class RecentsStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var store: RecentsStore!
    private let base = "sftp://reader@fixture.invalid/media/"

    override func setUp() {
        suite = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        store = RecentsStore(defaults: defaults, limit: 3)
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    private func record(_ name: String, at position: TimeInterval = 0, of duration: TimeInterval = 100, t: TimeInterval = 0) {
        store.record(url: base + name, title: name, position: position, duration: duration, now: Date(timeIntervalSince1970: t))
    }

    func testNewestFirstAndCappedAtLimit() {
        for (i, n) in ["a", "b", "c", "d"].enumerated() { record(n, t: Double(i)) }
        XCTAssertEqual(store.all().map(\.title), ["d", "c", "b"])
    }

    func testRecordingSameURLUpdatesAndMovesToFront() {
        record("a", at: 10, t: 1)
        record("b", t: 2)
        record("a", at: 40, t: 3)
        XCTAssertEqual(store.all().map(\.title), ["a", "b"])
        XCTAssertEqual(store.all().first?.position, 40)
    }

    func testPasswordIsStrippedFromStoredURL() {
        store.record(url: "sftp://reader:hunter2-fixture@fixture.invalid:2222/a.mkv", title: "a", position: 0, duration: 0)
        XCTAssertEqual(store.all().first?.url, "sftp://reader@fixture.invalid:2222/a.mkv")
        let raw = String(data: defaults.data(forKey: "sftp_history")!, encoding: .utf8)!
        XCTAssertFalse(raw.contains("hunter2"))
    }

    func testResumeLookupIgnoresPasswordInQuery() {
        store.record(url: "sftp://reader@fixture.invalid/a.mkv", title: "a", position: 30, duration: 100)
        XCTAssertEqual(store.resumePosition(for: "sftp://reader:secret@fixture.invalid/a.mkv"), 30)
    }

    func testDefaultPortIsNormalizedWhenRecordingAndLookingUp() {
        store.record(url: "sftp://reader@fixture.invalid:22/a.mkv", title: "a", position: 30, duration: 100)
        XCTAssertEqual(store.all().first?.url, "sftp://reader@fixture.invalid/a.mkv")
        XCTAssertEqual(store.resumePosition(for: "sftp://reader@fixture.invalid/a.mkv"), 30)
        XCTAssertEqual(store.resumePosition(for: "sftp://reader@fixture.invalid:22/a.mkv"), 30)
        store.record(url: "sftp://reader@fixture.invalid:2222/a.mkv", title: "a", position: 0, duration: 0)
        XCTAssertEqual(store.all().count, 2)
    }

    func testDuplicatesFromOlderBuildAreMergedOnLoadKeepingNewest() throws {
        func item(_ url: String, _ position: Double, _ t: Double) -> RecentItem {
            RecentItem(url: url, title: "a", lastPlayed: Date(timeIntervalSince1970: t), position: position, duration: 100)
        }
        let stored = [item("sftp://reader@fixture.invalid:22/a.mkv", 70, 5),
                      item("sftp://reader@fixture.invalid/b.mkv", 1, 4),
                      item("sftp://reader@fixture.invalid/a.mkv", 20, 3)]
        defaults.set(try JSONEncoder().encode(stored), forKey: "sftp_history")
        let all = store.all()
        XCTAssertEqual(all.map(\.url), ["sftp://reader@fixture.invalid/a.mkv", "sftp://reader@fixture.invalid/b.mkv"])
        XCTAssertEqual(all.first?.position, 70)
    }

    func testResumeRules() {
        record("early", at: 4)
        record("mid", at: 50)
        record("done", at: 95)
        XCTAssertNil(store.resumePosition(for: base + "early"))
        XCTAssertEqual(store.resumePosition(for: base + "mid"), 50)
        XCTAssertNil(store.resumePosition(for: base + "done"))
        XCTAssertNil(store.resumePosition(for: base + "unknown"))
    }

    func testUnknownDurationDoesNotResume() {
        record("live", at: 50, of: 0)
        XCTAssertNil(store.resumePosition(for: base + "live"))
    }

    func testAudioTrackIsStoredAndFoundThroughURLVariants() {
        store.record(url: "sftp://reader@fixture.invalid:22/a.mkv", title: "a", position: 0, duration: 100, audioTrack: 2)
        XCTAssertEqual(store.audioTrack(for: "sftp://reader:secret@fixture.invalid/a.mkv"), 2)
        XCTAssertNil(store.audioTrack(for: "sftp://reader@fixture.invalid/other.mkv"))
    }

    func testAudioTrackIsKeptWhenPositionIsNotResumed() {
        store.record(url: base + "a", title: "a", position: 99, duration: 100, audioTrack: 3)
        XCTAssertNil(store.resumePosition(for: base + "a"))
        XCTAssertEqual(store.audioTrack(for: base + "a"), 3)
    }

    func testEntryWithoutAudioTrackFromOlderBuildStillLoads() {
        let old = #"[{"url":"sftp://reader@fixture.invalid/a.mkv","title":"a","lastPlayed":0,"position":30,"duration":100}]"#
        defaults.set(Data(old.utf8), forKey: "sftp_history")
        XCTAssertEqual(store.all().count, 1)
        XCTAssertNil(store.audioTrack(for: "sftp://reader@fixture.invalid/a.mkv"))
    }

    func testClear() {
        record("a")
        store.clear()
        XCTAssertTrue(store.all().isEmpty)
    }
}

final class RecentItemTests: XCTestCase {
    private func item(_ position: Double, _ duration: Double) -> RecentItem {
        RecentItem(url: "sftp://reader@fixture.invalid/a.mkv", title: "a", lastPlayed: Date(timeIntervalSince1970: 0),
                   position: position, duration: duration)
    }

    func testFractionIsClampedAndZeroWithoutDuration() {
        XCTAssertEqual(item(50, 100).fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(item(150, 100).fraction, 1)
        XCTAssertEqual(item(-5, 100).fraction, 0)
        XCTAssertEqual(item(50, 0).fraction, 0)
    }

    func testFinishedMeansInTheLastTenSeconds() {
        XCTAssertFalse(item(89, 100).isFinished)
        XCTAssertTrue(item(95, 100).isFinished)
        XCTAssertFalse(item(50, 0).isFinished)
    }
}
