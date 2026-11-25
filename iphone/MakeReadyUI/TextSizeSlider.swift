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
/// video-polish D11 (owner 2026-11-24): a 1pt line, 263.5pt long, centred in the 20pt frame, and a
/// 12pt dot on it. Linear, **top = 1 (largest), bottom = 0 (smallest)**; the point size is the
/// caller's mapping (activities-editor OQ-015).
///
/// Controlled (R-01): it displays `value` and never holds it. Width-driven, chrome-free (R-16):
/// it states its own 263.5pt height, paints no background and adds no outer padding. The dot
/// overhangs the line's ends by 6pt (OQ-C-093-003).
struct TextSizeSlider: View {
    /// §4 — thumb position, 0…1 along the track, 1 = top = largest.
    let value: CGFloat
    /// §4 — fires with the new 0…1 value on every movement while the finger is down.
    var onChange: (CGFloat) -> Void = { _ in }

    /// §2 frame: 20 × 263.5pt (§1 deviation 3 — the half point is laid out as authored).
    private let trackWidth: CGFloat = 20
    private let trackHeight: CGFloat = 263.5
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
            .frame(width: trackWidth, height: trackHeight)
            .overlay(alignment: .top) {
                // `radius-circle` is 50 %, not a point value — the disc is a Circle().
                Circle()
                    .fill(Token.white100)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .ui2Element("Thumb")
                    // OQ-C-093-003: the centre travels the full track, y = (1 − value) × 263.5.
                    .offset(y: (1 - clamped(value)) * trackHeight - thumbDiameter / 2)
            }
            // OQ-C-093-002: a touch anywhere on the strip jumps the thumb to the touch's y,
            // then tracks the finger. OQ-C-093-001: no dragging look, no haptic.
            .contentShape(
                Rectangle()
                    .size(width: hitWidth, height: trackHeight)
                    .offset(x: (trackWidth - hitWidth) / 2)
            )
            .gesture(
                // pan-ok: vertical slider — tracks the finger on its own strip
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let next = clamped(1 - drag.location.y / trackHeight)
                        if next != value { onChange(next) }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Text size")
            .accessibilityValue("\(percent) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onChange(clamped(value + 0.1))
                case .decrement: onChange(clamped(value - 0.1))
                @unknown default: break
                }
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
