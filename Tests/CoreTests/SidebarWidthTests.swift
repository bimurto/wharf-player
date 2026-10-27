import XCTest
@testable import Core

final class SidebarWidthTests: XCTestCase {
    private func store() -> SidebarWidthStore {
        let defaults = UserDefaults(suiteName: "SidebarWidthTests-\(UUID().uuidString)")!
        return SidebarWidthStore(defaults: defaults)
    }

    func testNothingSavedByDefault() {
        XCTAssertNil(store().saved)
    }

    func testSavedWidthIsRestored() {
        let defaults = UserDefaults(suiteName: "SidebarWidthTests-\(UUID().uuidString)")!
        SidebarWidthStore(defaults: defaults).save(450)
        XCTAssertEqual(SidebarWidthStore(defaults: defaults).saved, 450)
    }

    func testClampsToMinimumAndThreeQuartersOfWindow() {
        XCTAssertEqual(SidebarWidthStore.clamped(100, windowWidth: 1200), 320)
        XCTAssertEqual(SidebarWidthStore.clamped(500, windowWidth: 1200), 500)
        XCTAssertEqual(SidebarWidthStore.clamped(1000, windowWidth: 1200), 900)
    }

    func testSmallWindowNeverGoesBelowMinimum() {
        XCTAssertEqual(SidebarWidthStore.clamped(500, windowWidth: 300), 320)
    }

    func testClampingDoesNotChangeSavedValue() {
        let store = store()
        store.save(800)
        _ = SidebarWidthStore.clamped(store.saved!, windowWidth: 900)
        XCTAssertEqual(store.saved, 800)
    }

    func testArrowKeysStepBy20AndShiftBy50() {
        XCTAssertEqual(SidebarWidthStore.resized(400, .wider, windowWidth: 1200), 420)
        XCTAssertEqual(SidebarWidthStore.resized(400, .narrower, windowWidth: 1200), 380)
        XCTAssertEqual(SidebarWidthStore.resized(400, .wider, large: true, windowWidth: 1200), 450)
        XCTAssertEqual(SidebarWidthStore.resized(400, .narrower, large: true, windowWidth: 1200), 350)
    }

    func testStepsStopAtLimits() {
        XCTAssertEqual(SidebarWidthStore.resized(330, .narrower, large: true, windowWidth: 1200), 320)
        XCTAssertEqual(SidebarWidthStore.resized(890, .wider, large: true, windowWidth: 1200), 900)
    }

    func testHomeAndEndJumpToLimits() {
        XCTAssertEqual(SidebarWidthStore.resized(500, .minimum, windowWidth: 1200), 320)
        XCTAssertEqual(SidebarWidthStore.resized(500, .maximum, windowWidth: 1200), 900)
    }
}
