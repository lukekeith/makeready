//
//  EnrollmentsHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollments-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups/{groupId}/enrollments ·
//  GET /api/programs/{programId}/enrollments · GET /api/enrollments/{id}/completion-stats ·
//  GET /api/search
//  (one assembled org-wide enrollments feed, the status-filter definition and the multi-org
//  org scope are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Enrollments — the Enrollments tab of the Home section switcher (§6): the org-wide enrollment
/// directory, grouped by group. A header of C-034 search over four C-035 filter chips, pinned below
/// the shell's TopNav, then one section per group — a C-058 header over its C-059 rows — with a
/// C-088 rule between consecutive sections (§2). The C-019 TopNav is the shell's (§1 deviation 3).
/// Composed only of §4's C-034, C-035, C-058, C-059 and C-088; C-021 and C-038 render inside C-058, C-057 and C-043 inside C-059.
/// C-036 FilterMenuOverlay is presented by a chip but §4 drops it ("presented, not on the
/// screen"), so a chip tap leaves the screen through `onOpenFilter`.
///
/// §3 names five states: `loading`, `populated`, `filtered-empty`, `empty` and `error`. The
/// `loading` skeleton sections and the `error` inline retry name no §4 component, no geometry
/// and no copy, so both render the persistent header over an empty body and the missing parts
/// are reported as spec gaps — not improvised here (the members-home precedent).
struct EnrollmentsHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays — one
    /// entry per group section, and one per enrollment row with `programGroupIndexes` naming its
    /// section — because the preview's props are JSON and the §4 views take flat parameters
    /// (R-05). Order is the feed's (OQ-enrollments-home-1: most-recent activity first).
    struct State {
        // ── Header (§2) ──
        /// C-034 `text`: the current query. "" shows the placeholder (§4 `Default`).
        var searchText: String
        /// C-035 `label` per chip: "label = current selection per C-035 contract" (§2). §2's
        /// resting labels: "All Orgs" · "All groups" · "All Leaders" · "Active".
        var orgFilterLabel: String
        var groupFilterLabel: String
        var leaderFilterLabel: String
        var statusFilterLabel: String
        /// §3 `loading`: "first launch with no cached data". The body shows no sections.
        var loading: Bool
        /// §3 `error`: the load failed. The body shows no sections.
        var failed: Bool
        // ── Sections (§2): one C-058 per entry ──
        /// C-058 `groupName`.
        var groupNames: [String]
        /// C-058 `leaderName`.
        var groupLeaderNames: [String]
        /// C-058 `imageURL`; "" = no photo → C-038's `Initials` (§2).
        var groupPhotoURLs: [String]
        // ── Rows (§2): one C-059 `state=Progress` per enrollment ──
        /// The section (index into `groupNames`) each enrollment sits in.
        var programGroupIndexes: [Int]
        /// C-059 `title`.
        var programTitles: [String]
        /// C-059 `progress` (0…1); 1.0 renders `state=Complete` (§3 row states).
        var programProgress: [Double]
        /// C-059's designed chips (C-059 §3a `Progress`): completed count, then hours.
        var programCompleteCounts: [String]
        var programHours: [String]
        /// The third C-043 chip's `value`: «Mon D, YYYY» (§2, OQ-C-059-1 (c)).
        var programEnrolledDates: [String]
        /// C-059 `cover`, resolved from the media cache by URL (R-19/R-32); "" = none.
        var programCoverURLs: [String]
        /// §2 draft rows (deviation 8): parallel to `programTitles`; a missing index reads as "".
        /// "" = an enrollment row; non-empty (e.g. "Draft · 2/6") = a draft row showing this label.
        var programDraftLabels: [String] = []
        /// A draft row's starter line under its label (e.g. "Started by Jane Doe"); "" = no line.
        var programDraftStarters: [String] = []
    }

    let state: State
    // §3 interactions that leave the screen. Each is an on<Verb> closure with R-03's no-op
    // default. The screen never decides what an action means. (No tab / nav-toggle callbacks —
    // the shell's TopNav owns them.)
    var onSearch: (String) -> Void = { _ in }       // §3: live local text filter (300ms, min 2)
    var onOpenFilter: (String) -> Void = { _ in }   // §3: chip tap → C-036 for that dimension
    var onOpenGroup: (Int) -> Void = { _ in }       // §3: C-058 arrow → groups-detail, by section
    /// §3: row tap → `onOpenProgram(section, row)` — enrollment and draft rows alike; the host
    /// decides the destination.
    var onOpenProgram: (Int, Int) -> Void = { _, _ in }
    /// §3: search became active / ended (members-home's pattern) — the shell hides its TopNav
    /// while it is active. The screen only reports it.
    var onSearchActiveChange: (Bool) -> Void = { _ in }

    // R-31 ephemeral UI: the query as typed (§3 "live text filter").
    @SwiftUI.State private var query: String
    /// The editable C-034's focus, as it reports it.
    @SwiftUI.State private var searchFocused = false

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onOpenFilter: @escaping (String) -> Void = { _ in },
        onOpenGroup: @escaping (Int) -> Void = { _ in },
        onOpenProgram: @escaping (Int, Int) -> Void = { _, _ in },
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onOpenFilter = onOpenFilter
        self.onOpenGroup = onOpenGroup
        self.onOpenProgram = onOpenProgram
        self.onSearchActiveChange = onSearchActiveChange
        _query = SwiftUI.State(initialValue: state.searchText)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2: "placeholder \"Search enrollments\"".
    private static let searchPlaceholder = "Search enrollments"
    /// §3 chip dimensions, in §2's order: org scope · groups · leaders · enrollment status.
    private static let filterDimensions = ["Orgs", "Groups", "Leaders", "Status"]
    /// §2's resting chip labels, in the same order — a chip off its resting label is narrowing.
    private static let restingFilterLabels = ["All Orgs", "All groups", "All Leaders", "Active"]
    /// §3 / OQ-enrollments-home-6 (closed): the two centred lines.
    private static let noMatchMessage = "No enrollments match"
    private static let emptyMessage = "No enrollments yet"
    /// §2: "a third `label=\"Enrolled\"`" C-043 chip.
    private static let enrolledLabel = "Enrolled"
    /// C-059 §3a `Progress`: "completed count, hours" — the chip keys of C-059's own samples.
    private static let completeLabel = "complete"
    private static let hoursLabel = "hours"
    /// §3: "debounce/min-chars follow search-home's precedent: 300ms, min 2".
    private static let minimumQueryLength = 2

    /// §3: search is active while the field is focused or holds a query (members-home's rule).
    static func isSearchActive(query: String, focused: Bool) -> Bool {
        focused || !query.isEmpty
    }

    private var searchActive: Bool { Self.isSearchActive(query: query, focused: searchFocused) }

    // MARK: - §2 geometry the screen owns

    // GAP — enrollments-home §2: "header block (`space-page-margin` 16 padding, 16 gap; 116
    // tall)" — the vertical 16 between search and chips has no spacing token naming the role.
    private static let headerGap: CGFloat = 16
    // GAP — enrollments-home §2: "Per group section (gap 16)" / "Enrollment list (starts 16
    // below the header)" — no spacing token names the header-to-list gap.
    private static let sectionInnerGap: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's; the C-019 TopNav is the shell's (§1 deviation 3).
        // §2: the header is a pinned section header (members-home's), so inside the shell's
        // scroll it stays below the TopNav and the sections scroll beneath it.
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                sectionsContainer
            } header: {
                header.background { Self.headerMaterial }
                    // topnav-height-env: once pinned, the growing TopNav pushes it down.
                    .pinnedBelowTopNav()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        .onChange(of: searchActive, initial: true) { _, active in onSearchActiveChange(active) }
    }

    // GAP — §2 pinned header: no material token — members-home's header material
    // (`ultraThinMaterial` under `color-layout-background` at 0.8).
    private static let headerScrimOpacity: Double = 0.8

    private static var headerMaterial: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Token.layoutBackground.opacity(headerScrimOpacity)
        }
    }

    // MARK: §2 Header

    /// §2: "header block (`space-page-margin` 16 padding, 16 gap; 116 tall)" — persists in every
    /// §3 state.
    private var header: some View {
        VStack(alignment: .leading, spacing: Self.headerGap) {
            // §2: C-034 "408×44, `Default` state". §3: its editable form — focus is the field's
            // own, reported so the screen can tell the shell when search is active.
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
                // members-home: while active the x is always there and ends the search.
                showsClearWhenEmpty: searchActive,
                onFocusChange: { searchFocused = $0 },
                clearDismisses: true,
                editable: true
            )
            .ui2Element("C-034 SearchField")
            .padding(.horizontal, Token.Space.pageMargin)
            chipRow
        }
        .padding(.vertical, Token.Space.pageMargin)
    }

    /// §2: "Filter rail — 4 × C-035 FilterChip (`type=Menu, active=false`), gap
    /// `space-element-gap` (8), 24 tall". The frame's fourth chip runs past the right edge, so
    /// the rail scrolls horizontally with the 16 leading inset; a horizontal carousel keeps its
    /// own ScrollView (D22).
    private var chipRow: some View {
        HorizontalRail {
            HStack(spacing: Token.Space.elementGap) {
                ForEach(chipLabels.indices, id: \.self) { index in
                    FilterChip(type: .menu, active: false, label: chipLabels[index]) {
                        onOpenFilter(Self.filterDimensions[index])
                    }
                    .ui2Element(Self.partName("C-035 FilterChip", ordinal: index + 1))
                }
            }
            .padding(.horizontal, Token.Space.pageMargin)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: §2 Sections

    /// §2: "the sections container (16 padding, `space-section-gap` 32 between blocks). Between
    /// consecutive group sections, one C-088 SectionDivider (408 wide, 32 above and below — the
    /// section gap belongs to this host)."
    private var sectionsContainer: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            ForEach(Array(visibleSections.enumerated()), id: \.element) { position, section in
                if position > 0 {
                    SectionDivider()
                        .ui2Element(Self.partName("C-088 SectionDivider", ordinal: position))
                }
                groupSection(section, ordinal: position + 1)
            }
            if let message = bodyMessage {
                // §3 / OQ-enrollments-home-6: "one centered `color-text-secondary` line".
                // GAP — §3 names the colour only; the type style is invites-home's ruled
                // empty line (OQ-invites-home-003: "14 Regular" → `type-body-sm`).
                Text(message)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(Token.Space.pageMargin)
    }

    /// §2 "Per group section (gap 16)": C-058 → 16 → the enrollment list.
    private func groupSection(_ section: Int, ordinal: Int) -> some View {
        VStack(alignment: .leading, spacing: Self.sectionInnerGap) {
            GroupSectionHeader(
                groupName: state.groupNames[section],
                leaderName: state.groupLeaderNames[safe: section] ?? "",
                imageURL: Self.url(state.groupPhotoURLs[safe: section]),
                initials: Self.initials(state.groupNames[section]),
                onOpen: { onOpenGroup(section) }
            )
            .ui2Element(Self.partName("C-058 GroupSectionHeader", ordinal: ordinal))
            // §2: "one C-059 StudyProgramRow (408×96, `state=Progress`) per enrollment of that
            // group, stacked with no gap and no separators."
            VStack(alignment: .leading, spacing: 0) {
                ForEach(visibleRows(in: section), id: \.self) { row in
                    programRow(row)
                }
            }
        }
    }

    /// §2: one row per entry, chosen by its draft label (`programDraftLabels[i]`; missing = "").
    @ViewBuilder
    private func programRow(_ row: Int) -> some View {
        let draftLabel = state.programDraftLabels[safe: row] ?? ""
        if draftLabel.isEmpty {
            enrollmentRow(row)
        } else {
            draftRow(row, label: draftLabel)
        }
    }

    /// §2 Draft row (deviation 8): "the same 408×96 row with the same 64×64 cover and title, but
    /// the label is shown, and on the line below it the starter text … No C-057 and no C-043 are
    /// drawn on a draft row." C-059's `Program` variant is the row with neither bar nor chips:
    /// its description line carries the label and its caption line the starter ("" drops it).
    private func draftRow(_ row: Int, label: String) -> some View {
        let starter = state.programDraftStarters[safe: row] ?? ""
        return StudyProgramRow(
            state: .program,
            title: state.programTitles[row],
            description: label,
            caption: starter.isEmpty ? nil : starter,
            progress: 0,
            metaChips: [],
            cover: Self.cachedImage(state.programCoverURLs[safe: row]),
            onTap: { onOpenProgram(state.programGroupIndexes[safe: row] ?? 0, row) }
        )
        .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: row + 1))
    }

    /// §2 Enrollment row: "title → C-057 PercentBar `size=sm`/`Left` → C-043 MetaChips (the designed two + a
    /// third `label=\"Enrolled\"`, `value=«Mon D, YYYY»`, `align=right`, `state=default`) →
    /// 64×64 `radius-card` cover". §3 row states: "a 100% enrollment renders C-059
    /// `state=Complete`" — whose completed-count chip is C-043 `state=complete` (C-059 §3a).
    private func enrollmentRow(_ row: Int) -> some View {
        let progress = state.programProgress[safe: row] ?? 0
        let complete = progress >= 1
        return StudyProgramRow(
            state: complete ? .complete : .progress,
            title: state.programTitles[row],
            progress: progress,
            metaChips: [
                .init(
                    value: state.programCompleteCounts[safe: row] ?? "",
                    label: Self.completeLabel,
                    state: complete ? .complete : .default
                ),
                .init(value: state.programHours[safe: row] ?? "", label: Self.hoursLabel),
                .init(
                    value: state.programEnrolledDates[safe: row] ?? "",
                    label: Self.enrolledLabel,
                    align: .leading
                )
            ],
            cover: Self.cachedImage(state.programCoverURLs[safe: row]),
            onTap: { onOpenProgram(state.programGroupIndexes[safe: row] ?? 0, row) }
        )
        .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: row + 1))
    }

    // MARK: - §3 rules

    private var chipLabels: [String] {
        [state.orgFilterLabel, state.groupFilterLabel, state.leaderFilterLabel, state.statusFilterLabel]
    }

    /// §3: "Search: live text filter over program title + group name … min 2".
    private var needle: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= Self.minimumQueryLength ? trimmed : ""
    }

    private func visibleRows(in section: Int) -> [Int] {
        let groupMatches = !needle.isEmpty && state.groupNames[section].localizedCaseInsensitiveContains(needle)
        return state.programTitles.indices.filter { row in
            state.programGroupIndexes[safe: row] == section
                && (needle.isEmpty || groupMatches || state.programTitles[row].localizedCaseInsensitiveContains(needle))
        }
    }

    /// §3 `loading` and `error` show no sections; otherwise a group shows when it has a row left.
    private var visibleSections: [Int] {
        guard !state.loading, !state.failed else { return [] }
        return state.groupNames.indices.filter { !visibleRows(in: $0).isEmpty }
    }

    /// §3: `filtered-empty` → "No enrollments match"; `empty` (zero enrollments org-wide) →
    /// "No enrollments yet". `filtered-empty` is the empty body while a query or a chip off its
    /// resting label is narrowing the list.
    private var bodyMessage: String? {
        guard visibleSections.isEmpty, !state.loading, !state.failed else { return nil }
        let narrowed = !needle.isEmpty || chipLabels != Self.restingFilterLabels
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

    private static func url(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// R-19/R-32: the cover's bytes come from the media cache by URL; the view does no loading.
    private static func cachedImage(_ raw: String?) -> Image? {
        guard let url = url(raw), let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
    }

    /// C-058 `initials` — "derived by the caller from `groupName`": the first letter of the first
    /// two words, uppercased.
    private static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
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

extension EnrollmentsHomeScreen.State {

    /// §3 `populated`: every name, title and date is the text on the frozen frame `default`
    /// (node 3823:34548; §1 deviation 1: sample content), in the frame's order. Fills are the
    /// frame's bar widths over 408 (0.12 · 0.54 · 0.31 · 0.05). The frame draws no completed-count
    /// or hours chip (§1 deviation 6), so those take C-059's own `Progress` sample ("12 complete"
    /// · "15 hours"). Photos and covers are stand-in URLs (the component previews' picsum seeds).
    static let populated = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: false,
        failed: false,
        groupNames: ["Stickane Family", "Young Professionals"],
        groupLeaderNames: ["Scott Stickane", "Luke Keith"],
        groupPhotoURLs: [
            "https://picsum.photos/seed/enrollments-home-group-1/256",
            "https://picsum.photos/seed/enrollments-home-group-2/256"
        ],
        programGroupIndexes: [0, 0, 0, 1],
        programTitles: ["Daily Inspiration", "Romans in 30 days", "John 1:1-18", "Daily Inspiration"],
        programProgress: [0.12, 0.54, 0.31, 0.05],
        programCompleteCounts: ["12", "12", "12", "12"],
        programHours: ["15", "15", "15", "15"],
        programEnrolledDates: ["Jan 3, 2025", "Jan 3, 2025", "Jan 3, 2025", "Jan 3, 2025"],
        programCoverURLs: [
            "https://picsum.photos/seed/c059/128/176",
            "https://picsum.photos/seed/enrollments-home-2/128/176",
            "https://picsum.photos/seed/enrollments-home-3/128/176",
            "https://picsum.photos/seed/c059/128/176"
        ]
    )

    /// §3 `populated` capture state `with-draft` (deviation 8): "one section with two enrollment
    /// rows + one draft row". The frame's first group with two of its titles, then a draft
    /// ("Draft · 2/6", "Started by Jane Doe" — §2's samples). Photo and covers are catalog images
    /// (image-fixtures).
    static let withDraft = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: false,
        failed: false,
        groupNames: ["Stickane Family"],
        groupLeaderNames: ["Scott Stickane"],
        groupPhotoURLs: ["http://localhost:5961/api/projects/makeready/images/image-5"],
        programGroupIndexes: [0, 0, 0],
        programTitles: ["Romans in 30 days", "John 1:1-18", "Wisdom at Work"],
        programProgress: [0.54, 0.31, 0],
        programCompleteCounts: ["12", "12", ""],
        programHours: ["15", "15", ""],
        programEnrolledDates: ["Jan 3, 2025", "Jan 3, 2025", ""],
        programCoverURLs: [
            "http://localhost:5961/api/projects/makeready/images/romans-new-life-baptism",
            "http://localhost:5961/api/projects/makeready/images/john-vine-branches",
            "http://localhost:5961/api/projects/makeready/images/proverbs-wisdom-at-work"
        ],
        programDraftLabels: ["", "", "Draft · 2/6"],
        programDraftStarters: ["", "", "Started by Jane Doe"]
    )

    /// §3 `loading`: "first launch with no cached data … search + chips render immediately".
    static let loading = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: true,
        failed: false,
        groupNames: [],
        groupLeaderNames: [],
        groupPhotoURLs: [],
        programGroupIndexes: [],
        programTitles: [],
        programProgress: [],
        programCompleteCounts: [],
        programHours: [],
        programEnrolledDates: [],
        programCoverURLs: []
    )

    /// §3 `filtered-empty`: the "All groups" chip set to the frame's "Young Professionals" and
    /// the query "Romans" (a title on the frame that group does not have) — the feed answers
    /// nothing, so the body shows "No enrollments match".
    static let filteredEmpty = Self(
        searchText: "Romans",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "Young Professionals",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: false,
        failed: false,
        groupNames: [],
        groupLeaderNames: [],
        groupPhotoURLs: [],
        programGroupIndexes: [],
        programTitles: [],
        programProgress: [],
        programCompleteCounts: [],
        programHours: [],
        programEnrolledDates: [],
        programCoverURLs: []
    )

    /// §3 `empty`: "zero enrollments org-wide", every chip at its resting label.
    static let empty = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: false,
        failed: false,
        groupNames: [],
        groupLeaderNames: [],
        groupPhotoURLs: [],
        programGroupIndexes: [],
        programTitles: [],
        programProgress: [],
        programCompleteCounts: [],
        programHours: [],
        programEnrolledDates: [],
        programCoverURLs: []
    )

    /// §3 `error`: "inline retry in the body; header persists" — the retry has no §4 component
    /// or copy (a spec gap), so the body is empty.
    static let error = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        groupFilterLabel: "All groups",
        leaderFilterLabel: "All Leaders",
        statusFilterLabel: "Active",
        loading: false,
        failed: true,
        groupNames: [],
        groupLeaderNames: [],
        groupPhotoURLs: [],
        programGroupIndexes: [],
        programTitles: [],
        programProgress: [],
        programCompleteCounts: [],
        programHours: [],
        programEnrolledDates: [],
        programCoverURLs: []
    )
}

// MARK: - Previews (D21): one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("loading") {
    EnrollmentsHomeScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated") {
    EnrollmentsHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("filtered-empty") {
    EnrollmentsHomeScreen(state: .filteredEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    EnrollmentsHomeScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    EnrollmentsHomeScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("with-draft") {
    EnrollmentsHomeScreen(state: .withDraft)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
