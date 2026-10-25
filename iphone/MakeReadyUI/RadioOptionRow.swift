//
//  RadioOptionRow.swift
//  MakeReadyUI — the UI 2.0 module
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
    /// §4: `recommended: Bool` (default `false`) — an 18pt `star-filled-carbon` in
    /// `color-amber-400` 10pt after the title. Independent of `selected`; maps to the Figma
    /// `Icon` layer's visibility (shown in `Recommended` `4692:45996`).
    var recommended: Bool = false
    /// §4: `disabled: Bool` (default `false`) — the whole row at 0.4 opacity and `onSelect`
    /// not fired (OQ-C-047-2, owner 2026-09-16). No Figma symbol.
    var disabled: Bool = false
    /// §4: `onSelect: () -> Void` — fired when the row is tapped; the consumer updates its
    /// selection and re-renders the stack. Not fired while `disabled`. Interaction-bearing,
    /// so it has no render effect; emitted as a defaulted no-op so the promoted view keeps
    /// its real signature.
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
        // §3c (OQ-C-047-1, ruled): the whole row is the hit target, and there is no pressed
        // treatment beyond the selection change itself — so a tap gesture on the row's shape
        // rather than a `Button`, whose `.plain` style still dims on press.
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        // §2 Disabled (OQ-C-047-2, ruled): "the whole row — text column, recommended mark
        // and glyph — at 0.4 opacity … the row ignores taps (`onSelect` not fired)".
        .opacity(disabled ? Self.disabledOpacity : 1)
        .allowsHitTesting(!disabled)
        // §2 Accessibility (D28, R-17): the row is the one interactive element — one combined
        // label ("<title>, recommended" when the mark shows, OQ-C-047-001), a button, selected
        // when `selected`, not enabled when `disabled`.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .disabled(disabled)
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
    //   100 = 16 + 20 + 8 + 40 + 16   the sampled two-line description
    //   120 = 16 + 20 + 8 + 60 + 16   the three-line cap — never exceeded (OQ-C-047-3)
    // The recommended mark never changes them (18 < the 20pt title line).
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            titleLine
            if let description {
                Text(description)
                    // §2 Description: "SF Pro Regular 14/20 (`type-page-title`),
                    // `color-text-secondary`, wraps to at most three lines, tail ellipsis
                    // beyond, full column width" (OQ-C-047-3, owner 2026-09-16).
                    // Not `designTextStyle`: its lineSpacing (lineHeight − size = 6) is added
                    // to SF Pro's natural ~16.7 line, a 22.7pt pitch that made the three-line
                    // cap 62.3 tall, not 60. Spend only the line box less the natural line
                    // height — between lines, and half above / half below — so n lines are
                    // exactly n × 20 (same construction as C-023's title / KPIPickerRow).
                    .font(Token.TypeStyle.pageTitle.font)
                    .tracking(Token.TypeStyle.pageTitle.tracking)
                    .lineSpacing(Self.descriptionLeading)
                    .padding(.vertical, Self.descriptionLeading / 2)
                    .foregroundStyle(Token.textSecondary)
                    .lineLimit(Self.descriptionLineCap)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The capture harness measures with `sizeToFit()` on zero bounds, a NUMERIC
                    // height proposal; `fixedSize` makes the text size to its own lines.
                    .fixedSize(horizontal: false, vertical: true)
                    .ui2Element("Description")
            }
        }
        // `flex 1 0 0`: the column takes every point the glyph leaves, and never pushes it.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // §2 Title line: "row, height 20, `items-center`, gap 10 between title and recommended
    // mark; hugs its content (the mark sits right after the text, never trailing-aligned)".
    // §2 Title: "with the mark shown the title truncates first — the mark is never clipped"
    // (OQ-C-047-001): the mark is `fixedSize`, so only the title gives way.
    private var titleLine: some View {
        HStack(alignment: .center, spacing: Self.markGap) {
            Text(title)
                // §2 Title: "SF Pro Regular 14/20 (`type-page-title` face), `color-text-primary`,
                // single line, height 20, nowrap, overflow hidden, ellipsis". `type-page-title`
                // is the program's one Regular 14/20 row (§2's own D7 note).
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .ui2Element("Title")
            if recommended {
                recommendedMark.ui2Element("Recommended mark")
            }
        }
        // A FIXED box: §2 states the title line's height as 20, and a single line never
        // needs to grow past its designed line box.
        .frame(height: Self.lineBox(Token.TypeStyle.pageTitle))
        .frame(maxWidth: .infinity, alignment: .leading)
        // OQ-C-047-001 (ruled 2026-10-24): VoiceOver reads the row as "<title>, recommended".
        .accessibilityElement(children: .combine)
    }

    // §2 Recommended mark: "glyph `star-filled-carbon`, 18×18, `shrink 0`, tinted
    // `color-amber-400`, centred on the 20pt title line". `Glyph` renders only the token
    // scale (16 / 24 / 32), so the library imageset is drawn directly at 18 — the same way
    // ListResultRow draws its 18pt glyphs.
    private var recommendedMark: some View {
        Image(GlyphName.starFilledCarbon.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.markSize, height: Self.markSize)
            .foregroundStyle(Token.amber400)
            .fixedSize()                             // `shrink 0`
            .accessibilityLabel("recommended")
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

    // FLAGGED LITERAL — C-047 §2 (D7): the 10pt title↔mark gap is Figma's measured gap, and
    // the 18pt mark is shape geometry, not a token candidate.
    private static let markGap: CGFloat = 10
    private static let markSize: CGFloat = 18

    // C-047 §2 Description (OQ-C-047-3): "wraps to at most three lines".
    private static let descriptionLineCap = 3

    // FLAGGED LITERAL — C-047 §2 (D7): the disabled 0.4 opacity is the ruling's own value;
    // the token set holds no opacity token (OQ-C-047-2).
    private static let disabledOpacity: Double = 0.4

    /// §2 Description: the `type-page-title` line box (14/**20**) less the face's natural line
    /// height — the leading actually left to spend between and around lines.
    private static let descriptionLeading: CGFloat = {
        let style = Token.TypeStyle.pageTitle
        let natural = UIFont.systemFont(ofSize: style.size, weight: .regular).lineHeight
        return max(lineBox(style) - natural, 0)
    }()

    /// The designed line box of a type token: SwiftUI has no line-height, so the box has to
    /// be spelled as a frame.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
