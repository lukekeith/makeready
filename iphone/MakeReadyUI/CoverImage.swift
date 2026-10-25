//
//  CoverImage.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-087-cover-image in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-087 CoverImage — a program's cover picture, shown as a rounded banner.
///
/// §2: "A single rounded rectangle with the image clipped inside it" — no border, overlay,
/// gradient or badge. With no image it is the placeholder fill; with one, the cover covers it.
///
/// §2 / R-16: fills the width it is given and states its own fixed height; it paints nothing
/// outside its rounded frame and adds no outer padding.
struct CoverImage: View {

    /// C-087 §4 `image` — the program's cover, already resolved by the caller (R-04, R-19).
    /// Required with no default (R-07); `nil` renders `No cover` (and loading, OQ-C-087-001).
    let image: Image?

    /// GAP — C-087 §2: height 180, no token. OQ-C-087-002 (ruled 2026-10-02): "Fixed 180pt at
    /// every width … the centered crop just shows less of the sides."
    private static let height: CGFloat = 180

    var body: some View {
        // §2 "Fill with no image: `color-screenshot-placeholder`" (OQ-C-087-001).
        Token.screenshotPlaceholder
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            // Deviation 2: "aspect-fill with a centered crop, clipped to the frame".
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .ui2Element("Image")
                }
            }
            // §2 "Corner: `radius-card` (8), with the content clipped to it."
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
            // §2 Accessibility: decorative, hidden from VoiceOver.
            .accessibilityHidden(true)
            .ui2Element("CoverImage")
    }
}
