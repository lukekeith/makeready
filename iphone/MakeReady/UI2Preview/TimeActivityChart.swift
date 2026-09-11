//
//  TimeActivityChart.swift
//  UI2Preview — the UI 2.0 preview module
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
    /// order; count = chart width ÷ 5px pitch (88 at 438pt); values scale to bar heights, window
    /// max → 100pt".
    let bins: [Double]
    /// C-030 §4: `tickLabels: [(value: String, unit: String)]` — "4 justified C-022 MetaPairs
    /// under the chart". §4's tuple type verbatim.
    let tickLabels: [(value: String, unit: String)]

    init(bins: [Double], tickLabels: [(value: String, unit: String)]) {
        self.bins = bins
        self.tickLabels = tickLabels
    }

    // MARK: - §2 geometry

    /// C-030 §2's measured footprint, in the component's own coordinate space.
    private enum Geometry {
        static let width: CGFloat = 438             // §2: "Root: 438 wide vertical stack"
        static let chartHeight: CGFloat = 100       // §2: "Chart area (438×100)"
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

        /// GAP — C-030 §2: "Root: 438 wide vertical stack, gap 16 — chart area over tick row".
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

    /// §4: "values scale to bar heights, window max → 100pt"; §2: "near-zero bins render as ≥3px
    /// dot stubs".
    ///
    /// OQ-C-030-1's proposed default lives in the `max <= 0` branch: an all-zero window renders
    /// every bin as the 3px baseline stub with the gradient still applied. §3 carries that row as
    /// UNDESIGNED, so rule 7 gives it no fixture state and nothing in the fixture reaches it.
    private var barHeights: [CGFloat] {
        let peak = bins.max() ?? 0
        guard peak > 0 else {
            return Array(repeating: Geometry.barMinHeight, count: bins.count)
        }
        return bins.map { value in
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
        .frame(width: Geometry.width)
        .ui2Element("TimeActivityChart")
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "**Chart area (438×100):** a single horizontal gradient fill, alpha-masked by the bar
    /// shapes."
    private var chartArea: some View {
        ZStack(alignment: .bottomLeading) {
            gradient
                .mask(alignment: .bottomLeading) { barRow }
            // A mask's subtree does not carry its preferences up, so the same row is laid out
            // once more, fully transparent, purely to publish the per-bar element anchors. It
            // paints nothing and the mask above is still what renders.
            barRow
                .opacity(0)
                .ui2Element("Bar mask")
        }
        .frame(width: Geometry.width, height: Geometry.chartHeight, alignment: .bottomLeading)
        .ui2Element("Chart area")
    }

    /// §2: "**Bar mask** … bottom-anchored to y=100; sample holds 88 bars (88 × 5 ≈ 438 — bin
    /// count = width ÷ 5px pitch)".
    private var barRow: some View {
        HStack(alignment: .bottom, spacing: Geometry.barGap) {
            ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: Geometry.barRadius, style: .continuous)
                    .frame(width: Geometry.barWidth, height: height)
                    .ui2Element("Bar \(index + 1)")
            }
        }
    }

    /// §2: "**Tick row (24pt, inset 16, justified space-between):** 4 × C-022 MetaPair".
    private var tickRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(tickLabels.enumerated()), id: \.offset) { index, tick in
                if index > 0 { Spacer(minLength: 0) }
                MetaPair(value: tick.value, unit: tick.unit)
                    .ui2Element("MetaPair \(index + 1)")
            }
        }
        // §2's inset is INSIDE the 438 root, so the width is pinned outermost and the padding
        // narrows the proposal the space-between HStack receives (438 − 2×16 = 406).
        .frame(height: Geometry.tickRowHeight)
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(width: Geometry.width)
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
