//
//  DateSpanIndicator.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-064-date-span-indicator.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  ARTWORK: C-075's two vectors (§5a) are carried in Resources/Glyphs.xcassets under the
//  `c075-` prefix, `original`-rendered because their fill is baked in — the same carriage
//  C-072 and C-074 use. A raw .svg in a bundle is not loadable; the catalog is the only way
//  iOS renders these.
//

import SwiftUI

/// C-064 DateSpanIndicator — "the length of a scheduled range, read out between two arrows".
///
/// §2: "A fixed 184×88 box holding one horizontal band: an arrow, two value+label pairs, an
/// arrow. No fill, no border, no shadow, no label of its own."
///
/// The component states its own footprint, so the ViewRegistry call site fixes no width — it
/// supplies the outer margin and the ground only, as C-052 DayChip's does. The 184×88 is
/// §2's flagged literal, not a token; see `frameWidth` below.
struct DateSpanIndicator: View {

    /// C-064 §4 `months: Int` — "the whole months in the span — the leading pair's value".
    let months: Int
    /// C-064 §4 `days: Int` — "the remaining days in the span — the trailing pair's value".
    let days: Int

    /// §3a: "**Interaction.** No pressed, hover, focus or disabled symbol, and no action in
    /// the source. The arrows read as decoration, not controls … Proposed default:
    /// **non-interactive**, the whole component a read-out." So there is no interaction-bearing
    /// prop here and preview-build.md OQ-PB-3 does not arise — the same as C-022 MetaPair.
    var body: some View {
        band
            // §2: "Root | 184×88 **fixed**". Set on the component, not on the call site,
            // because it is the component's own designed footprint (deviation 5: "The 88 and
            // the 184 **are** set") rather than a sheet's master width like C-045's 387.
            .frame(width: Self.frameWidth, height: Self.frameHeight)
            // §1 deviation 4: "The root carries a `radius-card-sm` (4) with no fill and no
            // border — no visual effect. Vestigial." Nothing is drawn for it, the same way
            // C-022's root carries one and draws nothing.
            .ui2Element("DateSpanIndicator")          // capture element map — UI2Element.swift
    }

    // §2: "Content band | 162×24 — the four slots plus three 8pt gaps — centred, leaving 11
    // left / 11 right and **32 above / 32 below**." The band measures its content; the slack
    // is what the 184×88 frame above leaves around it, not padding this stack applies.
    private var band: some View {
        HStack(alignment: .center, spacing: Self.bandGap) {
            ArrowGlyph(direction: .left)
                .ui2Element("Leading arrow")
            pair(value: months, label: "months")
                .ui2Element("Months pair")
            pair(value: days, label: "days")
                .ui2Element("Days pair")
            ArrowGlyph(direction: .right)
                .ui2Element("Trailing arrow")
        }
        .ui2Element("Content band")
    }

    /// §5: "**C-022 MetaPair** ×2 — `layout=inline`, `align=Left`, rendering Regular 12/24 with
    /// a white value and a `color-text-secondary` label."
    ///
    /// **The real C-022, with the divergence §5 predicts.** "Figma has these as local frames at
    /// gap **2**, where C-022 §2 measures **4** (§1 change 3, OQ-C-064-3). A build that renders
    /// real C-022 instances here comes out 4pt wider than the source until that is ruled on."
    /// Building local runs at gap 2 instead would match the picture while silently contradicting
    /// §5's composition claim, and would hide exactly the measurement OQ-C-064-3 is asking about
    /// — so the real row is composed and the 4pt is surfaced in the diff. C-022 owns its own gap
    /// (it takes no gap prop), so there is nothing to pass here.
    ///
    /// §4: "**The labels 'months' and 'days' are not props.** They are fixed by the component's
    /// role." §3a's pluralisation proposal is NOT built: "Zero, singular and absent units" are
    /// undesigned and OQ-C-064-5 is still open, so building the proposed pluraliser would invent
    /// the ruling its OQ is waiting for (preview-build.md §3 rule 7) — the same reason C-022
    /// builds nothing for its own undesigned truncation.
    private func pair(value: Int, label: String) -> some View {
        MetaPair(value: String(value), label: label, layout: .inline, align: .left)
    }

    // FLAGGED LITERAL — C-064 §2: "**The 184×88 frame and its 11/32 slack.** Stated dimensions
    // rather than tokens, and questioned rather than adopted — OQ-C-064-2." Whether the box is
    // designed or authoring residue is the owner's call; until then it is carried as measured.
    private static let frameWidth: CGFloat = 184
    private static let frameHeight: CGFloat = 88

    // FLAGGED LITERAL — C-064 §2: "**The 8pt and 2pt gaps.** Recorded as measured values rather
    // than as `space-element-gap` (8) and `space-chip-gap` (2). Both are hex-equal, and both are
    // true gaps between siblings — the same claim C-022 §2 makes for its own 4 and 8, and
    // carried the same way pending the one spacing ruling." OQ-C-022-5.
    //
    // NOT `Token.Space.elementGap`, which is the identical 8: spending the token here would
    // assert the decision the contract holds open.
    private static let bandGap: CGFloat = 8
}

/// C-075 ArrowGlyph — "a 24×24 static directional arrow (NOT a button — no hit target, no
/// action, no tint prop)".
///
/// Built inline rather than as its own preview: its contract is **§5a of C-064's file** with no
/// frozen snapshot of its own, so it is not a legal `/d2m-component-build` target and can never
/// earn its own comparison row. The same carriage C-038 gives C-074 PersonGlyph and C-033 gives
/// C-072 LinkStatusGlyph.
struct ArrowGlyph: View {

    /// C-075 §5a `direction: left | right` — the row's one axis, "both designed and both
    /// consumed" by C-064. Raw values are the contract's own names, which are also the
    /// artwork filenames (`assets/C-075-direction-<value>.svg`) and the catalog keys.
    enum Direction: String {
        case left
        case right
    }

    /// C-075 §5a: "`direction: left | right`. **No tint prop** — see the fill note."
    let direction: Direction

    var body: some View {
        // §5a: "**Fill:** `white @ 20%` (`White/20%` → `color-white-20`), baked into the
        // exported path — `fill="white" fill-opacity="0.2"` — **not applied by the consumer**."
        // So the imageset is `original`-rendered and carries no `.foregroundColor`;
        // `Token.white20` is the token that value equals, and is named here rather than applied.
        //
        // This is also why `right` needs its own imageset despite sharing one vector with C-021
        // `arrow-forward` (§5a: byte-identical paths): C-021's catalog entry is `template`, a
        // mask tinted `color-accent`, and reusing it would drop the baked 20% white. The two
        // rows differ in fill and role, which is the whole of OQ-C-064-7.
        Image(Self.asset(for: direction), bundle: .ui2Preview)
            .resizable()
            .scaledToFit()
            // §5a: "**Geometry:** 24×24 viewBox, one path, no container and no background."
            // A stated size of the glyph's own box, like C-021 §2's 24 and C-072 §3e's 16 —
            // no token row carries it, and the hex-equal `space-row-gap` (24) is a gap between
            // table rows, not the size of an icon.
            .frame(width: Self.box, height: Self.box)
            .ui2Element("ArrowGlyph (\(direction.rawValue))")
    }

    /// §5a: "**Artwork:** `assets/C-075-direction-left.svg`, `assets/C-075-direction-right.svg`."
    /// Carried into the catalog under the `c075-` prefix, so the asset name is derived from the
    /// §5a value and there is no mapping table to drift.
    private static func asset(for direction: Direction) -> String {
        "c075-direction-\(direction.rawValue)"
    }

    /// §5a: the 24×24 box both values are drawn in.
    private static let box: CGFloat = 24
}
