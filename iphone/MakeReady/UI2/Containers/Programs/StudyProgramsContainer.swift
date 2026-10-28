import SwiftUI

/// ui2-programs §iphone Programs list: the Home tab's Programs section (D3, D4).
/// Cache-first: renders `AppState.programs` (newest first, D3) at once, then loads programs, leaders and the
/// caller's orgs. The screen has no root scroll — the shell's page scroll (HomeSectionLayout)
/// scrolls it and owns its pull-to-refresh (`refresh`). A row tap pushes `destination(id, name)`
/// on this tab's stack (UI2Shell passes `.studyProgramHome`).
struct StudyProgramsContainer: View {
    /// D1: the page a row opens.
    let destination: (_ id: String, _ name: String) -> UI2Destination

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// The text as typed — the screen filters by it itself (D3), this keeps it across re-renders.
    @State private var typedSearch = ""
    @State private var selection = StudyProgramsMapper.Selection()
    /// members-search-pinned (owner 2026-10-28: as on Members): while search is active the
    /// shell's TopNav moves off screen.
    @State private var searchActive = false
    /// Bumped when covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0

    var body: some View {
        let app = AppState.shared
        let output = StudyProgramsMapper.output(
            programs: app.programs.all, leaders: app.groupLeaders, organizations: app.myOrganizations,
            selection: selection, typedSearch: typedSearch,
            loaded: app.programsListLoaded, failed: app.programsListFailed
        )
        let _ = coversSeeded
        // cover-image-sizes: the screen reads covers from Ui2ImageCache only — the 400px list copy.
        let state = { var s = output.state; s.programCoverURLs = CoverImageLoader.cachedListURLs(s.programCoverURLs); return s }()
        StudyProgramsScreen(
            state: state,
            onSearch: { typedSearch = $0 },
            onSaveOrgs: { selection.orgLabels = $0 },
            onSaveLeaders: { selection.leaderLabels = $0 },
            onOpenProgram: { row in
                guard let id = output.programId(atRow: row) else { return }
                navigator.push(destination(id, output.state.programTitles[row]))
            },
            onRetry: { Task { await Self.load(authManager: authManager) } },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .task { await Self.load(authManager: authManager) }
        .task(id: output.state.programCoverURLs) {
            if await CoverImageLoader.seedList(output.state.programCoverURLs) { coversSeeded += 1 }
        }
    }

    /// D3/D4: programs, leaders and orgs all at once. Every failure is console-only (D4: a refresh
    /// the user didn't start never interrupts them); with nothing cached the screen shows its
    /// inline Retry. Returns whether the programs load succeeded.
    @MainActor
    @discardableResult
    static func load(authManager: AuthManager) async -> Bool {
        await load(api: APIClient.shared, state: AppState.shared, onUnauthorized: signOut(authManager))
    }

    /// `load` with its client, state and 401 handler injected (tests). Programs always fetch: the
    /// body already renders the cache, and the Action's cache branch would detach the fetch and
    /// drop the 401 sign-out.
    @MainActor
    @discardableResult
    static func load(api: APIClientProtocol, state: AppState,
                     onUnauthorized: @escaping @MainActor () async -> Void) async -> Bool {
        async let leaders: () = loadLeaders(api: api, state: state, onUnauthorized: onUnauthorized)
        async let orgs: () = GroupActions(api: api, state: state, onUnauthorized: onUnauthorized).loadMyOrganizations()
        var ok = true
        do {
            try await ProgramActions(api: api, state: state).loadPrograms(forceRefresh: true)
            state.programsListLoaded = true
            state.programsListFailed = false
        } catch {
            if !GroupActions.isCancellation(error) {
                ok = false
                state.programsListFailed = true
                await route(error, context: "StudyProgramsContainer.loadPrograms", state: state,
                            onUnauthorized: onUnauthorized)
            }
        }
        _ = await (leaders, orgs)
        return ok
    }

    /// D3: the Programs section's pull-to-refresh (UI2Shell.refreshAction).
    @MainActor
    static func refresh(authManager: AuthManager) async {
        await load(authManager: authManager)
    }

    /// D4 + ui2-shell D28: a cancelled load is nothing; a 401 signs out; anything else is recorded,
    /// console-only.
    @MainActor
    private static func route(_ error: Error, context: String, state: AppState,
                              onUnauthorized: @MainActor () async -> Void) async {
        if GroupActions.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        state.recordError(error, context: context, surface: false)
    }

    @MainActor
    private static func loadLeaders(api: APIClientProtocol, state: AppState,
                                    onUnauthorized: @escaping @MainActor () async -> Void) async {
        do {
            try await ProgramActions(api: api, state: state).loadGroupLeaders()
        } catch {
            await route(error, context: "StudyProgramsContainer.loadGroupLeaders", state: state,
                        onUnauthorized: onUnauthorized)
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    private static func signOut(_ authManager: AuthManager) -> @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "StudyProgramsContainer.signOut", surface: false)
            }
        }
    }
}
