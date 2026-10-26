//
//  DualSeriesBarChart.swift
//  MakeReadyUI — the UI 2.0 module
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
    /// as the columns scroll, a fling's coast included (Luke 2026-10-15), and by the VoiceOver
    /// adjustable action (OQ-C-026-001).
    let onWindowChange: (ClosedRange<Date>) -> Void

    /// Bumped by the consumer to bring the columns back to `window` — "Jump to today" (D31/D20).
    /// The chart scrolls there itself with `recenterAnimation`, which also stops a running fling;
    /// re-creating the chart instead would snap it back with no motion.
    let recenterRequest: Int
    let recenterAnimation: Animation

    // GAP — C-026: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). Columns sweep in toward today, the
    /// completed fill climbs after, then the today rule drops and its badge pops.
    let intro: ChartIntro?

    /// The timeline index of the column at the leading edge — the scroll view's own position, so
    /// the chart pans even for a consumer that does not feed `onWindowChange` back.
    @SwiftUI.State private var leadingColumn: ColumnID?
    /// The leading column's timeline index.
    private var leadingDay: Int? { leadingColumn?.index }

    /// A column's scroll id. Its own type, so a consumer's ScrollViewReader that scrolls other
    /// views by Int ids (the day rail beside this chart) can never move these columns.
    struct ColumnID: Hashable {
        let index: Int
    }
    /// The window chart and consumer last agreed on: what the chart emitted, or what the consumer
    /// passed. A `window` equal to it is the consumer echoing a pan and must not scroll the
    /// columns back under a coasting fling.
    @SwiftUI.State private var syncedWindow: ClosedRange<Date>?
    /// True while a finger, or the fling it left, drives the columns.
    @SwiftUI.State private var userScrolling = false
    /// The timeline index the tick labels count from, fixed when the chart first appears so the
    /// labels scroll with their days instead of re-stepping on every pan.
    @SwiftUI.State private var tickPhase: Int?

    init(
        days: [Day],
        window: ClosedRange<Date>,
        today: Date,
        onWindowChange: @escaping (ClosedRange<Date>) -> Void = { _ in },
        recenterRequest: Int = 0,
        recenterAnimation: Animation = .easeInOut(duration: 0.45),
        intro: ChartIntro? = nil
    ) {
        self.days = days
        self.window = window
        self.today = today
        self.onWindowChange = onWindowChange
        self.recenterRequest = recenterRequest
        self.recenterAnimation = recenterAnimation
        self.intro = intro
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
        static let todayLabelY: CGFloat = 2         // §2: today label "y=2"
        static let todayRuleWidth: CGFloat = 1      // §2: "**solid** 1px `color-highlight`"
        /// Owner ruling 2026-10-25 (ui2-shell): an empty window draws one baseline stub per day,
        /// as C-030's empty strip does — the same 3pt stub height as C-030 `barMinHeight`.
        static let emptyStubHeight: CGFloat = 3

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

    /// Every calendar day the chart can scroll across: the loaded `days`, widened to cover
    /// `window`, each paired with its `Day` when `days` has one (a missing day draws as an empty
    /// column). The columns are laid out once over this whole timeline and scroll — they are
    /// never re-filled in place, which made a pan morph every column instead of sliding them.
    private struct Timeline {
        let dates: [Date]
        let entries: [Day?]
        /// Days in `window`, inclusive — how many columns fill the chart's width.
        let windowLength: Int
        /// The timeline index of `window`'s first day.
        let windowStart: Int
        /// The timeline index of `today`, when the timeline holds it.
        let todayIndex: Int?
        /// The scale and both badges. Owner ruling 2026-10-25 (ui2-shell): a column is its day —
        /// once drawn it never changes height — so the max/min are the WHOLE loaded timeline's,
        /// not the visible window's (OQ-C-026-3's per-window default rescaled every column
        /// whenever a pan changed the window's max).
        let maxScheduled: Int
        let minScheduled: Int

        init(days: [Day], window: ClosedRange<Date>, today: Date, calendar cal: Calendar) {
            var byDay: [Date: Day] = [:]
            for day in days { byDay[cal.startOfDay(for: day.date)] = day }
            let windowLower = cal.startOfDay(for: window.lowerBound)
            let windowUpper = cal.startOfDay(for: window.upperBound)
            let first = min(byDay.keys.min() ?? windowLower, windowLower)
            let last = max(byDay.keys.max() ?? windowUpper, windowUpper)
            let count = (cal.dateComponents([.day], from: first, to: last).day ?? 0) + 1
            dates = (0..<max(count, 0)).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
            entries = dates.map { byDay[$0] }
            windowLength = max((cal.dateComponents([.day], from: windowLower, to: windowUpper).day ?? 0) + 1, 1)
            windowStart = cal.dateComponents([.day], from: first, to: windowLower).day ?? 0
            let todayStart = cal.startOfDay(for: today)
            todayIndex = dates.firstIndex(of: todayStart)
            maxScheduled = days.map(\.scheduled).max() ?? 0
            minScheduled = days.map(\.scheduled).min() ?? 0
        }

        /// The furthest a leading column can go and still fill the width.
        var lastLeadingIndex: Int { max(dates.count - windowLength, 0) }

        func clampedLeading(_ index: Int) -> Int { min(max(index, 0), lastLeadingIndex) }

        /// The window whose first column is `leading`.
        func window(leading: Int) -> ClosedRange<Date>? {
            let lower = clampedLeading(leading)
            let upper = min(lower + windowLength - 1, dates.count - 1)
            guard dates.indices.contains(lower), dates.indices.contains(upper) else { return nil }
            return dates[lower]...dates[upper]
        }

        /// §3 empty window + OQ-C-026-1/-010 as amended 2026-10-25: a timeline with nothing
        /// scheduled draws the baseline stubs and the tick row only.
        var hasData: Bool { maxScheduled > 0 }
    }

    private func timeline() -> Timeline {
        Timeline(days: days, window: window, today: today, calendar: Self.utcCalendar)
    }

    /// §2: "flex-equal width (13.24pt at 29 across 440), gap 2 (`space-chip-gap`)" — the
    /// window's columns span the full given width, gaps included.
    private static func columnWidth(in width: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let gaps = CGFloat(count - 1) * Token.Space.chipGap
        return max((width - gaps) / CGFloat(count), 0)
    }

    // GAP — C-026 §2 gives "tallest sample column 98pt" as a measurement, not a scale rule.
    // OQ-C-026-003 was answered "a default size, but it can be controlled by prop", but §4
    // declares no such prop yet, so the default stands alone: the timeline's max `scheduled`
    // maps to 98pt. Reported for a contract card.
    private static func columnHeight(_ value: Int, max maxScheduled: Int) -> CGFloat {
        guard maxScheduled > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxScheduled) * Geometry.tallestColumn
    }

    /// A column's height at intro progress `progress` — the still height at 1.
    static func introColumnHeight(_ value: Int, max maxScheduled: Int, progress: Double) -> CGFloat {
        ChartIntro.scaled(columnHeight(value, max: maxScheduled), by: progress)
    }

    /// D3: when the today rule starts — after the sweep reaches the window's right edge, capped
    /// at 0.4 s so the badge's 0.6 s rise ends by 1.1 s.
    static func introSettle(windowLength: Int) -> Double {
        min(ChartIntroMotion.stagger(windowLength - 1, of: windowLength), 0.4)
    }

    /// OQ-C-026-001: the value "summarises the visible window (\"Jul 3 to Jul 31, today Jul 26\")".
    private func accessibilitySummary(_ shown: ClosedRange<Date>) -> String {
        let range = "\(Self.tickFormatter.string(from: shown.lowerBound)) to "
            + Self.tickFormatter.string(from: shown.upperBound)
        guard shown.contains(Self.utcCalendar.startOfDay(for: today)) else { return range }
        return range + ", today " + Self.tickFormatter.string(from: today)
    }

    // MARK: - Body

    var body: some View {
        let line = timeline()
        let leading = line.clampedLeading(leadingDay ?? line.windowStart)
        let shown = line.window(leading: leading) ?? window
        let progress = intro?.progress(fadeOnly: !line.hasData) ?? 1
        return GeometryReader { proxy in
            let width = proxy.size.width
            let column = Self.columnWidth(in: width, count: line.windowLength)
            ScrollViewReader { reader in
                ZStack(alignment: .topLeading) {
                    // Luke 2026-10-15: a free pan that settles on whole days, and a fling carries
                    // on — a real scroll view, so the coast is UIKit's own (HorizontalScrolling.swift).
                    HorizontalRail(showsIndicators: false) {
                        columns(line, column: column, progress: progress)
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                    .scrollPosition(id: $leadingColumn, anchor: .leading)
                    .onScrollPhaseChange { _, phase in
                        userScrolling = phase == .interacting || phase == .decelerating
                        if phase == .idle { emitIfMoved(line) }
                    }
                    .onChange(of: leadingColumn) { _, _ in
                        if userScrolling { emitIfMoved(line) }
                    }
                    if line.hasData {
                        Group {
                            gridline(Token.highlight, width: width)
                                .offset(y: Geometry.highGridlineY)
                                .ui2Element("High gridline")
                            gridline(Token.white50, width: width)
                                .offset(y: Geometry.lowGridlineY)
                                .ui2Element("Low gridline")
                            maxBadge(line.maxScheduled, width: width)
                            minBadge(line.minScheduled, width: width)
                        }
                        .opacity(progress)
                        .animation(intro?.animation(ChartIntroMotion.draw), value: intro?.played)
                    }
                }
                .frame(width: width, height: Geometry.height, alignment: .topLeading)
                .onAppear {
                    tickPhase = tickPhase ?? line.windowStart + 1
                    syncedWindow = window
                    leadingColumn = ColumnID(index: line.clampedLeading(line.windowStart))
                }
                // The consumer moved the window (Jump to today, the day rail): scroll there. A
                // direct scroll, so it also stops a fling still coasting. The consumer echoing
                // the chart's own pan is not a move.
                .onChange(of: window) { _, newWindow in
                    guard newWindow != syncedWindow else { return }
                    syncedWindow = newWindow
                    let fresh = timeline()
                    let target = fresh.clampedLeading(fresh.windowStart)
                    userScrolling = false
                    reader.scrollTo(ColumnID(index: target), anchor: .leading)
                    leadingColumn = ColumnID(index: target)
                }
                .onChange(of: recenterRequest) { _, _ in
                    let fresh = timeline()
                    let target = fresh.clampedLeading(fresh.windowStart)
                    syncedWindow = window
                    userScrolling = false
                    withAnimation(recenterAnimation) {
                        reader.scrollTo(ColumnID(index: target), anchor: .leading)
                        leadingColumn = ColumnID(index: target)
                    }
                }
            }
        }
        // §2: "fills the width its consumer gives it", intrinsic height 149.
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.height)
        // OQ-C-026-001: one element, "Daily activity", adjustable one week at a time.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily activity")
        .accessibilityValue(accessibilitySummary(shown))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(line, from: leading, byDays: 7)
            case .decrement: step(line, from: leading, byDays: -7)
            @unknown default: break
            }
        }
        .chartIntroMorph(intro, value: days)              // D9
        .chartIntroFade(intro, fadeOnly: !line.hasData)   // D16
        .ui2Element("DualSeriesBarChart")
    }

    // MARK: - Pan

    /// Tells the consumer the window the columns now show, once per whole-day change.
    private func emitIfMoved(_ line: Timeline) {
        guard let leadingDay, let moved = line.window(leading: leadingDay), moved != syncedWindow else { return }
        syncedWindow = moved
        onWindowChange(moved)
    }

    /// The VoiceOver adjustable action: a week at a time.
    private func step(_ line: Timeline, from leading: Int, byDays offset: Int) {
        let target = line.clampedLeading(leading + offset)
        guard target != leading, let moved = line.window(leading: target) else { return }
        withAnimation(.snappy) { leadingColumn = ColumnID(index: target) }
        syncedWindow = moved
        onWindowChange(moved)
    }

    // MARK: - Parts (§2 anatomy)

    /// §2: "23–129 | Column plot area (baseline y=129; columns bottom-anchored)" — one column per
    /// day of the whole timeline, each a scroll target so a pan settles on a whole day. The tick
    /// labels and the Today overlay ride on the columns, so they scroll with their days.
    private func columns(_ line: Timeline, column: CGFloat, progress: Double) -> some View {
        let pitch = column + Token.Space.chipGap
        return HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
            ForEach(line.dates.indices, id: \.self) { index in
                // D2: the sweep runs left to right across the window and ends at today.
                let wave = ChartIntroMotion.stagger(max(index - line.windowStart, 0), of: line.windowLength)
                Group {
                    if line.hasData {
                        bar(line.entries[index], isFuture: line.dates[index] > today, max: line.maxScheduled,
                            progress: progress, wave: wave)
                    } else {
                        // Owner ruling 2026-10-25: the empty timeline's baseline — one
                        // track-coloured stub per day column, as C-030's empty strip does.
                        Rectangle()
                            .fill(Token.white20)
                            .frame(height: Geometry.emptyStubHeight)
                    }
                }
                .frame(width: column, height: Geometry.plotHeight, alignment: .bottom)
                .ui2Element(line.hasData ? "Column \(index + 1)" : "Empty stub \(index + 1)")
                .id(ColumnID(index: index))
            }
        }
        .scrollTargetLayout()
        .padding(.top, Geometry.highGridlineY)
        .padding(.bottom, Geometry.height - Geometry.baselineY)
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                tickLabels(line, pitch: pitch)
                if line.hasData { todayOverlay(line, column: column, pitch: pitch, progress: progress) }
            }
        }
        .ui2Element("Column plot area")
    }

    /// §2: "a bottom segment of height ∝ **completed** count fills `color-accent`
    /// (Purple/100%); the remainder above it is the track, `color-white-20`" — square corners.
    /// §2: "**Every column dated after `today` renders track-only** — its fill is not drawn
    /// whatever `completed` holds" — compared by date, so a fully-future window (Default
    /// rendering) is track-only too (§3). Today's own column keeps its fill.
    private func bar(_ day: Day?, isFuture: Bool, max maxScheduled: Int, progress: Double, wave: Double) -> some View {
        let completed = isFuture ? 0 : min(day?.completed ?? 0, day?.scheduled ?? 0)
        return ZStack(alignment: .bottom) {
            Rectangle().fill(Token.white20)
            Rectangle()
                .fill(Token.accent)
                // Completed is drawn INSIDE scheduled: a day reporting more completions than
                // it scheduled fills its column and never grows past it.
                .frame(height: Self.introColumnHeight(completed, max: maxScheduled, progress: progress))
                .animation(intro?.animation(ChartIntroMotion.draw, after: wave + 0.15), value: intro?.played)
        }
        .frame(height: Self.introColumnHeight(day?.scheduled ?? 0, max: maxScheduled, progress: progress))
        .clipped()
        .animation(intro?.animation(ChartIntroMotion.rise, after: wave), value: intro?.played)
    }

    /// §2: "137–152 | Tick row … ~5 date labels at data-driven x offsets … Regular 12
    /// `color-white-50`". A label every 7 days, each at its own day's column; the first sits one
    /// column in from the opening window's start — §2's "inset x=15" at the design's 440.
    private func tickLabels(_ line: Timeline, pitch: CGFloat) -> some View {
        let phase = tickPhase ?? line.windowStart + 1
        let first = ((phase % 7) + 7) % 7
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: first, to: line.dates.count, by: 7)), id: \.self) { index in
                Text(Self.tickFormatter.string(from: line.dates[index]))
                    .designTextStyle(Self.annotationStyle)
                    .foregroundStyle(Token.white50)
                    .fixedSize()
                    .offset(x: CGFloat(index) * pitch, y: Geometry.tickRowY)
            }
        }
        .ui2Element("Tick row")
    }

    /// §2 Today overlay: "vertical rule centred in the 2pt gap **after** today's column (sample:
    /// today's column spans x 335.3–348.6, rule x=349, next column starts 350.6) … **solid** 1pt
    /// `color-highlight`, y 23–129 (h 106); 'TODAY' label Bold 10 `color-highlight`, ending at
    /// the rule". It scrolls with today's column, so it shows exactly when `today` ∈ the shown
    /// window (§3's derived Today rendering).
    @ViewBuilder
    private func todayOverlay(_ line: Timeline, column: CGFloat, pitch: CGFloat, progress: Double) -> some View {
        if let index = line.todayIndex {
            let ruleX = CGFloat(index) * pitch + column + (Token.Space.chipGap - Geometry.todayRuleWidth) / 2
            let settle = Self.introSettle(windowLength: line.windowLength)
            Rectangle()
                .fill(Token.highlight)
                .frame(width: Geometry.todayRuleWidth, height: Geometry.plotHeight)
                .scaleEffect(x: 1, y: progress, anchor: .top)
                .animation(intro?.animation(ChartIntroMotion.draw, after: settle), value: intro?.played)
                .offset(x: ruleX, y: Geometry.highGridlineY)
                .ui2Element("Today rule")
            // §2 samples the label container at x=331; the normative statement is "ending at
            // the rule", so the label is anchored there and its own width runs left.
            Text("TODAY")
                .designTextStyle(Self.todayLabelStyle)
                .foregroundStyle(Token.highlight)
                .fixedSize()
                .scaleEffect(0.6 + 0.4 * progress, anchor: .trailing)
                .opacity(progress)
                .animation(intro?.animation(ChartIntroMotion.rise, after: settle + 0.1), value: intro?.played)
                .frame(width: ruleX, height: Geometry.badgeHeight, alignment: .trailing)
                .offset(y: Geometry.todayLabelY)
                .ui2Element("TODAY label")
        }
    }

    /// §2: "full-width hairline, 0.5pt … dash 2/2" — for both gridlines.
    private func gridline(_ color: Color, width: CGFloat) -> some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: Self.hairlineWidth, dash: Self.hairlineDash))
        .frame(width: width, height: Self.hairlineWidth)
        .allowsHitTesting(false)
    }

    /// §2: "0–15 | **Max badge**: value text, container at x=409, Regular 12 `color-highlight`"
    /// — trailing-anchored. The vestigial r4 wrapper §2 describes carries no fill or border and
    /// has "no visual effect", so it is not rendered.
    private func maxBadge(_ value: Int, width: CGFloat) -> some View {
        Text(String(value))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.highlight)
            .frame(width: Geometry.maxBadgeWidth, height: Geometry.badgeHeight, alignment: .trailing)
            .offset(x: width - Geometry.maxBadgeWidth)
            .allowsHitTesting(false)
            .ui2Element("Max badge")
    }

    /// §2: "86–101 | **Min badge**: value text at x=416, Regular 12 `color-text-primary`".
    private func minBadge(_ value: Int, width: CGFloat) -> some View {
        Text(String(value))
            .designTextStyle(Self.annotationStyle)
            .foregroundStyle(Token.textPrimary)
            .frame(width: Geometry.minBadgeWidth, height: Geometry.badgeHeight, alignment: .trailing)
            .offset(x: width - Geometry.minBadgeWidth, y: Geometry.minBadgeY)
            .allowsHitTesting(false)
            .ui2Element("Min badge")
    }
}
