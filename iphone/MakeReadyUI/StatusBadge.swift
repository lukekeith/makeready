//
//  StatusBadge.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-053-status-badge.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-053 StatusBadge — "a small pill that says what publish state a thing is in".
///
/// §2: "A pill and a word, in either state. There is no icon, no dot, no border and no
/// shadow, and the two states share every measurement except the width their labels
/// produce."
///
/// Chrome-free and content-sized: the pill hugs its label (§3b — the sample's 74 is what
/// "Published" happens to measure, not a width), and its 25pt height is the sum of the
/// paddings and the label's line box and nothing else. Frame, background and outer padding
/// belong to the call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct StatusBadge: View {

    /// §4 `state` — `published | draft`. The closed list above is its whole vocabulary, and
    /// §1 deviation 1: the label is NOT a prop, it is the state's name. Both values are
    /// DESIGNED as of the 2026-09-11 set re-spec (`4147:8257`).
    enum State: String {
        case published
        case draft
    }

    /// §4: the one prop.
    let state: State

    var body: some View {
        label
            // FLAGGED LITERAL — C-053 §2: "The **px 8 / py 4** are recorded as measured
            // paddings rather than as `space-element-gap` (8) and `space-meta-gap` (4). Both
            // are hex-equal, but both are *gaps between siblings* in the spacing family, and
            // this is an inset inside a pill; citing them would assert that a badge's padding
            // and a card stack's rhythm are one decision."
            .padding(.horizontal, Self.paddingX)
            .padding(.vertical, Self.paddingY)
            .background(
                // §2: `radius-card-sm` (4), fill per state.
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .fill(pillFill)
                    .ui2Element("Pill")
            )
            .ui2Element("StatusBadge")     // capture element map — UI2Element.swift
    }

    // §2: the label, centred in the pill, `nowrap`.
    private var label: some View {
        Text(labelText)
            .designTextStyle(Self.labelStyle)
            .foregroundColor(labelColor)
            // §1 deviation 4: "**Both** labels carry **70% opacity** on the text node, not on
            // the pill — so each pill's fill is full-strength and only the lettering is
            // softened." Applied here, once, because the re-spec established it as a property
            // of the COMPONENT rather than of the `published` state.
            //
            // FLAGGED LITERAL — §2: "`tokens.md` has `color-white-70` but no 70% row for
            // either `color-black` or `color-neutral-50`, so the opacity is applied at the
            // call site rather than named." OQ-C-053-4.
            .opacity(Self.labelOpacity)
            .lineLimit(1)
            .fixedSize()
            // §2: "leading **1.4** (= 16.8, a 17pt box)", and "The height is the sum and
            // nothing else: 25 = 4 + 17 + 4". SwiftUI's lineSpacing does nothing to a
            // single line, so the line box is pinned as a frame — the same construction
            // C-046's Bold-14 label uses — or the pill would come out ~22 tall.
            .frame(height: Self.labelLineBox)
            .ui2Element("Label")
    }

    /// §1 deviation 1: "The label string is **not** per-instantiation content — it is the
    /// state's name". §3a for `published`; `draft`'s "Draft" is §3a's proposal.
    private var labelText: String {
        switch state {
        case .published: "Published"
        case .draft: "Draft"
        }
    }

    private var pillFill: Color {
        switch state {
        case .published: Self.publishedGreen
        // §3a: `draft`'s pill is `color-neutral-600` — a BOUND token, unlike its sibling's raw
        // green (§1 deviation 2, OQ-C-053-2). Designed 2026-09-11; before that this state was
        // undesigned and the proposal here was `color-white-20`, which the design did not
        // confirm.
        case .draft: Token.neutral600
        }
    }

    /// §3a. Both are bound tokens; the 70% that softens them is applied once, on the Text.
    private var labelColor: Color {
        switch state {
        case .published: Token.black
        // §3a: `color-neutral-50`, minted by the 2026-09-11 re-spec. The 2026-09-01 proposal
        // for this state was `color-text-primary` — a different colour.
        case .draft: Token.neutral50
        }
    }

    // FLAGGED LITERAL — C-053 §1 deviation 2: "The pill's fill is the raw literal `#6cff73`,
    // hex-equal to `color-positive` (Figma variable `green`) but **not variable-bound**. Only
    // the label's black binds a variable." Emitted as the literal the source states per
    // preview-build.md §3 rule 4, NOT promoted to `Token.positive` — promoting it would
    // assert a binding Figma does not have, and the point of the flag is that the next Figma
    // edit can move one and not the other. OQ-C-053-2 asks for the binding.
    private static let publishedGreen = Color(red: 0.4235, green: 1.0, blue: 0.451, opacity: 1)

    // GAP — C-053 §2: the label is "SF Pro Text **Bold 12**, leading **1.4** (= 16.8, a 17pt
    // box), tracking **−0.24**", and §2 declines to resolve that against `type-caption-bold`,
    // which `tokens.md` records as "SF Pro Bold 12" with NO leading and NO tracking: "this is
    // either that token finally measured, or a second Bold-12. The tracking is the
    // discriminator and it is not nothing" — OQ-C-053-3. Using `Token.TypeStyle.captionBold`
    // here would assert the identity the contract refuses to assert, and would drop both
    // measured values; carried as a per-component literal until the OQ is ruled on.
    private static let labelStyle = DesignTextStyle(
        weight: .bold, size: 12, lineHeight: 16.8, tracking: -0.24
    )

    /// §2: the label's 17pt line box — the middle term of 25 = 4 + 17 + 4.
    private static let labelLineBox: CGFloat = 17
    /// §2: the pill's measured insets — see the flag on `body`'s padding.
    private static let paddingX: CGFloat = 8
    private static let paddingY: CGFloat = 4
    /// §2: the label opacity, in BOTH states — see the flag on `label`.
    private static let labelOpacity: Double = 0.7
}
