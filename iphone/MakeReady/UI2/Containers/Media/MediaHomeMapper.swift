import Foundation

/// media-page §iphone State: AppState.mediaLibrary → what MediaHomeScreen shows. Pure (today and the
/// time zone are inputs), so the order, search and chips are tested without a view.
enum MediaHomeMapper {
    /// D7 Time chip (single-select).
    enum TimeWindow: String, CaseIterable, Equatable {
        case all, last7, last30, last90
        var label: String {
            switch self {
            case .all: return "All time"
            case .last7: return "Last 7 days"
            case .last30: return "Last 30 days"
            case .last90: return "Last 90 days"
            }
        }
        var days: Int? {
            switch self {
            case .all: return nil
            case .last7: return 7
            case .last30: return 30
            case .last90: return 90
            }
        }
    }

    /// The search text and chip picks — the container's `@State`.
    struct Selection: Equatable {
        var search = ""
        var tags: Set<String> = []
        var leaderIds: Set<String> = []
        var time: TimeWindow = .all
        /// media-library D7: the chosen sources (org ids, MakeReady's included); empty = every source.
        var sourceIds: Set<String> = []
        var hasFilters: Bool {
            !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !tags.isEmpty || !leaderIds.isEmpty
                || time != .all || !sourceIds.isEmpty
        }
    }

    struct Option: Equatable {
        let id: String
        let label: String
    }

    /// One grid tile (D10): `mediumURL` at 5 columns, `thumbURL` denser and as every fallback.
    struct Tile: Equatable, Identifiable {
        let id: String
        let mediumURL: URL?
        let thumbURL: URL?
        let fullURL: String
        let date: Date
        let title: String
    }

    struct Output: Equatable {
        /// Oldest → newest (D5).
        let tiles: [Tile]
        let tagOptions: [String]
        let leaderOptions: [Option]
        /// The shown tiles' first and last date; nil when none.
        let dateRange: ClosedRange<Date>?
        let isEmptyLibrary: Bool
        let isNoResults: Bool
    }

    static func output(items: [MediaLibraryItem], selection: Selection, today: Date, timeZone: TimeZone) -> Output {
        let photos = items.filter { $0.type == "photo" }.sorted(by: gridOrder)
        let tagOptions = Set(photos.flatMap { $0.tags.map { $0.lowercased() } }).sorted()
        var leaders: [String: String] = [:]
        for item in photos { if let u = item.uploader { leaders[u.id] = u.name } }
        let leaderOptions = leaders.map { Option(id: $0.key, label: $0.value) }.sorted {
            let order = $0.label.localizedCaseInsensitiveCompare($1.label)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        let cutoff = cutoff(selection.time, today: today, timeZone: timeZone)
        let query = selection.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedTags = Set(selection.tags.map { $0.lowercased() })
        let shown = photos.filter { item in
            if !query.isEmpty, !matches(item, query: query) { return false }
            if !wantedTags.isEmpty, wantedTags.isDisjoint(with: item.tags.map { $0.lowercased() }) { return false }
            if !selection.leaderIds.isEmpty {
                guard let id = item.uploader?.id, selection.leaderIds.contains(id) else { return false }
            }
            if let cutoff, item.sortDate < cutoff { return false }
            if !selection.sourceIds.isEmpty {
                guard let org = item.organizationId, selection.sourceIds.contains(org) else { return false }
            }
            return true
        }
        // media-library D22: MakeReady covers lead the grid, so their tile date is clamped to the oldest
        // org item's — the grid's dates (month/year pills, the range) stay oldest → newest.
        let oldestOrgDate = shown.first { $0.isMakeReady != true }?.sortDate
        let tiles = shown.map { item -> Tile in
            let urls = tileURLs(url: item.url, thumbnailUrl: item.thumbnailUrl)
            let date = item.isMakeReady == true ? min(item.sortDate, oldestOrgDate ?? item.sortDate) : item.sortDate
            return Tile(id: item.id, mediumURL: urls.medium, thumbURL: urls.thumb, fullURL: item.url,
                        date: date, title: item.displayTitle)
        }
        let range = tiles.first.flatMap { first in tiles.last.map { first.date...$0.date } }
        return Output(tiles: tiles, tagOptions: tagOptions, leaderOptions: leaderOptions, dateRange: range,
                      isEmptyLibrary: photos.isEmpty, isNoResults: !photos.isEmpty && tiles.isEmpty)
    }

    /// media-library D22: MakeReady's covers sit at the oldest end (before every org item), A–Z by title,
    /// so a fresh import never fills the newest end the grid opens on; org items keep D5's order.
    static func gridOrder(_ a: MediaLibraryItem, _ b: MediaLibraryItem) -> Bool {
        let aMR = a.isMakeReady == true, bMR = b.isMakeReady == true
        if aMR != bMR { return aMR }
        if aMR {
            let order = a.title.localizedCaseInsensitiveCompare(b.title)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
        return a.sortDate == b.sortDate ? a.id < b.id : a.sortDate < b.sortDate
    }

    /// media-library D7: the Source chip's options, in `/api/media/sources` order (MakeReady, then orgs).
    static func sourceOptions(_ sources: [MediaSource]) -> [Option] {
        sources.map { Option(id: $0.id, label: $0.name) }
    }

    /// D10: `.jpeg` → `-md.jpeg` for the 5-column tile; `thumbnailUrl ?? url` otherwise and as the fallback.
    static func tileURLs(url: String, thumbnailUrl: String?) -> (medium: URL?, thumb: URL?) {
        let medium = url.hasSuffix(".jpeg") ? URL(string: String(url.dropLast(5)) + "-md.jpeg") : nil
        let thumbSource = (thumbnailUrl?.isEmpty == false ? thumbnailUrl : nil) ?? url
        return (medium, URL(string: thumbSource))
    }

    /// D7: start of today in `timeZone` minus (N − 1) days; nil for All time.
    static func cutoff(_ window: TimeWindow, today: Date, timeZone: TimeZone) -> Date? {
        guard let days = window.days else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: today))
    }

    /// D6: title, description, each tag and the uploader's name, case-insensitive substring.
    private static func matches(_ item: MediaLibraryItem, query: String) -> Bool {
        let fields = [item.title, item.description ?? "", item.uploader?.name ?? ""] + item.tags
        return fields.contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
