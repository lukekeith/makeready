//
//  PageActionButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-048 PageActionButton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-048 PageActionButton — "the full-width page-level action button (Save / Create / Done)".
///
/// §2: "A single-line centered label inside a rounded pill; no glyph, no sub-components."
///
/// Chrome-free and width-driven: §2 says "**Width is the consumer's.** The symbols hug their
/// label; every consumer stretches the button to its content width — 408 on the 440pt screen
/// frames … and 384 inside C-066's p24 container." So the view fills the width it is given and
/// states only its own height; the ViewRegistry call site supplies the consumer width, the outer
/// margin and the ground.
struct PageActionButton: View {

    /// C-048 §4 `role: affirmative | destructive | prominent` — "the intent the button carries
    /// — selects the paint row of §2".
    ///
    /// **This row's own axis, not Figma's.** §3: Figma's `color` axis {Red, Green, Muted, White}
    /// "is recorded once in §1 as evidence and **renamed for what it selects**: `role` … ×
    /// `isEnabled`. Every consumer toggles Muted ⇄ Green as an enabled flag on one affirmative
    /// button, which is what makes Muted `isEnabled=false` rather than a fourth role."
    enum Role: String {
        case affirmative
        case destructive
        case prominent
    }

    /// C-048 §4 `label: String` — "the centered label; single line, no wrap".
    let label: String
    /// C-048 §4 `role`.
    let role: Role
    /// C-048 §4 `isEnabled: Bool (default true)` — "`false` renders the Muted look (§3 rows 4–6)
    /// and swallows taps". §4 gives the default, so the signature carries it.
    var isEnabled: Bool = true
    /// C-048 §4 `action: () -> Void` — "tap handler; never invoked while `isEnabled == false`".
    /// No render effect; emitted as a defaulted no-op so the promoted view keeps its real
    /// signature (preview-build.md OQ-PB-3's default).
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            pill
        }
        .buttonStyle(.plain)
        // §3 rows 4–6: "a disabled button ignores taps and never invokes `action`."
        //
        // `.allowsHitTesting(false)`, NOT `.disabled(true)`: SwiftUI paints a disabled control at
        // 50% opacity, which lands ON TOP of the Muted paint §2 designs. Measured 2026-09-15 —
        // the first capture rendered the stroke at #191d1f, exactly `color-layout-border`
        // (#2f3639) at 0.5 over `color-layout-background` (#030405), instead of the #2f3639 the
        // frozen snapshot shows. §2's disabled row IS the full-strength Muted paint; the dim is
        // the framework's opinion, not the contract's. Hit-testing gives §3's behaviour with no
        // paint of its own.
        .allowsHitTesting(isEnabled)
        // §2: "**Hit target** = the button's own frame (36/38 × width); nothing larger is
        // designed." So no expanded contentShape, unlike C-021 GlyphButton's 44pt target.
        .ui2Element("PageActionButton")           // capture element map — UI2Element.swift
    }

    // §2 Box: "padding 16 horizontal / 8 vertical … corner radius `radius-card` (8 …) · label
    // box 20pt tall → **36pt content box**."
    private var pill: some View {
        Text(label)
            .designTextStyle(Self.labelStyle)
            .foregroundColor(look.labelColor)
            // §2: "centered, single line, no wrap". §3/OQ-C-048-4: truncation is undesigned —
            // "Proposed default: single line, no wrap, no ellipsis" — so nothing is built for
            // it; building the proposal would pre-empt the ruling its OQ waits on
            // (preview-build.md §3 rule 7).
            .lineLimit(1)
            .multilineTextAlignment(.center)
            // §2: "label box 20pt tall". SwiftUI has no line-height, so `designTextStyle` spells
            // 20 as lineSpacing, which applies only BETWEEN lines — a single run would otherwise
            // sit in its ~14.3pt font box and the pill would close short of 36. The same
            // construction C-022 §2's inline run uses.
            .frame(height: Self.labelBox)
            .ui2Element("Label")
            .frame(maxWidth: .infinity)           // §2: "the label stays centered at any width"
            .padding(.horizontal, Self.padH)
            .padding(.vertical, Self.padV)
            .background(look.fill)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
            // §2: "The 1px stroke … is drawn **outside** the 36pt content box in Figma, which is
            // why the bordered symbols measure 38 and White 36. Reproduced as designed
            // (OQ-C-048-3 asks whether to unify)." The 1pt ring is therefore LAYOUT, not just
            // paint: `.padding` grows the box to 38 and `strokeBorder` draws inside that ring,
            // leaving the content box at 36. A plain `.overlay(...stroke...)` would centre the
            // line on the edge and leave the height at 36, losing the 2pt the contract measures.
            .modifier(OutsideStroke(color: look.stroke, width: Self.hairline,
                                    cornerRadius: Token.Radius.card))
    }

    // §3 carries a non-axis row for pressed feedback — "**proposed default:** whole button at
    // 0.6 opacity while pressed" (OQ-C-048-2) — and NOTHING is built for it. It is undesigned on
    // all four symbols, no §3 state and no §4 prop can reach it, so building the proposal would
    // invent the ruling its OQ is waiting for (preview-build.md §3 rule 7) — the same reason
    // C-022 builds nothing for its undesigned truncation.

    /// §2 "Paint by state" — the whole delta between symbols is paint, plus whether a stroke
    /// exists at all. §3 rows 4–6: `isEnabled == false` is the Muted look **regardless of role**
    /// (OQ-C-048-1's proposed default), which is why this reads `isEnabled` first.
    private var look: Look {
        guard isEnabled else {
            // §2 disabled row: no fill, 1px `color-layout-border`, `color-text-secondary` label.
            // §3 row 6: a disabled prominent button "drops its white fill" and is bordered at 38.
            return Look(fill: Token.transparent, stroke: Token.layoutBorder, labelColor: Token.textSecondary)
        }
        switch role {
        case .affirmative:
            // §2: no fill, 1px `color-positive`, `color-positive` label, 38.
            return Look(fill: Token.transparent, stroke: Token.positive, labelColor: Token.positive)
        case .destructive:
            // §2: no fill, 1px `color-negative`, `color-negative` label, 38.
            return Look(fill: Token.transparent, stroke: Token.negative, labelColor: Token.negative)
        case .prominent:
            // §2: fill `color-text-primary`, NO stroke, `color-black` label, 36.
            //
            // The contract flags the fill's own name: "(Figma `Color/Base/White` — the token
            // carries that alias; a fill citing a *text* token is a naming smell, noted for the
            // tokens consolidation OQ, not re-minted here)." Cited by the name the register has.
            return Look(fill: Token.textPrimary, stroke: nil, labelColor: Token.black)
        }
    }

    /// One row of §2's paint table. `stroke == nil` is the prominent row — the only look with no
    /// border, and therefore the only one that measures 36 rather than 38.
    private struct Look {
        let fill: Color
        let stroke: Color?
        let labelColor: Color
    }

    /// §2: "The 1px stroke … is drawn **outside** the 36pt content box." Applied as a 1pt ring
    /// around the content box, so the bordered looks measure 38 and the unbordered one 36.
    private struct OutsideStroke: ViewModifier {
        let color: Color?
        let width: CGFloat
        let cornerRadius: CGFloat

        // @ViewBuilder: `ViewModifier.body` is not implicitly one, so an if/else returning two
        // different view types does not type-check without it.
        @ViewBuilder func body(content: Content) -> some View {
            if let color {
                content
                    .padding(width)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius + width)
                            .strokeBorder(color, lineWidth: width)
                    )
            } else {
                content
            }
        }
    }

    // GAP — C-048 §2: the label is `type-button-label` (SF Pro Text Regular 12/20, tracking
    // −0.24), a token the contract records as "minted this run". The row EXISTS in d2m's
    // register, but `Tokens.swift` is generated by `capture/lib/ui2-tokens.mjs` from
    // `docs/ui2/design-system/tokens.md`, and that file has never received it — so
    // `Token.TypeStyle.buttonLabel` does not exist and cannot be cited by name. The values here
    // are §2's own, verbatim.
    //
    // NOT a flagged literal: the contract does not flag this type, it mints a token for it. This
    // literal stands only until the token register and `tokens.md` are reconciled; the fix is
    // one row in tokens.md (or pointing the generator at d2m), after which this becomes
    // `Token.TypeStyle.buttonLabel` and nothing else about the view changes.
    // Same gap blocks C-049 `type-link` and C-051 `type-block-label`.
    private static let labelStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 20, tracking: -0.24
    )

    // FLAGGED LITERAL — C-048 §2: "padding 16 horizontal / 8 vertical (**literals, flagged** —
    // no button-padding token; the values coincide with `space-card-padding` 16 and
    // `space-element-gap` 8 but those are role-named for other things)."
    //
    // NOT `Token.Space.cardPadding` / `Token.Space.elementGap`, which are the identical 16 and 8:
    // spending those tokens here would assert that a button's insets and a card's padding are
    // one decision, which is exactly what the contract's flag denies.
    private static let padH: CGFloat = 16
    private static let padV: CGFloat = 8

    // FLAGGED LITERAL — C-048 §2: "The 1px stroke (**literal, flagged** — the program-wide
    // hairline)".
    private static let hairline: CGFloat = 1

    /// §2: "label box 20pt tall → **36pt content box**" (20 + 8 + 8).
    private static let labelBox: CGFloat = 20
}
