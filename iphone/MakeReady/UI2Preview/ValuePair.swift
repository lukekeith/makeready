//
//  ValuePair.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-071-value-pair in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  First built inline inside DayActivityCard.swift (C-025's R-15 fallback, 2026-09-20) and
//  relocated here unchanged by `/d2m-component-merge C-023 C-025` (2026-09-21); rewritten by
//  `/d2m-component-build C-071` so the row has a view, fixture and subject of its own.
//

import SwiftUI

/// C-071 ValuePair — two stacked caption values with a colour-state axis.
///
/// 95×36 in its own symbol, 97 inside C-023 `kind=day` (C-071 §1 deviation 3: "the block is
/// width-driven"), so it takes the width it is given and states a 36pt intrinsic height
/// (R-16). No background, border, padding or corner radius: bare text over the consumer's
/// surface. Where C-025 §3b and this contract differ, this contract wins (its deviation 4:
/// `lessonDay` line 1 is Bold 12/14).
struct ValuePair: View {

    /// C-071 §4 `state` — the seven values of its §3, 1:1 with Figma's `state` axis
    /// (R-06, R-36; OQ-C-071-3 closed: keep 7, do not collapse to 5).
    enum State {
        case `default`
        case nothing
        case muted
        case lessonDay
        case highlighted
        case single
        case singleMuted
    }

    // C-071 §4's rows, one parameter each, in the contract's order (R-05); all required (R-07).
    /// C-071 §4: `line1` — rendered verbatim, single line, no wrap.
    let line1: String
    /// C-071 §4: `line2: String?` — not rendered in `single` / `singleMuted`; a non-nil value
    /// there is ignored (OQ-C-071-3 closed).
    let line2: String?
    /// C-071 §4: `state` — selects the §3 row.
    let state: State

    var body: some View {
        // C-071 §2: "line 1 over line 2 … gap `space-element-gap` (8)"; "Stack: 14 + 8 + 14 = 36".
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            line(line1, style: line1Style, color: line1Color).ui2Element("Line 1")
            if let line2, !isSingle {
                line(line2, style: Token.TypeStyle.caption, color: line2Color).ui2Element("Line 2")
            }
        }
        // C-071 §2 / OQ-C-025-6 (closed: "fixed 36pt height by contract", cited by OQ-C-071-1):
        // the block is 36 tall in all seven states — `single` / `singleMuted` keep the two-line
        // box with the one line at the top and no gap, so day cells align across a rail.
        .frame(maxWidth: .infinity, minHeight: Self.blockHeight, maxHeight: Self.blockHeight,
               alignment: .topLeading)
        .ui2Element("ValuePair")
    }

    private func line(_ text: String, style: DesignTextStyle, color: Color) -> some View {
        Text(text)
            .designTextStyle(style)
            .foregroundColor(color)
            .lineLimit(1)
            // C-071 §2's 14pt line box (`type-caption` is Regular 12/**14**). Framed
            // explicitly: `designTextStyle` spells 14 as lineSpacing, which applies only
            // BETWEEN lines, so a single run would otherwise sit in its own ~12pt font box
            // and the two-line stack would close short of 36.
            .frame(maxWidth: .infinity, minHeight: Self.lineBox,
                   maxHeight: Self.lineBox, alignment: .leading)
    }

    /// C-071 §3: `single` and `singleMuted` are the two states with no line 2. The state wins
    /// over the prop, because it is what §3 designs (OQ-C-071-3).
    private var isSingle: Bool { state == .single || state == .singleMuted }

    // C-071 §2: line 1 is `type-caption` in every state except `lessonDay`.
    private var line1Style: DesignTextStyle {
        state == .lessonDay ? Self.lessonDayLine1Style : Token.TypeStyle.caption
    }

    // FLAGGED LITERAL — C-071 §2 (deviation 4, OQ-C-071-2): `lessonDay`'s line 1 is "SF Pro
    // Bold 12 / 14"; no token carries Bold 12/14 (`type-caption-bold` is Bold 12/**12**,
    // `type-caption` is Regular 12/14). OQ-C-071-2 is CLOSED — "widen type-caption-bold to
    // carry both leadings" — but the register still reads 12/12, so the contract's flag
    // carries until that row is widened; never promoted to a token here.
    private static let lessonDayLine1Style = DesignTextStyle(
        weight: .bold, size: 12, lineHeight: 14, tracking: 0
    )

    // C-071 §3's colour pairs, one row per designed state. Every value is a token by name.
    private var line1Color: Color {
        switch state {
        case .default, .muted, .highlighted, .single: return Token.textPrimary
        // OQ-C-071-3: `singleMuted` takes the `Nothing` line-1 colour, not `Muted`'s.
        case .nothing, .singleMuted: return Token.white20
        case .lessonDay: return Token.accent
        }
    }

    private var line2Color: Color {
        switch state {
        case .default: return Token.positive
        case .nothing: return Token.white20
        case .muted, .lessonDay: return Token.textSecondary
        case .highlighted: return Token.highlight
        // C-071 §3: line 2 is absent in both `single` states — this branch never paints.
        case .single, .singleMuted: return Token.transparent
        }
    }

    // C-071 §2: both lines are `type-caption` line boxes (Regular 12/14) — 14pt tall.
    private static let lineBox: CGFloat =
        Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size

    // C-071 §2: "Stack: 14 + 8 + 14 = 36" — the block's height in every state, from tokens.
    private static let blockHeight: CGFloat = lineBox + Token.Space.elementGap + lineBox
}
