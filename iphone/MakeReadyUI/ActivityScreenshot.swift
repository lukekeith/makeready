//
//  ActivityScreenshot.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-079-activity-screenshot in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-079 ActivityScreenshot — a lesson activity's full-screen capture, shown at thumbnail scale.
///
/// §2: "a single rounded rectangle" — Deviation 2 collapses Figma's outer frame and its
/// "Image wrapper" into this one clipped view. With no image it is the placeholder fill; with
/// one, the screenshot covers it.
///
/// §2 / R-16: fills the width it is given and states its own height from the capture aspect;
/// it paints nothing outside its rounded frame and adds no outer padding.
struct ActivityScreenshot: View {

    /// C-079 §4 `image` — the activity's screenshot, already resolved by the caller (R-04, R-19).
    /// Required with no default (R-07); `nil` renders `empty`.
    let image: Image?

    /// §2 / Deviation 1: "Height: intrinsic, `width × 956 / 440`" — the owner's fixed capture
    /// size (C-079 preamble: "It will always be captured at 440x956"). A ratio, not a point
    /// size, so it has no token family to live in.
    private static let captureWidth: CGFloat = 440
    private static let captureHeight: CGFloat = 956

    var body: some View {
        // §2 "Fill when there is no image: `color-screenshot-placeholder`" (OQ-C-079-003).
        Token.screenshotPlaceholder
            .aspectRatio(Self.captureWidth / Self.captureHeight, contentMode: .fit)
            .frame(maxWidth: .infinity)
            // OQ-C-079-002 (ruled 2026-09-27): "aspect-fill, top-aligned, clipped to
            // radius-card" — an off-size image loses its bottom edge, never letterboxes.
            .overlay(alignment: .top) {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .ui2Element("Image layer")
                }
            }
            // §2 "Corner: `radius-card` (8) with content clipped to it."
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
            .ui2Element("ActivityScreenshot")
            // The harness measures with a numeric 0 height proposal; a `.fit` aspect ratio
            // would honour it and collapse. Freeing the vertical axis lets the height come
            // from the width alone, which is what §2 says it is.
            .fixedSize(horizontal: false, vertical: true)
    }
}
