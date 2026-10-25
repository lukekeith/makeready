//
//  TrendIndicator.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-077-trend-indicator in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  ARTWORK: the three arrows are this component's own (§5: "deliberately **not** minted as
//  glyph rows: their fills are variable-bound"), carried in Resources/Glyphs.xcassets under
//  the `c077-` prefix and `template`-rendered — the mask is tinted here, by the same value
//  that colours the label, which is what "bound, not baked" means in code. Exported from the
//  set's three `Icon` instances (`3673:11268` / `11283` / `11288`) with each path at its
//  measured offset inside the 14×14 box; the 14×14 `Transparent` backing rect is an export
//  hit-rect and is not emitted (§1 deviation 2).
//

import SwiftUI

/// C-077 TrendIndicator — "which way a metric moved, and by how much".
///
/// §2: "An arrow and a number, in a row, centred on each other. No ground, no border, no
/// padding."
///
/// Chrome-free and content-sized: the row hugs its label (§3b, "Width is not a variant"), and
/// its 14pt height IS the label's line box — the 14pt glyph "happens to match it exactly, so
/// nothing overhangs". Frame, background and outer padding belong to the call site.
struct TrendIndicator: View {

    /// C-077 §4 `direction: up / down / neutral` — which way the arrow points. Raw values are
    /// the contract's own names (§1 deviation 3 lower-cases Figma's `Up` / `Down` / `Neutral`),
    /// which are also the artwork catalog keys.
    enum Direction: String {
        case up
        case down
        case neutral
    }

    /// C-077 §4 `polarity: positive / negative / neutral` — whether that movement is good, bad
    /// or neither. Owner note 2026-09-17 04:23 (assimilated): "it could be a bad thing that a
    /// number is going up, so it's possible to go up and be red".
    enum Polarity: String {
        case positive
        case negative
        case neutral
    }

    /// §4: "Which way the arrow points — the metric rose, fell or held. **The glyph only**
    /// (owner note, 2026-09-17 04:23): it no longer carries the colour; that is `polarity`."
    ///
    /// **An explicit prop, never derived from `label`** — owner ruling 2026-09-17 (OQ-C-077-2
    /// closed): "A build may not derive it by parsing the number."
    let direction: Direction
    /// §4: "sets the colour of glyph **and** label: `positive` → `color-positive`, `negative` →
    /// `color-negative`, `neutral` → `color-text-secondary`."
    ///
    /// **Independent of `direction`** — all nine `direction`×`polarity` cells are legal (owner,
    /// 2026-09-17 06:10, OQ-C-077-4 closed), so this view "asserts on nothing" (§4): there is no
    /// validation between the two props, only the §3a rule — glyph by `direction`, colour by
    /// `polarity`.
    let polarity: Polarity
    /// §4: "The magnitude, **pre-formatted by the consumer** … This row does not format, sign
    /// or round anything, and it never renders a minus."
    let label: String

    var body: some View {
        // §2: "horizontal, `items: center`, gap **4**; content-hugging both axes."
        HStack(alignment: .center, spacing: Self.gap) {
            glyph
            labelText
        }
        // §3c: display-only — "the indicator is display-only and its one host is not
        // interactive in v1" — so there is no interaction-bearing prop and no gesture.
        .ui2Element("TrendIndicator")     // capture element map — UI2Element.swift
    }

    // §2: "**14×14** vector, leading. One path per `direction`, fill = the `polarity` colour
    // per §3a".
    private var glyph: some View {
        Image(Self.asset(for: direction), bundle: .ui2Preview)
            // The catalog marks the three arrows template-rendering, so the vector is a mask
            // and `color` below is the whole of its fill — §2: "The glyph is still not tinted
            // at the call site; the consumer passes `polarity`, and the component applies it."
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphBox, height: Self.glyphBox)
            .foregroundStyle(color)
            .ui2Element("Glyph")
    }

    // §2: "SF Pro **Regular 12**, leading **14** — this is `type-caption`, a real token —
    // colour = the `polarity` colour per §3a, `nowrap`."
    private var labelText: some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            // §2: "**The height is the label's line box.** 14 = the label's leading". SwiftUI's
            // lineSpacing does nothing to a single line, so the line box is pinned as a frame
            // — from the token's own leading, the same construction C-027's label uses.
            .frame(height: Token.TypeStyle.caption.lineHeight)
            .ui2Element("Label")
    }

    /// §2: "**The glyph and the label share one colour.** … a build tints both from that one
    /// value — never two colours in one indicator, and never a colour chosen from `direction`."
    private var color: Color {
        switch polarity {
        case .positive: return Token.positive         // §4 `positive` — `color-positive`
        case .negative: return Token.negative         // §4 `negative` — `color-negative`
        case .neutral: return Token.textSecondary     // §4 `neutral` — `color-text-secondary`
        }
    }

    /// Catalog key derived from the §4 value, so there is no mapping table to drift.
    private static func asset(for direction: Direction) -> String {
        "c077-direction-\(direction.rawValue)"
    }

    // FLAGGED LITERAL — C-077 §2: "**The 4pt gap.** Hex-equal to `space-meta-gap`, but that
    // token's stated role is MetaPair's value↔label and meta dots, which this is not. Carried
    // as this component's own measurement, the way `C-027-legend-item.md` §2 carries its 8."
    // (OQ-C-027-4 closed on C-027 without naming this 4 — "the measurement stands".)
    //
    // NOT `Token.Space.metaGap`, which is the identical 4: spending the token here would
    // assert a decision the contract explicitly declined to take.
    private static let gap: CGFloat = 4

    // FLAGGED LITERAL — C-077 §2: "**The glyph's 14.** A size, not a spacing — and the
    // program's *fourth* arrow size." (OQ-C-038-7 closed without reaching these bound arrows.)
    private static let glyphBox: CGFloat = 14
}
