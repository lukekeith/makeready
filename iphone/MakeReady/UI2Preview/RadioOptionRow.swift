//
//  RadioOptionRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-047-radio-option-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  DEPENDENCIES: none. C-047 §5 consumes nothing from the registry — the 22pt radio
//  glyph (Figma set 3770:6508) is registered INSIDE this row, with exactly one designed
//  host. It is drawn here as shape geometry; if a second consumer appears it is extracted
//  as its own Primitives row and this file repointed (OQ-C-047-4).
//

import SwiftUI

/// C-047 RadioOptionRow — one option in a single-select list: title, optional description,
/// trailing radio glyph.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no background (§2: "no background, no border and no separator") and adds
/// no outer padding. Frame, background and outer padding belong to the ViewRegistry call
/// site. The row is stateless about its siblings — single-select is the consumer's rule
/// (§3c, recorded in `shared-edit-field` §3).
struct RadioOptionRow: View {

    /// §4: `title: String` — the option's name. Single line, ellipsised (§2).
    let title: String
    /// §4: `description: String?` — optional explanatory copy under the title; `nil`
    /// collapses the line and the row to 54pt. Maps to Figma `showDescription`.
    var description: String?
    /// §4: `selected: Bool` — whether this option is the chosen one. Maps to Figma `state`
    /// (`Selected` ↔ `true`, `Default` ↔ `false`).
    let selected: Bool
    /// §4: `onSelect: () -> Void` — fired when the row is tapped; the consumer updates its
    /// selection and re-renders the stack. Interaction-bearing, so it has no render effect;
    /// emitted as a defaulted no-op so the promoted view keeps its real signature.
    var onSelect: () -> Void = {}

    var body: some View {
        // §2 Root: "row, `items-center` … gap 16 between text column and glyph".
        HStack(alignment: .center, spacing: Self.gap) {
            textColumn.ui2Element("Text column")
            glyph.ui2Element("Glyph")
        }
        // §2 Root: "vertical padding 16, horizontal padding 0" — the row is width-driven
        // and its consumer owns the page margin (§1 deviation 2).
        .padding(.vertical, Self.padY)
        .frame(maxWidth: .infinity, alignment: .leading)
        // §3c (OQ-C-047-1 proposed default): the whole row is the hit target, and there is
        // no pressed treatment beyond the selection change itself — so a tap gesture on the
        // row's shape rather than a `Button`, whose `.plain` style still dims on press.
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .ui2Element("RadioOptionRow")               // capture element map — UI2Element.swift
    }

    // §2 Text column: "column, `flex 1 0 0`, `min-width 1`, gap `space-element-gap` (8)
    // between title and description; word-break on the description".
    //
    // The row's height is NOT set anywhere, and deliberately so: §2's three stated heights
    // are "the sum and nothing else", and they fall out of the designed line boxes plus the
    // glyph exactly. Pinning them would hide it if they ever stopped agreeing.
    //   54  = 16 + 22 + 16            title only — the 22pt glyph is taller than the 20pt
    //                                 title box, so the glyph sets the height
    //   80  = 16 + 20 + 8 + 20 + 16   one-line description
    //   100 = 16 + 20 + 8 + 40 + 16   the sampled two-line description; a longer one keeps
    //                                 growing (§1 deviation 5, OQ-C-047-3)
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(title)
                // §2 Title: "SF Pro Regular 14/20 (`type-page-title` face), `color-text-primary`,
                // single line, height 20, nowrap, overflow hidden, ellipsis". `type-page-title`
                // is the program's one Regular 14/20 row (§2's own D7 note).
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                // A FIXED box: §2 states the title's height as 20, and a single line never
                // needs to grow past its designed line box.
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.lineBox(Token.TypeStyle.pageTitle))
                .ui2Element("Title")
            if let description {
                Text(description)
                    // §2 Description: "SF Pro Regular 14/20 (`type-page-title`),
                    // `color-text-secondary`, wraps freely, full column width".
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    // A MINIMUM here, unlike the title: the designed 20pt line box is larger
                    // than SF Pro's natural ~16.7 at 14pt, and a wrapping description has to
                    // be free to grow past it.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Self.lineBox(Token.TypeStyle.pageTitle),
                        alignment: .leading
                    )
                    // §3c (OQ-C-047-3 proposed default): no line cap — unlimited wrap.
                    //
                    // `fixedSize` OUTSIDE the min-height frame, not inside it as C-042's
                    // Multiline value has it. The capture harness measures a component with
                    // `sizeToFit()` on zero bounds, and that zero reaches SwiftUI as a NUMERIC
                    // height proposal: a `minHeight` frame is proposal-driven, so it clamped
                    // 0 → 20 and never asked the text — the sampled two-line description was
                    // drawn on two lines but measured at one, and the row came out 80, not
                    // §2's 100. Out here, `fixedSize` proposes nil to the frame, which then
                    // sizes to the text (clamped to the 20pt line box) whatever the harness
                    // proposes. C-042's sample never wraps, so it never hit this.
                    .fixedSize(horizontal: false, vertical: true)
                    .ui2Element("Description")
            }
        }
        // `flex 1 0 0`: the column takes every point the glyph leaves, and never pushes it.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // §2 Glyph: "22×22, `shrink 0`. Unselected: ring centre (11,11) r10, 2pt stroke
    // `color-text-secondary`, no fill. Selected: the same ring in `color-text-primary` plus
    // a filled dot r7 `color-text-primary`."
    //
    // `strokeBorder` on the 22pt box puts the 2pt stroke's centreline at r10 — inside edge
    // r9, outside edge r11 — which is exactly the ring §2 measures; a centred `stroke` on a
    // 20pt box would draw the same ink but let its outer 1pt spill past the layout box.
    private var glyph: some View {
        ZStack {
            Circle()
                .strokeBorder(selected ? Token.textPrimary : Token.textSecondary, lineWidth: Self.ringStroke)
            if selected {
                Circle()
                    .fill(Token.textPrimary)
                    .frame(width: Self.dotRadius * 2, height: Self.dotRadius * 2)
            }
        }
        .frame(width: Self.glyphSize, height: Self.glyphSize)
        .fixedSize()                                 // `shrink 0`
    }

    // FLAGGED LITERAL — C-047 §2 (D7): the 16pt vertical padding and the 16pt text↔glyph
    // gap are the spacing scale's 16 step (`space-page-margin` / `space-card-padding` both
    // carry it) but neither row is named for row padding; carried as a literal on the scale
    // rather than mis-citing an inset token.
    private static let padY: CGFloat = 16
    private static let gap: CGFloat = 16

    // FLAGGED LITERAL — C-047 §2 (D7): glyph dimensions 22 / r10 / r7 / 2pt stroke are shape
    // geometry, not token candidates.
    private static let glyphSize: CGFloat = 22
    private static let ringStroke: CGFloat = 2
    private static let dotRadius: CGFloat = 7

    /// The designed line box of a type token: SwiftUI has no line-height, so the box has to
    /// be spelled as a frame.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
