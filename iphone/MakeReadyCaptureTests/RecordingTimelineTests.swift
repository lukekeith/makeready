import XCTest
@testable import MakeReady

/// video-recorder D2–D5: the recording timeline, the pre-roll and the end countdown.
final class RecordingTimelineTests: XCTestCase {

    /// video-polish D13: any whole second in 0:05…2:00, no snapping.
    func testLengthIsClampedNotSnapped() {
        XCTAssertEqual(RecordingTimeline.clampedLength(0), 5)
        XCTAssertEqual(RecordingTimeline.clampedLength(64), 64)
        XCTAssertEqual(RecordingTimeline.clampedLength(94), 94)
        XCTAssertEqual(RecordingTimeline.clampedLength(500), 120)
        XCTAssertEqual(RecordingTimeline(lengthSeconds: 2).lengthSeconds, 5)
    }

    func testEndCountdownAcrossSegments() {
        var t = RecordingTimeline(lengthSeconds: 30, mode: .specify, endCountdownSeconds: 10)
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

    // MARK: video-polish D4, D6

    func testEndCountdownOffByDefault() {
        let t = RecordingTimeline(lengthSeconds: 30, mode: .specify, endCountdownSeconds: 0)
        XCTAssertNil(t.endCountdown(atRecorded: 29))
        XCTAssertNil(RecordingTimeline(lengthSeconds: 30).endCountdown(atRecorded: 29))
    }

    func testEndCountdownAtThreeSeconds() {
        let t = RecordingTimeline(lengthSeconds: 30, mode: .specify, endCountdownSeconds: 3)
        XCTAssertNil(t.endCountdown(atRecorded: 26.5))
        XCTAssertEqual(t.endCountdown(atRecorded: 27.5), 3)
        XCTAssertEqual(t.endCountdown(atRecorded: 29.5), 1)
    }

    func testNoEndCountdownUnderAnyLength() {
        let t = RecordingTimeline(lengthSeconds: 30, mode: .any, endCountdownSeconds: 10)
        XCTAssertNil(t.endCountdown(atRecorded: 115))
        XCTAssertEqual(t.effectiveLength, 120)
        XCTAssertTrue(t.shouldAutoStop(atRecorded: 120))
        XCTAssertFalse(t.shouldAutoStop(atRecorded: 60))
    }

    func testEndCountdownFromStartWhenShorter() {
        let t = RecordingTimeline(lengthSeconds: 5, mode: .specify, endCountdownSeconds: 10)
        XCTAssertEqual(t.endCountdown(atRecorded: 0.1), 5)
    }

    func testAnyLengthBarSpansTheCap() {
        var t = RecordingTimeline(lengthSeconds: 30, mode: .any)
        t.append(60)
        XCTAssertEqual(t.segmentFractions, [0.5])
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
