//
//  KeypadKey.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-108-keypadkey in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-108 KeypadKey — a key on the number keypad.
///
/// A circular, unfilled 64pt cell holding one centred element: a digit as text, or the
/// library's `backspace` glyph for `delete` (§2). Chrome-free: it paints nothing at rest, adds
/// no outer padding, and states its own 64×64 footprint — C-107 NumberKeypad places it.
///
/// Stateless apart from the press feedback (R-01, R-02): `pressed` is ephemeral `@State`
/// (§3 "not a prop"), so the Digit · pressed preview renders at rest — the C-036 / C-082 /
/// C-102 precedent. Performs no side effects (R-04): taps leave through the closures.
struct KeypadKey: View {

    /// §4 `key` (R-06, R-36): which key this is. `*` and `#` are excluded by OQ-C-108-003.
    enum Key: Equatable {
        /// A digit, 0–9.
        case digit(Int)
        case delete
    }

    /// §4 `key` — selects the content and the accessibility label.
    let key: Key
    /// §4 `enabled` (R-34, R-35) — `false` is the disabled state: content at 0.4, no touches.
    var enabled: Bool = true
    /// §4 `onTap` (R-03) — a tap on an enabled key; the caller appends or deletes.
    var onTap: () -> Void = {}
    /// §4 `onLongPress` (R-03) — a long press on an enabled key. Only `delete` uses it
    /// (clears the number, OQ-invite-member-002); a digit key ignores it.
    var onLongPress: () -> Void = {}

    @State private var pressed = false   // feedback only: internal (R-02)

    /// C-108 §2's placed geometry.
    private enum Geometry {
        /// §2: "**Cell:** 64×64 pt, circular" — the key's intrinsic size and its hit area.
        static let cell: CGFloat = 64
        /// §2 + OQ-C-108-004 ruling: "the `backspace` glyph at 28×28pt". No `GlyphSize` case
        /// is 28, so the glyph's imageset is sized here directly.
        static let glyph: CGFloat = 28
        /// §2 + OQ-C-108-002 ruling: "the content (digit or glyph) at 0.4 opacity".
        static let disabledOpacity: Double = 0.4
        /// Not a design value: SwiftUI's own default long-press duration, stated so a digit
        /// key can use 0 (feedback only) beside it. The contract names no duration.
        static let longPressDuration: Double = 0.5
    }

    var body: some View {
        content
            .opacity(enabled ? 1 : Geometry.disabledOpacity)
            .frame(width: Geometry.cell, height: Geometry.cell)
            // OQ-C-108-001 ruling: a `color-white-10` circle fills the cell behind the content
            // while pressed, for digit and delete alike. `radius-circle` ("50%") is NOT PARSED
            // in the token file, so the circle is the shape itself.
            .background(Circle().fill(pressed ? Token.white10 : Token.transparent))
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(
                minimumDuration: key == .delete ? Geometry.longPressDuration : 0,
                perform: { if key == .delete { onLongPress() } },
                onPressingChanged: { pressed = $0 }
            )
            .disabled(!enabled)
            // §2 (R-17): one button element; disabled is conveyed by `.disabled`.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onTap)
            .ui2Element("KeypadKey")
    }

    @ViewBuilder
    private var content: some View {
        switch key {
        case .digit(let value):
            // §2: the digit as text, `type-keypad-digit`, `color-positive`, single line.
            Text(String(value))
                .designTextStyle(Token.TypeStyle.keypadDigit)
                .foregroundStyle(Token.positive)
                .lineLimit(1)
                .fixedSize()
                .ui2Element("Digit")
        case .delete:
            // §2 + OQ-invite-member-002: the `backspace` glyph, tinted `color-positive`.
            Image(GlyphName.backspace.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .foregroundStyle(Token.positive)
                .ui2Element("Backspace glyph")
        }
    }

    private var accessibilityLabel: String {
        switch key {
        case .digit(let value): return String(value)
        case .delete: return "Delete"
        }
    }
}
