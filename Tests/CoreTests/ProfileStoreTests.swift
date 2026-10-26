import XCTest
@testable import Core

final class ProfileStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var secrets: InMemorySecretStore!
    private var store: ProfileStore!

    override func setUp() {
        suite = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        secrets = InMemorySecretStore()
        store = ProfileStore(defaults: defaults, secrets: secrets)
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    private func profile(_ label: String = "Box", auth: ConnectionProfile.Auth = .password) -> ConnectionProfile {
        ConnectionProfile(label: label, host: "fixture.invalid", username: "reader", auth: auth)
    }

    func testSaveAndLoadRoundTrip() {
        let p = profile(auth: .key(path: "/keys/id_fixture"))
        store.save(p)
        XCTAssertEqual(store.all(), [p])
    }

    func testSaveWithSameIdReplaces() {
        var p = profile()
        store.save(p)
        p.label = "Renamed"
        store.save(p)
        XCTAssertEqual(store.all().map(\.label), ["Renamed"])
    }

    func testSecretIsNotWrittenToDefaults() {
        let p = profile()
        store.save(p, secret: "hunter2-fixture")
        let raw = String(data: defaults.data(forKey: "sftp_profiles")!, encoding: .utf8)!
        XCTAssertFalse(raw.contains("hunter2-fixture"))
        XCTAssertEqual(store.secret(for: p), "hunter2-fixture")
    }

    func testNilSecretKeepsAndEmptySecretClears() {
        let p = profile()
        store.save(p, secret: "one")
        store.save(p)
        XCTAssertEqual(store.secret(for: p), "one")
        store.save(p, secret: "")
        XCTAssertNil(store.secret(for: p))
    }

    func testDeleteRemovesProfileAndSecret() {
        let p = profile()
        store.save(p, secret: "one")
        store.delete(p)
        XCTAssertTrue(store.all().isEmpty)
        XCTAssertNil(secrets.secret(for: p.id))
    }

    func testURLNeverContainsCredentials() {
        var p = profile()
        store.save(p, secret: "hunter2-fixture")
        XCTAssertEqual(p.url(), "sftp://reader@fixture.invalid/")
        XCTAssertFalse(p.url().contains("hunter2"))
        p.port = 2222
        p.defaultDirectory = "media/shows"
        XCTAssertEqual(p.url(), "sftp://reader@fixture.invalid:2222/media/shows")
        XCTAssertEqual(p.url(path: "/a b/[x].mkv"), "sftp://reader@fixture.invalid:2222/a b/[x].mkv")
    }

    func testKeychainRoundTripAndClear() {
        let keychain = KeychainSecretStore(service: "com.bimurto.sftp-media-player.tests.\(UUID().uuidString)")
        let id = UUID()
        defer { keychain.setSecret(nil, for: id) }
        keychain.setSecret("one", for: id)
        XCTAssertEqual(keychain.secret(for: id), "one")
        keychain.setSecret("two", for: id)
        XCTAssertEqual(keychain.secret(for: id), "two")
        keychain.setSecret(nil, for: id)
        XCTAssertNil(keychain.secret(for: id))
    }
}
