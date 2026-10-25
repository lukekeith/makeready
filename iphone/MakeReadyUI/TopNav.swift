//
//  TopNav.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-019-top-nav.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  Figma designs the two RESTING states only. Every transition rule — the morph, the gesture
//  model, the switch choreography — is §2c, restated from the behavior source
//  (docs/features/navigation/01-account-switcher-analysis.md) and ruled by OQ-C-019-5/6:
//  this view renders every `expansion` between the two designed endpoints.
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
    /// SHOW a slot is C-069 `hasAdd`, not this closure's presence.
    var onAdd: ((String) -> Void)?

    // §2 table: row leading/trailing inset — 8 (`px-8`, in the component) collapsed; "none
    // in the component" expanded, and none from the host (OQ-C-019-1, closed: one shared
    // inset — the first label sits 16pt from the row edge in both presentations).
    //
    // GAP — the 8pt row inset has no row in docs/ui2/design-system/tokens.md, so it cannot
    // resolve to a Token member by name (preview-build.md §3 rule 4). The spacing family's
    // only 8 is `space-element-gap`, which §2 already spends on this row's GAP — a different
    // role. Emitted as C-019 §2's own literal; reported by the run.
    private static let collapsedInset: CGFloat = 8
    // Owner ruling 2026-10-25 (ui2-shell): the expanded row keeps the first and last cards off
    // the screen edge by the same gap as between cards — `space-element-gap`, the row's GAP —
    // instead of §2's "none in the component". The first label drifts 16 → 25 over the morph.
    private static let expandedInset: CGFloat = Token.Space.elementGap

    var body: some View {
        // §2: "the row is horizontally scrollable and clips at the raw edges — no fade
        // mask". A real ScrollView, not an overflowing HStack: an HStack offered less than
        // its ideal width ACCEPTS the offer and centres its overflow, which clipped the row
        // at both ends and put Library, not Home, against the leading edge. A ScrollView
        // takes the width it is offered and lays its content out from the leading edge,
        // which is both the designed behaviour and the only construction that survives the
        // 656/1048-into-440 overflow.
        //
        // §2c proposed "a thin indicator under the row appears while panning, then fades"
        // (undesigned, OQ-C-019-6); owner ruling 2026-10-25: the row shows no scroll
        // indicator, so it is hidden.
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Token.Space.elementGap) {      // §2: gap = `space-element-gap` (8)
                    ForEach(tabs, id: \.self) { tab in
                        // C-069 §4: every tab takes the row's `expansion` unchanged — §2c "one
                        // row, two projections": 0→1 drives every tab at once — `hasAdd` per §1
                        // deviation 3, and routes its two actions out through this row's §4
                        // callbacks.
                        NavTabButton(
                            label: tab,
                            expansion: progress,
                            active: tab == selectedTab,
                            hasAdd: tab != Self.tabWithoutAdd,
                            onTap: { onSelect(tab) },
                            onAdd: { onAdd?(tab) }
                        )
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
            // §2c Switch (OQ-C-019-6): "the row auto-scrolls so the selected tab lands at the
            // leading edge". Panning never changes selection, so only a selection moves it.
            .onChange(of: selectedTab) { _, tab in
                withAnimation { proxy.scrollTo(tab, anchor: .leading) }
            }
        }
        // §2 table: row height 32 collapsed · 96 expanded, growing in step with the tabs
        // (§2c step 2: "the row height grows 32→96"), `items: center`.
        .frame(height: NavTabButton.height(at: progress))
        .background(Token.layoutBackground)                // §2: on `color-layout-background`
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpansion() }              // §4: "Tap toggles"
        .ui2Element("TopNav")                              // capture element map — UI2Element.swift
    }

    /// §4: `expansion` 0…1 — the designed symbols are its two endpoints and "every value
    /// between renders the §2c choreography" (OQ-C-019-5), which C-069 owns per tab.
    private var progress: CGFloat { min(max(CGFloat(expansion), 0), 1) }

    /// The row inset moves collapsed → expanded over C-069's growth window, while each tab's
    /// own padding grows 8 → 16, so the first label moves continuously through the morph.
    private var inset: CGFloat {
        let growth = NavTabButton.growth(at: progress)
        return Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
    }
}
