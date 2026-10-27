import XCTest
@testable import Core

private final class FakeLister: DirectoryLister, @unchecked Sendable {
    var folders: [String: [RemoteEntry]]
    var failing: Set<String> = []
    private(set) var requested: [String] = []
    private let lock = NSLock()
    init(_ folders: [String: [RemoteEntry]]) { self.folders = folders }

    private func record(_ path: String) { lock.lock(); requested.append(path); lock.unlock() }

    func list(_ path: String) async -> Result<Listing, Failure> {
        record(path)
        guard !failing.contains(path), let entries = folders[path] else { return .failure(Failure("no such folder")) }
        return .success(Listing(path: path, entries: entries))
    }
}

final class ExternalSubtitlesTests: XCTestCase {
    private func dir(_ n: String) -> RemoteEntry { RemoteEntry(name: n, isDirectory: true) }
    private func file(_ n: String) -> RemoteEntry { RemoteEntry(name: n, isDirectory: false) }
    private func names(_ subs: [ExternalSubtitle]) -> [String] { subs.map(\.path) }

    func testSupportsFourFormatsCaseInsensitiveAndIgnoresOthers() {
        let subs = ExternalSubtitles.rank(videoName: "m.mkv", folders: [("/v", [
            file("m.srt"), file("m.VTT"), file("m.ass"), file("m.ssa"), file("m.txt"), file("m.idx"), dir("m.srt"),
        ])])
        XCTAssertEqual(subs.count, 4)
    }

    func testPrefixMatchesComeFirstThenOthers() {
        let subs = ExternalSubtitles.rank(videoName: "Movie.mkv", folders: [("/v", [
            file("Other.srt"), file("movie.en.srt"), file("Movie.srt"),
        ])])
        XCTAssertEqual(names(subs), ["/v/movie.en.srt", "/v/Movie.srt", "/v/Other.srt"])
        XCTAssertEqual(subs.map(\.matchesVideo), [true, true, false])
    }

    func testOwnFolderBeforeSubfolderWithinGroupAndPrefixBeatsFolder() {
        let subs = ExternalSubtitles.rank(videoName: "Movie.mkv", folders: [
            ("/v", [file("Other.srt"), file("Movie.srt")]),
            ("/v/Subs", [file("Movie.en.srt"), file("Another.srt")]),
        ])
        XCTAssertEqual(names(subs), ["/v/Movie.srt", "/v/Subs/Movie.en.srt", "/v/Other.srt", "/v/Subs/Another.srt"])
    }

    func testNaturalNameOrder() {
        let subs = ExternalSubtitles.rank(videoName: "x.mkv", folders: [("/v", [file("s10.srt"), file("s2.srt")])])
        XCTAssertEqual(names(subs), ["/v/s2.srt", "/v/s10.srt"])
    }

    func testRootFolderPaths() {
        let subs = ExternalSubtitles.rank(videoName: "m.mkv", folders: [("/", [file("m.srt")])])
        XCTAssertEqual(names(subs), ["/m.srt"])
    }

    func testDiscoverListsOwnFolderAndSubfoldersAnyCase() async {
        let lister = FakeLister([
            "/v": [file("Movie.mkv"), file("Movie.srt"), dir("SUBS"), dir("subtitles"), dir("Sub"), dir("Extras")],
            "/v/SUBS": [file("Movie.en.ass")],
            "/v/subtitles": [file("Other.vtt")],
            "/v/Sub": [file("Movie.ssa")],
            "/v/Extras": [file("Nope.srt")],
        ])
        let subs = await ExternalSubtitles.discover(videoPath: "/v/Movie.mkv", lister: lister)
        XCTAssertEqual(names(subs), ["/v/Movie.srt", "/v/SUBS/Movie.en.ass", "/v/Sub/Movie.ssa", "/v/subtitles/Other.vtt"])
        XCTAssertFalse(lister.requested.contains("/v/Extras"))
    }

    func testMissingSubfolderDoesNotFail() async {
        let lister = FakeLister(["/v": [file("m.mkv"), file("m.srt")]])
        let subs = await ExternalSubtitles.discover(videoPath: "/v/m.mkv", lister: lister)
        XCTAssertEqual(names(subs), ["/v/m.srt"])
        XCTAssertEqual(lister.requested, ["/v"])
    }

    func testFailingSubfolderIsSkipped() async {
        let lister = FakeLister(["/v": [file("m.srt"), dir("Subs")], "/v/Subs": [file("m.en.srt")]])
        lister.failing = ["/v/Subs"]
        let subs = await ExternalSubtitles.discover(videoPath: "/v/m.mkv", lister: lister)
        XCTAssertEqual(names(subs), ["/v/m.srt"])
    }

    func testUnlistableVideoFolderGivesNothing() async {
        let lister = FakeLister([:])
        let subs = await ExternalSubtitles.discover(videoPath: "/v/m.mkv", lister: lister)
        XCTAssertTrue(subs.isEmpty)
    }

    func testVideoAtRoot() async {
        let lister = FakeLister(["/": [file("m.mkv"), file("m.srt"), dir("Subs")], "/Subs": [file("m2.srt")]])
        let subs = await ExternalSubtitles.discover(videoPath: "/m.mkv", lister: lister)
        XCTAssertEqual(names(subs), ["/m.srt", "/Subs/m2.srt"])
    }

    func testNotLoadedDropsSubtitlesAlreadyAddedToMpv() {
        let a = ExternalSubtitle(path: "/v/Subs/My Movie.en.srt", name: "My Movie.en.srt", matchesVideo: true)
        let b = ExternalSubtitle(path: "/v/Subs/other.srt", name: "other.srt", matchesVideo: false)
        let loaded = SubtitleTrack.parse("""
        [{"id":2,"type":"sub","external":true,"selected":true,
          "external-filename":"http://127.0.0.1:5000/tok/v/Subs/My%20Movie.en.srt"}]
        """)
        XCTAssertEqual(ExternalSubtitles.notLoaded([a, b], tracks: loaded), [b])
        XCTAssertEqual(ExternalSubtitles.notLoaded([a, b], tracks: []), [a, b])
    }

    func testExtensionsCoverTheFourSubtitleFormats() {
        XCTAssertEqual(ExternalSubtitles.extensions, ["srt", "vtt", "ass", "ssa"])
    }
}
