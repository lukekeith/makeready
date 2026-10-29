//
//  EnrollmentSelectProgramScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollment-select-program in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/programs · GET /api/group-leaders ·
//  GET /api/groups/{groupId}/enrollments (the enrollable filter, the completed-enrollment count,
//  the org filter and server-side search are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select program — step "Choose a study program" of the enrollment checklist
/// (`groups-enroll-program`, §6): the leader picks the ONE program to enroll; only Select
/// commits. C-040 header, a filter band of C-034 search over two C-035 chips, then the program
/// list of selectable C-037 rows between C-088 rules (§2). Composed only of §4's C-040, C-034,
/// C-035, C-037 and C-088; C-038 and C-043 render inside C-037 (§4).
///
/// C-036 FilterMenuOverlay and the already-enrolled warning are presented by this screen but are
/// not on §4's roll-call ("Overlays presented", §4/§6), so a chip tap and Select leave the screen
/// through `onOpenOrgFilter` / `onOpenLeaderFilter` / `onSelect`.
///
/// §3 names `none`, `selected`, `already-enrolled warning` and `loading / empty / no results`
/// (OQ-004). `none`, `selected`, `empty` and `no results` render in full. `already-enrolled
/// warning` renders the picker under its confirm sheet — the sheet (OQ-002) is not a §4 part.
/// `loading` (C-076 ActivitySpinner, not on §4) renders the header and filters over an empty
/// list area; the missing part is reported as a spec gap, not improvised here (the
/// enrollment-select-group precedent).
struct EnrollmentSelectProgramScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per program row in the supplier's order, because the preview's props are JSON and
    /// the §4 views take flat parameters (R-05).
    struct State {
        // ── Filter band (§2 L3) ──
        /// C-034 `text` — the current query; "" → the placeholder shows ("Search study programs").
        var searchText: String
        /// OQ-005: the Orgs chip is hidden for a single-org leader; the frame draws multi-org.
        var orgFilterVisible: Bool
        /// C-035 `label` of the Orgs chip — the chosen option, or "Orgs" at rest (§4).
        var orgFilterLabel: String
        /// C-035 `label` of the Leaders chip — the chosen option, or "Leaders" at rest (§4).
        var leaderFilterLabel: String
        // ── Program list (§2 L4) — C-037 `Program · selectable`, one per enrollable program ──
        /// C-037 `title` — the program name.
        var programTitles: [String]
        /// C-038's cover inside C-037; "" = no cover → C-038's own fallback.
        var programCoverURLs: [String]
        /// First chip — the created month, already `MMM yyyy` ("May 2026", §2).
        var programCreatedLabels: [String]
        /// Second chip — the length ("45 days", §2).
        var programDayCounts: [Int]
        /// Third chip — completed enrollments (OQ-003); 0 → "Never enrolled", > 0 → highlighted.
        var programCompletedCounts: [Int]
        /// The picked row on open (§3 "Opening with a value"); -1 = no program picked (`none`).
        var selectedIndex: Int
        // ── List area (§3 / OQ-004) ──
        /// OQ-004 loading: no cache, the list has not arrived.
        var loading: Bool
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                        // §3 Back: discard the pick + pop
    var onSelect: (Int) -> Void = { _ in }             // §3 Select: already-enrolled check, commit + pop
    var onSearch: (String) -> Void = { _ in }          // §3: filters as the leader types
    var onOpenOrgFilter: () -> Void = {}               // §3: Orgs ▾ → C-036
    var onOpenLeaderFilter: () -> Void = {}            // §3: Leaders ▾ → C-036
    var onPickProgram: (Int) -> Void = { _ in }        // §3: row tap → that row is the pick

    // R-31 ephemeral UI: the query as typed and the single pick (§3 "Tap a row selects it and
    // deselects any other"; OQ-004: tapping the selected row keeps it selected).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var selection: Int?
    /// `selection` while the pick is filtered out of view: Select stays enabled, no row matches.
    private static let pickOutOfView = -1

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (Int) -> Void = { _ in },
        onSearch: @escaping (String) -> Void = { _ in },
        onOpenOrgFilter: @escaping () -> Void = {},
        onOpenLeaderFilter: @escaping () -> Void = {},
        onPickProgram: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
        self.onSearch = onSearch
        self.onOpenOrgFilter = onOpenOrgFilter
        self.onOpenLeaderFilter = onOpenLeaderFilter
        self.onPickProgram = onPickProgram
        _query = SwiftUI.State(initialValue: state.searchText)
        _selection = SwiftUI.State(initialValue: state.programTitles.indices.contains(state.selectedIndex)
                                   ? state.selectedIndex : nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §2 L2: centred title "Select program".
    private static let pageTitle = "Select program"
    /// §2 L2 / §1 deviation 3: trailing action "Select".
    private static let selectLabel = "Select"
    /// §2 L3: placeholder "Search study programs".
    private static let searchPlaceholder = "Search study programs"
    /// §4: C-035 labels "Orgs", "Leaders" — the resting labels; any other label is a set filter
    /// (§4: "`active=true` once a filter is set").
    private static let restingOrgLabel = "Orgs"
    private static let restingLeaderLabel = "Leaders"
    /// OQ-004: "No study programs found" / "No programs match your search" (1.0 copy).
    private static let emptyMessage = "No study programs found"
    private static let noMatchMessage = "No programs match your search"
    /// §2 L4 / §1 deviation 1: the history chip at zero.
    private static let neverEnrolled = "Never enrolled"

    // MARK: - §2 geometry the screen owns

    // GAP — enrollment-select-program §2 L3: "16 gap, then a chip row" — a vertical 16 with no
    // spacing token naming the role (the padding is `space-page-margin`, cited; this gap is not).
    private static let filterRowGap: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§2 L1) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBand
            listArea
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: the page background
        // The highlight follows the caller's pick: a query that moves the picked row moves its
        // highlight with it, and one that filters it out of view leaves no row highlighted while
        // Select stays enabled (`pickOutOfView`; select-group §3) — so Select commits the row shown.
        .onChange(of: state.selectedIndex) { _, index in
            if state.programTitles.indices.contains(index) {
                selection = index
            } else if selection != nil {
                selection = Self.pickOutOfView
            }
        }
    }

    /// §2 L2: C-040 `style: backAndLink` (D60) — back glyph, centred title, trailing "Select";
    /// `trailingEnabled` = a row is picked (OQ-001 → OQ-C-040-001: `color-white-50`, inert).
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

    // MARK: §2 L3 Filter band

    /// §2 L3: "screen-local frame, 440×116 … padding 16 top, 16 sides", search, a 16 gap, the
    /// chip row (gap 8), 16 bottom, closed by a C-088.
    private var filterBand: some View {
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
            // §2: "a chip row at y 179 with gap 8" — C-035 `type: Menu`, width hugs the label.
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
        // §2 L3: "closed by a C-088 SectionDivider (408×1, y 218)" — the band's last point (the
        // first row at y 219), so it overlays the bottom padding.
        .overlay(alignment: .bottom) {
            SectionDivider()
                .ui2Element("C-088 SectionDivider")
                .padding(.horizontal, Token.Space.pageMargin)
        }
    }

    // MARK: §2 L4 Program list

    /// §2 L4: "x 16, width 408. Each item is C-037 … followed by a C-088 SectionDivider" — each
    /// rule in its row's last point (frame: rows at 219/315/411, rules at 314/410/506).
    /// OQ-004 empty / no results: one centred `color-text-secondary` line. OQ-004 loading: the
    /// list area is empty (C-076 is a spec gap).
    private var listArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleRows, id: \.self) { index in
                programRow(at: index)
                    .overlay(alignment: .bottom) {
                        SectionDivider()
                            .ui2Element(Self.partName("C-088 SectionDivider", ordinal: index + 2))
                    }
            }
            if let message = bodyMessage {
                // OQ-004. GAP — the answer names the colour only; the type style is
                // invites-home's ruled empty line (OQ-invites-home-003: `type-body-sm`), as on
                // enrollment-select-group.
                Text(message)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Token.Space.pageMargin)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §4: C-037 `subject=program · detail=chips · trailing=none`, `selection` from the screen's
    /// single pick. Chips, in order: created month · length · enrollment history — the first two
    /// `Default · Single`, the third `Default` ("Never enrolled") or `Highlighted`
    /// ("«n» completed enrollment(s)", OQ-003's singular).
    private func programRow(at index: Int) -> some View {
        let cover = state.programCoverURLs[safe: index] ?? ""
        let completed = state.programCompletedCounts[safe: index] ?? 0
        return ListResultRow(
            subject: .program,
            title: state.programTitles[index],
            detail: .chips,
            chips: [
                ListResultRow.Chip(value: state.programCreatedLabels[safe: index] ?? ""),
                ListResultRow.Chip(value: Self.count(state.programDayCounts[safe: index] ?? 0,
                                                     one: "day", many: "days")),
                completed > 0
                    ? ListResultRow.Chip(value: Self.count(completed, one: "completed enrollment",
                                                           many: "completed enrollments"),
                                         state: .highlighted)
                    : ListResultRow.Chip(value: Self.neverEnrolled)
            ],
            trailing: .none,
            selection: selection == index ? .selected : .unselected,
            imageURL: cover.isEmpty ? nil : URL(string: cover),
            onTap: {
                // §3 single select; OQ-004: the selected row stays selected.
                selection = index
                onPickProgram(index)
            }
        )
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }

    // MARK: - Derived

    /// OQ-004 loading lists no rows.
    private var visibleRows: [Int] {
        guard !state.loading else { return [] }
        return Array(state.programTitles.indices)
    }

    /// OQ-004: the no-results copy when a query or a set chip narrows the list, otherwise
    /// "No study programs found".
    private var bodyMessage: String? {
        guard visibleRows.isEmpty, !state.loading else { return nil }
        let narrowed = !query.isEmpty
            || state.orgFilterLabel != Self.restingOrgLabel
            || state.leaderFilterLabel != Self.restingLeaderLabel
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    /// §2: "45 days", "1 completed enrollment" / "4 completed enrollments".
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

extension EnrollmentSelectProgramScreen.State {

    /// The three programs on the frozen frame `program-selected` (§1 deviation 2: sample
    /// content). Covers are stand-in URLs (picsum seeds).
    private static func programs(selectedIndex: Int) -> Self {
        Self(
            searchText: "",
            orgFilterVisible: true,
            orgFilterLabel: "Orgs",
            leaderFilterLabel: "Leaders",
            programTitles: ["Daily Inspiration", "Daily Inspiration", "Daily Inspiration"],
            programCoverURLs: [
                "https://picsum.photos/seed/enrollment-select-program-1/256",
                "https://picsum.photos/seed/enrollment-select-program-2/256",
                "https://picsum.photos/seed/enrollment-select-program-3/256"
            ],
            programCreatedLabels: ["May 2026", "Jul 2025", "Apr 2024"],
            programDayCounts: [45, 45, 30],
            programCompletedCounts: [0, 4, 0],
            selectedIndex: selectedIndex,
            loading: false
        )
    }

    /// An empty list with the band at rest.
    private static func emptyList(searchText: String, loading: Bool) -> Self {
        Self(
            searchText: searchText, orgFilterVisible: true, orgFilterLabel: "Orgs",
            leaderFilterLabel: "Leaders", programTitles: [], programCoverURLs: [],
            programCreatedLabels: [], programDayCounts: [], programCompletedCounts: [],
            selectedIndex: -1, loading: loading
        )
    }

    /// §3 `none` — no program picked; Select disabled.
    static let noPick = programs(selectedIndex: -1)
    /// §3 `selected` (frame `program-selected`) — row 3 picked; Select enabled.
    static let selected = programs(selectedIndex: 2)
    /// §3 `already-enrolled warning` — Select pressed on row 3; the confirm sheet itself is not a
    /// §4 part (OQ-002), so the picker renders.
    static let alreadyEnrolledWarning = programs(selectedIndex: 2)
    /// OQ-004 loading — no cache: header + filter band, empty list area (C-076 is a spec gap).
    static let loading = emptyList(searchText: "", loading: true)
    /// OQ-004 empty — no enrollable program: "No study programs found".
    static let empty = emptyList(searchText: "", loading: false)
    /// OQ-004 no results — a query matches nothing: "No programs match your search".
    static let noResults = emptyList(searchText: "Romans", loading: false)
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("none") {
    EnrollmentSelectProgramScreen(state: .noPick)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("selected") {
    EnrollmentSelectProgramScreen(state: .selected)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("already-enrolled warning") {
    EnrollmentSelectProgramScreen(state: .alreadyEnrolledWarning)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    EnrollmentSelectProgramScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    EnrollmentSelectProgramScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("no results") {
    EnrollmentSelectProgramScreen(state: .noResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
