//
//  KPIPickerRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-090-kpi-picker-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  Composes the real C-023 RailCard (`kind: .metric`) and C-021 GlyphButton (`glyph: .add`),
//  both built on their own rows (R-15). The text column between them, `KPIDetailsColumn`, is
//  an inline part of this row by §5 ("not a registry row and not to be minted").
//

import SwiftUI

/// C-090 KPIPickerRow — one KPI offered for adding to Home: its RailCard, its name over a
/// short description, and an `add` plus.
///
/// Width-driven, intrinsic height (R-16, §2): the row fills the width it is given and is 192
/// tall, set by the card. It paints no ground of its own — note 2026-10-06T13:07:44.019Z,
/// "Transparent background card component with the @C-023" — and adds no outer padding.
struct KPIPickerRow: View {

    // C-090 §4's nine flat parameters, in the contract's order (R-05). Required (R-07) except
    // `averageLabel` (C-023 treats it as optional) and `onAdd` (no-op default, R-03).

    /// C-090 §4: `name` — the label, and C-023's `title` (OQ-C-090-003: one prop feeds both).
    let name: String
    /// C-090 §4: `description` — one or two lines, tail-truncated past two; the a11y hint.
    let description: String
    /// C-090 §4: `series` — → C-023 `series`, unchanged; all zeros gives C-023 `empty`.
    let series: [Double]
    /// C-090 §4: `averageLabel` — → C-023 `averageLabel`; nil = average line only.
    var averageLabel: String? = nil
    /// C-090 §4: `value` — → C-023 `value`, formatted by the caller.
    let value: String
    /// C-090 §4: `trendDirection` — C-077 `direction`'s value set, cited not copied.
    let trendDirection: TrendIndicator.Direction
    /// C-090 §4: `trendPolarity` — C-077 `polarity`'s value set, cited not copied.
    let trendPolarity: TrendIndicator.Polarity
    /// C-090 §4: `trendLabel` — → C-023 `trendLabel`, formatted by the caller, never signed.
    let trendLabel: String
    /// C-090 §4: `onAdd` — "fires when the row is tapped **or** the C-021 plus is tapped, and
    /// it fires **once** per tap". No render effect; defaulted no-op (R-03).
    var onAdd: () -> Void = {}

    var body: some View {
        // §4 / §2 "Hit area": the whole row is one tap target. The plus is a Button nested in
        // this one's label, so a tap on it is taken by the plus alone and `onAdd` fires once.
        SwiftUI.Button(action: onAdd) {
            // §2: "A row of three parts, leading to trailing, top-aligned, with gap
            // `space-card-padding` (16) between them."
            HStack(alignment: .top, spacing: Token.Space.cardPadding) {
                // §2 Card: "C-023 RailCard `kind: metric` at its contracted 140×192 … Fixed
                // width; it never stretches." `kind` is not a prop here (§4 "Mapping to C-023").
                RailCard(
                    kind: .metric,
                    title: name,
                    series: series,
                    averageLabel: averageLabel,
                    value: value,
                    trendDirection: trendDirection,
                    trendPolarity: trendPolarity,
                    trendLabel: trendLabel
                )
                .frame(width: Self.cardWidth)
                .ui2Element("Card")

                detailsColumn

                // §2 Plus: "C-021 GlyphButton `glyph: add`: a 24×24 visual at the trailing
                // edge, top-aligned at y 0, not centred" (OQ-C-090-002). C-021 owns its tap
                // area and its colour.
                GlyphButton(glyph: .add, onTap: onAdd)
                    .ui2Element("Plus")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2: "The row's tap area is its full 408×192 bounds, including the transparent
            // gaps."
            .contentShape(Rectangle())
        }
        // §3 `pressed` (OQ-C-090-004, ratified): "the whole row takes the system button
        // highlight (SwiftUI's default plain-button press dimming), with no geometry change".
        // Ephemeral feedback owned by the button, never a prop (R-02).
        .buttonStyle(.plain)
        // §2 Accessibility (R-17): ONE element with the button trait, label "Add «name»", hint
        // «description»; `.ignore` hides the card and C-021's own label so VoiceOver does not
        // announce two "Add" buttons.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add \(name)")
        .accessibilityHint(description)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onAdd() }
        .ui2Element("KPIPickerRow")
    }

    // MARK: - §2 Text column (`KPIDetailsColumn`, inline part)

    private var detailsColumn: some View {
        // §2: "Column, `items: start`, top-aligned with the card (y 0). Gap
        // `space-element-gap` (8) between label and description." Takes all the remaining
        // width (`flex: 1`): row width − 196.
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            // §2 Label: "`type-title-card` (SF Pro Bold 14/20), `color-text-primary`
            // (deviation 2). One line" — OQ-C-090-005: "one line with a tail ellipsis; the
            // description does not move". Framed to the token's 20pt line box, because
            // `designTextStyle` spells leading as lineSpacing, which does nothing to one line.
            Text(name)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: Self.labelLineBox,
                       maxHeight: Self.labelLineBox, alignment: .leading)
                .ui2Element("Label")
            // §2 Description: "`type-body-sm` (SF Pro Regular 14/20), `color-text-secondary`.
            // Wraps to the column width; at most two lines, then a tail ellipsis (deviation 4).
            // Two lines = 40pt." Leading spent as in C-023's title: only the difference between
            // the token's line box and the face's natural line, half above and half below, so
            // each line is exactly 20.
            Text(description)
                .font(Token.TypeStyle.bodySm.font)
                .tracking(Token.TypeStyle.bodySm.tracking)
                .lineSpacing(Self.descriptionLeading)
                .padding(.vertical, Self.descriptionLeading / 2)
                .foregroundColor(Token.textSecondary)
                .lineLimit(Self.descriptionLineCap)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Description")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Text column")
    }

    // MARK: - Geometry (§2)

    // §2 Card: C-023's contracted metric width. A component MEASUREMENT, not a spacing value —
    // the same treatment C-023's own 192pt height gets in RailCard.swift.
    private static let cardWidth: CGFloat = 140
    private static let descriptionLineCap = 2                  // deviation 4

    // §2 Label: the `type-title-card` line box (Bold 14/**20**), from the token's own leading.
    private static let labelLineBox: CGFloat =
        Token.TypeStyle.titleCard.lineHeight ?? Token.TypeStyle.titleCard.size

    // §2 Description: the `type-body-sm` line box less the face's natural line height.
    private static let descriptionLeading: CGFloat = {
        let style = Token.TypeStyle.bodySm
        let natural = UIFont.systemFont(ofSize: style.size, weight: .regular).lineHeight
        return max((style.lineHeight ?? style.size) - natural, 0)
    }()
}
