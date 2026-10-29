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
    /// C-019 §4: `pin` — "keeps the tab under the finger under it while the morph is scrubbed".
    /// nil = no effect (owner 2026-10-29).
    var pin: Pin? = nil

    /// C-019 §4: `Pin { x: CGFloat (TopNav's own space), animation: Animation? }`.
    struct Pin: Equatable {
        var x: CGFloat
        var animation: Animation?
    }

    /// §4 `pin` 3: measured frames and hug widths in a non-observed reference box (ephemeral,
    /// R-02), so scrolling does not re-render the row.
    private final class PinBox {
        var frames: [String: CGRect] = [:]
        var hugs: [String: CGFloat] = [:]
        var viewport: CGFloat = 0
        /// §4 `pin` 1: the held (tab, f) while pinned.
        var held: (tab: String, f: CGFloat)?
    }
    @State private var box = PinBox()

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
            HorizontalRail {
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
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
                            record(tab, frame)
                        }
                    }
                }
                // §4: `scrollOffset` — "one shared offset across both presentations". A resting
                // render has no live scroll position to drive, so the offset is applied to the
                // content, which is what a scroll position IS for a static frame.
                .offset(x: -scrollOffset)
            }
            .scrollIndicators(.hidden)
            // §2 table: row leading/trailing inset — as content margins, not padding, so the
            // auto-scroll below lands the selected tab at the inset, not against the screen edge
            // (owner 2026-10-25, ui2-shell D14(e)).
            .contentMargins(.horizontal, inset, for: .scrollContent)
            // §2c Switch (OQ-C-019-6): "the row auto-scrolls so the selected tab lands at the
            // leading edge" — the inset's edge. Panning never changes selection, so only a
            // selection moves it.
            .onChange(of: selectedTab) { _, tab in
                withAnimation { proxy.scrollTo(tab, anchor: .leading) }
            }
            // §4 `pin` 1–2: hold the touched tab when the pin is set, then keep it under `pin.x`
            // on every `expansion` change.
            .onChange(of: pin) { old, new in
                guard let new else { box.held = nil; return }
                if old == nil { box.held = pinnedTab(at: new.x) }
                scrollToPin(new, proxy)
            }
            .onChange(of: expansion) { _, _ in
                if let pin { scrollToPin(pin, proxy) }
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { box.viewport = $0 }
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

    /// TopNav's own space — `pin.x` and the measured tab frames.
    private static let space = "TopNav.pin"

    /// §4 `pin` 2: a tab's collapsed width, cached from measured frames — read back through
    /// C-069's growth (w = hug + (124 − hug)·growth); a fully grown frame carries no hug.
    private func record(_ tab: String, _ frame: CGRect) {
        box.frames[tab] = frame
        let growth = NavTabButton.growth(at: progress)
        if growth < 0.999 {
            box.hugs[tab] = (frame.width - Self.expandedWidth * growth) / (1 - growth)
        }
    }

    /// §4 `pin` 1: the tab whose visible frame contains `x` — the nearest tab in a gap or past
    /// either end — and `f = (x − tab.minX) / tab.width`.
    private func pinnedTab(at x: CGFloat) -> (tab: String, f: CGFloat)? {
        let measured = tabs.compactMap { tab in box.frames[tab].map { (tab, $0) } }
        let hit = measured.first { $0.1.minX <= x && x <= $0.1.maxX }
            ?? measured.min { distance(x, $0.1) < distance(x, $1.1) }
        guard let (tab, frame) = hit, frame.width > 0 else { return nil }
        return (tab, (x - frame.minX) / frame.width)
    }

    private func distance(_ x: CGFloat, _ frame: CGRect) -> CGFloat {
        x < frame.minX ? frame.minX - x : max(0, x - frame.maxX)
    }

    /// §4 `pin` 2: scroll so `tab.minX = pin.x − f·w` at the current `expansion`, inside
    /// `withAnimation(pin.animation)`. `scrollTo` aligns the tab's anchor with the same anchor
    /// of the inset viewport, so the anchor solving `minX = inset + a·(V − 2·inset − w)` lands
    /// it there. Clamping at the scroll ends is accepted.
    private func scrollToPin(_ pin: Pin, _ proxy: ScrollViewProxy) {
        guard let (tab, f) = box.held else { return }
        let growth = NavTabButton.growth(at: progress)
        let hug = box.hugs[tab] ?? box.frames[tab]?.width ?? Self.expandedWidth
        let width = hug + (Self.expandedWidth - hug) * growth
        let span = box.viewport - 2 * inset - width
        guard span > 0 else { return }
        let anchor = UnitPoint(x: (pin.x - f * width - inset) / span, y: 0.5)
        withAnimation(pin.animation) { proxy.scrollTo(tab, anchor: anchor) }
    }

    // GAP — C-069 §2: "fixed 124×96" expanded card, the end of every tab's growth; C-019 §4
    // `pin` restates it (w = hug + (124 − hug)·growth). C-069 keeps its geometry private.
    private static let expandedWidth: CGFloat = 124

    /// The row inset moves collapsed → expanded over C-069's growth window, while each tab's
    /// own padding grows 8 → 16, so the first label moves continuously through the morph.
    private var inset: CGFloat {
        let growth = NavTabButton.growth(at: progress)
        return Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
    }
}
