//
//  TopNav.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-019-top-nav.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  Figma designs the two RESTING states only. Every transition rule — the finger-tracked
//  morph, the gesture model, the switch choreography — lives in the behavior source
//  (docs/features/navigation/01-account-switcher-analysis.md) and is undesigned here
//  (OQ-C-019-5/6), so this view renders the two designed endpoints and nothing between.
//

import SwiftUI

/// C-019 TopNav — the app's primary switcher: one scrollable tab row in two presentations.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no page background and adds no outer padding. §2's content width exceeds
/// the device in both presentations (656 / 1048 against 440), so the row clips at the raw
/// edges — which is the design, not a truncation.
struct TopNav: View {

    /// C-019 §2: "Row order (closed, 8 tabs)". §1 deviation 4 — the labels and their order
    /// are content, contracted here because they are a program-level fact; this constant is
    /// the contract's list, not a default the view imposes.
    static let designedTabs = [
        "Home", "Library", "Groups", "Members", "Enrollments", "Invites", "Programs", "Media"
    ]

    /// §1 deviation 3 / §2b: "hidden on Home in the row" — the one tab whose expanded card
    /// carries no add slot (OQ-C-019-2 closed it: the add action is per-tab, Home has none).
    static let tabWithoutAdd = "Home"

    /// C-019 §4: `tabs` — "Order is the designed order".
    let tabs: [String]
    /// C-019 §4: `selectedTab` — "Exactly one; sets C-069 `active=true` on that tab".
    let selectedTab: String
    /// C-019 §4: `expansion` 0…1 — "the morph as a continuous value, NOT a boolean".
    let expansion: Double
    /// C-019 §4: `scrollOffset` — "One shared offset across both presentations; panning
    /// never changes selection".
    let scrollOffset: CGFloat
    /// C-019 §4: `onSelect(tab)`. No render effect — a defaulted no-op so the promoted view
    /// keeps its real signature (preview-build.md OQ-PB-3's proposed default).
    var onSelect: (String) -> Void = { _ in }
    /// C-019 §4: `onToggleExpansion`. No render effect (OQ-PB-3).
    var onToggleExpansion: () -> Void = {}
    /// C-019 §4: `onAdd(tab)` — "absent for Home". No render effect (OQ-PB-3); which cards
    /// SHOW a slot is §2b's rule, not this closure's presence — see `addAction(for:)`.
    var onAdd: ((String) -> Void)?

    // §2 table: row height 32 collapsed · 96 expanded.
    private static let collapsedHeight: CGFloat = 32
    private static let expandedHeight: CGFloat = 96

    // §2 table: row leading/trailing inset — 8 (`px-8`, in the component) collapsed; "none
    // in the component" expanded (the home-dashboard instance adds 16 — OQ-C-019-1, which
    // asks whether the two presentations should share one inset; the component is built as
    // designed, asymmetry included).
    //
    // GAP — the 8pt row inset has no row in docs/ui2/design-system/tokens.md, so it cannot
    // resolve to a Token member by name (preview-build.md §3 rule 4). The spacing family's
    // only 8 is `space-element-gap`, which §2 already spends on this row's GAP — a different
    // role. Emitted as C-019 §2's own literal; reported by the run.
    private static let collapsedInset: CGFloat = 8
    private static let expandedInset: CGFloat = 0

    var body: some View {
        // §2: "the row is horizontally scrollable and clips at the raw edges — no fade
        // mask". A real ScrollView, not an overflowing HStack: an HStack offered less than
        // its ideal width ACCEPTS the offer and centres its overflow, which clipped the row
        // at both ends and put Library, not Home, against the leading edge. A ScrollView
        // takes the width it is offered and lays its content out from the leading edge,
        // which is both the designed behaviour and the only construction that survives the
        // 656/1048-into-440 overflow.
        //
        // §3's scroll indicator is UNDESIGNED (OQ-C-019-6), so none is rendered: showing
        // the system one would invent the treatment that OQ waits on.
        ScrollView(.horizontal) {
            HStack(spacing: Token.Space.elementGap) {      // §2: gap = `space-element-gap` (8)
                ForEach(tabs, id: \.self) { tab in
                    NavTabButton(
                        label: tab,
                        presentation: presentation,
                        active: tab == selectedTab,
                        addAction: addAction(for: tab)
                    )
                    .contentShape(Rectangle())
                    // §4: `onSelect(tab)`. A tap gesture rather than a Button because §3's
                    // pressed state is UNDESIGNED (OQ-C-019-4) — a button style would render
                    // a press treatment the contract has not ruled on, and the add slot's own
                    // GlyphButton is already a Button nested inside this row.
                    .onTapGesture { onSelect(tab) }
                }
            }
            // §2 table: row leading/trailing inset.
            .padding(.horizontal, inset)
            // §4: `scrollOffset` — "one shared offset across both presentations". A resting
            // render has no live scroll position to drive, so the offset is applied to the
            // content, which is what a scroll position IS for a static frame.
            .offset(x: -scrollOffset)
        }
        .scrollIndicators(.hidden)
        // §2 table: row height 32 collapsed · 96 expanded, `items: center`.
        .frame(height: height)
        .background(Token.layoutBackground)                // §2: on `color-layout-background`
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpansion() }              // §4: "Tap toggles"
        .ui2Element("TopNav")                              // capture element map — UI2Element.swift
    }

    /// §4: the designed symbols are `expansion`'s two ENDPOINTS. §3's morph intermediate is
    /// undesigned (OQ-C-019-5), so this resolves to the nearer designed endpoint rather than
    /// interpolating: rendering an in-between would invent the ruling that OQ waits on
    /// (preview-build.md §3 rule 7).
    private var presentation: NavTabButton.Presentation {
        expansion >= 0.5 ? .expanded : .collapsed
    }

    private var height: CGFloat {
        presentation == .expanded ? Self.expandedHeight : Self.collapsedHeight
    }

    private var inset: CGFloat {
        presentation == .expanded ? Self.expandedInset : Self.collapsedInset
    }

    /// §2b: the add slot is designed on every EXPANDED card; §1 deviation 3: the row hides
    /// it on Home. Whether a slot renders is that rule — not whether a consumer happened to
    /// pass `onAdd`, which is an interaction prop with no render effect (OQ-PB-3). So the
    /// closure returned here is non-nil wherever the design shows a slot, and forwards to
    /// `onAdd` only if one was supplied.
    private func addAction(for tab: String) -> (() -> Void)? {
        guard presentation == .expanded, tab != Self.tabWithoutAdd else { return nil }
        return { onAdd?(tab) }
    }
}
