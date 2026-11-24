//
//  VideoEditorMapperTests.swift
//  MakeReadyCaptureTests
//
//  The editor model as d2m's screen state, and a style both ways (video-editor D3, D13, D14, D22, D24).
//

import XCTest
@testable import MakeReady

@MainActor
final class VideoEditorMapperTests: XCTestCase {
    private typealias Screen = VideoEditorScreen.State

    /// A 10 s clip over a spy player.
    private func make(_ layers: [VideoLayer]) -> VideoEditorModel {
        VideoEditorModel(
            clip: .init(urls: [URL(fileURLWithPath: "/tmp/a.mov")], window: nil, duration: 10,
                        frame: CGSize(width: 1080, height: 1920), look: VideoLook()),
            layers: layers, transcript: nil, player: ReviewPlayerSpy(),
            transcribe: { nil }, save: { _, _ in }, report: { _ in }, sleep: { _ in throw CancellationError() })
    }

    /// The text layers' tracks, newest on top.
    private func textTracks(_ state: Screen) -> [String] {
        state.layers.filter { $0.kind == .text }.reversed().map(\.text)
    }

    private func captionTrack(_ state: Screen) -> [String] {
        state.layers.filter { $0.kind == .caption }.sorted { $0.startMs < $1.startMs }.map(\.text)
    }

    /// What the preview draws: the layers visible at the playhead.
    private func previewTexts(_ state: Screen) -> [String] {
        state.layers.filter { $0.startMs <= state.playheadMs && state.playheadMs < $0.endMs }.map(\.text)
    }

    func testState() {
        let m = make([VideoLayer(kind: .caption, text: "a", startMs: 0, endMs: 1000), VideoLayer(kind: .text, text: "Old", startMs: 0, endMs: 12_900),
                      VideoLayer(kind: .text, text: "New", startMs: 61_000, endMs: 75_000)])
        var state = VideoEditorMapper.state(of: m, filmstrip: [])
        XCTAssertEqual(textTracks(state), ["New", "Old"]); XCTAssertEqual(captionTrack(state), ["a"]); XCTAssertEqual(previewTexts(state), ["a", "Old"])
        XCTAssertEqual(m.session.layers.dropFirst().map(VideoEditorMapper.trackLabel), ["Old, 0:00 to 0:12", "New, 1:01 to 1:15"])
        XCTAssertFalse(state.canSplit); XCTAssertFalse(state.canUndo)
        m.session.select(m.session.layers[1].id); m.session.seek(5000)
        state = VideoEditorMapper.state(of: m, filmstrip: [])
        XCTAssertTrue(state.canSplit); XCTAssertEqual(previewTexts(state), ["Old"])
        m.session.split()
        XCTAssertTrue(VideoEditorMapper.state(of: m, filmstrip: []).canUndo)
    }

    func testStyleRoundTrip() {
        let styles = VideoLayerStyle.Font.allCases.flatMap { font in
            VideoLayerStyle.Background.allCases.map {
                VideoLayerStyle(font: font, weight: 700, size: 51, colour: "#3EA6FF", background: $0, alignment: .left)
            }
        }
        for s in styles { XCTAssertEqual(VideoEditorMapper.style(VideoEditorMapper.style(s)), s) }
    }
}
