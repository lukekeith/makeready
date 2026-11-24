//
//  VideoEditorModelTests.swift
//  MakeReadyCaptureTests
//
//  The editor without a screen: playback, the text tool, captions and leaving (video-editor D3, D4,
//  D7, D8, D11, D14, D15, D20, D21, D23, D30).
//

import XCTest
@testable import MakeReady

@MainActor
final class VideoEditorModelTests: XCTestCase {
    private var player = ReviewPlayerSpy()
    private var saves: [(layers: [VideoLayer], transcript: VideoTranscript?)] = []
    private var finished: [[VideoLayer]] = []
    private var asked = 0
    private var released = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private let t = VideoTranscript(text: "a b", segments: [
        VideoTranscriptSegment(text: "a", startMs: 0, endMs: 1000),
        VideoTranscriptSegment(text: "b", startMs: 1000, endMs: 2000),
    ])

    override func setUp() {
        player = ReviewPlayerSpy()
        saves = []
        finished = []
        asked = 0
    }

    private func release() {
        released = true
        waiting.forEach { $0.resume() }
        waiting = []
    }

    /// A 10 s clip. Each transcription takes the next answer; `held` ones wait for `release`.
    private func make(_ layers: [VideoLayer] = [], answers: [VideoTranscript?] = [], held: Bool = false) -> VideoEditorModel {
        released = false
        waiting = []
        var remaining = answers
        return VideoEditorModel(
            clip: .init(urls: [URL(fileURLWithPath: "/tmp/a.mov")], window: nil, duration: 10,
                        frame: CGSize(width: 1080, height: 1920), look: VideoLook()),
            layers: layers,
            transcript: nil,
            player: player,
            transcribe: { [weak self] in
                guard let self else { return nil }
                self.asked += 1
                let answer = remaining.isEmpty ? nil : remaining.removeFirst()
                if held, !self.released { await withCheckedContinuation { self.waiting.append($0) } }
                return answer
            },
            save: { [weak self] in self?.saves.append(($0, $1)) },
            report: { _ in },
            sleep: { _ in throw CancellationError() }
        )
    }

    func testCaptions() async {
        let m = make(answers: [t])
        m.captionsTapped(); XCTAssertEqual(m.captions, .transcribing)
        m.captionsTapped(); await m.captionsSettled()
        XCTAssertEqual(m.captions, .added); XCTAssertEqual(m.session.layers.map(\.text), ["a", "b"]); XCTAssertEqual(saves.last?.transcript, t)
        m.captionsTapped(); XCTAssertTrue(m.offersRemoveCaptions)
        m.removeCaptionsConfirmed(); XCTAssertEqual(m.captions, .off); XCTAssertEqual(m.session.layers, [])
        m.captionsTapped(); XCTAssertEqual(m.captions, .added)
        m.cancelTapped(); XCTAssertTrue(m.confirmsCancel)
        m.cancelConfirmed()
        XCTAssertTrue(m.isClosed); XCTAssertEqual(saves.last?.layers, []); XCTAssertEqual(saves.last?.transcript, t); XCTAssertEqual(asked, 1)
    }

    func testCaptionsUnavailable() async {
        let m = make(answers: [nil, VideoTranscript(text: " ", segments: []), t])
        for expected in [VideoEditorModel.Captions.unavailable, .unavailable, .added] {
            XCTAssertTrue(saves.isEmpty); XCTAssertFalse(m.session.canUndo)
            m.captionsTapped(); await m.captionsSettled()
            XCTAssertEqual(m.captions, expected)
        }
    }

    func testLeavingCancelsTranscribing() async {
        for leave in [{ (m: VideoEditorModel) in m.backgrounded() }, { $0.doneTapped() }, { $0.cancelTapped() }] {
            let m = make(answers: [t], held: true)
            m.captionsTapped(); leave(m)
            XCTAssertEqual(m.captions, .off)
            release(); await m.captionsSettled()
            XCTAssertEqual(m.session.layers, []); XCTAssertTrue(saves.isEmpty)
        }
    }

    func testPlayback() {
        let m = make(); m.open()
        XCTAssertFalse(player.loops || player.autoplays)
        m.playTapped(); player.currentTime = 1.25; m.tick()
        XCTAssertEqual(m.session.playheadMs, 1250)
        m.scrub(toMs: 2000); XCTAssertFalse(m.isPlaying); XCTAssertEqual(player.seeks.last, 2)
        m.playTapped(); player.onEnd?()
        XCTAssertFalse(m.isPlaying); XCTAssertEqual(m.session.playheadMs, 10_000)
        m.playTapped(); m.textTapped(); XCTAssertFalse(m.isPlaying)
        m.commitText("Hi", style: .standard)
        m.playTapped(); m.backgrounded(); XCTAssertFalse(m.isPlaying)
        XCTAssertTrue(player.shownLayers.isEmpty)
    }

    func testTextTool() async {
        let m = make(answers: [t])
        m.textTapped(); XCTAssertEqual(m.textTool?.text, "")
        m.commitText("Title", style: .standard); XCTAssertNil(m.textTool)
        m.editTapped(); XCTAssertEqual(m.textTool?.text, "Title"); XCTAssertEqual(m.textTool?.offersStyle, true)
        m.commitText("", style: .standard); XCTAssertEqual(m.session.layers, [])
        m.captionsTapped(); await m.captionsSettled()
        m.session.select(m.session.layers[0].id); m.editTapped(); XCTAssertEqual(m.textTool?.offersStyle, false)
        m.commitText("A", style: .standard)
        for i in 0..<20 { m.textTapped(); m.commitText("t\(i)", style: .standard) }
        XCTAssertNil(m.limitMessage)
        m.textTapped(); XCTAssertNil(m.textTool); XCTAssertEqual(m.limitMessage, "Up to 20 text layers")
    }

    func testLeaving() {
        let m = make(); m.onFinished = { [unowned self] in finished.append($0) }
        m.cancelTapped(); m.doneTapped()
        XCTAssertFalse(m.confirmsCancel); XCTAssertEqual(finished, [[]]); XCTAssertEqual(player.stops, 1)
        let n = make(); n.textTapped(); n.commitText("Title", style: .standard)
        n.cancelTapped(); n.dismissConfirm(); XCTAssertFalse(n.isClosed)
        n.doneTapped(); XCTAssertEqual(saves.last?.layers.map(\.text), ["Title"])
    }
}
