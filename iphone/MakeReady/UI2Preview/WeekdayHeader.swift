//
//  WeekdayHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-114-weekday-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-114 WeekdayHeader — the pinned S M T W T F S letter row over the calendar's seven columns.
///
/// §2 / R-16: fills the width it is given (the full screen width, no side margin) and paints no
/// background; seven equal columns of width / 7, the same column centres as C-115 / C-116.
///
/// §4: `hairline` draws the 1 px `color-white-10` rule under the letters (month mode); `false`
/// omits it (day mode). The letters are not a prop: the fixed Sunday-first week (D9).
struct WeekdayHeader: View {
    let hairline: Bool

    @Environment(\.displayScale) private var displayScale

    /// FLAGGED LITERAL — C-114 §2: letter row "18 pt tall (FLAGGED LITERAL, 02-design §2.3)".
    private static let rowHeight: CGFloat = 18

    /// FLAGGED LITERAL — C-114 §2: "SF Pro **Semibold 10**, `color-white-50` — FLAGGED LITERAL
    /// type (no 10 pt token); fixed size (§10)", so no Dynamic Type scaling.
    private static let letterStyle = DesignTextStyle(
        weight: .semibold, size: 10, lineHeight: nil, tracking: 0
    )

    /// D9: the locale's very-short standalone symbols, Sunday first regardless of locale —
    /// Foundation's array is always Sunday-indexed, so it is taken as-is, never rotated by
    /// `firstWeekday`.
    private static let letters: [String] = Calendar.current.veryShortStandaloneWeekdaySymbols

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .designTextStyle(Self.letterStyle)
                        .foregroundStyle(Token.white50)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ui2Element("Letter \(index + 1)")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .ui2Element("Letter row")

            if hairline {
                // §2: "1 px (`1 / displayScale`) `color-white-10`, full width, directly under
                // the letter row".
                Token.white10
                    .frame(maxWidth: .infinity)
                    .frame(height: 1 / displayScale)
                    .ui2Element("Hairline")
            }
        }
        // §2 Accessibility (R-17): non-interactive; hidden from VoiceOver — every date control
        // already speaks its full weekday (C-113, C-116).
        .accessibilityHidden(true)
        .ui2Element("WeekdayHeader")
    }
}
