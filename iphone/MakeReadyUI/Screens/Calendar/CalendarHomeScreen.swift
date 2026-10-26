//
//  CalendarHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen calendar-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: API-GAP GET /api/calendar/events?start&end ·
//  API-GAP GET /api/calendar/search?q&limit&cursor
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Calendar Home — the root-level Calendar tab, modelled on Apple Calendar's Month view: a
/// continuous month grid, a tapped date opening one day under a week strip, day/week paging,
/// Today, and event search (§1). Three modes — `month`, `day(date)`, `search` (§3) — over the
/// app-level C-084 TabBar (§2.1). No C-040 PageHeader: a root tab page.
struct CalendarHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. The events are the
    /// fixture source's answer for the rendered state (§5 fixture set F), as parallel arrays —
    /// one entry per `CalendarEvent` — because the preview's props are JSON; the screen does
    /// §5's mapping to component props itself.
    struct State {
        /// §3 mode: `month`, `day` or `search`.
        var mode: String
        /// §3: "`search` remembers its origin mode" — `month` or `day`.
        var origin: String
        /// The injected `now`, `yyyy-MM-dd'T'HH:mm` local (§3: 2026-10-20 22:42).
        var now: String
        /// `month`: the month whose section top sits under the header, `yyyy-MM`.
        var topMonth: String
        /// `day`: the selected date, `yyyy-MM-dd`.
        var selectedDate: String
        /// `search`: the C-034 query.
        var query: String
        /// `search`: C-034 `focused`.
        var focused: Bool
        /// §3 undesigned `loading`: first load, no cache.
        var loading: Bool
        /// §3 undesigned `search-fetching`.
        var searchFetching: Bool
        /// §3 undesigned `search-error`.
        var searchFailed: Bool
        // ── §5 CalendarEvent, one entry per event ──
        /// `localDate`, `yyyy-MM-dd`.
        var eventDates: [String]
        var eventTitles: [String]
        /// `type`, lowercased (= C-112 EventType raw values).
        var eventTypes: [String]
        /// `startTime` `HH:mm`; "" = null = all-day (§5 contract: `isAllDay` when start is null).
        var eventStarts: [String]
        /// `endTime` `HH:mm`; "" for all-day.
        var eventEnds: [String]
        /// `locationName`; "" = null.
        var eventLocations: [String]
        /// `externalUrl`; "" = null.
        var eventURLs: [String]
        /// `groupName`.
        var eventGroups: [String]
        /// `isRecurring`.
        var eventRecurring: [Bool]
    }

    let state: State
    // §3 actions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onOpenEvent: (String) -> Void = { _ in }        // §3 C-117 / C-118 tap (D7)
    var onSearch: (String) -> Void = { _ in }           // §3 query typing → the search source
    var onSelectTab: (TabBar.Tab) -> Void = { _ in }    // §3 C-084 other tabs (shell-tabs)
    var onAdd: () -> Void = {}                          // §6 C-084 Add (shell-tabs)

    // R-31 ephemeral UI, seeded from `State`: the mode machine (§3.2), the day shown, the
    // timeline's top minute, the month scroll and the query as typed.
    @SwiftUI.State private var mode: Mode
    @SwiftUI.State private var origin: Mode
    @SwiftUI.State private var selectedDate: Date
    @SwiftUI.State private var topMinute: Int
    @SwiftUI.State private var anchorMonth: Date
    @SwiftUI.State private var visibleMonth: Date
    @SwiftUI.State private var monthOffset: CGFloat = 0
    @SwiftUI.State private var monthPosition = ScrollPosition()
    @SwiftUI.State private var listPosition = ScrollPosition()
    @SwiftUI.State private var query: String
    @SwiftUI.State private var focused: Bool
    @SwiftUI.State private var allDayExpanded = false
    @SwiftUI.State private var pageDrag: CGFloat = 0
    @SwiftUI.State private var stripDrag: CGFloat = 0
    @SwiftUI.State private var pageWidth: CGFloat = 0

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        state: State,
        onOpenEvent: @escaping (String) -> Void = { _ in },
        onSearch: @escaping (String) -> Void = { _ in },
        onSelectTab: @escaping (TabBar.Tab) -> Void = { _ in },
        onAdd: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onOpenEvent = onOpenEvent
        self.onSearch = onSearch
        self.onSelectTab = onSelectTab
        self.onAdd = onAdd
        let now = Self.parse(state.now, Self.nowFormatter) ?? Date(timeIntervalSince1970: 1_700_000_000)
        let selected = Self.parse(state.selectedDate, Self.dayFormatter) ?? Self.calendar.startOfDay(for: now)
        let top = Self.parse(state.topMonth, Self.monthKeyFormatter) ?? Self.monthStart(of: now)
        let events = Self.events(of: state)
        _mode = SwiftUI.State(initialValue: Mode(rawValue: state.mode) ?? .month)
        _origin = SwiftUI.State(initialValue: Mode(rawValue: state.origin) ?? .month)
        _selectedDate = SwiftUI.State(initialValue: selected)
        _topMinute = SwiftUI.State(initialValue: Self.defaultTopMinute(for: selected, events: events, now: now))
        _anchorMonth = SwiftUI.State(initialValue: top)
        _visibleMonth = SwiftUI.State(initialValue: top)
        _query = SwiftUI.State(initialValue: state.query)
        _focused = SwiftUI.State(initialValue: state.focused)
    }

    // MARK: - Model

    private enum Mode: String { case month, day, search }

    /// §5 `CalendarEvent`, as the screen reads it.
    private struct Event {
        let id: String
        let day: Date
        let title: String
        let type: EventIndicator.EventType
        /// Minute of day; nil = all-day.
        let start: Int?
        let end: Int?
        let location: String?
        let url: String?
        let group: String
        let recurring: Bool
        var allDay: Bool { start == nil }
        /// D14: "An end earlier than its start splits at midnight."
        var overnight: Bool { if let start, let end { end < start } else { false } }
    }

    /// One C-121 row: an event on one day (an overnight event gives two, D14).
    private struct ResultRow {
        let event: Event
        let day: Date
        let timing: CalendarEventRow.Timing
    }

    private struct ResultGroup {
        let day: Date
        let rows: [ResultRow]
    }

    // MARK: - §2 geometry the screen owns

    private enum Geometry {
        // GAP — calendar-home §2.1: control row "y 62–106" on the 440×956 canvas, less the
        // device's 59 pt top inset the harness draws (02-design's "safe-area top + 6" disagrees
        // with its own 62; the measured y wins).
        static let controlTop: CGFloat = 3
        // GAP — calendar-home §2.1: control row "44 tall", no sizing token.
        static let controlHeight: CGFloat = 44
        static var controlBottom: CGFloat { controlTop + controlHeight }
        // GAP — calendar-home §2.2: title band from the control row (y 106) to the weekday
        // header (y 168), title baseline y 155 → 13 pt above the band bottom.
        static let titleBand: CGFloat = 62
        static let titleBaselineInset: CGFloat = 13
        // GAP — calendar-home §2.2: weekday header "y 168–187" (18 letters + hairline).
        static let monthHeader: CGFloat = 19
        // GAP — calendar-home §2.2/§2.3: body "to y 872" = TabBar top, less the 59 pt inset.
        static let region: CGFloat = 813
        // GAP — calendar-home §2.2: month body "y 187 to y 872".
        static let monthBody: CGFloat = 685
        // GAP — calendar-home §2.3: pinned day header, control row bottom (y 106) → timeline
        // top (y 219): letters centred y 124, strip y 132–176, hairlines y 183 / 218, subtitle
        // centred y 201.
        static let dayHeader: CGFloat = 113
        static let dayLettersTop: CGFloat = 9
        static let dayStripTop: CGFloat = 26
        static let dayHairline1: CGFloat = 77
        static let dayHairline2: CGFloat = 112
        // GAP — calendar-home §2.3: DayTimeline "viewport y 219–872 (653 pt)".
        static let dayViewport: CGFloat = 653
        // GAP — calendar-home §2.4: "a `color-layout-background` band … from y 0 to y 117".
        static let searchBand: CGFloat = 58
        // GAP — calendar-home §2.4: results list "y 118–872".
        static let listTop: CGFloat = 59
        static let listHeight: CGFloat = 754
        // GAP — calendar-home §2.4: C-076 "24 pt below the field"; C-122 "120 pt below".
        static let spinnerGap: CGFloat = 24
        static let emptyStateGap: CGFloat = 120
        // GAP — calendar-home §2.4: results "day header band 40 tall".
        static let resultHeader: CGFloat = 40
        // GAP — calendar-home §2.4: C-121 row "52 tall" (its contract's height).
        static let resultRow: CGFloat = 52
        // FLAGGED LITERAL — calendar-home §2.5 FL-4: 31 pt after a group's last row, no token.
        static let groupGap: CGFloat = 31
        // FLAGGED LITERAL — C-115 §2: month section "27 + rows × 69" (the grid's own geometry,
        // repeated here to place a month's section top).
        static let monthLabelBand: CGFloat = 27
        static let weekRow: CGFloat = 69
        // FLAGGED LITERAL — C-120 §2: "minute m at y = 8 + m × 50/60", canvas 1216.
        static let timelinePadding: CGFloat = 8
        static let pointsPerMinute: CGFloat = 50.0 / 60.0
        static let timelineCanvas: CGFloat = 1216
        // GAP — calendar-home §3.2: page commit "past 35 % of the width or at > 300 pt/s".
        static let commitFraction: CGFloat = 0.35
        static let commitVelocity: CGFloat = 300
        // GAP — calendar-home §3.2 / §2.2: range "±24 months from today" (D8).
        static let monthRange = 24
    }

    /// FLAGGED LITERAL — calendar-home §2.5 FL-5: motion values with no token (02-design §7).
    private enum Motion {
        static let curtain = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let page = Animation.easeOut(duration: 0.3)
        static let collapse = Animation.smooth(duration: 0.45)
        static let title = Animation.easeInOut(duration: 0.15)
        static let todayScroll = Animation.easeInOut(duration: 0.35)
        static let searchOpen = Animation.easeOut(duration: 0.25)
        static let searchClose = Animation.easeOut(duration: 0.2)
        static let resultToDay = Animation.easeInOut(duration: 0.25)
        static let crossfade = Animation.easeInOut(duration: 0.2)
    }

    /// FLAGGED LITERAL — calendar-home §2.5 FL-1: large title Bold 32 / 38, no type token.
    private static let titleStyle = DesignTextStyle(weight: .bold, size: 32, lineHeight: 38, tracking: 0)
    /// FLAGGED LITERAL — calendar-home §2.5 FL-2: day subtitle Semibold 15, no type token.
    private static let subtitleStyle = DesignTextStyle(weight: .semibold, size: 15, lineHeight: nil, tracking: 0)
    /// FLAGGED LITERAL — calendar-home §2.5 FL-3: results day header Semibold 13, no type token.
    private static let resultHeaderStyle = DesignTextStyle(weight: .semibold, size: 13, lineHeight: nil, tracking: 0)

    // MARK: - §2 copy

    private static let searchPlaceholder = "Search events"
    private static let todayLabel = "Today"
    private static let noResultsTitle = "No Results"
    private static let noResultsMessage = "Check the spelling or try a new search."
    private static let unavailableTitle = "Search unavailable"
    private static let unavailableMessage = "Check your connection and try again."
    /// §3.2: "Debounce 300 ms, minimum 2 characters."
    private static let minimumQueryLength = 2

    // MARK: - Derived

    private var now: Date { Self.parse(state.now, Self.nowFormatter) ?? Date(timeIntervalSince1970: 1_700_000_000) }
    private var today: Date { Self.calendar.startOfDay(for: now) }
    private var events: [Event] { Self.events(of: state) }

    /// §3.2: "Below 2 the body is the one it came from."
    private var isQuerying: Bool { mode == .search && query.count >= Self.minimumQueryLength }

    /// The fixture source's answer: word-AND over title and location (§5 contract matching).
    private var searchResults: [ResultGroup] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        let matches = events.filter { event in
            let haystack = "\(event.title) \(event.location ?? "")".lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        var rows: [ResultRow] = []
        for event in Self.sorted(matches) {
            if event.overnight {
                // §5: "`continues` on the start day …, `ends` on the next day".
                rows.append(ResultRow(event: event, day: event.day, timing: .continues))
                rows.append(ResultRow(event: event, day: Self.addDays(1, to: event.day), timing: .ends))
            } else {
                rows.append(ResultRow(event: event, day: event.day, timing: event.allDay ? .allDay : .timed))
            }
        }
        let days = rows.map(\.day).reduce(into: [Date]()) { if !$0.contains($1) { $0.append($1) } }.sorted()
        return days.map { day in ResultGroup(day: day, rows: rows.filter { $0.day == day }) }
    }

    private enum Region { case month, day, cleared, results }

    private var bodyKind: Region {
        switch mode {
        case .month: return .month
        case .day: return .day
        case .search:
            if !isQuerying || state.searchFetching { return origin == .day ? .day : .month }
            if state.searchFailed || searchResults.isEmpty { return .cleared }
            return .results
        }
    }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device; the month body, the
        // timeline and the results list scroll inside their own pinned regions (§2.2–§2.4).
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if bodyKind == .month { monthMode.transition(.opacity) }
                if bodyKind == .day { dayMode.transition(.opacity) }
                if bodyKind == .cleared { clearedBody.transition(.opacity) }
                if bodyKind == .results { resultsList.transition(.opacity) }
                if mode == .search && state.searchFetching && isQuerying { fetchingSpinner }
                if mode == .search { searchChrome } else { controlRow }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Geometry.region, alignment: .top)
            .clipped()

            // §2.1: C-084 pinned bottom, Calendar selected; re-tapping Calendar is a no-op here.
            TabBar(selected: .calendar, onSelect: { if $0 != .calendar { onSelectTab($0) } }, onAdd: onAdd)
                .ui2Element("C-084 TabBar")
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
    }

    // MARK: §2.1 Control row

    private var controlRow: some View {
        HStack(spacing: Token.Space.elementGap) {
            if mode == .day {
                // §2.1 day: C-105 back, label = the selected date's full month name.
                Button(label: Self.monthNameFormatter.string(from: selectedDate), leadingGlyph: .chevronLeft,
                       onTap: collapse)
                    .ui2Element("C-105 Button")
                    .transition(.opacity)
            } else if state.loading {
                // §3 undesigned `loading`: C-076 in the left slot until the first range arrives.
                ActivitySpinner()
                    .ui2Element("C-076 ActivitySpinner")
            }
            Spacer(minLength: 0)
            // §2.1 right slot: C-049 "Today" alone, trailing edge at the page margin. No Search
            // control (owner ruling: not needed for now) and no Add control (owner ruling, 2026-10-21).
            LinkButton(label: Self.todayLabel, style: .default, onTap: goToToday)
                .ui2Element("C-049 LinkButton")
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(height: Geometry.controlHeight)
        .padding(.top, Geometry.controlTop)
    }

    // MARK: §2.2 Month mode

    private var monthMode: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Geometry.controlBottom)
            titleBand
            // §2.2: C-114 `hairline: true`; title and header are opaque, the grid scrolls under.
            WeekdayHeader(hairline: true)
                .ui2Element("C-114 WeekdayHeader")
                .frame(height: Geometry.monthHeader, alignment: .top)
            monthScroll
                .frame(height: Geometry.monthBody)
        }
    }

    /// §2.2: the top-most month's full name, Bold 32 / 38 at x 16, baseline 8 pt below the
    /// control row; the year follows in `color-text-secondary` when not the current year (D2).
    private var titleBand: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
            Color.clear
                .frame(height: Geometry.titleBand)
                .alignmentGuide(.lastTextBaseline) { $0.height - Geometry.titleBaselineInset }
            titleText
                .designTextStyle(Self.titleStyle)
                .lineLimit(1)
                .id(visibleMonth)
                .transition(.opacity)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: Geometry.titleBand)
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: Text {
        let name = Text(Self.monthNameFormatter.string(from: visibleMonth)).foregroundStyle(Token.white100)
        guard !Self.calendar.isDate(visibleMonth, equalTo: now, toGranularity: .year) else { return name }
        let year = Text(Self.yearFormatter.string(from: visibleMonth)).foregroundStyle(Token.textSecondary)
        return Text("\(name) \(year)")
    }

    /// §2.2 Month body: "one C-115 per month stacked with no gap … ±24 months from today".
    private var monthScroll: some View {
        let months = monthRange
        let offsets = sectionOffsets(months)
        let total = offsets.last ?? 0
        let anchorOffset = sectionTop(of: anchorMonth, months: months, offsets: offsets)
        let range = max(total - Geometry.monthBody, 0)
        let visible = months.indices.filter {
            offsets[$0 + 1] > anchorOffset && offsets[$0] < anchorOffset + Geometry.monthBody
        }
        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(months.indices, id: \.self) { index in
                    let grid = MonthGrid(
                        month: months[index],
                        today: now,
                        days: state.loading ? [] : monthDays(months[index]),
                        onSelectDate: expand
                    )
                    // Only the sections on screen at rest are annotated: the rest are never in
                    // a capture.
                    if let position = visible.firstIndex(of: index) {
                        grid.ui2Element(position == 0 ? "C-115 MonthGrid" : "C-115 MonthGrid \(position + 1)")
                    } else {
                        grid
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($monthPosition)
        // §3.1: "Scrolled so <month>'s section top sits under the header" — layout, not an effect.
        .defaultScrollAnchor(UnitPoint(x: 0, y: range > 0 ? min(anchorOffset / range, 1) : 0), for: .initialOffset)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
            monthOffset = y
            // §3.2: "the section containing the point 1 pt below the header's bottom edge".
            let index = offsets.lastIndex { $0 <= y + 1 }.map { min($0, months.count - 1) } ?? 0
            let month = months[index]
            if month != visibleMonth { withAnimation(motion(Motion.title)) { visibleMonth = month } }
        }
    }

    private var monthRange: [Date] {
        let base = Self.monthStart(of: now)
        return (-Geometry.monthRange...Geometry.monthRange).compactMap {
            Self.calendar.date(byAdding: .month, value: $0, to: base)
        }
    }

    /// Cumulative section tops; the last entry is the content height.
    private func sectionOffsets(_ months: [Date]) -> [CGFloat] {
        months.reduce(into: [CGFloat(0)]) { $0.append(($0.last ?? 0) + Self.sectionHeight(of: $1)) }
    }

    private func sectionTop(of month: Date, months: [Date], offsets: [CGFloat]) -> CGFloat {
        guard let index = months.firstIndex(where: { Self.calendar.isDate($0, equalTo: month, toGranularity: .month) })
        else { return 0 }
        return offsets[index]
    }

    /// §5: "C-115 `days`: per day, all-day first, then `startTime`, then `title`."
    private func monthDays(_ month: Date) -> [MonthGrid.DayEvents] {
        let inMonth = events.filter { Self.calendar.isDate($0.day, equalTo: month, toGranularity: .month) }
        let byDay = Dictionary(grouping: inMonth) { Self.calendar.component(.day, from: $0.day) }
        return byDay.keys.sorted().map { day in
            MonthGrid.DayEvents(day: day, eventTypes: Self.sorted(byDay[day] ?? []).map(\.type))
        }
    }

    // MARK: §2.3 Day mode

    private var dayMode: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Geometry.controlBottom)
            dayHeader
            dayTimeline
                .frame(height: Geometry.dayViewport)
        }
    }

    private var dayHeader: some View {
        ZStack(alignment: .top) {
            // §2.3: C-114 `hairline: false`, letters centred y 124.
            WeekdayHeader(hairline: false)
                .ui2Element("C-114 WeekdayHeader")
                .padding(.top, Geometry.dayLettersTop)
            // §2.3: C-116 numerals centred y 154, row y 132–176; the strip tracks a drag (§3.2).
            WeekStrip(
                week: selectedDate, selected: selectedDate, today: now,
                onSelectDate: { page(to: $0, keepOffset: true) },
                onNextWeek: { pageWeek(by: 1) },
                onPreviousWeek: { pageWeek(by: -1) }
            )
            .offset(x: stripDrag)
            .ui2Element("C-116 WeekStrip")
            .padding(.top, Geometry.dayStripTop)
            .horizontalPan(onChanged: { stripDrag = $0.translation }, onEnded: stripEnded)
            hairline
                .padding(.top, Geometry.dayHairline1)
            // §2.3: subtitle "EEEE – MMM d, yyyy", centred y 201, between the hairlines.
            Text(Self.subtitleFormatter.string(from: selectedDate))
                .designTextStyle(Self.subtitleStyle)
                .foregroundStyle(Token.white100)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: Geometry.dayHairline2 - Geometry.dayHairline1 - 1)
                .offset(x: pageDrag)
                .padding(.top, Geometry.dayHairline1 + 1)
            hairline
                .padding(.top, Geometry.dayHairline2)
        }
        .frame(height: Geometry.dayHeader, alignment: .top)
        .clipped()
    }

    /// §2.3: one C-120 page for the selected day, dragged horizontally to page (§3.2).
    private var dayTimeline: some View {
        let dayEvents = timedEvents(on: selectedDate)
        return DayTimeline(
            timedEvents: dayEvents,
            allDayEvents: allDayEvents(on: selectedDate),
            allDayExpanded: allDayExpanded,
            onAllDayExpandedChange: { allDayExpanded = $0 },
            nowMinute: Self.calendar.isDate(selectedDate, inSameDayAs: now) ? Self.minute(of: now) : nil,
            topMinute: topMinute,
            onTopMinuteChange: { topMinute = $0 },
            onOpenEvent: onOpenEvent,
            onNextDay: { page(by: 1) },
            onPreviousDay: { page(by: -1) }
        )
        .ui2Element("C-120 DayTimeline")
        .offset(x: pageDrag)
        .horizontalPan(onChanged: { pageDrag = $0.translation }, onEnded: pageEnded)
    }

    private func timedEvents(on day: Date) -> [DayTimeline.TimedEvent] {
        let previous = Self.addDays(-1, to: day)
        return events.compactMap { event -> DayTimeline.TimedEvent? in
            guard let start = event.start, let end = event.end else { return nil }
            let (detailKind, detail) = Self.detail(of: event)
            let range = "\(Self.timeText(start)) to \(Self.timeText(end))"
            // D14: an overnight event draws on its own day to 12 AM and on the next from 12 AM.
            let span: (Int, Int)?
            if Self.calendar.isDate(event.day, inSameDayAs: day) {
                span = (start, event.overnight ? 1440 : end)
            } else if event.overnight && Self.calendar.isDate(event.day, inSameDayAs: previous) {
                span = (0, end)
            } else {
                span = nil
            }
            guard let span else { return nil }
            return DayTimeline.TimedEvent(
                id: event.id, title: event.title, detail: detail, detailKind: detailKind,
                eventType: event.type, recurring: event.recurring,
                startMinute: span.0, endMinute: span.1, timeRangeText: range
            )
        }
    }

    private func allDayEvents(on day: Date) -> [DayTimeline.AllDayEvent] {
        Self.sorted(events.filter { $0.allDay && Self.calendar.isDate($0.day, inSameDayAs: day) })
            .map { DayTimeline.AllDayEvent(id: $0.id, title: $0.title, eventType: $0.type) }
    }

    // MARK: §2.4 Search mode

    private var searchChrome: some View {
        VStack(spacing: 0) {
            // §2.4: "C-034 SearchField alone … x 16–424 … There is no second button to the
            // right of it."
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                focused: focused,
                onChange: { query = $0; onSearch($0) },
                onClear: clearOrCloseSearch,
                showsClearWhenEmpty: true
            )
            .ui2Element("C-034 SearchField")
            .padding(.horizontal, Token.Space.pageMargin)
            .frame(height: Geometry.controlHeight)
            .padding(.top, Geometry.controlTop)
            Spacer(minLength: 0)
        }
        .frame(height: Geometry.searchBand, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Token.layoutBackground)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    /// §2.4: "fetching → unchanged body + C-076 centred horizontally, 24 pt below the field".
    private var fetchingSpinner: some View {
        ActivitySpinner()
            .ui2Element("C-076 ActivitySpinner")
            .padding(.top, Geometry.controlBottom + Geometry.spinnerGap)
    }

    /// §2.4: "0 results → body cleared; C-122 centred with its top 120 pt below the field".
    private var clearedBody: some View {
        VStack(spacing: 0) {
            CalendarEmptyState(
                title: state.searchFailed ? Self.unavailableTitle : Self.noResultsTitle,
                message: state.searchFailed ? Self.unavailableMessage : Self.noResultsMessage
            )
            .ui2Element("C-122 CalendarEmptyState")
            .padding(.top, Geometry.controlBottom + Geometry.emptyStateGap)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.layoutBackground)
    }

    /// §2.4 Results list: grouped by day ascending, scrolled so the first event on or after
    /// today is at the top (§3 state 10).
    private var resultsList: some View {
        let groups = searchResults
        let offsets = groups.reduce(into: [CGFloat(0)]) { $0.append(($0.last ?? 0) + Self.groupHeight($1)) }
        let content = offsets.last ?? 0
        let target = groups.firstIndex { $0.day >= today }.map { offsets[$0] } ?? 0
        // GAP — calendar-home §3 state 10: the first event on or after today "is at the list's
        // top"; the tail is padded so the list can scroll that far.
        let tail = max(Geometry.listHeight - (content - target), 0)
        let range = max(content + tail - Geometry.listHeight, 0)
        // Row numbering for the part highlights, running across groups.
        let firstRow = groups.reduce(into: [0]) { $0.append(($0.last ?? 0) + $1.rows.count) }
        return VStack(spacing: 0) {
            Color.clear.frame(height: Geometry.listTop)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(groups.indices, id: \.self) { groupIndex in
                        let group = groups[groupIndex]
                        resultHeader(group.day)
                        ForEach(group.rows.indices, id: \.self) { rowIndex in
                            let row = group.rows[rowIndex]
                            let number = firstRow[groupIndex] + rowIndex + 1
                            resultRow(row)
                                .ui2Element(number == 1 ? "C-121 CalendarEventRow" : "C-121 CalendarEventRow \(number)")
                        }
                        Color.clear.frame(height: Geometry.groupGap)
                    }
                    Color.clear.frame(height: tail)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollPosition($listPosition)
            .defaultScrollAnchor(UnitPoint(x: 0, y: range > 0 ? min(target / range, 1) : 0), for: .initialOffset)
            .frame(height: Geometry.listHeight)
        }
    }

    /// §2.4: "a day header band 40 tall … Semibold 13 `color-white-50` at x 16 … a 1 px
    /// `color-white-10` hairline across its full width at the bottom".
    private func resultHeader(_ day: Date) -> some View {
        VStack(spacing: 0) {
            Text(Self.subtitleFormatter.string(from: day))
                .designTextStyle(Self.resultHeaderStyle)
                .foregroundStyle(Token.white50)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, Token.Space.pageMargin)
            hairline
        }
        .frame(height: Geometry.resultHeader)
        .accessibilityAddTraits(.isHeader)
    }

    private func resultRow(_ row: ResultRow) -> some View {
        let (detailKind, detail) = Self.detail(of: row.event)
        return CalendarEventRow(
            title: row.event.title,
            detail: detail,
            detailKind: detailKind,
            eventType: row.event.type,
            timing: row.timing,
            startTime: row.event.start.map(Self.timeText),
            endTime: row.event.end.map(Self.timeText),
            past: row.day < today,
            onTap: { openResult(row) }
        )
    }

    /// §2.3 / §2.4: the screen's 1 px `color-white-10` rules (OQ-calendar-home-003).
    private var hairline: some View {
        Token.white10
            .frame(maxWidth: .infinity)
            .frame(height: 1 / displayScale)
    }

    // MARK: - §3.2 Interactions

    private func motion(_ animation: Animation) -> Animation {
        // §3.2: "With Reduce Motion on, every spring or slide becomes a 0.2 s crossfade".
        reduceMotion ? Motion.crossfade : animation
    }

    /// §3.2 Tap a date: the curtain expand, one spring.
    private func expand(_ date: Date) {
        withAnimation(motion(Motion.curtain)) {
            selectedDate = date
            topMinute = Self.defaultTopMinute(for: date, events: events, now: now)
            allDayExpanded = false
            mode = .day
        }
    }

    /// §3.2 C-105 back: the collapse, positioned at the selected date's month section top.
    private func collapse() {
        withAnimation(motion(Motion.collapse)) {
            anchorMonth = Self.monthStart(of: selectedDate)
            visibleMonth = anchorMonth
            mode = .month
        }
    }

    /// §3.2 day paging: content drag, strip tap. Within a week the `topMinute` is kept.
    private func page(to date: Date, keepOffset: Bool) {
        let sameWeek = Self.calendar.isDate(date, equalTo: selectedDate, toGranularity: .weekOfYear)
        withAnimation(motion(Motion.page)) {
            selectedDate = date
            pageDrag = 0
            if !(keepOffset && sameWeek) { topMinute = Self.defaultTopMinute(for: date, events: events, now: now) }
        }
    }

    private func page(by days: Int) { page(to: Self.addDays(days, to: selectedDate), keepOffset: true) }

    /// §3.2 strip drag: "the selection moves to the same weekday … opens at the default anchor".
    private func pageWeek(by weeks: Int) {
        withAnimation(motion(Motion.page)) {
            stripDrag = 0
            selectedDate = Self.addDays(7 * weeks, to: selectedDate)
            topMinute = Self.defaultTopMinute(for: selectedDate, events: events, now: now)
        }
    }

    // Both strips are sideways only, so a vertical drag on them scrolls the page
    // (HorizontalScrolling.swift).
    private func pageEnded(_ value: HorizontalPanValue) {
        switch commit(value) {
        case 1: page(by: 1)        // §3.2: "Left = next day."
        case -1: page(by: -1)
        default: withAnimation(motion(Motion.page)) { pageDrag = 0 }
        }
    }

    private func stripEnded(_ value: HorizontalPanValue) {
        switch commit(value) {
        case 1: pageWeek(by: 1)
        case -1: pageWeek(by: -1)
        default: withAnimation(motion(Motion.page)) { stripDrag = 0 }
        }
    }

    /// §3.2: "commits past 35 % of the width or at > 300 pt/s" — 1 next, −1 previous, 0 none.
    private func commit(_ value: HorizontalPanValue) -> Int {
        let width = pageWidth
        let dx = value.translation
        let velocity = value.velocity
        if dx < -width * Geometry.commitFraction || velocity < -Geometry.commitVelocity { return 1 }
        if dx > width * Geometry.commitFraction || velocity > Geometry.commitVelocity { return -1 }
        return 0
    }

    /// §3.2 Today: month → scroll (animated within ±1 screen height, else a jump); day → page.
    private func goToToday() {
        switch mode {
        case .month:
            let months = monthRange
            let target = sectionTop(of: today, months: months, offsets: sectionOffsets(months))
            if abs(target - monthOffset) <= Geometry.monthBody {
                withAnimation(motion(Motion.todayScroll)) { monthPosition.scrollTo(y: target) }
            } else {
                monthPosition.scrollTo(y: target)
            }
        case .day:
            if Self.calendar.isDate(today, equalTo: selectedDate, toGranularity: .weekOfYear) {
                page(to: today, keepOffset: true)
            } else {
                withAnimation(Motion.crossfade) {
                    selectedDate = today
                    topMinute = Self.defaultTopMinute(for: today, events: events, now: now)
                }
            }
        case .search:
            // §3.2: "Scrolls the list back to the first event on or after today."
            let groups = searchResults
            let target = groups.prefix { $0.day < today }.reduce(CGFloat(0)) { $0 + Self.groupHeight($1) }
            withAnimation(motion(Motion.todayScroll)) { listPosition.scrollTo(y: target) }
        }
    }

    /// §3 parked: no control calls this while search mode has no trigger (owner ruling).
    private func openSearch() {
        withAnimation(motion(Motion.searchOpen)) {
            origin = mode
            mode = .search
            focused = true
        }
    }

    /// §3.2 C-034 clear x: query non-empty → "Clears the text; the field stays focused";
    /// query empty → "Dismisses search".
    private func clearOrCloseSearch() {
        if query.isEmpty {
            closeSearch()
        } else {
            query = ""
            onSearch("")
        }
    }

    /// §3.2 C-034 clear x, query empty: "The originating body shows exactly as left, and the
    /// control row … restores".
    private func closeSearch() {
        withAnimation(motion(Motion.searchClose)) {
            query = ""
            focused = false
            mode = origin
        }
    }

    /// §3.2 C-121 row tap: "enter `day(row date)` with a 0.25 s crossfade … The event's start
    /// sits at 25 % of the viewport."
    private func openResult(_ row: ResultRow) {
        withAnimation(motion(Motion.resultToDay)) {
            query = ""
            focused = false
            selectedDate = row.day
            topMinute = row.event.start.map { Self.topMinute(placing: $0, at: 0.25) }
                ?? Self.defaultTopMinute(for: row.day, events: events, now: now)
            mode = .day
        }
    }

    // MARK: - §3.3 Day scroll anchor (D10)

    private static func defaultTopMinute(for day: Date, events: [Event], now: Date) -> Int {
        if calendar.isDate(day, inSameDayAs: now) {
            // "Today → the current time at 70 % of the 653 pt viewport, clamped".
            return topMinute(placing: minute(of: now), at: 0.7)
        }
        // "Any other day → anchor minute min(300, earliest timed start − 60), clamped ≥ 0 …
        // topMinute = anchor − 49" (OQ-calendar-home-001).
        let starts = events.filter { calendar.isDate($0.day, inSameDayAs: day) }.compactMap(\.start)
        let anchor = max(min(300, (starts.min() ?? 360) - 60), 0)
        return max(anchor - 49, 0)
    }

    /// The `topMinute` that puts `minute` at `fraction` of the viewport, clamped to C-120's range.
    private static func topMinute(placing minute: Int, at fraction: CGFloat) -> Int {
        let y = Geometry.timelinePadding + CGFloat(minute) * Geometry.pointsPerMinute
        let range = Geometry.timelineCanvas - Geometry.dayViewport
        let offset = min(max(y - fraction * Geometry.dayViewport, 0), range)
        return Int((offset / Geometry.pointsPerMinute).rounded())
    }

    // MARK: - §5 mapping

    private static func events(of state: State) -> [Event] {
        state.eventDates.indices.compactMap { index in
            guard let day = parse(state.eventDates[index], dayFormatter) else { return nil }
            func value(_ values: [String]) -> String? {
                index < values.count && !values[index].isEmpty ? values[index] : nil
            }
            return Event(
                id: "event-\(index + 1)",
                day: day,
                title: value(state.eventTitles) ?? "",
                type: value(state.eventTypes).flatMap(EventIndicator.EventType.init(rawValue:)) ?? .other,
                start: value(state.eventStarts).flatMap(minute(of:)),
                end: value(state.eventEnds).flatMap(minute(of:)),
                location: value(state.eventLocations),
                url: value(state.eventURLs),
                group: value(state.eventGroups) ?? "",
                recurring: index < state.eventRecurring.count && state.eventRecurring[index]
            )
        }
    }

    /// "all-day first, then `startTime`, then `title`".
    private static func sorted(_ events: [Event]) -> [Event] {
        events.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            if $0.allDay != $1.allDay { return $0.allDay }
            if ($0.start ?? 0) != ($1.start ?? 0) { return ($0.start ?? 0) < ($1.start ?? 0) }
            return $0.title < $1.title
        }
    }

    /// §5 `detailKind` / `detail`: online (URL host, else location) · location · group.
    private static func detail(of event: Event) -> (CalendarEventBlock.DetailKind, String?) {
        if event.url != nil || event.type == .online {
            return (.online, event.url.flatMap { URL(string: $0)?.host } ?? event.location)
        }
        if let location = event.location { return (.location, location) }
        return (.group, event.group)
    }

    private static func groupHeight(_ group: ResultGroup) -> CGFloat {
        Geometry.resultHeader + CGFloat(group.rows.count) * Geometry.resultRow + Geometry.groupGap
    }

    private static func sectionHeight(of month: Date) -> CGFloat {
        let first = monthStart(of: month)
        let column = calendar.component(.weekday, from: first) - 1
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = (column + days + 6) / 7
        return Geometry.monthLabelBand + CGFloat(rows) * Geometry.weekRow
    }

    // MARK: - Dates (D9: Gregorian, Sunday first)

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = format
        return f
    }

    private static let nowFormatter = formatter("yyyy-MM-dd'T'HH:mm")
    private static let dayFormatter = formatter("yyyy-MM-dd")
    private static let monthKeyFormatter = formatter("yyyy-MM")
    private static let monthNameFormatter = formatter("MMMM")
    private static let yearFormatter = formatter("yyyy")
    /// §2.3 / §2.4: "`EEEE – MMM d, yyyy`, en dash".
    private static let subtitleFormatter = formatter("EEEE – MMM d, yyyy")
    /// §5: times "h:mm a".
    private static let clockFormatter = formatter("h:mm a")

    private static func parse(_ text: String, _ formatter: DateFormatter) -> Date? { formatter.date(from: text) }

    private static func monthStart(of date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func minute(of date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    /// `HH:mm` → minute of day.
    private static func minute(of text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : nil
    }

    private static func timeText(_ minute: Int) -> String {
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let date = calendar.date(byAdding: .minute, value: minute % 1440, to: base) ?? base
        return clockFormatter.string(from: date)
    }
}

// MARK: - Sample states (the preview props, written as Swift — §5 fixture set F)

extension CalendarHomeScreen.State {
    /// §3 state "month-current".
    static let monthCurrent = Self(
        mode: "month", origin: "month", now: "2026-10-20T22:42", topMonth: "2026-10",
        selectedDate: "2026-10-20", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-10-01",
            "2026-10-02",
            "2026-10-05",
            "2026-10-05",
            "2026-10-06",
            "2026-10-08",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-12",
            "2026-10-12",
            "2026-10-15",
            "2026-10-19",
            "2026-10-19",
            "2026-10-20",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-26",
            "2026-10-27",
            "2026-10-27",
            "2026-10-27",
            "2026-10-31",
            "2026-11-02",
            "2026-11-03",
            "2026-11-03",
            "2026-11-06",
            "2026-11-06",
            "2026-11-06",
            "2026-11-09",
            "2026-11-09",
            "2026-11-09",
            "2026-11-09",
            "2026-11-13",
            "2026-11-13",
            "2026-11-16",
            "2026-11-20",
            "2026-11-20",
            "2026-11-23",
            "2026-11-27"
        ],
        eventTitles: [
            "Meeting 1",
            "Other 1",
            "Lesson 1",
            "Meeting 2",
            "Online 1",
            "Lesson 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Social 1",
            "Lesson 1",
            "Meeting 2",
            "Daily team sync",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Social 5",
            "Lesson 1",
            "Lesson 1",
            "Social 2",
            "Other 3",
            "Social 1",
            "Meeting 1",
            "Lesson 1",
            "Meeting 2",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Lesson 1",
            "Meeting 1",
            "Online 2",
            "Lesson 1",
            "Social 1"
        ],
        eventTypes: [
            "meeting",
            "other",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "social",
            "lesson",
            "meeting",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "social",
            "lesson",
            "lesson",
            "social",
            "other",
            "social",
            "meeting",
            "lesson",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "social"
        ],
        eventStarts: [
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "09:47",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00"
        ],
        eventEnds: [
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "10:13",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "14:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00"
        ],
        eventLocations: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventURLs: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Leadership Team",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults"
        ],
        eventRecurring: [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    )

    /// §3 state "month-next-year".
    static let monthNextYear = Self(
        mode: "month", origin: "month", now: "2026-10-20T22:42", topMonth: "2027-04",
        selectedDate: "2026-10-20", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2027-04-01",
            "2027-04-05",
            "2027-04-05",
            "2027-04-08",
            "2027-04-12",
            "2027-04-15",
            "2027-04-15",
            "2027-04-15",
            "2027-04-19",
            "2027-04-19",
            "2027-04-22",
            "2027-04-26",
            "2027-04-26",
            "2027-04-26",
            "2027-04-26",
            "2027-05-03",
            "2027-05-10"
        ],
        eventTitles: [
            "Lesson 1",
            "Lesson 1",
            "Meeting 2",
            "Online 1",
            "Meeting 1",
            "Lesson 1",
            "Meeting 2",
            "Deadline 3",
            "Lesson 1",
            "Meeting 2",
            "Social 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Lesson 1",
            "Meeting 1"
        ],
        eventTypes: [
            "lesson",
            "lesson",
            "meeting",
            "online",
            "meeting",
            "lesson",
            "meeting",
            "deadline",
            "lesson",
            "meeting",
            "social",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "lesson",
            "meeting"
        ],
        eventStarts: [
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "09:00"
        ],
        eventEnds: [
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "10:00"
        ],
        eventLocations: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventURLs: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults"
        ],
        eventRecurring: [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    )

    /// §3 state "month-dense".
    static let monthDense = Self(
        mode: "month", origin: "month", now: "2026-10-20T22:42", topMonth: "2026-09",
        selectedDate: "2026-10-20", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-09-01",
            "2026-09-01",
            "2026-09-02",
            "2026-09-02",
            "2026-09-03",
            "2026-09-04",
            "2026-09-04",
            "2026-09-04",
            "2026-09-04",
            "2026-09-06",
            "2026-09-07",
            "2026-09-07",
            "2026-09-09",
            "2026-09-09",
            "2026-09-09",
            "2026-09-10",
            "2026-09-11",
            "2026-09-11",
            "2026-09-11",
            "2026-09-11",
            "2026-09-11",
            "2026-09-16",
            "2026-09-16",
            "2026-09-16",
            "2026-09-16",
            "2026-09-21",
            "2026-09-21",
            "2026-09-28",
            "2026-09-28",
            "2026-09-30",
            "2026-09-30",
            "2026-09-30",
            "2026-09-30",
            "2026-10-01",
            "2026-10-02",
            "2026-10-05",
            "2026-10-05",
            "2026-10-06",
            "2026-10-08",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-12",
            "2026-10-12",
            "2026-10-15",
            "2026-10-19",
            "2026-10-19",
            "2026-10-20",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-26",
            "2026-10-27",
            "2026-10-27",
            "2026-10-27",
            "2026-10-31"
        ],
        eventTitles: [
            "Lesson 1",
            "Meeting 2",
            "Lesson 1",
            "Online 2",
            "Meeting 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Other 1",
            "Meeting 1",
            "Social 2",
            "Lesson 1",
            "Online 2",
            "Meeting 3",
            "Meeting 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Social 5",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Lesson 1",
            "Meeting 2",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Social 4",
            "Meeting 1",
            "Other 1",
            "Lesson 1",
            "Meeting 2",
            "Online 1",
            "Lesson 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Social 1",
            "Lesson 1",
            "Meeting 2",
            "Daily team sync",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Social 5",
            "Lesson 1",
            "Lesson 1",
            "Social 2",
            "Other 3",
            "Social 1"
        ],
        eventTypes: [
            "lesson",
            "meeting",
            "lesson",
            "online",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "other",
            "meeting",
            "social",
            "lesson",
            "online",
            "meeting",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "social",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "lesson",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "social",
            "meeting",
            "other",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "social",
            "lesson",
            "meeting",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "social",
            "lesson",
            "lesson",
            "social",
            "other",
            "social"
        ],
        eventStarts: [
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "09:47",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00"
        ],
        eventEnds: [
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "14:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "10:13",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "14:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00"
        ],
        eventLocations: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventURLs: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Leadership Team",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults"
        ],
        eventRecurring: [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    )

    /// Owner preview "day-past" (covers §3 state day-past) — the owner's props, kept.
    static let dayPast = Self(
        mode: "day", origin: "day", now: "2026-10-20T22:42", topMonth: "2026-07",
        selectedDate: "2026-07-29", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-07-29",
            "2026-07-29"
        ],
        eventTitles: [
            "Daily team sync",
            "Luke & Scott"
        ],
        eventTypes: [
            "meeting",
            "meeting"
        ],
        eventStarts: [
            "09:47",
            "13:02"
        ],
        eventEnds: [
            "10:13",
            "13:59"
        ],
        eventLocations: [
            "",
            "Three Forks Steakhouse"
        ],
        eventURLs: [
            "",
            ""
        ],
        eventGroups: [
            "Leadership Team",
            "Young Adults"
        ],
        eventRecurring: [
            true,
            true
        ]
    )

    /// §3 state "day-today".
    static let dayToday = Self(
        mode: "day", origin: "day", now: "2026-10-20T22:42", topMonth: "2026-10",
        selectedDate: "2026-10-20", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-10-20"
        ],
        eventTitles: [
            "Daily team sync"
        ],
        eventTypes: [
            "meeting"
        ],
        eventStarts: [
            "09:47"
        ],
        eventEnds: [
            "10:13"
        ],
        eventLocations: [
            ""
        ],
        eventURLs: [
            ""
        ],
        eventGroups: [
            "Leadership Team"
        ],
        eventRecurring: [
            true
        ]
    )

    /// Owner preview "day-overlap" (covers §3 state day-overlap) — the owner's props, kept.
    static let dayOverlap = Self(
        mode: "day", origin: "day", now: "2026-10-20T22:42", topMonth: "2026-07",
        selectedDate: "2026-07-31", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-07-31",
            "2026-07-31"
        ],
        eventTitles: [
            "Daily Inspiration",
            "Group Meeting"
        ],
        eventTypes: [
            "meeting",
            "meeting"
        ],
        eventStarts: [
            "07:30",
            "10:02"
        ],
        eventEnds: [
            "08:00",
            "10:58"
        ],
        eventLocations: [
            "",
            "Starbucks"
        ],
        eventURLs: [
            "",
            ""
        ],
        eventGroups: [
            "Leadership Team",
            "Young Adults"
        ],
        eventRecurring: [
            true,
            true
        ]
    )

    /// §3 state "day-allday".
    static let dayAllday = Self(
        mode: "day", origin: "day", now: "2026-10-20T22:42", topMonth: "2026-07",
        selectedDate: "2026-07-22", query: "", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-07-22",
            "2026-07-22"
        ],
        eventTitles: [
            "Team offsite",
            "Daily team sync"
        ],
        eventTypes: [
            "lesson",
            "meeting"
        ],
        eventStarts: [
            "",
            "09:47"
        ],
        eventEnds: [
            "",
            "10:13"
        ],
        eventLocations: [
            "",
            ""
        ],
        eventURLs: [
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Leadership Team"
        ],
        eventRecurring: [
            false,
            true
        ]
    )

    /// §3 state "search-focused-empty".
    static let searchFocusedEmpty = Self(
        mode: "search", origin: "month", now: "2026-10-20T22:42", topMonth: "2026-10",
        selectedDate: "2026-10-20", query: "", focused: true,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2026-10-01",
            "2026-10-02",
            "2026-10-05",
            "2026-10-05",
            "2026-10-06",
            "2026-10-08",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-09",
            "2026-10-12",
            "2026-10-12",
            "2026-10-15",
            "2026-10-19",
            "2026-10-19",
            "2026-10-20",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-23",
            "2026-10-26",
            "2026-10-27",
            "2026-10-27",
            "2026-10-27",
            "2026-10-31",
            "2026-11-02",
            "2026-11-03",
            "2026-11-03",
            "2026-11-06",
            "2026-11-06",
            "2026-11-06",
            "2026-11-09",
            "2026-11-09",
            "2026-11-09",
            "2026-11-09",
            "2026-11-13",
            "2026-11-13",
            "2026-11-16",
            "2026-11-20",
            "2026-11-20",
            "2026-11-23",
            "2026-11-27"
        ],
        eventTitles: [
            "Meeting 1",
            "Other 1",
            "Lesson 1",
            "Meeting 2",
            "Online 1",
            "Lesson 1",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Social 1",
            "Lesson 1",
            "Meeting 2",
            "Daily team sync",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Social 5",
            "Lesson 1",
            "Lesson 1",
            "Social 2",
            "Other 3",
            "Social 1",
            "Meeting 1",
            "Lesson 1",
            "Meeting 2",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Lesson 1",
            "Meeting 2",
            "Online 3",
            "Deadline 4",
            "Meeting 1",
            "Online 2",
            "Lesson 1",
            "Meeting 1",
            "Online 2",
            "Lesson 1",
            "Social 1"
        ],
        eventTypes: [
            "meeting",
            "other",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "social",
            "lesson",
            "meeting",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "social",
            "lesson",
            "lesson",
            "social",
            "other",
            "social",
            "meeting",
            "lesson",
            "meeting",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "meeting",
            "online",
            "deadline",
            "meeting",
            "online",
            "lesson",
            "meeting",
            "online",
            "lesson",
            "social"
        ],
        eventStarts: [
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "09:47",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "09:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "10:00",
            "11:00",
            "09:00",
            "10:00",
            "11:00",
            "12:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00",
            "10:00",
            "09:00",
            "09:00"
        ],
        eventEnds: [
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "10:13",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "14:00",
            "10:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "11:00",
            "12:00",
            "10:00",
            "11:00",
            "12:00",
            "13:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00",
            "11:00",
            "10:00",
            "10:00"
        ],
        eventLocations: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventURLs: [
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Leadership Team",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults"
        ],
        eventRecurring: [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    )

    /// §3 state "search-no-results".
    static let searchNoResults = Self(
        mode: "search", origin: "month", now: "2026-10-20T22:42", topMonth: "2026-10",
        selectedDate: "2026-10-20", query: "birthfay", focused: true,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [],
        eventTitles: [],
        eventTypes: [],
        eventStarts: [],
        eventEnds: [],
        eventLocations: [],
        eventURLs: [],
        eventGroups: [],
        eventRecurring: []
    )

    /// §3 state "search-results".
    static let searchResults = Self(
        mode: "search", origin: "month", now: "2026-10-20T22:42", topMonth: "2026-10",
        selectedDate: "2026-10-20", query: "lidon", focused: false,
        loading: false, searchFetching: false, searchFailed: false,
        eventDates: [
            "2020-01-13",
            "2021-08-28",
            "2021-10-21",
            "2024-08-28",
            "2025-08-28",
            "2026-08-28",
            "2026-10-22",
            "2026-11-01",
            "2027-08-28"
        ],
        eventTitles: [
            "Manners Class pick up // Lidon + Zura",
            "Lidon lunch",
            "Parent Teacher Conference- Lidon",
            "Lidon birthday",
            "Lidon birthday",
            "Lidon birthday",
            "Lidon soccer practice",
            "Lidon recital",
            "Lidon birthday"
        ],
        eventTypes: [
            "lesson",
            "social",
            "online",
            "other",
            "other",
            "other",
            "social",
            "lesson",
            "other"
        ],
        eventStarts: [
            "15:50",
            "23:00",
            "10:15",
            "",
            "",
            "",
            "17:30",
            "14:00",
            ""
        ],
        eventEnds: [
            "16:20",
            "00:30",
            "10:30",
            "",
            "",
            "",
            "18:30",
            "15:00",
            ""
        ],
        eventLocations: [
            "Joe V. Hart Elementary School, 450 Country Club Dr",
            "",
            "",
            "",
            "",
            "",
            "Hart Park",
            "",
            ""
        ],
        eventURLs: [
            "",
            "",
            "https://meet.google.com/abc-defg-hij",
            "",
            "",
            "",
            "",
            "",
            ""
        ],
        eventGroups: [
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults",
            "Young Adults"
        ],
        eventRecurring: [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    )
}

#Preview("month-current") {
    CalendarHomeScreen(state: .monthCurrent)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("month-next-year") {
    CalendarHomeScreen(state: .monthNextYear)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("month-dense") {
    CalendarHomeScreen(state: .monthDense)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("day-past") {
    CalendarHomeScreen(state: .dayPast)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("day-today") {
    CalendarHomeScreen(state: .dayToday)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("day-overlap") {
    CalendarHomeScreen(state: .dayOverlap)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("day-allday") {
    CalendarHomeScreen(state: .dayAllday)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-focused-empty") {
    CalendarHomeScreen(state: .searchFocusedEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-no-results") {
    CalendarHomeScreen(state: .searchNoResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-results") {
    CalendarHomeScreen(state: .searchResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
