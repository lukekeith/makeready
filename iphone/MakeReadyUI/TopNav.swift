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
    /// C-019 §4: `pin` — holds one tab horizontally fixed while the row morphs.
    /// nil = no effect (owner 2026-10-29).
    var pin: Pin? = nil

    /// C-019 §4: `Pin { x: CGFloat = 0 (TopNav's own space), tab: String? = nil, animation: Animation? }`.
    /// `tab` nil = the finger pin (holds the tab under `x`); set = the named-tab pin (holds
    /// that tab where it sits, `x` ignored).
    struct Pin: Equatable {
        var x: CGFloat = 0
        var tab: String? = nil
        var animation: Animation?

        /// §4 `pin` identity: a change of tab, or of a finger pin's `x`, re-holds; a change
        /// of `animation` alone (the release settle) keeps the hold.
        func sameHold(as other: Pin) -> Bool {
            tab == other.tab && (tab != nil || x == other.x)
        }
    }

    /// §4 `pin` 3: measured frames and hug widths in a non-observed reference box (ephemeral,
    /// R-02), so scrolling does not re-render the row.
    private final class PinBox {
        var frames: [String: CGRect] = [:]
        var hugs: [String: CGFloat] = [:]
        var viewport: CGFloat = 0
        /// §4 `pin` 1: the held (tab, f) and held x while pinned.
        var held: (tab: String, f: CGFloat, x: CGFloat)?
        /// §4 `pin` x-lock 1: the locked tab's index, its measured minX and its analytic content
        /// position at hold time; nil for an unlocked hold (§4 x-lock 5).
        var lock: (index: Int, minX0: CGFloat, pos0: CGFloat)?
    }
    @State private var box = PinBox()
    /// §2 "Scroll range": the two measured inputs the trailing room is solved from — observed
    /// (unlike `box`), because the room is layout. Neither changes on a pan or a morph frame:
    /// the last tab's width `w` is computed from `lastTabHug` in the same pass (never read back
    /// from its frame, which is one frame stale mid-morph), so no morph frame writes state (R-02).
    @State private var viewportWidth: CGFloat = 0
    @State private var lastTabHug: CGFloat = 0

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
                HStack(spacing: 0) {
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
                            // §2: only the collapsed hug is measured, written only on a
                            // > 0.5pt change, so a morph frame never writes state.
                            if tab == tabs.last, let hug = box.hugs[tab],
                               abs(hug - lastTabHug) > 0.5 {
                                lastTabHug = hug
                            }
                        }
                    }
                }
                // §4: `scrollOffset` — "one shared offset across both presentations". A resting
                // render has no live scroll position to drive, so the offset is applied to the
                // content, which is what a scroll position IS for a static frame.
                .offset(x: -scrollOffset)
                // §2 "Scroll range" (owner 2026-11-09): trailing room so the LAST tab can sit at
                // the leading inset, the same x as every other selected tab. With the trailing
                // content margin (`inset`) this makes the trailing margin
                // `viewport − inset − last tab width` — recomputed as `expansion` moves that width.
                Color.clear.frame(width: trailingRoom, height: 0)
                }
                // §4 `pin` x-lock 4 / §2c x-lock: while a pin holds no `scrollTo` runs; the row
                // takes `.offset(x: −(lockShift − lockShiftCollapsed))` in the same layout pass as
                // the new widths, so the held tab has zero lag. ScrollXLockRelease moves the real
                // offset at the hold and the release.
                .offset(x: -((lockShift ?? 0) - (lockShiftCollapsed ?? 0)))
                .background(ScrollXLockRelease(shift: lockShift, base: lockShiftCollapsed))
            }
            .scrollIndicators(.hidden)
            // §2 table: row leading/trailing inset — as content margins, not padding, so the
            // auto-scroll below lands the selected tab at the inset, not against the screen edge
            // (owner 2026-10-25, ui2-shell D14(e)). The trailing room above extends the range;
            // the margins stay symmetric so the `scrollTo` anchor solves below hold.
            .contentMargins(.horizontal, inset, for: .scrollContent)
            // §2c Switch (OQ-C-019-6): "the row auto-scrolls so the selected tab lands at the
            // leading inset" — every tab, the last included (§2 trailing room). Panning never
            // changes selection, so only a selection moves it.
            .onChange(of: selectedTab) { _, tab in
                withAnimation { proxy.scrollTo(tab, anchor: .leading) }
            }
            // §4 `pin` 1–2: (re)hold when the pin's identity changes — the touched tab under
            // `pin.x`, or the named tab where it sits — then keep it at the held x on every
            // `expansion` change. §4 `pin` 5: on release, hand the row back to the selected tab.
            .onChange(of: pin) { old, new in
                guard let new else {
                    box.held = nil
                    // §4 `pin` x-lock 4–5: a locked release already moved the shift into the
                    // scroll offset (ScrollXLockRelease); only an unlocked hold re-anchors.
                    if box.lock == nil { reanchorOnSelection(proxy) }
                    box.lock = nil
                    return
                }
                if old.map({ !$0.sameHold(as: new) }) ?? true {
                    box.held = hold(new)
                    box.lock = makeLock(new)
                }
                if box.lock == nil { scrollToPin(new, proxy) }
            }
            .onChange(of: expansion) { _, _ in
                if let pin, box.lock == nil { scrollToPin(pin, proxy) }
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            box.viewport = $0
            viewportWidth = $0
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

    /// TopNav's own space — `pin.x` and the measured tab frames.
    private static let space = "TopNav.pin"

    /// §4 `pin` 2: a tab's collapsed width, cached from measured frames — read back through
    /// C-069's growth (w = hug + (124 − hug)·growth); a fully grown frame carries no hug.
    private func record(_ tab: String, _ frame: CGRect) {
        box.frames[tab] = frame
        let growth = NavTabButton.growth(at: progress)
        // §4 `pin` x-lock 2: hugs are read back only while g < 0.5 — 1/(1−g) amplifies
        // sub-point rounding as g → 1.
        if growth < 0.5 {
            box.hugs[tab] = (frame.width - Self.expandedWidth * growth) / (1 - growth)
        }
    }

    /// §4 `pin` 1: the hold a pin makes — a named tab at its measured `minX` with `f = 0`
    /// (unmeasured holds nothing), else the finger's tab at `pin.x`.
    private func hold(_ pin: Pin) -> (tab: String, f: CGFloat, x: CGFloat)? {
        if let tab = pin.tab {
            return box.frames[tab].map { (tab, 0, $0.minX) }
        }
        return pinnedTab(at: pin.x).map { ($0.tab, $0.f, pin.x) }
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

    /// §4 `pin` 2: scroll so `tab.minX = held x − f·w` at the current `expansion`, inside
    /// `withAnimation(pin.animation)`. `scrollTo` aligns the tab's anchor with the same anchor
    /// of the inset viewport, so the anchor solving `minX = inset + a·(V − 2·inset − w)` lands
    /// it there. §2c (owner 2026-11-09): no clamp for trailing tabs — the §2 trailing room
    /// lets the last tab reach the leading inset.
    private func scrollToPin(_ pin: Pin, _ proxy: ScrollViewProxy) {
        guard let (tab, f, x) = box.held else { return }
        let growth = NavTabButton.growth(at: progress)
        let hug = box.hugs[tab] ?? box.frames[tab]?.width ?? Self.expandedWidth
        let width = hug + (Self.expandedWidth - hug) * growth
        let span = box.viewport - 2 * inset - width
        guard span > 0 else { return }
        let anchor = UnitPoint(x: (x - f * width - inset) / span, y: 0.5)
        withAnimation(pin.animation) { proxy.scrollTo(tab, anchor: anchor) }
    }

    /// §4 `pin` 5 (owner 2026-10-29): on release, re-anchor the scroll on the SELECTED tab
    /// where it currently sits — no movement, no animation. `scrollTo` leaves the ScrollView
    /// re-applying its last target whenever the content size changes; the pin's
    /// `scrollTo(heldTab, anchor: a)` replaced the selection's, so later morphs jumped sideways.
    /// Same anchor solve as `scrollToPin`; skipped when unmeasured or the span is ≤ 0.
    private func reanchorOnSelection(_ proxy: ScrollViewProxy) {
        guard let frame = box.frames[selectedTab] else { return }
        let span = box.viewport - 2 * inset - frame.width
        guard span > 0 else { return }
        let anchor = UnitPoint(x: (frame.minX - inset) / span, y: 0.5)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(selectedTab, anchor: anchor) }
    }

    /// §4 `pin` x-lock 1: a named-tab hold locks the row's x so the tab sits at the leading
    /// inset through the whole morph (§2c x-lock). Nil — an unlocked hold (§4 x-lock 5) — until
    /// the tab and every preceding tab's hug are measured.
    private func makeLock(_ pin: Pin) -> (index: Int, minX0: CGFloat, pos0: CGFloat)? {
        guard let tab = pin.tab, let index = tabs.firstIndex(of: tab),
              let frame = box.frames[tab], let pos = contentPosition(index) else { return nil }
        return (index, frame.minX, pos)
    }

    /// §4 `pin` x-lock 2 `contentPosition(index, at:)`: the tab's leading x in the row's
    /// content at the current `expansion`, inset included.
    private func contentPosition(_ index: Int, at expansion: CGFloat? = nil) -> CGFloat? {
        let growth = NavTabButton.growth(at: expansion ?? progress)
        var x = Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
        for tab in tabs.prefix(index) {
            guard let hug = box.hugs[tab] else { return nil }
            x += hug + (Self.expandedWidth - hug) * growth + Token.Space.elementGap
        }
        return x
    }

    /// §4 `pin` x-lock 3 `lockShift`: the leftward shift since the hold that keeps the locked
    /// tab at the leading inset; nil when no pin holds (the pin is a prop, so its release
    /// re-renders the row).
    private var lockShift: CGFloat? {
        guard pin != nil, let lock = box.lock, let pos = contentPosition(lock.index) else { return nil }
        return pos - lock.pos0 + lock.minX0 - inset
    }

    /// §4 `pin` x-lock 3 `lockShiftCollapsed`: the same shift at g = 0 with the collapsed
    /// inset. The real scroll offset moves by this at the hold (x-lock 4) — the collapsed
    /// position is inside the scroll range at every `expansion`, so nothing clamps.
    private var lockShiftCollapsed: CGFloat? {
        guard pin != nil, let lock = box.lock, let pos = contentPosition(lock.index, at: 0) else { return nil }
        return pos - lock.pos0 + lock.minX0 - Self.collapsedInset
    }

    // GAP — C-069 §2: "fixed 124×96" expanded card, the end of every tab's growth; C-019 §4
    // `pin` restates it (w = hug + (124 − hug)·growth). C-069 keeps its geometry private.
    private static let expandedWidth: CGFloat = 124

    /// §2 "Scroll range": the spacer after the last tab. Content ends at the trailing margin
    /// `inset + room = viewport − inset − w(last)`, so the furthest pan puts the last tab's minX
    /// at the leading inset and no further. `w = hug + (124 − hug)·growth(at: expansion)` — the
    /// `scrollToPin` formula — computed in this pass, so content size, max offset and the pin
    /// solve share one frame's width. 0 until the viewport (and, before full growth, the hug)
    /// is measured.
    private var trailingRoom: CGFloat {
        let growth = NavTabButton.growth(at: progress)
        guard viewportWidth > 0, lastTabHug > 0 || growth >= 0.999 else { return 0 }
        let width = lastTabHug + (Self.expandedWidth - lastTabHug) * growth
        return max(0, viewportWidth - 2 * inset - width)
    }

    /// The row inset moves collapsed → expanded over C-069's growth window, while each tab's
    /// own padding grows 8 → 16, so the first label moves continuously through the morph.
    private var inset: CGFloat {
        let growth = NavTabButton.growth(at: progress)
        return Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
    }
}

/// C-019 §4 `pin` x-lock 4: on the hold (base nil → value) moves the scroll offset by `base`
/// (`lockShiftCollapsed`); while held the row's `.offset` covers `shift − base`; on release
/// (→ nil, `.offset` → 0 in the same update) moves the scroll by the last `shift − base`, so
/// nothing moves visibly. Both writes are `UIScrollView.contentOffset` changes.
private struct ScrollXLockRelease: UIViewRepresentable {
    let shift: CGFloat?
    let base: CGFloat?

    final class Coordinator { var last: (shift: CGFloat, base: CGFloat)? }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        if let shift, let base {
            if coordinator.last == nil { move(view, by: base) }
            coordinator.last = (shift, base)
            return
        }
        guard let last = coordinator.last else { return }
        coordinator.last = nil
        move(view, by: last.shift - last.base)
    }

    private func move(_ view: UIView, by delta: CGFloat) {
        var ancestor = view.superview
        while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
        guard let scrollView = ancestor as? UIScrollView, delta != 0 else { return }
        scrollView.contentOffset.x += delta
    }
}
