//
//  EnrollmentSelectGroupScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollment-select-group in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups · GET /api/group-leaders ·
//  GET /api/organizations/my/organization · GET /api/groups/{groupId}/enrollments
//  (eligibility scope, per-row leader + active-enrollment count and a "my organizations" list
//  are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select group — step "Choose a group" of the enrollment checklist (`groups-enroll-program`,
/// §6): the leader picks the ONE group to enroll; only Select commits. C-040 header, a filter
/// block of C-034 search over two C-035 chips, then the group list of selectable C-037 rows
/// between C-088 rules (§2). Composed only of §4's C-040, C-034, C-035, C-037 and C-088; C-038
/// and C-043 render inside C-037 (§4).
///
/// C-036 FilterMenuOverlay and the state-3 warning confirmation are presented by this screen
/// but are not on §4's roll-call ("Not on the roll-call", §4), so a chip tap and Select leave
/// the screen through `onOpenOrgFilter` / `onOpenLeaderFilter` / `onSelect`.
///
/// §3 names six states — `none`, `selected`, `already-enrolled warning`, `loading`, `empty`,
/// `error`. `none`, `selected` and `empty` render in full. `already-enrolled warning` renders
/// the picker under its warning — the confirmation itself (OQ-002) is not a §4 part.
/// `loading` (C-076 ActivitySpinner, not on §4) and `error` (an error line + Retry, no §4 part
/// and no copy) render the header and filters over an empty list area; the missing parts are
/// reported as spec gaps, not improvised here (the enrollments-home precedent).
struct EnrollmentSelectGroupScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per group row in the supplier's order (§3: alphabetical by group name), because the
    /// preview's props are JSON and the §4 views take flat parameters (R-05).
    struct State {
        // ── Filter block (§2 L2) ──
        /// C-034 `text` — the current query; "" → the placeholder shows ("Search groups").
        var searchText: String
        /// OQ-003: "Orgs shows only for multi-org callers" — the frame draws the multi-org look.
        var orgFilterVisible: Bool
        /// C-035 `label` of the Orgs chip — the chosen option, or "Orgs" at rest (§3).
        var orgFilterLabel: String
        /// C-035 `label` of the Leaders chip — the chosen option, or "Leaders" at rest (§3).
        var leaderFilterLabel: String
        // ── Group list (§2 L3) — C-037 `Group · selectable`, one per eligible group ──
        /// C-037 `title` — the group name.
        var groupNames: [String]
        /// C-038's photo inside C-037; "" = no photo → C-038's own fallback.
        var groupPhotoURLs: [String]
        /// First chip — the leader's full name ("Tony Stark").
        var groupLeaderNames: [String]
        /// Second chip — the member count ("14 members").
        var groupMemberCounts: [Int]
        /// Third chip — the active-enrollment count ("2 enrollments"); > 0 → `highlighted`.
        var groupEnrollmentCounts: [Int]
        /// The picked row on open (§3 `selected`: "opens in this state with that group
        /// selected"); -1 = no group picked (§3 `none`).
        var selectedIndex: Int
        // ── List area (§3) ──
        /// §3 `loading`: no cache, the first page has not arrived.
        var loading: Bool
        /// §3 `error`: the list failed to load with no cache.
        var failed: Bool
        /// §3 state 7 unavailable row — the group is enrolled (active or upcoming) in the
        /// checklist's program; indexed like the group list, a missing index = available.
        var groupUnavailable: [Bool] = []
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                        // §3 Back: discard + pop
    var onSelect: (Int) -> Void = { _ in }             // §3 Select: warning checks, commit + pop
    var onSearch: (String) -> Void = { _ in }          // §3: live filter, debounced 300 ms
    var onOpenOrgFilter: () -> Void = {}               // §3: Orgs chip → C-036
    var onOpenLeaderFilter: () -> Void = {}            // §3: Leaders chip → C-036
    var onPickGroup: (Int) -> Void = { _ in }          // §3: row tap → that row is the pick

    // R-31 ephemeral UI: the query as typed (§3 "live filter") and the single pick (§3: "Row
    // tap → that row becomes the selection"; OQ-005: tapping the selected row keeps it).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var selection: Int?
    /// `selection` while the pick is filtered out of view: Select stays enabled, no row matches.
    private static let pickOutOfView = -1

    /// invite-member tweaks (owner 2026-10-26): true puts L3's group list in its own vertical
    /// scroll under the pinned header and filter block, bouncing even when the rows fit. Default
    /// false keeps D22's full-length canvas for previews and capture.
    var scrollsList: Bool = false

    init(
        state: State,
        scrollsList: Bool = false,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (Int) -> Void = { _ in },
        onSearch: @escaping (String) -> Void = { _ in },
        onOpenOrgFilter: @escaping () -> Void = {},
        onOpenLeaderFilter: @escaping () -> Void = {},
        onPickGroup: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.scrollsList = scrollsList
        self.onBack = onBack
        self.onSelect = onSelect
        self.onSearch = onSearch
        self.onOpenOrgFilter = onOpenOrgFilter
        self.onOpenLeaderFilter = onOpenLeaderFilter
        self.onPickGroup = onPickGroup
        _query = SwiftUI.State(initialValue: state.searchText)
        _selection = SwiftUI.State(initialValue: state.groupNames.indices.contains(state.selectedIndex)
                                   && !(state.groupUnavailable[safe: state.selectedIndex] ?? false)
                                   ? state.selectedIndex : nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §2 L1: centred title "Select group".
    private static let pageTitle = "Select group"
    /// §2 L1: `trailingLabel: "Select"`.
    private static let selectLabel = "Select"
    /// §2 L2: placeholder "Search groups".
    private static let searchPlaceholder = "Search groups"
    /// §4: C-035 labels "Orgs", "Leaders" — the resting labels; any other label is a chosen
    /// filter (§2: "`active: true` once a filter is chosen").
    private static let restingOrgLabel = "Orgs"
    private static let restingLeaderLabel = "Leaders"
    /// OQ-004: "No groups ready to enroll" / "No groups match your search".
    private static let emptyMessage = "No groups ready to enroll"
    private static let noMatchMessage = "No groups match your search"
    /// §3 state 7: the one muted line that replaces the chips.
    private static let unavailableMessage = "Unavailable because currently enrolled"

    // MARK: - §2 geometry the screen owns

    // GAP — enrollment-select-group §2 L2: "16 pt between its two rows" — a vertical 16 with no
    // spacing token naming the role (the padding is `space-page-margin`, cited; this gap is not).
    private static let filterRowGap: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBlock
            if scrollsList {
                // §2 L3: "vertical scroll container directly under the filter block".
                ScrollView(.vertical) { listArea }
                    .scrollBounceBehavior(.always, axes: .vertical)
            } else {
                listArea
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: the page background
        // The highlight follows the caller's pick: a query that moves the picked row moves its
        // highlight with it, and one that filters it out of view leaves no row highlighted while
        // Select stays enabled (`pickOutOfView`; select-group §3) — so Select commits the row shown.
        .onChange(of: state.selectedIndex) { _, index in
            if state.groupNames.indices.contains(index), !isUnavailable(index) {
                selection = index
            } else if selection != nil {
                selection = Self.pickOutOfView
            }
        }
    }

    /// §2 L1: C-040 `style: backAndLink` (D60) — back glyph, centred title, trailing "Select";
    /// `trailingEnabled` = a group is picked (OQ-001 → OQ-C-040-001: `color-white-50`, inert).
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.pageTitle,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: Self.selectLabel,
            trailingEnabled: selection != nil,
            onLeading: onBack,
            onDone: {
                if let selection { onSelect(selection) }
            }
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: §2 L2 Filter block

    /// §2 L2: "an inline page container (not a component), 116 pt tall, padding
    /// `space-page-margin` (16) on all sides, 16 pt between its two rows".
    private var filterBlock: some View {
        VStack(alignment: .leading, spacing: Self.filterRowGap) {
            // C-034 editable form (D19 precedent, members-home): the field owns its focus, so
            // `focused` stays false and typing reaches `onChange` → `onSearch`.
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
                },
                editable: true
            )
            .ui2Element("C-034 SearchField")
            // §2: "Chip row, 24 pt tall, 8 pt gap" — C-035 `type: Menu`, width hugs the label.
            HStack(spacing: Token.Space.elementGap) {
                if state.orgFilterVisible {
                    FilterChip(type: .menu,
                               active: state.orgFilterLabel != Self.restingOrgLabel,
                               label: state.orgFilterLabel,
                               onTap: onOpenOrgFilter)
                        .ui2Element("C-035 FilterChip")
                }
                FilterChip(type: .menu,
                           active: state.leaderFilterLabel != Self.restingLeaderLabel,
                           label: state.leaderFilterLabel,
                           onTap: onOpenLeaderFilter)
                    .ui2Element(state.orgFilterVisible ? "C-035 FilterChip 2" : "C-035 FilterChip")
            }
        }
        .padding(Token.Space.pageMargin)
        // §2 L3 Rules: "one C-088 SectionDivider above the first row" — the frame draws it in the
        // block's last point (y218, the first row at y219), so it overlays the bottom padding.
        .overlay(alignment: .bottom) {
            if !visibleRows.isEmpty {
                SectionDivider()
                    .ui2Element("C-088 SectionDivider")
                    .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    // MARK: §2 L3 Group list

    /// §2 L3: "One C-037 ListResultRow per eligible group … horizontal inset `space-page-margin`
    /// (16), so rows and rules are 408 wide", "one C-088 SectionDivider … after every row" —
    /// each in its row's last point (frame: rows at 219/315/411, rules at 314/410/506).
    /// §3 `empty`: "one centred line in `color-text-secondary`". §3 `loading` / `error`: the list
    /// area is empty (their parts are spec gaps).
    private var listArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleRows, id: \.self) { index in
                groupRow(at: index)
                    .overlay(alignment: .bottom) {
                        SectionDivider()
                            .ui2Element(Self.partName("C-088 SectionDivider", ordinal: index + 2))
                    }
            }
            if let message = bodyMessage {
                // §3 `empty` / OQ-004. GAP — §3 names the colour only; the type style is
                // invites-home's ruled empty line (OQ-invites-home-003: "14 Regular" →
                // `type-body-sm`), as on enrollments-home.
                Text(message)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Token.Space.pageMargin)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §2 L3: C-037 `subject: .group`, `detail: .chips`, `trailing: .none`, `selection` from the
    /// screen's single pick. Chips, in order: leader · members · enrollments, each a C-043
    /// `value` with no `label`; enrollments > 0 → `highlighted`, every other chip → `muted`
    /// (OQ-006).
    @ViewBuilder private func groupRow(at index: Int) -> some View {
        if isUnavailable(index) {
            unavailableRow(at: index)
        } else {
            availableRow(at: index)
        }
    }

    private func availableRow(at index: Int) -> some View {
        let photo = state.groupPhotoURLs[safe: index] ?? ""
        let enrollments = state.groupEnrollmentCounts[safe: index] ?? 0
        return ListResultRow(
            subject: .group,
            title: state.groupNames[index],
            detail: .chips,
            chips: [
                ListResultRow.Chip(value: state.groupLeaderNames[safe: index] ?? "", state: .muted),
                ListResultRow.Chip(value: Self.count(state.groupMemberCounts[safe: index] ?? 0,
                                                     one: "member", many: "members"),
                                   state: .muted),
                ListResultRow.Chip(value: Self.count(enrollments, one: "enrollment", many: "enrollments"),
                                   state: enrollments > 0 ? .highlighted : .muted)
            ],
            trailing: .none,
            selection: selection == index ? .selected : .unselected,
            imageURL: photo.isEmpty ? nil : URL(string: photo),
            onTap: {
                // §3 single select; OQ-005: the selected row stays selected.
                selection = index
                onPickGroup(index)
            }
        )
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }

    /// §3 state 7 unavailable row: same position, the chips replaced by one muted line (C-037
    /// `detail=text`, whose description is `color-white-50`), not selectable (`onTap: nil` — C-037
    /// §4 "nil → the row is inert", so neither `onPickGroup` nor `onSelect` can fire for it).
    /// OQ-enrollment-select-group-7 (owner 2026-10-29): the whole row at `color-white-50` as its
    /// alpha, exactly as enrollment-select-program's unavailable row, so both pickers read alike.
    private func unavailableRow(at index: Int) -> some View {
        let photo = state.groupPhotoURLs[safe: index] ?? ""
        return ListResultRow(
            subject: .group,
            title: state.groupNames[index],
            detail: .text,
            description: Self.unavailableMessage,
            trailing: .none,
            selection: .unselected,
            imageURL: photo.isEmpty ? nil : URL(string: photo),
            onTap: nil
        )
        .mask(Token.white50)
        .disabled(true)
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }

    // MARK: - Derived

    private func isUnavailable(_ index: Int) -> Bool {
        state.groupUnavailable[safe: index] ?? false
    }

    /// §3 `loading` and `error` list no rows.
    private var visibleRows: [Int] {
        guard !state.loading, !state.failed else { return [] }
        return Array(state.groupNames.indices)
    }

    /// §3 `empty` / OQ-004: the search-or-filter copy when a query or a chosen chip narrows the
    /// list, otherwise "No groups ready to enroll".
    private var bodyMessage: String? {
        guard visibleRows.isEmpty, !state.loading, !state.failed else { return nil }
        let narrowed = !query.isEmpty
            || state.orgFilterLabel != Self.restingOrgLabel
            || state.leaderFilterLabel != Self.restingLeaderLabel
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    /// §2: "14 members", "1 enrollment" / "2 enrollments".
    private static func count(_ value: Int, one: String, many: String) -> String {
        "\(value) \(value == 1 ? one : many)"
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

extension EnrollmentSelectGroupScreen.State {

    /// The three groups on the frozen frame `group-selected` (§1 deviation 1: sample content),
    /// in §3's alphabetical order (deviation 5: the frame's order is sample content). Photos are
    /// stand-in URLs (picsum seeds).
    private static func groups(selectedIndex: Int) -> Self {
        Self(
            searchText: "",
            orgFilterVisible: true,
            orgFilterLabel: "Orgs",
            leaderFilterLabel: "Leaders",
            groupNames: ["Coffee and football", "Old professionals", "Young Professionals"],
            groupPhotoURLs: [
                "https://picsum.photos/seed/enrollment-select-group-2/256",
                "https://picsum.photos/seed/enrollment-select-group-3/256",
                "https://picsum.photos/seed/enrollment-select-group-1/256"
            ],
            groupLeaderNames: ["Steve Rogers", "John Smith", "Tony Stark"],
            groupMemberCounts: [7, 32, 14],
            groupEnrollmentCounts: [2, 1, 0],
            selectedIndex: selectedIndex,
            loading: false,
            failed: false
        )
    }

    /// §3 `none` — no group picked; Select disabled.
    static let noPick = groups(selectedIndex: -1)
    /// §3 `selected` (frame `group-selected`) — "Coffee and football" picked; Select enabled.
    static let selected = groups(selectedIndex: 0)
    /// §3 `already-enrolled warning` — Select tapped on "Coffee and football" (2 active
    /// enrollments); the confirmation itself is not a §4 part (OQ-002), so the picker renders.
    static let alreadyEnrolledWarning = groups(selectedIndex: 0)
    /// §3 `loading` — no cache: header + filter block, empty list area (C-076 is a spec gap).
    static let loading = Self(
        searchText: "", orgFilterVisible: true, orgFilterLabel: "Orgs", leaderFilterLabel: "Leaders",
        groupNames: [], groupPhotoURLs: [], groupLeaderNames: [], groupMemberCounts: [],
        groupEnrollmentCounts: [], selectedIndex: -1, loading: true, failed: false
    )
    /// §3 `empty` — the leader has no eligible group: "No groups ready to enroll" (OQ-004).
    static let empty = Self(
        searchText: "", orgFilterVisible: true, orgFilterLabel: "Orgs", leaderFilterLabel: "Leaders",
        groupNames: [], groupPhotoURLs: [], groupLeaderNames: [], groupMemberCounts: [],
        groupEnrollmentCounts: [], selectedIndex: -1, loading: false, failed: false
    )
    /// §3 `error` — load failed with no cache: empty list area (the error line + Retry is a gap).
    static let error = Self(
        searchText: "", orgFilterVisible: true, orgFilterLabel: "Orgs", leaderFilterLabel: "Leaders",
        groupNames: [], groupPhotoURLs: [], groupLeaderNames: [], groupMemberCounts: [],
        groupEnrollmentCounts: [], selectedIndex: -1, loading: false, failed: true
    )
    /// §3 state 7 `row-unavailable` — row 1 ("Coffee and football", 2 enrollments) is a group
    /// already enrolled in the checklist's program; the other two stay pickable.
    static let rowUnavailable: Self = {
        var state = groups(selectedIndex: -1)
        state.groupUnavailable = [true, false, false]
        return state
    }()
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("none") {
    EnrollmentSelectGroupScreen(state: .noPick)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("selected") {
    EnrollmentSelectGroupScreen(state: .selected)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("already-enrolled warning") {
    EnrollmentSelectGroupScreen(state: .alreadyEnrolledWarning)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    EnrollmentSelectGroupScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    EnrollmentSelectGroupScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    EnrollmentSelectGroupScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("row-unavailable") {
    EnrollmentSelectGroupScreen(state: .rowUnavailable)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
