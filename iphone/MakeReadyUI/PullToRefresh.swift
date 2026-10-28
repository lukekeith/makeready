//
//  PullToRefresh.swift
//  MakeReadyUI — the UI 2.0 module
//
//  The ONE way a UI 2.0 list or scroll page reloads by pulling down (owner 2026-10-28,
//  OQ-study-program-home-19): the standard system pull-down-to-reload on the page's vertical
//  ScrollView. A failed load says "pull down to refresh" rather than drawing a Retry button, and
//  the same pull reloads a page that did not fail.
//
//  UI 2.0 screens have no root ScrollView (D22: the canvas is the content's full length), so the
//  screen exposes the reload as a closure (`onRetry`) and whoever owns the ScrollView — the app
//  container that hosts the screen — applies `.pullToRefresh(onRetry)` to it.
//

import SwiftUI

extension View {
    /// The standard pull-down-to-reload on the vertical ScrollView this modifies (or encloses).
    /// The spinner stays up until `action` returns.
    func pullToRefresh(_ action: @escaping @MainActor () async -> Void) -> some View {
        refreshable { await action() }
    }

    /// A screen's synchronous `onRetry`: the reload is the caller's, so the spinner only marks the
    /// pull — the page's own `loading` state shows the wait.
    func pullToRefresh(_ action: @escaping () -> Void) -> some View {
        refreshable { action() }
    }
}
