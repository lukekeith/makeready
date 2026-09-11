//
//  RadialDayClock.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-029-radial-day-clock.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-029 RadialDayClock — a 24-hour radial activity ring with a center key value.
///
/// §3 carries exactly one designed rendering (the source is a plain frame, `3634:4871`, with no
/// variant axes), so the component has no state axis: what changes between renders is data.
/// The other two §3 rows — empty period, and loading/error/pressed — are UNDESIGNED, so rule 7
/// gives them no fixture state; the empty case is handled below only as OQ-C-029-2's proposed
/// default standing in for a design, and nothing in the fixture reaches it.
struct RadialDayClock: View {

    /// C-029 §4: `hourValues: [Double]` (24) — "activity concentration per hour of the day;
    /// drives which angular spans render arcs and each arc's opacity band".
    let hourValues: [Double]
    /// C-029 §4: `centerValue: String` — "center number (sample \"32\")".
    let centerValue: String
    /// C-029 §4: `centerUnit: String` — "unit beside the number (sample \"min\")".
    let centerUnit: String
    /// C-029 §4: `centerCaption: String` — "caption under the value (sample \"Average session\")".
    let centerCaption: String

    init(
        hourValues: [Double],
        centerValue: String,
        centerUnit: String,
        centerCaption: String
    ) {
        self.hourValues = hourValues
        self.centerValue = centerValue
        self.centerUnit = centerUnit
        self.centerCaption = centerCaption
    }

    // MARK: - §2 geometry

    /// C-029 §2's measured footprint and radii, in the component's own coordinate space.
    ///
    /// FLAGGED LITERAL — C-029 §2 closes: "No new tokens; flagged literals: 10pt ring stroke,
    /// 4pt dots, r135/r150 radii, the `text/navigation` binding, and the Inter typography".
    /// Rule 4's flagged-literal path therefore covers the stroke, the dot size and both radii:
    /// they stay literals carrying the flag rather than being promoted into `tokens.md`.
    private enum Geometry {
        static let footprintWidth: CGFloat = 357        // §2: "Footprint 357×326"
        static let footprintHeight: CGFloat = 326
        static let ringRadius: CGFloat = 135            // §2: "circle r=135 (centerline)"
        static let ringStroke: CGFloat = 10             // §2: "stroke 10pt"
        static let tickRadius: CGFloat = 150            // §2: dots "on a r=150 circle"
        static let tickDiameter: CGFloat = 4            // §2: "24 dots, 4pt diameter"
        static let hourCount = 24
        static let degreesPerHour: CGFloat = 360 / CGFloat(hourCount)
        static let centerStackWidth: CGFloat = 146      // §2: "146pt wide stack"

        /// GAP — C-029 §2 places the hour labels "just outside the tick circle" and gives no
        /// numeric offset at all. Calibrated against the frozen snapshot, whose eight label ink
        /// boxes clear the ring centre by 158.5–168.5pt (mean ≈161) — the tick circle's 150 plus
        /// the dot's 2pt radius plus a gap. This constant anchors SwiftUI's LAYOUT box, which
        /// carries typographic padding the Figma text node does not, so it sits ~4pt inside the
        /// measured ink figure to put the rendered ink where the snapshot's is; capture 1 at 160
        /// landed every label ~3pt too far out. Contract-traceable but unnamed, so it is a
        /// literal with an OQ rather than an invented token. §2's one sentence supports a single
        /// clearance radius; the snapshot's own eight offsets are not uniform (the "6 AM" label
        /// is the outlier at 168.5), so a residual ±3pt spread is a contract gap, not a nudge.
        static let labelClearRadius: CGFloat = 156

        /// A generous layout box for one hour label; the label is aligned to the box edge that
        /// faces the ring, so the box size affects placement only through that alignment.
        static let labelBoxWidth: CGFloat = 64
        static let labelBoxHeight: CGFloat = 20
    }

    // FLAGGED LITERAL — C-029 §2: the hour labels bind Figma variable `text/navigation` #8d9fa7,
    // and §2 records that this variable "has **no token row** (near-duplicate of
    // `color-nav-text` #8ea0a7, existing tokens.md hygiene flag; cite the variable until the
    // owner consolidates)"; §2's flagged-literal list names "the `text/navigation` binding".
    // `tokens.md` does carry #8d9fa7 — as `color-nav-border-active` ("same hex as
    // `text/navigation` — alias") — but that row is a nav BORDER colour, and naming it for chart
    // label text would assert a semantic the contract does not. Literal + flag per rule 4.
    private static let hourLabelColor = Color(red: 141 / 255, green: 159 / 255, blue: 167 / 255)

    // FLAGGED LITERAL — C-029 §2: every string in this component is **Inter** ("all chart text is
    // Inter, not SF Pro (extends OQ-home-dashboard-5)"), and §2's flagged-literal list closes with
    // "the Inter typography". `tokens.md` § Typography states Inter is deliberately NOT tokenized.
    // Inter is also not bundled in this app, so naming it in `.custom` would fall back to the
    // system face silently while claiming otherwise — the size, weight and leading are honoured
    // here and the face is reported as a gap instead. Where a token happens to match the metrics
    // it is named in the comment; these local styles exist to carry the flag, not to shadow it.
    private static let hourLabelStyle = DesignTextStyle(
        weight: .bold, size: 12, lineHeight: nil, tracking: 0
    )                                                   // §2: "Inter Bold 12" (= `type-caption-bold` metrics)
    private static let valueStyle = DesignTextStyle(
        weight: .regular, size: 24, lineHeight: 24, tracking: 0
    )                                                   // §2: "Inter Regular 24/24" (`type-value-hero` is 24/**32**)
    private static let unitStyle = DesignTextStyle(
        weight: .regular, size: 14, lineHeight: 14, tracking: 0
    )                                                   // §2: "Inter Regular 14/14" (`type-body` is 14, leading unmeasured)
    private static let captionStyle = DesignTextStyle(
        weight: .bold, size: 18, lineHeight: 24, tracking: 0
    )                                                   // §2: "Inter Bold 18/24" (= `type-value-emphasis` metrics)

    // MARK: - Bands (§2 arcs)

    /// §2: arcs render "`color-accent` at one of three opacities per arc — 100% (`Purple/100%`),
    /// 50% (`Purple/50%`), 20% (`Purple/20%`) — opacity encodes activity concentration".
    private enum Band {
        case faint, half, solid

        var color: Color {
            switch self {
            case .faint: return Token.accent20
            case .half: return Token.accent50
            case .solid: return Token.accent
            }
        }
    }

    private struct ArcRun {
        let startHour: Int
        let endHour: Int
        let band: Band
    }

    /// §4: `hourValues` is 24 long. Anything shorter is zero-filled and anything longer is
    /// truncated rather than trapping — the prop's own contract states the length.
    private var resolvedHourValues: [Double] {
        var values = Array(hourValues.prefix(Geometry.hourCount))
        if values.count < Geometry.hourCount {
            values.append(contentsOf: Array(repeating: 0, count: Geometry.hourCount - values.count))
        }
        return values
    }

    /// OQ-C-029-1's proposed default: "terciles of the period's non-zero hourly activity".
    ///
    /// Read as terciles of the non-zero VALUE RANGE (min…max split in thirds), not as equal-count
    /// quantiles. That is the reading which reproduces §2's sample distribution: the frozen
    /// snapshot's thirteen active hours split 4 faint / 3 half / 6 solid, and equal-count terciles
    /// of thirteen values can only ever split 5/4/4. Reported as part of OQ-C-029-1 so the owner's
    /// ruling has the two readings in front of it.
    private var hourBands: [Band?] {
        let values = resolvedHourValues
        let active = values.filter { $0 > 0 }
        guard let low = active.min(), let high = active.max() else {
            return Array(repeating: nil, count: Geometry.hourCount)
        }
        let span = high - low
        return values.map { value in
            guard value > 0 else { return nil }
            guard span > 0 else { return .solid }
            let position = (value - low) / span
            if position < 1.0 / 3.0 { return .faint }
            if position < 2.0 / 3.0 { return .half }
            return .solid
        }
    }

    /// Contiguous hours sharing a band collapse into one arc, so §2's "3 solid, 2 half, 1 faint"
    /// sample reads as arcs rather than as 24 abutting segments.
    ///
    /// GAP — C-029 §2 measures the sample's arc spans as **continuous** ("Arc angular spans in the
    /// sample are continuous (not hour-quantized) — quantization is OQ-C-029-3"), but §4's only
    /// data prop is `hourValues` (24 hourly buckets). Every arc endpoint this component can
    /// produce therefore falls on a 15° hour boundary, whichever way OQ-C-029-3 is ruled: the
    /// props cannot express a span that starts at 4.10h. The resulting endpoint drift against the
    /// frozen snapshot is up to ~7°, and it is a contract gap, not a geometry to nudge.
    private var arcRuns: [ArcRun] {
        let bands = hourBands
        var runs: [ArcRun] = []
        var index = 0
        while index < bands.count {
            guard let band = bands[index] else {
                index += 1
                continue
            }
            var end = index + 1
            while end < bands.count, bands[end] == band { end += 1 }
            runs.append(ArcRun(startHour: index, endHour: end, band: band))
            index = end
        }
        return runs
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            baseRing
            activityArcs
            tickDots
            hourLabels
            centerKeyValue
        }
        .frame(width: Geometry.footprintWidth, height: Geometry.footprintHeight)
        .ui2Element("RadialDayClock")
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "**Base ring:** circle r=135 (centerline; 270pt diameter), stroke 10pt
    /// `color-white-10`, full 360°."
    private var baseRing: some View {
        Circle()
            .strokeBorder(Token.white10, lineWidth: Geometry.ringStroke)
            .frame(
                width: Geometry.ringRadius * 2 + Geometry.ringStroke,
                height: Geometry.ringRadius * 2 + Geometry.ringStroke
            )
            .ui2Element("Base ring")
    }

    /// §2: "**Activity arcs:** 10pt strokes on the same r=135 centerline … butt caps (no rounding
    /// observed in the path strokes)."
    private var activityArcs: some View {
        ZStack {
            ForEach(Array(arcRuns.enumerated()), id: \.offset) { index, run in
                arcShape(run)
                    .stroke(
                        run.band.color,
                        style: StrokeStyle(lineWidth: Geometry.ringStroke, lineCap: .butt)
                    )
                    .ui2Element("Arc \(index + 1)")
            }
        }
        .frame(
            width: Geometry.ringRadius * 2 + Geometry.ringStroke,
            height: Geometry.ringRadius * 2 + Geometry.ringStroke
        )
    }

    private func arcShape(_ run: ArcRun) -> Path {
        let box = Geometry.ringRadius * 2 + Geometry.ringStroke
        let center = CGPoint(x: box / 2, y: box / 2)
        var path = Path()
        path.addArc(
            center: center,
            radius: Geometry.ringRadius,
            startAngle: Self.ringAngle(hour: CGFloat(run.startHour)),
            endAngle: Self.ringAngle(hour: CGFloat(run.endHour)),
            clockwise: false
        )
        return path
    }

    /// §2: hour 0 sits at the top and the day runs clockwise ("12 AM top, then clockwise 3 AM …").
    /// SwiftUI's angles start at +x and increase clockwise on screen, so the hour ray is
    /// `hour × 15° − 90°`.
    private static func ringAngle(hour: CGFloat) -> Angle {
        .degrees(Double(hour * Geometry.degreesPerHour - 90))
    }

    /// §2: "**Tick dots:** 24 dots, 4pt diameter, fill `color-white-20`, evenly spaced (15°) on a
    /// r=150 circle … one per hour."
    private var tickDots: some View {
        ZStack {
            ForEach(0..<Geometry.hourCount, id: \.self) { hour in
                Circle()
                    .fill(Token.white20)
                    .frame(width: Geometry.tickDiameter, height: Geometry.tickDiameter)
                    .offset(Self.rayOffset(hour: CGFloat(hour), radius: Geometry.tickRadius))
            }
        }
        .ui2Element("Tick dots")
    }

    /// §2: "**Hour labels:** 8, at the 3-hour compass points just outside the tick circle — 12 AM
    /// top, then clockwise 3 AM, 6 AM (right), 9 AM, 12 PM (bottom), 3 PM, 6 PM (left), 9 PM.
    /// Inter Bold 12, variable `text/navigation` #8d9fa7."
    private var hourLabels: some View {
        ZStack {
            ForEach(Self.labelHours, id: \.self) { hour in
                hourLabel(hour)
            }
        }
    }

    private static let labelHours = [0, 3, 6, 9, 12, 15, 18, 21]

    private func hourLabel(_ hour: Int) -> some View {
        let direction = Self.rayDirection(hour: CGFloat(hour))
        // The label's box edge facing the ring is what clears the tick circle, so the box is
        // pushed out by half its own extent along the ray and the text hugs the inner edge.
        let offset = CGSize(
            width: direction.width * Geometry.labelClearRadius
                + Self.sign(direction.width) * Geometry.labelBoxWidth / 2,
            height: direction.height * Geometry.labelClearRadius
                + Self.sign(direction.height) * Geometry.labelBoxHeight / 2
        )
        return Text(Self.labelText(hour: hour))
            .designTextStyle(Self.hourLabelStyle)
            .foregroundColor(Self.hourLabelColor)
            .frame(
                width: Geometry.labelBoxWidth,
                height: Geometry.labelBoxHeight,
                alignment: Self.labelAlignment(direction)
            )
            .offset(offset)
            .ui2Element("Hour label \(Self.labelText(hour: hour))")
    }

    /// §2's clock face: 12 AM / 3 AM / 6 AM / 9 AM / 12 PM / 3 PM / 6 PM / 9 PM.
    private static func labelText(hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display) \(period)"
    }

    private static func labelAlignment(_ direction: CGSize) -> Alignment {
        let horizontal: HorizontalAlignment
        switch sign(direction.width) {
        case 1: horizontal = .leading
        case -1: horizontal = .trailing
        default: horizontal = .center
        }
        let vertical: VerticalAlignment
        switch sign(direction.height) {
        case 1: vertical = .top
        case -1: vertical = .bottom
        default: vertical = .center
        }
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    /// §2: "**Center key value** (146pt wide stack, gap 4, centered in the donut): value row —
    /// number Inter Regular 24/24 `color-text-primary` + 2gap + unit Inter Regular 14/14
    /// `color-text-secondary`, bottom-aligned; caption row — Inter Bold 18/24
    /// `color-text-secondary`, centered."
    private var centerKeyValue: some View {
        VStack(spacing: Token.Space.metaGap) {
            HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
                Text(centerValue)
                    .designTextStyle(Self.valueStyle)
                    .foregroundColor(Token.textPrimary)
                    .ui2Element("Value")
                Text(centerUnit)
                    .designTextStyle(Self.unitStyle)
                    .foregroundColor(Token.textSecondary)
                    .ui2Element("Unit")
            }
            .ui2Element("Value row")
            Text(centerCaption)
                .designTextStyle(Self.captionStyle)
                .foregroundColor(Token.textSecondary)
                .multilineTextAlignment(.center)
                .ui2Element("Caption row")
        }
        .frame(width: Geometry.centerStackWidth)
        .ui2Element("Center key value")
    }

    // MARK: - Ray helpers

    /// The unit vector of hour `hour`'s ray: 12 AM straight up, the day running clockwise.
    private static func rayDirection(hour: CGFloat) -> CGSize {
        let radians = CGFloat(ringAngle(hour: hour).radians)
        return CGSize(width: cos(radians), height: sin(radians))
    }

    private static func rayOffset(hour: CGFloat, radius: CGFloat) -> CGSize {
        let direction = rayDirection(hour: hour)
        return CGSize(width: direction.width * radius, height: direction.height * radius)
    }

    /// `sign` with a hard zero: a ray exactly on an axis must not be nudged off it by floating
    /// point, or the cardinal labels stop being centred on their compass point.
    private static func sign(_ value: CGFloat) -> CGFloat {
        if abs(value) < 0.0001 { return 0 }
        return value > 0 ? 1 : -1
    }
}
