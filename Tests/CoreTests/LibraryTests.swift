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

    func testSizeSortKeepsFoldersFirstAndBreaksTiesByName() {
        let sized = [
            RemoteEntry(name: "b.mkv", isDirectory: false, size: 300),
            RemoteEntry(name: "a.mkv", isDirectory: false, size: 300),
            RemoteEntry(name: "small.mkv", isDirectory: false, size: 10),
            RemoteEntry(name: "Zeta", isDirectory: true),
            RemoteEntry(name: "alpha", isDirectory: true),
        ]
        XCTAssertEqual(Library.sorted(sized, by: .sizeAscending).map(\.name),
                       ["alpha", "Zeta", "small.mkv", "a.mkv", "b.mkv"])
        XCTAssertEqual(Library.sorted(sized, by: .sizeDescending).map(\.name),
                       ["alpha", "Zeta", "a.mkv", "b.mkv", "small.mkv"])
    }

    func testSortRoundTripsThroughColumnAndDirection() {
        for sort in LibrarySort.allCases {
            XCTAssertEqual(LibrarySort(column: sort.column, ascending: sort.ascending), sort)
        }
        XCTAssertEqual(LibrarySort(column: .modified, ascending: false), .modifiedNewest)
    }

    private let series = [
        RemoteEntry(name: "10.mkv", isDirectory: false),
        RemoteEntry(name: "2.mkv", isDirectory: false),
        RemoteEntry(name: "1.mkv", isDirectory: false),
        RemoteEntry(name: "1.srt", isDirectory: false),
        RemoteEntry(name: "Extras", isDirectory: true),
    ]

    func testNeighborUsesNaturalOrderAndSkipsNonVideos() {
        XCTAssertEqual(Library.neighbor(of: "2.mkv", in: series, offset: 1)?.name, "10.mkv")
        XCTAssertEqual(Library.neighbor(of: "2.mkv", in: series, offset: -1)?.name, "1.mkv")
        XCTAssertEqual(Library.neighbor(of: "S01E09.mkv", in: [
            RemoteEntry(name: "S01E10.mkv", isDirectory: false),
            RemoteEntry(name: "S01E09.mkv", isDirectory: false),
        ], offset: 1)?.name, "S01E10.mkv")
    }

    func testNeighborIsNilPastEitherEndOrForUnknownName() {
        XCTAssertNil(Library.neighbor(of: "1.mkv", in: series, offset: -1))
        XCTAssertNil(Library.neighbor(of: "10.mkv", in: series, offset: 1))
        XCTAssertNil(Library.neighbor(of: "missing.mkv", in: series, offset: 1))
    }
}
