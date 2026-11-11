import XCTest
@testable import MakeReady

/// text-activity Task 24 (D15, D16): the Text tile creates then swaps to the editor; the other tiles are inert.
@MainActor
final class ActivityNewContainerTests: XCTestCase {

    final class RecordingNavigator: ActivityNewNavigating {
        var replaced: [UI2Destination] = []
        var pushed: [UI2Destination] = []
        var depth = 0
        func push(_ destination: UI2Destination) { pushed.append(destination) }
        func replace(with destination: UI2Destination) { replaced.append(destination) }
    }

    private struct Boom: Error {}

    func testOtherTilesAreUnavailable() {
        XCTAssertEqual(Set(ActivityNewContainer.unavailableTypes), Set(["video", "youtube", "write", "poll"]))
    }

    func testTheBibleTileIsAvailable() {
        XCTAssertFalse(ActivityNewContainer.unavailableTypes.contains(ActivityTypeGrid.ActivityType.bibleVerse.rawValue))
    }

    /// D15: the tile pushes Books with a new-activity flow that returns to this page's depth; nothing is created.
    func testTheBibleTilePushesBooksWithAFlowAndCreatesNothing() async {
        let nav = RecordingNavigator()
        nav.depth = 4
        var creates = 0
        let actions = ActivityNewContainer.Actions(draftVersionId: { _ in "draft" }, create: { _, _, _, _ in creates += 1; return "n" })
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: nav)
        model.afterActivityId = "a1"
        model.selectBible()
        guard case .bibleBooks(let flowId)? = nav.pushed.first else { return XCTFail("no Books push") }
        let flow = AppState.shared.biblePickFlows[flowId]
        XCTAssertEqual(flow?.caller, .newActivity(lessonId: "l1", afterActivityId: "a1"))
        XCTAssertEqual(flow?.returnDepth, 4)
        XCTAssertEqual(creates, 0)
        AppState.shared.endBiblePickFlow(flowId)
    }

    /// D14/D15: a picked passage is created and the first part opens in the editor.
    func testAPickCreatesTheActivityAndOpensIt() async {
        let nav = RecordingNavigator()
        let actions = ActivityNewContainer.Actions(draftVersionId: { _ in "draft" }, create: { _, kind, _, _ in
            XCTAssertEqual(kind, "bible"); return "b1" })
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: nav)
        let pick = BiblePick(
            passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16,
                                  startOffset: nil, endOffset: nil, translation: "KJV"),
            verses: [BibleVerse(verse: 16, text: "For God so loved the world.")], bookName: "John")
        await model.createBible(pick: pick)
        XCTAssertEqual(nav.replaced, [.activitiesEditor(activityId: "b1")])
    }

    /// D14: a failed save surfaces the banner with a Retry that resumes, never re-POSTing a created part.
    func testAFailedBibleSaveOffersARetryThatResumes() async {
        var posts = 0, failNext = true
        var retry: (() -> Void)?
        let actions = ActivityNewContainer.Actions(draftVersionId: { _ in "draft" }, create: { _, _, _, _ in
            if failNext { failNext = false; throw BibleSaveTests.Stub.Down() }
            posts += 1; return "b1" })
        let nav = RecordingNavigator()
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: nav,
                                               reportBible: { _, r in retry = r })
        let pick = BiblePick(
            passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16,
                                  startOffset: nil, endOffset: nil, translation: "KJV"),
            verses: [BibleVerse(verse: 16, text: "For God so loved the world.")], bookName: "John")
        await model.createBible(pick: pick)
        XCTAssertNotNil(retry)
        XCTAssertTrue(nav.replaced.isEmpty)
        await model.retryBible()
        XCTAssertEqual(posts, 1)
        XCTAssertEqual(nav.replaced, [.activitiesEditor(activityId: "b1")])
    }

    func testTextTileCreatesThenOpensTheEditor() async {
        let nav = RecordingNavigator()
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: .stub(createdId: "new1"), navigator: nav)
        await model.selectText()
        XCTAssertEqual(nav.replaced, [.activitiesEditor(activityId: "new1")])
        XCTAssertFalse(model.isCreating)
    }

    /// D16: the create is on the lesson's draft, titled "Text", with the starter document.
    func testCreateTargetsTheDraftWithTheStarterDocument() async {
        var seen: (version: String, title: String, kind: String, document: ActivityDocument)?
        let actions = ActivityNewContainer.Actions(
            draftVersionId: { lessonId in "draft-of-\(lessonId)" },
            create: { version, kind, title, document in seen = (version, title, kind, document); return "n" })
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: RecordingNavigator())
        await model.selectText()
        XCTAssertEqual(seen?.version, "draft-of-l1")
        XCTAssertEqual(seen?.kind, "text")
        XCTAssertEqual(seen?.title, "Text")
        XCTAssertEqual(seen?.document.raw[path: ["kind"]], .string("text"))
        XCTAssertNotNil(seen?.document.background.gradient)
    }

    /// D16: the tile is disabled while the request is in flight.
    func testTheTileIsDisabledWhileTheRequestIsInFlight() async {
        var duringCreate: Bool?
        var model: ActivityNewContainer.Model!
        let actions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v" },
            create: { _, _, _, _ in duringCreate = model.isCreating; return "n" })
        model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: RecordingNavigator())
        await model.selectText()
        XCTAssertEqual(duringCreate, true)
    }

    /// A second tap while creating makes no second request.
    func testASecondTapWhileCreatingIsIgnored() async {
        var creates = 0
        var model: ActivityNewContainer.Model!
        let actions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v" },
            create: { _, _, _, _ in creates += 1; await model.selectText(); return "n" })
        model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: RecordingNavigator())
        await model.selectText()
        XCTAssertEqual(creates, 1)
    }

    /// A create failure surfaces the banner and leaves the tile enabled, with no navigation.
    func testACreateFailureSurfacesTheBannerAndLeavesTheTileEnabled() async {
        let nav = RecordingNavigator()
        var reported = 0
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: .stub(failing: Boom()), navigator: nav,
                                               report: { _ in reported += 1 })
        await model.selectText()
        XCTAssertEqual(reported, 1)
        XCTAssertTrue(nav.replaced.isEmpty)
        XCTAssertFalse(model.isCreating)
        XCTAssertEqual(model.pendingType, "")
    }

    /// D46: the cached draft was frozen by a publish made elsewhere; the tile reloads the draft and posts once more.
    func testANotDraftCreateReloadsTheDraftAndPostsOnceMore() async {
        let nav = RecordingNavigator()
        var versions: [String] = []
        let actions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "stale" },
            reloadDraftVersionId: { _ in "fresh" },
            create: { version, _, _, _ in
                versions.append(version)
                if version == "stale" { throw ActivityActionsError.notDraft }
                return "new1"
            })
        let model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: nav, report: { _ in XCTFail("reported") })
        await model.selectText()
        XCTAssertEqual(versions, ["stale", "fresh"])
        XCTAssertEqual(nav.replaced, [.activitiesEditor(activityId: "new1")])
    }

    func testThePendingTypeNamesTheTextTileWhileCreating() async {
        var during: String?
        var model: ActivityNewContainer.Model!
        let actions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v" },
            create: { _, _, _, _ in during = model.pendingType; return "n" })
        model = ActivityNewContainer.Model(lessonId: "l1", actions: actions, navigator: RecordingNavigator())
        await model.selectText()
        XCTAssertEqual(during, "text")
    }

    /// D16: empty canvas on a generated gradient (text-activity-v2 D5), a share chrome and 02 §2's fallback.
    func testTheStarterDocumentIsAnEmptyTextCanvas() {
        let doc = ActivityNewContainer.textDocument(title: "Text")
        XCTAssertEqual(doc.raw[path: ["schemaVersion"]], .number(1))
        XCTAssertEqual(doc.raw[path: ["kind"]], .string("text"))
        XCTAssertEqual(doc.raw[path: ["chrome", "topAction"]], .string("share"))
        XCTAssertEqual(doc.raw[path: ["content", "type"]], .string("canvas"))
        XCTAssertEqual(doc.raw[path: ["content", "objects"]], .array([]))
        XCTAssertEqual(doc.raw[path: ["actions"]], .array([]))
        XCTAssertEqual(doc.raw[path: ["fallback", "body"]], .string(ActivityDocument.fallbackBody))
        guard case .canvas(let canvas) = doc.renderable else { return XCTFail("not a canvas") }
        XCTAssertTrue(canvas.objects.isEmpty)
    }

    /// The picker's state names the unavailable tiles and the pending one.
    func testTheMapperCarriesUnavailableAndPendingTypes() {
        let s = ActivityNewMapper.state(lesson: nil, pendingType: "text")
        XCTAssertEqual(s.pendingType, "text")
        XCTAssertEqual(Set(s.unavailableTypes), Set(ActivityNewContainer.unavailableTypes))
    }

    /// text-activity-v2 D5/D17: the starter's background is a blob gradient whose base is the page colour.
    func testTheStarterCarriesABlobGradient() throws {
        var rng = SeededRandom(seed: 1)
        let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
        let gradient = try XCTUnwrap(doc.background.gradient)
        XCTAssertEqual(gradient.style, "blobs")
        XCTAssertEqual(gradient.blobs.count, 4)
        XCTAssertEqual(doc.background.color, gradient.base)
        XCTAssertNotEqual(doc.background.color.uppercased(), "#FFFFFF")
    }

    /// text-activity-v2 D3: the same seed gives the same starter.
    func testASeededStarterIsDeterministic() {
        var a = SeededRandom(seed: 9), b = SeededRandom(seed: 9)
        XCTAssertEqual(ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &a),
                       ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &b))
    }

}

extension ActivityNewContainer.Actions {
    static func stub(createdId: String) -> Self {
        Self(draftVersionId: { _ in "draft" }, reloadDraftVersionId: { _ in "draft" }, create: { _, _, _, _ in createdId })
    }

    static func stub(failing error: Error) -> Self {
        Self(draftVersionId: { _ in "draft" }, reloadDraftVersionId: { _ in "draft" }, create: { _, _, _, _ in throw error })
    }
}
