//
//  FieldGroup.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-046-field-group.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-046 FieldGroup — one labelled field: a name over its input.
///
/// §2: a two-part vertical stack and no third part — no helper text, no error line, no
/// required marker (§3c records those as undesigned, OQ-C-046-2/-3). Both axes are
/// pass-throughs into C-045 TextInput, which owns every pixel inside the box.
///
/// **OQ-C-046-1 — "a build must pick one", and this build picks the second option.** `style`
/// is contracted as *focus only*, with input content orthogonal to it (`text` / `placeholder`
/// are their own props, per §4's `(input content)` row). That is the reading §6 says "matches
/// C-045's overlay reading of focus and needs no new symbol", and it is the only one under
/// which shared-edit-field's filled-but-unfocused "ready to save" frames are expressible
/// without a third `style` value. The four designed cells are unaffected: §1 deviation 4 has
/// all four symbols sampling empty content, so they render with `text: ""` either way.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no page background and adds no outer padding. Frame, background and outer
/// padding belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct FieldGroup: View {

    /// C-046 §4 `field: Text | Multiline Text` — selects the inner input's line count (§3a).
    /// Raw values are the contract's enumerated values verbatim (preview-build.md §3 rule 5).
    enum Field: String {
        case text = "Text"
        case multilineText = "Multiline Text"
    }

    /// C-046 §4 `style: Default | Focus` — selects the inner input's state (§3a).
    enum Style: String {
        case `default` = "Default"
        case focus = "Focus"
    }

    /// C-046 §4: `label: String`. The field name above the input. Single line.
    let label: String
    /// C-046 §4: `field: Text | Multiline Text`.
    let field: Field
    /// C-046 §4: `style: Default | Focus`.
    let style: Style
    /// C-046 §4 *(input content)* — per C-045 TextInput, deliberately not restated by C-046.
    /// §1 deviation 4: all four symbols sample EMPTY content, so the focused states draw the
    /// placeholder too (C-045 deviation 3 / OQ-C-045-1).
    let text: String
    /// C-046 §4 *(input content)* — per C-045 TextInput. §1 deviation 1 makes the string
    /// itself per-instantiation content, not contract.
    let placeholder: String

    var body: some View {
        // §2: column, leading-aligned, width from the consumer; gap 12 between label and
        // input. Heights are the sum and nothing else — 14 + 12 + 44 = 70 (`Text`), and
        // 14 + 12 + 88 = 114 (`Multiline Text`) — so neither is set here.
        VStack(alignment: .leading, spacing: Self.labelInputGap) {
            labelRow
            // §2: the Input part is C-045 TextInput at the full width of the group. §3a maps
            // both axes onto it one-for-one and nothing else varies.
            TextInput(
                text: text,
                placeholder: placeholder,
                lines: field == .text ? .single : .multi,
                focused: style == .focus
            )
            // §2's anatomy name for the slot. The dependency also names itself, so the
            // element map reports `TextInput` nested inside `Input` by rect containment.
            .ui2Element("Input")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("FieldGroup")                     // capture element map — UI2Element.swift
    }

    private var labelRow: some View {
        Text(label)
            .designTextStyle(Self.labelStyle)
            // §2: `color-text-primary`.
            .foregroundColor(Token.textPrimary)
            // §2: single line, `nowrap`. OQ-C-046-4 records that long labels have no designed
            // overflow at the 196 compact width; SwiftUI's default tail ellipsis is that OQ's
            // proposed default, taken here and reported by the run.
            .lineLimit(1)
            .truncationMode(.tail)
            // §2: the label's designed line box is **14** — the same 14 that makes the group
            // 70 and 114 tall. A 14pt system face lays out in a ~16.7pt font box, so leaving
            // the intrinsic height would silently add ~2.7pt to both totals; the explicit box
            // centres the glyphs in the designed 14, exactly as Figma's 14/14 line box does.
            .frame(maxWidth: .infinity,
                   minHeight: Self.labelLineBox, maxHeight: Self.labelLineBox,
                   alignment: .leading)
            .ui2Element("Label")
    }

    // FLAGGED LITERAL — C-046 §2: "The label's **Bold 14/14** is the program's third Bold-14
    // leading, beside `type-title-card` (Bold 14/20) and `type-nav-label` (Bold 14/16). No
    // token is minted for a single component; OQ-C-046-6 asks for the ruling". Carried as a
    // per-component literal per preview-build.md §3 rule 4 rather than bent onto either
    // neighbouring Bold-14 token — and distinct from `type-body`, which is REGULAR 14/14.
    private static let labelStyle = DesignTextStyle(
        weight: .bold, size: 14, lineHeight: 14, tracking: 0
    )

    /// §2: the label's line box, and the first term of the 70 / 114 sums.
    private static let labelLineBox: CGFloat = 14

    // FLAGGED LITERAL — C-046 §2: "The **12pt label↔input gap** has no row in the spacing
    // family (2 / 4 / 8 / 16 / 24 / 32). Carried as a per-component literal rather than a
    // unilateral token mint — see OQ-C-046-5, which belongs with the program's pending `10`
    // ruling." Same D7 path as C-033's 10pt root gap.
    private static let labelInputGap: CGFloat = 12
}
