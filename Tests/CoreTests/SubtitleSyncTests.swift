import XCTest
@testable import Core

final class SubtitleSyncTests: XCTestCase {
    func testStepMovesByHalfSecond() {
        XCTAssertEqual(SubtitleSync.stepped(0, by: 1), 0.5)
        XCTAssertEqual(SubtitleSync.stepped(0, by: -1), -0.5)
        XCTAssertEqual(SubtitleSync.stepped(1.5, by: -1), 1.0)
    }

    func testClampsToFiveSeconds() {
        XCTAssertEqual(SubtitleSync.stepped(5, by: 1), 5)
        XCTAssertEqual(SubtitleSync.stepped(-5, by: -1), -5)
        XCTAssertEqual(SubtitleSync.clamped(12), 5)
        XCTAssertEqual(SubtitleSync.clamped(-12), -5)
    }

    func testSnapsOffGridValuesToStep() {
        XCTAssertEqual(SubtitleSync.stepped(0.3, by: 1), 1.0)
        XCTAssertEqual(SubtitleSync.stepped(0.3, by: -1), 0)
    }

    func testLabel() {
        XCTAssertEqual(SubtitleSync.label(1.5), "+1.5 s")
        XCTAssertEqual(SubtitleSync.label(-0.5), "-0.5 s")
        XCTAssertEqual(SubtitleSync.label(0), "0.0 s")
        XCTAssertEqual(SubtitleSync.label(-0.0001), "0.0 s")
    }

    func testBoundsFlags() {
        XCTAssertTrue(SubtitleSync.canStep(4.5, by: 1))
        XCTAssertFalse(SubtitleSync.canStep(5, by: 1))
        XCTAssertFalse(SubtitleSync.canStep(-5, by: -1))
        XCTAssertTrue(SubtitleSync.canStep(-5, by: 1))
    }
}
