//
//  LibraryHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen library-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: none ("Verified none. The screen reads and
//  writes no model and calls no endpoint.").
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Library — the Home tab's Library section root (§6, D51/D64): a temporary placeholder that
/// tells leaders the Library is coming. One C-132 EmptyState, centred in the content area. No
/// TopNav, no TabBar: the shell's `HomeSectionLayout` owns both (§1 deviation 1).
///
/// §3 names one state, `default`, and its copy is static, so `State` carries no field: there is
/// no value that differs between states.
struct LibraryHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone — §3's only state,
    /// `default`, needs none ("The copy is static").
    struct State {
        /// §3 `default` — the frozen frame.
        static let comingSoon = State()
    }

    let state: State

    // §3 Interactions: "none on the content … The screen adds no gesture, no pull-to-refresh and
    // no tap target." So there is no on<Verb> closure to expose.

    init(state: State) {
        self.state = state
    }

    // MARK: - §2 copy (static, screen-local — §5)

    /// §2 item 3 Title.
    private static let title = "Library coming soon"
    /// §2 item 3 Message.
    private static let message =
        "The library will be a place to explore community generated content and share your content with the community."

    var body: some View {
        // D22: no ScrollView — §2 item 2 "It does not scroll, because nothing overflows."
        EmptyState(glyph: .bookOpen, title: Self.title, message: Self.message)
            .ui2Element("C-132 EmptyState")
            // §2 item 3: "`space-page-margin` (16) on each side, so it is 408 wide."
            .padding(.horizontal, Token.Space.pageMargin)
            // §2 item 2/3: the content area "fills the remaining height"; the block is "centred
            // vertically in the content area".
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Token.layoutBackground)              // §2: "Background `color-layout-background`"
    }
}

#Preview("Coming soon") {
    LibraryHomeScreen(state: .comingSoon)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
