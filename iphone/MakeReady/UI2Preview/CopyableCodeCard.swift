//
//  CopyableCodeCard.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-110-copyablecodecard in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-110 CopyableCodeCard — a short code on an accent panel with a trailing copy action.
///
/// Chrome-free and width-driven (R-16): it paints only its own panel, adds no outer padding,
/// and is 56pt tall at the designed content (a 24pt line + 2 × 16pt padding). It performs no
/// side effects (R-04): the caller writes the pasteboard, fires the haptic and drives `copied`.
struct CopyableCodeCard: View {

    /// C-110 §4 `code` — shown verbatim on one line; resolved by the caller (R-19).
    let code: String
    /// C-110 §4 `copied` — `true` shows the "Copied" overlay; caller-owned (R-01), the caller
    /// runs the 1.2 s hold.
    let copied: Bool
    /// C-110 §4 `onCopy` — the copy glyph was tapped (R-03). No render effect; defaulted to a
    /// no-op.
    var onCopy: () -> Void = {}

    /// Ephemeral press feedback only (R-02, OQ-C-110-001).
    @State private var pressed = false

    private enum Geometry {
        // GAP — C-110 §2: "Library glyph `copy` (template), 24×24pt"; no glyph-size token yet.
        // OQ-C-021-4 (owner, 2026-10-20) rules `size-glyph` = 24 — this becomes its member once
        // a spec run lands the row.
        static let glyph: CGFloat = 24
        // GAP — C-110 §2 / deviation 1: "Hit target: 44×44pt centred on the glyph"; no
        // hit-target token yet. OQ-C-021-4 (owner, 2026-10-20) rules `size-hit-target` = 44.
        static let hitTarget: CGFloat = 44
        /// OQ-C-110-001 (owner, 2026-10-20): the copy glyph dims to 0.6 opacity while the
        /// finger is down; the card itself does not change.
        static let pressedOpacity: Double = 0.6
    }

    private enum Motion {
        // FLAGGED LITERAL — C-110 §2 FL-C-110-1: the overlay fades in over 150 ms, ease-in-out
        // (ratified in OQ-invite-qr-007; no motion token holds the value).
        static let overlayIn = Animation.easeInOut(duration: 0.15)
        // FLAGGED LITERAL — C-110 §2 FL-C-110-1: the overlay fades out over 200 ms, ease-in-out
        // (ratified in OQ-invite-qr-007; no motion token holds the value).
        static let overlayOut = Animation.easeInOut(duration: 0.2)
    }

    /// §2 `type-code-display` is Bold 24 / 24: the line box is pinned to the designed 24pt
    /// rather than the font's own taller natural line.
    private static let codeStyle = Token.TypeStyle.codeDisplay
    private static var codeLine: CGFloat { codeStyle.lineHeight ?? codeStyle.size }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Token.Radius.card)        // §2: `radius-card` (8)
    }

    var body: some View {
        HStack(spacing: 0) {
            // §2 Leading — code text (`4654:9339`).
            Text(code)
                .designTextStyle(Self.codeStyle)
                .foregroundStyle(Token.textPrimary)              // deviation 3
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: Self.codeLine)
                .speechSpellsOutCharacters()                     // §4 a11y: read as its characters
                .ui2Element("Code")

            Spacer(minLength: 0)                                 // §2: space-between

            // §2 Trailing — copy glyph (`4654:9342`), the only interactive element.
            Image(GlyphName.copy.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .foregroundStyle(Token.accent)                   // §2: tint `color-accent`
                .opacity(pressed ? Geometry.pressedOpacity : 1)
                // Deviation 1: the 44pt target is an expanded content shape on the 24pt layout
                // frame, so the glyph's right edge stays 16pt from the card's edge.
                .contentShape(Rectangle().inset(by: -(Geometry.hitTarget - Geometry.glyph) / 2))
                .onTapGesture(perform: onCopy)
                .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
                .accessibilityElement()
                .accessibilityLabel("Copy code")                 // §4 a11y (R-17)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onCopy() }
                .ui2Element("Copy glyph")
        }
        .padding(Token.Space.cardPadding)                        // §2: 16 on all four sides
        .frame(maxWidth: .infinity)
        .background(shape.fill(Token.accent20))                  // §2: `color-accent-20`
        .overlay { copiedOverlay }
        .clipShape(shape)                                        // §2: content clips to the corner
        .accessibilityElement(children: .contain)
        .accessibilityValue(copied ? "Copied" : "")              // §4 a11y: announced while copied
        .ui2Element("CopyableCodeCard")
    }

    /// §2 Copied overlay (state `copied`, OQ-invite-qr-003/-007): the card's full bounds and
    /// corner, `color-accent-50`, "Copied" centred in `type-label-emphasis`.
    private var copiedOverlay: some View {
        ZStack {
            shape.fill(Token.accent50)
            Text("Copied")
                .designTextStyle(Token.TypeStyle.labelEmphasis)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .ui2Element("Copied label")
        }
        .opacity(copied ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)                               // the card's value carries it
        .animation(copied ? Motion.overlayIn : Motion.overlayOut, value: copied)
        .ui2Element("Copied overlay")
    }
}
