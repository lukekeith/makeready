import XCTest
@testable import MakeReady

/// media-page D5–D8, D10: oldest→newest by takenAt ?? createdAt; search; Tags / Leaders / Time with AND.
final class MediaHomeMapperTests: XCTestCase {
    typealias M = MediaHomeMapper
    private let chicago = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-31T17:00:00Z")!   // 12:00 in Chicago

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func item(_ id: String, created: String = "2026-10-01T12:00:00Z", taken: String? = nil, title: String = "",
                      description: String? = nil, tags: [String] = [], uploader: (String, String)? = ("u1", "Ann"),
                      url: String? = nil, thumb: String? = nil, type: String = "photo") -> MediaLibraryItem {
        MediaLibraryItem(id: id, title: title, description: description, url: url ?? "https://img/\(id).jpeg", type: type,
                         mimeType: nil, fileSize: nil, thumbnailUrl: thumb ?? "https://img/\(id)-thumb.jpeg",
                         uploadStatus: "ready", duration: nil, tags: tags, usageCount: 0,
                         uploader: uploader.map { MediaUploader(id: $0.0, name: $0.1) }, video: nil,
                         createdAt: date(created), updatedAt: date(created), takenAt: taken.map(date))
    }

    private func ids(_ items: [MediaLibraryItem], _ s: M.Selection = .init()) -> [String] {
        M.output(items: items, selection: s, today: today, timeZone: chicago).tiles.map(\.id)
    }

    func testOrdersOldestToNewestByTakenAtElseCreatedAtTiesById() {
        let items = [item("c", created: "2026-10-03T00:00:00Z"),
                     item("a", created: "2026-10-30T00:00:00Z", taken: "2025-06-14T14:30:00Z"),
                     item("b", created: "2026-10-03T00:00:00Z"),
                     item("v", type: "video")]
        XCTAssertEqual(ids(items), ["a", "b", "c"])
    }

    private func sourced(_ id: String, org: String, makeReady: Bool = false, title: String = "",
                         created: String = "2026-10-01T12:00:00Z") -> MediaLibraryItem {
        var i = item(id, created: created, title: title)
        i.organizationId = org
        i.isMakeReady = makeReady ? true : nil
        return i
    }

    /// media-library D22: MakeReady covers first (the oldest end), A–Z by title; org items by date after them.
    func testMakeReadyCoversSitAtTheOldestEndByTitle() {
        let items = [sourced("o-new", org: "o1", created: "2026-10-30T00:00:00Z"),
                     sourced("mr-b", org: "mr", makeReady: true, title: "Book of Ruth", created: "2026-11-01T00:00:00Z"),
                     sourced("o-old", org: "o1", created: "2024-01-01T00:00:00Z"),
                     sourced("mr-a", org: "mr", makeReady: true, title: "acts — pentecost", created: "2026-11-01T00:00:00Z")]
        XCTAssertEqual(ids(items), ["mr-a", "mr-b", "o-old", "o-new"])
        let out = M.output(items: items, selection: .init(), today: today, timeZone: chicago)
        let dates = out.tiles.map(\.date)
        XCTAssertEqual(dates, dates.sorted(), "tile dates stay oldest → newest")
        XCTAssertEqual(out.dateRange, date("2024-01-01T00:00:00Z")...date("2026-10-30T00:00:00Z"))
    }

    /// media-library D7: an empty Source selection shows every source; a choice narrows to those orgs.
    func testSourceFilterNarrowsByOrganization() {
        let items = [sourced("m", org: "mr", makeReady: true, title: "m"), sourced("a", org: "o1"), sourced("b", org: "o2")]
        XCTAssertEqual(Set(ids(items)), ["m", "a", "b"])
        XCTAssertEqual(ids(items, .init(sourceIds: ["o1"])), ["a"])
        XCTAssertEqual(Set(ids(items, .init(sourceIds: ["mr", "o2"]))), ["m", "b"])
        XCTAssertTrue(M.Selection(sourceIds: ["o1"]).hasFilters)
    }

    func testSourceOptionsKeepTheServerOrder() {
        let sources = [MediaSource(id: "mr", name: "MakeReady", isMakeReady: true, canUpload: false),
                       MediaSource(id: "o1", name: "Alpha", isMakeReady: false, canUpload: true)]
        XCTAssertEqual(M.sourceOptions(sources), [.init(id: "mr", label: "MakeReady"), .init(id: "o1", label: "Alpha")])
    }

    func testSearchMatchesTitleDescriptionTagAndUploaderCaseInsensitively() {
        let items = [item("t", title: "Easter Sunrise"), item("d", description: "at the LAKE"),
                     item("g", tags: ["baptism"]), item("u", uploader: ("u9", "Nathan Hughes")), item("x")]
        XCTAssertEqual(ids(items, .init(search: "sunrise")), ["t"])
        XCTAssertEqual(ids(items, .init(search: "lake")), ["d"])
        XCTAssertEqual(ids(items, .init(search: "BAPT")), ["g"])
        XCTAssertEqual(ids(items, .init(search: "hughes")), ["u"])
        XCTAssertEqual(ids(items, .init(search: "  ")).count, 5)
    }

    func testTagsAnyOfAndOptionsFromTheLoadedListSorted() {
        let items = [item("1", tags: ["youth", "retreat"]), item("2", tags: ["family"]), item("3")]
        XCTAssertEqual(ids(items, .init(tags: ["Retreat", "family"])), ["1", "2"])
        XCTAssertEqual(M.output(items: items, selection: .init(), today: today, timeZone: chicago).tagSections,
                       [M.TagSection(title: nil, options: [.init(id: "family", label: "Family"),
                                                           .init(id: "retreat", label: "Retreat"),
                                                           .init(id: "youth", label: "Youth")])])
    }

    // MARK: tag-categories (D7, D8, D10, D12, D13, D16)

    private let bible = TagCategory(key: "bible-books", name: "Books of the Bible", position: 1, tags: [
        TagCategoryMember(tag: "genesis", label: "Genesis", position: 1),
        TagCategoryMember(tag: "exodus", label: "Exodus", position: 2),
        TagCategoryMember(tag: "1samuel", label: "1 Samuel", position: 9),
        TagCategoryMember(tag: "psalm", label: "Psalms", position: 19),
        TagCategoryMember(tag: "psalms", label: "Psalms", position: 19),
    ])

    private func sections(_ items: [MediaLibraryItem], _ categories: [TagCategory]) -> [M.TagSection] {
        M.output(items: items, selection: .init(), today: today, timeZone: chicago, categories: categories).tagSections
    }

    func testBooksFirstInBookOrderThenContentAToZ() {
        let out = sections([item("1", tags: ["dogs", "exodus", "1 samuel"]), item("2", tags: ["animals", "genesis"])], [bible])
        XCTAssertEqual(out.map(\.title), ["BOOKS OF THE BIBLE", "CONTENT"])
        XCTAssertEqual(out[0].options, [.init(id: "cat:bible-books:1", label: "Genesis"),
                                        .init(id: "cat:bible-books:2", label: "Exodus"),
                                        .init(id: "cat:bible-books:9", label: "1 Samuel")])
        XCTAssertEqual(out[1].options.map(\.label), ["Animals", "Dogs"])
    }

    func testOnlyBooksHasNoContentSection() {
        XCTAssertEqual(sections([item("1", tags: ["genesis"])], [bible]).map(\.title), ["BOOKS OF THE BIBLE"])
    }

    func testNoTagsNoSections() {
        XCTAssertEqual(sections([item("1")], [bible]), [])
    }

    func testPsalmAndPsalmsAreOneOptionThatMatchesBoth() {
        let items = [item("1", tags: ["psalm"]), item("2", tags: ["Psalms"]), item("3", tags: ["genesis"])]
        XCTAssertEqual(sections(items, [bible]).first?.options, [.init(id: "cat:bible-books:1", label: "Genesis"),
                                                                 .init(id: "cat:bible-books:19", label: "Psalms")])
        let shown = M.output(items: items, selection: .init(tags: ["cat:bible-books:19"]), today: today, timeZone: chicago,
                             categories: [bible]).tiles.map(\.id)
        XCTAssertEqual(shown, ["1", "2"])
    }

    func testTitleCaseLabelsAndNoCategoriesFallsBackToOneFlow() {
        let out = sections([item("1", tags: ["new life", "genesis"])], [])
        XCTAssertEqual(out, [M.TagSection(title: nil, options: [.init(id: "genesis", label: "Genesis"),
                                                                .init(id: "new life", label: "New Life")])])
    }

    func testTagLabelsFollowOptionOrderAndSkipUnknownIds() {
        let out = sections([item("1", tags: ["dogs", "genesis"])], [bible])
        XCTAssertEqual(M.tagLabels(for: ["dogs", "cat:bible-books:1", "gone"], in: out), ["Genesis", "Dogs"])
    }

    func testALiteralCatColonTagIsTreatedAsText() {
        let items = [item("1", tags: ["cat:nope"]), item("2", tags: ["genesis"])]
        XCTAssertEqual(sections(items, [bible]).last?.options, [.init(id: "cat:nope", label: "Cat:nope")])
        let shown = M.output(items: items, selection: .init(tags: ["cat:nope"]), today: today, timeZone: chicago,
                             categories: [bible]).tiles.map(\.id)
        XCTAssertEqual(shown, ["1"])
    }

    func testLeadersByIdSameNamesKeptApartAndNoUploaderOnlyWhenEmpty() {
        let items = [item("1", uploader: ("u1", "Sam")), item("2", uploader: ("u2", "Sam")), item("3", uploader: nil)]
        let out = M.output(items: items, selection: .init(), today: today, timeZone: chicago)
        XCTAssertEqual(out.leaderOptions, [.init(id: "u1", label: "Sam"), .init(id: "u2", label: "Sam")])
        XCTAssertEqual(ids(items, .init(leaderIds: ["u2"])), ["2"])
        XCTAssertEqual(ids(items).count, 3)
    }

    func testTimeCutoffIsStartOfTodayMinusNMinusOneDaysInTheDeviceZone() {
        // Chicago 2026-10-31: last 7 days starts 2026-10-25 00:00 CDT = 05:00Z.
        XCTAssertEqual(M.cutoff(.last7, today: today, timeZone: chicago), date("2026-10-25T05:00:00Z"))
        XCTAssertNil(M.cutoff(.all, today: today, timeZone: chicago))
        let items = [item("in", taken: "2026-10-25T05:00:00Z"), item("out", taken: "2026-10-25T04:59:59Z")]
        XCTAssertEqual(ids(items, .init(time: .last7)), ["in"])
    }

    func testChipsCombineWithAnd() {
        let items = [item("1", tags: ["youth"], uploader: ("u1", "Ann")), item("2", tags: ["youth"], uploader: ("u2", "Bo"))]
        XCTAssertEqual(ids(items, .init(tags: ["youth"], leaderIds: ["u2"])), ["2"])
    }

    func testTileURLFallbacks() {
        XCTAssertEqual(M.tileURLs(url: "https://img/a.jpeg", thumbnailUrl: "https://img/a-thumb.jpeg").medium?.absoluteString, "https://img/a-md.jpeg")
        let png = M.tileURLs(url: "https://img/a.png", thumbnailUrl: nil)
        XCTAssertNil(png.medium)
        XCTAssertEqual(png.thumb?.absoluteString, "https://img/a.png")
    }

    func testEmptyAndNoResultsAndDateRange() {
        XCTAssertTrue(M.output(items: [], selection: .init(), today: today, timeZone: chicago).isEmptyLibrary)
        let items = [item("a", taken: "2024-01-05T08:00:00Z"), item("b", taken: "2025-06-14T14:30:00Z")]
        let none = M.output(items: items, selection: .init(search: "zzz"), today: today, timeZone: chicago)
        XCTAssertTrue(none.isNoResults)
        XCTAssertFalse(none.isEmptyLibrary)
        XCTAssertEqual(M.output(items: items, selection: .init(), today: today, timeZone: chicago).dateRange,
                       date("2024-01-05T08:00:00Z")...date("2025-06-14T14:30:00Z"))
    }
}
