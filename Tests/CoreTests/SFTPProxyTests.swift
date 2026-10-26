import XCTest
@testable import Core

final class SFTPProxyTests: XCTestCase {
    private func makeProxy() throws -> SFTPProxy {
        try XCTUnwrap(SFTPProxy(target: SFTPTarget(host: "fixture.invalid", user: "reader")))
    }

    func testURLEncodesPathAndIncludesToken() throws {
        let proxy = try makeProxy()
        let url = proxy.url(for: "/shows/[Group] Ep 1?.mkv")
        XCTAssertTrue(url.hasPrefix("http://127.0.0.1:\(proxy.port)/"))
        XCTAssertTrue(url.hasSuffix("/shows/%5BGroup%5D%20Ep%201%3F.mkv"), url)
    }

    func testRequestWithoutTokenGets404WithoutOpeningSSH() async throws {
        let proxy = try makeProxy()
        let url = URL(string: "http://127.0.0.1:\(proxy.port)/not-the-token/shows/a.mkv")!
        let (_, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
    }
}
