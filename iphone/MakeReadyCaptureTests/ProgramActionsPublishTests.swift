import XCTest
@testable import MakeReady

/// text-activity Task 22 (D37, D41): publish is one POST that may write nothing.
@MainActor
final class ProgramActionsPublishTests: XCTestCase {
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    func testPublishPostsToPublishAndReadsNullVersion() async throws {
        api.stub("POST", "/api/programs/p1/publish", json: #"{"programVersion":null,"changedLessonIds":[]}"#)
        let r = try await ProgramActions(api: api, state: AppState()).publish(programId: "p1", changeSummary: nil)
        XCTAssertNil(r.programVersionNumber)
        XCTAssertEqual(r.changedLessonIds, [])
        XCTAssertEqual(api.calls.last?.method, "POST")
        XCTAssertEqual(api.calls.last?.body?.count, 0)
    }

    func testPublishReadsTheVersionNumberAndSendsTheSummary() async throws {
        api.stub("POST", "/api/programs/p1/publish", json: #"{"programVersion":{"id":"pv2","number":2},"changedLessonIds":["l1","l3"]}"#)
        let r = try await ProgramActions(api: api, state: AppState()).publish(programId: "p1", changeSummary: "Typos")
        XCTAssertEqual(r.programVersionNumber, 2)
        XCTAssertEqual(r.changedLessonIds, ["l1", "l3"])
        XCTAssertEqual(api.calls.last?.body?["changeSummary"] as? String, "Typos")
    }

    func testPublishDropsTheFrozenDraftFromState() async throws {
        let state = AppState()
        state.lessons.upsert(Lesson(id: "l1", position: 1, title: "One", draftVersionId: "v1"))
        state.lessonVersions.upsert(LessonVersion(id: "v1", lessonId: "l1", enrollmentId: nil, number: 1,
                                                  status: .draft, title: nil, estimatedSeconds: nil, publishedAt: nil))
        XCTAssertEqual(state.draftVersionId(forLesson: "l1"), "v1")
        api.stub("POST", "/api/programs/p1/publish", json: #"{"programVersion":{"id":"pv2","number":2},"changedLessonIds":["l1"]}"#)
        _ = try await ProgramActions(api: api, state: state).publish(programId: "p1", changeSummary: nil)
        XCTAssertNil(state.draftVersionId(forLesson: "l1"))
        XCTAssertNil(state.lessonVersions["v1"])
        XCTAssertEqual(state.lessons["l1"]?.publishedVersionId, "v1")
    }
}
