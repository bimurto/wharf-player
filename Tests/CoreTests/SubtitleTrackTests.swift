import XCTest
@testable import Core

final class SubtitleTrackTests: XCTestCase {
    private let json = """
    [
      {"id":1,"type":"video","codec":"h264","selected":true},
      {"id":1,"type":"audio","lang":"eng","selected":true},
      {"id":1,"type":"sub","lang":"eng","title":"Full","codec":"subrip","selected":true,"external":false},
      {"id":2,"type":"sub","lang":"fre","codec":"hdmv_pgs_subtitle","selected":false},
      {"id":3,"type":"sub","title":"Commentary","codec":"ass","selected":false},
      {"id":4,"type":"sub","external":true,"codec":"subrip","selected":false},
      {"id":5,"type":"sub","codec":"subrip","selected":false}
    ]
    """

    func testKeepsSubtitleTracksAndFlagsExternalOnes() {
        let tracks = SubtitleTrack.parse(json)
        XCTAssertEqual(tracks.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(tracks.map(\.external), [false, false, false, true, false])
    }

    func testExternalTrackKeepsTitleAndFilename() {
        let ext = """
        [{"id":2,"type":"sub","external":true,"title":"My Movie.en.srt","codec":"subrip","selected":true,
          "external-filename":"http://127.0.0.1:5000/tok/Subs/My%20Movie.en.srt"}]
        """
        let track = SubtitleTrack.parse(ext)[0]
        XCTAssertEqual(track.label, "My Movie.en.srt")
        XCTAssertEqual(track.externalName, "My Movie.en.srt")
        XCTAssertNil(SubtitleTrack.parse(json)[0].externalName)
    }

    func testSubAddArgumentsSelectWithNameAsTitle() {
        XCTAssertEqual(SubtitleTrack.subAddArguments(url: "http://127.0.0.1:1/t/a.srt", name: "a.srt"),
                       ["sub-add", "http://127.0.0.1:1/t/a.srt", "select", "a.srt"])
    }

    func testReadsFieldsAndSelection() {
        let first = SubtitleTrack.parse(json)[0]
        XCTAssertEqual(first.language, "eng")
        XCTAssertEqual(first.title, "Full")
        XCTAssertEqual(first.codec, "subrip")
        XCTAssertTrue(first.selected)
        XCTAssertFalse(SubtitleTrack.parse(json)[1].selected)
    }

    func testLabelCombinesLanguageAndTitle() {
        let tracks = SubtitleTrack.parse(json)
        XCTAssertEqual(tracks[0].label, "eng · Full")
        XCTAssertEqual(tracks[1].label, "fre")
        XCTAssertEqual(tracks[2].label, "Commentary")
        XCTAssertEqual(tracks[4].label, "Track 5")
    }

    func testBadInputGivesNoTracks() {
        XCTAssertEqual(SubtitleTrack.parse(""), [])
        XCTAssertEqual(SubtitleTrack.parse("not json"), [])
        XCTAssertEqual(SubtitleTrack.parse("{}"), [])
        XCTAssertEqual(SubtitleTrack.parse("[]"), [])
    }

    func testSidArgumentIsTrackIdOrNo() {
        XCTAssertEqual(SubtitleTrack.sidArgument(3), "3")
        XCTAssertEqual(SubtitleTrack.sidArgument(nil), "no")
    }

    func testOffWhenNoTrackSelected() {
        let tracks = SubtitleTrack.parse(json)
        XCTAssertFalse(SubtitleTrack.isOff(tracks))
        XCTAssertTrue(SubtitleTrack.isOff(tracks.map { SubtitleTrack(id: $0.id, language: nil, title: nil, codec: nil, selected: false, external: false) }))
        XCTAssertTrue(SubtitleTrack.isOff([]))
    }
}
