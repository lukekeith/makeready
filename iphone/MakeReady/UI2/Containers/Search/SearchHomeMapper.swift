import Foundation

/// Where a tapped row goes (master-search D9, D27): a page pushed on the Search tab's stack, or the
/// ImageViewer over the screen.
enum SearchHomeExit: Equatable {
    case push(UI2Destination)
    case viewer(url: String, title: String)
}

/// master-search §iphone: the AppState search domain → what `SearchHomeScreen` shows. Pure (the time
/// zone is an input), so the kind map, labels, tag sections and routing are tested without a view.
enum SearchHomeMapper {
    /// The five chips' picks (ids), the container's `@State`.
    struct Selection: Equatable {
        var typeIds: Set<String> = []
        var orgIds: Set<String> = []
        var groupIds: Set<String> = []
        var leaderIds: Set<String> = []
        var tagIds: Set<String> = []
    }

    struct Output {
        let state: SearchHomeScreen.State
        /// The rows `state`'s recent arrays describe, index for index (unknown types dropped).
        let recentItems: [SearchItem]
        /// The rows `state`'s result arrays describe, index for index (unknown types dropped).
        let resultItems: [SearchItem]
    }

    // MARK: - Type chip (D5)

    /// D5: the closed list of the Type chip, in the design's order. Programs stands for two types.
    static let typeOptions: [(id: String, label: String, types: [String])] = [
        ("programs", "Programs", ["PROGRAM", "TEMPLATE"]),
        ("members", "Members", ["MEMBER"]),
        ("groups", "Groups", ["GROUP"]),
        ("lessons", "Lessons", ["LESSON"]),
        ("events", "Events", ["EVENT"]),
        ("posts", "Posts", ["POST"]),
        ("videos", "Videos", ["VIDEO"]),
        ("photos", "Photos", ["PHOTO"])
    ]

    /// The picks as C1/C2's lists, in a stable order.
    static func filters(_ selection: Selection) -> SearchFilters {
        SearchFilters(
            types: typeOptions.filter { selection.typeIds.contains($0.id) }.flatMap(\.types),
            orgIds: selection.orgIds.sorted(),
            groupIds: selection.groupIds.sorted(),
            leaderIds: selection.leaderIds.sorted(),
            tags: selection.tagIds.sorted())
    }

    // MARK: - Tags (D14, D31)

    /// One section per `category` in first-seen order (C5 sends them in display order), then one
    /// untitled section for the tags with none. An option's id is the tag C1 and C2 take.
    static func tagSections(options: SearchFilterOptions?) -> [MediaHomeMapper.TagSection] {
        guard let tags = options?.tags else { return [] }
        var order: [String] = []
        var byCategory: [String: [MediaHomeMapper.Option]] = [:]
        var uncategorized: [MediaHomeMapper.Option] = []
        for tag in tags {
            let option = MediaHomeMapper.Option(id: tag.tag, label: tag.label)
            if let category = tag.category {
                if byCategory[category] == nil { order.append(category) }
                byCategory[category, default: []].append(option)
            } else {
                uncategorized.append(option)
            }
        }
        let titled = order.map { MediaHomeMapper.TagSection(title: $0, options: byCategory[$0] ?? []) }
        return titled + (uncategorized.isEmpty ? [] : [MediaHomeMapper.TagSection(title: nil, options: uncategorized)])
    }

    // MARK: - Output

    static func output(recents: [SearchItem], results: [SearchItem], query: String, answeredQuery: String?,
                       selection: Selection, options: SearchFilterOptions?, tz: TimeZone,
                       resultsGeneration: Int = 0) -> Output {
        let recentItems = recents.filter { kind(of: $0.type) != nil }
        let resultItems = results.filter { kind(of: $0.type) != nil }
        let typeLabels = typeOptions.filter { selection.typeIds.contains($0.id) }.map(\.label)
        let orgLabels = (options?.organizations ?? []).filter { selection.orgIds.contains($0.id) }.map(\.name)
        let groupLabels = (options?.groups ?? []).filter { selection.groupIds.contains($0.id) }.map(\.name)
        let leaderLabels = (options?.leaders ?? []).filter { selection.leaderIds.contains($0.id) }.map(\.name)
        let tagLabels = MediaHomeMapper.tagLabels(for: selection.tagIds, in: tagSections(options: options))
        let chips: [(SearchHomeScreen.Filter, [String])] = [
            (.type, typeLabels), (.orgs, orgLabels), (.groups, groupLabels), (.leaders, leaderLabels), (.tags, tagLabels)
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let answered = answeredQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        // D41 (refined): an answer with no rows stays on screen as its no-results line until the
        // current query is answered; a query that is itself answered needs no held line.
        let heldNoResultsQuery: String? = {
            guard let answered, resultItems.isEmpty, answered != trimmed, answered.count >= 2 else { return nil }
            return answered
        }()
        let state = SearchHomeScreen.State(
            searchText: query,
            typeFilterLabel: FilterMenuOverlay.chipLabel(picked: typeLabels, resting: "Type", noun: "types"),
            orgFilterLabel: FilterMenuOverlay.chipLabel(picked: orgLabels, resting: "Orgs", noun: "orgs"),
            groupFilterLabel: FilterMenuOverlay.chipLabel(picked: groupLabels, resting: "Groups", noun: "groups"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: leaderLabels, resting: "Leaders", noun: "leaders"),
            tagFilterLabel: FilterMenuOverlay.chipLabel(picked: tagLabels, resting: "Tags", noun: "tags"),
            activeFilters: chips.filter { !$0.1.isEmpty }.map { $0.0.rawValue },
            recentKinds: recentItems.compactMap { kind(of: $0.type) },
            recentTitles: recentItems.map(\.title),
            recentDescriptions: recentItems.map { HomeDashboardMapper.createdLabel($0.createdAt, tz: tz) },
            recentImageURLs: recentItems.map(previewURL(of:)),
            resultKinds: resultItems.compactMap { kind(of: $0.type) },
            resultTitles: resultItems.map(\.title),
            resultDescriptions: resultItems.map { HomeDashboardMapper.createdLabel($0.createdAt, tz: tz) },
            resultImageURLs: resultItems.map(previewURL(of:)),
            // D41: an answer belongs to one query; another query's answer is not this one's.
            queryAnswered: answered.map { $0 == trimmed } ?? false,
            heldNoResultsQuery: heldNoResultsQuery,
            resultsGeneration: resultsGeneration)
        return Output(state: state, recentItems: recentItems, resultItems: resultItems)
    }

    /// D44: a row's image, the server's `thumbnailUrl`, then a photo's full image; nil for none.
    static func previewURL(of item: SearchItem) -> URL? {
        let urls = [item.thumbnailUrl, item.imageUrl].compactMap { $0 }.filter { !$0.isEmpty }
        return urls.first.flatMap(URL.init(string:))
    }

    /// D21: the C-085 `kind` raw value; nil for a type this build does not know (the row is dropped).
    static func kind(of type: String) -> String? {
        switch type {
        case "PROGRAM", "TEMPLATE": return "program"
        case "MEMBER": return "member"
        case "GROUP": return "group"
        case "LESSON": return "lesson"
        case "EVENT": return "event"
        case "POST": return "post"
        case "VIDEO": return "media"
        case "PHOTO": return "photo"
        default: return nil
        }
    }

    // MARK: - Routing (D9, D27)

    static func exit(for item: SearchItem) -> SearchHomeExit {
        switch item.type {
        case "PROGRAM": return .push(.studyProgramHome(id: item.id, name: item.title))
        case "TEMPLATE": return .push(.programsHome)
        case "MEMBER": return .push(.memberDetail(id: item.id, name: item.title))
        case "GROUP": return .push(.groupDetail(id: item.id, name: item.title))
        case "LESSON":
            guard let parent = item.parent else { return .push(.programsHome) }   // contract: always set
            return .push(.studyProgramHome(id: parent.id, name: parent.name))
        case "EVENT", "POST":
            guard let parent = item.parent else { return .push(.programsHome) }   // contract: always set
            return .push(.groupDetail(id: parent.id, name: parent.name))
        case "PHOTO":
            // C1/C2 always send a photo's url; without one the Media page is the nearest page.
            guard let url = item.imageUrl, !url.isEmpty else { return .push(.mediaHome) }
            return .viewer(url: url, title: item.title)
        default: return .push(.mediaHome)   // VIDEO (D9)
        }
    }
}
