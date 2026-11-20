//
//  MemoTranscriberTests.swift
//  MakeReadyCaptureTests
//
//  The unavailable path: no analyzer starts and nothing throws (D5, D21). Live transcription is
//  proven on a device only (F1).
//

import Speech
import XCTest
@testable import MakeReady

final class MemoTranscriberTests: XCTestCase {
    func testUnavailableStartsNothingAndReturnsNil() async throws {
        let t = MemoTranscriber(availability: .unavailable)
        let (stream, _) = AsyncStream<AnalyzerInput>.makeStream()
        let started = await t.startLive(stream: stream)
        XCTAssertFalse(started)
        XCTAssertNil(t.analyzerFormat)
        let finished = await t.finish()
        XCTAssertNil(finished)
    }

    func testTranscribeFileReturnsNilWhenAssetsUnavailable() async throws {
        let url = try MemoAudioFixtures.sineCAF(seconds: 1)
        let result = await MemoTranscriber(availability: .unavailable).transcribeFile(url)
        XCTAssertNil(result)
    }

    func testTranscriptJoinsResultsWithOneSpaceAndKeepsOneSegmentEach() {
        let pieces = [
            MemoTranscriber.Piece(text: "hello there", startMs: 0, endMs: 1_200),
            MemoTranscriber.Piece(text: "general", startMs: 1_500, endMs: 2_050)
        ]
        let transcript = MemoTranscriber.transcript(from: pieces)
        XCTAssertEqual(transcript?.text, "hello there general")
        XCTAssertEqual(transcript?.segments, [
            TranscriptSegment(text: "hello there", startMs: 0, endMs: 1_200),
            TranscriptSegment(text: "general", startMs: 1_500, endMs: 2_050)
        ])
    }

    func testTranscriptIsNilWhenNothingWasSaid() {
        XCTAssertNil(MemoTranscriber.transcript(from: []))
        XCTAssertNil(MemoTranscriber.transcript(from: [MemoTranscriber.Piece(text: "", startMs: 0, endMs: 10)]))
    }
}
