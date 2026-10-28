import SwiftUI

/// ui2-groups-browse §iphone Groups home: the Home tab's Groups section (D3, D20, D22).
/// Cache-first: renders `AppState.groups` at once, then loads groups, leaders and the caller's
/// orgs. The screen has no root scroll — the shell's page scroll (HomeSectionLayout) scrolls it.
/// A row tap pushes `destination(id, name)` on this tab's stack (UI2Shell passes `.groupDetail`).
struct GroupsHomeContainer: View {
    /// D3: the search applies this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)
    /// D22: the banner over a list whose load failed.
    static let loadFailedMessage = "Couldn't load your groups"

    /// D1: the page a row opens.
    let destination: (_ id: String, _ name: String) -> UI2Destination

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// The text as typed (the field shows it); `selection.search` is the debounced copy.
    @State private var typedSearch = ""
    @State private var selection = GroupsHomeMapper.Selection()
    /// The pending debounce; a newer keystroke cancels it (Task + `Task.sleep`, never `asyncAfter`).
    @State private var searchTask: Task<Void, Never>?
    /// groups-home §3 Search active: while search is active the shell's TopNav moves off screen.
    @State private var searchActive = false

    var body: some View {
        let app = AppState.shared
        let output = GroupsHomeMapper.output(
            groups: app.groups.all, leaders: app.groupLeaders, organizations: app.myOrganizations,
            selection: selection, typedSearch: typedSearch, loaded: app.groupsListLoaded || !app.groups.all.isEmpty
        )
        GroupsHomeScreen(
            state: output.state,
            onSearch: { text in
                typedSearch = text
                searchTask?.cancel()
                searchTask = Task { @MainActor in
                    try? await Task.sleep(for: Self.searchDebounce)
                    guard !Task.isCancelled else { return }
                    selection.search = text
                }
            },
            onSaveOrgs: { selection.orgLabels = $0 },
            onSaveLeaders: { selection.leaderLabels = $0 },
            onOpenGroup: { row in
                guard let id = output.groupId(atRow: row) else { return }
                navigator.push(destination(id, output.state.groupNames[row]))
            },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .task { await Self.load(authManager: authManager) }
        .onDisappear { searchTask?.cancel() }
    }

    /// D3/D22: groups (a failure surfaces the banner over the cached or empty list), leaders and
    /// orgs (console-only) all at once. A groups success sets `AppState.groupsListLoaded` (D22).
    /// Returns whether the groups load succeeded.
    @MainActor
    @discardableResult
    static func load(authManager: AuthManager) async -> Bool {
        await load(api: APIClient.shared, state: AppState.shared, onUnauthorized: signOut(authManager))
    }

    /// `load` with its client, state and 401 handler injected (tests).
    /// The body already renders the cache from `AppState.groups`, so groups always fetch: the
    /// Action's cache branch would detach the fetch and drop both the banner and the 401 sign-out.
    @MainActor
    @discardableResult
    static func load(api: APIClientProtocol, state: AppState,
                     onUnauthorized: @escaping @MainActor () async -> Void) async -> Bool {
        async let leaders: () = loadLeaders(api: api, state: state, onUnauthorized: onUnauthorized)
        async let orgs: () = GroupActions(api: api, state: state, onUnauthorized: onUnauthorized).loadMyOrganizations()
        var ok = true
        do {
            try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true)
            state.groupsListLoaded = true
        } catch {
            ok = false
            await route(error, context: "GroupsHomeContainer.loadGroups", surface: true,
                        state: state, onUnauthorized: onUnauthorized)
        }
        _ = await (leaders, orgs)
        return ok
    }

    /// D3: the Groups section's pull-to-refresh (UI2Shell.refreshAction).
    @MainActor
    static func refresh(authManager: AuthManager) async {
        await load(authManager: authManager)
    }

    /// D22 + ui2-shell D28: a cancelled load is nothing; a 401 signs out; anything else is
    /// recorded — surfaced with `loadFailedMessage` when `surface` (the groups list), else console-only.
    @MainActor
    static func route(_ error: Error, context: String, surface: Bool, state: AppState,
                      onUnauthorized: @MainActor () async -> Void) async {
        if GroupActions.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        state.recordError(error, context: context, surface: surface,
                          friendlyMessage: surface ? loadFailedMessage : nil)
    }

    @MainActor
    private static func loadLeaders(api: APIClientProtocol, state: AppState,
                                    onUnauthorized: @escaping @MainActor () async -> Void) async {
        do {
            try await ProgramActions(api: api, state: state).loadGroupLeaders()
        } catch {
            await route(error, context: "GroupsHomeContainer.loadGroupLeaders", surface: false,
                        state: state, onUnauthorized: onUnauthorized)
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    private static func signOut(_ authManager: AuthManager) -> @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "GroupsHomeContainer.signOut", surface: false)
            }
        }
    }
}
