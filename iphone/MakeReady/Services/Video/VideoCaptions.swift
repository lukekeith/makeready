//
//  VideoCaptions.swift
//  MakeReady
//
//  Captions from a transcript's segments, and the transcript sent at Save once captions were
//  corrected (video-editor D4, D12, D24, D26). Pure, so it unit-tests without a UI.
//

import CoreGraphics
import Foundation

enum VideoCaptions {
    /// The caption house style d2m designed: sans 700, 24 wu, white on a dark label, centred.
    static let style = VideoLayerStyle(
        font: .sans, weight: 700, size: 24, colour: "#FFFFFF", background: .solidDark, alignment: .center
    )
    /// The lower third, as a unit point on the frame.
    static let centre = CGPoint(x: 0.5, y: 0.78)

    /// One caption per segment, in time order. A segment with no text, or whose window is empty once
    /// clamped to the clip and to the previous caption's end, makes none (D24).
    static func layers(from transcript: VideoTranscript, clipMs: Int) -> [VideoLayer] {
        var layers: [VideoLayer] = []
        var previousEnd = 0
        for (index, segment) in transcript.segments.enumerated() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let start = max(segment.startMs, previousEnd, 0)
            let end = min(segment.endMs, clipMs)
            guard !text.isEmpty, end > start else { continue }
            layers.append(VideoLayer(
                kind: .caption, text: text, style: style, centre: centre,
                startMs: start, endMs: end, sourceSegment: index
            ))
            previousEnd = end
        }
        return layers
    }

    /// The transcript to send: each segment takes its reworded captions' texts, joined by a space in
    /// time order; a segment with none reworded or none left keeps its own. Times never change; with
    /// no captions the transcript is returned as it is (D12, D26).
    static func corrected(_ transcript: VideoTranscript, with layers: [VideoLayer]) -> VideoTranscript {
        let captions = layers.filter { $0.kind == .caption && $0.sourceSegment != nil }
        guard !captions.isEmpty else { return transcript }
        let bySegment = Dictionary(grouping: captions) { $0.sourceSegment ?? -1 }
        let segments = transcript.segments.enumerated().map { index, segment -> VideoTranscriptSegment in
            let original = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let reworded = (bySegment[index] ?? [])
                .sorted { $0.startMs < $1.startMs }
                .map(\.text)
                .filter { $0 != original }
            guard !reworded.isEmpty else { return segment }
            return VideoTranscriptSegment(
                text: reworded.joined(separator: " "), startMs: segment.startMs, endMs: segment.endMs
            )
        }
        let text = segments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return VideoTranscript(text: text, segments: segments)
    }
}
