//
//  MemoModelsTests.swift
//  MakeReadyCaptureTests
//
//  Voice-memo wire types against the frozen §Contract, and the D27 Info.plist strings.
//

import XCTest
@testable import MakeReady

final class MemoModelsTests: XCTestCase {
    func testVoiceMemoDecodesTheDetailPayloadWithFractionalDates() throws {
        let json = #"{"id":"m1","title":"Memo 1","url":"https://s.test/g","urlExpiresAt":"2026-11-20T11:30:00.123Z","mimeType":"audio/mp4","fileSize":5000,"durationMs":1000,"waveformPeaks":[0.1,0.5],"transcript":"hi","transcriptSegments":[{"text":"hi","startMs":0,"endMs":500}],"transcriptStatus":"ready","transcriptSource":"on_device","uploadStatus":"ready","recordedAt":"2026-11-20T10:30:00.123Z","createdAt":"2026-11-20T10:30:01.000Z","updatedAt":"2026-11-20T10:30:02.456Z"}"#
        let memo = try JSONDecoder.apiDecoder.decode(VoiceMemo.self, from: Data(json.utf8))
        XCTAssertEqual(memo.transcriptSegments, [TranscriptSegment(text: "hi", startMs: 0, endMs: 500)])
        XCTAssertEqual(memo.transcriptStatus, .ready)
        XCTAssertEqual(memo.recordedAt.timeIntervalSince1970, 1_795_170_600.123, accuracy: 0.001)
    }

    func testSummaryDecodesNullsAndUnknownStatus() throws {
        let json = #"{"id":"m2","title":"Memo 2","mimeType":"audio/mp4","fileSize":null,"durationMs":null,"transcriptPreview":null,"transcriptStatus":"processing","transcriptSource":null,"uploadStatus":"ready","recordedAt":"2026-11-20T10:30:00.000Z","createdAt":"2026-11-20T10:30:00.000Z","updatedAt":"2026-11-20T10:30:00.000Z"}"#
        let s = try JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(json.utf8))
        XCTAssertEqual(s.transcriptStatus, .unknown)
        XCTAssertNil(s.transcriptPreview)
    }

    func testInfoPlistCarriesTheD27Strings() {
        let info = Bundle.main.infoDictionary!
        XCTAssertEqual(info["NSMicrophoneUsageDescription"] as? String, "MakeReady uses the microphone to record videos and voice memos.")
        XCTAssertEqual(info["NSSpeechRecognitionUsageDescription"] as? String, "MakeReady turns your voice memos into text on your iPhone.")
    }
}
