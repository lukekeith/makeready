import XCTest
@testable import MakeReady

/// text-activity Task 22 (§Contract rows 1-6, D46): the draft endpoints write the stores and
/// refresh what the program home derives from them.
@MainActor
final class ActivityActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private var actions: ActivityActions { ActivityActions(api: api, state: state) }

    private enum Fixture {
        static let textDocument = ##"{"schemaVersion":1,"kind":"text","background":{"color":"#000000"},"content":{"type":"canvas","objects":[]},"actions":[]}"##

        static func activity(_ id: String, position: Int, version: String = "v1", title: String = "Text", seconds: String = "null") -> String {
            #"{"id":"\#(id)","lessonVersionId":"\#(version)","activityKey":"k-\#(id)","position":\#(position),"kind":"text","title":"\#(title)","document":\#(textDocument),"estimatedSeconds":\#(seconds)}"#
        }

        static let createResponse = #"{"activity":\#(activity("a1", position: 0)),"media":{"m1":{"url":"https://cdn.example/m1.jpg","kind":"image"}}}"#

        static func version(_ id: String = "v1", status: String = "DRAFT") -> String {
            #"{"id":"\#(id)","lessonId":"l1","enrollmentId":null,"number":1,"status":"\#(status)","title":"Day one","estimatedSeconds":null,"publishedAt":null}"#
        }
    }

    private func seed(_ id: String, position: Int, version: String = "v1", seconds: Int? = nil) throws {
        let json = Fixture.activity(id, position: position, version: version, seconds: seconds.map(String.init) ?? "null")
        state.activities.upsert(try JSONDecoder.apiDecoder.decode(ContentActivity.self, from: Data(json.utf8)))
    }

    private func seedLesson() throws {
        state.lessons.upsert(Lesson(id: "l1", studyProgramId: "p1", position: 1))
        state.lessonVersions.upsert(try JSONDecoder.apiDecoder.decode(LessonVersion.self, from: Data(Fixture.version().utf8)))
    }

    private var emptyText: ActivityDocument {
        ActivityDocument(raw: (try? JSONDecoder().decode(JSONValue.self, from: Data(Fixture.textDocument.utf8))) ?? .null)
    }

    // MARK: - Create

    func testCreateAppendsToTheVersionAndStoresMedia() async throws {
        api.stub("POST", "/api/lesson-versions/v1/activities", json: Fixture.createResponse)
        let act = try await actions.create(versionId: "v1", kind: "text", title: "Text", document: emptyText)
        XCTAssertEqual(state.activities(forVersion: "v1").map(\.id), [act.id])
        XCTAssertNotNil(state.mediaMap["m1"])
    }

    func testCreateSendsTheKindTitleAndWholeDocument() async throws {
        api.stub("POST", "/api/lesson-versions/v1/activities", json: Fixture.createResponse)
        _ = try await actions.create(versionId: "v1", kind: "text", title: "Text", document: emptyText)
        let body = try XCTUnwrap(api.calls.last?.body)
        XCTAssertEqual(body["kind"] as? String, "text")
        XCTAssertEqual(body["title"] as? String, "Text")
        XCTAssertEqual((body["document"] as? [String: Any])?["kind"] as? String, "text")
    }

    func testCreateRefreshesTheLessonRowsRailSummaries() async throws {
        try seedLesson()
        api.stub("POST", "/api/lesson-versions/v1/activities", json: Fixture.createResponse)
        _ = try await actions.create(versionId: "v1", kind: "text", title: "Text", document: emptyText)
        XCTAssertEqual(state.lessons["l1"]?.activities.map(\.id), ["a1"])
        XCTAssertEqual(state.lessons["l1"]?.draftVersionId, "v1")
    }

    // MARK: - Delete

    func testDeleteRemovesAndClosesUpPositions() async throws {
        try seed("a", position: 0)
        try seed("b", position: 1)
        api.stub("DELETE", "/api/content-activities/a", json: #"{"success":true}"#)
        try await actions.delete(activityId: "a")
        XCTAssertEqual(state.activities(forVersion: "v1").map { [$0.id, String($0.position)] }, [["b", "0"]])
    }

    func testDeleteLeavesOtherVersionsAlone() async throws {
        try seed("a", position: 0)
        try seed("x", position: 3, version: "v2")
        api.stub("DELETE", "/api/content-activities/a", json: #"{"success":true}"#)
        try await actions.delete(activityId: "a")
        XCTAssertEqual(state.activities(forVersion: "v2").map(\.position), [3])
    }

    // MARK: - Save

    func testSaveConflictThrowsNotDraft() async {
        api.errorFor = { _, _ in APIHTTPError(status: 409, message: "x", details: ["code": "NOT_DRAFT"]) }
        do {
            try await actions.save(activityId: "a", title: nil, document: emptyText)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? ActivityActionsError, .notDraft)
        }
    }

    func testOtherConflictsAreNotNotDraft() async {
        api.errorFor = { _, _ in APIHTTPError(status: 409, message: "x", details: ["code": "CONFLICT"]) }
        do {
            try await actions.save(activityId: "a", title: nil, document: emptyText)
            XCTFail("expected a throw")
        } catch {
            XCTAssertNil(error as? ActivityActionsError)
            XCTAssertEqual((error as? APIHTTPError)?.status, 409)
        }
    }

    func testSaveReplacesTheActivityAndOmitsAnUnchangedTitle() async throws {
        try seed("a1", position: 0)
        api.stub("PUT", "/api/content-activities/a1", json: Fixture.createResponse.replacingOccurrences(of: #""title":"Text""#, with: #""title":"Renamed""#))
        try await actions.save(activityId: "a1", title: nil, document: emptyText)
        XCTAssertNil(api.calls.last?.body?["title"])
        XCTAssertEqual(state.activities["a1"]?.title, "Renamed")
        XCTAssertNotNil(state.mediaMap["m1"])
    }

    // MARK: - Reads

    func testLoadDraftReplacesTheVersionsActivitiesAndStoresTheVersion() async throws {
        try seed("gone", position: 0)
        api.stub("GET", "/api/lessons/l1/draft", json: #"{"version":\#(Fixture.version()),"activities":[\#(Fixture.activity("a1", position: 0))],"media":{}}"#)
        try await actions.loadDraft(lessonId: "l1")
        XCTAssertEqual(state.activities(forVersion: "v1").map(\.id), ["a1"])
        XCTAssertEqual(state.draftVersionId(forLesson: "l1"), "v1")
    }

    func testLoadVersionStoresAPublishedVersion() async throws {
        api.stub("GET", "/api/lesson-versions/v9", json: #"{"version":\#(Fixture.version("v9", status: "PUBLISHED")),"activities":[\#(Fixture.activity("a9", position: 0, version: "v9"))],"media":{}}"#)
        try await actions.loadVersion(id: "v9")
        XCTAssertEqual(state.activities(forVersion: "v9").map(\.id), ["a9"])
        XCTAssertNil(state.draftVersionId(forLesson: "l1"))
    }

    // MARK: - Reorder

    func testReorderStoresTheServersOrder() async throws {
        try seed("a", position: 0)
        try seed("b", position: 1)
        api.stub("PATCH", "/api/lesson-versions/v1/activities/order",
                 json: #"{"activities":[\#(Fixture.activity("b", position: 0)),\#(Fixture.activity("a", position: 1))]}"#)
        try await actions.reorder(versionId: "v1", activityIds: ["b", "a"])
        XCTAssertEqual(state.activities(forVersion: "v1").map(\.id), ["b", "a"])
        XCTAssertEqual(api.calls.last?.body?["activityIds"] as? [String], ["b", "a"])
    }

    // MARK: - Session

    func testActivitiesVersionsAndMediaPersistAcrossTheDiskCache() throws {
        try seed("a1", position: 0)
        try seedLesson()
        state.mediaMap["m1"] = MediaMapEntry(url: "u", width: nil, height: nil, kind: "image", playbackUrl: nil,
                                             posterUrl: nil, durationSeconds: nil, uploaderName: nil)
        let snapshot = PersistedState(from: state)
        XCTAssertEqual(snapshot.activities.map(\.id), ["a1"])
        XCTAssertEqual(snapshot.lessonVersions.map(\.id), ["v1"])
        XCTAssertNotNil(snapshot.mediaMap["m1"])
    }
}
