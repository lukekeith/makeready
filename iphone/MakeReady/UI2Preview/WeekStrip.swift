//
//  WeekStrip.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-116-week-strip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-116 WeekStrip — "the day-mode row of one week's seven dates with the selected-day circle".
///
/// §2: "One week, width-driven (R-16): the full screen width, **7 equal columns** of width / 7,
/// Sunday first (D9) — the **same column centres as C-115** … Row height **44** … No background,
/// no indicators." The horizontal swipe is the screen's (§4, D11), not this row's.
struct WeekStrip: View {

    // MARK: - Props (§4, in order — R-05)

    /// §4 `week` — "any instant in the week to draw (normalised to its Sunday, D9)".
    let week: Date

    /// §4 `selected` — "the selected date — drawn with the Ø36 circle when it falls in this week".
    let selected: Date

    /// §4 `today` — "the screen's injected `now`; marks today's look. Never read from the clock
    /// (R-04)".
    let today: Date

    /// §4 `onSelectDate` — "a date tap; the screen pages the day (§7.2)".
    /// Unrequired (R-07 call-out): no-op default.
    var onSelectDate: (Date) -> Void = { _ in }

    /// §4 `onNextWeek` — "VoiceOver \"Next week\" action; the screen pages (§7.3)".
    /// Unrequired (R-07 call-out): no-op default.
    var onNextWeek: () -> Void = {}

    /// §4 `onPreviousWeek` — "VoiceOver \"Previous week\" action".
    /// Unrequired (R-07 call-out): no-op default.
    var onPreviousWeek: () -> Void = {}

    /// §3 `pressed / in-flight` — "Ø36 `color-white-30` (ephemeral)" (R-02): the column whose
    /// date is touched, not a prop, no preview.
    @State private var pressedColumn: Int?

    // MARK: - Geometry

    private enum Geometry {
        // FLAGGED LITERAL — C-116 §2: "Row height **44** (FLAGGED LITERAL, 02-design §5.1)", no token.
        static let height: CGFloat = 44
        // FLAGGED LITERAL — C-116 §2: Selection circle "Ø **36** (FLAGGED LITERAL)", no token.
        static let circle: CGFloat = 36
        /// D9: "Sunday first".
        static let columns = 7
    }

    /// FLAGGED LITERAL — C-116 §2: "SF Pro 19 — weight and colour per §3 (FLAGGED LITERAL type,
    /// no 19 pt token; fixed size, §10)". §3: Regular for an unselected date.
    private static let regularStyle = DesignTextStyle(weight: .regular, size: 19, lineHeight: nil, tracking: 0)

    /// FLAGGED LITERAL — C-116 §3: "today, not selected | Semibold 19" (same flag as above).
    private static let todayStyle = DesignTextStyle(weight: .semibold, size: 19, lineHeight: nil, tracking: 0)

    /// FLAGGED LITERAL — C-116 §3: "selected … | Bold 19" (same flag as above).
    private static let selectedStyle = DesignTextStyle(weight: .bold, size: 19, lineHeight: nil, tracking: 0)

    /// D9: Gregorian, week starts Sunday — the calendar C-113 and C-115 read their dates with.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }()

    /// §2 Accessibility (R-17): "labelled \"<EEEE, MMMM d, yyyy>[, today]\"".
    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    // MARK: - Derived

    /// §4: `week` "normalised to its Sunday, D9".
    private var sunday: Date {
        Self.calendar.dateInterval(of: .weekOfYear, for: week)?.start ?? Self.calendar.startOfDay(for: week)
    }

    private func date(at column: Int) -> Date {
        Self.calendar.date(byAdding: .day, value: column, to: sunday) ?? sunday
    }

    /// One date's §3 look.
    private struct Look {
        let style: DesignTextStyle
        let numeral: Color
        let circle: Color?
    }

    /// §3 per-date look (02-design §5.2 — closed): selected beats today beats weekend.
    private func look(of date: Date) -> Look {
        let isSelected = Self.calendar.isDate(date, inSameDayAs: selected)
        let isToday = Self.calendar.isDate(date, inSameDayAs: today)
        switch (isSelected, isToday) {
        case (true, true):
            return Look(style: Self.selectedStyle, numeral: Token.white100, circle: Token.negative)
        case (true, false):
            return Look(style: Self.selectedStyle, numeral: Token.black, circle: Token.white100)
        case (false, true):
            return Look(style: Self.todayStyle, numeral: Token.negative, circle: nil)
        case (false, false):
            let weekday = Self.calendar.component(.weekday, from: date)   // 1 = Sunday, 7 = Saturday
            let weekend = weekday == 1 || weekday == 7
            return Look(style: Self.regularStyle, numeral: weekend ? Token.white50 : Token.white100, circle: nil)
        }
    }

    private func accessibilityText(of date: Date) -> String {
        var text = Self.labelFormatter.string(from: date)
        if Self.calendar.isDate(date, inSameDayAs: today) { text += ", today" }
        return text
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<Geometry.columns, id: \.self) { column in
                dateColumn(column)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.height)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next week") { onNextWeek() }
        .accessibilityAction(named: "Previous week") { onPreviousWeek() }
        .ui2Element("WeekStrip")
    }

    /// §2 Date numeral — "centred in its column, centre y 22"; "hit target = column × 44".
    private func dateColumn(_ column: Int) -> some View {
        let date = date(at: column)
        let look = look(of: date)
        let isSelected = look.circle != nil
        return ZStack {
            circle(column: column, fill: look.circle)
            Text(verbatim: "\(Self.calendar.component(.day, from: date))")
                .designTextStyle(look.style)
                .foregroundStyle(look.numeral)
                .lineLimit(1)
                .fixedSize()
                .ui2Element("Date \(column + 1)")
        }
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.height)
        .contentShape(Rectangle())
        .onTapGesture { onSelectDate(date) }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressedColumn = $0 ? column : nil }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(of: date))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelectDate(date) }
    }

    /// §2 Selection circle — "Ø **36**, `radius-circle`, centred on the selected date's numeral,
    /// fill per §3"; §3 pressed — "Ø36 `color-white-30` (ephemeral)" while a date is touched.
    @ViewBuilder
    private func circle(column: Int, fill: Color?) -> some View {
        if pressedColumn == column {
            Circle()
                .fill(Token.white30)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .ui2Element("Pressed circle")
        } else if let fill {
            Circle()
                .fill(fill)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .ui2Element("Selection circle")
        }
    }
}
