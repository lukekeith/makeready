//
//  SuggestionRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-050-suggestion-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-050 SuggestionRow — "one AI-generated suggestion with an add affordance".
///
/// §2: "A horizontal row: **title** (leading, flexible) + **C-021 GlyphButton `add`**
/// (trailing, fixed). Nothing else — no background, no border, no separator (deviation 2)."
/// The inter-row hairline is C-051's, so a row rendered alone shows no line, and that is
/// correct against the source. Chrome-free and width-driven (R-16): it fills the width it
/// is given and states its own height — 56 at one title line, +24 per wrapped line.
struct SuggestionRow: View {

    /// C-050 §4: `title` — "the suggestion text (Figma text prop `title` on the symbol);
    /// wraps per OQ-C-050-2". Required: the design shows no default for it (R-07).
    let title: String
    /// C-050 §4: `onAdd` — "invoked when the suggestion is chosen … Forwarded to C-021
    /// `action`". Interaction-bearing with no render effect, so it is emitted as a defaulted
    /// no-op closure (R-03) and the promoted view keeps its real signature.
    var onAdd: () -> Void = {}

    // FLAGGED LITERAL — C-050 §2: "Vertical padding **16** top and bottom … (The two 16s are
    // flagged literals: no row-padding token exists; they sit on the same scale step as
    // `space-card-padding` / `space-page-margin`.)"
    private static let rowPadding: CGFloat = 16
    // FLAGGED LITERAL — C-050 §2: "Gap title↔glyph **16**" — the second of the two.
    private static let rowGap: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: Self.rowGap) {         // §2: "items centred vertically"
            Text(title)
                // §2: "**Title** (`3526:30717`): `type-input` — SF Pro Regular 14/24 … colour
                // `color-text-primary`." OQ-C-050-4 (ruled 2026-09-19) aliases this value as
                // `type-body`; that row has not landed in the register yet, so the §2 symbol
                // is what generates.
                .designTextStyle(Token.TypeStyle.input)
                .foregroundStyle(Token.textPrimary)
                // §2: "Flexible (`flex 1 0 0`, min-width 1), word-wrapping, no line limit" —
                // OQ-C-050-2 (ruled 2026-09-19): "the title wraps, +24pt per line, no cap and
                // no truncation". The line box is the style's own 24pt leading, so one line
                // makes the row 16 + 24 + 16 = 56 (§2 "Height"); fixedSize sits OUTSIDE the
                // minHeight frame so a wrapped title grows the frame instead of clipping.
                .frame(maxWidth: .infinity, minHeight: Self.lineBox(Token.TypeStyle.input), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .ui2Element("Title")
            // §2: "**Add glyph:** C-021 GlyphButton, `glyph = add` (instance of `3499:27601`),
            // 24×24, does not shrink, tint `color-accent` per C-021 §2." §4: "the trailing
            // glyph is always C-021 `glyph = add`" — fixed, not a prop. C-021 owns the size,
            // the tint and the press highlight (OQ-C-050-1's "system highlight on the glyph
            // only, no row-level highlight").
            GlyphButton(glyph: .add, action: onAdd)
                .fixedSize()
                .ui2Element("Add glyph")
        }
        // §2: "Vertical padding **16** top and bottom; horizontal padding **0** — the row
        // inherits its inset from the parent". Background `color-transparent` = none painted
        // (R-16).
        .padding(.vertical, Self.rowPadding)
        // OQ-C-050-1 (ruled 2026-09-17): "the whole row is the tap target and invokes onAdd;
        // the glyph is the affordance, not the only hit area." A gesture rather than a Button
        // so the row itself shows no press highlight (§3 pressed: "no row-level highlight, no
        // geometry change"); the glyph inside keeps C-021's own.
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
        // R-17: the row is the interactive element (OQ-C-050-1), so it carries the label and
        // the button trait; the glyph inside is the affordance, not a second control.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .ui2Element("SuggestionRow")                              // capture element map — UI2Element.swift
    }

    /// The designed line box of a text style — its leading, or its size when none is designed.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
