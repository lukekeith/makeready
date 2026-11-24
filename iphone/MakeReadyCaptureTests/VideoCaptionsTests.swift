//
//  VideoCaptionsTests.swift
//  MakeReadyCaptureTests
//
//  Captions from a transcript and the corrected transcript sent at Save (video-editor D4, D12,
//  D24, D26).
//

import XCTest
@testable import MakeReady

final class VideoCaptionsTests: XCTestCase {
    private func seg(_ text: String, _ start: Int, _ end: Int) -> VideoTranscriptSegment {
        VideoTranscriptSegment(text: text, startMs: start, endMs: end)
    }

    func testLayers() {
        let long = String(repeating: "word", count: 60)
        let t = VideoTranscript(text: "x", segments: [seg(" Hello ", 0, 1200), seg("there", 1000, 2000), seg("  ", 2000, 2500), seg("in", 1100, 1900), seg(long, 2600, 9999)])
        let layers = VideoCaptions.layers(from: t, clipMs: 5000)
        XCTAssertEqual(layers.map(\.text), ["Hello", "there", long])
        XCTAssertEqual(layers.map { [$0.startMs, $0.endMs] }, [[0, 1200], [1200, 2000], [2600, 5000]])
        XCTAssertEqual(layers.map(\.sourceSegment), [0, 1, 4])
        XCTAssertTrue(layers.allSatisfy { $0.kind == .caption && $0.style == VideoCaptions.style && $0.centre == VideoCaptions.centre })
    }

    func testCorrected() {
        let t = VideoTranscript(text: "Jon three then rest", segments: [seg("Jon three", 0, 1000), seg("then", 1000, 2000), seg("rest", 2000, 3000)])
        var layers = VideoCaptions.layers(from: t, clipMs: 3000)
        layers[0].text = "John 3"
        layers.remove(at: 1)
        layers[1] = VideoLayerTiming.trimEnd(layers[1], to: 2600, in: 0...3000)
        XCTAssertEqual(layers[1].endMs, 2600)
        let out = VideoCaptions.corrected(t, with: layers)
        XCTAssertEqual(out.segments, [seg("John 3", 0, 1000), seg("then", 1000, 2000), seg("rest", 2000, 3000)])
        XCTAssertEqual(out.text, "John 3 then rest")
    }

    func testCorrectedAfterASplit() {
        let t = VideoTranscript(text: "Jon three sixteen", segments: [seg("Jon three sixteen", 0, 4000)])
        var (a, b) = VideoLayerTiming.split(VideoCaptions.layers(from: t, clipMs: 4000)[0], at: 2000)
        XCTAssertEqual(VideoCaptions.corrected(t, with: [a, b]).text, "Jon three sixteen")
        a.text = "John"
        XCTAssertEqual(VideoCaptions.corrected(t, with: [a, b]).text, "John")
        b.text = "3:16"
        XCTAssertEqual(VideoCaptions.corrected(t, with: [b, a]).text, "John 3:16")
        XCTAssertEqual(VideoCaptions.corrected(t, with: []), t)
    }
}
