//
//  EnrollmentSelectScheduleScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen enrollment-select-schedule in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/programs/{id} ·
//  GET /api/groups/{groupId}/enrollments · GET /api/enrollments/{id} (the commit is the
//  checklist's POST /api/enrollments; its missing `overriddenDates` is an API-GAP in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select schedule — step "Choose a schedule" of the enrollment checklist
/// (`groups-enroll-program`, §3): the leader picks a start date, the weekdays lessons fall on and
/// any one-off overrides; the end date is derived. Only Select commits. C-040 header, the C-128
/// calendar body on its #0D101A fill, then a pinned footer holding C-127 (§2). With no program on
/// the checklist (§3 state 6) the body and footer are replaced by a centred line over C-048.
///
/// The picker's draft — `startDate`, `enabledDays`, `overriddenDates`, `prompt` — is screen-local
/// (§3 "Screen-local draft (D43)"): Back discards it, Select hands it to the checklist.
struct EnrollmentSelectScheduleScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Dates are `yyyy-MM-dd`
    /// in the device's time zone (start of day), as C-128's fixtures write them.
    struct State {
        /// §3 state 6: false = the checklist has no program → needs-program.
        var programChosen: Bool
        /// C-128 `lessonCount` — the checklist program's lesson count (0 with no program).
        var lessonCount: Int
        /// C-128 `today` — the device's current day; previews pin it.
        var today: String
        /// The schedule's current value on open; "" = no start (§3 no-start).
        var startDate: String
        /// 0 = Sun … 6 = Sat; §3 seeds Mon–Fri when the row has no value.
        var enabledDays: [Int]
        /// Start-of-day dates whose inclusion is flipped.
        var overriddenDates: [String]
        /// The chosen group's lesson dates (`[]` with no group, or until they load — §3 Loading).
        var existingLessonDates: [String]
        /// C-128 `prompt`: `none`, `override(yyyy-MM-dd)` or `overlap(yyyy-MM-dd)`.
        var prompt: String
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                                              // §3 Back: discard + pop
    var onSelect: (Date, Date, Set<Int>, Set<Date>) -> Void = { _, _, _, _ in } // §3 Select: commit + pop
    var onChooseProgram: () -> Void = {}                                     // §3 state 6: push the program picker

    // §3 "Screen-local draft (D43): startDate, enabledDays, overriddenDates, prompt."
    @SwiftUI.State private var startDate: Date?
    @SwiftUI.State private var enabledDays: Set<Int>
    @SwiftUI.State private var overriddenDates: Set<Date>
    @SwiftUI.State private var prompt: DateRangePicker.Prompt

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (Date, Date, Set<Int>, Set<Date>) -> Void = { _, _, _, _ in },
        onChooseProgram: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
        self.onChooseProgram = onChooseProgram
        let days = state.enabledDays.isEmpty ? Self.defaultDays : Set(state.enabledDays)
        let overrides = Set(state.overriddenDates.compactMap(Self.day))
        // §3 cascades: a seeded start that fails the §5 check (before `today`, or not on an
        // included day) is dropped, and the screen opens in no-start with the seeded weekdays.
        let seeded = Self.day(state.startDate).flatMap { start in
            Self.passes(start: start, today: Self.day(state.today) ?? start,
                        days: days, overrides: overrides, lessonCount: state.lessonCount) ? start : nil
        }
        _startDate = SwiftUI.State(initialValue: seeded)
        _enabledDays = SwiftUI.State(initialValue: days)
        _overriddenDates = SwiftUI.State(initialValue: overrides)
        _prompt = SwiftUI.State(initialValue: Self.prompt(state.prompt))
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2 L1: centred title "Select schedule".
    private static let pageTitle = "Select schedule"
    /// §2 L1 / §4: trailing action "Select".
    private static let selectLabel = "Select"
    /// §2 *needs-program body* 1.
    private static let needsProgramLine = "Choose a study program first to set the schedule"
    /// §2 *needs-program body* 3 / §4 C-048 `label`.
    private static let chooseProgramLabel = "Choose a study program"
    /// §3: "Seeded … else `enabledDays = {Mon…Fri}`".
    private static let defaultDays: Set<Int> = [1, 2, 3, 4, 5]

    // MARK: - §2 geometry the screen owns

    // FLAGGED LITERAL — enrollment-select-schedule §2: #0D101A body fill behind C-128, no token
    // (OQ-enrollment-select-schedule-001, owner 2026-10-24).
    private static let calendarFill = Color(red: 13 / 255, green: 16 / 255, blue: 26 / 255)
    // GAP — enrollment-select-schedule §2 L2: the body "fills everything between the header and the
    // footer (713 pt on this frame)", no sizing token. A floor so the footer sits above the bottom
    // safe area when the harness proposes no height; flexible above it.
    private static let calendarHeight: CGFloat = 713
    // GAP — enrollment-select-schedule §2 *needs-program body*: "vertically centred in the body
    // area — everything between the header's bottom edge (y 103) and the bottom safe area" (y 910
    // → 807 pt), no sizing token. A floor, flexible above it.
    private static let bodyAreaHeight: CGFloat = 807

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — only C-128 scrolls (§2). The status bar is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            header
            if state.programChosen {
                calendar
                footer
            } else {
                needsProgram
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                       // §2: the page background
    }

    /// §2 L1: C-040 `style: backAndLink` (D60) — back glyph, centred title, trailing "Select";
    /// `trailingEnabled` = the §5 schedule check passes (OQ-C-040-001: `color-white-50`, inert).
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.pageTitle,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: Self.selectLabel,
            trailingEnabled: selectEnabled,
            onLeading: onBack,
            onDone: {
                guard selectEnabled, let startDate, let endDate else { return }
                onSelect(startDate, endDate, enabledDays, overriddenDates)
            }
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2 L2: C-128, full width, the scroll body; the screen answers its three callbacks (§3).
    private var calendar: some View {
        DateRangePicker(
            lessonCount: state.lessonCount,
            today: today,
            startDate: startDate,
            enabledDays: enabledDays,
            overriddenDates: overriddenDates,
            existingLessonDates: Set(state.existingLessonDates.compactMap(Self.day)),
            currentScheduleDates: [],                            // §3: always `[]`
            prompt: prompt,
            onStartDateChange: { startDate = $0 },
            onOverriddenDatesChange: { overriddenDates = $0 },
            onPromptChange: { prompt = $0 }
        )
        .frame(maxWidth: .infinity, minHeight: Self.calendarHeight, maxHeight: .infinity)
        .background(Self.calendarFill)                           // §2: painted by the screen
        .ui2Element("C-128 DateRangePicker")
    }

    /// §2 L3: an inline page container, `space-page-margin` on every side, holding C-127.
    private var footer: some View {
        ScheduleSummaryFooter(
            dateRange: dateRange,
            enabledDays: Set(enabledDays.map { ScheduleSummaryFooter.Weekday.allCases[$0] }),
            onEnabledDaysChange: { days in
                // §3: overrides persist; a toggle off the start's weekday keeps the start (OQ-004).
                enabledDays = Set(days.compactMap { ScheduleSummaryFooter.Weekday.allCases.firstIndex(of: $0) })
            }
        )
        .ui2Element("C-127 ScheduleSummaryFooter")
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity)
        .background(Token.layoutBackground)
    }

    /// §2 *needs-program body*: the line, `space-stack-gap`, then a full-width C-048 — inset
    /// `space-page-margin` left and right, vertically centred in the body area.
    private var needsProgram: some View {
        VStack(spacing: Token.Space.stackGap) {
            Text(Self.needsProgramLine)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundColor(Token.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            PageActionButton(
                label: Self.chooseProgramLabel,
                role: .affirmative,
                size: .md,
                glyph: nil,
                layout: .centered,
                enabled: true,
                onTap: onChooseProgram
            )
            .ui2Element("C-048 PageActionButton")
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(maxWidth: .infinity, minHeight: Self.bodyAreaHeight, maxHeight: .infinity)
    }

    // MARK: - Derived (R-30: computed on read, through C-128's ported rules)

    private var today: Date { Self.day(state.today) ?? Foundation.Calendar.current.startOfDay(for: Date()) }

    /// §3: "End date = C-128's ported `calculatedEndDate` over the draft".
    private var endDate: Date? {
        Self.scratch(start: startDate, days: enabledDays, overrides: overriddenDates,
                     lessonCount: state.lessonCount).calculatedEndDate
    }

    /// §3: "C-127 gets `dateRange = startDate…endDate` (or `nil`)".
    private var dateRange: ClosedRange<Date>? {
        guard let startDate, let endDate, startDate <= endDate else { return nil }
        return startDate...endDate
    }

    /// §3 "Select enabled iff the draft passes design §5's schedule check".
    private var selectEnabled: Bool {
        guard state.programChosen, let startDate else { return false }
        return Self.passes(start: startDate, today: today, days: enabledDays,
                           overrides: overriddenDates, lessonCount: state.lessonCount)
    }

    /// §5 check: start ≥ today, on an included day, weekdays not empty, an end date computed.
    private static func passes(start: Date, today: Date, days: Set<Int>, overrides: Set<Date>,
                               lessonCount: Int) -> Bool {
        let scratch = scratch(start: start, days: days, overrides: overrides, lessonCount: lessonCount)
        return lessonCount > 0
            && start >= today
            && !days.isEmpty
            && scratch.isDateIncluded(start)
            && scratch.calculatedEndDate != nil
    }

    /// The port's `EnrollmentDateState` as a scratch copy, so no rule is re-implemented here.
    private static func scratch(start: Date?, days: Set<Int>, overrides: Set<Date>,
                                lessonCount: Int) -> EnrollmentDateState {
        let scratch = EnrollmentDateState(lessonCount: lessonCount)
        scratch.startDate = start
        scratch.enabledDays = days
        scratch.overriddenDates = overrides
        return scratch
    }

    // MARK: - Decoding the State's strings

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Foundation.Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func day(_ raw: String) -> Date? {
        raw.isEmpty ? nil : dayFormatter.date(from: String(raw.prefix(10)))
    }

    private static func prompt(_ raw: String) -> DateRangePicker.Prompt {
        if raw.hasPrefix("override("), raw.hasSuffix(")"),
           let date = day(String(raw.dropFirst(9).dropLast())) {
            return .override(date)
        }
        if raw.hasPrefix("overlap("), raw.hasSuffix(")"),
           let date = day(String(raw.dropFirst(8).dropLast())) {
            return .overlap(date)
        }
        return .none
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case). Values trace to §1 deviation 1 and C-128's own §3 samples.

extension EnrollmentSelectScheduleScreen.State {
    /// §3 state 1 — no start; Mon–Fri on.
    static let noStart = Self(programChosen: true, lessonCount: 15, today: "2026-10-24", startDate: "",
                              enabledDays: [1, 2, 3, 4, 5], overriddenDates: [], existingLessonDates: [],
                              prompt: "none")
    /// §3 state 2 (frame `date-range`) — Mon 2 Nov, Mon/Wed/Fri, 15 lessons → NOV 2 - DEC 4.
    static let range = Self(programChosen: true, lessonCount: 15, today: "2026-10-24", startDate: "2026-11-02",
                            enabledDays: [1, 3, 5], overriddenDates: [], existingLessonDates: [],
                            prompt: "none")
    /// §3 state 3 — range plus C-128's two sample overrides (one removed, one added).
    static let overrides = Self(programChosen: true, lessonCount: 15, today: "2026-10-24",
                                startDate: "2026-11-02", enabledDays: [1, 3, 5],
                                overriddenDates: ["2026-11-11", "2026-11-19"], existingLessonDates: [],
                                prompt: "none")
    /// §3 state 4 — the override dialog on 11 Nov over the overrides draft.
    static let overrideSheet = Self(programChosen: true, lessonCount: 15, today: "2026-10-24",
                                    startDate: "2026-11-02", enabledDays: [1, 3, 5],
                                    overriddenDates: ["2026-11-11", "2026-11-19"], existingLessonDates: [],
                                    prompt: "override(2026-11-11)")
    /// §3 state 5 — "Lesson already scheduled" for a 2 Nov tap against the group's lessons.
    static let overlapWarning = Self(programChosen: true, lessonCount: 15, today: "2026-10-24", startDate: "",
                                     enabledDays: [1, 2, 3, 4, 5], overriddenDates: [],
                                     existingLessonDates: ["2026-11-09", "2026-11-16", "2026-11-17"],
                                     prompt: "overlap(2026-11-02)")
    /// §3 state 6 — no program on the checklist.
    static let needsProgram = Self(programChosen: false, lessonCount: 0, today: "2026-10-24", startDate: "",
                                   enabledDays: [1, 2, 3, 4, 5], overriddenDates: [], existingLessonDates: [],
                                   prompt: "none")
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("no-start") {
    EnrollmentSelectScheduleScreen(state: .noStart)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("range") {
    EnrollmentSelectScheduleScreen(state: .range)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("overrides") {
    EnrollmentSelectScheduleScreen(state: .overrides)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("override-sheet") {
    EnrollmentSelectScheduleScreen(state: .overrideSheet)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("overlap-warning") {
    EnrollmentSelectScheduleScreen(state: .overlapWarning)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("needs-program") {
    EnrollmentSelectScheduleScreen(state: .needsProgram)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
