//
//  ModalCloseButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-082-modalclosebutton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-082 ModalCloseButton — the floating white ✕ disc that closes a full-screen modal.
///
/// One tappable disc holding one glyph: no label, no border, no shadow (§2). A fixed 44×44
/// control — it does not stretch to the width it is given; the host positions it (C-036
/// centres it above the screen bottom). It paints nothing outside its circle (§1 deviation 1).
/// There is no `disabled` state: a modal that cannot be closed omits the button (§3).
struct ModalCloseButton: View {

    /// C-082 §4 `onClose: () -> Void` — fired on tap; the presenter dismisses the modal
    /// (R-03). No render effect; defaulted to a no-op.
    var onClose: () -> Void = {}

    /// C-082 §2's placed geometry.
    private enum Geometry {
        /// GAP — C-082 §2: "Disc | 44×44" (fixed size, also the hit target); no sizing token.
        static let disc: CGFloat = 44
    }

    var body: some View {
        SwiftUI.Button(action: onClose) {
            // §2 Glyph: `close-carbon`, 24×24 (GlyphSize.md), centred — inset 10 on every side.
            // FLAGGED LITERAL — C-082 §2: glyph tint `color-slate-900`, a palette step with no
            // semantic token (the same flagged literal-by-token C-036 §2 uses).
            Glyph(.closeCarbon, size: .md, tint: Color.palette.slate900)
                .accessibilityHidden(true)              // §4: the glyph is decorative
                .ui2Element("Glyph")
                .frame(width: Geometry.disc, height: Geometry.disc)
                // §2 Disc: `radius-circle` (deviation 2) — a true circle. `radius-circle` is
                // not parsed (no CGFloat member: "50%"), so the shape is `Circle()` itself.
                .background(Circle().fill(Token.white100))
                .contentShape(Circle())
                .ui2Element("Disc")
        }
        // §3 `pressed`, ruled by OQ-C-036-8: the system highlight of a plain button style,
        // ephemeral (R-02), no geometry change.
        .buttonStyle(.plain)
        // §4 / R-17: a button labelled "Close" with the button trait.
        .accessibilityLabel("Close")
        .accessibilityAddTraits(.isButton)
        .ui2Element("ModalCloseButton")
    }
}
