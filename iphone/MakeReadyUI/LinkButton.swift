//
//  LinkButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-049 LinkButton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-049 LinkButton — "inline underlined text link that triggers an action".
///
/// §2: "A single-line text label with a hairline underline flush beneath it. **Hug-width** —
/// the component is as wide as its label and never stretches … No padding, no background, no
/// glyph." §5: a leaf — "the label is a text node and the underline is a border".
///
/// Chrome-free: the view states its own footprint (113×24.5 at "Get suggestions") and paints
/// no ground; the ViewRegistry call site supplies the outer margin and the background.
struct LinkButton: View {

    /// C-049 §4 `style: default | muted` — "the Figma `style` axis; selects the label +
    /// underline colour (§3)". §3: both values are active links — "`muted` is
    /// **low-emphasis, not disabled**" (OQ-C-049-2, ratified 2026-09-16).
    enum Style: String {
        case `default`
        case muted
    }

    /// C-049 §4 `label: String` — "the link text; single line (OQ-C-049-4). Consumers supply
    /// it verbatim from their spec — the set's "Get suggestions" is sample text only".
    let label: String
    /// C-049 §4 `style`. "Default `default`", so the signature carries it.
    var style: Style = .default
    /// C-049 §4 `onTap: () -> Void` — "raised on tap-up inside the hit area (deviation 1)".
    /// No render effect; emitted as a defaulted no-op so the promoted view keeps its real
    /// signature (preview-build.md OQ-PB-3's default).
    var onTap: () -> Void = {}
    /// C-049 §4 `isEnabled: Bool` — "`false` renders 50% opacity and suppresses `onTap`.
    /// Default `true`" (OQ-C-049-2, ratified 2026-09-16).
    var isEnabled: Bool = true
    /// filter-menu text links (owner 2026-10-26): false is the plain text-button variant — the
    /// same label, colours and states with no underline, so the footprint is the 24pt line box.
    /// Default true keeps the designed underlined link.
    var underlined: Bool = true

    var body: some View {
        SwiftUI.Button(action: onTap) {
            Text(label)
                .designTextStyle(Token.TypeStyle.link)     // §2: `type-link` — SF Pro Semibold 14/24
                .foregroundColor(color)
                // §2: "single line, **no wrap**". OQ-C-049-4 (ratified 2026-09-16): "never
                // wraps; tail-truncates with an ellipsis when the row cannot fit it, underline
                // spans the truncated width" — the underline is an overlay on this text, so it
                // spans whatever width the text ends up with.
                .lineLimit(1)
                .truncationMode(.tail)
                // §2: "Height **24.5** = 24 (label line box) + 0.5 (underline)". SwiftUI has no
                // line-height — `designTextStyle` spells 24 as lineSpacing, which applies only
                // BETWEEN lines — so a single run would otherwise sit in its ~17pt font box. The
                // line box is the token's own leading, read from the token rather than restated.
                .frame(height: Self.labelBox)
                .ui2Element("Label")
                // §2 Underline: "0.5px solid bottom border on the container, full label width,
                // colour = the label's colour, drawn directly below the 24pt line box with no
                // gap." The bottom padding grows the box to 24.5 and the overlay pins the rule
                // into that half-point, so the underline is as wide as the (possibly truncated)
                // label and never as wide as the consumer's row.
                .padding(.bottom, underlined ? Self.underline : 0)
                .overlay(alignment: .bottom) {
                    if underlined {
                        Rectangle()
                            .fill(color)
                            .frame(height: Self.underline)
                            .ui2Element("Underline")
                    }
                }
        }
        .buttonStyle(PressedDim())
        // OQ-C-049-2 (ratified 2026-09-16): "isEnabled=false renders the current style at 50%
        // opacity and ignores taps". Explicit opacity + hit-testing rather than `.disabled(true)`:
        // the framework's own disabled paint is not the contract's 50%, and C-048 measured it
        // landing ON TOP of the designed look. `.allowsHitTesting(false)` swallows the tap
        // without adding paint of its own.
        .opacity(isEnabled ? 1 : Self.dimmed)
        .allowsHitTesting(isEnabled)
        // OQ-C-049-3 (ratified 2026-09-16, deviation 1): "an invisible 44×44pt minimum tap
        // target around the 24.5pt drawn geometry". An expanded tap SHAPE, not a larger frame —
        // a 44pt frame would make the layout footprint 44 and push every consumer's row
        // (C-020's is 24pt tall). Same construction as C-021 GlyphButton's target. The inset is
        // uniform, so the width also grows by 19.5, which keeps any label ≥ 24.5pt wide at or
        // above 44.
        .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.labelBox - Self.underline) / 2))
        .ui2Element("LinkButton")                 // capture element map — UI2Element.swift
    }

    /// §3: the whole delta between the two symbols is colour, on label and underline alike.
    private var color: Color {
        switch style {
        case .default: return Token.accent      // §1: `Purple/100%` → `color-accent`
        case .muted: return Token.white20       // §1: `White/20%` → `color-white-20`
        }
    }

    // OQ-C-049-1 (ratified 2026-09-16): "50% opacity on label + underline while the touch is
    // down; no scale, no haptic". A custom style rather than `.plain`, whose own pressed dim is
    // the framework's value, not the contract's.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? LinkButton.dimmed : 1)
        }
    }

    /// §2: "24 (label line box)" — `type-link`'s own leading, 14/**24**. Read from the token so
    /// a re-measured line-height moves this with it.
    private static let labelBox: CGFloat = Token.TypeStyle.link.lineHeight ?? Token.TypeStyle.link.size

    // FLAGGED LITERAL — C-049 §2: "Underline: 0.5px … **Flagged literal**: 0.5 has no token; it
    // renders as one device pixel at 2×/3×."
    private static let underline: CGFloat = 0.5

    /// OQ-C-049-1 / OQ-C-049-2 (both ratified 2026-09-16): the one dim the contract names —
    /// "50% opacity" — for pressed and for disabled alike. A ruling value, not a colour token:
    /// it multiplies whatever `style` paints (`color-accent` or `color-white-20`) rather than
    /// swapping in `color-accent-50`, which would give `muted` no disabled look at all.
    private static let dimmed: Double = 0.5

    /// OQ-C-049-3 (ratified 2026-09-16, deviation 1): "44×44pt minimum tap target" — the same
    /// 44 C-021 §2 names; no token row exists for a tap target.
    private static let hitTarget: CGFloat = 44
}
