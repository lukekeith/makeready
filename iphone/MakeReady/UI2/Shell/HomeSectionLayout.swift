import SwiftUI

/// SPEC D11/D12: the TopNav row over the section content — the one place the two layout facts
/// home-dashboard's frame draws between them live, shared by the shell and the capture harness.
///
/// Off the Home tab the row and its gap collapse to zero height, hidden and inert, but stay
/// mounted, so switching back restores the section AND the row's own horizontal scroll
/// position (D12: TopNav's position lives in its own ScrollView, not in `scrollOffset`).
struct HomeSectionLayout<Content: View>: View {
    @Binding var model: UI2ShellModel
    /// home-dashboard-data D24: the page's pull-to-refresh; nil = the page does not refresh.
    var onRefresh: (@MainActor () async -> Void)?
    @ViewBuilder var content: Content

    /// The host's horizontal inset around C-019 TopNav: none.
    ///
    /// The frozen home-dashboard frame (440pt wide) draws the first tab label's ink at x=16.
    /// C-019 already puts it there: collapsed = row inset 8 (TopNav `collapsedInset`) + C-069
    /// label padding 8 (`space-element-gap`) = 16; expanded = row inset 8 (`expandedInset`,
    /// owner ruling 2026-10-25: the card gap) + label padding 16 (`space-card-padding`) + the
    /// card's 1px border = 25. Any host inset H adds to both (16 + H, 25 + H), so H = 0 is the
    /// only value that keeps the collapsed label on the frame's x=16 (OQ-C-019-1: "none from
    /// the host"). The pre-12b screen's
    /// `.padding(.horizontal, 8)` put the collapsed label at 24, 8pt right of the frame.
    static var navHostInset: CGFloat { 0 }

    // GAP — home-dashboard frame default: 16 between the nav row and the first section header,
    // no vertical-spacing token.
    static var navGap: CGFloat { 16 }

    /// The row's resting footprint: the collapsed row + its gap. The page always starts here.
    static var collapsedFootprint: CGFloat { NavTabButton.height(at: 0) + navGap }

    var body: some View {
        if model.showsTopNav {
            // SPEC D14, revised 2026-10-25: the row floats over the page and the page's scroll
            // view never moves or resizes — moving it under a finger read as a finger jump and
            // flung the page (on-device recording, 3.75s). The page CONTENT slides down by the
            // row's growth instead. One section, one scroll: a switch starts the new page at its
            // top (the row is outside the `id`, so it keeps its own scroll position, D12).
            ZStack(alignment: .top) {
                SectionPageScroll(model: $model, growth: growth, onRefresh: onRefresh) { content }
                    .id(model.section)
                    .padding(.top, Self.collapsedFootprint)
                navRow.background(Token.layoutBackground)
            }
        } else {
            VStack(spacing: 0) {
                navRow
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// How far the row has grown past its collapsed height. A row drag writes `model.expansion`
    /// live, so the page follows the finger and the spring from the one value the row draws.
    private var growth: CGFloat {
        NavTabButton.height(at: min(1, max(0, model.expansion))) - NavTabButton.height(at: 0)
    }

    private var navRow: some View {
        VStack(spacing: 0) {
            TopNavHost(model: $model)
                .padding(.horizontal, Self.navHostInset)
            Spacer().frame(height: Self.navGap)
        }
        .frame(height: model.showsTopNav ? nil : 0, alignment: .top)
        .clipped()
        .opacity(model.showsTopNav ? 1 : 0)
        .allowsHitTesting(model.showsTopNav)
        .accessibilityHidden(!model.showsTopNav)
    }
}

/// SPEC D14, revised 2026-10-25 against the owner's reference recording
/// (`Design reference/Navigation/navigation feel.MP4`) — the page's own scroll triggers the
/// morph, and the page keeps its native scroll and bounce throughout:
/// (a) pulling past the page top by `expandPull` springs the row open (10.79–10.92s: the morph
///     fires on a short pull while the page keeps rubber-banding under the finger);
/// (c) scrolling the page up by `collapseScroll` while the row is open springs it shut as the
///     page scrolls on (8.27–8.40s: collapse and scroll run together).
/// The page always bounces (`.always`), so a page shorter than the screen — EmptyPage — pulls too.
///
/// This scroll view's frame and insets never change, so its offset is the finger's alone and
/// nothing the morph does reads back into it. The row's growth reaches the page as a visual
/// offset on the content (`growth`), which the scroll never measures.
private struct SectionPageScroll<Content: View>: View {
    @Binding var model: UI2ShellModel
    let growth: CGFloat
    let onRefresh: (@MainActor () async -> Void)?
    @ViewBuilder var content: Content

    // GAP — home-dashboard-data D24: no pull-to-refresh in C-019 or the analysis. A pull this far
    // past the top arms it (well past `expandPull`, so a pull first opens the row, then refreshes);
    // releasing armed runs it. The system refresh control would sit under the floating row.
    static var refreshPull: CGFloat { 72 }
    // GAP — the room the content makes below the row for the spinner while it refreshes.
    static var refreshGap: CGFloat { 48 }

    @State private var refreshArmed = false
    @State private var refreshing = false

    // GAP — no pull distance in C-019 or the analysis; the reference fires on a short pull
    // (10.62–10.79s shows the page barely moved before the morph): 12pt past the top.
    static var expandPull: CGFloat { 12 }
    // GAP — the reference collapses as soon as the page moves up: 8pt, past touch jitter.
    static var collapseScroll: CGFloat { 8 }
    // GAP — the reference's page-triggered morph settles in ~130ms (10.79→10.92s, 60fps); the
    // row drag keeps `TopNavHost.morphSpring`.
    static var triggerSpring: Animation { .spring(duration: 0.15, bounce: 0) }

    @State private var phase: ScrollPhase = .idle

    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .top) {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .offset(y: growth + (refreshing ? Self.refreshGap : 0))
                if refreshArmed || refreshing {
                    ActivitySpinner()
                        .offset(y: growth + (Self.refreshGap - 24) / 2)
                        .transition(.opacity)
                        .accessibilityLabel("Refreshing")
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.always, axes: .vertical)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            react(to: offset)
        }
        .onScrollPhaseChange { _, new in
            phase = new
            if new != .interacting, refreshArmed { startRefresh() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: refreshArmed) { _, armed in armed }
    }

    private func startRefresh() {
        refreshArmed = false
        guard let onRefresh, !refreshing else { return }
        withAnimation(TopNavHost.morphSpring) { refreshing = true }
        Task { @MainActor in
            await onRefresh()
            withAnimation(TopNavHost.morphSpring) { refreshing = false }
        }
    }

    private func react(to offset: CGFloat) {
        if onRefresh != nil, !refreshing, phase == .interacting, offset <= -Self.refreshPull, !refreshArmed {
            withAnimation(.easeOut(duration: 0.15)) { refreshArmed = true }
        }
        if model.expansion == 0, phase == .interacting, offset <= -Self.expandPull {
            withAnimation(Self.triggerSpring) { model.expansion = 1 }
        } else if model.expansion == 1, offset >= Self.collapseScroll {
            withAnimation(Self.triggerSpring) { model.expansion = 0 }
        }
    }
}
