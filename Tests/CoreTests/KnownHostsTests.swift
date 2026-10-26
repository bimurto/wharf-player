import XCTest
@testable import Core

final class KnownHostsTests: XCTestCase {
    private let file = """
    fixture.invalid ssh-ed25519 AAAAfixture1
    [fixture.invalid]:2222 ssh-ed25519 AAAAfixture2
    other.invalid,10.0.0.9 ssh-ed25519 AAAAfixture3

    """

    func testRemovesOnlyTheDefaultPortEntry() {
        let out = KnownHosts.removing(host: "fixture.invalid", port: 22, from: file)
        XCTAssertFalse(out.contains("AAAAfixture1"))
        XCTAssertTrue(out.contains("AAAAfixture2"))
        XCTAssertTrue(out.contains("AAAAfixture3"))
    }

    func testRemovesOnlyThePortSpecificEntry() {
        let out = KnownHosts.removing(host: "fixture.invalid", port: 2222, from: file)
        XCTAssertTrue(out.contains("AAAAfixture1"))
        XCTAssertFalse(out.contains("AAAAfixture2"))
    }

    func testRemovesEntryListedAmongSeveralNames() {
        let out = KnownHosts.removing(host: "OTHER.invalid", port: 22, from: file)
        XCTAssertFalse(out.contains("AAAAfixture3"))
        XCTAssertTrue(out.contains("AAAAfixture1"))
    }

    func testUnknownHostLeavesFileUnchanged() {
        XCTAssertEqual(KnownHosts.removing(host: "nope.invalid", port: 22, from: file), file)
    }

    func testHostKeyAndAuthFailuresAreNotRetryable() {
        XCTAssertTrue(Failure("connect: timeout").retryable)
        XCTAssertFalse(Failure("authentication failed", retryable: false).retryable)
        let fp = HostKeyFingerprint(host: "fixture.invalid", port: 2222, keyType: "ssh-ed25519", sha256: "SHA256:fixture")
        XCTAssertEqual(fp.hostLabel, "fixture.invalid:2222")
        XCTAssertNil(Failure("plain").hostKey)
    }
}
