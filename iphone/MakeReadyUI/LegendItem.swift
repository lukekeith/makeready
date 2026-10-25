//
//  LegendItem.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-027-legend-item.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-027 LegendItem — "a series dot and its name, one entry of a chart legend".
///
/// §2: "A dot and a word, laid out in a row, centred on each other."
///
/// Chrome-free and content-sized: the row hugs its label (§3b), and its 24pt height IS the
/// label's line box — the dot is centred inside it and sets nothing. Frame, background and
/// outer padding belong to the call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct LegendItem: View {

    /// §4 `color` — the dot's fill, and so the series this entry labels.
    ///
    /// A real colour, not a variant: C-027 §4 states that "`color`'s value set is owned by
    /// `tokens.md`, not by this row", because a legend entry takes the colour of whatever
    /// series it labels. §3a's `color-accent` / `color-white-20` are its two DESIGNED values,
    /// not its range — a third series is a new token, not a new state.
    ///
    /// There is deliberately no variant prop. Figma's two symbols differ in exactly this one
    /// value, and modelling that difference as an axis as well would give one value two
    /// owners (§4, and registry naming rule 6). Figma's own `Property 1` / `Variant2` are
    /// placeholders it auto-assigns; they are recorded in C-027 §1 as evidence and appear
    /// nowhere in this file.
    let color: Color
    /// §4 `label` — the series name. A per-instantiation override: home-dashboard replaces
    /// the set's "Total engagement" with "Scheduled lessons" (§1 deviation 1).
    let label: String
    /// §4 `onTap` — makes the entry tappable. **This component does not define what tapping
    /// does**; the presenting surface does (§3c, owner ruling 2026-09-11). No render effect,
    /// so it is a defaulted no-op here and the promoted view keeps its real signature
    /// (preview-build.md OQ-PB-3).
    var onTap: () -> Void = {}

    var body: some View {
        // §2: "horizontal, `items: center`, gap **8**".
        //
        // FLAGGED LITERAL — C-027 §2: "The **8pt gap and the 8pt dot.** Both are recorded as
        // measured values rather than as `space-element-gap` (8). The gap is hex-equal to it
        // and is genuinely a gap between siblings, so the case for citing the token is
        // stronger here than in C-053 or C-038 — but the *dot diameter* is a size, not a
        // spacing, and naming one and not the other inside a two-part component would be
        // arbitrary." OQ-C-027-4.
        HStack(alignment: .center, spacing: Self.gap) {
            dot
            labelText
        }
        // §3c: the entry is tappable. `onTap` has no render effect, so the gesture changes
        // nothing the capture can see — it is here so the promoted view is the real one.
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // §2: the row is content-hugging on both axes, and its height is the label's line
        // box — pinned on the label below, so the row takes it rather than setting it.
        .ui2Element("LegendItem")     // capture element map — UI2Element.swift
    }

    // §2: "**8×8** circle, fill per variant (§3a). Vertically centred — it sits at y=8 in the
    // 24pt row, 8 above and 8 below." `.center` alignment on the HStack is that centring;
    // the 8/8 split is its result, not a second offset to apply.
    private var dot: some View {
        Circle()
            .fill(color)
            .frame(width: Self.dotSize, height: Self.dotSize)
            .ui2Element("Dot")
    }

    // §2: "SF Pro **Regular 12**, leading **24**, variable `text/navigation` #8d9fa7,
    // `nowrap`."
    private var labelText: some View {
        Text(label)
            .designTextStyle(Self.labelStyle)
            .foregroundColor(Self.labelColor)
            .lineLimit(1)
            .fixedSize()
            // §2: "The height is the label's line box." SwiftUI's lineSpacing does nothing to
            // a single line, so the 24pt box is pinned as a frame — the same construction
            // C-046's Bold-14 label and C-053's pill label use — or the row would come out
            // ~14 tall and the dot would no longer sit at y=8.
            .frame(height: Self.lineBox)
            .ui2Element("Label")
    }

    // FLAGGED LITERAL — C-027 §2: "**The label colour.** Variable `text/navigation` #8d9fa7
    // has **no token row** — `tokens.md` records it only as a near-duplicate of
    // `color-nav-text` (#8ea0a7) and as the hex-twin of `color-nav-border-active`. Cite the
    // variable until the owner consolidates, exactly as `C-029-radial-day-clock.md` §2 does
    // for the hour labels." C-027 is the third text consumer of that variable. OQ-C-027-2.
    //
    // NOT `Token.navBorderActive`, which is the same hex: that token names a BORDER role, and
    // spending it on text would assert a consolidation the owner has not made.
    private static let labelColor = Color(red: 0.5529, green: 0.6235, blue: 0.6549, opacity: 1)

    // FLAGGED LITERAL — C-027 §2: "**The label's type, Regular 12/24.** No row carries it.
    // `type-caption` is Regular 12/**14** and had cited "legends" among its observation
    // sources — an assertion this measurement contradicts, so that citation is withdrawn in
    // `tokens.md`. Not minted off one component, per the same D7 reasoning as C-046's Bold
    // 14/14." The program's first Regular 12/24. OQ-C-027-2.
    private static let labelStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 24, tracking: 0
    )

    /// §2: the label's 24pt line box, which IS the row's height.
    private static let lineBox: CGFloat = 24
    /// §2: the dot's diameter and the row's gap — see the flag on `body`.
    private static let dotSize: CGFloat = 8
    private static let gap: CGFloat = 8
}
