//
//  NavTabButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-069-nav-tab-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-069 NavTabButton — one tab of C-019 TopNav: a text label at `expansion` 0, a 124×96
/// card at 1, and §2's morph frames in between.
///
/// The morph is a pure function of `expansion` (§2, R-04): the view holds no timer and no
/// animation, so C-019 can scrub it under a finger and reverse it mid-gesture. Sized by §2
/// itself (label-hugging collapsed, fixed card expanded); it paints no page background and
/// adds no outer padding.
struct NavTabButton: View {

    /// §4 `label` — the tab's name, one of C-019's closed 8.
    let label: String
    /// §4 `expansion` 0…1 (OQ-C-069-001): 0 is the collapsed symbol, 1 the expanded one.
    let expansion: CGFloat
    /// §4 `active` — the selected tab.
    let active: Bool
    /// §4 `hasAdd` = true (R-07: every designed expanded symbol shows the slot; Home passes false).
    var hasAdd: Bool = true
    /// §4 `onTap` — tab tapped; C-019 decides select vs toggle (R-03). No render effect.
    var onTap: () -> Void = {}
    /// §4 `onAdd` — add slot tapped; C-019 routes it to the tab's create list. No render effect.
    var onAdd: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§4 "Pressed is internal").
    @State private var pressed = false

    private enum Geometry {
        // GAP — C-069 §2: "fixed 124×96" expanded card; no size token family.
        static let expandedSize = CGSize(width: 124, height: 96)
        // GAP — C-069 §2: collapsed "height 32 (8+16+8)"; no size token family.
        static let collapsedHeight: CGFloat = 32
        // GAP — C-069 §2: border "1px"; no stroke token.
        static let border: CGFloat = 1
        // GAP — C-069 §2 morph step 1: the outline pill's "radius 16"; `radius-modal` is also 16
        // but names a different role.
        static let pillRadius: CGFloat = 16
        // GAP — C-069 §2: the add slot's "40×40 box"; no size token family.
        static let addSlot: CGFloat = 40
        // GAP — C-069 §2 morph windows (OQ-C-069-002, ratified): outline 0→0.2, growth 0.2→1,
        // disclosure 0.7→1.
        static let outlineEnd: CGFloat = 0.2
        static let disclosureStart: CGFloat = 0.7
    }

    // MARK: - §2 morph windows

    /// Window 2 at `expansion` — exposed so C-019's row grows its height and sheds its inset in
    /// step with its tabs (one owner for the windows).
    static func growth(at expansion: CGFloat) -> CGFloat {
        window(expansion, Geometry.outlineEnd, 1)
    }

    /// §2 height at `expansion`: 32 → 96 across the growth window.
    static func height(at expansion: CGFloat) -> CGFloat {
        Geometry.collapsedHeight
            + (Geometry.expandedSize.height - Geometry.collapsedHeight) * growth(at: expansion)
    }

    /// Window 1, 0 → 0.2: the outline's opacity.
    private var outline: CGFloat { Self.window(expansion, 0, Geometry.outlineEnd) }
    /// Window 2, 0.2 → 1: size, padding, radius and the active fill.
    private var growth: CGFloat { Self.growth(at: expansion) }
    /// Window 3, 0.7 → 1: the add slot's opacity.
    private var disclosure: CGFloat { Self.window(expansion, Geometry.disclosureStart, 1) }

    private static func window(_ expansion: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        let progress = min(max(expansion, 0), 1)
        return min(max((progress - start) / (end - start), 0), 1)
    }

    /// OQ-C-069-003 (ratified): pressed takes the active look — `color-text-primary` label,
    /// `color-nav-tab-background` fill, `color-nav-border-active` border.
    private var lit: Bool { active || pressed }

    /// §2 padding 8 (`space-element-gap`) → 16 (`space-card-padding`), measured inside the 1px
    /// border at the expanded end: the frozen snapshot's label ink sits 16 + 1 from the outer edge.
    private var inset: CGFloat {
        lerp(Token.Space.elementGap, Token.Space.cardPadding + Geometry.border, growth)
    }

    /// §2 corner: the pill's 16 → `radius-card` (8) across the growth window.
    private var radius: CGFloat { lerp(Geometry.pillRadius, Token.Radius.card, growth) }

    // MARK: - Body

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        MorphLayout(growth: growth, inset: inset) {
            labelText
        }
        // §2 fill: none inactive; `color-nav-tab-background` active, fading in over growth.
        .background(shape.fill(Token.navTabBackground).opacity(lit ? growth : 0))
        // §2 border: 1px `color-nav-border` / `color-nav-border-active`, fading in over the outline.
        .overlay(
            shape
                .strokeBorder(lit ? Token.navBorderActive : Token.navBorder, lineWidth: Geometry.border)
                .opacity(outline)
        )
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        // §2 Accessibility (R-17): the tab is one button labelled by `label`.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onTap() }
        // Drawn after the border so the slot sits over it; outside the tab's gestures so the
        // nested button consumes its own tap (§2 Hit areas).
        .overlay(alignment: .bottomTrailing) { addSlot }
        .ui2Element("NavTabButton")
    }

    /// §2 label: `type-nav-label`, single line, never wraps or scales; color only for active.
    private var labelText: some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.navLabel)
            .foregroundStyle(lit ? Token.textPrimary : Token.navText)
            .lineLimit(1)
            .fixedSize()
            // §2: the label box is the style's 16pt line, so 8 + 16 + 8 = 32 collapsed.
            .frame(height: Token.TypeStyle.navLabel.lineHeight)
            .ui2Element("Label")
    }

    /// §2: a 40×40 box anchored bottom-trailing on the card's outer edge, holding C-021
    /// GlyphButton `glyph=add`. OQ-C-069-004: the 40 box stays as drawn; C-021's own 44pt
    /// content shape, centred on it, is the hit area. Fades over window 3 with no layout jump,
    /// and leaves accessibility and hit-testing while invisible.
    @ViewBuilder
    private var addSlot: some View {
        if hasAdd {
            GlyphButton(glyph: .add, onTap: onAdd)
                .frame(width: Geometry.addSlot, height: Geometry.addSlot)
                .opacity(disclosure)
                .allowsHitTesting(disclosure > 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Add to \(label)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onAdd() }
                .accessibilityHidden(disclosure == 0)
                .ui2Element("Add slot")
        }
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        from + (to - from) * t
    }

    /// §2's size table as one layout: width runs from the label-hugging width (label + 2×8)
    /// to 124, height from 32 to 96, and the label stays pinned top-leading at `inset`.
    private struct MorphLayout: Layout {
        let growth: CGFloat
        let inset: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let labelWidth = subviews.first?.sizeThatFits(.unspecified).width ?? 0
            let hugWidth = labelWidth + 2 * Token.Space.elementGap
            return CGSize(
                width: hugWidth + (Geometry.expandedSize.width - hugWidth) * growth,
                height: Geometry.collapsedHeight
                    + (Geometry.expandedSize.height - Geometry.collapsedHeight) * growth
            )
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            subviews.first?.place(
                at: CGPoint(x: bounds.minX + inset, y: bounds.minY + inset),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }
}
