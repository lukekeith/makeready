//
//  SectionDivider.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-088-section-divider in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-088 SectionDivider — the 1pt full-width rule between page sections.
///
/// §2: "one horizontal rule. No children, no text, no glyph, no slot." Square ends, no radius.
///
/// §2 / R-16: fills the width it is given and states its own 1pt height; it adds no vertical
/// margin and no horizontal inset — the `space-section-gap` above and below and the page
/// inset belong to the host.
///
/// §4: no props (`SectionDivider()`).
struct SectionDivider: View {

    /// GAP — C-088 §2: "Height: 1 pt intrinsic … the painted box is 1 pt tall", no stroke-width token.
    private static let thickness: CGFloat = 1

    var body: some View {
        // §2 "Colour: `color-layout-border`". §1 deviation 1: Figma's `layout/border`
        // resolves to #2f3639; the token binding is normative.
        Token.layoutBorder
            .frame(maxWidth: .infinity)
            .frame(height: Self.thickness)
            // §2 "Accessibility: decorative".
            .accessibilityHidden(true)
            .ui2Element("SectionDivider")
    }
}
