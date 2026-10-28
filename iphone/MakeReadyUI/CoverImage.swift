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
/// gradient or badge. With no image it is the placeholder fill with the centred no-cover glyph;
/// with one, the cover covers it.
///
/// §2 / R-16: fills the width it is given and derives its height from that width at 16:9; it
/// paints nothing outside its rounded frame and adds no outer padding.
struct CoverImage: View {

    /// C-087 §4 `image` — the program's cover, already resolved by the caller (R-04, R-19).
    /// Required with no default (R-07); `nil` renders `No cover` (and loading, OQ-C-087-001).
    let image: Image?

    /// GAP — C-087 §2: 16:9 aspect, no token. Deviation 3 (owner ruling D20, 2026-10-27):
    /// "height = width × 9/16" — replaces OQ-C-087-002's fixed 180.
    private static let aspectRatio: CGFloat = 16 / 9

    var body: some View {
        // §2 "Fill with no image: `color-screenshot-placeholder`" (OQ-C-087-001).
        Token.screenshotPlaceholder
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            // Deviation 2: "aspect-fill with a centered crop, clipped to the frame".
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .ui2Element("Image")
                } else {
                    // §2 "No-cover glyph: Lucide `image`, centred in the box both ways,
                    // 32×32pt, white at 20 % opacity" — drawn only when `image == nil`.
                    Glyph(.image, size: .lg, tint: Token.white20)
                        .ui2Element("NoCoverGlyph")
                }
            }
            // §2 "Corner: `radius-card` (8), with the content clipped to it."
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
            // §2 Accessibility: the picture and the no-cover glyph are decorative, hidden from VoiceOver.
            .accessibilityHidden(true)
            .ui2Element("CoverImage")
            // The harness measures with a numeric 0 height proposal; a `.fit` aspect ratio
            // would honour it and collapse. Freeing the vertical axis lets the height come
            // from the width alone, which is what §2 says it is (the C-079 precedent).
            .fixedSize(horizontal: false, vertical: true)
    }
}
