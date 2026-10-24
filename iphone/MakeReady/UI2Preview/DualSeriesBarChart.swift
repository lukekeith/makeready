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
/// Chrome-free. C-026 §2: "**Width-driven, intrinsic height 149** … the chart fills the width
/// its consumer gives it … and paints no background". Every y in this file is a measured
/// position from §2's vertical map; every x was measured at the design's 440 width and is
/// re-anchored to the width given (see `Geometry`).
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

    /// C-026 §4 `today: Date` — "the caller's current date; the component never reads the
    /// clock (R-04/R-19). Today rendering ⇔ `today` ∈ `window`; columns after `today` are
    /// track-only. Required (R-07)."
    let today: Date

    /// C-026 §4 `onWindowChange` — "emitted during pan with the proposed new window; the caller
    /// writes it back to `window` and syncs the shared timeline". Called whole day by whole day
    /// as the finger moves (Luke 2026-10-15), and by the VoiceOver adjustable action (OQ-C-026-001).
    let onWindowChange: (ClosedRange<Date>) -> Void

    /// The window a horizontal pan moved to — nil until the first pan, and dropped whenever the
    /// consumer passes a different `window` (the shared timeline moved from elsewhere). Held
    /// here so the chart pans even for a consumer that does not feed `onPan` back.
    @SwiftUI.State private var pannedWindow: ClosedRange<Date>?
    /// The window under the finger when the current drag began.
    @SwiftUI.State private var dragStartWindow: ClosedRange<Date>?

    init(
        days: [Day],
        window: ClosedRange<Date>,
        today: Date,
        onWindowChange: @escaping (ClosedRange<Date>) -> Void = { _ in }
    ) {
        self.days = days
        self.window = window
        self.today = today
        self.onWindowChange = onWindowChange
    }

    // MARK: - §2 geometry

    /// C-026 §2's vertical map, verbatim. These are measured positions in the component's own
    /// coordinate space, not token-family values. The x values are §2's measurements at the
    /// design's 440 width, kept as TRAILING offsets (the badges) and a leading inset + trailing
    /// inset (the tick row), so they reproduce §2 exactly at 440 — how they anchor at any other
    /// width is undesigned (OQ-C-026-005's ruling does not settle it; reported).
    private enum Geometry {
        static let designWidth: CGFloat = 440       // §2: "measured at the design's 440 width"
        static let height: CGFloat = 149            // §2: "intrinsic height 149"
        static let highGridlineY: CGFloat = 23      // §2: "23 | High gridline"
        static let lowGridlineY: CGFloat = 109      // §2: "109 | Low gridline"
        static let baselineY: CGFloat = 129         // §2: "23–129 | Column plot area (baseline y=129)"
        static let tallestColumn: CGFloat = 98      // §2: "tallest sample column 98pt"
        static let badgeHeight: CGFloat = 15        // §2: max badge "0–15", min badge "86–101"
        static let maxBadgeWidth: CGFloat = designWidth - 409   // §2: "container at x=409"
        static let minBadgeWidth: CGFloat = designWidth - 416   // §2: "value text at x=416"
        static let minBadgeY: CGFloat = 86
        static let tickRowY: CGFloat = 137          // §2: "137–152 | Tick row"
        static let tickRowInset: CGFloat = 15       // §2: "inset x=15, width 400"
        static let tickRowTrailingInset: CGFloat = designWidth - 15 - 400
        static let todayLabelY: CGFloat = 2         // §2: today label "y=2"
        static let todayRuleWidth: CGFloat = 1      // §2: "**solid** 1px `color-highlight`"

        /// §2: the plot area runs from the high gridline to the baseline.
        static var plotHeight: CGFloat { baselineY - highGridlineY }
    }

    // FLAGGED LITERAL — C-026 §2: "0.5pt … dash 2/2" for both gridlines. No stroke-width or dash
    // token exists; OQ-C-026-004 ruled them flagged literals (the C-024 §2 treatment).
    private static let hairlineWidth: CGFloat = 0.5
    private static let hairlineDash: [CGFloat] = [2, 2]

    // C-026 §2: badges and tick labels are Regular 12. OQ-home-dashboard-5 ruled "Use SF Pro
    // for everything, do not use Inter", which makes them exactly `type-caption`.
    private static let annotationStyle = Token.TypeStyle.caption

    // FLAGGED LITERAL — C-026 §2: the TODAY label is Bold 10 (SF Pro per OQ-home-dashboard-5).
    // No 10pt type token exists; OQ-C-026-004 ruled it a flagged literal.
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

    /// The window on screen: the consumer's, or where a pan has moved it since.
    private var shownWindow: ClosedRange<Date> { pannedWindow ?? window }

    /// §2: "one [column] per day of `window`". Every calendar day of the shown window, each
    /// paired with its `Day` when `days` has one (a missing day draws as an empty column).
    private var windowDays: [(date: Date, day: Day?)] {
        let cal = Self.utcCalendar
        let start = cal.startOfDay(for: shownWindow.lowerBound)
        let count = (cal.dateComponents([.day], from: start, to: shownWindow.upperBound).day ?? 0) + 1
        return (0..<max(count, 0)).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (date, days.first { cal.isDate($0.date, inSameDayAs: date) })
        }
    }

    /// The `Day` entries inside the shown window — what the badges and the scale read.
    private var visibleDays: [Day] { windowDays.compactMap(\.day) }

    /// §3 empty window + OQ-C-026-1/-010: "an empty or all-zero window renders the tick row
    /// only (no columns, gridlines or badges)".
    private var hasData: Bool { visibleDays.contains { $0.scheduled > 0 } }

    /// `today` ∈ `window`, by calendar day — a `today` carrying a time of day still falls in a
    /// window whose bounds are midnights.
    private var todayInWindow: Bool {
        shownWindow.contains(Self.utcCalendar.startOfDay(for: today))
    }

    /// §3: "`state` is **derived, not a free prop**: the Today rendering applies exactly when
    /// `today` ∈ `window`".
    private var todayIndex: Int? {
        guard todayInWindow else { return nil }
        return windowDays.firstIndex {
            Self.utcCalendar.isDate($0.date, inSameDayAs: today)
        }
    }

    /// §2: "column height ∝ **scheduled** count". §4: `window` drives "the max/min badge
    /// values" — recomputed per visible window, which is OQ-C-026-3's proposed default.
    private var maxScheduled: Int { visibleDays.map(\.scheduled).max() ?? 0 }
    private var minScheduled: Int { visibleDays.map(\.scheduled).min() ?? 0 }

    /// §2: "flex-equal width (13.24pt at 29 across 440), gap 2 (`space-chip-gap`)" — the
    /// columns span the full given width, gaps included.
    private func columnWidth(in width: CGFloat) -> CGFloat {
        let count = windowDays.count
        guard count > 0 else { return 0 }
        let gaps = CGFloat(count - 1) * Token.Space.chipGap
        return (width - gaps) / CGFloat(count)
    }

    /// §2: "vertical rule centred in the 2pt gap **after** today's column (sample: today's
    /// column spans x 335.3–348.6, rule x=349, next column starts 350.6)" — OQ-C-026-008 kept
    /// the contract. The rule's 1pt sits centred in the gap: today's trailing edge + (gap − 1)/2.
    private func todayRuleX(in width: CGFloat) -> CGFloat? {
        guard let index = todayIndex else { return nil }
        let column = columnWidth(in: width)
        let trailingEdge = CGFloat(index) * (column + Token.Space.chipGap) + column
        return trailingEdge + (Token.Space.chipGap - Geometry.todayRuleWidth) / 2
    }

    // GAP — C-026 §2 gives "tallest sample column 98pt" as a measurement, not a scale rule.
    // OQ-C-026-003 was answered "a default size, but it can be controlled by prop", but §4
    // declares no such prop yet, so the default stands alone: the window's max `scheduled`
    // maps to 98pt. Reported for a contract card.
    private func columnHeight(_ value: Int) -> CGFloat {
        guard maxScheduled > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxScheduled) * Geometry.tallestColumn
    }

    /// §2: "~5 date labels at data-driven x offsets", derived from `window` — not from the
    /// days in it (OQ-C-026-010) — so an empty window still has its tick row. A 7-day stride
    /// from the window start; the derivation itself is still unruled (OQ-C-026-002's answer
    /// asks for bucketed ticks the contract does not yet describe — reported).
    private var tickLabels: [String] {
        let dates = windowDays.map(\.date)
        return stride(from: 0, to: dates.count, by: 7).map {
            Self.tickFormatter.string(from: dates[$0])
        }
    }

    /// OQ-C-026-001: the value "summarises the visible window (\"Jul 3 to Jul 31, today Jul 26\")".
    private var accessibilitySummary: String {
        let range = "\(Self.tickFormatter.string(from: shownWindow.lowerBound)) to "
            + Self.tickFormatter.string(from: shownWindow.upperBound)
        guard todayInWindow else { return range }
        return range + ", today " + Self.tickFormatter.string(from: today)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                // §3 empty window, ruled by OQ-C-026-1/-010: tick row only.
                if hasData {
                    columnPlot(width: width)
                    gridline(Token.highlight, width: width)
                        .offset(y: Geometry.highGridlineY)
                        .ui2Element("High gridline")
                    gridline(Token.white50, width: width)
                        .offset(y: Geometry.lowGridlineY)
                        .ui2Element("Low gridline")
                    maxBadge(width: width)
                    minBadge(width: width)
                    todayOverlay(width: width)
                }
                tickRow(width: width)
            }
            .frame(width: width, height: Geometry.height, alignment: .topLeading)
            .onAppear { plotWidth = width }
            .onChange(of: width) { _, newWidth in plotWidth = newWidth }
        }
        // §2: "fills the width its consumer gives it", intrinsic height 149.
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.height)
        .contentShape(Rectangle())
        // Simultaneous, so a vertical drag still scrolls the page the chart sits in; the pan
        // only claims drags that run more sideways than up/down.
        .simultaneousGesture(panGesture)
        .onChange(of: window) { _, newWindow in
            if newWindow != pannedWindow { pannedWindow = nil }
        }
        // OQ-C-026-001: one element, "Daily activity", adjustable one week at a time.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily activity")
        .accessibilityValue(accessibilitySummary)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pan(to: shifted(shownWindow, byDays: 7))
            case .decrement: pan(to: shifted(shownWindow, byDays: -7))
            @unknown default: break
            }
        }
        .ui2Element("DualSeriesBarChart")
    }

    // MARK: - Pan (Luke 2026-10-15: free pan that snaps to whole days; a fling carries on)

    /// The width the chart was last laid out at — the pan's finger-to-day ratio reads it.
    @SwiftUI.State private var plotWidth: CGFloat = Geometry.designWidth

    /// One column's pitch — how far the finger travels to move the window by a day.
    private var dayPitch: CGFloat { max(columnWidth(in: plotWidth) + Token.Space.chipGap, 1) }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let start = dragStartWindow ?? shownWindow
                if dragStartWindow == nil {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragStartWindow = start
                }
                // Dragging right reveals earlier days.
                pan(to: shifted(start, byDays: -Int((value.translation.width / dayPitch).rounded())))
            }
            .onEnded { value in
                guard let start = dragStartWindow else { return }
                dragStartWindow = nil
                let days = -Int((value.predictedEndTranslation.width / dayPitch).rounded())
                withAnimation(.snappy) { pan(to: shifted(start, byDays: days)) }
            }
    }

    private func pan(to target: ClosedRange<Date>) {
        guard target != shownWindow else { return }
        pannedWindow = target
        onWindowChange(target)
    }

    /// `base` moved by whole days, kept the same length and clamped inside the loaded `days`.
    private func shifted(_ base: ClosedRange<Date>, byDays offset: Int) -> ClosedRange<Date> {
        let cal = Self.utcCalendar
        guard let first = days.map(\.date).min(), let last = days.map(\.date).max() else { return base }
        let length = cal.dateComponents([.day], from: base.lowerBound, to: base.upperBound).day ?? 0
        let earliest = cal.dateComponents([.day], from: first, to: base.lowerBound).day ?? 0
        let latest = cal.dateComponents([.day], from: base.upperBound, to: last).day ?? 0
        let clamped = min(max(offset, -max(earliest, 0)), max(latest, 0))
        guard clamped != 0,
              let lower = cal.date(byAdding: .day, value: clamped, to: base.lowerBound),
              let upper = cal.date(byAdding: .day, value: length, to: lower) else { return base }
        return lower...upper
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "23–129 | Column plot area (baseline y=129; columns bottom-anchored)".
    private func columnPlot(width: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
            ForEach(Array(windowDays.enumerated()), id: \.offset) { index, entry in
                column(entry.day, isFuture: entry.date > today)
                    .ui2Element("Column \(index + 1)")
            }
        }
        .frame(width: width, height: Geometry.plotHeight, alignment: .bottom)
        .offset(y: Geometry.highGridlineY)
        .ui2Element("Column plot area")
    }

    /// §2: "a bottom segment of height ∝ **completed** count fills `color-accent`
    /// (Purple/100%); the remainder above it is the track, `color-white-20`" — square corners.
    /// §2: "**Every column dated after `today` renders track-only** — its fill is not drawn
    /// whatever `completed` holds" — compared by date, so a fully-future window (Default
    /// rendering) is track-only too (§3). Today's own column keeps its fill.
    private func column(_ day: Day?, isFuture: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Token.white20)
            Rectangle()
                .fill(Token.accent)
                .frame(height: isFuture ? 0 : columnHeight(day?.completed ?? 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: columnHeight(day?.scheduled ?? 0))
    }

    /// §2: "full-width hairline, 0.5pt … dash 2/2" — for both gridlines.
    private func gridline(_ color: Color, width: CGFloat) -> some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: Self.hairlineWidth, dash: Self.hairlineDash))
        .frame(width: width, height: Self.hairlineWidth)
    }

    /// §2: "0–15 | **Max badge**: value text, container at x=409, Regular 12 `color-highlight`"
    /// — trailing-anchored. The vestigial r4 wrapper §2 describes carries no fill or border and
    /// has "no visual effect", so it is not rendered.
    private func maxBadge(width: CGFloat) -> some View {
        Text(String(maxScheduled))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.highlight)
            .frame(width: Geometry.maxBadgeWidth, height: Geometry.badgeHeight, alignment: .trailing)
            .offset(x: width - Geometry.maxBadgeWidth)
            .ui2Element("Max badge")
    }

    /// §2: "86–101 | **Min badge**: value text at x=416, Regular 12 `color-text-primary`".
    private func minBadge(width: CGFloat) -> some View {
        Text(String(minScheduled))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.textPrimary)
            .frame(width: Geometry.minBadgeWidth, height: Geometry.badgeHeight, alignment: .trailing)
            .offset(x: width - Geometry.minBadgeWidth, y: Geometry.minBadgeY)
            .ui2Element("Min badge")
    }

    /// §2: "137–152 | Tick row: inset x=15, width 400; ~5 date labels at data-driven x offsets
    /// … Regular 12 `color-white-50`".
    private func tickRow(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tickLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .designTextStyle(Self.annotationStyle)
                    .foregroundStyle(Token.white50)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(
            width: max(width - Geometry.tickRowInset - Geometry.tickRowTrailingInset, 0),
            alignment: .leading
        )
        .offset(x: Geometry.tickRowInset, y: Geometry.tickRowY)
        .ui2Element("Tick row")
    }

    /// §2 Today overlay (Today rendering only): "vertical rule centred in the 2pt gap **after**
    /// today's column … **solid** 1pt `color-highlight`, y 23–129 (h 106); 'TODAY' label Bold 10
    /// `color-highlight`, ending at the rule".
    @ViewBuilder
    private func todayOverlay(width: CGFloat) -> some View {
        if let todayRuleX = todayRuleX(in: width) {
            Rectangle()
                .fill(Token.highlight)
                .frame(width: Geometry.todayRuleWidth, height: Geometry.plotHeight)
                .offset(x: todayRuleX, y: Geometry.highGridlineY)
                .ui2Element("Today rule")
            // §2 samples the label container at x=331; the normative statement is "ending at
            // the rule", so the label is anchored there and its own width runs left.
            Text("TODAY")
                .designTextStyle(Self.todayLabelStyle)
                .foregroundStyle(Token.highlight)
                .frame(width: todayRuleX, height: Geometry.badgeHeight, alignment: .trailing)
                .offset(y: Geometry.todayLabelY)
                .ui2Element("TODAY label")
        }
    }
}
