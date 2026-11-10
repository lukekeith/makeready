//
//  ChipStrip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-106-chip-strip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-106 ChipStrip — "Generic horizontally scrolling strip of chips with a selected chip scrolled
/// into view; used for fonts and animation/effects." (the owner's description).
///
/// §2: one horizontal row of C-035 FilterChip inside a horizontal scroll container the full width
/// of the strip. Nothing else is drawn — no title, divider, indicator, edge fade or fill
/// (deviation 1). Width-driven, intrinsic height 8 + 36 + 8 = 52 (R-16).
///
/// §3 `fit` is derived from the width and `items`, never a prop: the same props fit at ≥ 421pt
/// and overflow below it.
struct ChipStrip: View {

    /// §4 `items` element (R-36, nested model type).
    struct Item {
        /// Stable key — C-092's `font` case names, or an animation/effect value (`none` first).
        let id: String
        /// The chip's text.
        let label: String
        /// §4 `font: C-092 font? = nil` — the face the label is set in; the value set is C-092's.
        let font: CanvasTextObject.Font?

        init(id: String, label: String, font: CanvasTextObject.Font? = nil) {
            self.id = id
            self.label = label
            self.font = font
        }
    }

    /// §4 #1 — the chips, in order; never empty. Required (R-07).
    let items: [Item]
    /// §4 #2 — the `id` of the chip drawn selected. Required (R-07).
    let selectedID: String
    /// §4 #3 — a chip tap with the tapped item's `id`. No render effect; no-op default (R-03).
    var onSelect: (String) -> Void = { _ in }
    /// OQ-activities-editor-46 (owner, 2026-11-09; activities-editor §15.1 D29): the dark blur
    /// material behind each chip, for a strip floating over a canvas. Defaults off — every other
    /// strip draws exactly as before.
    var chipMaterial: Bool = false

    /// The strip's measured width — layout only, never a prop (R-02). C-106 §2 (D34): the row
    /// is centred when it fits, so it is laid out at least as wide as the inset content area.
    @State private var stripWidth: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            HorizontalRail(showsIndicators: false) {
                // §2 Chip row (owner ruling 2026-11-10, D34): centred when its content fits the
                // width, leading-aligned (and scrolling) when it overflows. Gap
                // `space-element-gap`; chips vertically centred on the row's line (a 34pt filled
                // chip centres in the 36 line).
                HStack(alignment: .center, spacing: Token.Space.elementGap) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        chip(item)
                            .id(item.id)
                            .ui2Element("Chip \(index + 1)")
                    }
                }
                // §2: "vertical inset `space-element-gap` (8) above and below".
                .padding(.vertical, Token.Space.elementGap)
                // §2 (D34): at least the content area's width (the strip minus its two 16pt
                // insets), centred in it — a fitting row centres; an overflowing row is wider
                // than this minimum, so it starts at the leading inset and scrolls.
                .frame(
                    minWidth: max(stripWidth - 2 * Token.Space.pageMargin, 0),
                    alignment: .center
                )
                .ui2Element("Chip row")
            }
            // §3: "a row that fits does not scroll" — bounce only when the content overflows.
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // §2 Scroll container: the 16pt insets are SCROLL-CONTENT insets — under overflow the
            // chips pass beneath the edge; they are not outer padding on the strip. Content
            // margins (not padding) so `scrollTo` keeps the selected chip inside them.
            .contentMargins(.horizontal, Token.Space.pageMargin, for: .scrollContent)
            // §3 Behaviour: on first appearance the selection is scrolled into view unanimated
            // (re-opening a strip shows its selection); after that, every `selectedID` change.
            .onAppear { scrollToSelected(proxy, animated: false) }
            .onChange(of: selectedID) { scrollToSelected(proxy, animated: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stripWidth = $0 }
        // R-17: the strip is a horizontal scroll group; each chip's label and selected trait are
        // C-035's.
        .accessibilityElement(children: .contain)
        .ui2Element("ChipStrip")
    }

    /// §4 mapping to C-035 per item (re-specced 2026-10-10, OQ-C-106-001 owner).
    private func chip(_ item: Item) -> some View {
        FilterChip(
            type: .font,
            active: item.id == selectedID,
            label: item.label,
            // OQ-C-106-004 (owner, 2026-10-13): a nil-font item renders `sans`, so both strips
            // share one chip look and stay 52 tall.
            font: item.font ?? .sans,
            // C-035 names its Font-type action `onSelect`, not `onTap`.
            onSelect: { onSelect(item.id) }
        )
        .background {
            if chipMaterial {
                // FLAGGED LITERAL — activities-editor §15.1: the system dark ultra-thin material
                // (no `material` token family), in C-035's `radius-card` shape.
                RoundedRectangle(cornerRadius: Token.Radius.card)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
        }
    }

    /// OQ-C-106-002 (owner): the selected chip is scrolled the MINIMUM distance into full view —
    /// `scrollTo` with no anchor — and nothing moves if it is already visible; never centred.
    private func scrollToSelected(_ proxy: ScrollViewProxy, animated: Bool) {
        guard items.contains(where: { $0.id == selectedID }) else { return }
        if animated {
            // OQ-C-106-005 (owner): `motion-chip-select`, ≈ 150 ms ease-out.
            withAnimation(Token.Motion.chipSelect) { proxy.scrollTo(selectedID) }
        } else {
            proxy.scrollTo(selectedID)
        }
    }
}
