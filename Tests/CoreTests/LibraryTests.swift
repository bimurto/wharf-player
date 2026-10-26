import XCTest
@testable import Core

final class LibraryTests: XCTestCase {
    private func date(_ s: Double) -> Date { Date(timeIntervalSince1970: s) }

    private let entries = [
        RemoteEntry(name: "ep10.mkv", isDirectory: false, modified: Date(timeIntervalSince1970: 100)),
        RemoteEntry(name: "ep2.mkv", isDirectory: false, modified: Date(timeIntervalSince1970: 300)),
        RemoteEntry(name: "Zeta", isDirectory: true, modified: Date(timeIntervalSince1970: 50)),
        RemoteEntry(name: "alpha", isDirectory: true),
        RemoteEntry(name: "undated.mkv", isDirectory: false),
    ]

    func testNameAscendingUsesNaturalOrderAndFoldersFirst() {
        XCTAssertEqual(Library.sorted(entries, by: .nameAscending).map(\.name),
                       ["alpha", "Zeta", "ep2.mkv", "ep10.mkv", "undated.mkv"])
    }

    func testNameDescendingKeepsFoldersFirst() {
        XCTAssertEqual(Library.sorted(entries, by: .nameDescending).map(\.name),
                       ["Zeta", "alpha", "undated.mkv", "ep10.mkv", "ep2.mkv"])
    }

    func testNewestFirstPutsUndatedLastWithinGroup() {
        XCTAssertEqual(Library.sorted(entries, by: .modifiedNewest).map(\.name),
                       ["Zeta", "alpha", "ep2.mkv", "ep10.mkv", "undated.mkv"])
    }

    func testOldestFirstPutsUndatedLastWithinGroup() {
        XCTAssertEqual(Library.sorted(entries, by: .modifiedOldest).map(\.name),
                       ["Zeta", "alpha", "ep10.mkv", "ep2.mkv", "undated.mkv"])
    }

    func testFilterIsCaseInsensitiveSubstring() {
        XCTAssertEqual(Library.filtered(entries, query: " EP").map(\.name), ["ep10.mkv", "ep2.mkv"])
        XCTAssertEqual(Library.filtered(entries, query: "").count, entries.count)
    }
}
