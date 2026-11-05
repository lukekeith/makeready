import XCTest
@testable import MakeReady

/// master-search D5, D9, D14, D21, D27, D31, D41: the Search tab's mapper (items to State, labels,
/// tag sections, routing) and the container's paging decision.
@MainActor
final class SearchHomeMapperTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func item(_ id: String, type: String = "PROGRAM", title: String = "T", createdAt: String = "2026-10-03T12:00:00.000Z",
                      imageUrl: String? = nil, parent: SearchItemParent? = nil) -> SearchItem {
        SearchItem(type: type, id: id, title: title, createdAt: createdAt, imageUrl: imageUrl, parent: parent, openedAt: nil)
    }

    private func tag(_ tag: String, _ label: String, _ category: String?) -> SearchFilterTag {
        SearchFilterTag(tag: tag, label: label, category: category)
    }

    private func options(tags: [SearchFilterTag] = []) -> SearchFilterOptions {
        SearchFilterOptions(
            success: true,
            organizations: [SearchFilterOrg(id: "o1", name: "Org One"), SearchFilterOrg(id: "o2", name: "Org Two")],
            groups: [SearchFilterGroup(id: "g1", name: "Group One", organizationId: "o1"),
                     SearchFilterGroup(id: "g2", name: "Group Two", organizationId: "o1")],
            leaders: [SearchFilterLeader(id: "l1", name: "Lee")],
            tags: tags, error: nil)
    }

    private func output(results: [SearchItem] = [], query: String = "", answered: String? = nil,
                        selection: SearchHomeMapper.Selection = .init()) -> SearchHomeMapper.Output {
        SearchHomeMapper.output(recents: [], results: results, query: query, answeredQuery: answered,
                                selection: selection, options: options(), tz: utc)
    }

    func testKindMapDropsUnknownTypes() {
        let types = ["PROGRAM", "TEMPLATE", "MEMBER", "GROUP", "LESSON", "EVENT", "POST", "VIDEO", "PHOTO", "FUTURE"]
        let out = output(results: types.map { item($0, type: $0) }, query: "gr", answered: "gr")
        XCTAssertEqual(out.state.resultKinds, ["program", "program", "member", "group", "lesson", "event", "post", "media", "photo"])
        XCTAssertEqual(out.resultItems.count, 9)
    }

    func testExitsForEveryType() {
        let parent = SearchItemParent(type: "PROGRAM", id: "p", name: "Romans")
        let group = SearchItemParent(type: "GROUP", id: "gp", name: "Youth")
        XCTAssertEqual(SearchHomeMapper.exit(for: item("t", type: "TEMPLATE")), .push(.programsHome))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("l", type: "LESSON", parent: parent)), .push(.studyProgramHome(id: "p", name: "Romans")))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("v", type: "VIDEO")), .push(.mediaHome))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("m", type: "MEMBER", title: "Ann")), .push(.memberDetail(id: "m", name: "Ann")))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("g", type: "GROUP", title: "G")), .push(.groupDetail(id: "g", name: "G")))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("ph", type: "PHOTO", title: "P", imageUrl: "https://i")), .viewer(url: "https://i", title: "P"))
        // The rows the table did not spell out: a program, an event and a post.
        XCTAssertEqual(SearchHomeMapper.exit(for: item("p", type: "PROGRAM", title: "Romans")), .push(.studyProgramHome(id: "p", name: "Romans")))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("e", type: "EVENT", parent: group)), .push(.groupDetail(id: "gp", name: "Youth")))
        XCTAssertEqual(SearchHomeMapper.exit(for: item("po", type: "POST", parent: group)), .push(.groupDetail(id: "gp", name: "Youth")))
    }

    func testChipLabels() {
        var sel = SearchHomeMapper.Selection()
        XCTAssertEqual(output(selection: sel).state.typeFilterLabel, "Type")
        sel.orgIds = ["o1"]
        XCTAssertEqual(output(selection: sel).state.orgFilterLabel, "Org One")
        sel.groupIds = ["g1", "g2"]
        let out = output(selection: sel)
        XCTAssertEqual(out.state.groupFilterLabel, "2 groups")
        XCTAssertEqual(Set(out.state.activeFilters), ["orgs", "groups"])
    }

    func testProgramsChipSendsBothTypes() {
        var sel = SearchHomeMapper.Selection()
        sel.typeIds = ["programs", "photos"]
        XCTAssertEqual(Set(SearchHomeMapper.filters(sel).types), ["PROGRAM", "TEMPLATE", "PHOTO"])
    }

    func testTypeOptionsAreInDesignOrder() {
        XCTAssertEqual(SearchHomeMapper.typeOptions.map(\.label),
                       ["Programs", "Members", "Groups", "Lessons", "Events", "Posts", "Videos", "Photos"])
    }

    func testTagSectionsKeepC5Order() {
        let tags = [tag("1 samuel", "1 Samuel", "Books"), tag("mark", "Mark", "Books"), tag("lent", "Lent", nil)]
        let sections = SearchHomeMapper.tagSections(options: options(tags: tags))
        XCTAssertEqual(sections.map(\.title), ["Books", nil])
        XCTAssertEqual(sections[0].options.map(\.label), ["1 Samuel", "Mark"])
    }

    func testTagSectionsGroupByFirstSeenCategoryAndPutUncategorizedLast() {
        let tags = [tag("lent", "Lent", nil), tag("john", "John", "Books"), tag("advent", "Advent", "Seasons"),
                    tag("mark", "Mark", "Books")]
        let sections = SearchHomeMapper.tagSections(options: options(tags: tags))
        XCTAssertEqual(sections.map(\.title), ["Books", "Seasons", nil])
        XCTAssertEqual(sections[0].options.map(\.id), ["john", "mark"])
    }

    func testNoResultsHeldUntilAnswered() {
        XCTAssertFalse(output(results: [], query: "gra", answered: nil).state.queryAnswered)
        XCTAssertFalse(output(results: [], query: "gra", answered: "gr").state.queryAnswered)
        XCTAssertTrue(output(results: [], query: " gra ", answered: "gra").state.queryAnswered)
    }

    /// D41 (refined): an answer with no rows is held for the screen until the current query is answered.
    func testEmptyAnswerIsHeldWhileTheNextQueryIsUnanswered() {
        XCTAssertEqual(output(results: [], query: "xyz", answered: "xy").state.heldNoResultsQuery, "xy")
        XCTAssertEqual(output(results: [], query: "xyz", answered: " xy ").state.heldNoResultsQuery, "xy")
    }

    func testNothingIsHeldWithoutAnEmptyAnswerForAnotherQuery() {
        XCTAssertNil(output(results: [], query: "xyz", answered: "xyz").state.heldNoResultsQuery)
        XCTAssertNil(output(results: [], query: "xyz", answered: nil).state.heldNoResultsQuery)
        XCTAssertNil(output(results: [item("a")], query: "xyz", answered: "xy").state.heldNoResultsQuery)
        XCTAssertNil(output(results: [], query: "xyz", answered: " x ").state.heldNoResultsQuery)
    }

    func testDescriptionIsCreatedDate() {
        let out = output(results: [item("a", createdAt: "2026-10-03T12:00:00.000Z")], query: "gr", answered: "gr")
        XCTAssertEqual(out.state.resultDescriptions, ["Created Oct 3, 2026"])
    }

    func testRecentsMapWithTheSameKindsAndDropUnknownTypes() {
        let recents = [item("a", type: "LESSON", title: "Day 1"), item("b", type: "FUTURE")]
        let out = SearchHomeMapper.output(recents: recents, results: [], query: "", answeredQuery: nil,
                                          selection: .init(), options: nil, tz: utc)
        XCTAssertEqual(out.state.recentKinds, ["lesson"])
        XCTAssertEqual(out.state.recentTitles, ["Day 1"])
        XCTAssertEqual(out.recentItems.map(\.id), ["a"])
    }

    /// F11: what the code can prove. The next page is asked for only within the last five rows;
    /// whether the eager VStack fires every row at once is only observable on a device (agent walk).
    func testNextPageIsAskedForOnlyNearTheEnd() {
        XCTAssertFalse(SearchHomeContainer.shouldLoadNextPage(afterRow: 14, of: 20))
        XCTAssertTrue(SearchHomeContainer.shouldLoadNextPage(afterRow: 15, of: 20))
        XCTAssertTrue(SearchHomeContainer.shouldLoadNextPage(afterRow: 19, of: 20))
        XCTAssertTrue(SearchHomeContainer.shouldLoadNextPage(afterRow: 0, of: 3))
    }

    /// Agent walk round 1: the field reports its text again on losing focus; an answered query must
    /// not run again, or its first page replaces every page loaded since.
    func testAnAnsweredQueryDoesNotRunAgainWhenTheFieldReportsItUnchanged() {
        XCTAssertFalse(SearchHomeContainer.shouldRunQuery(text: "grace", previous: "grace", answered: "grace"))
        XCTAssertFalse(SearchHomeContainer.shouldRunQuery(text: "grace ", previous: "grace", answered: "grace"))
    }

    func testAChangedOrUnansweredQueryRuns() {
        XCTAssertTrue(SearchHomeContainer.shouldRunQuery(text: "grace", previous: "grac", answered: "grac"))
        XCTAssertTrue(SearchHomeContainer.shouldRunQuery(text: "gr", previous: "grace", answered: "grace"))
        XCTAssertTrue(SearchHomeContainer.shouldRunQuery(text: "", previous: "grace", answered: "grace"))
        XCTAssertTrue(SearchHomeContainer.shouldRunQuery(text: "grace", previous: "grace", answered: nil), "the Search key retries a failed query")
    }

    // MARK: - D41 (refined): what the screen draws below the header

    private func recentsState() -> SearchHomeScreen.State { .recentsPopulated }

    func testAnsweredEmptyKeepsItsLineWhileTheNextQueryIsUnanswered() {
        var state = recentsState()
        state.queryAnswered = false
        state.heldNoResultsQuery = "xy"
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "xyz"), .noResults(query: "xy"))
    }

    func testAnAnsweredEmptyQueryPrintsItsOwnLine() {
        var state = recentsState()
        state.queryAnswered = true
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "xyz"), .noResults(query: "xyz"))
    }

    func testUnansweredWithNothingHeldFallsThroughToRecents() {
        var state = recentsState()
        state.queryAnswered = false
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "xyz"), .recents)
        state.recentTitles = []
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "xyz"), .empty)
    }

    func testRowsWinOverAHeldLine() {
        var state = SearchHomeScreen.State.queryingResults
        state.queryAnswered = false
        state.heldNoResultsQuery = "xy"
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "Romans"), .results)
    }

    func testBelowTwoCharactersShowsRecents() {
        var state = recentsState()
        state.heldNoResultsQuery = "xy"
        XCTAssertEqual(SearchHomeScreen.content(for: state, query: "x"), .recents)
    }
}
