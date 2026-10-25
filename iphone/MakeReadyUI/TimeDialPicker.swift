//
//  TimeDialPicker.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-126-time-dial-picker in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-126 TimeDialPicker — a 24-hour dial that picks a time of day in 15-minute steps.
///
/// §2: a 357×326 dial block (12 AM at the top, time running clockwise at 15° per hour) over a
/// one-line readout ("7:00 AM") 48pt below it. The handle and the readout are both derived from
/// `value`, so they cannot disagree (§1 deviation 2).
///
/// Controlled (R-01): it displays `value` and never holds it. The only `@State` is the haptic
/// trigger (R-02 ephemeral feedback). Width-driven, chrome-free (R-16): the two blocks centre in
/// the width given, no background, no outer padding. OQ-C-126-001: no visual change while
/// dragging; the light haptic per step is the only drag feedback.
struct TimeDialPicker: View {
    /// §4 — the picked time as 24-hour "HH:mm". A malformed string draws as 07:00.
    let value: String
    /// §4 — fires with the new "HH:mm" each time a user tap or drag changes the snapped value.
    var onChange: (String) -> Void = { _ in }

    /// R-02: bumped only by a user tap/drag that changes the snapped value, so the haptic never
    /// fires when the caller changes `value` or when a gesture lands on the same step (§2).
    @State private var feedbackTick = 0

    // MARK: - §2 geometry

    // FLAGGED LITERAL — C-126 §2: "8pt ring stroke, 4pt dots, the r136/r148/r156 radii, the 2pt
    // line, the 4pt hub stroke with r14, the 32pt halo, the 8pt dot, the 22pt hit half-band, the
    // 48pt dial-to-readout gap" carry no token row.
    private enum Geometry {
        static let blockWidth: CGFloat = 357            // §2: "Dial block: 357×326"
        static let blockHeight: CGFloat = 326
        static let center = CGPoint(x: 178, y: 163)     // §2: "dial centre is at (178, 163)"
        static let ringRadius: CGFloat = 136            // §2: base ring r=136 (centreline)
        static let ringStroke: CGFloat = 8
        static let tickRadius: CGFloat = 148            // §2: 24 dots on r=148
        static let tickDiameter: CGFloat = 4
        static let labelClearRadius: CGFloat = 156      // §2: label edge nearest centre at r≈156
        static let lineStart: CGFloat = 16              // §2: hand line r=16 → r=136
        static let lineWidth: CGFloat = 2
        static let hubRadius: CGFloat = 14              // §2: hub r=14, stroke 4
        static let hubStroke: CGFloat = 4
        static let haloDiameter: CGFloat = 32
        static let dotDiameter: CGFloat = 8
        static let hitHalfBand: CGFloat = 22            // §2: hit band r = 136 ± 22
        static let readoutGap: CGFloat = 48             // §2: 48pt below the dial block
        static let degreesPerMinute: Double = 0.25      // §2: 15° per hour
        static let stepMinutes = 15
        static let dayMinutes = 1440
        static let fallbackMinutes = 7 * 60             // §4: malformed → 07:00

        /// A layout box for one hour label; the text hugs the box edge that faces the ring.
        static let labelBoxWidth: CGFloat = 64
        static let labelBoxHeight: CGFloat = 20
    }

    // FLAGGED LITERAL — C-126 §2: hour labels are "Inter Bold 12 (no Inter type token; same as
    // C-029, pending OQ-home-dashboard-5)". Inter is not bundled in this app, so the size and
    // weight are honoured on the system face and the face is reported as a gap.
    private static let hourLabelStyle = DesignTextStyle(weight: .bold, size: 12, lineHeight: nil, tracking: 0)

    private static let labelHours = [0, 3, 6, 9, 12, 15, 18, 21]

    // MARK: - Derived value

    /// §4: minutes since midnight, drawn at its exact angle even off the quarter-hour.
    private var minutes: Int {
        Self.parse(value) ?? Geometry.fallbackMinutes
    }

    private var angle: Angle {
        .degrees(Double(minutes) * Geometry.degreesPerMinute)
    }

    /// §2 readout format: `h:mm AM|PM`, no leading zero, uppercase meridiem.
    private var readout: String {
        Self.readoutString(minutes: minutes)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Geometry.readoutGap) {
            dial
            Text(readout)
                .designTextStyle(Token.TypeStyle.codeDisplay)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                // §2: one 24/24 line — the block's height is the style's line height.
                .frame(height: Token.TypeStyle.codeDisplay.lineHeight)
                .accessibilityHidden(true)
                .ui2Element("Readout")
        }
        .frame(maxWidth: .infinity)
        .ui2Element("TimeDialPicker")
    }

    // MARK: - Dial block (§2 anatomy, back to front)

    private var dial: some View {
        ZStack(alignment: .topLeading) {
            baseRing
            hourTicks
            hourLabels
            handLine
            hub
            handle
        }
        .frame(width: Geometry.blockWidth, height: Geometry.blockHeight, alignment: .topLeading)
        .contentShape(RingBand(), eoFill: true)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in select(at: drag.location) }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time")
        .accessibilityValue(readout)
        // R-17: `accessibilityAdjustableAction` carries the `.adjustable` trait §2 names.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(minutes: Self.snapped(minutes) + Geometry.stepMinutes, haptic: false)
            case .decrement: commit(minutes: Self.snapped(minutes) - Geometry.stepMinutes, haptic: false)
            @unknown default: break
            }
        }
        .ui2Element("Dial")
    }

    /// §2: "circle r=136 (centreline), stroke 8, full 360°", `color-white-10`.
    private var baseRing: some View {
        Circle()
            .stroke(Token.white10, lineWidth: Geometry.ringStroke)
            .frame(width: Geometry.ringRadius * 2, height: Geometry.ringRadius * 2)
            .ui2Element("Base ring")
            .position(Geometry.center)
    }

    /// §2: "24 dots, 4pt diameter, on r=148, one per hour", `color-white-20`.
    private var hourTicks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<24, id: \.self) { hour in
                Circle()
                    .fill(Token.white20)
                    .frame(width: Geometry.tickDiameter, height: Geometry.tickDiameter)
                    .position(Self.point(degrees: Double(hour) * 15, radius: Geometry.tickRadius))
            }
        }
        .frame(width: Geometry.blockWidth, height: Geometry.blockHeight, alignment: .topLeading)
        .ui2Element("Hour ticks")
    }

    /// §2: 8 labels at the 3-hour points, each on its own ray with the edge nearest the centre
    /// at r≈156, `color-text-navigation`.
    private var hourLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.labelHours, id: \.self) { hour in
                hourLabel(hour)
            }
        }
        .frame(width: Geometry.blockWidth, height: Geometry.blockHeight, alignment: .topLeading)
    }

    private func hourLabel(_ hour: Int) -> some View {
        let radians = (Double(hour) * 15 - 90) * .pi / 180
        let dx = CGFloat(cos(radians))
        let dy = CGFloat(sin(radians))
        // The box edge facing the ring sits on the clearance radius: push the box out by half
        // its extent along each non-zero axis and align the text to that inner edge.
        let center = CGPoint(
            x: Geometry.center.x + dx * Geometry.labelClearRadius + Self.sign(dx) * Geometry.labelBoxWidth / 2,
            y: Geometry.center.y + dy * Geometry.labelClearRadius + Self.sign(dy) * Geometry.labelBoxHeight / 2
        )
        let text = Self.labelText(hour: hour)
        return Text(text)
            .designTextStyle(Self.hourLabelStyle)
            .foregroundColor(Token.textNavigation)
            .lineLimit(1)
            .fixedSize()
            .ui2Element("Hour label \(text)")
            .frame(
                width: Geometry.labelBoxWidth,
                height: Geometry.labelBoxHeight,
                alignment: Self.labelAlignment(dx: dx, dy: dy)
            )
            .position(center)
    }

    /// §2: "a straight 2pt line from r=16 … to r=136 …, along the value's angle", `color-accent`.
    private var handLine: some View {
        Path { path in
            path.move(to: Self.point(degrees: angle.degrees, radius: Geometry.lineStart))
            path.addLine(to: Self.point(degrees: angle.degrees, radius: Geometry.ringRadius))
        }
        .stroke(Token.accent, lineWidth: Geometry.lineWidth)
        .frame(width: Geometry.blockWidth, height: Geometry.blockHeight)
        .ui2Element("Hand line")
    }

    /// §2: "circle r=14 (centreline), stroke 4, no fill, at the dial centre", `color-accent`.
    private var hub: some View {
        Circle()
            .stroke(Token.accent, lineWidth: Geometry.hubStroke)
            .frame(width: Geometry.hubRadius * 2, height: Geometry.hubRadius * 2)
            .ui2Element("Hub")
            .position(Geometry.center)
    }

    /// §2: a 32pt `color-accent-20` halo centred on the ring at the value's angle, with a
    /// concentric 8pt `color-accent` dot.
    private var handle: some View {
        ZStack {
            Circle()
                .fill(Token.accent20)
                .frame(width: Geometry.haloDiameter, height: Geometry.haloDiameter)
                .ui2Element("Handle halo")
            Circle()
                .fill(Token.accent)
                .frame(width: Geometry.dotDiameter, height: Geometry.dotDiameter)
                .ui2Element("Handle dot")
        }
        .ui2Element("Handle")
        .position(Self.point(degrees: angle.degrees, radius: Geometry.ringRadius))
    }

    // MARK: - Interaction (§2)

    /// §2 tap + drag: the finger's angle, snapped to 15 minutes, mod 1440. The content shape
    /// limits where a gesture may START (the ring band); once started it stays bound to the angle.
    private func select(at location: CGPoint) {
        let dx = Double(location.x - Geometry.center.x)
        let dy = Double(location.y - Geometry.center.y)
        var degrees = atan2(dx, -dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let raw = degrees / Geometry.degreesPerMinute
        let stepped = Int((raw / Double(Geometry.stepMinutes)).rounded()) * Geometry.stepMinutes
        commit(minutes: stepped, haptic: true)
    }

    private func commit(minutes next: Int, haptic: Bool) {
        let wrapped = ((next % Geometry.dayMinutes) + Geometry.dayMinutes) % Geometry.dayMinutes
        guard wrapped != minutes else { return }
        if haptic { feedbackTick += 1 }
        onChange(Self.format(minutes: wrapped))
    }

    // MARK: - Helpers

    /// "HH:mm" → minutes since midnight; nil when malformed.
    private static func parse(_ raw: String) -> Int? {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let hours = Int(parts[0]), let mins = Int(parts[1]),
              (0..<24).contains(hours), (0..<60).contains(mins) else { return nil }
        return hours * 60 + mins
    }

    private static func format(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func snapped(_ minutes: Int) -> Int {
        let step = Double(Geometry.stepMinutes)
        return Int((Double(minutes) / step).rounded()) * Geometry.stepMinutes
    }

    private static func readoutString(minutes: Int) -> String {
        let hours = minutes / 60
        let display = hours % 12 == 0 ? 12 : hours % 12
        return String(format: "%d:%02d %@", display, minutes % 60, hours < 12 ? "AM" : "PM")
    }

    /// §2's clock face: 12 AM / 3 AM / 6 AM / 9 AM / 12 PM / 3 PM / 6 PM / 9 PM.
    private static func labelText(hour: Int) -> String {
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display) \(hour < 12 ? "AM" : "PM")"
    }

    /// A point on the ray `degrees` clockwise from 12 o'clock, `radius` from the dial centre.
    private static func point(degrees: Double, radius: CGFloat) -> CGPoint {
        let radians = (degrees - 90) * .pi / 180
        return CGPoint(
            x: Geometry.center.x + CGFloat(cos(radians)) * radius,
            y: Geometry.center.y + CGFloat(sin(radians)) * radius
        )
    }

    private static func labelAlignment(dx: CGFloat, dy: CGFloat) -> Alignment {
        let horizontal: HorizontalAlignment
        switch sign(dx) {
        case 1: horizontal = .leading
        case -1: horizontal = .trailing
        default: horizontal = .center
        }
        let vertical: VerticalAlignment
        switch sign(dy) {
        case 1: vertical = .top
        case -1: vertical = .bottom
        default: vertical = .center
        }
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    /// `sign` with a hard zero, so a cardinal label stays centred on its compass point.
    private static func sign(_ value: CGFloat) -> CGFloat {
        if abs(value) < 0.0001 { return 0 }
        return value > 0 ? 1 : -1
    }

    /// §2 hit area: the annulus r = 136 ± 22. Filled even-odd so touches at r < 114 (the hub)
    /// and r > 158 are ignored.
    private struct RingBand: Shape {
        func path(in rect: CGRect) -> Path {
            let outer = Geometry.ringRadius + Geometry.hitHalfBand
            let inner = Geometry.ringRadius - Geometry.hitHalfBand
            var path = Path()
            path.addEllipse(in: CGRect(
                x: Geometry.center.x - outer, y: Geometry.center.y - outer, width: outer * 2, height: outer * 2
            ))
            path.addEllipse(in: CGRect(
                x: Geometry.center.x - inner, y: Geometry.center.y - inner, width: inner * 2, height: inner * 2
            ))
            return path
        }
    }
}
