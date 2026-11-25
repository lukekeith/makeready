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
/// Two rows top to bottom: the 44 pt track row (a 6 pt `color-white-20` capsule, a `color-accent`
/// fill to the thumb, a 24 pt white thumb with `elevation-thumb`) and the "0:05" / "2:00" end labels
/// (14, `type-caption`). 5…120 s, unsnapped, no label above the handle and no per-stop haptic
/// (video-polish D4, video-recorder §2d).
///
/// Controlled (R-01): it displays `length` and never holds it. Width-driven, chrome-free (R-16):
/// it fills the width it is given, states its own 62 pt height, and paints no background.
struct LengthSlider: View {
    /// §4: the chosen length in seconds, clamped to 5…120. Required (R-07).
    let length: TimeInterval
    /// §4: fires with the new whole second each time it changes under the finger, or on an
    /// accessibility increment or decrement. The caller writes it back.
    var onChange: (TimeInterval) -> Void = { _ in }

    /// R-02 ephemeral: the second last reported during this drag, so `onChange` never fires twice
    /// for the same value while the caller's write-back is in flight.
    @State private var draggedSeconds: Int?

    // §2 geometry: this component's own, as in C-093 (contract: "Literals: none").
    private static let trackHeight: CGFloat = 6
    private static let thumbDiameter: CGFloat = 24
    private static let hitHeight: CGFloat = 44
    private static let minimumSeconds = LengthEntry.minimumSeconds
    private static let maximumSeconds = LengthEntry.maximumSeconds
    /// video-polish D4: one VoiceOver adjustment.
    private static let adjustSeconds = 5

    private static var endLabelHeight: CGFloat { Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size }
    /// 44 + 4 + 14 = 62 pt.
    private static var intrinsicHeight: CGFloat { hitHeight + Token.Space.metaGap + endLabelHeight }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: Token.Space.metaGap) {
                trackRow(width: proxy.size.width)
                    .frame(height: Self.hitHeight)
                endLabels
                    .frame(height: Self.endLabelHeight)
            }
        }
        .frame(height: Self.intrinsicHeight)
        // §2 Accessibility (R-17): one adjustable element that speaks the value in words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording length")
        .accessibilityValue(spokenValue)
        // The adjustable trait comes with the adjustable action (SwiftUI adds it).
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: report(seconds + Self.adjustSeconds)
            case .decrement: report(seconds - Self.adjustSeconds)
            @unknown default: break
            }
        }
        .ui2Element("LengthSlider")
    }

    // MARK: - Rows

    /// §2 row 1: track, fill to the thumb's centre, and the thumb; the whole row is the hit area.
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
            // §2 Touch: a touch jumps to the finger, which needs the location .horizontalPan lacks.
            // pan-ok: slider — tracks the finger's absolute x on its own 44 pt row
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let next = value(atX: drag.location.x, width: width)
                    guard next != (draggedSeconds ?? seconds) else { return }
                    draggedSeconds = next
                    onChange(TimeInterval(next))
                }
                .onEnded { _ in draggedSeconds = nil }
        )
    }

    /// §2 row 2: the range's ends, leading and trailing.
    private var endLabels: some View {
        HStack(spacing: 0) {
            Text(LengthEntry.format(Self.minimumSeconds))
                .ui2Element("Start label")
            Spacer(minLength: 0)
            Text(LengthEntry.format(Self.maximumSeconds))
                .ui2Element("End label")
        }
        .designTextStyle(Token.TypeStyle.caption)
        .monospacedDigit()
        .lineLimit(1)
        .foregroundStyle(Token.textSecondary)
    }

    // MARK: - Value mapping (§2)

    /// `length` as whole seconds, clamped to the range.
    private var seconds: Int { clamped(Int(length.rounded())) }

    private func clamped(_ raw: Int) -> Int {
        min(max(raw, Self.minimumSeconds), Self.maximumSeconds)
    }

    private static var range: CGFloat { CGFloat(maximumSeconds - minimumSeconds) }

    /// The thumb's centre runs from 12 (0:05) to w − 12 (2:00).
    private func thumbCentre(width: CGFloat) -> CGFloat {
        let travel = max(width - Self.thumbDiameter, 0)
        return Self.thumbDiameter / 2 + CGFloat(seconds - Self.minimumSeconds) / Self.range * travel
    }

    private func value(atX x: CGFloat, width: CGFloat) -> Int {
        let travel = max(width - Self.thumbDiameter, 1)
        let fraction = (x - Self.thumbDiameter / 2) / travel
        return clamped(Self.minimumSeconds + Int((fraction * Self.range).rounded()))
    }

    /// Fire `onChange` for a value other than the current one (accessibility clamps at the ends).
    private func report(_ raw: Int) {
        let next = clamped(raw)
        guard next != seconds else { return }
        onChange(TimeInterval(next))
    }

    // MARK: - Formatting

    /// §2 Accessibility: the value in words — "10 seconds", "1 minute", "1 minute 30 seconds".
    private var spokenValue: String {
        Self.spokenFormatter.string(from: TimeInterval(seconds)) ?? LengthEntry.format(seconds)
    }

    private static let spokenFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.minute, .second]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
}
