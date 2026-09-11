//
//  TextInput.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-045-text-input.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-045 TextInput — the program's general text input (single and multiline).
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no page background and adds no outer padding. Frame, background and outer
/// padding belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct TextInput: View {

    /// C-045 §4 `lines: single | multi`.
    enum Lines: String {
        case single
        case multi
    }

    /// C-045 §4: `text: String` (empty → placeholder shows).
    let text: String
    /// C-045 §4: `placeholder: String`.
    let placeholder: String
    /// C-045 §4: `lines: single | multi`.
    let lines: Lines
    /// C-045 §4: `focused: Bool` (drives border + caret).
    let focused: Bool

    var body: some View {
        contentRow
            // §2: Single p16 · Multi px16 — the horizontal inset is 16 in both, measured
            // INSIDE the 1px border (see `borderWidth`).
            .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
            .padding(.vertical, verticalInset)
            // §2: Single 44pt, content vertically centered · Multi 88pt, content top-aligned.
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: boxAlignment)
            .overlay(
                // §2: Border 1px `color-card-border`; focused: 1px `color-text-primary`.
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(focused ? Token.textPrimary : Token.cardBorder, lineWidth: Self.borderWidth)
            )
            .ui2Element("TextInput")                  // capture element map — UI2Element.swift
    }

    // §2: Single 44pt · Multi 88pt. (OQ-C-045-3's grow-with-content is undesigned and
    // therefore not built — preview-build.md §3 rule 6.)
    private var height: CGFloat { lines == .single ? 44 : 88 }

    private var boxAlignment: Alignment { lines == .single ? .leading : .topLeading }

    // §2: Border 1px. The border INSETS the content — measured on the frozen snapshot, whose
    // caret (a hard-edged 2×24 rect, so the sharpest ruler in the file) starts at frame + 17
    // horizontally in every symbol, and at frame + 10 vertically in the Multi ones: 1 + 16
    // and 1 + 9, i.e. §2's p16/py9 taken from inside the stroke.
    private static let borderWidth: CGFloat = 1

    // §2: Text: Regular 14/24 — the designed line box the content row occupies.
    private static let lineBox: CGFloat = Token.TypeStyle.input.lineHeight ?? Token.TypeStyle.input.size

    // §2: Multi px16 **py9** (inside the border); Single states only "content vertically
    // centered" inside 44pt, so its vertical inset is the centring, not a padding value —
    // and centring a 24pt line box in 44pt lands it at 10, the same place the Multi inset
    // puts it. The two states' first lines are therefore co-located, as the snapshot shows.
    //
    // GAP — the 9pt multiline vertical inset has no row in
    // docs/ui2/design-system/tokens.md, so it cannot resolve to a Token member
    // (preview-build.md §3 rule 4). Emitted as C-045 §2's own literal; reported by the run.
    private var verticalInset: CGFloat { lines == .single ? 0 : Self.borderWidth + 9 }

    private var contentRow: some View {
        Text(text.isEmpty ? placeholder : text)
            // §2: Text: Regular 14/24 (`type-input`).
            .designTextStyle(Token.TypeStyle.input)
            // §2: placeholder `color-input-placeholder`, value `color-input-value`.
            .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.inputValue)
            // §2: Single — single line · Multi — wrapping.
            .lineLimit(lines == .single ? 1 : nil)
            .fixedSize(horizontal: false, vertical: true)
            // §2: Regular 14/**24** — the glyphs sit centred in a 24pt line box. SwiftUI has
            // no line-height: `designTextStyle` spells 24 as lineSpacing, which is leading
            // applied only BETWEEN lines, so the first line's glyphs otherwise sit at the top
            // of their ~16.7pt font box — ~4pt high, and out of centre with the 24pt caret.
            // Centring the run in an explicit 24pt box restores the half-leading above it.
            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
            // §2 draws one text run whose ROLE changes with `text` — the element map says
            // which, so a comment on it lands on the state it was made about.
            .ui2Element(text.isEmpty ? "Placeholder" : "Value")
            // §2: Caret (focused): 2×24, r2, `color-accent`, leading the content row.
            // An OVERLAY, not a row item: the frozen snapshot's focused and unfocused
            // symbols place the text at the identical x (their ink profiles are equal from
            // the glyph stem on), so the caret sits at the content row's leading edge
            // without displacing content.
            .overlay(alignment: lines == .single ? .leading : .topLeading) {
                if focused {
                    RoundedRectangle(cornerRadius: Token.Radius.bar)
                        .fill(Token.accent)
                        .frame(width: 2, height: 24)
                        .ui2Element("Caret")
                }
            }
    }
}
