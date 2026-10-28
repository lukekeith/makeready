import XCTest
import UIKit
@testable import MakeReady

/// ui2-programs Task 9 (§Contract, D5/D8/D10/D11): the program patch, create without a template,
/// one field's PATCH, the cover save, forgetting a program, and loading every lesson page.
@MainActor
final class ProgramActionsTests: XCTestCase {
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

    private var actions: ProgramActions { ProgramActions(api: api, state: state) }

    private func json(_ patch: ProgramPatch) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: patch.body, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func programJSON(_ extra: String = "") -> String {
        #"{"id":"p1","title":"Walk","createdAt":"2026-10-28T00:00:00Z","updatedAt":"2026-10-28T00:00:00Z""# + extra + "}"
    }

    // MARK: - ProgramPatch (D10)

    func testEachPatchEncodesOneKeyWithExplicitNulls() throws {
        XCTAssertEqual(try json(.name("Walk")), #"{"name":"Walk"}"#)
        XCTAssertEqual(try json(.description(nil)), #"{"description":null}"#)
        XCTAssertEqual(try json(.description("Daily")), #"{"description":"Daily"}"#)
        XCTAssertEqual(try json(.isPrivate(true)), #"{"isPrivate":true}"#)
        XCTAssertEqual(try json(.maxMembers(nil)), #"{"maxMembers":null}"#)
        XCTAssertEqual(try json(.maxMembers(40)), #"{"maxMembers":40}"#)
        XCTAssertEqual(try json(.memberDirectoryAccess("NAMES_ONLY")), #"{"memberDirectoryAccess":"NAMES_ONLY"}"#)
        XCTAssertEqual(try json(.leaderId(nil)), #"{"leaderId":null}"#)
        XCTAssertEqual(try json(.leaderId("u2")), #"{"leaderId":"u2"}"#)
    }

    func testAgeRangeIsNestedWithNullBounds() throws {
        XCTAssertEqual(try json(.ageRange(nil)), #"{"ageRange":null}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 18, max: nil))), #"{"ageRange":{"max":null,"min":18}}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 18, max: 35))), #"{"ageRange":{"max":35,"min":18}}"#)
    }

    // MARK: - Create (D8)

    func testCreateSendsOnlyTheNameAndStoresTheProgram() async throws {
        api.stub("POST", "/api/programs", json: #"{"success":true,"program":"# + programJSON(#","days":0,"creatorName":"Luke","leaderName":"Luke""#) + "}")
        let program = try await actions.createProgram(name: "Walk")
        XCTAssertEqual(api.calls.last?.body?.count, 1)
        XCTAssertEqual(api.calls.last?.body?["name"] as? String, "Walk")
        XCTAssertEqual(program.leaderName, "Luke")
        XCTAssertEqual(state.programs["p1"]?.name, "Walk")
    }

    // MARK: - Update (D10)

    func testUpdateSendsThePatchAndStoresTheResponse() async throws {
        state.programs.upsert(StudyProgram(id: "p1", name: "Walk", maxMembers: 10))
        api.stub("PATCH", "/api/programs/p1", json: #"{"success":true,"program":"# + programJSON(#","maxMembers":null,"leaderName":"Nathan""#) + "}")
        let program = try await actions.updateProgram(id: "p1", patch: .maxMembers(nil))
        XCTAssertEqual(api.calls.last?.method, "PATCH")
        XCTAssertEqual(api.calls.last?.body?.count, 1)
        XCTAssertTrue(api.calls.last?.body?["maxMembers"] is NSNull)
        XCTAssertNil(program.maxMembers)
        XCTAssertNil(state.programs["p1"]?.maxMembers)
        XCTAssertEqual(state.programs["p1"]?.leaderName, "Nathan")
    }

    // MARK: - Cover (D11)

    private func image() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
    }

    func testSaveCoverSendsFramingAndOriginalAndPatchesTheProgram() async throws {
        state.programs.upsert(StudyProgram(id: "p1", name: "Walk", coverImageUrl: "https://img/old.jpeg"))
        api.stub("POST", "/api/programs/p1/cover-image", json: #"{"success":true,"coverImageUrl":"https://img/new.jpeg","coverOriginalUrl":"https://img/o.jpeg","coverFraming":{"scale":2,"rotation":0,"offsetX":0,"offsetY":0}}"#)
        let framing = ImageFraming(scale: 2, rotation: 0, offsetX: 0, offsetY: 0)
        let result = try await actions.saveCover(programId: "p1", rendered: image(), framing: framing, original: image())
        let body = try XCTUnwrap(api.calls.last?.body)
        XCTAssertFalse((body["imageData"] as? String ?? "").isEmpty)
        XCTAssertFalse((body["originalData"] as? String ?? "").isEmpty)
        XCTAssertEqual((body["framing"] as? [String: Any])?["scale"] as? Double, 2)
        XCTAssertEqual(result.coverImageUrl, "https://img/new.jpeg")
        XCTAssertEqual(state.programs["p1"]?.coverImageUrl, "https://img/new.jpeg")
        XCTAssertEqual(state.programs["p1"]?.coverOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(state.programs["p1"]?.coverFraming, framing)
    }

    func testReEditSendsNoOriginal() async throws {
        state.programs.upsert(StudyProgram(id: "p1", name: "Walk"))
        api.stub("POST", "/api/programs/p1/cover-image", json: #"{"success":true,"coverImageUrl":"https://img/new.jpeg"}"#)
        _ = try await actions.saveCover(programId: "p1", rendered: image(), framing: .identity, original: nil)
        XCTAssertNil(api.calls.last?.body?["originalData"])
    }

    // MARK: - Forget (D5)

    func testForgetClearsTheProgramItsLessonsAndItsEnrollmentsIndex() {
        state.programs.upsert(StudyProgram(id: "p1", name: "Walk"))
        state.programLessonIndex.add(parentId: "p1", childId: "l1")
        state.lessonActivityIndex.add(parentId: "l1", childId: "a1")
        state.programEnrollmentIndex.add(parentId: "p1", childId: "e1")
        actions.forgetProgram(id: "p1")
        XCTAssertNil(state.programs["p1"])
        XCTAssertTrue(state.programLessonIndex.get("p1").isEmpty)
        XCTAssertTrue(state.lessonActivityIndex.get("l1").isEmpty)
        XCTAssertTrue(state.programEnrollmentIndex.get("p1").isEmpty)
    }

    func testForgetClearsTheProgramPagesEnrollments() throws {
        let json = #"{"id":"pe1","groupId":"g1","studyProgramId":"p1","startDate":"2026-10-01T00:00:00Z","endDate":"2026-11-01T00:00:00Z"}"#
        state.programEnrollments.upsert(try JSONDecoder.apiDecoder.decode(ProgramEnrollment.self, from: Data(json.utf8)))
        state.programProgramEnrollmentIndex.add(parentId: "p1", childId: "pe1")
        actions.forgetProgram(id: "p1")
        XCTAssertTrue(state.programEnrollmentsFor(programId: "p1").isEmpty)
        XCTAssertNil(state.programEnrollments["pe1"])
    }

    // MARK: - Every lesson page (D5)

    private func lessonJSON(_ id: String, day: Int) -> String {
        #"{"id":"\#(id)","programId":"p1","dayNumber":\#(day),"title":"Day \#(day)","activities":[],"createdAt":"2026-10-28T00:00:00Z","updatedAt":"2026-10-28T00:00:00Z"}"#
    }

    func testLoadProgramPagesByHasMoreAndReplacesTheLessonIndex() async throws {
        state.programLessonIndex.add(parentId: "p1", childId: "gone")
        api.stub("GET", "/api/programs/p1?lessonPage=1&lessonLimit=60",
                 json: #"{"success":true,"program":"# + programJSON(#","lessons":["# + lessonJSON("l1", day: 1) + "]") +
                       #","pagination":{"page":1,"limit":60,"totalLessons":2,"totalPages":2,"hasMore":true}}"#)
        api.stub("GET", "/api/programs/p1?lessonPage=2&lessonLimit=60",
                 json: #"{"success":true,"program":"# + programJSON(#","lessons":["# + lessonJSON("l2", day: 2) + "]") +
                       #","pagination":{"page":2,"limit":60,"totalLessons":2,"totalPages":2,"hasMore":false}}"#)
        try await actions.loadProgram(id: "p1")
        XCTAssertEqual(state.programLessonIndex.get("p1").sorted(), ["l1", "l2"])
        XCTAssertNotNil(state.lessons["l2"])
    }

    func testLoadProgramKeepsA404sStatus() async {
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/programs/p1") ? APIHTTPError(status: 404, message: nil) : nil }
        do {
            try await actions.loadProgram(id: "p1")
            XCTFail("expected a 404")
        } catch let error as APIHTTPError {
            XCTAssertEqual(error.status, 404)
        } catch {
            XCTFail("expected APIHTTPError, got \(error)")
        }
    }

    // MARK: - List (D15)

    func testTheListKeepsTheNewFields() async throws {
        api.stub("GET", "/api/programs", json: #"{"success":true,"programs":["# + programJSON(#","leaderName":"Nathan","isPrivate":true,"organizationName":"Grace""#) + "]}")
        try await actions.loadPrograms(forceRefresh: true)
        XCTAssertEqual(state.programs["p1"]?.leaderName, "Nathan")
        XCTAssertEqual(state.programs["p1"]?.isPrivate, true)
        XCTAssertEqual(state.programs["p1"]?.organizationName, "Grace")
    }
}
