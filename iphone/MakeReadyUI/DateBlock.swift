//
//  DateBlock.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-070-date-block in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  First built inline inside DayActivityCard.swift (C-025's R-15 fallback, 2026-09-20);
//  moved here by `/d2m-component-build C-070` so the row has a view, fixture and subject
//  of its own. C-025 composes this type unchanged.
//

import SwiftUI

/// C-070 DateBlock — "a day's calendar label (month + weekday, or TODAY) over its day number".
///
/// 97×38 as designed; per R-16 / C-070 §2 the block "fills the width it is given and states
/// its own 38pt intrinsic height" — the symbol is 97 wide because C-025's content slot is 97,
/// and the label row's justification spreads to whatever width the call site gives. No
/// background, border, padding or corner radius: bare text over the consumer's surface.
struct DateBlock: View {

    /// C-070 §4 `state: default | today` — Figma's own axis, 1:1 (R-06, R-36).
    enum State {
        case `default`
        case today
    }

    // C-070 §4's rows, one parameter each, in the contract's order (R-05); all required (R-07).
    /// C-070 §4: `month` — rendered verbatim, no case transform (OQ-C-070-2); ignored in `today`.
    let month: String
    /// C-070 §4: `weekday` — rendered verbatim; ignored in `today`.
    let weekday: String
    /// C-070 §4: `day` — rendered verbatim, single line, Bold 18 / 18.
    let day: String
    /// C-070 §4: `state` — selects the §3 row.
    let state: State

    var body: some View {
        // C-070 §2: "a 97×12 label row, gap `space-element-gap` (8), then the day number" —
        // stack 12 + 8 + 18 = 38.
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            labelRow
                .frame(maxWidth: .infinity, minHeight: Self.labelRowHeight,
                       maxHeight: Self.labelRowHeight, alignment: .leading)
                .ui2Element("Label row")
            Text(day)
                .designTextStyle(Self.dayNumberStyle)
                // C-070 §3: day number `color-text-primary` in both states.
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                // C-070 §2's 18pt line box. Framed explicitly: SwiftUI has no line-height, so
                // a single run otherwise sits in its own font box and the stack closes short
                // of 38.
                .frame(maxWidth: .infinity, minHeight: Self.dayNumberHeight,
                       maxHeight: Self.dayNumberHeight, alignment: .leading)
                .ui2Element("Day number")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // C-070 §2 accessibility (R-17): no interactive element, so no trait; "the three texts
        // are read as one element — `default` '<month> <weekday> <day>', `today` 'Today <day>'".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .ui2Element("DateBlock")
    }

    @ViewBuilder
    private var labelRow: some View {
        switch state {
        case .default:
            // C-070 §3 `Default`: "`month` (leading) + `weekday` (trailing, justified to the
            // 97pt edge), both `type-caption-bold` `color-text-secondary`".
            HStack(spacing: 0) {
                Text(month)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    .foregroundColor(Token.textSecondary)
                    .lineLimit(1)
                    .ui2Element("Month")
                Spacer(minLength: 0)
                Text(weekday)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    .foregroundColor(Token.textSecondary)
                    .lineLimit(1)
                    .ui2Element("Weekday")
            }
        case .today:
            // C-070 §3 `Today`: "ONE fixed label \"TODAY\", `type-caption-bold`
            // `color-highlight`; the weekday slot is not rendered".
            Text(Self.todayLabel)
                .designTextStyle(Token.TypeStyle.captionBold)
                .foregroundColor(Token.highlight)
                .lineLimit(1)
                .ui2Element("Today label")
        }
    }

    private var accessibilityText: String {
        switch state {
        case .default: return "\(month) \(weekday) \(day)"
        case .today: return "Today \(day)"
        }
    }

    // C-070 §1 deviation 1: "TODAY" is NOT content — it is the fixed label the `today` state
    // renders; §4 gives the state no string prop.
    private static let todayLabel = "TODAY"

    // C-070 §2: "a 97×12 label row" — `type-caption-bold`'s designed 12pt line box.
    private static let labelRowHeight: CGFloat =
        Token.TypeStyle.captionBold.lineHeight ?? Token.TypeStyle.captionBold.size
    // C-070 §2: the day number's "18pt line box" — the flagged literal's own line height.
    private static let dayNumberHeight: CGFloat =
        dayNumberStyle.lineHeight ?? dayNumberStyle.size

    // FLAGGED LITERAL — C-070 §2: "SF Pro Bold 18 with an 18pt line box (leading-none)";
    // "the program's only Bold 18 token is `type-value-emphasis` 18/**24**; this block designs
    // 18/**18**. Building it at 18/24 would make the block 44pt tall and break C-025's 192pt
    // stack." OQ-C-070-1 (↔ OQ-C-025-3, CLOSED: "Keep the flagged literal") — stays a literal,
    // never promoted to a token.
    private static let dayNumberStyle = DesignTextStyle(
        weight: .bold, size: 18, lineHeight: 18, tracking: 0
    )
}
