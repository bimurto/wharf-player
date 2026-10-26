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

    func testClear() {
        record("a")
        store.clear()
        XCTAssertTrue(store.all().isEmpty)
    }
}
