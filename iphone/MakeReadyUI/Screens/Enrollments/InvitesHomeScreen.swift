//
//  InvitesHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen invites-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/invites
//  (org-wide scope with `orgId` / `inviterId` filters, and a `rejected` status with decline
//  capture, are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Invites — the Invites tab root of the Home section switcher (§6): the org-wide list of sent
/// invites. The collapsed C-019 nav row, a header of C-034 search over four C-035 filter chips,
/// then the invite list of C-089 rows with no dividers (§2). Composed only of §4's C-019, C-034,
/// C-035 and C-089. C-036 FilterMenuOverlay is presented by a chip but is not on §4's roll-call,
/// so a chip tap leaves the screen through `onOpenFilter`.
///
/// §3 names five states: `populated`, `loading`, `empty`, `no results` and `error`. `loading` is
/// the cold first load ("the header with an empty list area"). A warm load renders the cache
/// exactly as `populated` does. `error` keeps the cached rows and shows no inline error (D39).
struct InvitesHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per invite row, because the preview's props are JSON and C-089 takes flat
    /// parameters (R-05).
    struct State {
        // ── Header (§2.2) ──
        /// C-034 `text`: the current query. "" shows the placeholder (§4 `state=Default`).
        var searchText: String
        /// C-035 `label` per chip: the filter's current selection. §2 defaults: "All Orgs",
        /// "All groups", "All Leaders", "All status".
        var orgFilterLabel: String
        var groupFilterLabel: String
        var leaderFilterLabel: String
        var statusFilterLabel: String
        /// §3 `loading`: a cold first load with nothing cached. The list area stays empty and
        /// shows no message.
        var loading: Bool
        // ── List (§2.3): one C-089 per entry ──
        /// C-089 `recipient`: the formatted phone (or the member's name, OQ-C-089-3).
        var inviteRecipients: [String]
        /// C-089 `status`: "sent" | "accepted" | "rejected" | "expired" (OQ-invites-home-001).
        var inviteStatuses: [String]
        /// C-089 `groupName`.
        var inviteGroupNames: [String]
        /// C-089 `date`, already formatted per OQ-invites-home-005.
        var inviteDates: [String]
    }

    let state: State
    // §3 interactions that leave the screen. Each is an on<Verb> closure with R-03's no-op
    // default. The screen never decides what an action means.
    var onSelectTab: (String) -> Void = { _ in }    // C-019 tab tap → that Home section (§6)
    var onToggleNav: () -> Void = {}                // C-019 collapse ⇄ expand
    var onSearch: (String) -> Void = { _ in }       // §3: typing filters on phone + group name
    var onOpenFilter: (String) -> Void = { _ in }   // §3: chip tap → C-036 for that dimension
    var onOpenInvite: (Int) -> Void = { _ in }      // §3: row tap → push invite-home, by row

    // R-31 ephemeral UI: the query as typed. §3: "The search text is ephemeral screen state
    // (D43)."
    @SwiftUI.State private var query: String

    init(
        state: State,
        onSelectTab: @escaping (String) -> Void = { _ in },
        onToggleNav: @escaping () -> Void = {},
        onSearch: @escaping (String) -> Void = { _ in },
        onOpenFilter: @escaping (String) -> Void = { _ in },
        onOpenInvite: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSelectTab = onSelectTab
        self.onToggleNav = onToggleNav
        self.onSearch = onSearch
        self.onOpenFilter = onOpenFilter
        self.onOpenInvite = onOpenInvite
        _query = SwiftUI.State(initialValue: state.searchText)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2.1: "the Home section switcher with **Invites** active".
    private static let selectedTab = "Invites"
    /// §2.2: "placeholder `Search invites`".
    private static let searchPlaceholder = "Search invites"
    /// §3 chip dimensions, in §2's order: "Orgs · Groups · Leaders · Status".
    private static let filterDimensions = ["Orgs", "Groups", "Leaders", "Status"]
    /// OQ-invites-home-003 (closed): "\"No invites yet\" (empty) or \"No invites match\" (no
    /// results)".
    private static let emptyMessage = "No invites yet"
    private static let noMatchMessage = "No invites match"

    // MARK: - §2 geometry the screen owns

    // GAP — invites-home §2.2: "vertical gap 16" between the search field and the chip row; no
    // spacing token names a vertical gap.
    private static let headerGap: CGFloat = 16
    // GAP — invites-home §2.3: "content padding 16, so the first row starts at y211"; no spacing
    // token names the list's padding.
    private static let listPadding: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 1) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            navRow
            header
            inviteList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // §2: "Background `color-background` (`layout/background`)". The register's row for
        // that Figma variable is `color-layout-background`.
        .background(Token.layoutBackground)
    }

    /// §2.1: "C-019 TopNav: y47, full width, height 32", collapsed (`expansion` 0) at rest
    /// (`scrollOffset` 0). Invites is the sixth tab, past the right edge in the frozen frame.
    /// No `onAdd`: §3 "No create or invite affordance is designed on this screen."
    private var navRow: some View {
        TopNav(
            tabs: TopNav.designedTabs,
            selectedTab: Self.selectedTab,
            expansion: 0,
            scrollOffset: 0,
            onSelect: onSelectTab,
            onToggleExpansion: onToggleNav
        )
        .ui2Element("C-019 TopNav")
    }

    // MARK: §2.2 Header

    /// §2.2: "Header (y79, padding `space-page-margin` 16 on all sides, vertical gap 16)".
    private var header: some View {
        VStack(alignment: .leading, spacing: Self.headerGap) {
            // §4: C-034 `state=Default`, derived by C-034 from `text.isEmpty × focused`. This
            // presentational screen owns no focus, so `focused` is false.
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                focused: false,
                onChange: { newValue in
                    query = newValue
                    onSearch(newValue)
                },
                onClear: {
                    query = ""
                    onSearch("")
                }
            )
            .ui2Element("C-034 SearchField")
            .padding(.horizontal, Token.Space.pageMargin)
            chipRow
        }
        .padding(.vertical, Token.Space.pageMargin)
    }

    /// §2.2: "Filter chip row: … height 24, gap `space-element-gap` 8 … The row is wider than
    /// the screen and scrolls horizontally, with the leading inset 16." A horizontal carousel
    /// keeps its own ScrollView (D22).
    private var chipRow: some View {
        HorizontalRail {
            HStack(spacing: Token.Space.elementGap) {
                ForEach(chipLabels.indices, id: \.self) { index in
                    let label = chipLabels[index]
                    // §3: "A chip whose filter is not \"All\" shows C-035's active state."
                    FilterChip(type: .menu, active: !Self.isAll(label), label: label) {
                        onOpenFilter(Self.filterDimensions[index])
                    }
                    .ui2Element(Self.partName("C-035 FilterChip", ordinal: index + 1))
                }
            }
            .padding(.horizontal, Token.Space.pageMargin)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: §2.3 List

    /// §2.3: "a vertical stack of C-089 InviteStatusRows. Each row is 408×80 with no gap between
    /// rows and no dividers." The list's content padding is 16 on every side.
    private var inviteList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleRows, id: \.self) { index in
                inviteRow(at: index)
            }
            if let message = listMessage {
                // OQ-invites-home-003 (closed): "one centred `color-text-secondary` 14 Regular
                // line".
                Text(message)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .padding(.vertical, Self.listPadding)
    }

    /// §4: one C-089 per invite: recipient, status word, group, date and chevron.
    private func inviteRow(at index: Int) -> some View {
        InviteStatusRow(
            recipient: state.inviteRecipients[index],
            status: InviteStatusRow.Status(rawValue: state.inviteStatuses[safe: index] ?? "") ?? .sent,
            groupName: state.inviteGroupNames[safe: index] ?? "",
            date: state.inviteDates[safe: index] ?? "",
            onTap: { onOpenInvite(index) }
        )
        .ui2Element(Self.partName("C-089 InviteStatusRow", ordinal: index + 1))
    }

    // MARK: - §3 rules

    private var chipLabels: [String] {
        [state.orgFilterLabel, state.groupFilterLabel, state.leaderFilterLabel, state.statusFilterLabel]
    }

    /// §3: "Type in C-034: filters the list on phone number and group name as the user types."
    private var visibleRows: [Int] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return state.inviteRecipients.indices.filter { index in
            needle.isEmpty
                || state.inviteRecipients[index].localizedCaseInsensitiveContains(needle)
                || (state.inviteGroupNames[safe: index] ?? "").localizedCaseInsensitiveContains(needle)
        }
    }

    /// §3 `loading` shows no message. `empty` and `no results` show OQ-invites-home-003's line:
    /// "no results" when a search or a non-"All" filter is narrowing the list.
    private var listMessage: String? {
        guard visibleRows.isEmpty, !state.loading else { return nil }
        let narrowed = !query.isEmpty || chipLabels.contains { !Self.isAll($0) }
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    /// A chip label is its dimension's "All …" option (OQ-invites-home-004: "an \"All …\" option
    /// first").
    private static func isAll(_ label: String) -> Bool {
        label.hasPrefix("All ")
    }

    /// `"C-### <Name>"`, with `" N"` from the second instance on (D11).
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension InvitesHomeScreen.State {

    /// §3 `populated`: every value is the text on the frozen frame `default` (node 3830:6919;
    /// §1 deviation 2: sample content), in the frame's order. Dates follow OQ-invites-home-005's
    /// "Aug 5, 2026" format rather than the frame's "July 17, 2026" (§1 deviation 2).
    static let populated = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "All status",
        loading: false,
        inviteRecipients: ["(214) 862-3686", "(214) 901-6271", "(469) 728-9102", "(972) 789-0196"],
        inviteStatuses: ["sent", "accepted", "sent", "rejected"],
        inviteGroupNames: ["Young Professionals", "Young Professionals", "Young Professionals", "Young Professionals"],
        inviteDates: ["Just now", "Aug 5, 2026", "Jul 17, 2026", "May 5, 2026"]
    )

    /// §3 `loading`: "A cold first load shows the header with an empty list area."
    static let loading = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "All status",
        loading: true,
        inviteRecipients: [],
        inviteStatuses: [],
        inviteGroupNames: [],
        inviteDates: []
    )

    /// §3 `empty`: no invites yet and every filter at "All" (OQ-invites-home-003).
    static let empty = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "All status",
        loading: false,
        inviteRecipients: [],
        inviteStatuses: [],
        inviteGroupNames: [],
        inviteDates: []
    )

    /// §3 `no results`: the Status filter set to "Expired" (one of §3's four statuses) matches
    /// nothing, so that chip is active and the list shows OQ-invites-home-003's no-results line.
    static let noResults = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Expired",
        loading: false,
        inviteRecipients: [],
        inviteStatuses: [],
        inviteGroupNames: [],
        inviteDates: []
    )

    /// §3 `error`: "cached rows stay. No inline error is designed": the cached rows of
    /// `populated`, unchanged.
    static let error = populated
}

// MARK: - Previews (D21): one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("populated") {
    InvitesHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    InvitesHomeScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    InvitesHomeScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("no results") {
    InvitesHomeScreen(state: .noResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    InvitesHomeScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
