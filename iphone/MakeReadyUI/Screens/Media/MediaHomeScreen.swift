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
/// top bar (C-034 search, four C-035 Menu chips) over C-129 MediaBrowser, the screen's only
/// scroller (media-page D16), with the date-range label floating over the grid's top-leading corner. No TopNav, no TabBar: the shell's
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
        /// Each photo's stable id, parallel to `photoURLs` — C-129's `Item.id` and the id `onTap`
        /// reports. Empty → the ids are "photo-<index>" (previews, capture).
        var photoIDs: [String] = []
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
        /// §3 Source chip label (media-library D7): nil = the resting "Source"; else the host's
        /// own "«first» +«n−1»" string. The screen never computes the Source options.
        var sourceLabel: String? = nil
        /// §3 Source chip `active`: ≥1 source selected.
        var sourceActive: Bool = false
        /// §3 date-range label capture input: nil = automatic (shown while scrolling, hidden
        /// ~2 s after), true = forced shown, false = forced hidden.
        var dateLabelVisible: Bool? = nil
        /// §3 Active search: the field's focus on first render (capture state `searchActiveEmpty`);
        /// the screen's own focus `@State` takes over from there.
        var searchFocused: Bool = false
    }

    let state: State
    // §3 "Actions out of the screen (D14, no-op defaults)" — R-03 / R-33.
    var onSearch: (String) -> Void = { _ in }
    var onSearchActiveChange: (Bool) -> Void = { _ in }
    var onSource: () -> Void = {}                        // §3 Source chip tap → host presents C-036 .multiple
    var onTapTags: () -> Void = {}                       // §3 R2: chip tap → host presents C-036
    var onTapLeaders: () -> Void = {}
    var onTapTime: () -> Void = {}
    var onClearFilters: () -> Void = {}                  // §3 noResults "Clear filters"
    var onRetry: () -> Void = {}                         // §3 failed "Retry"
    /// §3 Level reporting: each change of the resting level (five ⇄ three), first render included.
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

    // R-31 ephemeral UI: the query as typed, the range C-129 last reported, the scroll-to-newest
    // bump, and the date label's scroll-driven visibility (§3 "screen-level ephemeral `@State`
    // … The fade-out wait is a cancellable `Task.sleep`").
    @SwiftUI.State private var query: String
    @SwiftUI.State private var visibleRange: Range<Int>?
    @SwiftUI.State private var scrollToNewestToken = 0
    @SwiftUI.State private var dateLabelShown = false
    /// §3 Rendering cost: the last offset, the fade-out task and the derived items, held outside
    /// observation so a scroll frame re-renders only when `dateLabelShown` flips.
    @SwiftUI.State private var cache = MediaHomeCache()
    /// Owner 2026-11-01 (groups-home's rule): search is active while the field is focused or holds
    /// a query — as C-131 SearchFilterHeader reports it (it owns the field's focus, and the shell
    /// is told through `onSearchActiveChange`). Seeded from `State.searchFocused`.
    @SwiftUI.State private var searchActive: Bool

    /// §3 "Empty means trimmed": a whitespace-only query is empty for the blank state and the level.
    private var trimmedQueryEmpty: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// §3 Search-blank state: search active with an empty trimmed query → no C-129, blank ground.
    private var searchBlank: Bool { searchActive && trimmedQueryEmpty }

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in },
        onSource: @escaping () -> Void = {},
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
        self.onSource = onSource
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
        _searchActive = SwiftUI.State(initialValue: state.searchFocused || !state.searchText.isEmpty)
    }

    // MARK: - §2 / §3 constants

    /// §2: C-034 placeholder "Search".
    private static let searchPlaceholder = "Search"
    /// §3 Time chip options, in order; the first is "no filter".
    static let timeOptions = ["All time", "Last 7 days", "Last 30 days", "Last 90 days"]
    /// §3 Level follows the query (owner 2026-11-01): `five` with no trimmed query, `three` with one.
    private var level: MediaBrowser.Level { trimmedQueryEmpty ? .five : .three }
    /// §3 Visibility: "fades out about 2 seconds after scrolling stops".
    private static let dateLabelHold: Duration = .seconds(2)

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

    /// C-129 `items`, oldest → newest, and the `photoIDs` → index lookup — §3 Rendering cost:
    /// derived once per change of `photoDates`, `photoIDs` or `photoTitles`, then reused.
    private var derived: MediaHomeCache.Derived {
        cache.derived(dates: state.photoDates, ids: state.photoIDs, titles: state.photoTitles) {
            Self.derive(dates: state.photoDates, ids: state.photoIDs, titles: state.photoTitles)
        }
    }

    private static func derive(dates: [String], ids: [String], titles: [String]) -> MediaHomeCache.Derived {
        let items = dates.indices.map { index in
            let date = parse(dates[index]) ?? .distantPast
            let title = titles.indices.contains(index) ? titles[index] : ""
            return MediaBrowser.Item(
                id: ids.indices.contains(index) ? ids[index] : "photo-\(index)",   // "photo-<index>" without ids
                date: date,
                accessibilityLabel: "\(title), \(dayFormatter.string(from: date))"
            )
        }
        let indexByID = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return MediaHomeCache.Derived(items: items, indexByID: indexByID)
    }

    /// The `photoURLs` index an item id names: its place in `photoIDs`, or the "photo-<index>" suffix.
    private static func photoIndex(of id: String, in indexByID: [String: Int]) -> Int? {
        if let index = indexByID[id] { return index }
        guard id.hasPrefix("photo-") else { return nil }
        return Int(id.dropFirst("photo-".count))
    }

    /// §5: C-129 never loads an image; the screen reads the host's cache (Ui2ImageCache in the
    /// preview module), keyed by the photo's `photoURLs` entry. §3 `loading`: "C-129 … with its
    /// dark placeholder tiles" → nil for all.
    private func image(for id: String, indexByID: [String: Int]) -> UIImage? {
        guard state.phase != .loading,
              let index = Self.photoIndex(of: id, in: indexByID),
              state.photoURLs.indices.contains(index),
              !state.photoURLs[index].isEmpty else { return nil }
        if let image { return image(state.photoURLs[index]) }
        guard let url = URL(string: state.photoURLs[index]) else { return nil }
        return Ui2ImageCache.shared.image(for: url)
    }

    /// §2.4: the date label is not drawn with no photos on screen (loading, empty, noResults,
    /// failed with no photos), nor in the search-blank state (§3).
    private var drawsDateLabel: Bool {
        guard !state.photoDates.isEmpty else { return false }
        return state.phase == .loaded || state.phase == .failed
    }

    /// §3 Visibility: the capture input wins; nil → the scroll-driven state.
    private var dateLabelVisible: Bool { state.dateLabelVisible ?? dateLabelShown }

    /// §2.5: failed with photos loaded → the notice row below the chips.
    private var showsNotice: Bool { state.phase == .failed && !state.photoDates.isEmpty }

    /// §2.2: C-129 stays for loading, loaded and failed-with-photos; §2.3's lines replace it
    /// otherwise.
    private var showsGrid: Bool {
        guard !searchBlank else { return false }
        switch state.phase {
        case .loading, .loaded: return true
        case .failed: return !state.photoDates.isEmpty
        case .empty, .noResults: return false
        }
    }

    /// §3 Date-range label: the dates of the items C-129 reports (all items until it reports).
    private var dateRange: String {
        let all = derived.items
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
        // Fills exactly the height its host offers — no floor of its own: on device a floor taller
        // than the space under the TopNav overflowed it and the shell pushed the row off screen.
        // The capture harness, which proposes no height, gives it the 897pt canvas instead.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)              // §2: page ground
        .onChange(of: filterKey) { scrollToNewestToken += 1 }
        // §3 Level reporting: the host sizes its tile images for the resting level.
        .onChange(of: level, initial: true) { _, next in onLevelChange(next) }
        .onDisappear { cache.hideTask?.cancel() }
    }

    /// §3 Visibility: any change of C-129's reported offset shows the label; it fades out
    /// `dateLabelHold` after the last change, and a new scroll restarts the wait. The first
    /// report only records where the grid rests, so the label stays hidden at rest.
    private func scrollChanged(_ offset: CGFloat) {
        defer { cache.lastScrollOffset = offset }
        guard let last = cache.lastScrollOffset, last != offset else { return }
        if !dateLabelShown {
            withAnimation(Token.Motion.menuFadeIn) { dateLabelShown = true }
        }
        cache.hideTask?.cancel()
        cache.hideTask = Task { @MainActor in
            try? await Task.sleep(for: Self.dateLabelHold)
            guard !Task.isCancelled else { return }
            withAnimation(Token.Motion.menuFadeOut) { dateLabelShown = false }
        }
    }

    // MARK: §2.1 Top bar

    /// §2.1: fixed, full width; the search field and the chip row, now the shared C-131
    /// SearchFilterHeader (field, full-bleed rail, insets, material — OQ-media-home-9), plus
    /// §2.5's notice when failed with photos, just below the header (OQ-media-home-9).
    /// `.underShellTopNav`: no top padding — the shell's nav gap (16) is already the space under
    /// the TopNav (owner 2026-11-01).
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchFilterHeader(
                query: query,
                // §3 Search: "updates on every keystroke (`onSearch(String)`) with no server call";
                // C-034's clear empties it and ends the search.
                onQueryChange: { newValue in
                    query = newValue
                    onSearch(newValue)
                },
                placeholder: Self.searchPlaceholder,
                placement: .underShellTopNav,
                onSearchActiveChange: { active in
                    searchActive = active
                    onSearchActiveChange(active)
                },
                // §3 Active search: capture state `searchActiveEmpty` starts focused.
                initiallyFocused: state.searchFocused
            ) {
                chipRow
            }

            if showsNotice {
                noticeRow
                    .padding(.horizontal, Token.Space.pageMargin)
                    .padding(.bottom, Token.Space.pageMargin)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §2.1 Chip row: four C-035 `type: Menu` — Source · Tags · Leaders · Time —
    /// `space-element-gap` apart — C-131's slot, laid in its full-bleed FilterRail, which always
    /// swipes (owner 2026-11-01, filter-rail.md) — supersedes §2.1's "no horizontal scroll".
    @ViewBuilder private var chipRow: some View {
        FilterChip(
            type: .menu,
            active: state.sourceActive,
            label: state.sourceLabel ?? "Source",
            onTap: onSource
        )
        .ui2Element("C-035 FilterChip")
        FilterChip(
            type: .menu,
            active: !state.selectedTags.isEmpty,
            label: Self.chipLabel("Tags", state.selectedTags),
            onTap: onTapTags
        )
        .ui2Element("C-035 FilterChip 2")
        FilterChip(
            type: .menu,
            active: !state.selectedLeaders.isEmpty,
            label: Self.chipLabel("Leaders", state.selectedLeaders),
            onTap: onTapLeaders
        )
        .ui2Element("C-035 FilterChip 3")
        FilterChip(
            type: .menu,
            active: timeActive,
            label: state.timeOption,
            onTap: onTapTime
        )
        .ui2Element("C-035 FilterChip 4")
    }

    /// §2.5: "Some photos didn't load · Retry", Retry in `type-link`, `color-accent`.
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
        if searchBlank {
            // §3 Search-blank state: blank page ground under the top bar — no grid, no lines.
            Color.clear
        } else if showsGrid {
            let derived = derived
            MediaBrowser(
                items: derived.items,
                image: { image(for: $0, indexByID: derived.indexByID) },
                imageGeneration: imageGeneration,
                level: level,
                // §3 "Pinch is off" (owner 2026-11-01): the level comes from the query alone.
                pinchEnabled: false,
                hiddenItemID: state.hiddenItemID,
                frozen: state.frozen,
                scrollToNewestToken: scrollToNewestToken,
                timeZone: .current,
                refreshing: state.refreshing,
                onVisibleRangeChange: onVisibleRangeChange,
                // §3 Date-range label: the items ON SCREEN, not the prefetch range, which
                // carries a one-viewport margin each way.
                onVisibleItemsChange: { range in visibleRange = range },
                onTap: onTap,
                // §3 Scroll: forwarded to the shell, and drives the date label.
                onScrollChange: { offset, fingerDown in
                    scrollChanged(offset)
                    onScrollChange(offset, fingerDown)
                },
                onRefresh: onRefresh
            )
            .ui2Element("C-129 MediaBrowser")
            .overlay(alignment: .topLeading) {
                if drawsDateLabel { dateLabel }
            }
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

    /// §2.2 Date-range label (OQ-media-home-004): top-leading over the grid, `space-page-margin`
    /// in from its left and top edges, `type-caption` on a translucent dark capsule like C-129's
    /// month pills. It takes no layout space and passes touches through to the grid.
    private var dateLabel: some View {
        Text(dateRange)
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, Token.Space.metaGap)
            .padding(.horizontal, Token.Space.elementGap)
            // C-129's pill fill is "black at 50% opacity" (OQ-C-129-004); `color-black-50`.
            .background(Capsule().fill(Token.black50))
            .padding(Token.Space.pageMargin)
            .opacity(dateLabelVisible ? 1 : 0)
            .accessibilityHidden(!dateLabelVisible)
            .allowsHitTesting(false)
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

    /// §2.3 / §2.5 text action (OQ-media-home-005: accent text, not a registry button). R-17.
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
    /// §3 `failed` — some photos loaded: C-129 keeps them and §2.5's notice row shows.
    static let failed = Self(
        phase: .failed, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles
    )
    /// Capture state `source-active` — the Source chip active as "MakeReady +1"; the rest as `loaded`.
    static let sourceActive = Self(
        phase: .loaded, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles, sourceLabel: "MakeReady +1", sourceActive: true
    )
    /// Capture state `date-visible` — `loaded` with the date label forced shown.
    static let dateVisible = Self(
        phase: .loaded, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles, dateLabelVisible: true
    )

    /// Capture state `searchActiveEmpty` — search focused, empty query: blank ground below the top bar.
    static let searchActiveEmpty = Self(
        phase: .loaded, searchText: "", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: samplePhotoURLs, photoDates: samplePhotoDates,
        photoTitles: samplePhotoTitles, searchFocused: true
    )
    /// Capture state `searchResults` — query "Noah", a few matching photos, C-129 at `three`.
    static let searchResults = Self(
        phase: .loaded, searchText: "Noah", selectedTags: [], selectedLeaders: [],
        timeOption: "All time", photoURLs: Array(samplePhotoURLs.prefix(7)),
        photoDates: Array(samplePhotoDates.prefix(7)), photoTitles: Array(samplePhotoTitles.prefix(7))
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

#Preview("source-active") {
    MediaHomeScreen(state: .sourceActive)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("date-visible") {
    MediaHomeScreen(state: .dateVisible)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("searchActiveEmpty") {
    MediaHomeScreen(state: .searchActiveEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("searchResults") {
    MediaHomeScreen(state: .searchResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

// MARK: - §3 Rendering cost

/// Scroll bookkeeping and derived items, deliberately NOT observable (like C-129's
/// `MediaBrowserTracker`): a write from a scroll frame must not re-render the screen.
final class MediaHomeCache {
    struct Derived {
        let items: [MediaBrowser.Item]
        let indexByID: [String: Int]
    }

    var lastScrollOffset: CGFloat?
    var hideTask: Task<Void, Never>?

    private var key: (dates: [String], ids: [String], titles: [String])?
    private var value: Derived?

    /// The cached result while the inputs are unchanged; `make()` runs once per change.
    func derived(dates: [String], ids: [String], titles: [String], make: () -> Derived) -> Derived {
        if let key, let value, key.dates == dates, key.ids == ids, key.titles == titles { return value }
        let made = make()
        key = (dates, ids, titles)
        value = made
        return made
    }
}
