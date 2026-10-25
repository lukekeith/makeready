//
//  DateSpanIndicator.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-064-date-span-indicator.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  ARTWORK: the two arrows were C-075 ArrowGlyph, retired 2026-10-02 into the glyph library
//  as `arrow-left-carbon` / `arrow-right-carbon` and drawn through the generated `Glyph` view.
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
            Glyph(.arrowLeftCarbon, size: .md, tint: Self.arrowTint)
                .ui2Element("Leading arrow")
            pair(value: months, label: "months")
                .ui2Element("Months pair")
            pair(value: days, label: "days")
                .ui2Element("Days pair")
            Glyph(.arrowRightCarbon, size: .md, tint: Self.arrowTint)
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

    // §5a: "**Fill:** `white @ 20%` (`White/20%` → `color-white-20`)". The library art keeps
    // the absorbed `fill-opacity="0.2"`, so the 20% is already in the glyph's mask: tinting it
    // `Token.white20` would compound to 4%. Full white over the 20% mask renders color-white-20.
    private static let arrowTint = Token.white100
}
