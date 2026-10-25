//
//  ColorSwatch.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-096-colorswatch in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-096 ColorSwatch — one preset colour in C-094 TextColorPalette.
///
/// A 24pt rounded tile filled with `color` (§2). Fixed in both dimensions: a swatch is a fixed
/// tile the consumer places at its 40pt pitch, so R-16's width rule is set aside for this row
/// (§2). It paints nothing beyond its own fill and draws every stroke inside its box.
struct ColorSwatch: View {

    /// C-096 §4 `color` — the preset colour; fills the tile and decides `tone` (§3). Required.
    let color: Color
    /// C-096 §4 `label` — the colour's name for accessibility ("Blue"); never drawn. Required
    /// (R-17, OQ-C-096-003).
    let label: String
    /// C-096 §4 `selected` — draws the 2pt outline; selects §3 `selected` / `dark-selected`.
    var selected: Bool = false
    /// C-096 §4 `onTap` — the caller writes the colour to the text object (R-03). No render
    /// effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§2, OQ-C-096-002).
    @State private var pressed = false
    /// Resolves `color` to read its luminance (§3 `tone`, OQ-C-096-001).
    @Environment(\.self) private var environment

    /// C-096 §2's literal geometry.
    private enum Geometry {
        /// FLAGGED LITERAL — C-096 §1 deviation 3: the 24pt tile has no token.
        static let tile: CGFloat = 24
        /// FLAGGED LITERAL — C-096 §1 deviation 3: the 2pt selected outline width has no token.
        static let outline: CGFloat = 2
        /// FLAGGED LITERAL — C-096 §1 deviation 3: the 1pt dark-fill border width has no token.
        static let border: CGFloat = 1
        /// OQ-C-096-002 ruling: the whole tile dims to 0.6 while pressed; no opacity token family.
        static let pressedOpacity: Double = 0.6
        /// OQ-C-096-001 ruling: a fill whose relative luminance is below 0.1 is `tone=dark`.
        static let darkLuminance: Float = 0.1
    }

    /// §3 `tone`, derived from `color` (OQ-C-096-001) — never a prop.
    private var dark: Bool {
        let resolved = color.resolve(in: environment)
        // Relative luminance weighs LINEAR sRGB; `red`/`green`/`blue` are gamma-encoded.
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen
            + 0.0722 * resolved.linearBlue
        return luminance < Geometry.darkLuminance
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Token.Radius.cardSm)       // §2 Tile: `radius-card-sm`
    }

    var body: some View {
        tileShape
            .fill(color)
            .ui2Element("Tile")
            .overlay {
                // strokeBorder keeps every stroke inside the 24pt box (§2). OQ-C-096-001: the
                // selected outline REPLACES the dark-fill border — a tile never carries two.
                if selected {
                    tileShape
                        .strokeBorder(Token.white100, lineWidth: Geometry.outline)
                        .ui2Element("Selected outline")
                } else if dark {
                    tileShape
                        .strokeBorder(Token.white20, lineWidth: Geometry.border)
                        .ui2Element("Dark-fill border")
                }
            }
            .frame(width: Geometry.tile, height: Geometry.tile)
            .contentShape(tileShape)                              // §2 hit target: the tile as drawn
            .opacity(pressed ? Geometry.pressedOpacity : 1)
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
            // §2 Accessibility (R-17): a button labelled with the colour's name; selected while
            // `selected`.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .ui2Element("ColorSwatch")
    }
}
