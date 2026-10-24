//
//  IconButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-102-iconbutton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-102 IconButton — the program's generic 34pt glyph button: any library glyph, in a tone,
/// outlined or plain, optionally selected.
///
/// A fixed 34×34 control (§2): it does not stretch to the width it is given, and the host
/// positions it. It paints nothing outside its box and adds no outer padding (R-16). There is
/// no `disabled` state: a host with nothing to act on leaves the button out (OQ-C-102-5).
struct IconButton: View {

    /// C-102 §4 `tone` — the paint row of §2 (OQ-C-102-2).
    enum Tone: String {
        case `default`, destructive
    }

    /// C-102 §4 `style` — outlined draws the stroke and the backdrop blur; plain draws neither
    /// (OQ-C-102-7).
    enum Style: String {
        case outlined, plain
    }

    /// C-102 §4 `glyph` — any glyph of the era's library; the designed sample is `trash-2`.
    let glyph: GlyphName
    /// C-102 §4 `tone`.
    let tone: Tone
    /// C-102 §4 `style`.
    let style: Style
    /// C-102 §4 `selected` — `color-white-100` fill, `color-black` glyph (OQ-C-102-6).
    let selected: Bool
    /// C-102 §4 `accessibilityLabel` — the host names the action (R-17).
    let accessibilityLabel: String
    /// C-102 §4 `onTap` — fired on tap; the host decides what it means (R-03). No render
    /// effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// C-102 §2's placed geometry. Both are §2 dimensions of a fixed-size control, not values
    /// of a token family (§2: "a dimension, not a spacing token").
    private enum Geometry {
        /// C-102 §2 Box: "34×34 fixed, including its stroke".
        static let box: CGFloat = 34
        /// C-102 §2 Glyph: "18×18, centred — inset 8 on every side".
        static let glyph: CGFloat = 18
        /// FLAGGED LITERAL — C-102 §2: 1px stroke, the program-wide hairline; no stroke token.
        static let stroke: CGFloat = 1
    }

    /// §2 tone paints: the stroke and the glyph share one colour per tone.
    private var toneColor: Color {
        switch tone {
        case .default: return Token.navText          // OQ-C-102-3
        case .destructive: return Token.error        // designed — symbol 3411:2493
        }
    }

    /// §2 Selected: the glyph turns `color-black` in either tone (OQ-C-102-6).
    private var glyphColor: Color {
        selected ? Token.black : toneColor
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Token.Radius.cardSm)   // §2 / OQ-C-102-8
    }

    var body: some View {
        SwiftUI.Button(action: onTap) {
            Image(glyph.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .foregroundStyle(glyphColor)
                .accessibilityHidden(true)                    // §4: the glyph is decorative
                .ui2Element("Glyph")
                .frame(width: Geometry.box, height: Geometry.box)
                .background(fill)
                .overlay {
                    if style == .outlined {
                        // strokeBorder keeps the 1pt line inside the 34×34 box (§2).
                        shape.strokeBorder(toneColor, lineWidth: Geometry.stroke)
                    }
                }
                .contentShape(shape)
                .ui2Element("Box")
        }
        // §3 `pressed`, ruled by OQ-C-102-5: the system highlight of a plain button style,
        // ephemeral (R-02), no geometry change.
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .ui2Element("IconButton")
    }

    /// §2 Box fill: `color-transparent`, `color-white-100` while selected; an outlined box
    /// also carries the backdrop blur under its fill.
    @ViewBuilder private var fill: some View {
        if selected {
            shape.fill(Token.white100)
        } else if style == .outlined {
            // FLAGGED LITERAL — C-102 §2: Background blur 10, a Figma layer effect with no
            // material token. SwiftUI has no radius-set backdrop blur; the nearest is the
            // system's thinnest material, which renders as flat transparency in the simulator
            // capture (§2, deviation 3).
            shape.fill(.ultraThinMaterial)
        } else {
            shape.fill(Token.transparent)
        }
    }
}
