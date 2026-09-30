//
//  FilterChip.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-035-filter-chip.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-035 FilterChip — "a 24pt pill whose label is the filter's current selection".
///
/// Chrome-free and width-driven in the sense §2 means it: the chip **hugs its label**
/// (§3b "Width is not a variant" — 70 and 48 are what the sample label "Now" measures in
/// each type, and the eight consumed instances run 83–117 on their real labels with no other
/// change). It paints no page background and adds no outer padding; the frame, background and
/// outer padding belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
///
/// Two axes, four designed variants (§3a). `type=Menu` is a bordered, chevroned selector that
/// presents C-036; `type=Button` is a chevron-less pill that draws **no border** and, when
/// inactive, no ground at all (§1 change-list item 5 — the registry's "24pt pill, 1px border"
/// reading holds for `type=Menu` only).
struct FilterChip: View {

    /// C-035 §4 `type: Menu | Button` — "selects the presentation… carried verbatim from the
    /// source axis". The source's own axis values, capitalised as the source spells them
    /// (§1's symbol table); the fixture's Data tab enumerates exactly these two.
    enum ChipType: String {
        case menu = "Menu"
        case button = "Button"
    }

    /// C-035 §4 `type`.
    let type: ChipType
    /// C-035 §4 `active: Bool` — "selects the active treatment within the chosen `type` (§3a)".
    /// §4: "`active` was not in the prior contract and is not optional to model: three of the
    /// four designed variants are unreachable without it."
    let active: Bool
    /// C-035 §4 `label: String` — "the chip's text. In `type=Menu` this is **the filter's
    /// current selection**, not a static name — every consumption overrides the sample 'Now'."
    let label: String

    /// C-035 §4 `onTap: () -> Void` — "`type=Menu` presents C-036 FilterMenuOverlay;
    /// `type=Button`'s action is undesigned (OQ-C-035-5). No render effect." Emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3's default).
    let onTap: () -> Void

    init(
        type: ChipType,
        active: Bool,
        label: String,
        onTap: @escaping () -> Void = {}
    ) {
        self.type = type
        self.active = active
        self.label = label
        self.onTap = onTap
    }

    // MARK: - Geometry (§2)

    private enum Geometry {
        /// §2: "height **24**, width content-driven".
        static let height: CGFloat = 24
        /// §2 Pill: "**px 8**".
        ///
        /// FLAGGED LITERAL — C-035 §2: "**The px 8 inset and the 4pt gap.** Recorded as
        /// measured values rather than `space-element-gap` (8) and `space-meta-gap` (4). The
        /// gap is a true sibling gap and hex-equal to `space-meta-gap`; the inset is a pill
        /// inset, the case C-053 §2 and C-038 §2 both flag. Carried together for the same
        /// reason C-027 §2 gives: naming one and not the other inside a two-part component
        /// would be arbitrary."
        static let horizontalInset: CGFloat = 8
        /// §2 Pill: "`type=Menu` adds gap **4**; `type=Button` has no gap because it has one
        /// child". Same flagged literal as the inset above.
        static let menuGap: CGFloat = 4
        /// §2 Chevron: "**16×16**, leading".
        static let chevronBox: CGFloat = 16
        /// §3a: `type=Menu` carries a 1px border in both `active` values — visible
        /// `color-neutral-600` when inactive, invisible white when active (§1 deviation 3).
        static let borderWidth: CGFloat = 1
    }

    // MARK: - Variant resolution (§3a's closed matrix)

    /// §3a Ground: `Menu/false` none · `Menu/true` `color-text-primary` (white) ·
    /// `Button/false` none · `Button/true` `color-neutral-800`.
    ///
    /// §2 records the role mismatch this spends: "`Color/Base/White` is bound here as a
    /// **fill**, where `tokens.md` carries that white only as `color-text-primary` — the same
    /// variable-role mismatch C-038 found with `Border`" (OQ-C-035-4b). The token is used by
    /// name anyway; the mismatch is the owner's to consolidate, not this build's to work around.
    private var ground: Color {
        switch (type, active) {
        case (.menu, true): return Token.textPrimary
        case (.button, true): return Token.neutral800
        default: return .clear
        }
    }

    /// §3a Border: `Menu/false` 1px `color-neutral-600` · `Menu/true` 1px white, invisible ·
    /// both `Button` rows none.
    ///
    /// §1 deviation 3: "`active=true, type=Menu` carries a 1px border in `Color/Base/White`
    /// over a `Color/Base/White` fill — a border that cannot be seen, on the variant whose
    /// ground is the same colour. Vestigial… stated here because it is in the source, not
    /// because it renders." It is drawn rather than dropped because §3a's matrix lists it, and
    /// dropping it would make the active pill 2pt narrower than the 70 §3a states.
    private var border: Color? {
        switch type {
        case .menu: return active ? Token.textPrimary : Token.neutral600
        case .button: return nil
        }
    }

    /// §3a Chevron: `color-text-secondary` inactive, `color-black` active; `type=Button` has
    /// none.
    private var chevronColor: Color { active ? Token.black : Token.textSecondary }

    /// §3a Label colour: `color-black` in `Menu/true`, `color-text-primary` in `Button/true`,
    /// and the flagged `text/navigation` literal in both inactive rows.
    private var labelColor: Color {
        switch (type, active) {
        case (.menu, true): return Token.black
        case (.button, true): return Token.textPrimary
        default: return Self.navigationTextColor
        }
    }

    /// §3a Label type: Bold 14/**22** in `type=Menu`, Bold 14/**24** in `type=Button`.
    private var labelStyle: DesignTextStyle {
        type == .menu ? Self.menuLabelStyle : Self.buttonLabelStyle
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: type == .menu ? Geometry.menuGap : 0) {
            // §2: the chevron is `type=Menu` only.
            if type == .menu { chevron }
            labelText
        }
        // §2 measures the px 8 from INSIDE the border, not from the pill's outer edge: "1 + 8 +
        // 16 + 4 + 32 + 8 + 1 = **70**, the two 1s being the border, which is why the chevron
        // sits at x=9 and not x=8." So a bordered type insets by 9 and an unbordered one by 8 —
        // which is also why `type=Button`, drawing no border, measures 8 + 32 + 8 = 48.
        // (Measured on the first capture: padding a flat 8 made the Menu chip 66.67 and put the
        // chevron at x=8.) The border still draws INSIDE the 24pt height, as every symbol is 24.
        .padding(.horizontal, Geometry.horizontalInset + (border == nil ? 0 : Geometry.borderWidth))
        .frame(height: Geometry.height)
        // §2: "`radius-card` (8)" — the pill is a rounded rect, not a capsule: an 8pt radius
        // on a 24pt height leaves 8pt of straight edge top and bottom, which the snapshot shows.
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card).fill(ground)
        )
        .overlay(
            // `strokeBorder`, not `stroke`: the border is drawn INSIDE the 70/48 width §2
            // measures, which is what makes its arithmetic close ("1 + 8 + 16 + 4 + 32 + 8 + 1
            // = 70, the two 1s being the border, which is why the chevron sits at x=9 and not
            // x=8").
            border.map { colour in
                RoundedRectangle(cornerRadius: Token.Radius.card)
                    .strokeBorder(colour, lineWidth: Geometry.borderWidth)
            }
        )
        .ui2Element("FilterChip")
    }

    // MARK: - Parts (§2 anatomy)

    /// §2 Chevron: "**16×16**, leading. Fill baked into the artwork: `color-text-secondary`
    /// inactive, `color-black` active (§1 deviation 4)."
    ///
    /// The source ships **two** assets — the same path filled `#85979E` and `black` (§1
    /// deviation 4, verified on export 2026-09-11 from nodes `3668:7602` / `3668:7610`: the two
    /// SVGs are byte-identical but for the `fill` attribute). One asset is catalogued here,
    /// template-rendering, and the fill is applied as a token at this call site — exactly the
    /// accommodation C-072 LinkStatusGlyph makes for its own baked-fill pair, and what keeps
    /// §3a's two chevron colours **tokens by name** (preview-build.md §3 rule 4) instead of
    /// hexes frozen into a vector.
    ///
    /// Exported 2026-09-11 from `3668:7602` ("chevron--down", 16×16 at x=9 y=4 in the symbol)
    /// to docs/ui2/design-system/components/assets/C-035-chevron-down.svg.
    private var chevron: some View {
        Image(Self.chevronAsset, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            // The vector is 10×5.7 inside the 16×16 instance box (measured on the node:
            // origin 3, 5.3). Rendering the ARTWORK at its own size and the BOX as a frame
            // keeps §2's 16×16 slot while drawing the chevron at the weight the source draws
            // it — the same two-frame construction C-072 uses. The box centres it at
            // (3, 5.15) against the source's (3, 5.3): 0.15pt low, below a 3× render's
            // resolution and not worth an offset.
            .frame(width: Self.chevronArtwork.width, height: Self.chevronArtwork.height)
            .foregroundColor(chevronColor)
            .frame(width: Geometry.chevronBox, height: Geometry.chevronBox)
            .ui2Element("Chevron")
    }

    /// §2 Label: "SF Pro **Bold 14**; leading **22** in `type=Menu`, **24** in `type=Button`;
    /// colour per variant (§3a); `nowrap`."
    private var labelText: some View {
        Text(label)
            .designTextStyle(labelStyle)
            .foregroundColor(labelColor)
            // §2: `nowrap`. §3c's proposed default for overflow is that "the chip does not
            // truncate and the rail scrolls" (OQ-C-035-6), so no truncation is applied here —
            // the chip hugs whatever the label measures.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            // The label's line box IS its leading (measured: the Menu label node is 32×**22**
            // at y=1 in the 24pt symbol, the Button label 32×**24** at y=0). Without the frame
            // SwiftUI sizes the run to the font's own line height and the two types stop
            // differing, which is precisely what §2's "two leadings, one component" records.
            .frame(height: labelStyle.lineHeight ?? labelStyle.size)
            .ui2Element("Label")
    }

    // MARK: - Flagged literals (§2)

    // FLAGGED LITERAL — C-035 §2: "**The label colour in the two inactive variants.** Variable
    // `text/navigation` #8d9fa7 has **no token row** — `tokens.md` records it only as a
    // near-duplicate of `color-nav-text` (#8ea0a7) and as the hex-twin of
    // `color-nav-border-active`. Cite the variable until the owner consolidates, as
    // `C-029-radial-day-clock.md` §2 and `C-027-legend-item.md` §2 do." C-035 is the third
    // text consumer of that variable, and §2 records that the "members-home Bold 14/22 label"
    // consumer `tokens.md` already carried **is this row**. OQ-C-035-4a.
    //
    // NOT `Token.navBorderActive`, which is the same hex: that token names a BORDER role, and
    // spending it on text would assert a consolidation the owner has not made.
    private static let navigationTextColor = Color(
        red: 0.5529, green: 0.6235, blue: 0.6549, opacity: 1
    )

    // FLAGGED LITERAL — C-035 §2: "**Both label leadings.**… The Menu label is Bold 14/**22**
    // and the Button label is Bold 14/**24** — same face, same size, same weight, differing by
    // variant axis alone. Bold 14/24 is already on file from C-062 (this is its second site);
    // Bold 14/**22** is **new to the program**, which now carries five Bold-14 leadings: 14
    // (C-046), 16 (`type-nav-label`), 20 (`type-title-card`), 22 (here), 24 (C-062 + here).
    // Neither is minted as a token off this component." OQ-C-035-3, to settle with OQ-C-062-3
    // and OQ-C-046-6 as one typography ruling.
    private static let menuLabelStyle = DesignTextStyle(
        weight: .bold, size: 14, lineHeight: 22, tracking: 0
    )
    private static let buttonLabelStyle = DesignTextStyle(
        weight: .bold, size: 14, lineHeight: 24, tracking: 0
    )

    /// §1 deviation 4's artwork, and the size the vector occupies inside §2's 16×16 box.
    private static let chevronAsset = "c035-chevron-down"
    private static let chevronArtwork = CGSize(width: 10, height: 5.7)
}
