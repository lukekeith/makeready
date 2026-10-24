//
//  ClearSearchButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-039-clear-search-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  ARTWORK: the `Close icon` vector is leaf artwork carried in Resources/Glyphs.xcassets as
//  `c039-clear-icon` (14×14, template-rendered) — the same treatment C-021 gives its glyphs
//  (C-039 §5). That imageset was exported from C-021's `button=Clear` node `4029:40373`;
//  C-039 §1 records that vector as path-identical to this row's own `3561:33753`, and the
//  contract's stored export (`assets/C-039-clear-search-button.svg`, 32×32 with the glyph at
//  9,9) confirms it: both paths are the same coordinates translated by exactly (9, 9).
//

import SwiftUI

/// C-039 ClearSearchButton — the trailing clear affordance of a search field.
///
/// A single tappable glyph in a fixed square: no label, no container fill, no border (§2).
/// Chrome-free: it paints nothing but the glyph, adds no outer padding, and states its own
/// 32pt footprint. Visibility is the host's concern — C-034 renders it only while `text` is
/// non-empty (§3), so there is no `hidden`/`disabled` state here (OQ-C-039-2 ruling: absent,
/// never dimmed).
struct ClearSearchButton: View {

    /// C-039 §4 `action: () -> Void` — invoked on tap; carries no render effect. C-034 wires
    /// it to its `onClear`. Emitted as a defaulted no-op so the promoted view keeps its real
    /// signature.
    var action: () -> Void = {}

    /// C-039 §2's placed geometry.
    private enum Geometry {
        /// §2: "**Frame:** 32×32" — the designed visual bounds.
        static let frame: CGFloat = 32
        /// §2: "**Glyph:** the `Close icon` vector, 14×14".
        static let glyph: CGFloat = 14
        /// GAP — C-039 §2: "placed at (9, 9) — i.e. inset 9 on all sides"; no spacing token
        /// for 9. (Also the arithmetic: (32 − 14) / 2.)
        static let glyphInset: CGFloat = 9
        /// OQ-C-039-3 ruling: "visual bounds 32pt, hit target the host row's full height
        /// (44pt in C-034) and 44pt wide." The row height is the host's; this component
        /// contributes the 44pt square as an expanded tap shape, NOT a larger frame — a
        /// 44pt frame would move C-034's placed geometry (trailing 7 / top 5).
        static let hitTarget: CGFloat = 44
    }

    var body: some View {
        SwiftUI.Button(action: action) {
            Image("c039-clear-icon", bundle: .ui2Preview)
                // Template-rendered like every glyph in this catalog, so the vector is a mask
                // and the button style's tint below is the whole of its colour.
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .ui2Element("Close icon")
                // §2: inset 9 on all sides → the glyph is centred at (16, 16) in the 32 frame.
                .padding(Geometry.glyphInset)
                .frame(width: Geometry.frame, height: Geometry.frame)
                .background(Token.transparent)          // §2: frame `color-transparent`, no stroke
                .contentShape(Rectangle().inset(by: -(Geometry.hitTarget - Geometry.frame) / 2))
        }
        .buttonStyle(ClearSearchButtonStyle())
        // §4 (proposed default, not designed): label "Clear search", trait button — a host
        // may override the label to match its placeholder.
        .accessibilityLabel("Clear search")
        .ui2Element("ClearSearchButton")
    }
}

/// The tint is the only thing this component paints, and the only thing `pressed` changes.
///
/// §2: "**Tint:** white — raw `#FFFFFF`, not bound to a Figma variable. Hex-equal to
/// `color-text-primary`; contracted as that token (flagged literal…)."
/// FLAGGED LITERAL — C-039 §2: `#FFFFFF` = `color-text-primary`. The flag records that FIGMA
/// did not bind a variable (OQ-C-039-4's ruling is to bind it); §2's own normative line
/// names the token, so the token is used and the flag carried here rather than a second
/// copy of the hex.
///
/// §3 `pressed` + OQ-C-039-2 ruling: "opacity dip on the glyph (to `color-white-70`-
/// equivalent), no geometry change, no background." The row is undesigned in Figma so it has
/// no fixture state; the ruling is honoured as behaviour, reachable only by touch.
private struct ClearSearchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Token.white70 : Token.textPrimary)
    }
}
