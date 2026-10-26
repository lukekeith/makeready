//
//  TextSizeSlider.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-093-textsizeslider in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-093 TextSizeSlider — "Vertical wedge size slider with a 26pt thumb: writes the text
/// object's size."
///
/// §2: a 20 × 263.5pt wedge track tapering from a 20pt top edge to an apex at the bottom
/// centre, and a 26pt thumb disc on the track's centre line. Linear, **top = 1 (largest),
/// bottom = 0 (smallest)**; the point size is the caller's mapping (activities-editor OQ-015).
///
/// Controlled (R-01): it displays `value` and never holds it. Width-driven, chrome-free (R-16):
/// it states its own 263.5pt height, paints no background and adds no outer padding. The thumb
/// overhangs the 20pt frame by 3pt each side (§2) and the track's ends by 13pt (OQ-C-093-003).
struct TextSizeSlider: View {
    /// §4 — thumb position, 0…1 along the track, 1 = top = largest.
    let value: CGFloat
    /// §4 — fires with the new 0…1 value on every movement while the finger is down.
    var onChange: (CGFloat) -> Void = { _ in }

    /// §2 frame: 20 × 263.5pt (§1 deviation 3 — the half point is laid out as authored).
    private let trackWidth: CGFloat = 20
    private let trackHeight: CGFloat = 263.5
    /// §2 thumb: a 26 × 26pt disc.
    private let thumbDiameter: CGFloat = 26
    /// §2 touch / OQ-C-093-002: a 44pt-wide hit strip centred on the track, full height.
    private let hitWidth: CGFloat = 44

    var body: some View {
        Wedge()
            .fill(Token.white50)
            .ui2Element("Track")
            .frame(width: trackWidth, height: trackHeight)
            .overlay(alignment: .top) {
                // `radius-circle` is 50 %, not a point value — the disc is a Circle().
                Circle()
                    .fill(Token.white100)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .designShadow(Token.Elevation.thumb)
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

/// §2 track — `M0 0 H20 L10 263.5 Z`: the full top edge tapering to an apex at the bottom
/// centre. Inline anatomy of C-093, not a registry row (§5).
private struct Wedge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
