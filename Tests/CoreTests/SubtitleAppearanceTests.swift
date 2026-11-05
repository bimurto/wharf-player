import XCTest
@testable import Core

final class SubtitleAppearanceTests: XCTestCase {
    func testScaleStepsAndClamps() {
        XCTAssertEqual(SubtitleAppearance.steppedScale(1.0, by: 1), 1.01, accuracy: 1e-9)
        XCTAssertEqual(SubtitleAppearance.steppedScale(1.0, by: -1), 0.99, accuracy: 1e-9)
        XCTAssertEqual(SubtitleAppearance.steppedScale(2.0, by: 1), 2.0)
        XCTAssertEqual(SubtitleAppearance.steppedScale(0.75, by: -1), 0.75)
        XCTAssertEqual(SubtitleAppearance.clampedScale(5), 2.0)
        XCTAssertEqual(SubtitleAppearance.clampedScale(0.1), 0.75)
        XCTAssertFalse(SubtitleAppearance.canStepScale(2.0, by: 1))
        XCTAssertTrue(SubtitleAppearance.canStepScale(2.0, by: -1))
    }

    func testPositionStepsAndClamps() {
        XCTAssertEqual(SubtitleAppearance.steppedPosition(100, up: true), 99)
        XCTAssertEqual(SubtitleAppearance.steppedPosition(99, up: false), 100)
        XCTAssertEqual(SubtitleAppearance.steppedPosition(100, up: false), 100)
        XCTAssertEqual(SubtitleAppearance.steppedPosition(50, up: true), 50)
        XCTAssertEqual(SubtitleAppearance.clampedPosition(200), 100)
        XCTAssertEqual(SubtitleAppearance.clampedPosition(-3), 50)
        XCTAssertFalse(SubtitleAppearance.canStepPosition(100, up: false))
        XCTAssertFalse(SubtitleAppearance.canStepPosition(50, up: true))
    }

    func testLabels() {
        XCTAssertEqual(SubtitleAppearance.scaleLabel(1.0), "100%")
        XCTAssertEqual(SubtitleAppearance.scaleLabel(1.25), "125%")
        XCTAssertEqual(SubtitleAppearance.positionLabel(100), "0%")
        XCTAssertEqual(SubtitleAppearance.positionLabel(90), "10%")
    }

    func testStorePersistsAndDefaults() {
        let suite = "SubtitleAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SubtitleAppearanceStore(defaults: defaults)
        XCTAssertEqual(store.scale, 1.0)
        XCTAssertEqual(store.position, 100)
        store.scale = 1.5
        store.position = 80
        let again = SubtitleAppearanceStore(defaults: defaults)
        XCTAssertEqual(again.scale, 1.5)
        XCTAssertEqual(again.position, 80)
        defaults.set(99.0, forKey: "subtitle_scale")
        XCTAssertEqual(again.scale, 2.0)
        again.reset()
        XCTAssertEqual(again.scale, 1.0)
        XCTAssertEqual(again.position, 100)
    }
}
