//
//  DualSeriesBarChart.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-026-dual-series-bar-chart.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-026 DualSeriesBarChart — pannable day-column time chart: scheduled track + completed fill
/// per day.
///
/// Chrome-free. C-026 §2 states a **fixed footprint of 440×149** ("full-bleed within
/// `space-page-margin` insets on consumers"), so unlike C-024 this component owns both of its
/// own axes and the call site adds only the ground it is framed on (preview-build.md OQ-PB-2).
/// 440pt is also exactly the iPhone 16 Pro Max logical width, which is why the ViewRegistry
/// call site adds no page margin — see the note there.
///
/// Every x/y in this file is a measured position from §2's vertical map, in the component's
/// own 440×149 coordinate space.
struct DualSeriesBarChart: View {

    /// C-026 §4 `days: [(date, scheduled: Int, completed: Int)]` — one entry per day of the
    /// loaded timeline. §2: "Completed ≤ scheduled by construction."
    struct Day: Equatable {
        let date: Date
        let scheduled: Int
        let completed: Int
    }

    /// C-026 §4 `days` — the loaded timeline; `window` selects the slice that renders.
    let days: [Day]
    /// C-026 §4 `window: date range` — the visible slice. Drives which columns render, the tick
    /// labels, the max/min badge values, and the derived Default/Today rendering (§3).
    let window: ClosedRange<Date>

    /// CAPTURE SEAM — not a §4 prop.
    ///
    /// C-026 §3 makes `state` **derived, not a free prop**: "Today rendering applies exactly
    /// when today's date falls inside the visible window." Read straight off the clock that
    /// derivation is correct but not reproducible — the same fixture would render Today or
    /// Default depending on the day it was captured, and the frozen-snapshot diff would drift
    /// on its own. So "now" is injected, defaulted to the real clock: production callers use
    /// `DualSeriesBarChart(days:window:)` and get §3's derivation unchanged, while the capture
    /// pins it. This is the same accommodation preview-build.md OQ-PB-3 makes for
    /// interaction-bearing props (keep the real signature, neutralise it for capture), but no
    /// OQ-PB row covers it yet — raised in this build's report for an owner ruling.
    let today: Date

    /// C-026 §4 `onPan: callback` — "pan handler; the consumer syncs the shared timeline".
    /// §4 does not type it, so it carries no argument here. No render effect: emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3's default).
    let onPan: () -> Void

    init(
        days: [Day],
        window: ClosedRange<Date>,
        today: Date = Date(),
        onPan: @escaping () -> Void = {}
    ) {
        self.days = days
        self.window = window
        self.today = today
        self.onPan = onPan
    }

    // MARK: - §2 geometry

    /// C-026 §2's vertical map and footprint, verbatim. These are measured positions in the
    /// component's own coordinate space, not token-family values.
    private enum Geometry {
        static let width: CGFloat = 440             // §2: fixed footprint 440×149
        static let height: CGFloat = 149
        static let highGridlineY: CGFloat = 23      // §2: "23 | High gridline"
        static let lowGridlineY: CGFloat = 109      // §2: "109 | Low gridline"
        static let baselineY: CGFloat = 129         // §2: "23–129 | Column plot area (baseline y=129)"
        static let tallestColumn: CGFloat = 98      // §2: "tallest sample column 98pt"
        static let badgeHeight: CGFloat = 15        // §2: max badge "0–15", min badge "86–101"
        static let maxBadgeX: CGFloat = 409         // §2: "container at x=409"
        static let minBadgeX: CGFloat = 416         // §2: "value text at x=416"
        static let minBadgeY: CGFloat = 86
        static let tickRowY: CGFloat = 137          // §2: "137–152 | Tick row"
        static let tickRowInset: CGFloat = 15       // §2: "inset x=15, width 400"
        static let tickRowWidth: CGFloat = 400
        static let todayLabelY: CGFloat = 2         // §2: today label "y=2"
        static let todayRuleWidth: CGFloat = 1      // §2: "**solid** 1px `color-highlight`"

        /// §2: the plot area runs from the high gridline to the baseline.
        static var plotHeight: CGFloat { baselineY - highGridlineY }
    }

    // GAP — C-026 §2: "0.5pt … dash 2/2" for both gridlines. `tokens.md` has no stroke-width or
    // dash family, and unlike C-024 §2 this contract's flagged-literal list does NOT cover them
    // ("Flagged literals: none beyond the vestigial r4 wrappers and the Inter annotation font").
    // Contract-traceable, so emitted as a literal and raised as an OQ rather than stopping.
    private static let hairlineWidth: CGFloat = 0.5
    private static let hairlineDash: [CGFloat] = [2, 2]

    // FLAGGED LITERAL — C-026 §2: badges and tick labels are "Inter Regular 12", and §2 closes
    // "Flagged literals: none beyond the vestigial r4 wrappers and the Inter annotation font
    // (OQ-home-dashboard-5)". `tokens.md` § Typography states Inter is deliberately NOT
    // tokenized. Inter is also not bundled in this app, so naming it in `.custom` would fall
    // back to the system face silently while claiming otherwise — the size and weight are
    // honoured here and the face is reported as a gap instead. Size/weight match `type-caption`
    // (SF Pro Regular 12/14); the local style exists to carry the flag, not to shadow a token.
    private static let annotationStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 14, tracking: 0
    )

    // GAP — C-026 §2: the TODAY label is "Inter Bold 10". `tokens.md` has no 10pt row at all
    // (`type-caption-bold` is Bold 12), so this is contract-traceable with no token to name.
    // Same Inter caveat as `annotationStyle`.
    private static let todayLabelStyle = DesignTextStyle(
        weight: .bold, size: 10, lineHeight: nil, tracking: 0
    )

    /// §2's tick labels ("Jul 3 / Jul 10 / …"). UTC throughout so a fixture's dates render as
    /// the day they name regardless of the simulator's zone.
    private static let tickFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "MMM d"
        return f
    }()

    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return c
    }()

    // MARK: - Derived state (§3)

    /// §4: `window` "drives which columns render".
    private var visibleDays: [Day] {
        days.filter { window.contains($0.date) }
    }

    /// §3: "`state` is **derived, not a free prop**: Today rendering applies exactly when
    /// today's date falls inside the visible window."
    private var todayIndex: Int? {
        guard window.contains(today) else { return nil }
        return visibleDays.firstIndex {
            Self.utcCalendar.isDate($0.date, inSameDayAs: today)
        }
    }

    /// §2: "column height ∝ **scheduled** count". §4: `window` drives "the max/min badge
    /// values" — recomputed per visible window, which is OQ-C-026-3's proposed default.
    private var maxScheduled: Int { visibleDays.map(\.scheduled).max() ?? 0 }
    private var minScheduled: Int { visibleDays.map(\.scheduled).min() ?? 0 }

    /// §2: "flex-equal width (≈13.24pt at 29 columns), gap 2 (`space-chip-gap`)" — i.e. the
    /// columns span the full 440 footprint, gaps included.
    private var columnWidth: CGFloat {
        let count = visibleDays.count
        guard count > 0 else { return 0 }
        let gaps = CGFloat(count - 1) * Token.Space.chipGap
        return (Geometry.width - gaps) / CGFloat(count)
    }

    /// §2: "vertical rule at today's column boundary (sample x=349)" — derived from the column
    /// pitch rather than pinned to the sample, which lands within ~1.5pt of it at 29 columns.
    private var todayRuleX: CGFloat? {
        guard let index = todayIndex else { return nil }
        return CGFloat(index) * (columnWidth + Token.Space.chipGap)
    }

    // GAP — C-026 §2 gives "tallest sample column 98pt" as a MEASUREMENT and explicitly calls
    // the fills illustrative ("sample fills are illustrative, per the sheet's sample-data
    // convention"); it never states the value→height rule, and the badge values (42/3) do not
    // sit on the same scale as the columns in the frozen snapshot. Implemented as the reading
    // that reproduces §2's measurement: the window's max scheduled maps to 98pt.
    private func columnHeight(_ value: Int) -> CGFloat {
        guard maxScheduled > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxScheduled) * Geometry.tallestColumn
    }

    /// §2: "~5 date labels at data-driven x offsets". A 7-day stride over the sample's 29-day
    /// window yields exactly five, the last of them the window's final day.
    ///
    /// §2's sample strings are "Jul 3 / Jul 10 / Jul 17 / Jul 24 / Aug 2", which span 31 days
    /// and so cannot all come off one stride over a 29-column window; §2's own sample-data
    /// convention covers them, and the derivation itself is unstated — reported as a gap.
    private var tickLabels: [String] {
        stride(from: 0, to: visibleDays.count, by: 7).map {
            Self.tickFormatter.string(from: visibleDays[$0].date)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // OQ-C-026-1 proposed default: an empty window renders "tick row only; no columns,
            // no gridlines, no badges". §3 carries the state as UNDESIGNED, so rule 7 gives it
            // no fixture state — this guard is the proposed default standing in for one, and
            // nothing in the fixture reaches it.
            if !visibleDays.isEmpty {
                columnPlot
                gridline(Token.highlight)
                    .offset(y: Geometry.highGridlineY)
                    .ui2Element("High gridline")
                gridline(Token.white50)
                    .offset(y: Geometry.lowGridlineY)
                    .ui2Element("Low gridline")
                maxBadge
                minBadge
                todayOverlay
            }
            tickRow
        }
        .frame(width: Geometry.width, height: Geometry.height, alignment: .topLeading)
        .ui2Element("DualSeriesBarChart")
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "23–129 | Column plot area (baseline y=129; columns bottom-anchored)".
    private var columnPlot: some View {
        HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
            ForEach(Array(visibleDays.enumerated()), id: \.offset) { index, day in
                column(day, isFuture: isFuture(index))
                    .ui2Element("Column \(index + 1)")
            }
        }
        .frame(width: Geometry.width, height: Geometry.plotHeight, alignment: .bottom)
        .offset(y: Geometry.highGridlineY)
        .ui2Element("Column plot area")
    }

    /// §3 Today: "the 6 columns right of the rule render **track-only** (future days have no
    /// completions)". STRICTLY right of the rule, which sits on today's own leading boundary —
    /// so today keeps its fill. That is OQ-C-026-2's proposed default ("today's column shows
    /// its real partial fill; only future columns are track-only") and it deliberately differs
    /// from the frozen snapshot, where today's fill layer is hidden (`3672:10393`).
    private func isFuture(_ index: Int) -> Bool {
        guard let todayIndex else { return false }
        return index > todayIndex
    }

    /// §2: "a bottom segment of height ∝ **completed** count fills `color-accent`
    /// (Purple/100%); the remainder above it is the track, `color-white-20`" — square corners.
    private func column(_ day: Day, isFuture: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Token.white20)
            Rectangle()
                .fill(Token.accent)
                .frame(height: isFuture ? 0 : columnHeight(day.completed))
        }
        .frame(maxWidth: .infinity)
        .frame(height: columnHeight(day.scheduled))
    }

    /// §2: "full-width hairline, 0.5pt … dash 2/2" — for both gridlines.
    private func gridline(_ color: Color) -> some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: Geometry.width, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: Self.hairlineWidth, dash: Self.hairlineDash))
        .frame(width: Geometry.width, height: Self.hairlineWidth)
    }

    /// §2: "0–15 | **Max badge**: value text right-aligned, container at x=409, Inter Regular 12
    /// `color-highlight`". The vestigial r4 wrapper §2 describes carries no fill or border and
    /// has "no visual effect", so it is not rendered.
    private var maxBadge: some View {
        Text(String(maxScheduled))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.highlight)
            .frame(
                width: Geometry.width - Geometry.maxBadgeX,
                height: Geometry.badgeHeight,
                alignment: .trailing
            )
            .offset(x: Geometry.maxBadgeX)
            .ui2Element("Max badge")
    }

    /// §2: "86–101 | **Min badge**: value text at x=416, Inter Regular 12 `color-text-primary`".
    private var minBadge: some View {
        Text(String(minScheduled))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.textPrimary)
            .frame(
                width: Geometry.width - Geometry.minBadgeX,
                height: Geometry.badgeHeight,
                alignment: .trailing
            )
            .offset(x: Geometry.minBadgeX, y: Geometry.minBadgeY)
            .ui2Element("Min badge")
    }

    /// §2: "137–152 | Tick row: inset x=15, width 400; ~5 date labels at data-driven x offsets
    /// … Inter Regular 12 `color-white-50`".
    private var tickRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(tickLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .designTextStyle(Self.annotationStyle)
                    .foregroundStyle(Token.white50)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: Geometry.tickRowWidth, alignment: .leading)
        .offset(x: Geometry.tickRowInset, y: Geometry.tickRowY)
        .ui2Element("Tick row")
    }

    /// §2 Today overlay (`state=Today` only): "vertical rule at today's column boundary …
    /// **solid** 1px `color-highlight`, spanning high gridline → baseline (y 23–129, h 106);
    /// 'TODAY' label Inter Bold 10 `color-highlight` right-aligned to the rule".
    @ViewBuilder
    private var todayOverlay: some View {
        if let todayRuleX {
            Rectangle()
                .fill(Token.highlight)
                .frame(width: Geometry.todayRuleWidth, height: Geometry.plotHeight)
                .offset(x: todayRuleX, y: Geometry.highGridlineY)
                .ui2Element("Today rule")
            // §2 samples the label container at x=331, which is narrower than "TODAY" renders
            // at Bold 10; the normative statement is "right-aligned to the rule", so the label
            // is anchored there and its own width runs left.
            Text("TODAY")
                .designTextStyle(Self.todayLabelStyle)
                .foregroundStyle(Token.highlight)
                .frame(width: todayRuleX, height: Geometry.badgeHeight, alignment: .trailing)
                .offset(y: Geometry.todayLabelY)
                .ui2Element("TODAY label")
        }
    }
}
