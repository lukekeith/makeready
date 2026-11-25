//
//  VideoLayerTiming.swift
//  MakeReady
//
//  Pure trim, slide and split of a video layer's window (video-editor D3, D13, D24). All times are
//  milliseconds on the clip.
//

import Foundation

enum VideoLayerTiming {
    /// The shortest window a trim leaves; a layer already shorter keeps its own length.
    static let minimumMs = 500

    private static func minimumLength(of layer: VideoLayer) -> Int {
        min(minimumMs, layer.endMs - layer.startMs)
    }

    static func trimStart(_ layer: VideoLayer, to ms: Int, in range: ClosedRange<Int>) -> VideoLayer {
        var out = layer
        let latest = max(range.lowerBound, layer.endMs - minimumLength(of: layer))
        out.startMs = min(max(ms, range.lowerBound), latest)
        return out
    }

    static func trimEnd(_ layer: VideoLayer, to ms: Int, in range: ClosedRange<Int>) -> VideoLayer {
        var out = layer
        let earliest = min(range.upperBound, layer.startMs + minimumLength(of: layer))
        out.endMs = max(min(ms, range.upperBound), earliest)
        return out
    }

    /// Moves the window to start at `ms`, keeping its length, clamped to the range.
    static func slide(_ layer: VideoLayer, to ms: Int, in range: ClosedRange<Int>) -> VideoLayer {
        var out = layer
        let length = layer.endMs - layer.startMs
        let latestStart = max(range.lowerBound, range.upperBound - length)
        out.startMs = min(max(ms, range.lowerBound), latestStart)
        out.endMs = out.startMs + length
        return out
    }

    /// 0…clip; a caption's also stop at the nearest captions before and after it (D24).
    static func bounds(of layer: VideoLayer, among layers: [VideoLayer], clipMs: Int) -> ClosedRange<Int> {
        guard layer.kind == .caption else { return 0...max(0, clipMs) }
        let others = layers.filter { $0.kind == .caption && $0.id != layer.id }
        let lower = others.filter { $0.endMs <= layer.startMs }.map(\.endMs).max() ?? 0
        let upper = others.filter { $0.startMs >= layer.endMs }.map(\.startMs).min() ?? clipMs
        return lower...max(lower, upper)
    }

    /// A snap engages within 200 ms (8 pt at the timeline's 40 pt/s) and lets go past 300 ms (12 pt)
    /// — the canvas's hysteresis (video-polish D12).
    static let snapEngageMs = 200
    static let snapReleaseMs = 300

    /// `ms` pulled to the nearest target within the engage distance, or held to `current` while
    /// still within the release distance; otherwise `ms` itself and no target (video-polish D12).
    static func snap(_ ms: Int, targets: [Int], current: Int?) -> (ms: Int, target: Int?) {
        if let current, targets.contains(current), abs(ms - current) <= snapReleaseMs { return (current, current) }
        guard let nearest = targets.min(by: { abs($0 - ms) < abs($1 - ms) }),
              abs(nearest - ms) <= snapEngageMs else { return (ms, nil) }
        return (nearest, nearest)
    }

    static func canSplit(_ layer: VideoLayer, at ms: Int) -> Bool {
        ms - layer.startMs >= minimumMs && layer.endMs - ms >= minimumMs
    }

    /// The first half keeps the id; the second is a new layer with everything else the same (D13).
    static func split(_ layer: VideoLayer, at ms: Int) -> (VideoLayer, VideoLayer) {
        var first = layer
        first.endMs = ms
        var second = layer
        second.id = UUID()
        second.startMs = ms
        return (first, second)
    }
}
