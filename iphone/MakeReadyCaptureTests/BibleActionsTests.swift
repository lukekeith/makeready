import XCTest
@testable import MakeReady

/// bible-verse-picker Task 7: BibleActions and the AppState Bible domain (D7, D9, D17, D18, D24).
@MainActor
final class BibleActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private var actions: BibleActions!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        // A chapter left on disk by another test must not mask the failure case.
        BibleCacheManager.shared.clearCache()
        state = AppState()
        api = StubAPIClient()
        actions = BibleActions(api: api, state: state)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "selectedBibleTranslation")
        BibleCacheManager.shared.clearCache()
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func decode(_ json: String) throws -> BibleSearchResult {
        try JSONDecoder.apiDecoder.decode(BibleSearchResult.self, from: Data(json.utf8))
    }

    func testTranslationsArePopularFirstAndKJVResolvesToTheServedCode() async {
        api.stub("GET", "/api/bible/translations", json: #"{"translations":[{"id":"a","code":"WEBBE","name":"World English Bible, British Edition","language":"eng","copyright":"","popularity":10},{"id":"b","code":"ENGKJV","name":"King James (Authorised) Version","language":"eng","copyright":"","popularity":80},{"id":"c","code":"NIV11","name":"New International Version","language":"eng","copyright":"","popularity":100}]}"#)
        state.selectedBibleTranslation = "KJV"
        await actions.loadTranslations()
        XCTAssertEqual(state.sortedBibleTranslations.map(\.code), ["NIV11", "ENGKJV", "WEBBE"])
        XCTAssertEqual(state.selectedBibleTranslation, "ENGKJV")
    }

    func testSearchSendsRecordAndTranslation() async {
        api.stub("POST", "/api/search/smart", json: #"{"type":"grouped","books":[],"verses":[]}"#)
        await actions.search("jo", record: false)
        let body = api.calls.last!.body!
        XCTAssertEqual(body["record"] as? Bool, false); XCTAssertEqual(body["translation"] as? String, state.selectedBibleTranslation)
    }

    func testEverySmartSearchTypeDecodes() throws {
        XCTAssertEqual(try decode(#"{"type":"direct","book":{"bookNumber":43,"name":"John","abbrev":"John"},"chapter":3,"verses":[{"verse":16,"text":"For God","reference":"John 3:16"}]}"#), .direct(book: 43, chapter: 3, verses: [BibleVerse(verse: 16, text: "For God")]))
        if case .grouped(_, let v) = try decode(#"{"type":"semantic","books":[],"verses":[{"bookNumber":19,"chapter":23,"verse":1,"verseEnd":6,"reference":"Psalm 23:1-6","text":"The Lord","title":"The Shepherd","summary":"Care"}]}"#) {
            XCTAssertEqual(v.first?.verseEnd, 6) } else { XCTFail() }
        XCTAssertEqual(try decode(#"{"type":"error","error":"nope"}"#), .error("nope"))
    }

    func testAnErrorTypeSurfacesTheBanner() async {
        api.stub("POST", "/api/search/smart", json: #"{"type":"error","error":"Translation not found"}"#)
        await actions.search("john", record: true)
        XCTAssertNotNil(state.activeSurfacedError)
    }

    func testDeleteRecentRemovesTheRow() async {
        state.bibleRecents = [BibleRecent(id: "r1", query: "grace"), BibleRecent(id: "r2", query: "love")]
        api.stub("DELETE", "/api/search/recent/r1", json: #"{"success":true}"#)
        await actions.deleteRecent(id: "r1")
        XCTAssertEqual(state.bibleRecents.map(\.id), ["r2"])
    }

    func testAFailedChapterThrowsTypedAndWritesNothing() async {
        api.errorToThrow = URLError(.notConnectedToInternet)
        do { _ = try await actions.loadChapter(book: 43, chapter: 3, translation: "ENGKJV"); XCTFail() }
        catch { XCTAssertEqual(error as? BibleActionsError, .chapterUnavailable) }
        XCTAssertTrue(state.bibleChapters.isEmpty)
    }
}
