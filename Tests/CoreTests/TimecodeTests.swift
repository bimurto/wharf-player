import XCTest
@testable import Core

final class TimecodeTests: XCTestCase {
    func testFormats() {
        XCTAssertEqual(Timecode.string(0), "0:00")
        XCTAssertEqual(Timecode.string(65.9), "1:05")
        XCTAssertEqual(Timecode.string(3600), "1:00:00")
        XCTAssertEqual(Timecode.string(1420), "23:40")
    }

    func testBadValuesShowZero() {
        XCTAssertEqual(Timecode.string(-5), "0:00")
        XCTAssertEqual(Timecode.string(.nan), "0:00")
        XCTAssertEqual(Timecode.string(.infinity), "0:00")
    }
}
