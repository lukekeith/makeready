//
//  HomeDashboardScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen home-dashboard in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/analytics/query ·
//  GET /api/analytics/meta · GET/PUT /api/preferences/{key} · GET /api/engagement/heatmap ·
//  GET /api/programs/{programId}/enrollments · GET /api/groups/{groupId}/enrollments ·
//  GET /api/enrollments/{id}/completion-stats · GET /api/enrollments/{id}/sync
//  (sessions, the engagement aggregate and the assembled followed-enrollments payload are
//  API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Home (leader dashboard) — the Home tab root (§6). Five sections on the page background,
/// separated by hairlines, on the page background.
/// App chrome (C-019 TopNav, C-084 TabBar) is the shell's — ui2-shell D11; this screen renders
/// content only. Composed only of §4's
/// C-019, C-020, C-023, C-026, C-027, C-029, C-030, C-031, C-032 and C-033; C-021, C-022,
/// C-024, C-028, C-062 and C-077 render only inside those (§4).
///
/// §3 names four per-section states — `loading`, `populated`, `empty`, `error`. This build
/// renders `populated` and `empty`; `loading` (a skeleton placeholder) and `error` (an inline
/// retry) name no §4 component and no geometry, so they are reported as spec defects and not
/// improvised here.
struct HomeDashboardScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel
    /// arrays, one entry per rail card / program / group card, because the preview's props
    /// are JSON and the §4 views take flat parameters (R-05).
    struct State {
        // ── Overview (§2.1) ──
        /// C-022's value in the header — "N metrics" = the count of enabled metrics (§3).
        var metricCount: String
        /// C-023 `kind=metric` ×3: title, headline value, C-077 direction / polarity / label,
        /// C-024 average label, and the 24-point series each card passes to C-024.
        var kpiTitles: [String]
        var kpiValues: [String]
        var kpiTrendDirections: [String]
        var kpiTrendPolarities: [String]
        var kpiTrendLabels: [String]
        /// "" = no average label (C-023 §4: nil = line only).
        var kpiAverageLabels: [String]
        var kpiSeries: [[Double]]
        // ── Activity (§2.2) ──
        /// C-023 `kind=day · transparent` ×4: C-070 month / weekday / day / state, the C-024
        /// series, and C-071 line1 / line2 / state.
        var dayMonths: [String]
        var dayWeekdays: [String]
        var dayNumbers: [String]
        var dayDateStates: [String]
        var daySeries: [[Double]]
        var dayLine1s: [String]
        var dayLine2s: [String]
        var dayDetailsStates: [String]
        /// Each day card's date as yyyy-MM-dd (UTC) — what ties the rail to C-026's timeline so
        /// panning either moves the other. Empty = the rail does not follow the chart.
        var dayDates: [String] = []
        /// C-026's timeline — one entry per day, dates as yyyy-MM-dd (UTC) — its visible
        /// window, and the caller's "today" (C-026 §4: the component never reads the clock).
        var chartDates: [String]
        var chartScheduled: [Int]
        var chartCompleted: [Int]
        var chartWindowStart: String
        var chartWindowEnd: String
        var chartToday: String
        // ── Sessions (§2.3) ──
        /// C-028's current option, from `sessionRanges` (§3: All time · Year · Month · Week).
        var sessionRange: String
        /// C-029: 24 hourly values (index 0 = 12 AM) and the centre key value.
        var hourValues: [Double]
        var centerValue: String
        var centerUnit: String
        var centerCaption: String
        /// C-030: one intensity per 5pt bin (88 at 438pt) and its four C-022 tick pairs.
        var bins: [Double]
        var sessionTickValues: [String]
        var sessionTickUnits: [String]
        // ── Engagement (§2.4) ──
        /// C-022's value in the header — "N active" (OQ-home-dashboard-1, deferred).
        var activeCount: String
        /// C-031, in its §4 order.
        var engagementPercent: Int
        var engagementLabel: String
        var engagementCount: Int
        var engagementProgress: Double
        var engagementSubtitle: String
        var engagementColor: String
        // ── Following (§2.5) ──
        /// C-022's value in the header — "N enrollments" ("0" in §3's Following `empty`).
        var followedCount: String
        /// C-032 ×N, one per followed program.
        var programTitles: [String]
        var programAuthors: [String]
        var programCreatedLabels: [String]
        /// C-033 ×M, each pointing at its program by index into `programTitles`.
        var groupProgramIndices: [Int]
        var groupTitles: [String]
        /// "" = no photo → C-038's initials fallback.
        var groupPhotoURLs: [String]
        var groupMembers: [String]
        var groupPercents: [String]
        var groupColors: [String]
        var groupShowLinks: [Bool]
    }

    let state: State
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with
    // R-03's no-op default. The screen never decides what an action means.
    var onPickMetrics: () -> Void = {}                 // Overview plus → home-kpi-picker
    var onJumpToToday: () -> Void = {}                 // "Jump to today" recenters both timelines
    var onSelectSessionRange: (String) -> Void = { _ in } // C-028 time range → re-scopes §2.3
    var onOpenEngagement: () -> Void = {}              // Engagement arrow → OQ-home-dashboard-1
    var onFollowEnrollment: () -> Void = {}            // Following plus → home-follow-picker
    var onProgramMenu: (Int) -> Void = { _ in }        // C-032 ellipsis → OQ-home-dashboard-4
    var onOpenGroup: (Int) -> Void = { _ in }          // C-033 tap → OQ-home-dashboard-4
    /// dashboard-chart-intros D7: only the live app (HomeDashboardContainer) passes true; every
    /// capture, fixture and preview leaves the charts still.
    let introsEnabled: Bool

    init(
        state: State,
        onPickMetrics: @escaping () -> Void = {},
        onJumpToToday: @escaping () -> Void = {},
        onSelectSessionRange: @escaping (String) -> Void = { _ in },
        onOpenEngagement: @escaping () -> Void = {},
        onFollowEnrollment: @escaping () -> Void = {},
        onProgramMenu: @escaping (Int) -> Void = { _ in },
        onOpenGroup: @escaping (Int) -> Void = { _ in },
        introsEnabled: Bool = false
    ) {
        self.state = state
        self.onPickMetrics = onPickMetrics
        self.onJumpToToday = onJumpToToday
        self.onSelectSessionRange = onSelectSessionRange
        self.onOpenEngagement = onOpenEngagement
        self.onFollowEnrollment = onFollowEnrollment
        self.onProgramMenu = onProgramMenu
        self.onOpenGroup = onOpenGroup
        self.introsEnabled = introsEnabled
    }

    // The Sessions range re-scopes data through
    // `onSelectSessionRange`. The day rail and the chart scroll INDEPENDENTLY (owner 2026-10-25,
    // superseding the 2026-10-15 two-way sync: syncing them on every pan step slowed the UI).
    // Both open on today at the right; "Jump to today" brings both back.

    /// The day card at the rail's leading edge.
    @SwiftUI.State private var railDay: Int?
    /// The chart has been panned off `state`'s window (kept only for the link's state).
    @SwiftUI.State private var chartOffToday = false
    /// Bumped by "Jump to today": the chart eases its columns back to `state`'s window.
    @SwiftUI.State private var chartRecenter = 0
    /// Whether any part of today's day card is in the rail's view. Only the flip is stored, so a
    /// scrolling rail does not re-render the whole screen every frame.
    @SwiftUI.State private var todayCardOnScreen = true
    private static let railWindowLead = 2
    /// dashboard-chart-intros D5/D15: which sections have played this visit.
    @SwiftUI.State private var introLedger = ChartIntroLedger()
    @Environment(\.chartIntroActive) private var introActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: the section titles, top → bottom.
    private static let overviewTitle = "Overview"
    private static let activityTitle = "Activity"
    private static let sessionsTitle = "Sessions"
    private static let engagementTitle = "Engagement"
    private static let followingTitle = "Following"
    /// §2.1 / §2.4 / §2.5: the C-022 labels beside each header's count.
    private static let metricsLabel = "metrics"
    private static let activeLabel = "active"
    private static let enrollmentsLabel = "enrollments"
    /// §2.2: the Activity header's C-049 `style=muted` link (C-020 §4 correction 2026-09-15).
    private static let jumpToTodayLabel = "Jump to today"
    /// §3: the Sessions dropdown's closed option list.
    private static let sessionRanges = ["All time", "Year", "Month", "Week"]
    /// §2.2: the legend — "Completed lessons" purple dot, "Scheduled lessons" gray dot
    /// (C-027 `primary` = `color-accent`, `secondary` = `color-white-20`).
    private static let completedLegendLabel = "Completed lessons"
    private static let scheduledLegendLabel = "Scheduled lessons"

    // MARK: - §2 geometry the screen owns

    // GAP — home-dashboard §2.1: "C-023 RailCard `kind=metric` 140×192" — a contract width
    // with no spacing token; the card fills the width the rail gives it (C-023 §2a).
    private static let metricCardWidth: CGFloat = 140
    // GAP — home-dashboard §2.2: "RailCard `kind=day · transparent` 131×192".
    private static let dayCardWidth: CGFloat = 131
    // GAP — home-dashboard §2.2: "cards butt together with shared 1px vertical borders
    // (−1 overlap)".
    private static let dayCardOverlap: CGFloat = -1
    // GAP — home-dashboard §2.2: "DualSeriesBarChart 440×149 full-bleed".
    private static let dualChartWidth: CGFloat = 440
    private static let dualChartHeight: CGFloat = 149
    // GAP — home-dashboard §2.3: "TimeActivityChart 438×140".
    private static let timeChartWidth: CGFloat = 438
    private static let timeChartHeight: CGFloat = 140
    // GAP — home-dashboard §2.3: "→ 16pt → TimeActivityChart"; the frozen frame `default`
    // draws the same 16 between the Sessions header and the radial clock. No 16pt vertical-spacing token (page-margin and
    // card-padding are horizontal roles).
    private static let chartGap: CGFloat = 16
    // GAP — home-dashboard frame `default` (element map 2026-09-26): every section header
    // sits 32 above its first block (Overview 119→151, Activity 430→462, Engagement
    // 1562→1593, Following 1745→1777). §2.1 writes "→ 8pt →" for the Overview rail; the frame
    // measures 32, so the build follows the frame and the §2 line is reported.
    private static let headerGap: CGFloat = Token.Space.sectionGap
    // GAP — home-dashboard §2: "1px `color-layout-border` hairlines" — no stroke-width token.
    private static let hairline: CGFloat = 1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's
        // full length, so the page lays out top to bottom at full height.
        VStack(alignment: .leading, spacing: 0) {
            // Owner ruling OQ-spreview-home-dashboard-populated-1 (2026-10-19): the Following
            // section (the group cards) moves to the top of the page, ahead of §2's order.
            followingSection
            sectionDivider
            overviewSection.modifier(revealsIntro(.overview))
            sectionDivider
            activitySection.modifier(revealsIntro(.activity))
            sectionDivider
            sessionsSection.modifier(revealsIntro(.sessions))
            sectionDivider
            engagementSection.modifier(revealsIntro(.engagement))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        // D6/D15: cleared while Home sits hidden under another tab; visible sections replay on return.
        .onChange(of: introActive) { _, active in introLedger.setActive(active) }
    }

    /// §2: "Five sections separated by 1px `color-layout-border` hairlines with
    /// `space-section-gap` (32) above and below the divider."
    private var sectionDivider: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(maxWidth: .infinity)
            .frame(height: Self.hairline)
            .padding(.vertical, Token.Space.sectionGap)
    }

    // MARK: §2.1 Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: Self.overviewTitle,
                accessory: .meta(value: state.metricCount, label: Self.metricsLabel, glyph: .add),
                onAccessoryTap: onPickMetrics
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader")
            Spacer().frame(height: Self.headerGap)
            // §2.1: "horizontally scrolling KPI rail … gap 8, leading inset 16, rail overflows
            // the viewport." A horizontal carousel keeps its own ScrollView (D22).
            HorizontalRail {
                HStack(alignment: .top, spacing: Token.Space.elementGap) {
                    ForEach(state.kpiTitles.indices, id: \.self) { index in
                        RailCard(
                            kind: .metric,
                            title: state.kpiTitles[index],
                            series: state.kpiSeries[safe: index] ?? [],
                            averageLabel: Self.optionalText(state.kpiAverageLabels[safe: index]),
                            value: state.kpiValues[safe: index] ?? "",
                            trendDirection: TrendIndicator.Direction(
                                rawValue: state.kpiTrendDirections[safe: index] ?? ""
                            ) ?? .neutral,
                            trendPolarity: TrendIndicator.Polarity(
                                rawValue: state.kpiTrendPolarities[safe: index] ?? ""
                            ) ?? .neutral,
                            trendLabel: state.kpiTrendLabels[safe: index] ?? "",
                            intro: intro(.overview, delay: Self.cascadeDelay(index: index, lead: 0))
                        )
                        .frame(width: Self.metricCardWidth)
                        .ui2Element(Self.partName("C-023 RailCard", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: §2.2 Activity

    private var activitySection: some View {
        // The reader lets "Jump to today" scroll the rail directly — a binding write the rail
        // already holds would not move it, and a direct scroll also stops a running fling.
        ScrollViewReader { rail in
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(
                    title: Self.activityTitle,
                    // ui2-shell D31: C-049 `default` (`color-accent`) while today's day card is off
                    // screen; the designed `muted` while it shows, where a tap has nowhere to go.
                    accessory: .link(label: Self.jumpToTodayLabel, style: todayCardOnScreen && !chartOffToday ? .muted : .default),
                    onAccessoryTap: { jumpToToday(rail) }
                )
                .padding(.horizontal, Token.Space.pageMargin)
                .ui2Element("C-020 SectionHeader 2")
                Spacer().frame(height: Self.headerGap)
                // §2.2: "day rail … 131×192, cards butt together with shared 1px vertical borders
                // (−1 overlap), leading inset 16, horizontal scroll".
                HorizontalRail {
                    // Lazy: ~190 days of history (owner 2026-10-25) — only the cards on screen are built.
                    LazyHStack(alignment: .top, spacing: Self.dayCardOverlap) {
                        ForEach(state.dayNumbers.indices, id: \.self) { index in
                            RailCard(
                                kind: .day,
                                series: state.daySeries[safe: index] ?? [],
                                state: .transparent,
                                month: state.dayMonths[safe: index] ?? "",
                                weekday: state.dayWeekdays[safe: index] ?? "",
                                day: state.dayNumbers[index],
                                dateState: Self.dateState(state.dayDateStates[safe: index]),
                                line1: state.dayLine1s[safe: index] ?? "",
                                line2: Self.optionalText(state.dayLine2s[safe: index]),
                                detailsState: Self.detailsState(state.dayDetailsStates[safe: index]),
                                intro: intro(.activity, delay: Self.cascadeDelay(index: index, lead: railDay ?? 0))
                            )
                            .frame(width: Self.dayCardWidth)
                            .ui2Element(Self.partName("C-023 RailCard", ordinal: state.kpiTitles.count + index + 1))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, Token.Space.pageMargin)
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $railDay, anchor: .leading)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    Self.cardOnScreen(
                        index: todayDayIndex, visible: geometry.visibleRect,
                        leadingInset: Token.Space.pageMargin, width: Self.dayCardWidth,
                        step: Self.dayCardWidth + Self.dayCardOverlap
                    )
                } action: { _, onScreen in
                    todayCardOnScreen = onScreen
                }
                // The rail opens with its three whole cards ending on the window's last day (today).
                .onAppear { alignRail(to: chartWindow) }
                Spacer().frame(height: Token.Space.sectionGap)           // §2.2: "→ 32pt →"
                // §2.2: "DualSeriesBarChart 440×149 full-bleed". C-026 §3 derives Default/Today from
                // whether `today` ∈ `window`.
                DualSeriesBarChart(
                    days: chartDays,
                    window: chartWindow,
                    today: Self.chartDate(state.chartToday) ?? .distantPast,
                    onWindowChange: { window in
                        let off = window != chartWindow
                        if off != chartOffToday { chartOffToday = off }
                    },
                    recenterRequest: chartRecenter,
                    recenterAnimation: Self.jumpAnimation,
                    intro: intro(.activity)
                )
                .frame(width: Self.dualChartWidth, height: Self.dualChartHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("C-026 DualSeriesBarChart")
                Spacer().frame(height: Token.Space.sectionGap)           // frame `default`: 834→865
                // §2.2: "Legend row (LegendItem ×2 …), inset 16, gap 16."
                // GAP — home-dashboard §2.2: the 16pt gap between legend items has no spacing
                // token that names the role; `space-page-margin` is the same number.
                HStack(alignment: .center, spacing: Token.Space.pageMargin) {
                    LegendItem(color: Token.accent, label: Self.completedLegendLabel)
                        .ui2Element("C-027 LegendItem")
                    LegendItem(color: Token.white20, label: Self.scheduledLegendLabel)
                        .ui2Element("C-027 LegendItem 2")
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    // MARK: §2.3 Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: Self.sessionsTitle,
                // C-020 §4: the dropdown is a trigger that shows the caller's current range; the
                // C-036 menu over `sessionRanges` that commits to `onSelectSessionRange` is the
                // presenter's to wire at promotion.
                accessory: .dropdown(label: state.sessionRange)
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 3")
            Spacer().frame(height: Self.chartGap)
            // §2.3: "RadialDayClock centered, 280pt ring in a 357×326 chart area".
            RadialDayClock(
                hourValues: state.hourValues,
                centerValue: state.centerValue,
                centerUnit: state.centerUnit,
                centerCaption: state.centerCaption,
                intro: intro(.sessions)
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .ui2Element("C-029 RadialDayClock")
            Spacer().frame(height: Self.chartGap)                    // §2.3: "→ 16pt →"
            // §2.3: "TimeActivityChart 438×140" — at x=0 on the frame `default`.
            TimeActivityChart(bins: state.bins, tickLabels: sessionTickLabels, intro: intro(.sessions))
                .frame(width: Self.timeChartWidth, height: Self.timeChartHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("C-030 TimeActivityChart")
        }
    }

    // MARK: §2.4 Engagement

    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: Self.engagementTitle,
                accessory: .meta(value: state.activeCount, label: Self.activeLabel, glyph: .arrowForward),
                onAccessoryTap: onOpenEngagement
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 4")
            Spacer().frame(height: Self.headerGap)
            // §2.4: "EnrollmentStatusRow 408×64, inset 16" — the row is width-driven (C-031 §2).
            EnrollmentStatusRow(
                percent: state.engagementPercent,
                label: state.engagementLabel,
                count: state.engagementCount,
                progress: state.engagementProgress,
                subtitle: state.engagementSubtitle,
                statusColor: EnrollmentStatusRow.StatusColor(rawValue: state.engagementColor) ?? .green,
                intro: intro(.engagement)
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-031 EnrollmentStatusRow")
        }
    }

    // MARK: §2.5 Following

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                title: Self.followingTitle,
                accessory: .meta(value: state.followedCount, label: Self.enrollmentsLabel, glyph: .add),
                onAccessoryTap: onFollowEnrollment
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 5")
            // §3: the Following `empty` state "shows the header with "0 enrollments" + plus as
            // the only affordance" — no program blocks follow.
            ForEach(state.programTitles.indices, id: \.self) { programIndex in
                Spacer().frame(height: Self.headerGap)
                programBlock(programIndex)
            }
        }
    }

    /// §2.5: "per followed program: FollowedProgramHeader (40pt) → 32pt → horizontally
    /// scrolling GroupFollowCard rail 179×228, gap 8, leading inset 16 → 32pt → next program
    /// block." The 32 before each block is the ForEach's; this is the header and its rail.
    private func programBlock(_ programIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FollowedProgramHeader(
                title: state.programTitles[programIndex],
                author: state.programAuthors[safe: programIndex] ?? "",
                createdLabel: state.programCreatedLabels[safe: programIndex] ?? "",
                onMenu: { onProgramMenu(programIndex) }
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element(Self.partName("C-032 FollowedProgramHeader", ordinal: programIndex + 1))
            Spacer().frame(height: Token.Space.sectionGap)           // §2.5: "→ 32pt →"
            HorizontalRail {
                HStack(alignment: .top, spacing: Token.Space.elementGap) {
                    ForEach(groupIndices(for: programIndex), id: \.self) { groupIndex in
                        GroupFollowCard(
                            style: .noBar,                           // §4: `style=No bar` at all three colours
                            color: Self.bandColor(state.groupColors[safe: groupIndex]),
                            title: state.groupTitles[groupIndex],
                            photoURL: Self.optionalText(state.groupPhotoURLs[safe: groupIndex]),
                            members: state.groupMembers[safe: groupIndex] ?? "",
                            percent: state.groupPercents[safe: groupIndex] ?? "",
                            label: Self.completeLabel,
                            showLink: state.groupShowLinks[safe: groupIndex] ?? true,
                            progress: 0,                             // `default` only — unused in `noBar`
                            onTap: { onOpenGroup(groupIndex) }
                        )
                        .ui2Element(Self.partName("C-033 GroupFollowCard", ordinal: groupIndex + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// C-033 §4: "`label` — the word after `percent`" — "complete" on every card of the frame.
    private static let completeLabel = "complete"

    // MARK: - Derived (JSON-native props → the §4 views' types)

    /// D7: nil unless the live app turned intros on.
    private func intro(_ section: ChartIntroLedger.Section, delay: Double = 0) -> ChartIntro? {
        guard introsEnabled else { return nil }
        return ChartIntro(played: introLedger.hasPlayed(section), reduceMotion: reduceMotion, delay: delay)
    }

    /// D8: a rail card's cascade delay — its place from the rail's leading card, capped at the
    /// fourth. A lazy day card built later by a swipe is created already played, so it draws final.
    static func cascadeDelay(index: Int, lead: Int) -> Double {
        Double(min(max(index - lead, 0), 3)) * ChartIntroMotion.cascadeStep
    }

    /// D4: a section starts its intro when ≥ 50 % of it is in the Home page scroll.
    private func revealsIntro(_ section: ChartIntroLedger.Section) -> some ViewModifier {
        IntroReveal(enabled: introsEnabled) { introLedger.setVisible(section, $0) }
    }

    private func groupIndices(for programIndex: Int) -> [Int] {
        state.groupTitles.indices.filter { (state.groupProgramIndices[safe: $0] ?? 0) == programIndex }
    }

    private var chartDays: [DualSeriesBarChart.Day] {
        state.chartDates.indices.compactMap { index in
            guard let date = Self.chartDate(state.chartDates[index]) else { return nil }
            return DualSeriesBarChart.Day(
                date: date,
                scheduled: state.chartScheduled[safe: index] ?? 0,
                completed: state.chartCompleted[safe: index] ?? 0
            )
        }
    }

    private var chartWindow: ClosedRange<Date> {
        let start = Self.chartDate(state.chartWindowStart) ?? .distantPast
        let end = Self.chartDate(state.chartWindowEnd) ?? start
        return start...max(start, end)
    }

    // MARK: Shared timeline (day rail ⇄ C-026)

    /// ui2-shell D31 (owner 2026-10-25): whether any part of today's day card is inside the
    /// rail's visible rect. No rect yet (first frame) or no today card → treated as on screen.
    static func cardOnScreen(index: Int?, visible: CGRect?, leadingInset: CGFloat, width: CGFloat, step: CGFloat) -> Bool {
        guard let index, let visible else { return true }
        let minX = leadingInset + CGFloat(index) * step
        return minX + width > visible.minX && minX < visible.maxX
    }

    private var todayDayIndex: Int? { state.dayDateStates.firstIndex(of: "today") }

    // GAP — no motion token for the recentre: an ease-in-out, 0.45s.
    private static var jumpAnimation: Animation { .easeInOut(duration: 0.45) }

    /// ui2-shell D31: "Jump to today" eases both back to `state`'s window — the rail to today's
    /// card at the right, the chart's columns to today at its right edge — then tells the consumer.
    private func jumpToToday(_ rail: ScrollViewProxy) {
        // A direct scroll moves the rail even when the binding already holds the target, and
        // stops a fling still running.
        let lead = railLead(for: chartWindow, nearest: true)
        withAnimation(Self.jumpAnimation) {
            if let lead {
                railDay = lead
                rail.scrollTo(lead, anchor: .leading)
            }
        }
        chartRecenter += 1
        chartOffToday = false
        onJumpToToday()
    }

    /// Puts the card two days before `window`'s last day at the rail's leading edge. `nearest`
    /// settles for the closest card when the rail holds no card for that day (a pan past the
    /// rail's last day leaves it at its end); without it the rail moves only on an exact day,
    /// so a state whose rail and window were not drawn to line up opens as drawn.
    private func alignRail(to window: ClosedRange<Date>, nearest: Bool = false) {
        guard let index = railLead(for: window, nearest: nearest), index != railDay else { return }
        railDay = index
    }

    /// The card that leads the rail for `window`: two days before its last day.
    private func railLead(for window: ClosedRange<Date>, nearest: Bool) -> Int? {
        guard let lead = Self.utcCalendar.date(byAdding: .day, value: -Self.railWindowLead, to: window.upperBound) else { return nil }
        let dates = state.dayDates.map(Self.chartDate)
        var index = dates.firstIndex { $0 == lead }
        if index == nil, nearest, !dates.isEmpty {
            index = dates.lastIndex { ($0 ?? .distantFuture) <= lead } ?? 0
        }
        return index
    }

    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private var sessionTickLabels: [(value: String, unit: String)] {
        state.sessionTickValues.indices.map { index in
            (value: state.sessionTickValues[index], unit: state.sessionTickUnits[safe: index] ?? "")
        }
    }

    /// yyyy-MM-dd in UTC — the same reading C-026's build gives its dates (its calendar is UTC),
    /// so a day never shifts across a timezone. Data plumbing, not a side effect.
    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func chartDate(_ text: String) -> Date? {
        chartDateFormatter.date(from: text)
    }

    private static func optionalText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private static func dateState(_ raw: String?) -> DateBlock.State {
        raw == "today" ? .today : .default
    }

    private static func detailsState(_ raw: String?) -> ValuePair.State {
        switch raw {
        case "nothing": return .nothing
        case "muted": return .muted
        case "lessonDay": return .lessonDay
        case "highlighted": return .highlighted
        case "single": return .single
        case "singleMuted": return .singleMuted
        default: return .default
        }
    }

    private static func bandColor(_ raw: String?) -> GroupFollowCard.BandColor {
        switch raw {
        case "yellow": return .yellow
        case "red": return .red
        default: return .green
        }
    }

    /// D11: a component placed more than once gets " 2", " 3"… on the later instances.
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension HomeDashboardScreen.State {

    /// §3 `populated` — every value traces to §2/§4, a §4 contract's sample, or the text on
    /// the frozen frame `default` (node 3622:5487).
    static let populated = Self(
        metricCount: "5",
        kpiTitles: ["Completed lessons", "Total time in lessons", "Total video time"],
        kpiValues: ["158", "72.4hrs", "13.8hrs"],
        kpiTrendDirections: ["up", "up", "down"],
        kpiTrendPolarities: ["positive", "positive", "negative"],
        kpiTrendLabels: ["3%", "32.8%", "2.8%"],
        kpiAverageLabels: ["130", "58", "8.9"],
        kpiSeries: [
            [0, 0, 0, 0, 0, 0, 0, 10, 5.5, 0, 0, 0, 0.5, 4.5, 3.2, 1.2, 0, 0, 0, 0, 0, 0, 1.5, 0],
            [0, 0, 0, 0, 0, 0, 0, 10, 5.5, 0, 0, 0, 0.5, 4.5, 3.2, 1.2, 0, 0, 0, 0, 0, 0, 1.5, 0],
            [0, 0, 0, 0, 0, 0, 0, 10, 5.5, 0, 0, 0, 0.5, 4.5, 3.2, 1.2, 0, 0, 0, 0, 0, 0, 1.5, 0]
        ],
        dayMonths: ["JUL", "JUL", "JUL", "JUL"],
        dayWeekdays: ["MON", "TUE", "WED", ""],
        dayNumbers: ["24", "25", "26", "27"],
        dayDateStates: ["default", "default", "default", "today"],
        daySeries: [
            [0, 2, 5, 3, 0, 4, 6, 2, 0, 1, 3, 0],
            [0, 2, 5, 3, 0, 4, 6, 2, 0, 1, 3, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 20, 0, 0, 0, 12, 6, 18, 6, 0, 0, 5, 14, 24, 14, 6, 0, 0, 0, 0, 12, 6, 0]
        ],
        dayLine1s: ["27 mins", "3.2 hrs", "0 mins", "27 mins"],
        dayLine2s: ["8 lessons", "17 lessons", "0 complete", "1 lessons"],
        dayDetailsStates: ["default", "default", "nothing", "default"],
        dayDates: ["2026-07-24", "2026-07-25", "2026-07-26", "2026-07-27"],
        chartDates: [
            "2026-07-03", "2026-07-04", "2026-07-05", "2026-07-06", "2026-07-07", "2026-07-08",
            "2026-07-09", "2026-07-10", "2026-07-11", "2026-07-12", "2026-07-13", "2026-07-14",
            "2026-07-15", "2026-07-16", "2026-07-17", "2026-07-18", "2026-07-19", "2026-07-20",
            "2026-07-21", "2026-07-22", "2026-07-23", "2026-07-24", "2026-07-25", "2026-07-26",
            "2026-07-27", "2026-07-28", "2026-07-29", "2026-07-30", "2026-07-31"
        ],
        chartScheduled: [
            14, 12, 11, 13, 18, 22, 17, 14, 12, 24, 33, 29, 25, 28, 22, 21, 24, 26, 42, 6, 4, 3, 5,
            17, 25, 26, 28, 25, 22
        ],
        chartCompleted: [
            6, 5, 0, 5, 8, 9, 7, 6, 0, 10, 20, 12, 11, 13, 10, 9, 11, 12, 14, 3, 2, 1, 2, 7, 11, 12,
            18, 11, 9
        ],
        chartWindowStart: "2026-07-03",
        chartWindowEnd: "2026-07-31",
        chartToday: "2026-07-26",
        sessionRange: "All time",
        hourValues: [
            0, 0, 0, 0, 0.8, 0, 0.18, 0.42, 0.78, 0.95, 0.88, 0.14, 0.12, 0.1, 0, 0, 0, 0.85, 0.92,
            0.45, 0.4, 0, 0, 0
        ],
        centerValue: "32",
        centerUnit: "min",
        centerCaption: "Average session",
        bins: [
            61, 54, 48, 46, 44, 29, 5, 3, 4, 3, 6, 8, 14, 10, 5, 3, 3, 3, 3, 5, 15, 35, 28, 9, 5, 3,
            3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 9, 34, 68, 81, 90, 97, 100, 95, 91, 81, 74, 70, 67, 66,
            66, 56, 63, 66, 68, 70, 73, 79, 77, 72, 62, 49, 31, 11, 7, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
            5, 12, 27, 34, 43, 21, 16, 36, 37, 27, 12, 3
        ],
        sessionTickValues: ["12", "6", "12", "6"],
        sessionTickUnits: ["AM", "AM", "PM", "PM"],
        activeCount: "15",
        engagementPercent: 29,
        engagementLabel: "Members current",
        engagementCount: 52,
        engagementProgress: 0.21,
        engagementSubtitle: "178 total members enrolled across 15 groups",
        engagementColor: "green",
        followedCount: "3",
        programTitles: ["Daily inspiration", "Romans in 30 days"],
        programAuthors: ["Scott Stickane", "Luke Keith"],
        programCreatedLabels: ["Created Apr 13, 2026", "Created July 8, 2026"],
        groupProgramIndices: [0, 0, 0, 1, 1],
        groupTitles: [
            "Young professionals", "Grandparents and their kids", "The kids",
            "Grandparents and their kids", "Young professionals"
        ],
        groupPhotoURLs: [
            "https://pub-8fbdd7669af54158b1759ab47dcef688.r2.dev/groups/group-162b0930-6a71-4fa0-bed7-f564af2f097e-1768356813624.jpeg",
            "https://pub-8fbdd7669af54158b1759ab47dcef688.r2.dev/groups/group-162b0930-6a71-4fa0-bed7-f564af2f097e-1768356813624.jpeg",
            "https://pub-8fbdd7669af54158b1759ab47dcef688.r2.dev/groups/group-162b0930-6a71-4fa0-bed7-f564af2f097e-1768356813624.jpeg",
            "https://pub-8fbdd7669af54158b1759ab47dcef688.r2.dev/groups/group-162b0930-6a71-4fa0-bed7-f564af2f097e-1768356813624.jpeg",
            "https://pub-8fbdd7669af54158b1759ab47dcef688.r2.dev/groups/group-162b0930-6a71-4fa0-bed7-f564af2f097e-1768356813624.jpeg"
        ],
        groupMembers: ["9", "15", "2", "15", "9"],
        groupPercents: ["55%", "21%", "13%", "89%", "12%"],
        groupColors: ["green", "yellow", "red", "green", "red"],
        groupShowLinks: [true, true, true, true, true]
    )

    /// §3 `empty` — "section renders with zeroed/dimmed content"; each §4 part in its own
    /// zero form (C-023 `empty` / C-071 `nothing`, C-026 empty window, C-029 and C-030 empty
    /// period, C-031 at 0), and Following as "0 enrollments" + plus with no program blocks.
    static let empty = Self(
        metricCount: "5",
        kpiTitles: ["Completed lessons", "Total time in lessons", "Total video time"],
        kpiValues: ["0", "0", "0"],
        kpiTrendDirections: ["neutral", "neutral", "neutral"],
        kpiTrendPolarities: ["neutral", "neutral", "neutral"],
        kpiTrendLabels: ["0%", "0%", "0%"],
        kpiAverageLabels: ["", "", ""],
        kpiSeries: [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        dayMonths: ["JUL", "JUL", "JUL", "JUL"],
        dayWeekdays: ["MON", "TUE", "WED", ""],
        dayNumbers: ["24", "25", "26", "27"],
        dayDateStates: ["default", "default", "default", "today"],
        daySeries: [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        dayLine1s: ["0 mins", "0 mins", "0 mins", "0 mins"],
        dayLine2s: ["0 complete", "0 complete", "0 complete", "0 complete"],
        dayDetailsStates: ["nothing", "nothing", "nothing", "nothing"],
        chartDates: [],
        chartScheduled: [],
        chartCompleted: [],
        chartWindowStart: "2026-07-03",
        chartWindowEnd: "2026-07-31",
        chartToday: "2026-07-26",
        sessionRange: "All time",
        hourValues: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ],
        centerValue: "0",
        centerUnit: "min",
        centerCaption: "Average session",
        bins: Array(repeating: 0, count: 88),
        sessionTickValues: ["12", "6", "12", "6"],
        sessionTickUnits: ["AM", "AM", "PM", "PM"],
        activeCount: "0",
        engagementPercent: 0,
        engagementLabel: "Members current",
        engagementCount: 0,
        engagementProgress: 0,
        engagementSubtitle: "0 total members enrolled across 0 groups",
        engagementColor: "green",
        followedCount: "0",
        programTitles: [],
        programAuthors: [],
        programCreatedLabels: [],
        groupProgramIndices: [],
        groupTitles: [],
        groupPhotoURLs: [],
        groupMembers: [],
        groupPercents: [],
        groupColors: [],
        groupShowLinks: []
    )
}

#Preview("populated") {
    HomeDashboardScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    HomeDashboardScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

/// dashboard-chart-intros D4: reports a section crossing the 50 % line of the page scroll.
private struct IntroReveal: ViewModifier {
    let enabled: Bool
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onScrollVisibilityChange(threshold: 0.5) { visible in
            if enabled { onChange(visible) }
        }
    }
}
