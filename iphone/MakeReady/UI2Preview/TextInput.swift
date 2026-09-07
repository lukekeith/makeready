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
            // §2: Single p16 · Multi px16 — the horizontal inset is 16 in both.
            .padding(.horizontal, Token.Space.cardPadding)
            .padding(.vertical, verticalInset)
            // §2: Single 44pt, content vertically centered · Multi 88pt, content top-aligned.
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: boxAlignment)
            .overlay(
                // §2: Border 1px `color-card-border`; focused: 1px `color-text-primary`.
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(focused ? Token.textPrimary : Token.cardBorder, lineWidth: 1)
            )
    }

    // §2: Single 44pt · Multi 88pt. (OQ-C-045-3's grow-with-content is undesigned and
    // therefore not built — preview-build.md §3 rule 6.)
    private var height: CGFloat { lines == .single ? 44 : 88 }

    private var boxAlignment: Alignment { lines == .single ? .leading : .topLeading }

    // §2: Multi px16 **py9**; Single states only "content vertically centered" inside 44pt,
    // so its vertical inset is the centring, not a padding value.
    //
    // GAP — the 9pt multiline vertical inset has no row in
    // docs/ui2/design-system/tokens.md, so it cannot resolve to a Token member
    // (preview-build.md §3 rule 4). Emitted as C-045 §2's own literal; reported by the run.
    private var verticalInset: CGFloat { lines == .single ? 0 : 9 }

    private var contentRow: some View {
        Text(text.isEmpty ? placeholder : text)
            // §2: Text: Regular 14/24 (`type-input`).
            .designTextStyle(Token.TypeStyle.input)
            // §2: placeholder `color-input-placeholder`, value `color-input-value`.
            .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.inputValue)
            // §2: Single — single line · Multi — wrapping.
            .lineLimit(lines == .single ? 1 : nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                }
            }
    }
}
