//
//  RecordButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-013-recordbutton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-013 RecordButton — the recorder's round record / stop / pause control.
///
/// One circular frame with one centred mark (§2). Two sizes from two sources (§1 deviation 6):
/// `video` is Figma's RecordButton set (3322:31523 / 3322:31531 / 3322:31557); `memo` is
/// C-017 RecorderCompactView's built record and stop buttons, rendered unchanged. A fixed-size
/// control: it paints nothing outside its frame and adds no outer padding (R-16); the host
/// positions it. Video record ↔ stop morphs over `motion-record-morph`; memo swaps instantly
/// (OQ-C-013-005). No disabled state (OQ-C-013-004).
struct RecordButton: View {

    /// §4 `kind` — which mark the button shows and the action it fires.
    enum Kind {
        case record, stop, pause
    }

    /// §4 `size` — memo is C-017's 58 pt ring in `color-error`; video is the 80 pt
    /// (pause: 54 pt) `color-white-10` disc in `color-record`.
    enum Size {
        case memo, video
    }

    /// §4 `kind` — set by the caller from the recorder's state. Required.
    let kind: Kind
    /// §4 `size`. Required.
    let size: Size
    /// §4 `onTap` — the button was tapped; the caller decides what it means for the current
    /// kind (R-03, R-04). No render effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    // MARK: - Geometry

    private enum Geometry {
        /// FLAGGED LITERAL — C-013 §2 FL-V1: 80 pt video frame.
        static let videoFrame: CGFloat = 80
        /// FLAGGED LITERAL — C-013 §2 FL-V2: 54 pt video pause frame.
        static let videoPauseFrame: CGFloat = 54
        /// FLAGGED LITERAL — C-013 §2 FL-V3: 64 pt video record disc (8 pt inset).
        static let videoDisc: CGFloat = 64
        /// FLAGGED LITERAL — C-013 §2 FL-V4: 36 pt video stop square.
        static let videoSquare: CGFloat = 36
        /// FLAGGED LITERAL — C-013 §2 FL-V5: 18 pt pause glyph height.
        static let pauseGlyph: CGFloat = 18
        /// FLAGGED LITERAL — C-013 §2 FL-1 (C-017's): 58 pt memo ring.
        static let memoFrame: CGFloat = 58
        /// FLAGGED LITERAL — C-013 §2 FL-2 (C-017's): 24 pt memo stop square.
        static let memoSquare: CGFloat = 24
        /// FLAGGED LITERAL — C-013 §2 FL-3 (C-017's): 46 pt memo record disc.
        static let memoDisc: CGFloat = 46
        /// GAP — C-013 §2: "The 1 pt memo stroke is a GAP (no stroke token)".
        static let memoStroke: CGFloat = 1
        /// GAP — C-013 §2 Pressed / OQ-C-013-003: "dims to 0.6 opacity"; no opacity token.
        static let pressedOpacity: Double = 0.6
    }

    // MARK: - Body

    var body: some View {
        SwiftUI.Button(action: onTap) {
            content
                .contentShape(Circle())
                .accessibilityHidden(true)          // §2 / R-17: inner shapes hidden
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .ui2Element("RecordButton")
    }

    @ViewBuilder private var content: some View {
        switch size {
        case .video: videoContent
        case .memo: memoContent
        }
    }

    // MARK: - Video size (Figma)

    @ViewBuilder private var videoContent: some View {
        if kind == .pause {
            // §2 pause: a 54 pt `color-white-10` circle holding `pause-filled`, 18 pt tall,
            // `color-text-primary` (deviation 3: the library glyph, not Figma's SVG). The glyph
            // scale has no 18 pt step, so the 24 pt glyph is scaled to FL-V5.
            Glyph(.pauseFilled, size: .md, tint: Token.textPrimary)
                .scaleEffect(Geometry.pauseGlyph / GlyphSize.md.points)
                .frame(width: Geometry.pauseGlyph, height: Geometry.pauseGlyph)
                .ui2Element("Pause glyph")
                .frame(width: Geometry.videoPauseFrame, height: Geometry.videoPauseFrame)
                .background(Circle().fill(Token.white10).ui2Element("Frame"))
        } else {
            // §2 record / stop: one mark that morphs between the 64 pt disc and the 36 pt
            // `radius-card` square, size and corner radius together, over `motion-record-morph`.
            // The 80 pt `color-white-10` frame stays put.
            RoundedRectangle(cornerRadius: markRadius, style: .continuous)
                .fill(Token.record)              // deviation 4: `color-record`, not #FF002E
                .frame(width: markSide, height: markSide)
                .animation(Token.Motion.recordMorph, value: kind)
                .ui2Element(kind == .record ? "Record disc" : "Stop square")
                .frame(width: Geometry.videoFrame, height: Geometry.videoFrame)
                .background(Circle().fill(Token.white10).ui2Element("Frame"))
        }
    }

    /// The video mark's side: the record disc or the stop square.
    private var markSide: CGFloat { kind == .record ? Geometry.videoDisc : Geometry.videoSquare }

    /// The video mark's corner radius: half the disc (a circle) or `radius-card`.
    private var markRadius: CGFloat { kind == .record ? Geometry.videoDisc / 2 : Token.Radius.card }

    // MARK: - Memo size (C-017's built view, unchanged)

    @ViewBuilder private var memoContent: some View {
        // §2 memo: a 58 pt frame with a 1 pt `color-white-10` stroke border (no fill); swaps
        // instantly between kinds. `pause` has no memo design (§3), so it draws the record mark
        // rather than invent one.
        Group {
            if kind == .stop {
                RoundedRectangle(cornerRadius: Token.Radius.step4, style: .continuous)
                    .fill(Token.error)          // deviation 2: memo keeps `color-error`
                    .frame(width: Geometry.memoSquare, height: Geometry.memoSquare)
                    .ui2Element("Stop square")
            } else {
                Circle()
                    .fill(Token.error)
                    .frame(width: Geometry.memoDisc, height: Geometry.memoDisc)
                    .ui2Element("Record disc")
            }
        }
        .frame(width: Geometry.memoFrame, height: Geometry.memoFrame)
        .overlay(Circle().strokeBorder(Token.white10, lineWidth: Geometry.memoStroke).ui2Element("Frame"))
    }

    // MARK: - Accessibility

    /// §2 Accessibility (R-17): one label per kind.
    private var label: String {
        switch kind {
        case .record: return "Record"
        case .stop: return "Stop recording"
        case .pause: return "Pause recording"
        }
    }

    /// OQ-C-013-003 (R-02, internal): the whole button dims while pressed, no scale.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? Geometry.pressedOpacity : 1)
        }
    }
}
