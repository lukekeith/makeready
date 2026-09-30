//
//  MetaPair.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-022-meta-pair.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-022 MetaPair — "a value and its label, inline or stacked".
///
/// §2: "Two text runs — a **value** and a **label** — and nothing else. No icon, no ground, no
/// border, no shadow."
///
/// Chrome-free and content-hugging. §3c: "Width is not a variant … every form hugs its content";
/// §2: "Neither height is set" — 24 and 36 both fall out of the type. Frame, background and outer
/// padding belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct MetaPair: View {

    /// C-022 §4 `layout: inline | stacked`.
    ///
    /// **This row's own axis, not Figma's** (§1 deviation 5). The owner removed C-041 DetailPair
    /// as a duplicate on 2026-09-11 and merged its stacked set (`3499:27340`) into this row
    /// beside the inline one (`3636:5616`); `layout` is this contract's model of that merge, and
    /// §3a is the ruling that closed OQ-C-022-1 — both forms are designed and both are consumed,
    /// so neither could be dropped.
    enum Layout: String {
        case inline
        case stacked
    }

    /// C-022 §4 `align: Left | Right` — **inline only, and it does not align.**
    ///
    /// §3b: "`align=Right` reorders the two runs so the **value** sits on the right … A build
    /// must implement this as **order**, not as alignment. `.frame(alignment: .trailing)` would
    /// right-align a box that is already content-sized — a no-op — and leave the runs in the
    /// wrong order." Both symbols are the same 79×24 box and neither sets a text-alignment or
    /// justification property; §1 deviation 1 keeps the misleading name deliberately, because it
    /// is the designer's own and describes the intent a consumer has.
    ///
    /// The raw values are §4's own capitalised spellings, so the fixture carries the contract's
    /// vocabulary verbatim.
    enum Align: String {
        case left = "Left"
        case right = "Right"
    }

    /// C-022 §4 `value: String` — "the number or short datum (e.g. \"3\", \"5\", \"0 mins\") —
    /// rendered white in every form".
    let value: String
    /// C-022 §4 `label: String` — "what the value counts (e.g. \"enrollments\", \"metrics\") —
    /// `color-text-secondary` in every form".
    let label: String
    /// C-022 §4 `layout: inline | stacked`.
    let layout: Layout
    /// C-022 §4 `align: Left | Right`.
    ///
    /// §4: "**`align` is inert under `layout=stacked`.** That is a sparse matrix, not a missing
    /// state — see §3d, which declines to propose a stacked `align` rather than inventing one."
    /// §4 gives the prop no default, so the signature requires it and `stackedColumn` simply
    /// never reads it; the ViewRegistry call site supplies `.left` for the stacked state and
    /// records there that it is inert.
    let align: Align

    /// C-022 §4 `valueFirst: Bool` — **stacked only**, and the mirror of `align`.
    ///
    /// §3a: "`true` puts the value above the label, reversing the drawn order." **This is the one
    /// prop in the contract with no Figma symbol behind it** — §1 deviation 6 records it as an
    /// owner ruling (2026-09-11), made as a comment on this very preview. So the `stacked ·
    /// valueFirst` state renders from the contract alone and no frozen snapshot can confirm it
    /// (OQ-C-022-10); that is expected, not a diff failure.
    ///
    /// Defaulted, unlike `align`, because §4 gives it a default — `false`, the drawn form — which
    /// is also what keeps the three pre-existing states' call sites unchanged.
    var valueFirst: Bool = false

    /// §3d: "**Interaction.** No pressed, hover or disabled symbol, and no action prop in either
    /// form — a meta pair is a read-out." So there is no interaction-bearing prop here and
    /// preview-build.md OQ-PB-3 does not arise; where a consumer makes one tappable (C-020
    /// SectionHeader's `meta-button`) the tap target is the consumer's, not this row's.
    var body: some View {
        content
            // §1 deviation 2: "Both sets' root carries a `radius-card-sm` (4) with no fill and no
            // border — no visual effect. Vestigial." Nothing is drawn for it.
            .ui2Element("MetaPair")                   // capture element map — UI2Element.swift
    }

    @ViewBuilder private var content: some View {
        switch layout {
        case .inline: inlineRow
        case .stacked: stackedColumn
        }
    }

    // §2 `layout=inline`: "horizontal, `items: center`, gap **4**; content-hugging. Height 24",
    // order "`align=Left` value→label · `align=Right` label→value (§3b)".
    private var inlineRow: some View {
        HStack(alignment: .center, spacing: Self.inlineGap) {
            // §3b: the axis is the ORDER, nothing else. Each run keeps its own role and colour
            // in both symbols — only which one comes first changes.
            if align == .right {
                inlineRun(label, color: Token.textSecondary).ui2Element("Label")
                inlineRun(value, color: Self.inlineValueWhite).ui2Element("Value")
            } else {
                inlineRun(value, color: Self.inlineValueWhite).ui2Element("Value")
                inlineRun(label, color: Token.textSecondary).ui2Element("Label")
            }
        }
    }

    // §2 `layout=stacked`: "vertical, `items: start`, gap **8**; content-hugging. Height 36",
    // order "**label over value**, always".
    //
    // §2 flags the inversion as substantive: "Inline `align=Left` leads with the value ('3
    // enrollments'); stacked always leads with the **label** ('enrollments' over '5'). That is a
    // substantive difference between the merged halves, not a layout detail."
    private var stackedColumn: some View {
        VStack(alignment: .leading, spacing: Self.stackedGap) {
            // §3a `valueFirst`: the order is the whole of the state, exactly as `align` is the
            // whole of the inline one — each run keeps its own role, colour and type, and only
            // which comes first changes. Owner-ruled 2026-09-11; §1 deviation 6.
            if valueFirst {
                stackedRun(value, color: Token.textPrimary).ui2Element("Value")
                stackedRun(label, color: Token.textSecondary).ui2Element("Label")
            } else {
                stackedRun(label, color: Token.textSecondary).ui2Element("Label")
                stackedRun(value, color: Token.textPrimary).ui2Element("Value")
            }
        }
    }

    // §2 inline: "SF Pro **Regular 12**, leading **24**", value white, label
    // `color-text-secondary`.
    private func inlineRun(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(Self.inlineStyle)
            .foregroundColor(color)
            // §3d: "Both runs are `nowrap` and the component hugs them." Truncation is
            // undesigned — OQ-C-022-7 proposes the label truncates first — so nothing is built
            // for it: a content-hugging box never overflows, and building the proposal would
            // pre-empt the ruling its OQ is waiting for (preview-build.md §3 rule 7).
            .lineLimit(1)
            .fixedSize()
            // §2: "Inline: 24 = one 24pt line box, both runs sharing it." SwiftUI has no
            // line-height: `designTextStyle` spells 24 as lineSpacing, which applies only
            // BETWEEN lines, so a single run would otherwise sit in its ~14.3pt font box and the
            // row would close short of 24. The same construction C-027 §2's label uses.
            .frame(height: Self.inlineLineBox)
    }

    // §2 stacked: "SF Pro **Regular 14**, leading **14** (`type-body`)", value white (the bound
    // `Color/Base/White`), label `color-text-secondary`.
    private func stackedRun(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.body)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            // §2: "Stacked: 36 = 14 + 8 + 14." A FIXED box, not a minimum: `type-body`'s designed
            // 14pt line box is SMALLER than SF Pro's natural ~16.7 at that size, so a minHeight
            // would leave the column ~5pt past the 36 §2 states — the reason C-042 §2's label
            // pins the same box.
            .frame(height: Self.stackedLineBox)
    }

    // FLAGGED LITERAL — C-022 §2: "**The inline type, Regular 12/24.** No token row carries it:
    // `type-caption` is Regular 12/**14**. This is the **second independent component** to
    // measure it after C-027 LegendItem, which crosses the threshold `tokens.md` states for
    // minting — recommended there, not minted here, because it should be settled together with
    // `type-caption`." OQ-C-022-3.
    private static let inlineStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 24, tracking: 0
    )

    // FLAGGED LITERAL — C-022 §2: "**The inline value's white.** Hex-equal to
    // `color-text-primary` but bound to no Figma variable, where the stacked form's white **is**
    // bound." OQ-C-022-4.
    //
    // NOT `Token.textPrimary`, which is the identical hex: spending the token here would assert
    // the binding the contract records as absent, and OQ-C-022-4 is precisely the question of
    // whether the merged row carries one white or two. The stacked run above DOES use the token,
    // because its set binds `Color/Base/White`.
    private static let inlineValueWhite = Color(red: 1, green: 1, blue: 1)

    // FLAGGED LITERAL — C-022 §2: "**The 4pt and 8pt gaps.** Recorded as measured values rather
    // than as `space-meta-gap` (4) and `space-element-gap` (8). Both are hex-equal, and both are
    // genuinely gaps between siblings — the case for citing the tokens is stronger here than for
    // the pill insets C-053 §2 flags. Carried as measurements pending the same spacing ruling."
    // OQ-C-022-5.
    private static let inlineGap: CGFloat = 4
    private static let stackedGap: CGFloat = 8

    /// §2: the inline form's 24pt line box, shared by both runs — and therefore the row's height.
    private static let inlineLineBox: CGFloat = 24
    /// §2: `type-body`'s designed 14pt line box; 14 + 8 + 14 is the stacked form's 36.
    private static let stackedLineBox: CGFloat =
        Token.TypeStyle.body.lineHeight ?? Token.TypeStyle.body.size
}
