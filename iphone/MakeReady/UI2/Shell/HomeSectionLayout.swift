import SwiftUI

/// SPEC D11/D12: the TopNav row over the section content — the one place the two layout facts
/// home-dashboard's frame draws between them live, shared by the shell and the capture harness.
///
/// Off the Home tab the row and its gap collapse to zero height, hidden and inert, but stay
/// mounted, so switching back restores the section AND the row's own horizontal scroll
/// position (D12: TopNav's position lives in its own ScrollView, not in `scrollOffset`).
struct HomeSectionLayout<Content: View>: View {
    @Binding var model: UI2ShellModel
    @ViewBuilder var content: Content

    /// The host's horizontal inset around C-019 TopNav: none.
    ///
    /// The frozen home-dashboard frame (440pt wide) draws the first tab label's ink at x=16.
    /// C-019 already puts it there: collapsed = row inset 8 (TopNav `collapsedInset`) + C-069
    /// label padding 8 (`space-element-gap`) = 16; expanded = row inset 0 (`expandedInset`) +
    /// label padding 16 (`space-card-padding`) + the card's 1px border = 17 — the card itself
    /// starts at the row edge, so the 1pt is the card's own border, not a host offset. Any
    /// host inset H adds to both (16 + H, 17 + H), so H = 0 is the only value that keeps the
    /// collapsed label on the frame's x=16 and the expanded one on C-069's 16-inside-the-border
    /// (OQ-C-019-1, closed: "one shared inset … none from the host"). The pre-12b screen's
    /// `.padding(.horizontal, 8)` put the collapsed label at 24, 8pt right of the frame.
    static var navHostInset: CGFloat { 0 }

    // GAP — home-dashboard frame default: 16 between the nav row and the first section header,
    // no vertical-spacing token.
    static var navGap: CGFloat { 16 }

    var body: some View {
        VStack(spacing: 0) {
            navRow
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
