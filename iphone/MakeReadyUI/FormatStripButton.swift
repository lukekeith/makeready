//
//  FormatStripButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-003-format-strip-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-003 FormatStripButton — one control in C-002 FormatStrip: a plain library glyph that
/// becomes a filled `color-accent` circle while the caret or selection carries its style.
///
/// Controlled (R-01): `active` is the host's query of the caret's style run (02 §2); the button
/// never flips it. The tap leaves through `onTap` (R-03). A fixed 37×37 box in both states, so
/// toggling never moves the strip's other slots (§2 Stability); it paints nothing outside the
/// active circle and adds no outer padding (R-16).
struct FormatStripButton: View {

    /// C-003 §4 `glyph` — any glyph of the era's library; C-002 chooses it per control.
    let glyph: GlyphName
    /// C-003 §4 `active` — draws the accent circle and adds `.isSelected`; set by the host.
    let active: Bool
    /// C-003 §4 `accessibilityLabel` — the host names the control (R-17).
    let accessibilityLabel: String
    /// C-003 §4 `onTap` — the host toggles the style or opens C-015 ListStyleMenu (R-03).
    /// No render effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// C-003 §2's placed geometry: dimensions of a fixed-size control, not a token family.
    private enum Geometry {
        /// C-003 §2 Box / Active circle: "37 × 37 fixed" (01 §3.4, DECISIONS §4 "~37 pt").
        static let box: CGFloat = 37
        /// FLAGGED LITERAL — C-003 §2 FL-1: 20 × 20 glyph, no glyph-size token.
        static let glyph: CGFloat = 20
    }

    /// §2 Glyph paint: `color-text-primary` at rest, `color-white-100` on the circle (OQ-C-003-003).
    private var glyphColor: Color {
        active ? Token.white100 : Token.textPrimary
    }

    var body: some View {
        SwiftUI.Button(action: onTap) {
            ZStack {
                if active {
                    // §2 Active circle — the button's own background, not a sibling view (02 §7).
                    // `radius-circle` is parsed:false (no member), so the circle is the Circle
                    // shape itself. On: scales in with `motion-format-toggle-on`'s spring, which
                    // overshoots slightly and settles; off: fades over `motion-format-toggle-off`.
                    Circle()
                        .fill(Token.accent)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                        .ui2Element("Active circle")
                }
                Image(glyph.rawValue, bundle: .ui2Preview)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Geometry.glyph, height: Geometry.glyph)
                    .foregroundStyle(glyphColor)
                    .accessibilityHidden(true)                // §4 Traits: the glyph has no label
                    .ui2Element("Glyph")
            }
            .frame(width: Geometry.box, height: Geometry.box)
            .contentShape(Rectangle())                         // §2 Hit target: the 37 × 37 box
            .animation(active ? Token.Motion.formatToggleOn : Token.Motion.formatToggleOff, value: active)
            .ui2Element("Box")
        }
        // §3 pressed (OQ-C-003-004): the system plain-button highlight, ephemeral, no geometry change.
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("FormatStripButton")
    }
}
