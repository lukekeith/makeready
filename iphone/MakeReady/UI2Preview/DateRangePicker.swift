//
//  DateRangePicker.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-128-date-range-picker in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-128 DateRangePicker — the 1.0 enrollment calendar body, wrapped.
///
/// §1: "Behaviour and look are normative from the 1.0 code" — the calendar itself is
/// `EnrollCalendarRepresentable` + `EnrollmentDateState` in `EnrollCalendar.swift`, ported
/// unchanged. This view is only the controlled (R-01) shell over it: it mirrors the §4 props into
/// the port's state object, routes the port's taps through the 1.0 page's rules (§2 *Tap*), and
/// presents the 1.0 page's override dialog and overlap alert from `prompt` (§1 deviation 5).
///
/// §2: "It fills the given width and height (it is a scroll body)" — no background, no padding.
struct DateRangePicker: View {

    /// §4 `prompt` — "`.none`, `.override(Date)` (the dialog) or `.overlap(Date)` (the alert)" (R-36).
    enum Prompt: Equatable {
        case none
        case override(Date)
        case overlap(Date)
    }

    /// §4 `lessonCount` — "the program's lesson count; drives the end date".
    let lessonCount: Int
    /// §4 `today` — "the reference day (start of day)" (OQ-C-128-002).
    let today: Date
    /// §4 `startDate` — "the chosen start; `nil` = none".
    let startDate: Date?
    /// §4 `enabledDays` — "included weekdays, 0 = Sun … 6 = Sat. Read-only here".
    let enabledDays: Set<Int>
    /// §4 `overriddenDates` — "start-of-day dates whose inclusion is flipped".
    let overriddenDates: Set<Date>
    /// §4 `existingLessonDates` — "days the group already has a lesson (dots + overlap check)".
    let existingLessonDates: Set<Date>
    /// §4 `currentScheduleDates` — "ghost of an existing schedule; the enrollment flow passes `[]`".
    let currentScheduleDates: Set<Date>
    /// §4 `prompt` — which prompt is open.
    let prompt: Prompt
    /// §4 `onStartDateChange` — "a start was picked; always followed by `onOverriddenDatesChange([])`".
    var onStartDateChange: (Date) -> Void = { _ in }
    /// §4 `onOverriddenDatesChange` — "the override set after a long-press/drag flip, "Remove
    /// Override", or a start pick (empty)".
    var onOverriddenDatesChange: (Set<Date>) -> Void = { _ in }
    /// §4 `onPromptChange` — "open a prompt (tap rules, §2) or close it (any button, or dismiss → `.none`)".
    var onPromptChange: (Prompt) -> Void = { _ in }

    var body: some View {
        // The port's `EnrollmentDateState.lessonCount` is a `let`, so a new count is a new mirror.
        MirroredCalendar(picker: self)
            .id(lessonCount)
            .ui2Element("DateRangePicker")             // capture element map — UI2Element.swift
    }
}

// MARK: - The mirrored port

private extension DateRangePicker {

    /// Holds the port's `EnrollmentDateState` as the RENDER mirror of the props. The controller keeps
    /// it `weak`, so it lives in a `@StateObject` here; it is never the source of truth.
    struct MirroredCalendar: View {
        let picker: DateRangePicker
        @StateObject private var mirror: EnrollmentDateState

        init(picker: DateRangePicker) {
            self.picker = picker
            _mirror = StateObject(wrappedValue: picker.makeState())
        }

        var body: some View {
            mirrored
                .modifier(OverridePrompt(picker: picker, title: overrideTitle, message: overrideExplanation))
                .modifier(OverlapPrompt(picker: picker))
        }

        private var mirrored: some View {
            EnrollCalendarRepresentable(
                state: mirror,
                existingLessonDates: picker.existingLessonDates,
                currentScheduleDates: picker.currentScheduleDates,
                onOverrideDayTapped: { picker.onPromptChange(.override($0)) },
                onRegularDayTapped: { picker.handleDateSelection($0) }
            )
            // Props → mirror. Each write publishes, and the representable reloads (and runs the
            // port's start-change travel + bounce) exactly as the 1.0 page's state did.
            .onChange(of: picker.today) { _, value in mirror.today = value }
            .onChange(of: picker.startDate) { _, value in mirror.startDate = value }
            .onChange(of: picker.enabledDays) { _, value in mirror.enabledDays = value }
            .onChange(of: picker.overriddenDates) { _, value in mirror.overriddenDates = value }
            // The port's long-press/drag flips write the mirror directly (§2 *Long-press*); emit
            // each one. A prop push echoes back equal, so it emits nothing.
            .onReceive(mirror.$overriddenDates) { value in
                if value != picker.overriddenDates { picker.onOverriddenDatesChange(value) }
            }
        }

        /// §4 `.override(d)`: "titled `EEEE, MMMM d` of d ("Monday, December 23")".
        private var overrideTitle: String {
            guard case .override(let date) = picker.prompt else { return "Override Day" }
            return DateRangePicker.fullDateHeader.string(from: date)
        }

        /// §4 `.override(d)` message — removed when d's weekday is enabled, else added.
        private var overrideExplanation: String {
            guard case .override(let date) = picker.prompt else { return "" }
            let weekday = Foundation.Calendar.current.component(.weekday, from: date) - 1
            return picker.enabledDays.contains(weekday)
                ? "This day has been manually removed from the schedule."
                : "This day has been manually added to the schedule."
        }
    }
}

/// §4 `.override(d)` — the 1.0 page's confirmation dialog, verbatim.
private struct OverridePrompt: ViewModifier {
    let picker: DateRangePicker
    let title: String
    let message: String

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: promptBinding(picker, \.isOverride),
            titleVisibility: .visible
        ) {
            SwiftUI.Button("Remove Override", role: .destructive, action: removeOverride)
            SwiftUI.Button("Set as Start Date", action: setAsStart)
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private func removeOverride() {
        if case .override(let date) = picker.prompt { picker.removeOverride(date) }
    }

    private func setAsStart() {
        if case .override(let date) = picker.prompt { picker.pick(date, force: true) }
    }
}

/// §4 `.overlap(d)` — the 1.0 page's "Lesson already scheduled" alert, verbatim.
private struct OverlapPrompt: ViewModifier {
    let picker: DateRangePicker

    func body(content: Content) -> some View {
        content.alert("Lesson already scheduled", isPresented: promptBinding(picker, \.isOverlap)) {
            SwiftUI.Button("Choose another date", role: .cancel) {}
            SwiftUI.Button("Schedule anyway", action: scheduleAnyway)
        } message: {
            Text("This member already has a lesson on the selected date. MakeReady recommends one lesson per day per member. Choose another date or schedule anyway if this overlap is intentional.")
        }
    }

    private func scheduleAnyway() {
        if case .overlap(let date) = picker.prompt { picker.pick(date, force: false) }
    }
}

/// §4: any button, or a dismissal, closes the prompt → `onPromptChange(.none)`.
private func promptBinding(_ picker: DateRangePicker, _ kind: KeyPath<DateRangePicker.Prompt, Bool>) -> Binding<Bool> {
    Binding(
        get: { picker.prompt[keyPath: kind] },
        set: { presented in if !presented { picker.onPromptChange(.none) } }
    )
}

private extension DateRangePicker.Prompt {
    var isOverride: Bool { if case .override = self { return true } else { return false } }
    var isOverlap: Bool { if case .overlap = self { return true } else { return false } }
}

// MARK: - The 1.0 page's rules, emitted instead of applied

private extension DateRangePicker {

    /// `CalendarFormatters.fullDateHeader` — "EEEE, MMMM d", the 1.0 dialog title.
    static let fullDateHeader: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// A fresh port state carrying the props — the mirror's seed, and the scratch copy each action
    /// runs the port's own rule on (so no rule is re-implemented here).
    func makeState() -> EnrollmentDateState {
        let state = EnrollmentDateState(lessonCount: lessonCount)
        state.today = today
        state.startDate = startDate
        state.enabledDays = enabledDays
        state.overriddenDates = overriddenDates
        return state
    }

    /// 1.0 `handleDateSelection`: the overlap check runs first (ported quirk, §2), then the pick.
    func handleDateSelection(_ date: Date) {
        let calendar = Foundation.Calendar.current
        let overlapping = calculatePotentialDates(startingFrom: date).contains { potential in
            existingLessonDates.contains(calendar.startOfDay(for: potential))
        }
        if overlapping {
            onPromptChange(.overlap(date))
        } else {
            pick(date, force: false)
        }
    }

    /// 1.0 `calculatePotentialDates`: the would-be schedule from `startDate`, overrides applied.
    func calculatePotentialDates(startingFrom startDate: Date) -> Set<Date> {
        let calendar = Foundation.Calendar.current
        var dates: Set<Date> = []
        var currentDate = startDate
        var lessonsScheduled = 0
        let maxIterations = lessonCount * 10

        for _ in 0..<maxIterations {
            let weekday = calendar.component(.weekday, from: currentDate) - 1
            let isWeekdayEnabled = enabledDays.contains(weekday)
            let dayStart = calendar.startOfDay(for: currentDate)
            let isOverridden = overriddenDates.contains(dayStart)

            if isWeekdayEnabled != isOverridden {
                dates.insert(dayStart)
                lessonsScheduled += 1
                if lessonsScheduled >= lessonCount { break }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }

    /// The port's `selectStartDate(_:force:)` on a scratch copy: its past / included guards decide,
    /// and a pass emits the new start, then the cleared override set (§4 `onStartDateChange`).
    func pick(_ date: Date, force: Bool) {
        let scratch = makeState()
        scratch.startDate = nil
        scratch.selectStartDate(date, force: force)
        guard let picked = scratch.startDate else { return }
        onStartDateChange(picked)
        onOverriddenDatesChange([])
    }

    /// "Remove Override" — the port's `toggleOverride` on a scratch copy.
    func removeOverride(_ date: Date) {
        let scratch = makeState()
        scratch.toggleOverride(date)
        onOverriddenDatesChange(scratch.overriddenDates)
    }
}
