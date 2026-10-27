import SwiftUI

// topnav-height-env: the TopNav's live height, published to the section page the way a web page
// would publish a CSS variable. `HomeSectionLayout` writes how far the row has grown past its
// collapsed footprint on every frame of a drag or spring; a pinned or fixed element reads it so the
// row pushes it down instead of covering it.

extension EnvironmentValues {
    /// How far the TopNav row has grown past its collapsed height, in points. 0 when collapsed, when
    /// the row is hidden (Members' active search) and outside the shell (captures, previews).
    @Entry var topNavInset: CGFloat = 0
}

extension View {
    /// Keeps a pinned element below the TopNav as the row grows: pushes it down by exactly the part
    /// of `topNavInset` that would otherwise cover it, and leaves it alone once it already sits below.
    func pinnedBelowTopNav() -> some View {
        modifier(PinnedBelowTopNav())
    }
}

struct PinnedBelowTopNav: ViewModifier {
    @Environment(\.topNavInset) private var inset

    func body(content: Content) -> some View {
        let inset = inset
        // A render-time shift read from the element's live position in the page scroll — no layout
        // change, so the scroll view's content size and offset never move under the finger (D14).
        return content.visualEffect { effect, proxy in
            effect.offset(y: Self.shift(top: proxy.frame(in: .scrollView).minY, inset: inset))
        }
    }

    /// The push needed for an element whose top sits at `top` in the page scroll's visible
    /// coordinates while the row covers its first `inset` points — never more than the row grew,
    /// so a collapsed row moves nothing and an element scrolled above the page is never pulled in.
    nonisolated static func shift(top: CGFloat, inset: CGFloat) -> CGFloat {
        min(inset, max(0, inset - top))
    }
}
