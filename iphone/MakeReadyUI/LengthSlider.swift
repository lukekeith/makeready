//
//  LengthSlider.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-149-lengthslider in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-149 LengthSlider — "Slider in the Length sheet that sets the maximum recording length."
///
/// §2: three rows top to bottom: the `m:ss` value riding above the thumb (25.2, `type-timecode`),
/// the 44 pt track row (a 6 pt `color-white-20` capsule, a `color-accent` fill to the thumb, a 24 pt
/// white thumb with `elevation-thumb`), and the "0:10" / "2:00" end labels (14, `type-caption`).
/// 12 stops, 10…120 s (SPEC D3); the thumb never rests between stops.
///
/// Controlled (R-01): it displays `length` and never holds it. Width-driven, chrome-free (R-16):
/// it fills the width it is given, states its own 95.2 pt height, and paints no background.
struct LengthSlider: View {
    /// §4: the chosen length in seconds, one of 10, 20 … 120. A non-stop value is rounded to
    /// the nearest stop and clamped. Required (R-07: 1:00 is the container's default).
    let length: TimeInterval
    /// §4: fires with the new stop's seconds each time the stop under the finger, or an
    /// accessibility increment or decrement, changes it. The caller writes it back (D3).
    var onChange: (TimeInterval) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// R-02 ephemeral: the stop last reported during this drag, so `onChange` never fires twice
    /// for the same stop while the caller's write-back is in flight.
    @State private var draggedStop: Int?

    // §2 geometry: this component's own, as in C-093 (contract: "Literals: none").
    private static let trackHeight: CGFloat = 6
    private static let thumbDiameter: CGFloat = 24
    private static let hitHeight: CGFloat = 44
    /// D3: 12 stops, 10 s apart, from 0:10.
    private static let stopCount = 12
    private static let stepSeconds: TimeInterval = 10
    private static let minimumSeconds: TimeInterval = 10

    private static var labelHeight: CGFloat { Token.TypeStyle.timecode.lineHeight ?? Token.TypeStyle.timecode.size }
    private static var endLabelHeight: CGFloat { Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size }
    /// §2: 25.2 + 8 + 44 + 4 + 14 = 95.2 pt.
    private static var intrinsicHeight: CGFloat {
        labelHeight + Token.Space.elementGap + hitHeight + Token.Space.metaGap + endLabelHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            VStack(spacing: 0) {
                valueLabel(width: width)
                    .frame(height: Self.labelHeight)
                    .padding(.bottom, Token.Space.elementGap)
                trackRow(width: width)
                    .frame(height: Self.hitHeight)
                    .padding(.bottom, Token.Space.metaGap)
                endLabels
                    .frame(height: Self.endLabelHeight)
            }
            // §2 Motion: thumb, fill and value glide to the new stop; Reduce Motion jumps.
            .animation(reduceMotion ? nil : Token.Motion.chipSelect, value: stop)
        }
        .frame(height: Self.intrinsicHeight)
        // §2 Touch: the selection haptic per change of `length` (D3) — in-view feedback (R-04).
        .sensoryFeedback(.selection, trigger: stop)
        // §2 Accessibility (R-17): one adjustable element that speaks the value in words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording length")
        .accessibilityValue(spokenValue)
        // The adjustable trait comes with the adjustable action (SwiftUI adds it).
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: report(stop + 1)
            case .decrement: report(stop - 1)
            @unknown default: break
            }
        }
        .ui2Element("LengthSlider")
    }

    // MARK: - Rows

    /// §2 row 1: the `m:ss` value, centred on the thumb, clamped so it never leaves the width.
    private func valueLabel(width: CGFloat) -> some View {
        let centre = thumbCentre(width: width)
        return ZStack(alignment: .leading) {
            Color.clear
            Text(Self.timecode(seconds(of: stop)))
                .designTextStyle(Token.TypeStyle.timecode)
                .monospacedDigit()                       // §1 deviation 3
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Token.textPrimary)
                .alignmentGuide(.leading) { text in
                    -min(max(centre - text.width / 2, 0), max(width - text.width, 0))
                }
                .ui2Element("Value label")
        }
    }

    /// §2 row 2: track, fill to the thumb's centre, and the thumb; the whole row is the hit area.
    private func trackRow(width: CGFloat) -> some View {
        let centre = thumbCentre(width: width)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Token.white20)
                .frame(height: Self.trackHeight)
                .ui2Element("Track")
            Capsule()
                .fill(Token.accent)
                .frame(width: centre, height: Self.trackHeight)
                .ui2Element("Fill")
            // `radius-circle` is 50 %, not a point value — the disc is a Circle() (C-093).
            Circle()
                .fill(Token.white100)
                .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                .designShadow(Token.Elevation.thumb)
                .ui2Element("Thumb")
                // Padding, not offset: the thumb's layout frame (and its element-map rect) moves too.
                .padding(.leading, centre - Self.thumbDiameter / 2)
        }
        .frame(width: width, height: Self.hitHeight, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            // §2 Touch: a touch jumps to the nearest stop, which needs the location .horizontalPan lacks.
            // pan-ok: slider — tracks the finger's absolute x on its own 44 pt row
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let next = nearestStop(x: drag.location.x, width: width)
                    guard next != (draggedStop ?? stop) else { return }
                    draggedStop = next
                    report(next)
                }
                .onEnded { _ in draggedStop = nil }
        )
    }

    /// §2 row 3: the range's ends, leading and trailing.
    private var endLabels: some View {
        HStack(spacing: 0) {
            Text(Self.timecode(Self.minimumSeconds))
                .ui2Element("Start label")
            Spacer(minLength: 0)
            Text(Self.timecode(seconds(of: Self.stopCount - 1)))
                .ui2Element("End label")
        }
        .designTextStyle(Token.TypeStyle.caption)
        .monospacedDigit()
        .lineLimit(1)
        .foregroundStyle(Token.textSecondary)
    }

    // MARK: - Value mapping (§2)

    /// The stop `length` sits on: rounded to the nearest stop and clamped to 0…11.
    private var stop: Int {
        clampedStop(Int(((length - Self.minimumSeconds) / Self.stepSeconds).rounded()))
    }

    private func clampedStop(_ raw: Int) -> Int {
        min(max(raw, 0), Self.stopCount - 1)
    }

    private func seconds(of stop: Int) -> TimeInterval {
        Self.minimumSeconds + TimeInterval(stop) * Self.stepSeconds
    }

    /// §2: stop i has its thumb centre at 12 + i × (w − 24) / 11.
    private func thumbCentre(width: CGFloat) -> CGFloat {
        let travel = max(width - Self.thumbDiameter, 0)
        return Self.thumbDiameter / 2 + CGFloat(stop) * travel / CGFloat(Self.stopCount - 1)
    }

    private func nearestStop(x: CGFloat, width: CGFloat) -> Int {
        let travel = max(width - Self.thumbDiameter, 1)
        let fraction = (x - Self.thumbDiameter / 2) / travel
        return clampedStop(Int((fraction * CGFloat(Self.stopCount - 1)).rounded()))
    }

    /// Fire `onChange` for a stop other than the current one (accessibility clamps at the ends).
    private func report(_ raw: Int) {
        let next = clampedStop(raw)
        guard next != stop else { return }
        onChange(seconds(of: next))
    }

    // MARK: - Formatting

    /// §2: `m:ss` — 10 → "0:10", 60 → "1:00", 120 → "2:00".
    private static func timecode(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// §2 Accessibility: the value in words — "10 seconds", "1 minute", "1 minute 30 seconds".
    private var spokenValue: String {
        Self.spokenFormatter.string(from: seconds(of: stop)) ?? Self.timecode(seconds(of: stop))
    }

    private static let spokenFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.minute, .second]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
}
