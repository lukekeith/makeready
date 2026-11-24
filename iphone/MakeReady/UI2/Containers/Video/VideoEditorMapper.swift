//
//  VideoEditorMapper.swift
//  MakeReady
//
//  The editor model's values as d2m's `VideoEditorScreen.State`, and a style both ways (video-editor
//  D3, D13, D14, D22, D24). Pure, so it tests without a screen.
//

import CoreGraphics
import Foundation

@MainActor
enum VideoEditorMapper {
    typealias Screen = VideoEditorScreen.State

    /// `filmstrip` is the state's catalog-URL form; the app passes real frames to the screen instead.
    static func state(of model: VideoEditorModel, filmstrip: [String]) -> Screen {
        guard let session = model.session else { return Screen() }
        var state = Screen()
        state.layers = ordered(session.layers).map(layer)
        state.selectedID = session.selectedId?.uuidString
        state.playheadMs = session.playheadMs
        state.durationMs = session.clipMs
        state.playing = model.isPlaying
        let frame = model.clip.frame
        if frame.width > 0, frame.height > 0 { state.frameAspectRatio = Double(frame.width / frame.height) }
        state.filmstrip = filmstrip
        state.canUndo = session.canUndo
        state.canSplit = session.canSplit
        state.captions = captions(model.captions)
        state.captionsReason = model.captions == .unavailable ? model.captionsReason : ""
        state.limitMessage = model.limitMessage ?? ""
        state.textTool = model.textTool.map {
            Screen.TextTool(text: $0.text, style: style($0.style), stylePanels: $0.offersStyle)
        }
        state.confirm = model.confirmsCancel ? .cancel : model.offersRemoveCaptions ? .removeCaptions : .none
        return state
    }

    /// "Title, 0:00 to 0:12": seconds rounded down (D3).
    static func trackLabel(_ layer: VideoLayer) -> String {
        "\(layer.text), \(clock(layer.startMs)) to \(clock(layer.endMs))"
    }

    static func style(_ style: VideoLayerStyle) -> Screen.Style {
        Screen.Style(
            font: style.font.rawValue, weight: style.weight, size: style.size, color: style.colour,
            label: Screen.Style.Label(rawValue: style.background.rawValue) ?? .none,
            alignment: Screen.Style.Alignment(rawValue: style.alignment.rawValue) ?? .center)
    }

    static func style(_ style: Screen.Style) -> VideoLayerStyle {
        let standard = VideoLayerStyle.standard
        return VideoLayerStyle(
            font: .init(rawValue: style.font) ?? standard.font,
            weight: VideoLayerStyle.weights.contains(style.weight) ? style.weight : standard.weight,
            size: style.size, colour: style.color,
            background: .init(rawValue: style.label.rawValue) ?? standard.background,
            alignment: .init(rawValue: style.alignment.rawValue) ?? standard.alignment)
    }

    // MARK: Private

    /// Captions first in time order, then text layers oldest to newest (d2m's order).
    private static func ordered(_ layers: [VideoLayer]) -> [VideoLayer] {
        layers.filter { $0.kind == .caption }.sorted { $0.startMs < $1.startMs } + layers.filter { $0.kind == .text }
    }

    private static func layer(_ layer: VideoLayer) -> Screen.Layer {
        Screen.Layer(
            id: layer.id.uuidString, kind: layer.kind == .caption ? .caption : .text, text: layer.text,
            style: style(layer.style), centre: layer.centre, scale: layer.scale, rotation: layer.rotation,
            startMs: layer.startMs, endMs: layer.endMs)
    }

    private static func captions(_ captions: VideoEditorModel.Captions) -> Screen.Captions {
        switch captions {
        case .off: .none
        case .transcribing: .transcribing
        case .added: .added
        case .unavailable: .unavailable
        }
    }

    private static func clock(_ ms: Int) -> String {
        let seconds = max(0, ms) / 1000
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
