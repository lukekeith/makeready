//
//  MonthGrid.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-115-month-grid in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-115 MonthGrid — "one month section of the continuous calendar: label band, week rows of
/// dates, partial-row separators".
///
/// §2: "One month section, width-driven (R-16): fills the width given — the full screen width,
/// no side margin — split into 7 equal columns `colW = width / 7` (Sunday first, D9). Height =
/// 27 + rows × 69. No background."
struct MonthGrid: View {

    // MARK: - Model

    /// §4 `MonthGrid.DayEvents` — "`day: Int` (1…31) · `eventTypes: [C-112 EventType]` (sorted
    /// all-day first, then start; value set owned by C-112)". Nested (R-36).
    struct DayEvents {
        let day: Int
        let eventTypes: [EventIndicator.EventType]
    }

    // MARK: - Props (§4, in order — R-05)

    /// §4 `month` — "any instant in the month to draw (normalised to its 1st, Gregorian)".
    let month: Date

    /// §4 `today` — "the screen's injected `now` … Drives the red label (same month) and which
    /// C-113 gets `today: true`. The grid never reads the clock (R-04)".
    let today: Date

    /// §4 `days` — "per-date event types for this month … Dates not listed have no indicator;
    /// `[]` = no indicators at all".
    let days: [DayEvents]

    /// §4 `onSelectDate` — "a date tap, with that date; the screen runs the curtain".
    /// Unrequired (R-07 call-out): no-op default.
    var onSelectDate: (Date) -> Void = { _ in }

    // MARK: - Geometry

    private enum Geometry {
        // FLAGGED LITERAL — C-115 §2: label band "27 pt tall" (02-design §4.3), no token.
        static let labelBand: CGFloat = 27
        // FLAGGED LITERAL — C-115 §2: label "baseline 6 pt above the band bottom" (02-design §4.3,
        // calendar geometry like the 27 pt band; OQ-C-115-1), no token.
        static let labelBaselineInset: CGFloat = 6
        // FLAGGED LITERAL — C-115 §2: week rows "each 69 pt tall" (02-design §4.1), no token.
        static let rowHeight: CGFloat = 69
        /// D9: "Sunday first".
        static let columns = 7
    }

    @Environment(\.displayScale) private var displayScale

    /// D9: Gregorian, week starts Sunday — the same calendar C-113 reads its weekday with.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }()

    /// §2 Label band: "3-letter month (`MMM`, \"Oct\")".
    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "MMM"
        return f
    }()

    /// §2 Accessibility (R-17): container labelled "<MMMM yyyy>" ("October 2026").
    private static let accessibilityFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    // MARK: - Derived

    /// §4: `month` "normalised to its 1st".
    private var firstOfMonth: Date {
        let parts = Self.calendar.dateComponents([.year, .month], from: month)
        return Self.calendar.date(from: parts) ?? month
    }

    /// The 1st's column, 0 = Sunday.
    private var firstColumn: Int { Self.calendar.component(.weekday, from: firstOfMonth) - 1 }

    private var dayCount: Int { Self.calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30 }

    /// §2: "`rows` = ceil((col of 1st + days in month) / 7)".
    private var rows: Int { (firstColumn + dayCount + Geometry.columns - 1) / Geometry.columns }

    /// §2: "Colour `color-negative` when `month` is `today`'s month".
    private var isCurrentMonth: Bool { Self.calendar.isDate(firstOfMonth, equalTo: today, toGranularity: .month) }

    /// The day-of-month that is `today`, when `today` falls in this month.
    private var todayDay: Int? { isCurrentMonth ? Self.calendar.component(.day, from: today) : nil }

    private var height: CGFloat { Geometry.labelBand + CGFloat(rows) * Geometry.rowHeight }

    private func date(of day: Int) -> Date {
        Self.calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? firstOfMonth
    }

    /// §2 Date cell: "`eventTypes` from `days` (absent → `[]`)".
    private func eventTypes(of day: Int) -> [EventIndicator.EventType] {
        days.first { $0.day == day }?.eventTypes ?? []
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let colW = proxy.size.width / CGFloat(Geometry.columns)
            VStack(spacing: 0) {
                labelBand(colW: colW)
                ForEach(0..<rows, id: \.self) { row in
                    weekRow(row, colW: colW)
                }
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.accessibilityFormatter.string(from: firstOfMonth))
        .ui2Element("MonthGrid")
    }

    /// §2 Label band: "`type-title-tile` … centred horizontally over the column of the 1st,
    /// baseline 6 pt above the band bottom … Not sticky".
    private func labelBand(colW: CGFloat) -> some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
            Color.clear
                .frame(height: Geometry.labelBand)
                .alignmentGuide(.lastTextBaseline) { $0.height - Geometry.labelBaselineInset }
            Text(verbatim: Self.labelFormatter.string(from: firstOfMonth))
                .designTextStyle(Token.TypeStyle.titleTile)
                .foregroundStyle(isCurrentMonth ? Token.negative : Token.white100)
                .lineLimit(1)
                .fixedSize()
                .frame(width: colW)
                .offset(x: CGFloat(firstColumn) * colW)
                .ui2Element("Month label")
        }
        .frame(height: Geometry.labelBand)
        .ui2Element("Label band")
    }

    /// §2 Week rows: "Row 1 starts at the 1st's column; only this month's dates are drawn — no
    /// leading/trailing days from neighbours".
    private func weekRow(_ row: Int, colW: CGFloat) -> some View {
        let startIndex = row * Geometry.columns
        let firstCol = max(firstColumn - startIndex, 0)
        let lastCol = min(firstColumn + dayCount - 1 - startIndex, Geometry.columns - 1)
        return ZStack(alignment: .topLeading) {
            // §2 Separator: "1 px `color-white-10` along the top of every week row, spanning
            // only the columns holding this month's dates in that row".
            Token.white10
                .frame(width: CGFloat(lastCol - firstCol + 1) * colW, height: 1 / displayScale)
                .offset(x: CGFloat(firstCol) * colW)
                .ui2Element("Separator \(row + 1)")

            ForEach(firstCol...lastCol, id: \.self) { col in
                let day = startIndex + col - firstColumn + 1
                let date = date(of: day)
                MonthDayCell(
                    date: date,
                    today: day == todayDay,
                    eventTypes: eventTypes(of: day),
                    onTap: { onSelectDate(date) }
                )
                .frame(width: colW)
                .offset(x: CGFloat(col) * colW)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Geometry.rowHeight, alignment: .topLeading)
        .ui2Element("Week row \(row + 1)")
    }
}
