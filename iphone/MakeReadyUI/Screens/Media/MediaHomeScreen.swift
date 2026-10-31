//
//  MediaHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen media-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none:
//  GET /api/organizations/{organizationId}/media/library?type=photo&limit=200 (paged by nextCursor)
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Media home — the Home tab's Media section root (§6, D64): a browse-only photo library. A fixed
/// top bar (C-034 search, three C-035 Menu chips, the date-range line) over C-129 MediaBrowser,
/// the screen's only scroller (media-page D16). No TopNav, no TabBar: the shell's
/// `HomeSectionLayout` owns both (§1 deviation 1).
///
/// C-036 FilterMenuOverlay and ImageViewer are presented by the host (§4 "Not on this list", §6),
/// so a chip tap and a tile tap leave the screen as closures.
struct MediaHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Photos are parallel
    /// arrays, oldest → newest (media-page D5), because the preview's props are JSON.
    struct State {
        /// §3's closed states list (`MediaHomeScreen.State.Phase`, media-page PLAN Task 8).
        enum Phase: String {
            case loading, loaded, empty, noResults, failed
        }

        var phase: Phase
        /// C-034 `text` — the query; "" → the "Search" placeholder.
        var searchText: String
        /// §3 Tags chip: the selected tags; empty = no filter.
        var selectedTags: [String]
        /// §3 Leaders chip: the selected uploaders' names; empty = no filter.
        var selectedLeaders: [String]
        /// §3 Time chip: one of `MediaHomeScreen.timeOptions`.
        var timeOption: String
        /// The photos C-129 shows (already filtered by the host's `MediaHomeMapper`, §5).
        /// "" = no image in the cache yet → C-129's dark placeholder.
        var photoURLs: [String]
        /// Each photo's date (`takenAt ?? createdAt`), "yyyy-MM-dd".
        var photoDates: [String]
        /// Each photo's title — its accessibility label.
        var photoTitles: [String]
        /// §3 opening a photo: the tile ImageViewer is open on (C-129 `hiddenItemID`).
        var hiddenItemID: String? = nil
        /// §3 opening a photo: C-129 `frozen` while ImageViewer is up.
        var frozen: Bool = false
        /// §3 pull past the newest end: C-129 `refreshing` while the reload runs.
        var refreshing: Bool = false
    }

    let state: State
    // §3 "Actions out of the screen (D14, no-op defaults)" — R-03 / R-33.
    var onSearch: (String) -> Void = { _ in }
    var onSearchActiveChange: (Bool) -> Void = { _ in }
    var onTapTags: () -> Void = {}                       // §3 R2: chip tap → host presents C-036
    var onTapLeaders: () -> Void = {}
    var onTapTime: () -> Void = {}
    var onClearFilters: () -> Void = {}                  // §3 noResults "Clear filters"
    var onRetry: () -> Void = {}                         // §3 failed "Retry"
    var onLevelChange: (MediaBrowser.Level) -> Void = { _ in }
    var onTap: (String, CGRect) -> Void = { _, _ in }    // §3 opening a photo → ImageViewer
    var onVisibleRangeChange: (Range<Int>) -> Void = { _ in }
    var onScrollChange: (CGFloat, Bool) -> Void = { _, _ in }
    var onRefresh: () -> Void = {}
    /// §5 "the container loads … into a bounded cache": the host's image provider, keyed by the
    /// photo's `photoURLs` entry. nil → the preview module's `Ui2ImageCache` (previews, capture).
    var image: ((String) -> UIImage?)? = nil
    /// C-129 `imageGeneration`, passed through: the host bumps it when new images land.
    var imageGeneration: Int = 0

    // R-31 ephemeral UI: the query as typed, C-129's level (§3 "the screen holds C-129's
    // `level`. It opens at `five`"), the range C-129 last reported, and the scroll-to-newest bump.
    @SwiftUI.State private var query: String
    @SwiftUI.State private var level: MediaBrowser.Level = .five
    @SwiftUI.State private var visibleRange: Range<Int>?
    @SwiftUI.State private var scrollToNewestToken = 0

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in },
        onTapTags: @escaping () -> Void = {},
        onTapLeaders: @escaping () -> Void = {},
        onTapTime: @escaping () -> Void = {},
        onClearFilters: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onLevelChange: @escaping (MediaBrowser.Level) -> Void = { _ in },
        onTap: @escaping (String, CGRect) -> Void = { _, _ in },
        onVisibleRangeChange: @escaping (Range<Int>) -> Void = { _ in },
        onScrollChange: @escaping (CGFloat, Bool) -> Void = { _, _ in },
        onRefresh: @escaping () -> Void = {},
        image: ((String) -> UIImage?)? = nil,
        imageGeneration: Int = 0
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSearchActiveChange = onSearchActiveChange
        self.onTapTags = onTapTags
        self.onTapLeaders = onTapLeaders
        self.onTapTime = onTapTime
        self.onClearFilters = onClearFilters
        self.onRetry = onRetry
        self.onLevelChange = onLevelChange
        self.onTap = onTap
        self.onVisibleRangeChange = onVisibleRangeChange
        self.onScrollChange = onScrollChange
        self.onRefresh = onRefresh
        self.image = image
        self.imageGeneration = imageGeneration
        _query = SwiftUI.State(initialValue: state.searchText)
    }

    // MARK: - §2 / §3 constants

    /// §2: C-034 placeholder "Search".
    private static let searchPlaceholder = "Search"
    /// §3 Time chip options, in order; the first is "no filter".
    static let timeOptions = ["All time", "Last 7 days", "Last 30 days", "Last 90 days"]
    // GAP — media-home §2: "C-129 … to the bottom of the screen". The screen fills its host's
    // height; under the capture harness (which proposes no height) that is the device height
    // (956) less the 59pt top inset the harness draws. No layout token.
    private static let canvasHeight: CGFloat = 897

    // MARK: - Derived (§3)

    /// §3 chip label rule: "«none» → the one selection, or «first» +«n−1»".
    private static func chipLabel(_ resting: String, _ picked: [String]) -> String {
        switch picked.count {
        case 0: return resting
        case 1: return picked[0]
        default: return "\(picked[0]) +\(picked.count - 1)"
        }
    }

    private var timeActive: Bool { state.timeOption != Self.timeOptions[0] }

    /// C-129 `items`, oldest → newest.
    private var items: [MediaBrowser.Item] {
        state.photoDates.indices.map { index in
            let date = Self.parse(state.photoDates[index]) ?? .distantPast
            let title = state.photoTitles.indices.contains(index) ? state.photoTitles[index] : ""
            return MediaBrowser.Item(
                id: Self.itemID(index),
                date: date,
                accessibilityLabel: "\(title), \(Self.dayFormatter.string(from: date))"
            )
        }
    }

    private static func itemID(_ index: Int) -> String { "photo-\(index)" }

    /// §5: C-129 never loads an image; the screen reads the host's cache (Ui2ImageCache in the
    /// preview module). §3 `loading`: "C-129 … with its dark placeholder tiles" → nil for all.
    private func image(for id: String) -> UIImage? {
        guard state.phase != .loading,
              let index = Int(id.dropFirst("photo-".count)),
              state.photoURLs.indices.contains(index),
              !state.photoURLs[index].isEmpty else { return nil }
        if let image { return image(state.photoURLs[index]) }
        guard let url = URL(string: state.photoURLs[index]) else { return nil }
        return Ui2ImageCache.shared.image(for: url)
    }

    /// §2.1 / §3: the date line shows only at `five`, with photos on screen, and not while the
    /// failed notice row holds its slot (§2.4) or while loading ("No date line").
    private var showsDateLine: Bool {
        level == .five && state.phase == .loaded && !state.photoDates.isEmpty
    }

    /// §2.4: failed with photos loaded → the notice row in the date line's slot.
    private var showsNotice: Bool { state.phase == .failed && !state.photoDates.isEmpty }

    /// §2.2: C-129 stays for loading, loaded and failed-with-photos; §2.3's lines replace it
    /// otherwise.
    private var showsGrid: Bool {
        switch state.phase {
        case .loading, .loaded: return true
        case .failed: return !state.photoDates.isEmpty
        case .empty, .noResults: return false
        }
    }

    /// §3 Date-range line: the dates of the items C-129 reports (all items until it reports).
    private var dateRange: String {
        let all = items
        guard !all.isEmpty else { return "" }
        let range = visibleRange.map { $0.clamped(to: 0..<all.count) } ?? 0..<all.count
        guard let first = range.first, let last = range.last else { return "" }
        return Self.formatRange(all[first].date, all[last].date)
    }

    /// §3 formats: "Oct 10, 2026" · "Oct 10–11, 2026" · "Sep 15 – Oct 9, 2026".
    static func formatRange(_ start: Date, _ end: Date) -> String {
        let calendar = Calendar.current
        let a = calendar.dateComponents([.year, .month, .day], from: start)
        let b = calendar.dateComponents([.year, .month, .day], from: end)
        if a == b { return dayFormatter.string(from: start) }
        if a.year == b.year && a.month == b.month {
            return "\(monthDayFormatter.string(from: start))–\(b.day ?? 0), \(b.year ?? 0)"
        }
        if a.year == b.year {
            return "\(monthDayFormatter.string(from: start)) – \(dayFormatter.string(from: end))"
        }
        // Not in §3's list (a range across years): both ends in full.
        return "\(dayFormatter.string(from: start)) – \(dayFormatter.string(from: end))"
    }

    private static let dayFormatter: DateFormatter = formatter("MMM d, yyyy")
    private static let monthDayFormatter: DateFormatter = formatter("MMM d")
    private static let inputFormatter: DateFormatter = formatter("yyyy-MM-dd")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current            // §3: `timeZone` the device time zone
        f.dateFormat = format
        return f
    }

    private static func parse(_ raw: String) -> Date? {
        inputFormatter.date(from: raw)?.addingTimeInterval(12 * 3600)
    }

    /// §3: "A search or chip change keeps the level and scrolls to the newest end".
    private var filterKey: String {
        [query, state.selectedTags.joined(separator: "\u{1F}"),
         state.selectedLeaders.joined(separator: "\u{1F}"), state.timeOption].joined(separator: "\u{1E}")
    }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — C-129 is the screen's only scroller (D16).
        VStack(spacing: 0) {
            topBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: Self.canvasHeight, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)              // §2: page ground
        .onChange(of: filterKey) { scrollToNewestToken += 1 }
    }

    // MARK: §2.1 Top bar

    /// §2.1: fixed, full width, `color-layout-background`, `space-page-margin` padding.
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                focused: false,
                // §3 Search: "updates on every keystroke (`onSearch(String)`) with no server call".
                onChange: { newValue in
                    query = newValue
                    onSearch(newValue)
                },
                // §3: "C-034's clear button empties it."
                onClear: {
                    query = ""
                    onSearch("")
                },
                onFocusChange: onSearchActiveChange,
                editable: true
            )
            .ui2Element("C-034 SearchField")

            chipRow
                .padding(.top, Token.Space.elementGap)

            if showsDateLine {
                // §2.1 Date-range line (OQ-media-home-004).
                Text(dateRange)
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundStyle(Token.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, Token.Space.elementGap)
            } else if showsNotice {
                noticeRow
                    .padding(.top, Token.Space.elementGap)
            }
        }
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.layoutBackground)
    }

    /// §2.1 Chip row: three C-035 `type: Menu`, `space-element-gap` apart; no horizontal scroll.
    private var chipRow: some View {
        HStack(spacing: Token.Space.elementGap) {
            FilterChip(
                type: .menu,
                active: !state.selectedTags.isEmpty,
                label: Self.chipLabel("Tags", state.selectedTags),
                onTap: onTapTags
            )
            .ui2Element("C-035 FilterChip")
            FilterChip(
                type: .menu,
                active: !state.selectedLeaders.isEmpty,
                label: Self.chipLabel("Leaders", state.selectedLeaders),
                onTap: onTapLeaders
            )
            .ui2Element("C-035 FilterChip 2")
            FilterChip(
                type: .menu,
                active: timeActive,
                label: state.timeOption,
                onTap: onTapTime
            )
            .ui2Element("C-035 FilterChip 3")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §2.4: "Some photos didn't load · Retry", Retry in `type-link`, `color-accent`.
    private var noticeRow: some View {
        HStack(spacing: 0) {
            Text("Some photos didn't load · ")
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.textSecondary)
            actionButton("Retry", action: onRetry)
        }
        .lineLimit(1)
    }

    // MARK: §2.2 / §2.3 Content

    @ViewBuilder private var content: some View {
        if showsGrid {
            MediaBrowser(
                items: items,
                image: image(for:),
                imageGeneration: imageGeneration,
                level: level,
                onLevelChange: { next in
                    level = next
                    onLevelChange(next)
                },
                hiddenItemID: state.hiddenItemID,
                frozen: state.frozen,
                scrollToNewestToken: scrollToNewestToken,
                timeZone: .current,
                refreshing: state.refreshing,
                onVisibleRangeChange: { range in
                    visibleRange = range
                    onVisibleRangeChange(range)
                },
                onTap: onTap,
                onScrollChange: onScrollChange,
                onRefresh: onRefresh
            )
            .ui2Element("C-129 MediaBrowser")
        } else {
            switch state.phase {
            case .empty:
                stateLines("No photos yet")
            case .noResults:
                stateLines("No photos match your search", action: ("Clear filters", {
                    query = ""
                    onClearFilters()
                }))
            default:
                stateLines("Couldn't load photos", action: ("Retry", onRetry))
            }
        }
    }

    /// §2.3: the message `type-body-sm` `color-text-secondary`, centred, `space-page-margin` side
    /// inset; any action `space-element-gap` below in `type-link` `color-accent`.
    private func stateLines(_ message: String, action: (String, () -> Void)? = nil) -> some View {
        VStack(spacing: Token.Space.elementGap) {
            Text(message)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .multilineTextAlignment(.center)
            if let action {
                actionButton(action.0, action: action.1)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// §2.3 / §2.4 text action (OQ-media-home-005: accent text, not a registry button). R-17.
    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {   // the module's C-049 `Button` shadows SwiftUI's
            Text(label)
                .designTextStyle(Token.TypeStyle.link)
                .foregroundStyle(Token.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - §3 sample states (one per preview)

extension MediaHomeScreen.State {
    /// §3 `loading` — the library's dates known, no image in the cache: placeholder tiles.
    static let loading = Self(
        phase: .loading, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles
    )
    /// §3 `loaded` — Design 4's look: no search, no chip set, the grid at `five`.
    static let loaded = Self(
        phase: .loaded, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles
    )
    /// §3 `empty` — "No photos yet".
    static let empty = Self(
        phase: .empty, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: [], photoDates: [], photoTitles: []
    )
    /// §3 `noResults` — a search that excludes every photo ("Noah", the ruling's own example).
    static let noResults = Self(
        phase: .noResults, searchText: "Noah", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: [], photoDates: [], photoTitles: []
    )
    /// §3 `failed` — some photos loaded: C-129 keeps them and §2.4's notice row shows.
    static let failed = Self(
        phase: .failed, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles
    )

    // The owner's 13 catalog portraits (media-browser.md §6) in a fixed shuffle, four a day over
    // Oct 11–22, 2026 (the reference's header range, §1 t 4.0): 48 photos, a short last row.
    static let samplePhotoURLs: [String] = [
        "http://localhost:5961/api/projects/makeready/images/hal-jordan",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/bruce-banner",
        "http://localhost:5961/api/projects/makeready/images/clark-kent",
        "http://localhost:5961/api/projects/makeready/images/luke-cage",
        "http://localhost:5961/api/projects/makeready/images/logan",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/bruce-wayne",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/matt-murdock",
        "http://localhost:5961/api/projects/makeready/images/bruce-banner",
        "http://localhost:5961/api/projects/makeready/images/hal-jordan",
        "http://localhost:5961/api/projects/makeready/images/tony-stark",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/bruce-wayne",
        "http://localhost:5961/api/projects/makeready/images/luke-cage",
        "http://localhost:5961/api/projects/makeready/images/matt-murdock",
        "http://localhost:5961/api/projects/makeready/images/bruce-banner",
        "http://localhost:5961/api/projects/makeready/images/clark-kent",
        "http://localhost:5961/api/projects/makeready/images/logan",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/steven-strange",
        "http://localhost:5961/api/projects/makeready/images/luke-cage",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/logan",
        "http://localhost:5961/api/projects/makeready/images/luke-cage",
        "http://localhost:5961/api/projects/makeready/images/tony-stark",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/matt-murdock",
        "http://localhost:5961/api/projects/makeready/images/steven-strange",
        "http://localhost:5961/api/projects/makeready/images/clark-kent",
        "http://localhost:5961/api/projects/makeready/images/bruce-wayne",
        "http://localhost:5961/api/projects/makeready/images/bruce-banner",
        "http://localhost:5961/api/projects/makeready/images/matt-murdock",
        "http://localhost:5961/api/projects/makeready/images/peter-parker",
        "http://localhost:5961/api/projects/makeready/images/logan",
        "http://localhost:5961/api/projects/makeready/images/clark-kent",
        "http://localhost:5961/api/projects/makeready/images/peter-parker",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/barry-allen",
        "http://localhost:5961/api/projects/makeready/images/bruce-banner",
        "http://localhost:5961/api/projects/makeready/images/luke-cage",
        "http://localhost:5961/api/projects/makeready/images/guy-gardner",
        "http://localhost:5961/api/projects/makeready/images/wade-wilson",
        "http://localhost:5961/api/projects/makeready/images/tony-stark",
    ]

    static let samplePhotoDates: [String] = [
        "2026-10-11", "2026-10-11", "2026-10-11", "2026-10-11",
        "2026-10-12", "2026-10-12", "2026-10-12", "2026-10-12",
        "2026-10-13", "2026-10-13", "2026-10-13", "2026-10-13",
        "2026-10-14", "2026-10-14", "2026-10-14", "2026-10-14",
        "2026-10-15", "2026-10-15", "2026-10-15", "2026-10-15",
        "2026-10-16", "2026-10-16", "2026-10-16", "2026-10-16",
        "2026-10-17", "2026-10-17", "2026-10-17", "2026-10-17",
        "2026-10-18", "2026-10-18", "2026-10-18", "2026-10-18",
        "2026-10-19", "2026-10-19", "2026-10-19", "2026-10-19",
        "2026-10-20", "2026-10-20", "2026-10-20", "2026-10-20",
        "2026-10-21", "2026-10-21", "2026-10-21", "2026-10-21",
        "2026-10-22", "2026-10-22", "2026-10-22", "2026-10-22",
    ]

    static let samplePhotoTitles: [String] = [
        "Hal Jordan", "Guy Gardner", "Bruce Banner", "Clark Kent",
        "Luke Cage", "Logan", "Wade Wilson", "Bruce Wayne",
        "Wade Wilson", "Guy Gardner", "Matt Murdock", "Bruce Banner",
        "Hal Jordan", "Tony Stark", "Wade Wilson", "Bruce Wayne",
        "Luke Cage", "Matt Murdock", "Bruce Banner", "Clark Kent",
        "Logan", "Wade Wilson", "Guy Gardner", "Steven Strange",
        "Luke Cage", "Wade Wilson", "Logan", "Luke Cage",
        "Tony Stark", "Guy Gardner", "Matt Murdock", "Steven Strange",
        "Clark Kent", "Bruce Wayne", "Bruce Banner", "Matt Murdock",
        "Peter Parker", "Logan", "Clark Kent", "Peter Parker",
        "Guy Gardner", "Wade Wilson", "Barry Allen", "Bruce Banner",
        "Luke Cage", "Guy Gardner", "Wade Wilson", "Tony Stark",
    ]
}

// MARK: - Previews (one per §3 state, in §3 order)

#Preview("loading") {
    MediaHomeScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loaded") {
    MediaHomeScreen(state: .loaded)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    MediaHomeScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("noResults") {
    MediaHomeScreen(state: .noResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("failed") {
    MediaHomeScreen(state: .failed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
