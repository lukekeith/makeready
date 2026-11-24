//
//  VideoEditSession.swift
//  MakeReady
//
//  The video editor's state: its layers, selection, playhead and undo history (video-editor D3, D4,
//  D13, D14, D15, D24, D25, D30). Every action, and every gesture when it ends, is one history entry
//  and one `onChange` (the draft write); an action that changes nothing is neither.
//

import CoreGraphics
import Foundation
import Observation

@MainActor @Observable
final class VideoEditSession {
    private(set) var layers: [VideoLayer]
    private(set) var selectedId: UUID?
    private(set) var playheadMs = 0

    let clipMs: Int

    @ObservationIgnored private let opened: [VideoLayer]
    @ObservationIgnored private let onChange: ([VideoLayer]) -> Void
    /// The layers before each change, oldest first.
    private var history: [[VideoLayer]] = []
    /// The layers when the running gesture began; nil with no gesture.
    @ObservationIgnored private var gestureStart: [VideoLayer]?

    init(layers: [VideoLayer], clipMs: Int, onChange: @escaping ([VideoLayer]) -> Void) {
        self.layers = layers
        self.opened = layers
        self.clipMs = max(0, clipMs)
        self.onChange = onChange
    }

    // MARK: Reading

    var selected: VideoLayer? { layers.first { $0.id == selectedId } }
    var canUndo: Bool { !history.isEmpty }
    var hasCaptions: Bool { layers.contains { $0.kind == .caption } }
    var canAddText: Bool { textCount < VideoLayer.maxTextLayers }

    /// The playhead is inside the selected layer, 0.5 s clear of both ends; a text layer is not split
    /// at the limit (D13, D15).
    var canSplit: Bool {
        guard let layer = selected, VideoLayerTiming.canSplit(layer, at: playheadMs) else { return false }
        return layer.kind == .caption || canAddText
    }

    private var textCount: Int { layers.filter { $0.kind == .text }.count }

    // MARK: Actions

    func addText(_ text: String, style: VideoLayerStyle) {
        let layer = VideoLayer(kind: .text, text: "", style: style, startMs: 0, endMs: clipMs)
        let clean = Self.clean(text, limit: layer.textLimit)
        guard canAddText, !clean.isEmpty, clipMs > 0 else { return }
        var added = layer
        added.text = clean
        record { $0.append(added) }
        selectedId = added.id
    }

    /// Whitespace-only text deletes the layer. A caption keeps its style (D4, D8).
    func setText(_ id: UUID, text: String, style: VideoLayerStyle) {
        guard let layer = layers.first(where: { $0.id == id }) else { return }
        let clean = Self.clean(text, limit: layer.textLimit)
        guard !clean.isEmpty else { return delete(id) }
        record { layers in
            guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
            layers[i].text = clean
            if layers[i].kind == .text { layers[i].style = style }
        }
    }

    func delete(_ id: UUID) {
        record { $0.removeAll { $0.id == id } }
        clearGoneSelection()
    }

    /// The second half sits directly after the first and is selected (D13, D25).
    func split() {
        guard canSplit, let layer = selected else { return }
        let (first, second) = VideoLayerTiming.split(layer, at: playheadMs)
        record { layers in
            guard let i = layers.firstIndex(where: { $0.id == layer.id }) else { return }
            layers[i] = first
            layers.insert(second, at: i + 1)
        }
        selectedId = second.id
    }

    /// Captions go before every text layer; none are added when captions exist (D4, D25).
    func addCaptions(_ transcript: VideoTranscript) {
        guard !hasCaptions else { return }
        let captions = VideoCaptions.layers(from: transcript, clipMs: clipMs)
        record { $0.insert(contentsOf: captions, at: 0) }
    }

    func removeCaptions() {
        record { $0.removeAll { $0.kind == .caption } }
        clearGoneSelection()
    }

    func undo() {
        endGesture()
        guard let previous = history.popLast() else { return }
        layers = previous
        clearGoneSelection()
        onChange(layers)
    }

    /// Back to the layers as they were when the editor opened (D14).
    func cancel() {
        gestureStart = nil
        history = []
        layers = opened
        clearGoneSelection()
        onChange(layers)
    }

    func select(_ id: UUID?) {
        selectedId = id.flatMap { id in layers.contains { $0.id == id } ? id : nil }
    }

    func seek(_ ms: Int) {
        playheadMs = min(max(ms, 0), clipMs)
    }

    // MARK: Gestures — live until `endGesture`

    func trimStart(_ id: UUID, to ms: Int) {
        live(id) { layer, all in
            VideoLayerTiming.trimStart(layer, to: ms, in: VideoLayerTiming.bounds(of: layer, among: all, clipMs: clipMs))
        }
    }

    func trimEnd(_ id: UUID, to ms: Int) {
        live(id) { layer, all in
            VideoLayerTiming.trimEnd(layer, to: ms, in: VideoLayerTiming.bounds(of: layer, among: all, clipMs: clipMs))
        }
    }

    func slide(_ id: UUID, to ms: Int) {
        live(id) { layer, all in
            VideoLayerTiming.slide(layer, to: ms, in: VideoLayerTiming.bounds(of: layer, among: all, clipMs: clipMs))
        }
    }

    /// A caption is never moved, scaled or rotated (D24).
    func place(_ id: UUID, centre: CGPoint, scale: Double, rotation: Double) {
        live(id) { layer, _ in
            guard layer.kind == .text else { return layer }
            var out = layer
            out.centre = centre
            out.scale = scale
            out.rotation = rotation
            return out
        }
    }

    /// The finger lifted: the gesture is one history entry and one write, if it changed anything.
    func endGesture() {
        guard let start = gestureStart else { return }
        gestureStart = nil
        guard layers != start else { return }
        history.append(start)
        onChange(layers)
    }

    // MARK: Private

    private func live(_ id: UUID, _ change: (VideoLayer, [VideoLayer]) -> VideoLayer) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        if gestureStart == nil { gestureStart = layers }
        layers[i] = change(layers[i], layers)
    }

    /// One history entry and one `onChange` for `change`, when it changes the layers.
    private func record(_ change: (inout [VideoLayer]) -> Void) {
        endGesture()
        var after = layers
        change(&after)
        guard after != layers else { return }
        history.append(layers)
        layers = after
        onChange(after)
    }

    private func clearGoneSelection() {
        if let id = selectedId, !layers.contains(where: { $0.id == id }) { selectedId = nil }
    }

    /// Trimmed of whitespace and newlines, cut at the limit.
    private static func clean(_ text: String, limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
