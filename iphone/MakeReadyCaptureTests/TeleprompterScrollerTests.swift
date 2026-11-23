import XCTest
@testable import MakeReady

/// video-recorder D7: the teleprompter position is a function of recorded time only.
final class TeleprompterScrollerTests: XCTestCase {

    func testTeleprompterAcrossPause() {
        let s = TeleprompterScroller(speedStep: 3)
        let atPause = s.offset(atRecorded: 8, lineHeight: 30)
        XCTAssertEqual(s.offset(atRecorded: 8, lineHeight: 30), atPause)
        XCTAssertGreaterThan(s.offset(atRecorded: 8.5, lineHeight: 30), atPause)
        XCTAssertEqual(atPause, 24 * 8, accuracy: 0.001)
    }
}
