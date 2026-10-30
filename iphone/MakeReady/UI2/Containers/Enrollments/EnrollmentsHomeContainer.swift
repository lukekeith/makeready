import SwiftUI

/// ui2-enrollments-browse §iphone: the Home tab's Enrollments section (R1). Cache-first per filter
/// (`AppState.enrollmentFeed`); a filter whose answer is missing — first visit, or dropped by a
/// draft/enroll mutation — loads. The screen has no root scroll: the shell's page scroll scrolls it.
/// Load failures are background (console-only); pull-down reloads.
struct EnrollmentsHomeContainer: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var selection = EnrollmentsHomeMapper.Selection()
    @State private var openMenu: EnrollmentsHomeMapper.Dimension?
    @State private var searchActive = false
    @State private var loading = false
    @State private var failed = false
    /// Bumped when covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0

    /// Reload trigger: the filter, and whether its answer is missing.
    private struct LoadKey: Equatable { let filter: EnrollmentFeedFilter; let missing: Bool }

    var body: some View {
        let app = AppState.shared
        let feed = app.enrollmentFeed[selection.filter]
        let options = feed?.options ?? app.enrollmentFeed.values.first?.options
        let output = EnrollmentsHomeMapper.output(
            .init(feed: feed, options: options, selection: selection, loading: loading, failed: failed,
                  group: { app.groups[$0] }, program: { app.programs[$0] }),
            today: Date(), timeZone: .current)
        let _ = coversSeeded
        let state = {
            var s = output.state
            s.groupPhotoURLs = CoverImageLoader.cachedListURLs(s.groupPhotoURLs)
            s.programCoverURLs = CoverImageLoader.cachedListURLs(s.programCoverURLs)
            return s
        }()
        EnrollmentsHomeScreen(
            state: state,
            onOpenFilter: { openMenu = EnrollmentsHomeMapper.Dimension(rawValue: $0) },
            onOpenGroup: { section in
                if let next = output.groupDestination(section: section) { navigator.push(next) }
            },
            // Owner 2026-10-30: the header's add → the enroll checklist with that group chosen.
            onAddEnrollment: { section in
                guard output.sections.indices.contains(section) else { return }
                EnrollEntry.open(groupId: output.sections[section].id, studyProgramId: nil, push: { navigator.push($0) })
            },
            onOpenProgram: { _, row in EnrollDraftOpen.route(output.target(atRow: row), navigator: navigator) },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let dimension = openMenu {
                let menu = EnrollmentsHomeMapper.menu(dimension, options: options, organizations: app.myOrganizations)
                // Owner 2026-10-30: every chip is multi-select — Save applies the ticks.
                FilterMenuOverlay(
                    options: menu,
                    selectionMode: .multiple,
                    selectedIDs: EnrollmentsHomeMapper.selectedIds(dimension, selection),
                    onClose: { openMenu = nil },
                    onClear: {
                        selection = EnrollmentsHomeMapper.clearing(dimension, selection)
                        openMenu = nil
                    },
                    clearEnabled: !EnrollmentsHomeMapper.isAtRest(dimension, selection),
                    onSave: { ids in
                        selection = EnrollmentsHomeMapper.saving(ids, in: dimension, options: menu, selection)
                        openMenu = nil
                    }
                )
            }
        }
        .task { await GroupActions(onUnauthorized: signOut).loadMyOrganizations() }      // D15 Orgs menu
        .task(id: LoadKey(filter: selection.filter, missing: feed == nil)) {
            if feed == nil { await reload(force: false) }
        }
        .pageRefresh { await reload(force: true) }
        .task(id: output.state.groupPhotoURLs + output.state.programCoverURLs) {
            if await CoverImageLoader.seedList(output.state.groupPhotoURLs + output.state.programCoverURLs) { coversSeeded += 1 }
        }
    }

    @MainActor
    private func reload(force: Bool) async {
        loading = true
        defer { loading = false }
        failed = !(await Self.load(selection.filter, force: force, actions: EnrollmentActions(),
                                   state: .shared, onUnauthorized: signOut))
    }

    /// true = the feed is (or stays) loaded. A cancelled load is nothing; a 401 signs out; anything
    /// else is a background failure — recorded console-only (ios-error-surface).
    @MainActor
    static func load(_ filter: EnrollmentFeedFilter, force: Bool, actions: EnrollmentActions, state: AppState,
                     onUnauthorized: @MainActor () async -> Void) async -> Bool {
        do {
            try await actions.loadFeed(filter: filter, forceRefresh: force)
            return true
        } catch {
            if GroupActions.isCancellation(error) { return true }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            state.recordError(error, context: "EnrollmentsHomeContainer.loadFeed")
            return false
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    private var signOut: @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EnrollmentsHomeContainer.signOut", surface: false)
            }
        }
    }
}
