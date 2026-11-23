import XCTest
@testable import MakeReady

/// video-recorder D2–D5: the recording timeline, the pre-roll and the end countdown.
final class RecordingTimelineTests: XCTestCase {

    func testLengthSnaps() {
        XCTAssertEqual(RecordingTimeline.snappedLength(0), 10)
        XCTAssertEqual(RecordingTimeline.snappedLength(64), 60)
        XCTAssertEqual(RecordingTimeline.snappedLength(66), 70)
        XCTAssertEqual(RecordingTimeline.snappedLength(500), 120)
        XCTAssertEqual(Set(stride(from: 0.0, through: 130, by: 0.5).map(RecordingTimeline.snappedLength)).count, 12)
    }

    func testEndCountdownAcrossSegments() {
        var t = RecordingTimeline(lengthSeconds: 30)
        t.append(15)
        XCTAssertNil(t.endCountdown(atRecorded: t.total + 4.9))
        XCTAssertEqual(t.endCountdown(atRecorded: t.total + 5.01), 10)
        XCTAssertEqual(t.endCountdown(atRecorded: 29.5), 1)
        XCTAssertTrue(t.shouldAutoStop(atRecorded: 30))
        XCTAssertFalse(t.shouldAutoStop(atRecorded: 29.99))
    }

    func testSegments() {
        var t = RecordingTimeline(lengthSeconds: 60)
        XCTAssertTrue(t.canChangeLength)
        t.append(10); t.append(5)
        XCTAssertEqual(t.total, 15); XCTAssertFalse(t.canChangeLength)
        t.deleteLast()
        XCTAssertEqual(t.segments, [10])
        XCTAssertEqual(t.segmentFractions, [10.0 / 60.0])
    }

    func testPreRollBeepsHighOnTheLastSecond() {
        XCTAssertEqual(PreRoll.off.seconds, 0)
        XCTAssertEqual(PreRoll.three.seconds, 3)
        XCTAssertEqual(PreRoll.ten.seconds, 10)
        XCTAssertEqual(PreRoll.three.beepHz(remaining: 3), 1100)
        XCTAssertEqual(PreRoll.three.beepHz(remaining: 2), 1100)
        XCTAssertEqual(PreRoll.three.beepHz(remaining: 1), 1660)
    }
}
