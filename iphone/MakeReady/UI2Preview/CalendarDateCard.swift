//
//  CalendarDateCard.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-060-calendar-date-card in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-060 CalendarDateCard — "one calendar date as a bordered tear-off card".
///
/// 96×88 as designed; per R-16 / C-060 §1 deviation 4 the card fills the width it is given
/// (96 at every known call site) and states its own 88pt intrinsic height.
// note 2026-09-26T19:08:43.099Z — "designed to be generic to display any date for any
// purpose": no start/end role is encoded here; enrollment-home's first/final-day reading
// (notes 2026-09-11T05:38:35.302Z, 2026-09-11T05:39:17.917Z) is the call site's.
struct CalendarDateCard: View {

    // C-060 §4's rows, one parameter each, in the contract's order (R-05); all required (R-07).
    // No callbacks: non-interactive read-out (OQ-C-060-002, CLOSED).
    /// C-060 §4: `month` — header leading text, rendered verbatim.
    let month: String
    /// C-060 §4: `weekday` — header trailing text, rendered verbatim.
    let weekday: String
    /// C-060 §4: `day` — the day number, rendered verbatim, single line.
    let day: String

    var body: some View {
        // C-060 §2: "Stack: 1 (stroke) + 30 + 56 + 1 (stroke) = 88".
        VStack(spacing: 0) {
            headerRow
                .ui2Element("Header row")
            dayRow
                .ui2Element("Day row")
        }
        .padding(Self.borderWidth)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // C-060 §2 Card: "fill `color-card-background`; 1px **inside** stroke
        // `color-card-border`; corner `radius-card` (8); clips its content".
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .strokeBorder(Token.cardBorder, lineWidth: Self.borderWidth)
                .ui2Element("Border")
        )
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        // C-060 §2 accessibility (R-17): non-interactive, so no trait; "the three texts read
        // as ONE element, '<weekday> <month> <day>'".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weekday) \(month) \(day)")
        .ui2Element("CalendarDateCard")
    }

    // C-060 §2 Header row: "padding 8 all sides, `justify: space-between`, items centred,
    // 30 tall (8 + 14 + 8)".
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(month)
                .designTextStyle(Token.TypeStyle.calendarLabel)
                // OQ-C-060-001 (CLOSED): fixed calendar accent, always `color-negative`.
                .foregroundColor(Token.negative)
                .lineLimit(1)
                .ui2Element("Month")
            Spacer(minLength: 0)
            Text(weekday)
                .designTextStyle(Token.TypeStyle.calendarLabel)
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .ui2Element("Weekday")
        }
        // `type-calendar-label`'s designed 14pt line box — SwiftUI has no line-height.
        .frame(maxWidth: .infinity, minHeight: Self.labelLineBox, maxHeight: Self.labelLineBox)
        .padding(Self.rowInset)
    }

    // C-060 §2 Day row: "padding 8 all sides, 56 tall (8 + 40 + 8). Day number
    // leading-aligned".
    private var dayRow: some View {
        Text(day)
            .designTextStyle(Token.TypeStyle.calendarDate)
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            // `type-calendar-date`'s designed 40pt line box.
            .frame(maxWidth: .infinity, minHeight: Self.dateLineBox, maxHeight: Self.dateLineBox,
                   alignment: .leading)
            .ui2Element("Day number")
            .padding(Self.rowInset)
            // C-060 §2 Hairline: "1px `color-card-border`, full inner width, at y=31. It takes
            // **no layout height** … draw it as an overlay on the day row's top edge" — centred
            // on the header/day boundary, as Figma's 0-high vector strokes it.
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Token.cardBorder)
                    .frame(height: Self.borderWidth)
                    .offset(y: -Self.borderWidth / 2)
                    .ui2Element("Hairline")
            }
    }

    // C-060 §2: "1px inside stroke" / "1px `color-card-border`" hairline.
    private static let borderWidth: CGFloat = 1

    // GAP — C-060 §2: "padding 8 all sides" on both rows, no padding token. OQ-C-060-003
    // (CLOSED) ruled "Mint `space-card-padding-sm` = 8"; the row is not yet in the d2m token
    // register, so this stays a literal until it is — then becomes Token.Space.cardPaddingSm.
    private static let rowInset: CGFloat = 8

    private static let labelLineBox: CGFloat =
        Token.TypeStyle.calendarLabel.lineHeight ?? Token.TypeStyle.calendarLabel.size
    private static let dateLineBox: CGFloat =
        Token.TypeStyle.calendarDate.lineHeight ?? Token.TypeStyle.calendarDate.size
}
