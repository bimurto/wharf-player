import XCTest
@testable import Core

final class LibraryPathTests: XCTestCase {
    func testBreadcrumbs() {
        XCTAssertEqual(Breadcrumb.components(of: "/").map(\.path), ["/"])
        let crumbs = Breadcrumb.components(of: "/home/reader/My Shows/")
        XCTAssertEqual(crumbs.map(\.name), ["/", "home", "reader", "My Shows"])
        XCTAssertEqual(crumbs.map(\.path), ["/", "/home", "/home/reader", "/home/reader/My Shows"])
    }

    func testVideoDetectionByExtension() {
        func entry(_ n: String, dir: Bool = false) -> RemoteEntry { RemoteEntry(name: n, isDirectory: dir) }
        XCTAssertTrue(entry("a.MKV").isVideo)
        XCTAssertTrue(entry("[Group] b - 01 (1080p).mp4").isVideo)
        XCTAssertFalse(entry("a.srt").isVideo)
        XCTAssertFalse(entry("noextension").isVideo)
        XCTAssertFalse(entry("Season.mkv", dir: true).isVideo)
    }

    func testDisplayURLHasNoCredentials() {
        let t = SFTPTarget(host: "fixture.invalid", port: 2222, user: "reader", path: "/m/a b.mkv", password: "pw-fixture", passphrase: "phrase")
        XCTAssertEqual(t.displayURL, "sftp://reader@fixture.invalid:2222/m/a b.mkv")
        XCTAssertEqual(SFTPTarget(host: "h.invalid", user: "u", path: "/x").displayURL, "sftp://u@h.invalid/x")
    }
}
