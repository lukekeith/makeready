import XCTest
@testable import MakeReady

/// text-activity Task 24 (D15, D16): the Text tile creates then swaps to the editor; the other tiles are inert.
@MainActor
final class ActivityNewContainerTests: XCTestCase {

    final class RecordingNavigator: ActivityNewNavigating {
        var replaced: [UI2Destination] = []
        func replace(with destination: UI2Destination) { replaced.append(destination) }
    }

    private struct Boom: Error {}

    func testOtherTilesAreUnavailable() {
        XCTAssertEqual(Set(ActivityNewContainer.unavailableTypes), Set(["bibleVerse", "video", "youtube", "write", "poll"]))
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
}

extension ActivityNewContainer.Actions {
    static func stub(createdId: String) -> Self {
        Self(draftVersionId: { _ in "draft" }, reloadDraftVersionId: { _ in "draft" }, create: { _, _, _, _ in createdId })
    }

    static func stub(failing error: Error) -> Self {
        Self(draftVersionId: { _ in "draft" }, reloadDraftVersionId: { _ in "draft" }, create: { _, _, _, _ in throw error })
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
