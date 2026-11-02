//
//  SearchFilterHeader.swift
//  MakeReadyUI
//
//  Built from C-131-search-filter-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-131 SearchFilterHeader — the one search + filter header of every Home-section list:
/// C-034 SearchField (editable form) over the full-bleed C-130 FilterRail, whose content is the
/// header's one designed slot of C-035 FilterChips (R-08).
///
/// - §4 R-16 carve-out (owner description: "Owns spacing … and pin-below-TopNav"): the header
///   paints its pinned-header material and applies its own insets. It still fills the width it
///   is given and states its own height (116 `underScreenHeader`, 100 `underShellTopNav`).
/// - Being the pinned section header of a list is the CALLER's placement (§2 Pinning); the header
///   only applies `pinnedBelowTopNav()`, which moves nothing outside the shell.
struct SearchFilterHeader<Chips: View>: View {

    /// §4 `placement` — selects the top inset (§1 deviation 3).
    enum Placement {
        /// 0 top inset: the shell's 16 nav gap already sits between the TopNav and the field.
        case underShellTopNav
        /// `space-page-margin` (16) top inset, under a nav row or C-040 PageHeader the screen
        /// draws itself.
        case underScreenHeader
    }

    /// §4 `query` — the search text, owned by the caller (R-01). "" shows the placeholder.
    let query: String
    /// §4 `onQueryChange` — every keystroke, and "" when the clear x ends the search.
    let onQueryChange: (String) -> Void
    /// §4 `placeholder` — C-034's placeholder; each consumer supplies its own.
    let placeholder: String
    /// §4 `placement`.
    let placement: Placement
    /// §4 `onSearchActiveChange` — search-active on every change, initial value included.
    /// No render effect; a no-op default (R-03) because PageHeader screens ignore it.
    let onSearchActiveChange: (Bool) -> Void
    /// §4 `chips` — the slot passed into C-130's slot.
    private let chips: Chips

    /// The field's focus, reported by C-034's editable form — ephemeral (R-02), never a prop.
    /// Seeded by `initiallyFocused` (OQ-media-home-9), then the field's own.
    @State private var fieldFocused: Bool

    init(
        query: String,
        onQueryChange: @escaping (String) -> Void,
        placeholder: String,
        placement: Placement,
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in },
        initiallyFocused: Bool = false,
        @ViewBuilder chips: () -> Chips
    ) {
        self.query = query
        self.onQueryChange = onQueryChange
        self.placeholder = placeholder
        self.placement = placement
        self.onSearchActiveChange = onSearchActiveChange
        self.chips = chips()
        // OQ-media-home-9 (owner 2026-11-02): search starts active, as if the field were focused —
        // media-home's searchActiveEmpty state. Off by default, so no other consumer changes.
        _fieldFocused = State(initialValue: initiallyFocused)
    }

    /// §2 Search-active (reference rule 4): focused, or the query is non-empty.
    static func isSearchActive(query: String, focused: Bool) -> Bool {
        focused || !query.isEmpty
    }

    private var searchActive: Bool { Self.isSearchActive(query: query, focused: fieldFocused) }

    /// §2 Top inset: `space-page-margin` (16) under a screen-drawn header, 0 under the shell TopNav.
    private var topInset: CGFloat {
        switch placement {
        case .underShellTopNav: return 0
        case .underScreenHeader: return Token.Space.pageMargin
        }
    }

    // FLAGGED LITERAL — C-131 §2 (D7): opacity 0.8, which has no token (members-home's
    // "members-search-pinned" GAP).
    // (A computed static: a generic type cannot hold a stored one.)
    private static var materialScrimOpacity: Double { 0.8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §5: C-034 in its editable form — focus is the field's own; while search is active
            // the x always shows and ends the search.
            SearchField(
                text: query,
                placeholder: placeholder,
                focused: false,
                onChange: onQueryChange,
                onClear: { onQueryChange("") },
                showsClearWhenEmpty: searchActive,
                onFocusChange: { fieldFocused = $0 },
                clearDismisses: true,
                editable: true
            )
            .padding(.horizontal, Token.Space.pageMargin)        // §2: field side inset 16
            .ui2Element("Search field")

            // §2: field → rail gap `space-stack-gap` (16); rail full bleed (deviation 2).
            FilterRail { chips }
                .padding(.top, Token.Space.stackGap)
                .ui2Element("Filter rail")
        }
        .padding(.top, topInset)                                  // §2 Top inset (deviation 3)
        .padding(.bottom, Token.Space.pageMargin)                 // §2 Bottom inset 16
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { material }                                  // §2 Material (deviation 4)
        .pinnedBelowTopNav()                                      // §2 Pinning (deviation 4)
        .onChange(of: searchActive, initial: true) { _, active in onSearchActiveChange(active) }
        .ui2Element("SearchFilterHeader")
    }

    /// §2 Material: `.ultraThinMaterial` under `color-layout-background` at 0.8, filling the frame.
    private var material: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Token.layoutBackground.opacity(Self.materialScrimOpacity)
        }
    }
}
