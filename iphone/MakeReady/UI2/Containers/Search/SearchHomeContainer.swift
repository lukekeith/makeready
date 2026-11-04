import SwiftUI

/// master-search §iphone Container: the Search tab's `SearchHomeScreen`. The screen debounces nothing,
/// so this container does (300 ms, `Task.sleep`, as GroupsHomeContainer does); the query and the picks
/// are `@State` (D20) and the recents, results and filter options live in `AppState` (D26), written only
/// by `SearchActions`. A row tap records the open without waiting for it and then exits (D24); a photo
/// opens `ImageViewer`, every other type pushes a page (SearchHomeMapper.exit). The container owns the root
/// scroll the screen lacks (§iphone Root scroll).
struct SearchHomeContainer: View {
    /// D20: the query runs this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)
    /// D18/D20: the shortest query that is sent.
    static let minimumQueryLength = 2
    /// D20: the next page is asked for when a row within this many of the end appears.
    static let pagingLookahead = 5

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// The text as typed; the screen keeps its own copy for the field.
    @State private var query = ""
    @State private var selection = SearchHomeMapper.Selection()
    @State private var openMenu: SearchHomeScreen.Filter?
    @State private var viewer: Viewer?
    /// The pending debounce, or the immediate rerun after a pick; a newer one cancels it.
    @State private var searchTask: Task<Void, Never>?
    /// The tab mounts once per visit: results of an earlier visit are cleared then, never on a push and pop (D26).
    @State private var mounted = false
    @State private var hasAppeared = false

    private struct Viewer {
        let url: String
        let title: String
    }

    var body: some View {
        let app = AppState.shared
        let output = SearchHomeMapper.output(
            recents: app.searchRecents, results: app.searchResults, query: query,
            answeredQuery: app.searchAnsweredQuery, selection: selection, options: app.searchFilterOptions, tz: .current)
        ScrollView {
            screen(output: output)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.always, axes: .vertical)
        // `.underScreenHeader` already gives safe area + 16, so no top padding here. The status-bar strip
        // stays page background (HomeSectionLayout), so rows scrolling up never show through it.
        .overlay(alignment: .top) {
            Color.clear.frame(height: 0)
                .background(alignment: .bottom) { Token.layoutBackground.ignoresSafeArea(edges: .top) }
                .allowsHitTesting(false)
        }
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let filter = openMenu { menu(for: filter, options: app.searchFilterOptions) }
        }
        .imageViewerPresentation(viewer.map { opened in
            // The one-image init: a row has no tile frame, so the image grows in place.
            ImageViewer(url: opened.url, sourceFrame: nil, accessibilityLabel: opened.title, onClose: { viewer = nil })
        })
        .task {
            // D26/D42: recents and options load without `loadInitialData()`; an earlier visit's results go.
            if !mounted {
                mounted = true
                actions.cancelQuery()
                actions.clearRecentsLoadedWithPicks()
            }
            let filters = self.filters
            async let options: () = actions.loadFilterOptions()
            await actions.loadRecents(filters: filters)
            await options
        }
        .onAppear {
            // Returning from a pushed page: the opened item is at the top of C2 (the first appear is `.task`'s).
            if hasAppeared { reloadRecents() } else { hasAppeared = true }
        }
    }

    private func screen(output: SearchHomeMapper.Output) -> some View {
        SearchHomeScreen(
            state: output.state,
            onSearch: { queryChanged($0) },
            onTapFilter: { openMenu = $0 },
            onOpenRecent: { row in
                guard output.recentItems.indices.contains(row) else { return }
                open(output.recentItems[row])
            },
            onRemoveRecent: { row in
                guard output.recentItems.indices.contains(row) else { return }
                let item = output.recentItems[row]
                Task { await actions.removeRecent(item) }
            },
            onOpenResult: { row in
                guard output.resultItems.indices.contains(row) else { return }
                open(output.resultItems[row])
            },
            onResultAppear: { row in
                if Self.shouldLoadNextPage(afterRow: row, of: output.resultItems.count) { loadNextPage() }
            }
        )
    }

    // MARK: - Decisions (pure, tested)

    /// F11: only the last rows ask for the next page.
    static func shouldLoadNextPage(afterRow index: Int, of count: Int) -> Bool {
        index >= count - pagingLookahead
    }

    // MARK: - Effects

    private var filters: SearchFilters { SearchHomeMapper.filters(selection) }

    private var actions: SearchActions {
        SearchActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "SearchHomeContainer.signOut", surface: false)
            }
        })
    }

    private var isQueryLive: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumQueryLength
    }

    /// D20/D41: 2+ trimmed characters run after the debounce; fewer cancel it and clear the answer
    /// (C2 is current already: a pick refetches it in `applyPicks`).
    private func queryChanged(_ text: String) {
        query = text
        searchTask?.cancel()
        if isQueryLive {
            let actions = self.actions
            let filters = self.filters
            searchTask = Task { @MainActor in
                try? await Task.sleep(for: Self.searchDebounce)
                guard !Task.isCancelled else { return }
                await actions.search(query: text, filters: filters)
            }
        } else {
            // applyPicks already refetched C2 for any pick, so recents are current here.
            actions.cancelQuery()
        }
    }

    /// D6/D20: a changed pick reruns a live query at once (prior rows stay until the response) and refreshes C2.
    private func applyPicks(_ change: (inout SearchHomeMapper.Selection) -> Void) {
        var next = selection
        change(&next)
        selection = next
        reloadRecents()
        guard isQueryLive else { return }
        searchTask?.cancel()
        let actions = self.actions
        let filters = self.filters
        let text = query
        searchTask = Task { @MainActor in await actions.search(query: text, filters: filters) }
    }

    private func reloadRecents() {
        let filters = self.filters
        let actions = self.actions
        Task { await actions.loadRecents(filters: filters) }
    }

    /// The page after the cursor belongs to the query last answered, which may not be the typed one yet.
    private func loadNextPage() {
        guard let answered = AppState.shared.searchAnsweredQuery else { return }
        let actions = self.actions
        let filters = self.filters
        Task { await actions.loadNextPage(query: answered, filters: filters) }
    }

    /// D24: the open is recorded in its own task and the exit does not wait for it.
    private func open(_ item: SearchItem) {
        let actions = self.actions
        Task { await actions.recordOpened(item) }
        switch SearchHomeMapper.exit(for: item) {
        case .push(let destination): navigator.push(destination)
        case .viewer(let url, let title): viewer = Viewer(url: url, title: title)
        }
    }

    // MARK: - Chip menus (C-036)

    /// Every chip is a draft-mode multi-select with Save/Clear; Tags uses the tag-flow form (D14).
    @ViewBuilder private func menu(for filter: SearchHomeScreen.Filter, options: SearchFilterOptions?) -> some View {
        switch filter {
        case .type:
            listMenu(options: SearchHomeMapper.typeOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                     selected: selection.typeIds) { ids in applyPicks { $0.typeIds = ids } }
        case .orgs:
            listMenu(options: (options?.organizations ?? []).map { FilterMenuOverlay.Option(id: $0.id, label: $0.name) },
                     selected: selection.orgIds) { ids in applyPicks { $0.orgIds = ids } }
        case .groups:
            listMenu(options: (options?.groups ?? []).map { FilterMenuOverlay.Option(id: $0.id, label: $0.name) },
                     selected: selection.groupIds) { ids in applyPicks { $0.groupIds = ids } }
        case .leaders:
            listMenu(options: (options?.leaders ?? []).map { FilterMenuOverlay.Option(id: $0.id, label: $0.name) },
                     selected: selection.leaderIds) { ids in applyPicks { $0.leaderIds = ids } }
        case .tags:
            FilterMenuOverlay(
                sections: MediaHomeContainer.tagMenuSections(SearchHomeMapper.tagSections(options: options)),
                selectedIDs: selection.tagIds,
                onClose: { openMenu = nil },
                onSave: { ids in
                    applyPicks { $0.tagIds = ids }
                    openMenu = nil
                })
        }
    }

    private func listMenu(options: [FilterMenuOverlay.Option], selected: Set<String>,
                          save: @escaping (Set<String>) -> Void) -> some View {
        FilterMenuOverlay(
            options: options, selectionMode: .multiple, selectedIDs: selected,
            onClose: { openMenu = nil },
            onSave: { ids in
                save(ids)
                openMenu = nil
            })
    }
}
