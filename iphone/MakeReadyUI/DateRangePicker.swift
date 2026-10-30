//
//  DateRangePicker.swift
//  MakeReadyUI — the UI 2.0 module
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
/// presents the 1.0 page's override dialog from `prompt` (§1 deviation 5). No overlap alert (§1 deviation 8).
///
/// §2: "It fills the given width and height (it is a scroll body)" — no background, no padding.
struct DateRangePicker: View {

    /// §4 `prompt` — "`.none` or `.override(Date)` (the dialog)" (R-36).
    enum Prompt: Equatable {
        case none
        case override(Date)
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
    /// §4 `existingLessonDates` — "days the group already has a lesson; draws event dots only".
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
    /// §4 `onPromptChange` — "open the override dialog (tap rules, §2) or close it (any button, or dismiss → `.none`)".
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

/// §4: any button, or a dismissal, closes the prompt → `onPromptChange(.none)`.
private func promptBinding(_ picker: DateRangePicker, _ kind: KeyPath<DateRangePicker.Prompt, Bool>) -> Binding<Bool> {
    Binding(
        get: { picker.prompt[keyPath: kind] },
        set: { presented in if !presented { picker.onPromptChange(.none) } }
    )
}

private extension DateRangePicker.Prompt {
    var isOverride: Bool { if case .override = self { return true } else { return false } }
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

    /// 1.0 `handleDateSelection`, less the overlap check (§1 deviation 8) and the included check
    /// (§1 deviation 9): any day ≥ `today` becomes the start (§2 *Tap*).
    func handleDateSelection(_ date: Date) {
        pick(date, force: true)
    }

    /// The port's `selectStartDate(_:force:)` on a scratch copy: its past guard (and, unforced, its
    /// included guard) decides, and a pass emits the new start, then the cleared override set
    /// (§4 `onStartDateChange`).
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
