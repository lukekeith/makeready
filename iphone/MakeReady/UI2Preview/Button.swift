//
//  Button.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-105-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-105 Button — the program's generic outlined label pill: a single-line label with an
/// optional 18pt library glyph on either side, firing one action the host interprets (R-03).
///
/// §2 / R-16 (hugging exception, as C-102 / C-104): a fixed 36pt height and an intrinsic content
/// width; it does not stretch, paints nothing outside its box and adds no outer padding — the
/// host positions it. There is no disabled state: a host with nothing to act on leaves the
/// button out (OQ-C-105-002).
///
/// The type is the registry name plain (R-13), so inside this module it shadows SwiftUI's
/// `Button`; the view uses gestures rather than the system control, and needs neither.
struct Button: View {

    /// C-105 §4 `label` — the pill's text and its accessibility label. Required (R-07).
    let label: String
    /// C-105 §4 `leadingGlyph` — the 18pt library glyph before the label; `nil` draws none and
    /// drops its gap (OQ-C-105-001).
    var leadingGlyph: GlyphName? = nil
    /// C-105 §4 `trailingGlyph` — the 18pt library glyph after the label; never mirrored or
    /// recoloured; `nil` draws none and drops its gap.
    var trailingGlyph: GlyphName? = nil
    /// C-105 §4 `onTap` — fired once per tap; the host decides what it means (R-03). No render
    /// effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§4).
    @State private var pressed = false

    /// C-105 §2's literal geometry.
    private enum Geometry {
        /// FLAGGED LITERAL — C-105 §2: 1px stroke, the program-wide hairline; no stroke token.
        static let stroke: CGFloat = 1
        /// FLAGGED LITERAL — C-105 §2: glyph 18×18, a dimension; no icon-size token family.
        static let glyph: CGFloat = 18
        /// FLAGGED LITERAL — C-105 §2: 0.6 pressed opacity (ratified OQ-C-105-002); no opacity
        /// token family.
        static let pressedOpacity: Double = 0.6
    }

    private static let labelStyle = Token.TypeStyle.buttonLabelLg

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Token.Radius.card)        // §2 corner `radius-card`
    }

    var body: some View {
        HStack(spacing: Token.Space.buttonGap) {                 // §2 gap, only between present parts
            if let leadingGlyph {
                glyph(leadingGlyph)
                    .ui2Element("Leading glyph")
            }
            Text(label)
                .designTextStyle(Self.labelStyle)
                .foregroundStyle(Token.navText)
                // §2: "single line, no wrap, no truncation".
                .lineLimit(1)
                .fixedSize()
                // §2: the label box is the style's 18pt line. SwiftUI has no line-height and a
                // single run would sit in its ~20pt font box, so the 36pt height is held here.
                .frame(height: Self.labelStyle.lineHeight)
                .ui2Element("Label")
            if let trailingGlyph {
                glyph(trailingGlyph)
                    .ui2Element("Trailing glyph")
            }
        }
        // §2: `space-button-padding` (8) inside the 1pt stroke → content origin (9, 9).
        .padding(Token.Space.buttonPadding + Geometry.stroke)
        .background(fill)
        // `strokeBorder` keeps the 1pt line inside the box, so 1 + 8 + 18 + 8 + 1 = 36 (deviation 5).
        .overlay(shape.strokeBorder(Token.navBorder, lineWidth: Geometry.stroke))
        .contentShape(shape)                                     // §2 hit target: its own frame
        .ui2Element("Pill")
        // §3 row 5 (OQ-C-105-002): the whole pill at 0.6 while the finger is down.
        .opacity(pressed ? Geometry.pressedOpacity : 1)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        // §2 Accessibility (R-17): one button, labelled by `label`; the glyphs are decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .ui2Element("Button")                                    // capture element map — UI2Element.swift
    }

    /// §2 glyph: 18×18 in `color-nav-text` when the library glyph is a template; a full-colour
    /// glyph keeps its own colours (Glyph.swift's rule).
    private func glyph(_ name: GlyphName) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(name.isTemplate ? .template : .original)
            .resizable()
            .scaledToFit()
            .frame(width: Geometry.glyph, height: Geometry.glyph)
            .foregroundStyle(Token.navText)
            .accessibilityHidden(true)
    }

    /// §2 fill `color-transparent` over the backdrop blur.
    private var fill: some View {
        // FLAGGED LITERAL — C-105 §2: backdrop blur 10, a Figma layer effect with no material
        // token. SwiftUI has no radius-set backdrop blur; the nearest is the system's thinnest
        // material, which renders as flat transparency in the simulator capture (deviation 3).
        shape.fill(.ultraThinMaterial)
    }
}
