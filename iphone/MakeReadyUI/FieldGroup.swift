//
//  FieldGroup.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-046-field-group in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-046 FieldGroup — one labelled field: a name over its input.
///
/// §2: a two-part vertical stack and no third part — no helper text, no error line, no
/// required marker (§3c, ruled by OQ-C-046-2 / -3). `field` and `style` are pass-throughs
/// into C-045 TextInput (`kind`, `focused`), which owns every pixel inside the box; `layout`
/// (D58) is this component's own — it restyles the label, the gap and the input's alignment.
///
/// `style` is focus only, with input content orthogonal to it (OQ-C-046-1): a filled,
/// unfocused field is `style: .default` with a non-empty `text`.
///
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// intrinsic height, paints no page background and adds no outer padding.
struct FieldGroup: View {

    /// C-046 §4 `field: Text | Multiline Text | Phone` — the inner input's `kind` (§3a; Phone
    /// by D58 / OQ-invite-member-007). Raw values are the contract's values verbatim.
    enum Field: String {
        case text = "Text"
        case multilineText = "Multiline Text"
        case phone = "Phone"
    }

    /// C-046 §4 `style: Default | Focus` — focus only (OQ-C-046-1). Figma axis `state`.
    enum Style: String {
        case `default` = "Default"
        case focus = "Focus"
    }

    /// C-046 §4 `layout: Default | Centered` — label face/alignment, gap and input text
    /// alignment (§2; D58). Figma axis `style`.
    enum Layout: String {
        case `default` = "Default"
        case centered = "Centered"
    }

    /// C-046 §4: the field name above the input. Single line, tail ellipsis.
    let label: String
    /// C-046 §4: selects the inner input's `kind`.
    let field: Field
    /// C-046 §4: drives C-045's `focused` overlay.
    let style: Style
    /// C-046 §4: the label's face and alignment, the gap and the input's text alignment.
    let layout: Layout
    /// C-046 §4: passed to C-045 `text`; empty → placeholder shows.
    let text: String
    /// C-046 §4: passed to C-045 `placeholder`.
    let placeholder: String
    /// ui2-members-edit T9e: passed to C-045 `editing` — nil (the default) keeps the static
    /// render every preview and capture uses. Routed to /ui2-resolve (F2).
    var editing: TextInput.Editing? = nil
    /// ui2-members-edit T9e: C-045's `onChange` / `onFocusChange`, forwarded unchanged.
    var onChange: (String) -> Void = { _ in }
    var onFocusChange: (Bool) -> Void = { _ in }

    var body: some View {
        // §2: heights are the sum and nothing else — Default 20 + 12 + 44 / 88 (76 / 120,
        // OQ-C-046-001), Centered 24 + 32 + 44 / 88 (100 / 144) — so none is set here.
        VStack(alignment: isCentered ? .center : .leading, spacing: gap) {
            labelRow
            // §2: the Input part is C-045 TextInput at the full width of the group.
            TextInput(
                text: text,
                placeholder: placeholder,
                kind: kind,
                // §2 / OQ-C-046-004: Centered centres the input text; Phone ignores it.
                alignment: isCentered ? .center : .leading,
                focused: style == .focus,
                onChange: onChange,
                onFocusChange: onFocusChange,
                editing: editing
            )
            // §2's anatomy name for the slot; TextInput nests inside it by rect containment.
            .ui2Element("Input")
        }
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        .ui2Element("FieldGroup")                     // capture element map — UI2Element.swift
    }

    private var isCentered: Bool { layout == .centered }

    /// §3a: `field` → C-045 `kind` one-for-one.
    private var kind: TextInput.Kind {
        switch field {
        case .text: return .single
        case .multilineText: return .multi
        case .phone: return .phone
        }
    }

    /// §2: Default `space-field-gap` (12, OQ-C-046-5 / -002) · Centered `space-section-gap` (32).
    private var gap: CGFloat { isCentered ? Token.Space.sectionGap : Token.Space.fieldGap }

    /// §2: Default `type-title-card` (Bold 14/20, OQ-C-035-3 / OQ-C-046-001) · Centered
    /// `type-value-emphasis` (Bold 18/24).
    private var labelStyle: DesignTextStyle {
        isCentered ? Token.TypeStyle.valueEmphasis : Token.TypeStyle.titleCard
    }

    private var labelRow: some View {
        Text(label)
            .designTextStyle(labelStyle)
            // §2: `color-text-primary` in both layouts.
            .foregroundColor(Token.textPrimary)
            // §2 / OQ-C-046-4: single line, tail ellipsis at every width.
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(isCentered ? .center : .leading)
            // §2: the label's line box (20 / 24) is the first term of the height sums. A
            // single line lays out in its font box, shorter than the line height, so the
            // explicit box restores the half-leading above and below the glyphs.
            .frame(maxWidth: .infinity,
                   minHeight: labelLineBox, maxHeight: labelLineBox,
                   alignment: isCentered ? .center : .leading)
            .ui2Element("Label")
    }

    private var labelLineBox: CGFloat { labelStyle.lineHeight ?? labelStyle.size }
}
