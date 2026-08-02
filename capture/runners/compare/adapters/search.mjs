/**
 * Adapter: search (page comparison).
 * GlobalSearchPage — the global search tab (ViewRegistry pages.search ↔ web
 * GlobalSearch twin).
 *
 * Both ORIGINAL iPhone references are degenerate states, and the web side
 * matches them exactly rather than faking richer ones:
 *   • recent-results → "No recent items" (iOS hydrates recents from AppState,
 *     which drops every entity the harness has not cached)
 *   • with-results   → the LOADING spinner (the mocked /api/search response
 *     never resolves before the snapshot)
 * The populated renderings are exposed as WEB-ONLY variants (webOnly: true).
 *
 * Capture note: ViewRegistry passes `initialQuery`, but `isSearchActive` is
 * only mutated from inside SearchField — so the iPhone shot has NO close
 * button and NO active border. `active` therefore stays false here.
 */
export default {
  toClient(shared) {
    const {
      searchQuery = '',
      searchLoading = false,
      sections = [],
      activeCategory = null,
    } = shared ?? {};

    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'GlobalSearch',
        componentProps: {
          searchText: searchQuery,
          // iOS: initialQuery does not activate the field (see header note).
          active: false,
          loading: searchLoading,
          sections,
          activeCategory,
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    // The populated variants have no iPhone counterpart: recents hydrate from
    // AppState and the search response is mocked, so the harness can only
    // reach the empty/loading states (see the fixture note).
    if (shared?.webOnly) return null;
    return {
      platform: 'iphone',
      view: 'pages.search',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name ?? 'Alex Rivera',
          email: user.email ?? 'alex@example.com',
          picture: user.picture ?? null,
        },
      },
      state,
    };
  },
};
