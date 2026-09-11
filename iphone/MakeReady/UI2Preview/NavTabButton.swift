//
//  NavTabButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-019-top-nav.md §2b — which IS registry
//  row C-069's contract (§4 props, §3 states). PREVIEW ONLY: referenced by no screen,
//  route, tab or flag (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell
//  suite (§7).
//
//  C-069 has no contract FILE of its own, so it is not a legal `/ui2-component-build`
//  target (that command's phase 0.3) and is built here, inside its only consumer's run.
//  It is a top-level type rather than a private view inside TopNav.swift because C-019 §3
//  gives it four fixture states of its own that ViewRegistry has to construct directly —
//  a private type could not serve them — and because it is a named registry row, so §2's
//  plain naming and §7's zero-rename promotion apply to it exactly as to any other row.
//

import SwiftUI

/// C-069 NavTabButton — one tab of the C-019 row, in either presentation.
///
/// Chrome-free and intrinsically sized: collapsed is label-driven (58×32 at the "Home"
/// sample), expanded is the fixed 124×96 card. Frame, background and outer padding belong
/// to the call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct NavTabButton: View {

    /// C-019 §4 `presentation` {collapsed, expanded}. §1 deviation 1: the two Figma sets
    /// disagree on the axis name for the same presentation (the row says `state=Default`);
    /// the contract uses collapsed/expanded throughout, and so does this.
    enum Presentation: String {
        case collapsed
        case expanded
    }

    /// C-019 §4 (C-069): `label`.
    let label: String
    /// C-019 §4 (C-069): `presentation`.
    let presentation: Presentation
    /// C-019 §4 (C-069): `active` — §2b's active delta.
    let active: Bool
    /// C-019 §4 (C-069): `addAction?` — the expanded card's add slot. The action itself
    /// carries no render effect (OQ-PB-3), but its PRESENCE is what §2b gates the slot on,
    /// which is why it is an optional closure and not a defaulted no-op.
    var addAction: (() -> Void)?

    // §2b collapsed: "padding 8 on all sides … height 32 = 8 + 16 + 8".
    //
    // GAP — the 8pt tab padding has no row in docs/ui2/design-system/tokens.md, so it
    // cannot resolve to a Token member by name (preview-build.md §3 rule 4). The spacing
    // family is 16/16/8/32/4/2/24, and its only 8 is `space-element-gap` — the row's GAP
    // token (§2), a different role. Emitted as C-019 §2b's own literal; reported by the run.
    private static let collapsedPadding: CGFloat = 8
    // §2b: height 32.
    private static let collapsedHeight: CGFloat = 32
    // §2b expanded: "124×96 card".
    private static let expandedSize = CGSize(width: 124, height: 96)
    // §2b: the add slot's "40×40 hit area".
    private static let addSlotSize: CGFloat = 40
    // §2b: "1px solid border".
    private static let borderWidth: CGFloat = 1

    var body: some View {
        presentedTab
            .ui2Element("NavTabButton (\(label))")     // capture element map — UI2Element.swift
    }

    @ViewBuilder
    private var presentedTab: some View {
        switch presentation {
        case .collapsed: collapsedTab
        case .expanded: expandedTab
        }
    }

    // §2b: label `type-nav-label` (SF Pro Bold 14/16). "The active delta is color only —
    // no pill, no underline, no weight or size change."
    private var labelText: some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.navLabel)
            .foregroundColor(active ? Token.textPrimary : Token.navText)
            .lineLimit(1)
            .fixedSize()
            .ui2Element("Label")
    }

    // §2b collapsed: padding 8 all sides, height 32, width label-driven.
    private var collapsedTab: some View {
        labelText
            .padding(Self.collapsedPadding)
            .frame(height: Self.collapsedHeight)
    }

    // §2b expanded: 124×96 card, `radius-card` (8), `padding` `space-card-padding` (16),
    // 1px solid border, label pinned top-left (`items: start`).
    //
    // §2b's `gap: 10` between label and add slot is deliberately NOT emitted: the add slot
    // is absolutely positioned, so the gap has no layout effect (recorded, not tokenized —
    // OQ-C-019-7).
    private var expandedTab: some View {
        labelText
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // §2b: `padding` `space-card-padding` (16), measured INSIDE the 1px border —
            // which is what the add slot's own "-1 … so it aligns to the card's outer edge
            // over the 1px border" is compensating for: the slot has to be pulled back out
            // of a content box the stroke already inset. Measured on the frozen snapshot:
            // the label's ink sits at 18pt from the card's outer edge, 16 + 1 + bearing.
            .padding(Self.borderWidth + Token.Space.cardPadding)
            .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
            .background(
                // §2b: `active=false` → no fill (shows `color-layout-background`);
                // `active=true` → `color-nav-tab-background`.
                RoundedRectangle(cornerRadius: Token.Radius.card)
                    .fill(active ? Token.navTabBackground : Token.transparent)
            )
            .overlay(
                // §2b: border `color-nav-border` → active `color-nav-border-active`.
                RoundedRectangle(cornerRadius: Token.Radius.card)
                    .strokeBorder(active ? Token.navBorderActive : Token.navBorder,
                                  lineWidth: Self.borderWidth)
            )
            .overlay(alignment: .bottomTrailing) { addSlot }
    }

    // §2b: a 40×40 hit area "anchored to the card's bottom-right, offset -1 on both axes so
    // it aligns to the card's outer edge over the 1px border", containing C-021 GlyphButton
    // `glyph=add` at 24pt in `color-accent`. Anchoring the slot to the card's OUTER frame is
    // that construction's result — the -1 is how Figma expresses it against an inset stroke,
    // not a second offset to apply on top. Drawn after the border overlay, so it sits over it.
    //
    // Its 40pt box is smaller than C-021's stated 44pt hit target — OQ-C-019-3.
    @ViewBuilder
    private var addSlot: some View {
        if let addAction {
            GlyphButton(glyph: .add, action: addAction)
                .frame(width: Self.addSlotSize, height: Self.addSlotSize)
                .ui2Element("Add slot")
        }
    }
}
