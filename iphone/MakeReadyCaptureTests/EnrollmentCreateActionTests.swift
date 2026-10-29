import XCTest
@testable import MakeReady

/// ui2-enrollment-create T9/T13: the POST body the 2.0 checklist sends, and the stores it refreshes.
@MainActor
final class EnrollmentCreateActionTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\",\"Wed\"]","smsTime":"07:30","timezone":"America/Chicago","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ONE_AT_A_TIME","syncMode":"OFF"}}"#

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

    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    func testWireHelpers() {
        XCTAssertEqual(EnrollmentWire.dayNames([3, 1, 0]), ["Sun", "Mon", "Wed"])
        XCTAssertEqual(EnrollmentWire.ymd(day("2035-01-08")), "2035-01-08")
        XCTAssertEqual(EnrollmentWire.lessonAccessWire("one-at-a-time"), "ONE_AT_A_TIME")
        XCTAssertEqual(EnrollmentWire.lessonAccessWire("all-at-once"), "ALL_AT_ONCE")
        XCTAssertNil(EnrollmentWire.lessonAccessWire(""))
    }

    func testBodyCarriesScheduleDatesLessonAccessSyncModeAndWeekdayNames() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/programs/") ? APIError.serverError("not stubbed") : nil }
        let e = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: EnrollmentWire.dayNames([1, 3]), smsTime: "07:30", timezone: "America/Chicago",
            syncMode: .off,
            scheduleDates: [day("2035-01-08"), day("2035-01-10"), day("2035-01-12")],
            lessonAccess: "ONE_AT_A_TIME")
        XCTAssertEqual(e.lessonAccess, "ONE_AT_A_TIME")
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["scheduleDates"] as? [String], ["2035-01-08", "2035-01-10", "2035-01-12"])
        XCTAssertEqual(body?["lessonAccess"] as? String, "ONE_AT_A_TIME")
        XCTAssertEqual(body?["syncMode"] as? String, "OFF")
        XCTAssertEqual(body?["enabledDays"] as? [String], ["Mon", "Wed"])
        XCTAssertEqual(body?["smsTime"] as? String, "07:30")
        XCTAssertEqual(body?["timezone"] as? String, "America/Chicago")
    }

    func testOmitsTheNewKeysWhenNotGiven() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        _ = try? await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertNil(body?["scheduleDates"])
        XCTAssertNil(body?["lessonAccess"])
    }

    func testRefreshesTheGroupsEnrollmentsAndClearsNextStudyAfterCreate() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        api.stub("GET", "/api/programs/p1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s-old")
        _ = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/enrollments"), 1)
        XCTAssertEqual(api.callCount("GET", "/api/programs/p1/enrollments"), 1)
        XCTAssertNil(state.nextStudyByGroupId["g1"])
    }

    func testARefreshFailureDoesNotFailTheCreate() async throws {
        api.stub("POST", "/api/enrollments", json: created)
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/groups/") || endpoint.hasPrefix("/api/programs/") ? APIError.serverError("down") : nil }
        let e = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: day("2035-01-08"),
            enabledDays: ["Mon"], smsTime: nil, timezone: nil)
        XCTAssertEqual(e.id, "e9")
        XCTAssertNil(state.activeSurfacedError)
    }
}
