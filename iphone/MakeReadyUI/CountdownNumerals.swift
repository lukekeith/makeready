//
//  CountdownNumerals.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-148-countdownnumerals in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-148 CountdownNumerals — the recorder's countdown numeral.
///
/// One large numeral centred in the width it is given (§2, R-16): FL-1 type in
/// `color-text-primary` under the `elevation-countdown-numeral` shadow. It paints no
/// background and adds no padding; its intrinsic height is one 180 pt line. Display-only: the
/// container owns the clock and the beeps, and ticks `value` once per second (R-01, R-04).
struct CountdownNumerals: View {

    /// §4 `phase` — which countdown this is. It selects the accessibility label only; both
    /// phases draw the same numeral (§3, SPEC D4).
    enum Phase {
        case preRoll
        case ending
    }

    /// §4 `value` — the number to show, clamped into 1…10 (§2 Rules). Required (R-07).
    let value: Int
    /// §4 `phase`. Required (R-07).
    let phase: Phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            Text(String(shown))
                .designTextStyle(Self.numeralStyle)
                .monospacedDigit()                       // §1 deviation 1: 10 → 9 does not shift
                .lineLimit(1)
                .fixedSize()                             // §2: never truncated or scaled to fit
                .foregroundStyle(Token.textPrimary)
                .designShadow(Token.Elevation.countdownNumeral)
                .id(shown)
                // §2 Motion: the new numeral fades in; the previous one is removed at once.
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
                .ui2Element("Numeral")
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.numeralStyle.size)           // §2: intrinsic height, one 180 pt line
        .animation(reduceMotion ? nil : Token.Motion.countdownNumeralIn, value: shown)
        // §2 Accessibility: one non-interactive element that updates frequently.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
        .ui2Element("CountdownNumerals")
    }

    // MARK: - Derived

    /// §2 Rules: the recorder never shows 0 or more than 10 (D2, D4).
    private var shown: Int {
        min(max(value, 1), 10)
    }

    /// §2 Accessibility: "Recording starts in <n>" / "Recording ends in <n>".
    private var accessibilityText: String {
        switch phase {
        case .preRoll: return "Recording starts in \(shown)"
        case .ending: return "Recording ends in \(shown)"
        }
    }

    // FLAGGED LITERAL — C-148 §2 FL-1: SF Pro Light 180 / 180, monospaced digits, until a
    // `type-countdown-numeral` row exists on the Typography tab (OQ-C-148-001).
    private static let numeralStyle = DesignTextStyle(weight: .light, size: 180, lineHeight: 180, tracking: 0)
}
