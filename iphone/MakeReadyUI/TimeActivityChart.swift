//
//  TimeActivityChart.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-030-time-activity-chart.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  C-022 MetaPair (the tick row, ×4) is a LEVEL-2 dependency: its contract is
//  docs/ui2/screens/home-dashboard.md §4's "C-022 MetaPair" anchor, which D10 accepts as a full
//  anchor, and C-030 §2 restates the same rendering. It is built INLINE, nested, rather than as
//  its own preview, because it has no contract file and no frozen snapshot of its own — so it is
//  not a legal /ui2-component-build target (preview-build.md §4 / phase 0.3). Spec it with
//  `/ui2-component MetaPair <figma-url>` (node 3673:12445) and it earns its own row.
//

import SwiftUI

/// C-030 TimeActivityChart — activity intensity across one fixed, non-panning time window,
/// drawn as a horizontal gradient alpha-masked by the data bars.
///
/// §3 carries one designed variant (`style=Default`), so the component has no state axis: what
/// changes between renders is data. The other two §3 rows — empty period, and
/// loading/error/pressed — are UNDESIGNED, so rule 7 gives them no fixture state; the empty case
/// is handled below only as OQ-C-030-1's proposed default standing in for a design.
struct TimeActivityChart: View {

    /// C-030 §4: `bins: [Double]` — "activity intensity per time slice of the fixed window, in
    /// order; any count ≥ 1 — the chart resamples it to `floor(width ÷ 5px pitch)` bars (88 bins
    /// at the 438 design width draw as-is); values scale to bar heights, resampled window max →
    /// 100pt".
    let bins: [Double]
    /// C-030 §4: `tickLabels: [(value: String, unit: String)]` — "4 justified C-022 MetaPairs
    /// under the chart". §4's tuple type verbatim.
    let tickLabels: [(value: String, unit: String)]
    // GAP — C-030: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). Bars rise left to right across the
    /// same 0.6 s the RadialDayClock's sweep takes (D2).
    let intro: ChartIntro?

    private var introProgress: Double {
        intro?.progress(fadeOnly: !bins.contains { $0 > 0 }) ?? 1
    }

    init(bins: [Double], tickLabels: [(value: String, unit: String)], intro: ChartIntro? = nil) {
        self.bins = bins
        self.tickLabels = tickLabels
        self.intro = intro
    }

    // MARK: - §2 geometry

    /// C-030 §2's measured footprint, in the component's own coordinate space.
    private enum Geometry {
        /// §2: "Width-driven … the root fills the width its consumer gives it; the design width
        /// is 438 and is a sample, not a constant." Kept as the IDEAL width only, so a caller
        /// that asks for the intrinsic size (the capture harness) still gets the design's 438.
        static let designWidth: CGFloat = 438
        static let chartHeight: CGFloat = 100       // §2: "Chart area (width × 100)"
        static let tickRowHeight: CGFloat = 24      // §2: "Tick row (24pt, inset 16 …)"

        // FLAGGED LITERAL — C-030 §2: "bars 3px wide, corner radius 1.5 (pill ends), 5px pitch
        // (2px gap) … Bar/gap/radius values are flagged literals (mask geometry, no tokens)."
        // The 2pt gap is hex-… value-equal to `space-chip-gap`, but §2 flags it, and rule 4's
        // flagged-literal path is explicit that a flagged value is NOT promoted to a token.
        static let barWidth: CGFloat = 3
        static let barGap: CGFloat = 2
        static let barRadius: CGFloat = 1.5
        /// §2: "near-zero bins render as ≥3px dot stubs in the sample" — a 3×3 pill is the dot.
        static let barMinHeight: CGFloat = 3
        /// §2: "5px pitch kept (2px gap)".
        static let barPitch: CGFloat = barWidth + barGap

        /// GAP — C-030 §2: "Root: a vertical stack, gap 16 — chart area over tick row".
        /// `tokens.md`'s only stack-gap row is `space-element-gap` (8); its two 16s
        /// (`space-page-margin`, `space-card-padding`) are both horizontal-inset semantics, so
        /// naming either for a vertical stack gap would assert something the contract does not.
        /// Contract-traceable with no token to name — literal plus an OQ, per rule 4.
        static let rootGap: CGFloat = 16
    }

    // FLAGGED LITERAL — C-030 §2: the gradient's 0% stop is "`#ff4759` at 0% (raw literal in
    // Figma, hex-equal to `color-negative`/variable `Red/100` but not variable-bound — hygiene
    // flag, OQ-C-030-3)". Unlike C-034's flagged fills — where §2's own normative line NAMES the
    // token and the flag only records that Figma failed to bind it — here §2 writes the hex as
    // the normative value and OQ-C-030-3 asks the prior question: whether this stop is
    // "deliberately independent of the negative-semantics token". `Token.negative` is the same
    // hex, and using it would answer that OQ in Swift. The literal carries the flag instead.
    private static let gradientStart = Color(red: 1.0, green: 71 / 255, blue: 89 / 255)

    // MARK: - Derived

    /// §2: "Bar count = `floor(width / 5)` (88 at 438, 80 at 402)". A row of n bars is
    /// n × 3 + (n − 1) × 2 = 5n − 2 wide, so the count that fits — and that gives §2's own 88 at
    /// 438 and 80 at 402 — is floor((width + gap) / pitch).
    static func barCount(for width: CGFloat) -> Int {
        max(1, Int(((width + Geometry.barGap) / Geometry.barPitch).rounded(.down)))
    }

    /// §2: "the `bins` the consumer passes … are resampled to that count — each bar takes the
    /// mean of the bins it covers, or, when upsampling, the nearest bin". At an equal count the
    /// resample is the identity, so 438 draws exactly the bins it was given.
    static func resample(_ bins: [Double], to count: Int) -> [Double] {
        let source = bins.count
        guard source > 0, count > 0 else { return Array(repeating: 0, count: max(count, 0)) }
        guard source != count else { return bins }
        if count > source {
            return (0..<count).map { bar in
                bins[min(source - 1, Int((Double(bar) + 0.5) * Double(source) / Double(count)))]
            }
        }
        return (0..<count).map { bar in
            let start = bar * source / count
            let end = max(start + 1, (bar + 1) * source / count)
            let covered = bins[start..<min(end, source)]
            return covered.reduce(0, +) / Double(covered.count)
        }
    }

    /// §2: "bar height ∝ resampled intensity with the window max (resampled) → 100; near-zero
    /// bins render as ≥3px dot stubs".
    ///
    /// OQ-C-030-1's proposed default lives in the `max <= 0` branch: an all-zero window renders
    /// every bin as the 3px baseline stub with the gradient still applied. §3 carries that row as
    /// UNDESIGNED, so rule 7 gives it no fixture state and nothing in the fixture reaches it.
    private func barHeights(count: Int) -> [CGFloat] {
        let values = Self.resample(bins, to: count)
        let peak = values.max() ?? 0
        guard peak > 0 else {
            return Array(repeating: Geometry.barMinHeight, count: values.count)
        }
        return values.map { value in
            max(Geometry.barMinHeight, CGFloat(value / peak) * Geometry.chartHeight)
        }
    }

    /// §2 (left→right): `#ff4759` 0% → `color-accent` 25% → `color-accent` 75% →
    /// `color-positive` 100%. "Color is pure positional encoding across the period … it carries
    /// no per-bar meaning", which is why it is one fill across the whole chart rather than a
    /// colour resolved per bar.
    private var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Self.gradientStart, location: 0),
                .init(color: Token.accent, location: 0.25),
                .init(color: Token.accent, location: 0.75),
                .init(color: Token.positive, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Geometry.rootGap) {
            chartArea
            tickRow
        }
        // §2: width-driven — fills the consumer's width; 438 is only the ideal (design) width.
        .frame(minWidth: 0, idealWidth: Geometry.designWidth, maxWidth: .infinity)
        .chartIntroMorph(intro, value: bins)                         // D9
        .chartIntroFade(intro, fadeOnly: !bins.contains { $0 > 0 })  // D16
        .ui2Element("TimeActivityChart")
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "**Chart area (width × 100):** a single horizontal gradient fill, alpha-masked by the
    /// bar shapes." The gradient spans the given width.
    private var chartArea: some View {
        GeometryReader { proxy in
            let heights = barHeights(count: Self.barCount(for: proxy.size.width))
            ZStack(alignment: .bottomLeading) {
                gradient
                    .mask(alignment: .bottomLeading) { barRow(heights) }
                // A mask's subtree does not carry its preferences up, so the same row is laid out
                // once more, fully transparent, purely to publish the per-bar element anchors. It
                // paints nothing and the mask above is still what renders.
                barRow(heights)
                    .opacity(0)
                    .ui2Element("Bar mask")
            }
            .frame(width: proxy.size.width, height: Geometry.chartHeight, alignment: .bottomLeading)
        }
        .frame(height: Geometry.chartHeight)
        .ui2Element("Chart area")
    }

    /// §2: "**Bar mask** … 5px pitch kept (2px gap), bottom-anchored to y=100. Bar count =
    /// `floor(width / 5)`".
    private func barRow(_ barHeights: [CGFloat]) -> some View {
        HStack(alignment: .bottom, spacing: Geometry.barGap) {
            ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: Geometry.barRadius, style: .continuous)
                    .frame(width: Geometry.barWidth, height: ChartIntro.scaled(height, by: introProgress))
                    .animation(
                        intro?.animation(ChartIntroMotion.rise, after: ChartIntroMotion.stagger(index, of: barHeights.count)),
                        value: intro?.played
                    )
                    .ui2Element("Bar \(index + 1)")
            }
        }
    }

    /// §2: "**Tick row (24pt, inset 16, justified space-between across the given width):** 4 ×
    /// C-022 MetaPair".
    private var tickRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(tickLabels.enumerated()), id: \.offset) { index, tick in
                if index > 0 { Spacer(minLength: 0) }
                MetaPair(value: tick.value, unit: tick.unit)
                    .ui2Element("MetaPair \(index + 1)")
            }
        }
        // §2's inset is INSIDE the root, so the row fills the given width outermost and the
        // padding narrows the proposal the space-between HStack receives (438 − 2×16 = 406 at
        // the design width).
        .frame(height: Geometry.tickRowHeight)
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(maxWidth: .infinity)
        .ui2Element("Tick row")
    }

    /// C-022 MetaPair — the level-2 inline dependency (see the file header).
    ///
    /// home-dashboard §4: "Inline value+label pair, SF Pro Regular 12: value white, label
    /// `text/secondary`, 4pt gap … Props: `value: String`, `label: String`." C-030 §2 names the
    /// second member `unit` at this call site ("value … + 4gap + unit"), which is the name used
    /// here; a `/ui2-component` run on C-022 is what settles the prop's own name.
    ///
    /// GAP — C-030 §2 measures the tick type as "SF Pro Regular 12/**24**". `tokens.md` has
    /// `type-caption` (SF Pro Regular 12/**14**) and no 12/24 row at all, so the face and size are
    /// named by the token and the 24 is carried as §2's tick-row height rather than as leading.
    private struct MetaPair: View {
        let value: String
        let unit: String

        var body: some View {
            HStack(spacing: Token.Space.metaGap) {
                Text(value)
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundColor(Token.textPrimary)
                    .ui2Element("Value")
                Text(unit)
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundColor(Token.textSecondary)
                    .ui2Element("Unit")
            }
        }
    }
}
