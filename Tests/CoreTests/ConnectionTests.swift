import XCTest
@testable import Core

final class ConnectionTests: XCTestCase {
    private func profile(host: String = "fixture.invalid", port: Int = 22, user: String = "reader",
                         auth: ConnectionProfile.Auth = .password) -> ConnectionProfile {
        ConnectionProfile(label: "Box", host: host, port: port, username: user, auth: auth)
    }

    func testValidation() {
        XCTAssertNil(profile().validationError)
        XCTAssertNotNil(profile(host: " ").validationError)
        XCTAssertNotNil(profile(user: "").validationError)
        XCTAssertNotNil(profile(port: 0).validationError)
        XCTAssertNotNil(profile(port: 70000).validationError)
        XCTAssertNotNil(profile(auth: .key(path: "")).validationError)
        XCTAssertNil(profile(auth: .key(path: "/keys/id_fixture")).validationError)
    }

    func testPasswordProfileTargetUsesSecretAsPassword() {
        let t = profile().target(path: "/a", secret: "pw-fixture")
        XCTAssertEqual(t.password, "pw-fixture")
        XCTAssertNil(t.passphrase)
        XCTAssertNil(t.keyPath)
        XCTAssertEqual(t.path, "/a")
    }

    func testKeyProfileTargetUsesSecretAsPassphraseAndExpandsTilde() {
        let t = profile(auth: .key(path: "~/.ssh/id_fixture")).target(secret: "phrase-fixture")
        XCTAssertNil(t.password)
        XCTAssertEqual(t.passphrase, "phrase-fixture")
        XCTAssertEqual(t.keyPath, NSHomeDirectory() + "/.ssh/id_fixture")
    }

    func testEmptySecretMeansNoSecret() {
        XCTAssertNil(profile().target(secret: "").password)
        XCTAssertNil(profile().target(secret: nil).password)
    }

    func testWithPathKeepsCredentials() {
        let t = profile().target(secret: "pw-fixture").with(path: "/other")
        XCTAssertEqual(t.password, "pw-fixture")
        XCTAssertEqual(t.path, "/other")
    }

    func testUnreachableHostFailsInsteadOfHanging() async {
        let result = await ConnectionTester.test(SFTPTarget(host: "fixture.invalid", user: "reader"), directory: nil)
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertTrue(failure.description.hasPrefix("connect:"), failure.description)
    }
}
