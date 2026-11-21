import XCTest
@testable import MakeReady

/// memo-screens Task 8 (T3, D4, D16, D17): memo → memo-detail's state.
@MainActor
final class MemoDetailMapperTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// 2026-11-20 11:00 in Chicago.
    private let now = ISO8601DateFormatter().date(from: "2026-11-20T17:00:00Z")!

    private func todayAt(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)!
    }

    private func memo(status: String, segments: [(String, Int)]? = nil, transcript: String? = nil, durationMs: Int? = 42500) -> VoiceMemo {
        let stamp = "2026-11-20T16:00:00.000Z"
        let segmentsJSON = segments.map { list in
            "[" + list.map { #"{"text":"\#($0.0)","startMs":\#($0.1),"endMs":\#($0.1 + 1000)}"# }.joined(separator: ",") + "]"
        } ?? "null"
        let durationJSON = durationMs.map(String.init) ?? "null"
        let transcriptJSON = transcript.map { "\"\($0)\"" } ?? "null"
        let json = #"{"id":"m1","title":"Walk","url":null,"urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":5000,"durationMs":\#(durationJSON),"waveformPeaks":null,"transcript":\#(transcriptJSON),"transcriptSegments":\#(segmentsJSON),"transcriptStatus":"\#(status)","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
        return try! JSONDecoder.apiDecoder.decode(VoiceMemo.self, from: Data(json.utf8))
    }

    private func queued(transcript: Transcript?) -> MemoQueueItem {
        MemoQueueItem(
            localId: "q1", fileName: "q1.m4a", title: "Queued", durationMs: 5_000, waveformPeaks: [],
            recordedAt: "2026-11-20T16:30:00.000Z", transcript: transcript, fileSize: 10, serverId: nil, upload: nil,
            ownerUserId: "u1", environment: "test", attempts: 0, nextAttemptAt: nil)
    }

    private func state(status: String) -> MemoDetailScreen.State {
        MemoDetailMapper.state(memo: memo(status: status), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
    }

    func testSegmentsBecomeParagraphs() {
        let s = MemoDetailMapper.state(memo: memo(status: "ready", segments: [("A.", 0), ("B.", 4_500), ("C.", 8_000)]), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
        XCTAssertEqual(s.transcript, .paragraphs)
        XCTAssertEqual(s.paragraphStarts, [0, 4, 8]); XCTAssertEqual(s.paragraphTexts, ["A.", "B.", "C."])
    }

    func testNoSegmentsFallsBackToOneParagraphFromTranscript() {
        let s = MemoDetailMapper.state(memo: memo(status: "ready", segments: [], transcript: "Whole text."), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
        XCTAssertEqual(s.paragraphStarts, [0]); XCTAssertEqual(s.paragraphTexts, ["Whole text."])
    }

    func testPendingIsTranscribingAndFailedNoneAndUnknownAreUnavailable() {
        XCTAssertEqual(state(status: "pending").transcript, .transcribing)
        for status in ["failed", "none", "somethingNew"] { XCTAssertEqual(state(status: status).transcript, .unavailable) }
    }

    func testAQueuedMemoWithoutAnOnDeviceTranscriptIsTranscribing() {
        XCTAssertEqual(MemoDetailMapper.state(queued: queued(transcript: nil), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar).transcript, .transcribing)
    }

    func testAQueuedMemoUsesItsOnDeviceSegments() {
        let transcript = Transcript(text: "One Two", segments: [TranscriptSegment(text: "One", startMs: 0, endMs: 900), TranscriptSegment(text: "Two", startMs: 3_200, endMs: 4_000)])
        let s = MemoDetailMapper.state(queued: queued(transcript: transcript), elapsed: 1, playing: true, playerReady: false, now: now, calendar: calendar)
        XCTAssertEqual(s.transcript, .paragraphs)
        XCTAssertEqual(s.paragraphStarts, [0, 3]); XCTAssertEqual(s.paragraphTexts, ["One", "Two"])
        XCTAssertEqual(s.title, "Queued"); XCTAssertEqual(s.duration, 5)
        XCTAssertEqual(s.dateLabel, "Today 10:30 AM")
        XCTAssertEqual(s.elapsed, 1); XCTAssertTrue(s.playing); XCTAssertFalse(s.playerReady)
    }

    func testDurationIsSecondsAndZeroWhenUnknown() {
        XCTAssertEqual(state(status: "ready").duration, 42.5)
        let unknown = MemoDetailMapper.state(memo: memo(status: "ready", durationMs: nil), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
        XCTAssertEqual(unknown.duration, 0)
    }

    func testTheMetaDateReadsTodayAndTheTime() {
        XCTAssertEqual(MemoDetailMapper.metaDate(todayAt(19, 43), now: now, calendar: calendar), "Today 7:43 PM")
    }

    func testTheMetaDateNamesYesterdayAndOtherDaysByTheNotesRule() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayAt(9, 5))!
        XCTAssertEqual(MemoDetailMapper.metaDate(yesterday, now: now, calendar: calendar), "Yesterday 9:05 AM")
        let older = calendar.date(byAdding: .day, value: -10, to: todayAt(9, 5))!
        XCTAssertEqual(MemoDetailMapper.metaDate(older, now: now, calendar: calendar), "11/10/26 9:05 AM")
    }
}
