import XCTest
@testable import Core

final class AudioTrackTests: XCTestCase {
    private let json = """
    [
      {"id":1,"type":"video","codec":"h264","selected":true},
      {"id":1,"type":"audio","lang":"eng","title":"Main","codec":"ac3","demux-channels":"5.1(side)","selected":true},
      {"id":2,"type":"audio","lang":"fre","codec":"aac","selected":false},
      {"id":3,"type":"audio","title":"Commentary","selected":false},
      {"id":4,"type":"audio","selected":false},
      {"id":1,"type":"sub","lang":"eng","codec":"subrip","selected":true}
    ]
    """

    func testKeepsOnlyAudioTracks() {
        XCTAssertEqual(AudioTrack.parse(json).map(\.id), [1, 2, 3, 4])
    }

    func testReadsFieldsAndSelection() {
        let tracks = AudioTrack.parse(json)
        XCTAssertEqual(tracks[0].language, "eng")
        XCTAssertEqual(tracks[0].title, "Main")
        XCTAssertEqual(tracks[0].codec, "ac3")
        XCTAssertEqual(tracks[0].channels, "5.1(side)")
        XCTAssertTrue(tracks[0].selected)
        XCTAssertFalse(tracks[1].selected)
    }

    func testLabelCombinesNameAndFormat() {
        let tracks = AudioTrack.parse(json)
        XCTAssertEqual(tracks[0].label, "eng · Main (ac3 5.1(side))")
        XCTAssertEqual(tracks[1].label, "fre (aac)")
        XCTAssertEqual(tracks[2].label, "Commentary")
        XCTAssertEqual(tracks[3].label, "Track 4")
    }

    func testBadInputGivesNoTracks() {
        XCTAssertEqual(AudioTrack.parse(""), [])
        XCTAssertEqual(AudioTrack.parse("not json"), [])
        XCTAssertEqual(AudioTrack.parse("{}"), [])
        XCTAssertEqual(AudioTrack.parse("[]"), [])
    }

    func testAidArgumentIsTrackId() {
        XCTAssertEqual(AudioTrack.aidArgument(3), "3")
    }
}
