//
//  EditDateFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  ui2-members-edit (new, T11): the shared-edit-field date arrangement (P10, D3) — a pushed page
//  that edits ONE calendar date and saves it. C-040 header → page description → "Not set" line
//  (when empty) → native wheel DatePicker → C-049 "Clear" → inline error line → C-048 Save.
//  States as the other shared-edit-field screens: clean · dirty · saving (Save disabled, input
//  locked, no spinner — D26) · save-failed (inline error line above Save).
//  UNBUILT in d2m — routed to /ui2-resolve to be drawn and captured (P10, F2, F4). This view
//  calls no endpoint. Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift.
//

import SwiftUI

/// Edit Date Field — one calendar date, picked on a native wheel, clearable to "Not set".
/// Values are calendar-free `DateComponents(year:month:day:)` in local terms (D9): the caller
/// converts the stored date to them and back, so no instant ever crosses a time zone here.
struct EditDateFieldScreen: View {

    /// One state's inputs. Every state is reachable by these alone.
    struct State {
        /// C-040's centred title — the field name.
        var title: String
        /// The screen-owned page description.
        var description: String
        /// The value the page was loaded with — what `clean` / `dirty` compare against. nil = "Not set".
        var loadedValue: DateComponents?
        /// The value the page opens with (the loaded value in the app; previews vary it). nil = "Not set".
        var selectedValue: DateComponents?
        /// The wheel's range (D9: 1900-01-01 … today, device local).
        var minDate: Date
        var maxDate: Date
        /// `saving`: a save is in flight.
        var saving: Bool = false
        /// `save-failed`: the inline error line's copy; "" renders no line.
        var errorMessage: String = ""
        /// birthday-no-clear (owner 2026-10-26): false hides the Clear link — a field that can be
        /// changed but not emptied. Default true keeps the designed page.
        var showsClear: Bool = true
    }

    let state: State
    var onBack: () -> Void = {}
    /// The chosen day, or nil to clear.
    var onSave: (DateComponents?) -> Void = { _ in }

    /// The page's current value — nil while "Not set" (local UI state, seeded from `State`).
    @SwiftUI.State private var value: DateComponents?
    /// What the wheel shows; it keeps its position when Clear sets `value` to nil.
    @SwiftUI.State private var wheelDate: Date

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (DateComponents?) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        let start = Self.day(state.selectedValue)
        _value = SwiftUI.State(initialValue: start)
        _wheelDate = SwiftUI.State(initialValue: Self.wheelStart(
            loaded: start, min: state.minDate, max: state.maxDate, calendar: .current
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // C-040 `twoIcons`, `showIcons=false`, leading glyph `back`, centred title — as the
            // other shared-edit-field screens.
            PageHeader(
                style: .twoIcons,
                title: state.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // Content column — inset `space-page-margin`, `space-section-gap` between parts.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                Text(state.description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // D9: an empty value says so above the wheel.
                    // GAP — undesigned: `type-value-emphasis` `color-text-secondary` proposed.
                    if value == nil {
                        Text(Self.notSetLabel)
                            .designTextStyle(Token.TypeStyle.valueEmphasis)
                            .foregroundStyle(Token.textSecondary)
                            .ui2Element("Not set")
                    }

                    DatePicker(
                        state.title,
                        selection: wheelBinding,
                        in: Self.range(min: state.minDate, max: state.maxDate),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // GAP — undesigned: the system wheel in the dark scheme over
                    // `color-layout-background`.
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity)
                    .disabled(state.saving)                          // D26: input locked
                    .ui2Element("DatePicker")

                    // D28 / OQ-shared-edit-field-4: C-049 as built (accent).
                    if state.showsClear {
                        LinkButton(
                            label: Self.clearLabel,
                            onTap: { value = nil },
                            isEnabled: Self.clearEnabled(value: value, saving: state.saving)
                        )
                        .ui2Element("C-049 LinkButton")
                    }
                }

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // `save-failed`: the inline error line in `type-page-title` `color-error`
                    // directly above Save (edit-option-field's proposed default).
                    if !state.errorMessage.isEmpty {
                        Text(state.errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PageActionButton(
                        label: Self.saveLabel,
                        role: .affirmative,
                        enabled: Self.saveEnabled(value: value, loaded: state.loadedValue, saving: state.saving),
                        onTap: { onSave(value) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)
    }

    /// Any wheel movement sets the value (D9: from "Not set" that is dirty).
    private var wheelBinding: Binding<Date> {
        Binding(
            get: { wheelDate },
            set: { date in
                wheelDate = date
                value = Self.components(of: date, calendar: .current)
            }
        )
    }

    // MARK: - Rules (pure)

    /// The calendar day of `c` — year, month and day only; nil when any is missing.
    static func day(_ c: DateComponents?) -> DateComponents? {
        guard let year = c?.year, let month = c?.month, let day = c?.day else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }

    /// `clean` ⇔ the same calendar day (or both "Not set").
    static func isDirty(value: DateComponents?, loaded: DateComponents?) -> Bool {
        day(value) != day(loaded)
    }

    /// `clean` and `saving` disable Save; `dirty` and `save-failed` enable it.
    static func saveEnabled(value: DateComponents?, loaded: DateComponents?, saving: Bool) -> Bool {
        !saving && isDirty(value: value, loaded: loaded)
    }

    /// D9: Clear is disabled when the value is already "Not set"; D26: and while saving.
    static func clearEnabled(value: DateComponents?, saving: Bool) -> Bool {
        !saving && day(value) != nil
    }

    /// D9: a "Not set" page opens the wheel on 2000-01-01.
    static let unsetWheelStart = DateComponents(year: 2000, month: 1, day: 1)

    /// The wheel's opening date — the value (or 2000-01-01), clamped into min…max.
    static func wheelStart(loaded: DateComponents?, min: Date, max: Date, calendar: Calendar) -> Date {
        let bounds = range(min: min, max: max)
        guard let date = calendar.date(from: day(loaded) ?? unsetWheelStart) else { return bounds.upperBound }
        return Swift.min(Swift.max(date, bounds.lowerBound), bounds.upperBound)
    }

    /// The calendar day `date` falls on in `calendar`.
    static func components(of date: Date, calendar: Calendar) -> DateComponents {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: c.year, month: c.month, day: c.day)
    }

    /// A range that cannot trap when a caller passes max < min.
    private static func range(min: Date, max: Date) -> ClosedRange<Date> {
        min...Swift.max(min, max)
    }

    private static let notSetLabel = "Not set"
    private static let clearLabel = "Clear"
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}

private extension EditDateFieldScreen.State {
    static var previewCalendar: Calendar { Calendar(identifier: .gregorian) }

    /// The member Birthday Use (D14 copy) — the base every preview varies.
    static func birthday(
        loaded: DateComponents? = DateComponents(year: 1974, month: 6, day: 25),
        selected: DateComponents? = DateComponents(year: 1974, month: 6, day: 25),
        saving: Bool = false,
        errorMessage: String = ""
    ) -> Self {
        .init(
            title: "Birthday",
            description: "Used to show this member's age to group leaders.",
            loadedValue: loaded,
            selectedValue: selected,
            minDate: previewCalendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast,
            maxDate: previewCalendar.date(from: DateComponents(year: 2026, month: 10, day: 26)) ?? Date(),
            saving: saving,
            errorMessage: errorMessage
        )
    }
}

#Preview("clean") {
    EditDateFieldScreen(state: .birthday())
        .frame(width: 440)
}

#Preview("dirty") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25)))
        .frame(width: 440)
}

#Preview("saving") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25), saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25), errorMessage: "Couldn't save. Try again."))
        .frame(width: 440)
}

#Preview("not-set") {
    EditDateFieldScreen(state: .birthday(loaded: nil, selected: nil))
        .frame(width: 440)
}
