import XCTest
@testable import MakeReady

/// ui2-enrollment-create T8: draft → GroupsEnrollProgramScreen.State (design §3 rows), D10 preloads.
final class EnrollChecklistMapperTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }
    private func group(_ id: String, members: Int) throws -> UserGroup {
        try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(
            #"{"id":"\#(id)","code":"C1","name":"Young Professionals","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberCount":\#(members),"creatorId":"u1","creatorName":"Tony Stark","createdAt":"2025-01-03T12:00:00.000Z","updatedAt":"2025-01-03T12:00:00.000Z","coverImageUrl":"https://x/g.png"}"#.utf8))
    }
    private func program(_ id: String, days: Int, published: Bool) throws -> StudyProgram {
        try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"\#(id)","name":"Romans in 30 days","description":"A deep dive","days":\#(days),"isPublished":\#(published),"coverImageUrl":"https://x/p.png","createdAt":"2025-01-01T00:00:00.000Z","updatedAt":"2025-01-01T00:00:00.000Z"}"#.utf8))
    }

    func testEmptyDraftIsZeroOfSixAndDefaultsNeverCountAsDone() {
        let s = EnrollChecklistMapper.state(EnrollmentDraft(id: UUID()), group: nil, program: nil)
        XCTAssertEqual(s.phase, "checklist")
        XCTAssertEqual(s.groupName, "")
        XCTAssertEqual(s.programName, "")
        XCTAssertEqual(s.scheduleStartDay, "")
        XCTAssertEqual(s.smsTime, "")
        XCTAssertEqual(s.syncMode, "")
        XCTAssertEqual(s.lessonAccess, "")
    }

    func testGroupAndProgramRows() throws {
        var d = EnrollmentDraft(id: UUID()); d.groupId = "g1"; d.setProgram("p1")
        let s = EnrollChecklistMapper.state(d, group: try group("g1", members: 13), program: try program("p1", days: 30, published: true))
        XCTAssertEqual(s.groupName, "Young Professionals")
        XCTAssertEqual(s.groupInitials, "YP")
        XCTAssertEqual(s.groupImageURL, "https://x/g.png")
        XCTAssertEqual(s.groupActiveMembers, 13)
        XCTAssertTrue(s.groupCreatedOn.hasPrefix("January 3rd, 2025") || s.groupCreatedOn.hasPrefix("January 2nd, 2025")) // device zone
        XCTAssertEqual(s.programName, "Romans in 30 days")
        XCTAssertEqual(s.programDescription, "A deep dive")
    }

    func testScheduleRowAndTheRestWhenDone() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [5, 1, 3]
        d.scheduleDates = [day("2035-01-08"), day("2035-01-10")]; d.endDate = day("2035-10-18")
        d.smsTime = "07:30"; d.syncMode = "OFF"; d.lessonAccess = "one-at-a-time"
        let s = EnrollChecklistMapper.state(d, group: nil, program: nil, today: day("2035-01-08"))
        XCTAssertEqual(s.scheduleStartWeekday, "Monday")
        XCTAssertEqual(s.scheduleStartMonth, "January")
        XCTAssertEqual(s.scheduleStartDay, "8")
        XCTAssertTrue(s.scheduleStartToday)
        XCTAssertEqual(s.scheduleWeekdays, ["Monday", "Wednesday", "Friday"])
        XCTAssertEqual(s.scheduleEndDate, "October 18th, 2035")
        XCTAssertEqual(s.smsTime, "07:30")
        XCTAssertEqual(s.syncMode, "OFF")
        XCTAssertEqual(s.lessonAccess, "one-at-a-time")
    }

    func testScheduleNotDoneMapsEmptyEvenWithASeed() {
        var d = EnrollmentDraft(id: UUID()); d.startDate = day("2035-01-08"); d.enabledDays = [1]
        XCTAssertEqual(EnrollChecklistMapper.state(d, group: nil, program: nil).scheduleStartDay, "")
    }

    func testPhaseIsPassedThrough() {
        var d = EnrollmentDraft(id: UUID()); d.phase = .processing
        XCTAssertEqual(EnrollChecklistMapper.state(d, group: nil, program: nil).phase, "processing")
    }

    func testPreloadsPassOnlyWhenEligible() throws {   // D10 / design rule 1
        let groups = [try group("g1", members: 3), try group("g0", members: 0)]
        XCTAssertEqual(EnrollChecklistMapper.preloadedGroupId("g1", groups: groups), "g1")
        XCTAssertNil(EnrollChecklistMapper.preloadedGroupId("g0", groups: groups))
        XCTAssertNil(EnrollChecklistMapper.preloadedGroupId("gX", groups: groups))
        let programs = [try program("p1", days: 12, published: true), try program("p2", days: 0, published: true),
                        try program("p3", days: 5, published: false)]
        XCTAssertEqual(EnrollChecklistMapper.preloadedProgramId("p1", programs: programs), "p1")
        XCTAssertNil(EnrollChecklistMapper.preloadedProgramId("p2", programs: programs))
        XCTAssertNil(EnrollChecklistMapper.preloadedProgramId("p3", programs: programs))
    }

    func testLongDateOrdinals() {
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-01")), "January 1st, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-02")), "January 2nd, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-03")), "January 3rd, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-11")), "January 11th, 2035")
        XCTAssertEqual(EnrollChecklistMapper.longDate(day("2035-01-22")), "January 22nd, 2035")
    }
}
