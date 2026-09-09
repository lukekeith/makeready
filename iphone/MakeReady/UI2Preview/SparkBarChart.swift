//
//  SparkBarChart.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-024-spark-bar-chart.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-024 SparkBarChart — in-card miniature single-series bar chart over a time period.
///
/// Chrome-free and container-driven. C-024 §4 Sizing is explicit that this component has **no
/// intrinsic size**: it fills the height and width of its container, and a fixed-height
/// rendering is achieved by fixing the container. The 97×64 symbols in the frozen snapshot are
/// samples of that, not a footprint. Frame, background and outer padding therefore belong to
/// the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct SparkBarChart: View {

    /// C-024 §4 `align: top ⊕ / center / bottom`.
    enum Align: String {
        /// Owner-ruled 2026-09-07 (C-024 §3, OQ-C-024-1 resolved): the exact vertical mirror
        /// of `bottom` — bars hang from the top edge, annotation stack mirrored below its
        /// line. There is no Figma symbol for it; C-024 §1 carries it as a closed-list
        /// deviation, which is why its render has no counterpart in the frozen snapshot.
        case top
        case center
        case bottom
    }

    /// C-024 §4 `widthFill ⊕`: how the row fills the container width. §4 names exactly two
    /// modes and gives the discriminator — "bars stretch (wider bars, 2pt gap)" vs "gaps
    /// stretch (2pt bars, wider gaps)". Whether this stays an explicit prop or becomes an
    /// automatic rule keyed to bar count is OQ-C-024-3.
    enum WidthFill: String {
        case bars
        case gaps
    }

    /// C-024 §4 `averageLabelSide ⊕: left / right`.
    enum LabelSide: String {
        /// UNDESIGNED (C-024 §2/§3, OQ-C-024-4). Built as the OQ's proposed default: the
        /// mirror of the right placement. No fixture state renders it.
        case left
        case right
    }

    /// C-024 §4: `series: [Double]` — the single data series over the period, any point count.
    let series: [Double]
    /// C-024 §4: `targetBars: Int?` — nil = one bar per point.
    let targetBars: Int?
    /// C-024 §4: `align` — bar anchoring.
    let align: Align
    /// C-024 §4: `widthFill` — how the row fills the container width.
    let widthFill: WidthFill
    /// C-024 §4: `showAverage: Bool` — render the dashed average line at the series-average y.
    let showAverage: Bool
    /// C-024 §4: `averageLabel: String?` — label at the average line; nil = line only.
    let averageLabel: String?
    /// C-024 §4: `averageLabelSide` — label placement.
    let averageLabelSide: LabelSide

    // §2: "Bars: 2pt wide, corner radius 2 (`radius-bar`)… zero values render as 2×2pt dots."
    //
    // FLAGGED LITERAL — C-024 §2: "No new tokens; flagged literals: 2pt bar/dot module and the
    // 0.5pt dash-2/2 hairline." The contract flags it, so rule 4's flagged-literal path applies
    // and it is NOT silently promoted to a token.
    private static let barModule: CGFloat = 2

    // FLAGGED LITERAL — C-024 §2, same sentence: the 0.5pt dash-2/2 hairline.
    private static let hairlineWidth: CGFloat = 0.5
    private static let hairlineDash: [CGFloat] = [2, 2]

    var body: some View {
        GeometryReader { geo in
            let bars = resolvedSeries
            let metrics = rowMetrics(width: geo.size.width, count: bars.count)
            ZStack(alignment: .topLeading) {
                barRow(bars, metrics: metrics, height: geo.size.height)
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height,
                        alignment: Alignment(horizontal: .center, vertical: rowVerticalAlignment)
                    )
                if showAverage {
                    averageAnnotation(bars, size: geo.size).ui2Element("Average")
                }
            }
        }
        .ui2Element("SparkBarChart")                  // capture element map — UI2Element.swift
    }

    // MARK: - Series

    /// §4 `targetBars`: "when `series.count` exceeds it, values are aggregated per bucket to
    /// consolidate into `targetBars` bars".
    ///
    /// OQ-C-024-2 default taken: SUM per bucket over equal-width buckets — the OQ's own
    /// proposed default ("counts/durations; mean would flatten peaks"). No fixture state sets
    /// `targetBars`, so this path is built but not captured.
    private var resolvedSeries: [Double] {
        guard let targetBars, targetBars > 0, series.count > targetBars else { return series }
        return (0..<targetBars).map { bucket in
            let lower = series.count * bucket / targetBars
            let upper = series.count * (bucket + 1) / targetBars
            return series[lower..<upper].reduce(0, +)
        }
    }

    // MARK: - Horizontal layout

    private struct RowMetrics {
        let barWidth: CGFloat
        let gap: CGFloat
    }

    /// §2: "Horizontal row of bars, gap 2 (`space-chip-gap`), justified center." §4's two
    /// `widthFill` modes decide which of the two absorbs the container's slack.
    private func rowMetrics(width: CGFloat, count: Int) -> RowMetrics {
        let gaps = CGFloat(max(count - 1, 0))
        switch widthFill {
        case .gaps:
            // §4: "gaps stretch (2pt bars, wider gaps)" — the bar keeps §2's 2pt module.
            let slack = width - CGFloat(count) * Self.barModule
            let gap = gaps > 0 ? max(Token.Space.chipGap, slack / gaps) : Token.Space.chipGap
            return RowMetrics(barWidth: Self.barModule, gap: gap)
        case .bars:
            // §4: "bars stretch (wider bars, 2pt gap)" — the gap keeps §2's `space-chip-gap`.
            let slack = width - gaps * Token.Space.chipGap
            let barWidth = count > 0 ? max(Self.barModule, slack / CGFloat(count)) : Self.barModule
            return RowMetrics(barWidth: barWidth, gap: Token.Space.chipGap)
        }
    }

    // MARK: - Bars

    private var rowVerticalAlignment: VerticalAlignment {
        switch align {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        }
    }

    private func barRow(_ bars: [Double], metrics: RowMetrics, height: CGFloat) -> some View {
        HStack(alignment: rowVerticalAlignment, spacing: metrics.gap) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: Token.Radius.bar)
                    // §2: fill `color-accent`.
                    .fill(Token.accent)
                    .frame(width: metrics.barWidth, height: barHeight(value, of: bars, in: height))
                    // Per-bar, so a comment can name the point it is about. A 2pt bar is a
                    // 2pt target; the pointer falling in a gap resolves to `Bars` instead.
                    .ui2Element("Bar \(index + 1)")
            }
        }
        .ui2Element("Bars")
    }

    /// §4 Sizing: "Bar heights scale to the container: series max → full available height
    /// (half-height per side when centered)." §2: "zero values render as 2×2pt dots", which is
    /// the 2pt floor — and is the whole of the `No activity` state (§3: derived, all-zero).
    ///
    /// `center` needs no halving here: the row is centred as a whole, so a bar of the maximum
    /// value spans the full container height with half of it either side of the centreline,
    /// which is exactly what §4's parenthesis describes.
    private func barHeight(_ value: Double, of bars: [Double], in height: CGFloat) -> CGFloat {
        let maxValue = bars.max() ?? 0
        guard maxValue > 0, value > 0 else { return Self.barModule }
        return max(Self.barModule, CGFloat(value / maxValue) * height)
    }

    // MARK: - Average annotation

    /// §2: "a stack (gap 4, items-end) positioned at the average value's y — label (SF Pro
    /// Semibold 12/12 `color-text-secondary`; sample "24hrs") right-aligned above a full-width
    /// dashed hairline, 0.5pt `color-white-50` dash 2/2".
    @ViewBuilder
    private func averageAnnotation(_ bars: [Double], size: CGSize) -> some View {
        let y = averageY(bars, height: size.height)
        if align == .top {
            // §3 `align=top` (owner ruling 2026-09-07, OQ-C-024-1): the exact vertical mirror
            // of `bottom` — so the stack mirrors too, hairline first with the label BELOW it,
            // and the stack's TOP edge sits on the average y.
            VStack(alignment: labelHorizontalAlignment, spacing: Token.Space.metaGap) {
                hairline(width: size.width)
                label
            }
            .frame(width: size.width, height: max(size.height - y, 0), alignment: .top)
            .offset(y: max(y, 0))
        } else {
            VStack(alignment: labelHorizontalAlignment, spacing: Token.Space.metaGap) {
                label
                hairline(width: size.width)
            }
            // The stack's LAST item is the hairline, so bottom-aligning the stack inside a
            // frame that ends at the average y puts the hairline on the average and the label
            // above it.
            .frame(width: size.width, height: max(y, 0) + Self.hairlineWidth, alignment: .bottom)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let averageLabel {
            Text(averageLabel)
                .designTextStyle(Token.TypeStyle.captionSemibold)
                .foregroundColor(Token.textSecondary)
                .ui2Element("Average label")
        }
    }

    /// The y of a bar whose value is the series average — the same scale `scaledHeight` uses,
    /// measured from whichever edge `align` anchors to.
    ///
    /// `center` is NOT designed: C-024 §3 records "no annotation designed in the center
    /// samples", and no fixture state pairs `center` with `showAverage`. It is derived here as
    /// the top edge of a centred bar of the average value, so the prop stays total.
    private func averageY(_ bars: [Double], height: CGFloat) -> CGFloat {
        let maxValue = bars.max() ?? 0
        let mean = bars.isEmpty ? 0 : bars.reduce(0, +) / Double(bars.count)
        let extent = maxValue > 0 ? CGFloat(mean / maxValue) * height : 0
        switch align {
        case .bottom: return height - extent
        case .top: return extent
        case .center: return height / 2 - extent / 2
        }
    }

    private var labelHorizontalAlignment: HorizontalAlignment {
        averageLabelSide == .right ? .trailing : .leading
    }

    /// §2: full-width dashed hairline — "the program's standard chart hairline".
    private func hairline(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: Self.hairlineWidth / 2))
            path.addLine(to: CGPoint(x: width, y: Self.hairlineWidth / 2))
        }
        .stroke(
            Token.white50,
            style: StrokeStyle(lineWidth: Self.hairlineWidth, dash: Self.hairlineDash)
        )
        .frame(width: width, height: Self.hairlineWidth)
        .ui2Element("Average line")
    }
}
