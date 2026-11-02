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

    /// tag-categories D7: one group of the Tags filter's options; `title` nil draws no header.
    struct TagSection: Equatable {
        let title: String?
        let options: [Option]
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
        /// tag-categories D7/D8: the photos' tags, grouped by category (book order), then CONTENT A→Z.
        let tagSections: [TagSection]
        let leaderOptions: [Option]
        /// The shown tiles' first and last date; nil when none.
        let dateRange: ClosedRange<Date>?
        let isEmptyLibrary: Bool
        let isNoResults: Bool
    }

    static func output(items: [MediaLibraryItem], selection: Selection, today: Date, timeZone: TimeZone,
                       categories: [TagCategory] = []) -> Output {
        let photos = items.filter { $0.type == "photo" }.sorted(by: gridOrder)
        let tagSections = tagSections(tags: Set(photos.flatMap { $0.tags.map { $0.lowercased() } }), categories: categories)
        var leaders: [String: String] = [:]
        for item in photos { if let u = item.uploader { leaders[u.id] = u.name } }
        let leaderOptions = leaders.map { Option(id: $0.key, label: $0.value) }.sorted {
            let order = $0.label.localizedCaseInsensitiveCompare($1.label)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        let cutoff = cutoff(selection.time, today: today, timeZone: timeZone)
        let query = selection.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedTags = wantedSpellings(selection.tags, categories: categories)
        let shown = photos.filter { item in
            if !query.isEmpty, !matches(item, query: query) { return false }
            if !wantedTags.isEmpty, wantedTags.isDisjoint(with: item.tags.map(normalizeTag)) { return false }
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
        return Output(tiles: tiles, tagSections: tagSections, leaderOptions: leaderOptions, dateRange: range,
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

    // MARK: - Tag categories (tag-categories D7, D8, D10, D12, D13, D16)

    /// D10: the server's rule — lowercase, all whitespace removed ("1 Samuel" → "1samuel").
    static func normalizeTag(_ tag: String) -> String {
        tag.lowercased().filter { !$0.isWhitespace }
    }

    /// D13: an uncategorized tag reads as its lowercased text with each space-separated word capitalised.
    static func titleCase(_ tag: String) -> String {
        tag.lowercased().split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// D7/D8/D12: each category with a member among `tags` (category order, one option per member at its
    /// position, labelled by the member), then CONTENT A→Z. Nothing categorized → one untitled section.
    static func tagSections(tags: Set<String>, categories: [TagCategory]) -> [TagSection] {
        var memberBySpelling: [String: (category: TagCategory, member: TagCategoryMember)] = [:]
        for category in categories {
            for member in category.tags { memberBySpelling[member.tag] = (category, member) }
        }
        var present: [String: [Int: TagCategoryMember]] = [:]   // category key → position → member
        var plain: [Option] = []
        for tag in tags {
            if let hit = memberBySpelling[normalizeTag(tag)] {
                present[hit.category.key, default: [:]][hit.member.position] = hit.member
            } else {
                plain.append(Option(id: tag, label: titleCase(tag)))
            }
        }
        let content = plain.sorted {
            let order = $0.label.localizedCaseInsensitiveCompare($1.label)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        let titled = categories.sorted { $0.position < $1.position }.compactMap { category -> TagSection? in
            guard let members = present[category.key], !members.isEmpty else { return nil }
            let options = members.keys.sorted().compactMap { position in
                members[position].map { Option(id: "cat:\(category.key):\(position)", label: $0.label) }
            }
            return TagSection(title: category.name.uppercased(), options: options)
        }
        if titled.isEmpty { return content.isEmpty ? [] : [TagSection(title: nil, options: content)] }
        return titled + (content.isEmpty ? [] : [TagSection(title: "CONTENT", options: content)])
    }

    /// D12/D16: the normalized spellings the selected ids stand for. A `cat:<key>:<position>` id that resolves
    /// to a loaded member stands for all of that member's spellings; any other id is its own tag text.
    static func wantedSpellings(_ ids: Set<String>, categories: [TagCategory]) -> Set<String> {
        var spellings = Set<String>()
        for id in ids {
            let parts = id.split(separator: ":", maxSplits: 2).map(String.init)
            if parts.count == 3, parts[0] == "cat", let position = Int(parts[2]),
               let category = categories.first(where: { $0.key == parts[1] }) {
                let members = category.tags.filter { $0.position == position }.map(\.tag)
                if !members.isEmpty {
                    spellings.formUnion(members)
                    continue
                }
            }
            spellings.insert(normalizeTag(id))
        }
        return spellings
    }

    /// D13/D16: the picked options' labels in option order (the Tags chip's "first +n"); ids with no option skipped.
    static func tagLabels(for ids: Set<String>, in sections: [TagSection]) -> [String] {
        sections.flatMap(\.options).filter { ids.contains($0.id) }.map(\.label)
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
