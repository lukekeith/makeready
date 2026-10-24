//
//  TabBar.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-084-tabbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-084 TabBar — the app-level bottom tab bar of UI 2.0 (D51).
///
/// Five glyph-only C-083 cells in equal-width columns. Controlled (R-01): the caller owns
/// `selected`. Width-driven, with its height taken from the cells (84). OQ-C-084-003 is a
/// recorded exception to R-16: the bar paints its own opaque fill and 16pt side insets.
struct TabBar: View {

    /// C-084 §4: the D51 root tabs in bar order. OQ-C-084-002: Add is an action, not a case.
    enum Tab { case home, calendar, search, profile }

    /// C-084 §4: `selected`. `nil` means no tab is selected (the set symbol 3554:32376).
    let selected: Tab?
    /// C-084 §4: `onSelect`. Called for a root tab, including a re-tap of the selected one.
    /// It has no render effect (R-03).
    var onSelect: (Tab) -> Void = { _ in }
    /// C-084 §4: `onAdd`. Called when Add is tapped. It has no render effect (R-03).
    var onAdd: () -> Void = {}

    /// C-084 §2 "The tabs": one cell. `tab == nil` is the Add action.
    private struct Cell {
        let tab: Tab?
        let glyph: GlyphName
        let accessibilityLabel: String
    }

    /// C-084 §2: the fixed D51 order. These are contract, not props (§1 deviation 3).
    private static let cells: [Cell] = [
        Cell(tab: .home, glyph: .makereadyLogo, accessibilityLabel: "Home"),
        Cell(tab: .calendar, glyph: .calendarCarbon, accessibilityLabel: "Calendar"),
        Cell(tab: nil, glyph: .addLargeCarbon, accessibilityLabel: "Add"),
        Cell(tab: .search, glyph: .searchCarbon, accessibilityLabel: "Search"),
        Cell(tab: .profile, glyph: .userFilledCarbon, accessibilityLabel: "Profile")
    ]

    var body: some View {
        // §2: 5 equal-width cells with no gap between them. Each C-083 cell fills its share
        // of the width and is 84 tall.
        HStack(spacing: 0) {
            ForEach(Array(Self.cells.enumerated()), id: \.offset) { _, cell in
                // OQ-C-084-002: Add calls `onAdd` and is never `active`.
                TabBarButton(
                    glyph: cell.glyph,
                    accessibilityLabel: cell.accessibilityLabel,
                    active: cell.tab != nil && cell.tab == selected,
                    onTap: { tap(cell) }
                )
                .ui2Element(cell.accessibilityLabel)
            }
        }
        // OQ-C-084-003: the bar owns its `space-page-margin` side insets and its opaque
        // `color-layout-background` fill (exception to R-16).
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(maxWidth: .infinity)
        .background(Token.layoutBackground)
        // §2 Accessibility (R-17): the container is a tab bar. Each cell keeps C-083's own
        // label and traits.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .ui2Element("TabBar")
    }

    private func tap(_ cell: Cell) {
        if let tab = cell.tab { onSelect(tab) } else { onAdd() }
    }
}
