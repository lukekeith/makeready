//
//  FilterRail.swift
//  MakeReadyUI
//
//  Built from C-130-filter-rail in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-130 FilterRail — one horizontal row of C-035 FilterChips that always swipes left and right
/// (owner ruling 2026-11-01, docs/ui2/references/filter-rail.md).
///
/// - §4 `chips` is the one designed slot (R-08): menu chips (most pages) and button chips (Search)
///   both fit unchanged. Each chip keeps its own label, active rule and tap action; the rail has
///   no action, value or state of its own (R-01 / R-02 / R-03).
/// - §2 Chip row: gap `space-element-gap` (8); chips hug their labels at their own 24pt height.
/// - §2 Content inset / deviation 1 (full bleed): put the rail OUTSIDE the page's side padding.
///   The `space-page-margin` (16) inset sits inside the scroll content, so at rest the first chip
///   is 16 from the left edge and scrolled chips pass under both screen edges.
/// - Deviation 2: `HorizontalRail` scrolls it freely (a vertical swipe still scrolls the page).
///   No indicators, fade, fill or divider, and no vertical padding: the page keeps its own gaps.
struct FilterRail<Chips: View>: View {
    private let chips: Chips

    init(@ViewBuilder chips: () -> Chips) {
        self.chips = chips()
    }

    var body: some View {
        HorizontalRail(showsIndicators: false) {
            HStack(alignment: .center, spacing: Token.Space.elementGap) {
                chips
            }
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("Chip row")
        }
        .ui2Element("FilterRail")
    }
}
