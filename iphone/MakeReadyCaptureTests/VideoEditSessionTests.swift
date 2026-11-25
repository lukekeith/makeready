//
//  VideoEditSessionTests.swift
//  MakeReadyCaptureTests
//
//  The edit session's layers, selection and undo history (video-editor D3, D4, D8, D13, D14, D15,
//  D24, D25, D30).
//

import XCTest
@testable import MakeReady

@MainActor
final class VideoEditSessionTests: XCTestCase {
    private var saved: [[VideoLayer]] = []
    private let transcript = VideoTranscript(text: "a b", segments: [
        VideoTranscriptSegment(text: "a", startMs: 0, endMs: 1000),
        VideoTranscriptSegment(text: "b", startMs: 1000, endMs: 2000),
    ])

    override func setUp() { saved = [] }

    private func make(_ layers: [VideoLayer] = []) -> VideoEditSession {
        VideoEditSession(layers: layers, clipMs: 10_000) { [weak self] in self?.saved.append($0) }
    }

    func testUndoStepsBackThroughEveryAction() throws {
        let s = make()
        var before: [[VideoLayer]] = []
        func act(_ body: () -> Void) { before.append(s.layers); body(); XCTAssertNotEqual(s.layers, before.last) }
        act { s.addText("Title", style: .standard) }
        let id = try XCTUnwrap(s.selectedId)
        act { s.setText(id, text: "Titles", style: .standard) }
        act { for x in [0.4, 0.2] { s.place(id, centre: CGPoint(x: x, y: 0.2), scale: 1.5, rotation: 0.3) }; s.endGesture() }
        act { s.trimEnd(id, to: 5000); s.trimEnd(id, to: 4000); s.endGesture() }
        act { s.slide(id, to: 2000); s.endGesture() }
        act { s.seek(3000); s.split() }
        act { s.delete(id) }
        act { s.addCaptions(transcript) }
        act { s.removeCaptions() }
        XCTAssertEqual(saved.count, 9)
        for expected in before.reversed() { s.undo(); XCTAssertEqual(s.layers, expected) }
        XCTAssertFalse(s.canUndo); XCTAssertNil(s.selectedId)
    }

    func testNoChangeAndCancel() {
        let opened = [VideoLayer(kind: .text, text: "A", startMs: 0, endMs: 10_000)]
        let s = make(opened)
        s.setText(opened[0].id, text: "A", style: opened[0].style)
        s.slide(opened[0].id, to: 500); s.endGesture()
        s.addText("   ", style: .standard)
        XCTAssertFalse(s.canUndo); XCTAssertEqual(saved, [])
        s.addText("B", style: .standard); s.delete(opened[0].id); s.cancel()
        XCTAssertEqual(s.layers, opened); XCTAssertEqual(saved.last, opened); XCTAssertFalse(s.canUndo)
    }

    func testOrderAndCaptionRules() {
        let s = make()
        s.addText("one", style: .standard); s.addText("two", style: .standard); s.addCaptions(transcript); s.addCaptions(transcript)
        XCTAssertEqual(s.layers.map(\.text), ["a", "b", "one", "two"])
        let a = s.layers[0]
        s.place(a.id, centre: .zero, scale: 3, rotation: 1); s.slide(a.id, to: 800); s.endGesture()
        XCTAssertEqual(s.layers[0], a, "b starts where a ends")
        s.setText(a.id, text: "A!", style: VideoLayerStyle.standard)
        XCTAssertEqual(s.layers[0].text, "A!"); XCTAssertEqual(s.layers[0].style, a.style)
        s.select(s.layers[2].id); s.seek(5000); s.split()
        XCTAssertEqual(s.layers.map(\.text), ["A!", "b", "one", "one", "two"])
        XCTAssertEqual(s.selectedId, s.layers[3].id)
        s.setText(s.layers[4].id, text: " ", style: .standard)
        XCTAssertEqual(s.layers.count, 4)
    }

    func testScaleIsClamped() throws {
        let s = make()
        s.addText("T", style: .standard)
        let id = try XCTUnwrap(s.selectedId)
        let scales = [40, 10, 0.1, 0.001, -2, .nan].map { scale in
            s.place(id, centre: .zero, scale: scale, rotation: 0)
            return s.layers[0].scale
        }
        XCTAssertEqual(scales, [10, 10, 0.1, 0.1, 0.1, 0.1], "a scale that is no number changes nothing")
    }

    func testLimits() {
        let s = make()
        s.addCaptions(transcript)
        for i in 0..<21 { XCTAssertEqual(s.canAddText, i < 20); s.addText("t\(i)", style: .standard) }
        s.seek(5000); XCTAssertEqual(s.layers.count, 22); XCTAssertFalse(s.canSplit)
        s.setText(s.layers[2].id, text: String(repeating: "x", count: 300), style: .standard); XCTAssertEqual(s.layers[2].text.count, 200)
        s.select(s.layers[0].id); s.seek(500); XCTAssertTrue(s.canSplit)
        s.seek(99_999); XCTAssertEqual(s.playheadMs, 10_000)
    }

    // MARK: video-polish D12 — snapping

    private func text(_ start: Int, _ end: Int) -> VideoLayer {
        VideoLayer(kind: .text, text: "T", startMs: start, endMs: end)
    }

    private func make(clipMs: Int, _ layers: [VideoLayer]) -> VideoEditSession {
        VideoEditSession(layers: layers, clipMs: clipMs) { _ in }
    }

    func testTrimSnapsToOtherLayerEdgeAndPlayhead() {
        let s = make(clipMs: 20_000, [text(0, 4_000), text(6_000, 9_000)])
        s.seek(12_000)
        let id = s.layers[1].id
        s.trimEnd(id, to: 11_880)
        XCTAssertEqual(s.layers[1].endMs, 12_000)
        XCTAssertEqual(s.snappedTo, 12_000)
        s.endGesture()
        XCTAssertNil(s.snappedTo)
        s.trimStart(id, to: 4_120)
        XCTAssertEqual(s.layers[1].startMs, 4_000)
    }

    func testSnapHoldsUntilRelease() {
        let s = make(clipMs: 20_000, [text(0, 4_000), text(6_000, 9_000)])
        let id = s.layers[1].id
        s.trimStart(id, to: 4_150)
        XCTAssertEqual(s.layers[1].startMs, 4_000)
        s.trimStart(id, to: 4_280)
        XCTAssertEqual(s.layers[1].startMs, 4_000, "held within 300 ms")
        s.trimStart(id, to: 4_320)
        XCTAssertEqual(s.layers[1].startMs, 4_320)
        XCTAssertNil(s.snappedTo)
    }

    func testSlideSnapsNearerEdge() {
        let s = make(clipMs: 20_000, [text(0, 4_000), text(10_000, 13_000)])
        let id = s.layers[1].id
        s.slide(id, to: 4_150)
        XCTAssertEqual(s.layers[1].startMs, 4_000)
        XCTAssertEqual(s.layers[1].endMs, 7_000)
        s.endGesture()
        s.slide(id, to: 16_900)
        XCTAssertEqual(s.layers[1].endMs, 20_000, "the end edge snaps to the clip's end")
    }

    func testTrimNeverPassesClipStart() {
        let s = make(clipMs: 20_000, [text(1_000, 4_000)])
        s.trimStart(s.layers[0].id, to: -800)
        XCTAssertEqual(s.layers[0].startMs, 0)
    }
}
