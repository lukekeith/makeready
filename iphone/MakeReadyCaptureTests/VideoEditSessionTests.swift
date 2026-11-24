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

    func testLimits() {
        let s = make()
        s.addCaptions(transcript)
        for i in 0..<21 { XCTAssertEqual(s.canAddText, i < 20); s.addText("t\(i)", style: .standard) }
        s.seek(5000); XCTAssertEqual(s.layers.count, 22); XCTAssertFalse(s.canSplit)
        s.setText(s.layers[2].id, text: String(repeating: "x", count: 300), style: .standard); XCTAssertEqual(s.layers[2].text.count, 200)
        s.select(s.layers[0].id); s.seek(500); XCTAssertTrue(s.canSplit)
        s.seek(99_999); XCTAssertEqual(s.playheadMs, 10_000)
    }
}
