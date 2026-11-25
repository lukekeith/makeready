//
//  TextSizeSlider.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-093-textsizeslider in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-093 TextSizeSlider — vertical size line with a dot: writes the text object's size.
///
/// video-polish D11 (owner 2026-11-24): a 1pt line, `length` long, centred in the 20pt frame, and a
/// 12pt dot on it. Linear, **top = 1 (largest), bottom = 0 (smallest)**; the point size is the
/// caller's mapping (activities-editor OQ-015).
///
/// Controlled (R-01): it displays `value` and never holds it. Width-driven, chrome-free (R-16):
/// it states its own `length` height, paints no background and adds no outer padding. The dot
/// overhangs the line's ends by 6pt (OQ-C-093-003). The host places it by layout and adds no
/// gesture of its own.
struct TextSizeSlider: View {
    /// §4 — thumb position, 0…1 along the track, 1 = top = largest.
    let value: CGFloat
    /// §4 — the line's height in pt; hosts pass `min(263.5, freeHeight − 32)`.
    var length: CGFloat = 263.5
    /// §4 — fires with the new 0…1 value on every movement while the finger is down.
    var onChange: (CGFloat) -> Void = { _ in }
    /// §4 — fires once when the finger lifts (and after an accessibility step); the caller commits
    /// one edit.
    var onEnded: () -> Void = {}

    /// §2 frame: 20 × `length`pt.
    private let trackWidth: CGFloat = 20
    /// FLAGGED LITERAL — video-polish D11: a 1pt line and a 12pt dot, no size tokens.
    private let lineWidth: CGFloat = 1
    private let thumbDiameter: CGFloat = 12
    /// §2 touch / OQ-C-093-002: a 44pt-wide hit strip centred on the track, full height.
    private let hitWidth: CGFloat = 44

    var body: some View {
        Rectangle()
            .fill(Token.white100)
            .frame(width: lineWidth)
            .ui2Element("Track")
            .frame(width: trackWidth, height: length)
            .overlay(alignment: .top) {
                // `radius-circle` is 50 %, not a point value — the disc is a Circle().
                Circle()
                    .fill(Token.white100)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .ui2Element("Thumb")
                    // OQ-C-093-003: the centre travels the full track, y = (1 − value) × length.
                    .offset(y: (1 - clamped(value)) * length - thumbDiameter / 2)
            }
            // OQ-C-093-002: a touch anywhere on the strip jumps the thumb to the touch's y,
            // then tracks the finger. OQ-C-093-001: no dragging look, no haptic.
            .contentShape(
                Rectangle()
                    .size(width: hitWidth, height: length)
                    .offset(x: (trackWidth - hitWidth) / 2)
            )
            // §2: the one gesture, in this view's own space — y 0…length is the line as drawn.
            .gesture(
                // pan-ok: vertical slider — tracks the finger on its own strip
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { drag in
                        let next = clamped(1 - drag.location.y / max(length, 1))
                        if next != value { onChange(next) }
                    }
                    .onEnded { _ in onEnded() }
            )
            .accessibilityElement()
            .accessibilityLabel("Text size")
            .accessibilityValue("\(percent) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onChange(clamped(value + 0.1))
                case .decrement: onChange(clamped(value - 0.1))
                @unknown default: return
                }
                onEnded()
            }
            .ui2Element("TextSizeSlider")
    }

    /// R-17: the value announced as a percentage.
    private var percent: Int {
        Int((clamped(value) * 100).rounded())
    }

    private func clamped(_ raw: CGFloat) -> CGFloat {
        min(max(raw, 0), 1)
    }
}
