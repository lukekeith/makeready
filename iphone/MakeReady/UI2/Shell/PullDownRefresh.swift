//
//  PullDownRefresh.swift
//  MakeReady
//
//  The app's one pull-down-to-reload (owner 2026-10-28), the way iPhone apps do it:
//  1. pull to the full pull — a light tap says it is armed and can be let go;
//  2. let go — the page holds open below the spinner, which spins until the reload returns;
//  3. then the page animates back up and the spinner dissolves with it.
//  The spinner is fixed near the top of the scroll view (it never rides on the content), the
//  standard system spinner in the muted text colour. It stays hidden while pulling and appears
//  only once the pull arms, with the tap (owner 2026-10-29) — a pull let go short of it shows nothing.
//

import SwiftUI

/// How a page gets the pull-down reload:
/// - a page with its own vertical ScrollView applies `.pullDownRefresh { … }` to it;
/// - a page the shell scrolls for it (a TopNav section) declares `.pageRefresh { … }`, and the
///   shell's page scroll runs it. A page that declares nothing does not refresh.
extension View {
    /// Declares this page's reload for the scroll view hosting it (the shell's section scroll).
    func pageRefresh(_ action: @escaping @MainActor () async -> Void) -> some View {
        preference(key: PageRefreshKey.self, value: PageRefresh(action: action))
    }

    /// Pull-down-to-reload on the vertical ScrollView this modifies. `spinnerTop` is where the
    /// revealed gap starts inside the scroll view's frame (below a floating row, say).
    func pullDownRefresh(spinnerTop: CGFloat = 0,
                         _ action: (@MainActor () async -> Void)?) -> some View {
        modifier(PullDownRefresh(spinnerTop: spinnerTop, action: action))
    }
}

/// A page's declared reload. Equal by identity of the declaring page, never by the closure: the
/// closure reads the page's state when it runs, so a stale copy still reloads what is on screen.
struct PageRefresh: Equatable {
    let action: @MainActor () async -> Void
    static func == (lhs: PageRefresh, rhs: PageRefresh) -> Bool { true }
}

struct PageRefreshKey: PreferenceKey {
    static var defaultValue: PageRefresh? { nil }
    static func reduce(value: inout PageRefresh?, nextValue: () -> PageRefresh?) {
        value = value ?? nextValue()
    }
}

private struct PullDownRefresh: ViewModifier {
    let spinnerTop: CGFloat
    let action: (@MainActor () async -> Void)?

    // GAP — no pull distance in any spec: the full pull, where the reload arms. The page holds
    // open by the same distance while it reloads, so the spinner never moves.
    static var fullPull: CGFloat { 72 }
    // GAP — the spinner's fade in when the pull arms.
    static var appear: Animation { .easeOut(duration: 0.15) }
    // GAP — the page's return once the reload is done.
    static var settle: Animation { .spring(duration: 0.35, bounce: 0) }

    @State private var phase: ScrollPhase = .idle
    /// Reached the full pull with the finger down; runs on release.
    @State private var armed = false
    /// Reloading: the page holds open by `fullPull` and the spinner shows in full.
    @State private var refreshing = false

    func body(content: Content) -> some View {
        content
            // The hold: a top inset the scroll view settles against, as the system control does.
            .contentMargins(.top, refreshing ? Self.fullPull : 0, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, new in
                if action != nil, !refreshing, !armed, phase == .interacting, new >= Self.fullPull {
                    withAnimation(Self.appear) { armed = true }
                }
            }
            .onScrollPhaseChange { _, new in
                phase = new
                if new != .interacting, armed { start() }
            }
            .overlay(alignment: .top) {
                // Hidden until the pull arms (owner 2026-10-29: not before the tap).
                if action != nil, armed || refreshing {
                    ProgressView()
                        .tint(Token.textSecondary)
                        .frame(width: 24, height: 24)
                        .offset(y: spinnerTop + (Self.fullPull - 24) / 2)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Refreshing")
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, isArmed in isArmed }
    }

    private func start() {
        armed = false
        guard let action, !refreshing else { return }
        refreshing = true
        Task { @MainActor in
            await action()
            withAnimation(Self.settle) { refreshing = false }
        }
    }
}
