import XCTest
@testable import Core

final class LegacyMigrationTests: XCTestCase {
    private var names: [String] = []

    override func tearDown() {
        for n in names { UserDefaults.standard.removePersistentDomain(forName: n) }
        names = []
    }

    private func suite() -> UserDefaults {
        let n = "LegacyMigrationTests-\(UUID().uuidString)"
        names.append(n)
        return UserDefaults(suiteName: n)!
    }

    private func item(_ url: String, _ t: TimeInterval) -> RecentItem {
        RecentItem(url: url, title: "t", lastPlayed: Date(timeIntervalSince1970: t), position: 0, duration: 0)
    }
    private func data(_ items: [RecentItem]) -> Data { try! JSONEncoder().encode(items) }
    private func run(_ legacy: [String: Any]?, _ d: UserDefaults, domain: String = "io.example.dest") -> Bool {
        LegacyMigration.migrate(legacy: legacy, into: d, destinationDomain: domain)
    }

    func testCopiesWhenAbsent() {
        let d = suite()
        let legacy: [String: Any] = ["sftp_profiles": Data([1, 2]), "sidebar_width": 400.0, "subtitle_scale": 1.5]
        XCTAssertTrue(run(legacy, d))
        XCTAssertEqual(d.data(forKey: "sftp_profiles"), Data([1, 2]))
        XCTAssertEqual(d.double(forKey: "sidebar_width"), 400)
        XCTAssertEqual(d.double(forKey: "subtitle_scale"), 1.5)
        XCTAssertNil(d.object(forKey: "subtitle_position"))
    }

    func testDoesNotOverwriteExisting() {
        let d = suite()
        d.set(500.0, forKey: "sidebar_width")
        _ = run(["sidebar_width": 400.0, "subtitle_position": 7.0], d)
        XCTAssertEqual(d.double(forKey: "sidebar_width"), 500)
        XCTAssertEqual(d.double(forKey: "subtitle_position"), 7)
    }

    func testRecentsMergeDedupeAndOrder() throws {
        let d = suite()
        d.set(data([item("sftp://u@h/a", 10), item("sftp://u@h/b", 30)]), forKey: "sftp_history")
        let legacy = ["sftp_history": data([item("sftp://u@h:22/a", 20), item("sftp://u@h/c", 5)])]
        _ = run(legacy, d)
        let out = try JSONDecoder().decode([RecentItem].self, from: d.data(forKey: "sftp_history")!)
        XCTAssertEqual(out.map(\.url), ["sftp://u@h/b", "sftp://u@h/a", "sftp://u@h/c"])
        XCTAssertEqual(out[1].lastPlayed, Date(timeIntervalSince1970: 20))
    }

    func testRecentsCappedToLimit() throws {
        let d = suite()
        let many = (0..<30).map { item("sftp://u@h/\($0)", TimeInterval($0)) }
        _ = run(["sftp_history": data(many)], d)
        let out = try JSONDecoder().decode([RecentItem].self, from: d.data(forKey: "sftp_history")!)
        XCTAssertEqual(out.count, 20)
        XCTAssertEqual(out.first?.url, "sftp://u@h/29")
    }

    func testFlagPreventsSecondRun() {
        let d = suite()
        XCTAssertTrue(run(["sidebar_width": 400.0], d))
        d.removeObject(forKey: "sidebar_width")
        XCTAssertFalse(run(["sidebar_width": 400.0], d))
        XCTAssertNil(d.object(forKey: "sidebar_width"))
    }

    func testNoOpWhenLegacyNil() {
        let d = suite()
        XCTAssertFalse(run(nil, d))
        XCTAssertFalse(d.bool(forKey: LegacyMigration.flagKey))
    }

    func testNoOpWhenDestinationIsLegacyDomain() {
        let d = suite()
        XCTAssertFalse(run(["sidebar_width": 400.0], d, domain: LegacyMigration.legacyDomain))
        XCTAssertNil(d.object(forKey: "sidebar_width"))
        XCTAssertFalse(d.bool(forKey: LegacyMigration.flagKey))
    }

    func testLegacyDataUnchanged() {
        let legacySuite = suite()
        legacySuite.set(400.0, forKey: "sidebar_width")
        legacySuite.set(data([item("sftp://u@h:22/a", 1)]), forKey: "sftp_history")
        let name = names[0]
        let before = legacySuite.persistentDomain(forName: name)! as NSDictionary
        _ = run(legacySuite.persistentDomain(forName: name), suite())
        XCTAssertEqual(legacySuite.persistentDomain(forName: name)! as NSDictionary, before)
    }
}
