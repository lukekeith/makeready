//
//  SearchActions.swift
//  MakeReady
//
//  master-search: every search API call (C1-C5) and every write to the AppState search domain.
//  Failures are deliberate (D20, D24): a load keeps the last rendered state with no error UI, and
//  only a failed recent removal surfaces (D36).
//

import Foundation

struct SearchActions {

    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let onUnauthorized: @MainActor () async -> Void

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared
    ///   - onUnauthorized: runs when a call is rejected with a 401 (the container signs out)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - C1 ranked results

    /// First page for `query`. Prior results stay until the response lands (D20); a response for a
    /// superseded query, after `cancelQuery`, or after sign-out is dropped (D42).
    @MainActor
    func search(query: String, filters: SearchFilters) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = UUID()
        state.searchRequestToken = token
        state.searchNextPageToken = nil
        // The old query's cursor is meaningless for this one: clearing it makes a next-page load
        // inert until the first page lands, while the prior rows stay displayed (D20).
        state.searchNextCursor = nil
        let generation = state.initialLoad.generation
        do {
            let response: SearchItemsResponse = try await api.get(
                rankedPath(query: trimmed, filters: filters, cursor: nil), responseType: SearchItemsResponse.self)
            guard isCurrent(token: token, generation: generation) else { return }
            state.searchResults = Self.deduplicated(response.items)
            state.searchNextCursor = response.nextCursor
            state.searchAnsweredQuery = trimmed
        } catch {
            guard isCurrent(token: token, generation: generation) else { return }
            await handleLoadFailure(error, context: "SearchActions.search")
        }
    }

    /// The page after the cursor, appended and de-duplicated by key (D17). A no-op with no cursor or
    /// a page already in flight.
    @MainActor
    func loadNextPage(query: String, filters: SearchFilters) async {
        guard let cursor = state.searchNextCursor else { return }
        let token = state.searchRequestToken
        guard state.searchNextPageToken != token else { return }
        state.searchNextPageToken = token
        defer { if state.searchNextPageToken == token { state.searchNextPageToken = nil } }
        let generation = state.initialLoad.generation
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response: SearchItemsResponse = try await api.get(
                rankedPath(query: trimmed, filters: filters, cursor: cursor), responseType: SearchItemsResponse.self)
            guard isCurrent(token: token, generation: generation), state.searchNextCursor == cursor else { return }
            state.searchResults = Self.deduplicated(state.searchResults + response.items)
            state.searchNextCursor = response.nextCursor
        } catch {
            guard isCurrent(token: token, generation: generation) else { return }
            await handleLoadFailure(error, context: "SearchActions.loadNextPage")
        }
    }

    /// The query went below 2 characters (D41): invalidate the request in flight and clear the answer.
    @MainActor
    func cancelQuery() {
        state.searchRequestToken = UUID()
        state.searchNextPageToken = nil
        state.searchResults = []
        state.searchNextCursor = nil
        state.searchAnsweredQuery = nil
    }

    /// A new visit to the tab (D26): recents loaded under picks the fresh chips no longer show would
    /// render under at-rest chips, so they go until C2 lands.
    @MainActor
    func clearRecentsLoadedWithPicks() {
        guard state.searchRecentsFilters != SearchFilters() else { return }
        state.searchRecentsToken = UUID()
        state.searchRecents = []
        state.searchRecentsFilters = SearchFilters()
    }

    // MARK: - C2 recents

    /// Replaces the recents with the server's, minus rows whose removal has not settled (D42).
    @MainActor
    func loadRecents(filters: SearchFilters) async {
        let token = UUID()
        state.searchRecentsToken = token
        let generation = state.initialLoad.generation
        do {
            let response: SearchItemsResponse = try await api.get(
                path("/api/search/recent-results", filters: filters), responseType: SearchItemsResponse.self)
            guard state.searchRecentsToken == token, state.initialLoad.isCurrent(generation), !Task.isCancelled else { return }
            let pending = state.searchPendingRemovals
            state.searchRecents = Self.deduplicated(response.items.filter { !pending.contains($0.key) })
            state.searchRecentsFilters = filters
        } catch {
            guard state.searchRecentsToken == token, state.initialLoad.isCurrent(generation) else { return }
            await handleLoadFailure(error, context: "SearchActions.loadRecents")
        }
    }

    // MARK: - C5 filter options

    @MainActor
    func loadFilterOptions() async {
        let generation = state.initialLoad.generation
        do {
            let options: SearchFilterOptions = try await api.get(
                "/api/search/filter-options", responseType: SearchFilterOptions.self)
            guard state.initialLoad.isCurrent(generation), !Task.isCancelled else { return }
            state.searchFilterOptions = options
        } catch {
            guard state.initialLoad.isCurrent(generation) else { return }
            await handleLoadFailure(error, context: "SearchActions.loadFilterOptions")
        }
    }

    // MARK: - C3 record an open

    /// Moves `item` to the top of the recents at once, then tells the server (C3). A failure never
    /// blocks opening the item and the next open records it (D24); results are not touched (D42).
    @MainActor
    func recordOpened(_ item: SearchItem) async {
        state.searchRecents.removeAll { $0.key == item.key }
        state.searchRecents.insert(item, at: 0)
        let generation = state.initialLoad.generation
        do {
            let _: APISuccessResponse = try await api.request(
                endpoint: "/api/search/recent-results",
                method: "PUT",
                body: ["type": item.type, "id": item.id],
                responseType: APISuccessResponse.self)
        } catch {
            guard state.initialLoad.isCurrent(generation) else { return }
            await handleLoadFailure(error, context: "SearchActions.recordOpened")
        }
    }

    // MARK: - C4 remove a recent

    /// Removes the row at once and puts it back in place when C4 fails, surfacing it with a retry
    /// (D22, D36). `searchPendingRemovals` keeps a slow C2 from bringing the row back (D42).
    @MainActor
    func removeRecent(_ item: SearchItem) async {
        let index = state.searchRecents.firstIndex { $0.key == item.key }
        if let index { state.searchRecents.remove(at: index) }
        state.searchPendingRemovals.insert(item.key)
        let generation = state.initialLoad.generation
        do {
            let response: APISuccessResponse = try await api.delete(
                "/api/search/recent-results/\(Self.pathSegment(item.type))/\(Self.pathSegment(item.id))",
                responseType: APISuccessResponse.self)
            guard response.success else { throw APIError.serverError(response.error ?? "Failed to remove recent") }
            guard state.initialLoad.isCurrent(generation) else { return }
            state.searchPendingRemovals.remove(item.key)
            // A C2 the server answered before this delete would bring the row back: drop it.
            state.searchRecentsToken = UUID()
        } catch {
            guard state.initialLoad.isCurrent(generation) else { return }
            state.searchPendingRemovals.remove(item.key)
            if let index, !state.searchRecents.contains(where: { $0.key == item.key }) {
                state.searchRecents.insert(item, at: min(index, state.searchRecents.count))
            }
            if GroupActions.isCancellation(error) { return }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return
            }
            state.recordError(error, context: "SearchActions.removeRecent", surface: true,
                              friendlyMessage: "Couldn't remove that search",
                              retry: { Task { await self.removeRecent(item) } })
        }
    }

    // MARK: - Helpers

    @MainActor
    private func isCurrent(token: UUID, generation: Int) -> Bool {
        state.searchRequestToken == token && !Task.isCancelled && state.initialLoad.isCurrent(generation)
    }

    /// A failed load, record or page: a cancellation does nothing, a 401 signs out, and anything
    /// else is logged with no banner. The rendered state stays and `searchAnsweredQuery` is left
    /// alone, so a failed query never prints no-results (D20, D24, D41).
    @MainActor
    private func handleLoadFailure(_ error: Error, context: String) async {
        if GroupActions.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        // Silent: D20/D24 — search shows no error UI; the last rendered state stays, only the log records it.
        state.recordError(error, context: context, surface: false)
    }

    private func rankedPath(query: String, filters: SearchFilters, cursor: String?) -> String {
        var pairs: [(name: String, value: String)] = [("q", query)]
        pairs += filters.queryPairs
        if let cursor { pairs.append(("cursor", cursor)) }
        return path("/api/search/ranked", pairs: pairs)
    }

    private func path(_ base: String, filters: SearchFilters) -> String {
        path(base, pairs: filters.queryPairs)
    }

    /// `APIClient.get` takes the raw path, so each value is encoded here (`+`, `&`, `=` included).
    private func path(_ base: String, pairs: [(name: String, value: String)]) -> String {
        guard !pairs.isEmpty else { return base }
        return base + "?" + pairs.map { "\($0.name)=\(DashboardActions.queryValue($0.value))" }.joined(separator: "&")
    }

    private static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// First occurrence wins, order kept.
    private static func deduplicated(_ items: [SearchItem]) -> [SearchItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.key).inserted }
    }
}
