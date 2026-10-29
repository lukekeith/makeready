import XCTest
@testable import MakeReady

/// ui2-groups-browse D4, D5, D12, D13/D21, D16–D18: the group page from the group stores.
final class GroupDetailMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!    // Sun Oct 25, 12:00 local

    private func iso(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func group(ageRange: AgeRange? = nil, maxMembers: Int? = nil, isPrivate: Bool = false,
                       access: String? = "ALLOWED", memberDirectory: Bool = true) -> UserGroup {
        UserGroup(id: "g1", code: "ABC123", name: "Young Professionals", description: "Weeknights downtown",
                  coverImageUrl: "https://img/g1.jpg", isPrivate: isPrivate, allowInvites: true,
                  memberDirectory: memberDirectory, ageRange: ageRange, maxMembers: maxMembers, memberCount: 2,
                  creatorId: "u1", creatorName: "Luke Keith", memberDirectoryAccess: access,
                  createdAt: iso("2025-01-15T10:30:00Z"), updatedAt: iso("2025-01-15T10:30:00Z"))
    }

    private func output(_ input: GroupDetailMapper.Input) -> GroupDetailMapper.Output {
        GroupDetailMapper.output(input, now: now, timeZone: tz)
    }

    // MARK: - D5 stats + settings

    func testCoreFieldsAndStats() {
        let s = output(.init(name: "Pushed", group: group())).state
        XCTAssertEqual(s.groupName, "Young Professionals")
        XCTAssertEqual(s.coverURL, "https://img/g1.jpg")
        XCTAssertEqual(s.leaderName, "Luke Keith")                       // D5: creatorName, full
        XCTAssertEqual(s.createdLabel, "Jan 15, 2025")
        XCTAssertEqual(s.groupDescription, "Weeknights downtown")
        XCTAssertEqual(s.visibility, "Public")
        XCTAssertEqual(s.ageRange, "Any age")
        XCTAssertEqual(s.maximumMembers, "Unlimited")
        XCTAssertEqual(s.memberDirectoryAccess, "Allowed")
    }

    /// D4: the push renders at once under the row's name; every section empty until it loads.
    func testUnloadedGroupKeepsThePushedNameAndEmptySections() {
        let s = output(.init(name: "Prayer Team")).state
        XCTAssertEqual(s.groupName, "Prayer Team")
        XCTAssertEqual([s.leaderName, s.createdLabel, s.visibility, s.ageRange, s.maximumMembers, s.memberDirectoryAccess],
                       ["", "", "", "", "", ""])
        XCTAssertEqual(s.lessonTitles, [])
        XCTAssertEqual(s.memberNames, [])
        XCTAssertEqual(s.requestNames, [])
        XCTAssertEqual(s.programTitles, [])
        XCTAssertEqual(s.eventTexts, [])
        XCTAssertEqual(s.chartDates, [])                                 // C-026's empty state
        XCTAssertEqual(s.dayNumbers.count, 30)                           // C-071 `Nothing` cards
    }

    func testEveryAgeForm() {
        XCTAssertEqual(GroupDetailMapper.ageLabel(nil), "Any age")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: nil, max: nil)), "Any age")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: 18, max: 30)), "18 - 30")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: 18, max: nil)), "18+")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: nil, max: 30)), "Up to 30")
    }

    func testVisibilityAndMaxMembers() {
        XCTAssertEqual(GroupDetailMapper.visibilityLabel(true), "Private")
        XCTAssertEqual(GroupDetailMapper.visibilityLabel(false), "Public")
        XCTAssertEqual(GroupDetailMapper.maxMembersLabel(nil), "Unlimited")
        XCTAssertEqual(GroupDetailMapper.maxMembersLabel(50), "50")
        XCTAssertEqual(output(.init(name: "x", group: group(isPrivate: true))).state.visibility, "Private")
    }

    /// D5/D11: the three-state enum; an old server (nil) or an unknown value falls back to the Boolean.
    func testDirectoryAccessLabels() {
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("ALLOWED", memberDirectory: false), "Allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("NAMES_ONLY", memberDirectory: true), "Names only")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("NOT_ALLOWED", memberDirectory: true), "Not allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel(nil, memberDirectory: true), "Allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel(nil, memberDirectory: false), "Not allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("SOMETHING_NEW", memberDirectory: false), "Not allowed")
    }

    // MARK: - D12 rail

    func testRailIsThirtyDaysWithTodayTrailing() {
        let r = GroupDetailMapper.rail(days: nil, chart: nil, now: now, timeZone: tz)
        XCTAssertEqual(r.numbers.count, 30)
        XCTAssertEqual(r.numbers.first, "26")
        XCTAssertEqual(r.months.first, "SEP")
        XCTAssertEqual(r.weekdays.first, "SAT")                          // Sep 26 2026
        XCTAssertEqual(r.weekdays.last, "")                              // today shows no weekday
        XCTAssertEqual(r.dateStates.last, "today")
        XCTAssertEqual(r.dateStates.first, "default")
        XCTAssertEqual(Set(r.line1s), ["0 lessons"])
        XCTAssertEqual(Set(r.line2s), [""])
        XCTAssertEqual(Set(r.detailsStates), ["nothing"])
        XCTAssertEqual(r.series.first, Array(repeating: 0, count: 12))
    }

    func testRailLinesFromTheChartAndSeriesFromSessions() {
        let chart = GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2], completed: ["2026-10-25": 1, "2026-10-24": 2])
        let days = [HomeDay(day: "2026-10-23", sessionSeconds: 600, blocks: [0, 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 0])]
        let r = GroupDetailMapper.rail(days: days, chart: chart, now: now, timeZone: tz)
        XCTAssertEqual([r.line1s[29], r.line2s[29], r.detailsStates[29]], ["3 lessons", "2 left", "default"])     // today
        XCTAssertEqual([r.line1s[28], r.line2s[28], r.detailsStates[28]], ["2 lessons", "2 complete", "default"])
        XCTAssertEqual([r.line1s[27], r.line2s[27], r.detailsStates[27]], ["0 lessons", "", "default"])           // sessions only
        XCTAssertEqual(r.series[27], [0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(r.detailsStates[26], "nothing")
    }

    /// D12: today says "«N−C» left" while lessons remain, else "«C» complete"; no lessons → empty.
    func testLine2Rules() {
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 3, completed: 1, isToday: true), "2 left")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 2, completed: 2, isToday: true), "2 complete")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 3, completed: 1, isToday: false), "1 complete")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 0, completed: 0, isToday: true), "")
    }

    // MARK: - D13/D21 chart

    func testChartZeroFillsTheLoadedRangeAndOpensOnTheDesignedWindow() {
        let chart = GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2], completed: ["2026-10-25": 1])
        let c = GroupDetailMapper.chart(chart, now: now, timeZone: tz)
        XCTAssertEqual(c.dates.count, 33)                                // today−29 … today+3
        XCTAssertEqual(c.dates.first, "2026-09-26")
        XCTAssertEqual(c.dates.last, "2026-10-28")
        XCTAssertEqual(c.today, "2026-10-25")
        XCTAssertEqual(c.windowStart, "2026-10-02")                      // today−23
        XCTAssertEqual(c.windowEnd, "2026-10-28")                        // today+3
        let todayIndex = c.dates.firstIndex(of: "2026-10-25")!
        XCTAssertEqual(c.scheduled[todayIndex], 3)
        XCTAssertEqual(c.completed[todayIndex], 1)
        XCTAssertEqual(c.scheduled.reduce(0, +), 5)
        XCTAssertEqual(c.completed[todayIndex + 1], 0)
    }

    func testUnloadedChartIsEmpty() {
        let c = GroupDetailMapper.chart(nil, now: now, timeZone: tz)
        XCTAssertEqual(c.dates, [])
        XCTAssertEqual(c.today, "2026-10-25")
    }

    // MARK: - D16 dates

    func testDateLabels() {
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T17:30:00Z"), now: now, timeZone: tz), "Just now")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T15:00:00Z"), now: now, timeZone: tz), "Today")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-24T20:00:00Z"), now: now, timeZone: tz), "Yesterday")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T05:00:00Z"), now: now, timeZone: tz), "Yesterday")  // Oct 24, 23:00 local
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-03-04T12:00:00Z"), now: now, timeZone: tz), "Mar 4")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2025-12-31T12:00:00Z"), now: now, timeZone: tz), "Dec 31, 2025")
    }

    // MARK: - D17 next lesson

    /// D17: the scheduled date's UTC calendar date against the phone's local today.
    func testLessonMetaLabels() {
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-25T00:00:00.000Z", now: now, timeZone: tz), "Today")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-26T00:00:00.000Z", now: now, timeZone: tz), "Tomorrow")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-29T00:00:00.000Z", now: now, timeZone: tz), "Thursday")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-31T00:00:00.000Z", now: now, timeZone: tz), "Saturday")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-11-01T00:00:00.000Z", now: now, timeZone: tz), "Nov 1")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("not a date", now: now, timeZone: tz), "")
    }

    func testNextLessonCard() {
        let activities = [
            NextStudyActivity(id: "a1", type: "VIDEO", orderNumber: 1, title: "Watch", thumbnailUrl: "https://img/a1.jpg"),
            NextStudyActivity(id: "a2", type: "READ", orderNumber: 2, title: "Read", thumbnailUrl: nil),
            NextStudyActivity(id: "a3", type: "READ", orderNumber: 3, title: nil, thumbnailUrl: "https://img/a3.jpg"),
            NextStudyActivity(id: "a4", type: "VIDEO", orderNumber: 4, title: "Fourth", thumbnailUrl: "https://img/a4.jpg")
        ]
        var study = NextStudy(id: "s1", dayNumber: 3, scheduledDate: "2026-10-26T00:00:00.000Z", title: nil,
                              studyProgram: NextStudyProgram(id: "p1", name: "Faith over fear"), activities: activities)
        var s = output(.init(name: "x", nextStudy: study)).state
        XCTAssertEqual(s.lessonTitles, ["Day 3"])
        XCTAssertEqual(s.lessonProgramNames, ["Faith over fear"])
        XCTAssertEqual(s.lessonMetaLabels, ["Tomorrow"])
        XCTAssertEqual(s.lessonSlideImages, [["https://img/a1.jpg", "", "https://img/a3.jpg"]])
        XCTAssertEqual(s.lessonSlideLabels, [["Watch", "Read", ""]])
        study.title = "Week one"
        s = output(.init(name: "x", nextStudy: study)).state
        XCTAssertEqual(s.lessonTitles, ["Week one"])
    }

    // MARK: - D18 members, requests, enrollments

    func testMembersNewestFirstWithJoinedLabels() {
        let ann = GroupMember(id: "gm1", userId: "u-a", groupId: "g1", role: .member, name: "Ann Lee", avatarUrl: nil,
                              joinedAt: iso("2026-10-20T15:00:00Z"))
        let bob = GroupMember(id: "gm2", userId: "u-b", groupId: "g1", role: .member, name: "Bob Ray",
                              avatarUrl: "https://img/b.jpg", joinedAt: iso("2026-10-25T15:00:00Z"))
        let out = output(.init(name: "x", members: [ann, bob]))
        XCTAssertEqual(out.state.memberNames, ["Bob Ray", "Ann Lee"])
        XCTAssertEqual(out.state.memberJoinedLabels, ["Joined Today", "Joined 5 days ago"])
        XCTAssertEqual(out.state.memberPhotoURLs, ["https://img/b.jpg", ""])
        XCTAssertEqual(out.member(atRow: 0), GroupDetailMapper.MemberRow(id: "u-b", name: "Bob Ray"))   // D7: userId
        XCTAssertNil(out.member(atRow: 5))
    }

    func testRequestsNameOrUnknownAndDateAndAreNotMembers() {
        let tony = JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: iso("2026-10-24T20:00:00Z"),
                               member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: "Stark", avatarUrl: nil))
        let nameless = JoinRequest(id: "r2", status: "PENDING", message: nil, createdAt: iso("2026-03-04T12:00:00Z"),
                                   member: JoinRequestMember(id: "m2", firstName: nil, lastName: nil, avatarUrl: nil))
        let s = output(.init(name: "x", requests: [tony, nameless])).state
        XCTAssertEqual(s.requestNames, ["Tony Stark", "Unknown"])
        XCTAssertEqual(s.requestDates, ["Yesterday", "Mar 4"])
        XCTAssertEqual(s.memberNames, [])                                // not counted in "«N» members"
    }

    func testEnrollmentsNewestFirst() throws {
        let json = #"""
        [{"id":"e1","groupId":"g1","programId":"p1","startedAt":"2026-09-01T00:00:00Z","createdAt":"2026-09-01T15:00:00Z",
          "studyProgram":{"id":"p1","title":"Faith over fear","description":"30 days","coverImageUrl":"https://img/p1.jpg"}},
         {"id":"e2","groupId":"g1","programId":"p2","startedAt":"2026-10-01T00:00:00Z","createdAt":"2026-10-01T15:00:00Z",
          "studyProgram":{"id":"p2","title":"Daily Inspiration"}}]
        """#
        let enrollments = try JSONDecoder.apiDecoder.decode([EnrollmentWithProgram].self, from: Data(json.utf8))
        let s = output(.init(name: "x", enrollments: enrollments)).state
        XCTAssertEqual(s.programTitles, ["Daily Inspiration", "Faith over fear"])
        XCTAssertEqual(s.programDescriptions, ["", "30 days"])
        XCTAssertEqual(s.programEnrolledDates, ["Oct 1, 2026", "Sep 1, 2026"])
        XCTAssertEqual(s.programCoverURLs, ["", "https://img/p1.jpg"])
    }

    // MARK: - D16 timeline

    func testTimelineTextsHighlightsAndTones() {
        let events = [
            GroupHistoryEvent(id: "h1", occurredAt: "2026-10-25T17:30:00.000Z", kind: "member_joined",
                              text: "Tony Stark joined the group", highlight: "Tony Stark"),
            GroupHistoryEvent(id: "h2", occurredAt: "2025-12-31T12:00:00.000Z", kind: "settings_updated",
                              text: "Updated group settings", highlight: nil)
        ]
        let s = output(.init(name: "x", history: events)).state
        XCTAssertEqual(s.eventDates, ["Just now", "Dec 31, 2025"])
        XCTAssertEqual(s.eventTexts, ["Tony Stark joined the group", "Updated group settings"])
        XCTAssertEqual(s.eventHighlights, ["Tony Stark", ""])
        XCTAssertEqual(s.eventTones, ["accent", "neutral"])              // F8: renders plain until C-065 rebuild
    }

    // MARK: - ui2-enrollments-browse D7b/D14.2/D19/D28

    private func romans() throws -> StudyProgram {
        try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"p2","name":"Romans in 30 days","description":"A deep dive","days":30,"isPublished":true,"coverImageUrl":"https://x/p2.png","createdAt":"2025-01-01T00:00:00.000Z","updatedAt":"2025-01-01T00:00:00.000Z"}"#.utf8))
    }

    private func groupDraft(start: String? = nil, schedule: [String]? = nil, sms: String? = "07:30",
                            sync: String? = nil, access: String? = nil) -> DraftWire {
        DraftWire(id: "d1", groupId: "g1", studyProgramId: "p2", startDate: start,
                  enabledDays: schedule == nil ? nil : ["Mon"], overriddenDates: nil, scheduleDates: schedule,
                  smsTime: sms, timezone: sms == nil ? nil : "America/Denver", syncMode: sync, lessonAccess: access,
                  createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2026-10-20T00:00:00.000Z", updatedAt: "2026-10-21T00:00:00.000Z")
    }

    func testDraftRowsFollowTheEnrollmentsWithTheirMarkersAndTargets() throws {
        let json = #"[{"id":"e1","groupId":"g1","programId":"p1","startedAt":"2026-09-01T00:00:00Z","createdAt":"2026-09-01T15:00:00Z","studyProgram":{"id":"p1","title":"Faith over fear","description":"30 days","coverImageUrl":"https://img/p1.jpg"}}]"#
        let enrollments = try JSONDecoder.apiDecoder.decode([EnrollmentWithProgram].self, from: Data(json.utf8))
        let draft = groupDraft()
        let o = output(.init(name: "x", group: group(), enrollments: enrollments, drafts: [draft], programsById: ["p2": try romans()]))
        let s = o.state
        XCTAssertEqual(s.programTitles, ["Faith over fear", "Romans in 30 days"])
        XCTAssertEqual(s.programDescriptions, ["30 days", ""])
        XCTAssertEqual(s.programEnrolledDates, ["Sep 1, 2026", ""])
        XCTAssertEqual(s.programCoverURLs, ["https://img/p1.jpg", "https://x/p2.png"])
        XCTAssertEqual(s.programDraftLabels, ["", "Draft · 3/6"])                   // group, program, invite time
        XCTAssertEqual(s.programDraftStarters, ["", "Started by Luke Keith"])
        XCTAssertEqual(o.enrollmentTarget(atRow: 0), .enrollment(id: "e1", name: "Faith over fear"))   // D28
        XCTAssertEqual(o.enrollmentTarget(atRow: 1), .draft(draft, groupName: "Young Professionals", programName: "Romans in 30 days"))                                    // D21
        XCTAssertNil(o.enrollmentTarget(atRow: 2))
    }

    func testTheGroupPagesCountEqualsTheChecklistsIncludingTheStaleRule() throws {   // D19 + D9
        let program = try romans()
        let stale = groupDraft(start: "2026-10-01", schedule: ["2026-10-01"], sync: "AUTO", access: "ALL_AT_ONCE")
        let s = output(.init(name: "x", group: group(), drafts: [stale], programsById: ["p2": program])).state
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var checklist = EnrollmentDraftMapping.draft(stale, flowId: UUID(), zone: tz)
        checklist.clearStaleStart(today: now, calendar: cal)
        let n = GroupsEnrollProgramScreen.completedSteps(EnrollChecklistMapper.state(checklist, group: group(), program: program, today: now))
        XCTAssertEqual(n, 5)
        XCTAssertEqual(s.programDraftLabels, ["Draft · \(n)/6"])
    }

    func testNoDraftsLeavesTheEnrollmentRowsUnmarked() throws {
        let s = output(.init(name: "x", group: group())).state
        XCTAssertEqual(s.programDraftLabels, [])
        XCTAssertEqual(s.programDraftStarters, [])
    }
}
