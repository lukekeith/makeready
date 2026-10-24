//
//  PageIndicator.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-097-pageindicator in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-097 PageIndicator — a row of page dots, one active.
///
/// `pageCount` 8pt dots at a 17pt pitch, centred in the width it is given; the dot at `page`
/// fills `color-white-100`, the rest `color-white-20` (§2). Display-only and controlled (R-01):
/// the caller (C-094) writes `page`; the dots have no action. Paints no background (R-16, §1
/// deviation 3).
struct PageIndicator: View {

    /// C-097 §4 `pageCount` — how many dots to draw, in page order. Required (R-07).
    let pageCount: Int
    /// C-097 §4 `page` — 0-based index of the active dot; clamped to `0…pageCount−1`.
    var page: Int = 0

    /// C-097 §2's literal geometry and motion.
    private enum Geometry {
        /// FLAGGED LITERAL — C-097 §2: 8pt dot diameter, no token.
        static let dot: CGFloat = 8
        /// FLAGGED LITERAL — C-097 §2: 17pt pitch (a 9pt gap); `space-element-gap` is 8, not a fit.
        static let gap: CGFloat = 9
        /// FLAGGED LITERAL — C-097 §2 / OQ-C-097-2 ruling: 150 ms ease-out crossfade, no motion token.
        static let crossfade: Double = 0.15
    }

    /// §3: a `page` outside the range is a caller defect, clamped rather than drawn as nothing.
    private var activePage: Int {
        min(max(page, 0), max(pageCount - 1, 0))
    }

    var body: some View {
        HStack(spacing: Geometry.gap) {
            // OQ-C-097-1 ruling: with `pageCount` ≤ 1 no dots are drawn; the 8pt height stays.
            if pageCount > 1 {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()                                       // §2: `radius-circle`
                        .fill(index == activePage ? Token.white100 : Token.white20)
                        .frame(width: Geometry.dot, height: Geometry.dot)
                        .ui2Element("Dot \(index + 1)")
                }
            }
        }
        // OQ-C-097-2 ruling: a page change crossfades the two fills; no dot moves.
        .animation(.easeOut(duration: Geometry.crossfade), value: activePage)
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.dot)
        // §2 Accessibility (R-17): decorative — C-094 announces "page N of M" itself.
        .accessibilityHidden(true)
        .ui2Element("PageIndicator")
    }
}
