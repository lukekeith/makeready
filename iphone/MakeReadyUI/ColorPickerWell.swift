//
//  ColorPickerWell.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-095-colorpickerwell in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-095 ColorPickerWell — the current-colour well that arms the eyedropper.
///
/// A 34pt disc filled with the text object's current colour, ringed in white, with the
/// library glyph `color-picker` centred on it (§2). Fixed in both dimensions: a round well
/// cannot fill a width, so R-16's width rule is set aside for this row (§2) and the consumer
/// (C-094 TextColorPalette) places it. It paints nothing beyond its own disc.
struct ColorPickerWell: View {

    /// C-095 §4 `color` — the text object's current colour; fills the disc. Required.
    let color: Color
    /// C-095 §4 `armed` — true while the eyedropper this well arms is live; selects §3 `armed`.
    var armed: Bool = false
    /// C-095 §4 `onTap` — the caller arms the eyedropper / presents the HSB picker (R-03). No
    /// render effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§2, OQ-C-095-002).
    @State private var pressed = false
    /// Resolves `color` to read its luminance (OQ-C-095-003).
    @Environment(\.self) private var environment

    /// C-095 §2's literal geometry.
    private enum Geometry {
        /// §2: "34×34 pt, fixed in both dimensions".
        static let disc: CGFloat = 34
        /// FLAGGED LITERAL — C-095 §1 deviation 3: the 2pt ring width has no token.
        static let ring: CGFloat = 2
        /// FLAGGED LITERAL — C-095 §1 deviation 3: the 20pt glyph, 7pt inset in the 34pt disc,
        /// has no token.
        static let glyph: CGFloat = 20
        /// OQ-C-095-002 ruling: the whole well dims to 0.6 while pressed; no opacity token family.
        static let pressedOpacity: Double = 0.6
        /// OQ-C-095-003 ruling: a fill whose relative luminance is ≥ 0.5 is "light".
        static let lightLuminance: Float = 0.5
    }

    /// §2 Ring: `color-white-100`; OQ-C-095-001 ruling: `color-accent` while armed (same 2pt).
    private var ringColor: Color {
        armed ? Token.accent : Token.white100
    }

    /// §2 Glyph: `color-white-100`; OQ-C-095-003 ruling: `color-black` on a light fill. The ring
    /// is unaffected by the fill.
    private var glyphColor: Color {
        let resolved = color.resolve(in: environment)
        // Relative luminance weighs LINEAR sRGB; `red`/`green`/`blue` are gamma-encoded.
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen
            + 0.0722 * resolved.linearBlue
        return luminance >= Geometry.lightLuminance ? Token.black : Token.white100
    }

    var body: some View {
        Circle()                                                 // §2 Disc: `radius-circle`
            .fill(color)
            .ui2Element("Disc")
            // strokeBorder keeps the 2pt ring inside the 34pt box (§2).
            .overlay(Circle().strokeBorder(ringColor, lineWidth: Geometry.ring).ui2Element("Ring"))
            .overlay(
                Image(GlyphName.colorPicker.rawValue, bundle: .ui2Preview)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Geometry.glyph, height: Geometry.glyph)
                    .foregroundStyle(glyphColor)
                    .accessibilityHidden(true)
                    .ui2Element("Glyph")
            )
            .frame(width: Geometry.disc, height: Geometry.disc)
            .contentShape(Circle())                              // §2 hit target: the disc as drawn
            .opacity(pressed ? Geometry.pressedOpacity : 1)
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
            // §2 Accessibility (R-17): a button labelled "Current colour"; selected while armed.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current colour")
            .accessibilityAddTraits(armed ? [.isButton, .isSelected] : .isButton)
            .ui2Element("ColorPickerWell")
    }
}
