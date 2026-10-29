import XCTest
@testable import MakeReady

/// ui2-enrollments-browse T7/F7: §Contract Draft ↔ the checklist's EnrollmentDraft, and the save bodies.
final class EnrollmentDraftWireTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!

    private func day(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    private let full = #"{"id":"d1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08","enabledDays":["Mon","Wed"],"overriddenDates":["2035-01-10"],"scheduleDates":["2035-01-08","2035-01-15","2035-01-17"],"smsTime":"07:30","timezone":"America/Chicago","syncMode":"AUTO","lessonAccess":"ONE_AT_A_TIME","createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-02T00:00:00.000Z"}"#
    private let bare = #"{"id":"d2","groupId":"g1","studyProgramId":"p1","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":null,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z"}"#

    private func decode(_ json: String) throws -> DraftWire {
        try JSONDecoder.apiDecoder.decode(DraftWire.self, from: Data(json.utf8))
    }

    func testAFullDraftMapsEveryField() throws {
        let id = UUID()
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: id, zone: zone)
        XCTAssertEqual(d.id, id)                                   // D21: the flow id stays local
        XCTAssertEqual(d.serverId, "d1")
        XCTAssertEqual(d.createdByName, "Luke Keith")
        XCTAssertEqual(d.serverUpdatedAt, "2035-01-02T00:00:00.000Z")
        XCTAssertEqual(d.groupId, "g1")
        XCTAssertEqual(d.studyProgramId, "p1")
        XCTAssertEqual(d.startDate, day("2035-01-08"))
        XCTAssertEqual(d.enabledDays, [1, 3])                      // Mon, Wed
        XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertEqual(d.scheduleDates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertEqual(d.smsTime, "07:30")
        XCTAssertEqual(d.timezone, "America/Chicago")
        XCTAssertEqual(d.syncMode, "AUTO")
        XCTAssertEqual(d.lessonAccess, "one-at-a-time")
        XCTAssertEqual(d.phase, .checklist)
    }

    func testNullsMapToNotChosen() throws {
        let d = EnrollmentDraftMapping.draft(try decode(bare), flowId: UUID(), zone: zone)
        XCTAssertNil(d.startDate)
        XCTAssertEqual(d.enabledDays, [])
        XCTAssertEqual(d.overriddenDates, [])
        XCTAssertEqual(d.scheduleDates, [])
        XCTAssertNil(d.endDate)
        XCTAssertNil(d.smsTime); XCTAssertNil(d.timezone); XCTAssertNil(d.syncMode); XCTAssertNil(d.lessonAccess)
        XCTAssertNil(d.createdByName)                               // F9: createdBy null → no starter
        XCTAssertFalse(d.scheduleDone)
    }

    func testEndDateIsDerivedFromTheLastScheduleDate() throws {  // F7
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        XCTAssertEqual(d.endDate, day("2035-01-17"))
    }

    func testCreateBodyRoundTripsTheWire() throws {
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        let body = EnrollmentDraftMapping.createBody(d, zone: zone)
        XCTAssertEqual(body["groupId"] as? String, "g1")
        XCTAssertEqual(body["studyProgramId"] as? String, "p1")
        XCTAssertEqual(body["startDate"] as? String, "2035-01-08")
        XCTAssertEqual(body["enabledDays"] as? [String], ["Mon", "Wed"])
        XCTAssertEqual(body["overriddenDates"] as? [String], ["2035-01-10"])
        XCTAssertEqual(body["scheduleDates"] as? [String], ["2035-01-08", "2035-01-15", "2035-01-17"])
        XCTAssertEqual(body["smsTime"] as? String, "07:30")
        XCTAssertEqual(body["timezone"] as? String, "America/Chicago")
        XCTAssertEqual(body["syncMode"] as? String, "AUTO")
        XCTAssertEqual(body["lessonAccess"] as? String, "ONE_AT_A_TIME")
        XCTAssertNil(body["endDate"])                               // F7: never on the wire
    }

    func testCreateBodyOmitsUnsetFields() {
        let body = EnrollmentDraftMapping.createBody(EnrollmentDraft(id: UUID(), groupId: "g1", studyProgramId: "p1"), zone: zone)
        XCTAssertEqual(Set(body.keys), ["groupId", "studyProgramId"])
    }

    func testPatchSendsOnlyChangedKeysWithExplicitNulls() throws {
        let base = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        var next = base
        next.smsTime = "08:00"
        next.syncMode = nil
        let body = EnrollmentDraftMapping.patchBody(from: base, to: next, zone: zone)
        XCTAssertEqual(Set(body.keys), ["smsTime", "syncMode"])
        XCTAssertEqual(body["smsTime"] as? String, "08:00")
        XCTAssertTrue(body["syncMode"] is NSNull)
        XCTAssertTrue(EnrollmentDraftMapping.patchBody(from: base, to: base, zone: zone).isEmpty)
    }

    func testAProgramChangeAlwaysSendsScheduleDatesNull() throws {   // D4 + D23
        let base = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        var next = base
        next.setProgram("p2")
        let body = EnrollmentDraftMapping.patchBody(from: base, to: next, zone: zone)
        XCTAssertEqual(body["studyProgramId"] as? String, "p2")
        XCTAssertTrue(body["scheduleDates"] is NSNull)
        XCTAssertNil(body["startDate"])                              // start / weekdays / overrides kept
        // D23: the local schedule was already cleared, the server's was not — still null.
        var cleared = base
        cleared.scheduleDates = []; cleared.startDate = nil; cleared.endDate = nil
        var moved = cleared
        moved.setProgram("p3")
        XCTAssertTrue(EnrollmentDraftMapping.patchBody(from: cleared, to: moved, zone: zone)["scheduleDates"] is NSNull)
    }

    func testStaleStartClearsOnlyTheSchedule() throws {               // D9
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        var d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        XCTAssertFalse(d.clearStaleStart(today: day("2035-01-08"), calendar: cal))   // first date is today: kept
        XCTAssertTrue(d.scheduleDone)
        XCTAssertTrue(d.clearStaleStart(today: day("2035-01-09"), calendar: cal))
        XCTAssertNil(d.startDate); XCTAssertEqual(d.scheduleDates, []); XCTAssertNil(d.endDate)
        XCTAssertEqual(d.enabledDays, [1, 3]); XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertEqual(d.smsTime, "07:30")
    }
}
