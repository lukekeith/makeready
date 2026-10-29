import XCTest
@testable import MakeReady

/// ui2-enrollment-create D5/D17/D19 (program picker) and T8 (schedule seed + Select).
@MainActor
final class EnrollPickerMapperTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }
    private func program(_ id: String, _ name: String, days: Int, published: Bool = true, leader: String? = nil,
                         creator: String = "u1", completed: Int? = nil) throws -> StudyProgram {
        let leaderJSON = leader.map { #","leaderId":"\#($0)""# } ?? ""
        let completedJSON = completed.map { #","completedEnrollmentCount":\#($0)"# } ?? ""
        return try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"\#(id)","name":"\#(name)","days":\#(days),"isPublished":\#(published),"creatorId":"\#(creator)","createdAt":"2025-03-15T12:00:00.000Z","updatedAt":"2025-03-15T12:00:00.000Z"\#(leaderJSON)\#(completedJSON)}"#.utf8))
    }
    private func input(_ programs: [StudyProgram], group: [EnrollmentWithProgram]? = nil, leaderIds: Set<String> = [],
                       selectedId: String? = nil) -> EnrollSelectProgramMapper.Input {
        .init(programs: programs, query: "", leaderIds: leaderIds, leaders: [], draftGroupEnrollments: group,
              selectedId: selectedId, loading: false, today: day("2035-01-08"))
    }

    func testProgramPickerListsOnlyPublishedProgramsWithLessonsAToZ() throws {
        let out = EnrollSelectProgramMapper.output(input([
            try program("p2", "Zeal", days: 5), try program("p1", "Acts", days: 3),
            try program("p3", "Draft", days: 5, published: false), try program("p4", "Empty", days: 0),
        ]))
        XCTAssertEqual(out.programIds, ["p1", "p2"])
        XCTAssertEqual(out.state.programTitles, ["Acts", "Zeal"])
        XCTAssertEqual(out.state.programDayCounts, [3, 5])
        XCTAssertEqual(out.state.programCreatedLabels, ["Mar 2025", "Mar 2025"])
        XCTAssertFalse(out.state.orgFilterVisible)                       // D19
        XCTAssertEqual(out.state.selectedIndex, -1)
    }

    func testCompletedCountIsTheServersWithNoGroupAndTheGroupsOwnWithOne() throws {   // D17
        let p = try program("p1", "Acts", days: 3, completed: 7)
        XCTAssertEqual(EnrollSelectProgramMapper.output(input([p])).state.programCompletedCounts, [7])
        let ended = EnrollmentWithProgram(id: "e1", groupId: "g", studyProgramId: "p1", startDate: day("2034-12-01"), endDate: day("2035-01-01"))
        let running = EnrollmentWithProgram(id: "e2", groupId: "g", studyProgramId: "p1", startDate: day("2035-01-01"), endDate: day("2035-02-01"))
        let other = EnrollmentWithProgram(id: "e3", groupId: "g", studyProgramId: "pX", startDate: day("2034-12-01"), endDate: day("2035-01-01"))
        XCTAssertEqual(EnrollSelectProgramMapper.output(input([p], group: [ended, running, other])).state.programCompletedCounts, [1])
    }

    func testLeadersFilterOnLeaderElseCreatorAndSelectedId() throws {   // D19
        let ps = [try program("p1", "Acts", days: 3, leader: "l1"), try program("p2", "Zeal", days: 5, creator: "l2")]
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, leaderIds: ["l2"])).programIds, ["p2"])
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, selectedId: "p2")).state.selectedIndex, 1)
    }

    func testProgramsTheGroupIsCurrentlyEnrolledInAreUnavailable() throws {   // enroll-picker-hide-enrolled D1/D2
        let ps = [try program("p1", "Acts", days: 3), try program("p2", "Mark", days: 3), try program("p3", "Zeal", days: 3)]
        let now = Date()
        let active = EnrollmentWithProgram(id: "e1", groupId: "g", studyProgramId: "p1", startDate: now.addingTimeInterval(-86_400), endDate: now.addingTimeInterval(86_400))
        let upcoming = EnrollmentWithProgram(id: "e2", groupId: "g", studyProgramId: "p2", startDate: now.addingTimeInterval(86_400), endDate: now.addingTimeInterval(9 * 86_400))
        let ended = EnrollmentWithProgram(id: "e3", groupId: "g", studyProgramId: "p3", startDate: now.addingTimeInterval(-9 * 86_400), endDate: now.addingTimeInterval(-86_400))
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, group: [active, upcoming, ended])).state.programUnavailable, [true, true, false])
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps)).state.programUnavailable, [false, false, false])
        // D2: the draft's own pick is never muted against itself.
        XCTAssertEqual(EnrollSelectProgramMapper.output(input(ps, group: [active], selectedId: "p1")).state.programUnavailable, [false, false, false])
    }

    func testGroupPickerMutesTheUnavailableIdsButNotThePick() {   // enroll-picker-hide-enrolled D1/D2
        func group(_ id: String, _ name: String) -> UserGroup {
            UserGroup(id: id, code: "C\(id)", name: name, isPrivate: false, allowInvites: false, memberCount: 1,
                      creatorId: "u-\(id)", createdAt: Date(), updatedAt: Date())
        }
        var input = InviteSelectGroupMapper.Input(groups: [group("a", "Alpha"), group("b", "Bravo")], enrollmentCounts: [:],
                                                  query: "", leaderIds: [], loading: false, failed: false, eligibleOnly: true)
        XCTAssertEqual(InviteSelectGroupMapper.output(input).state.groupUnavailable, [false, false])
        input.unavailableIds = ["b"]
        XCTAssertEqual(InviteSelectGroupMapper.output(input).state.groupUnavailable, [false, true])
        input.selectedId = "b"
        XCTAssertEqual(InviteSelectGroupMapper.output(input).state.groupUnavailable, [false, false])
    }

    func testScheduleSeedFromTheDraft() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [1, 3]; d.overriddenDates = [day("2035-01-10")]
        let s = EnrollSelectScheduleMapper.state(draft: d, lessonCount: 3, existingLessonDates: [day("2035-01-15")], today: day("2035-01-07"))
        XCTAssertTrue(s.programChosen)
        XCTAssertEqual(s.lessonCount, 3)
        XCTAssertEqual(s.today, "2035-01-07")
        XCTAssertEqual(s.startDate, "2035-01-08")
        XCTAssertEqual(s.enabledDays, [1, 3])
        XCTAssertEqual(s.overriddenDates, ["2035-01-10"])
        XCTAssertEqual(s.existingLessonDates, ["2035-01-15"])
        XCTAssertEqual(s.prompt, "none")
        let none = EnrollSelectScheduleMapper.state(draft: EnrollmentDraft(id: UUID()), lessonCount: 0, existingLessonDates: [], today: day("2035-01-07"))
        XCTAssertFalse(none.programChosen)
        XCTAssertEqual(none.startDate, "")
        XCTAssertEqual(none.enabledDays, [])
    }

    func testApplyWritesTheExactDatesOrRefusesAShortList() {
        var d = EnrollmentDraft(id: UUID()); d.setProgram("p1")
        XCTAssertTrue(EnrollSelectScheduleMapper.apply(start: day("2035-01-08"), end: day("2035-01-17"), days: [1, 3],
                                                       overrides: [day("2035-01-10")], lessonCount: 3, to: &d))
        XCTAssertEqual(d.scheduleDates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertEqual(d.endDate, day("2035-01-17"))
        XCTAssertTrue(d.scheduleDone)
        var e = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollSelectScheduleMapper.apply(start: day("2035-01-08"), end: day("2035-01-08"), days: [], overrides: [], lessonCount: 3, to: &e))
        XCTAssertFalse(e.scheduleDone)
    }

    /// A4: the rule's own count guard — Mondays only, one lesson, the first two Mondays switched
    /// off → short of the lesson count, so Select is refused and the draft keeps what it had.
    func testApplyRefusesWhenOverridesExhaustTheIterationCap() {
        var d = EnrollmentDraft(id: UUID(), studyProgramId: "p1")
        let before = d
        // 2035-01-08 is a Monday; the next is 2035-01-15.
        XCTAssertFalse(EnrollSelectScheduleMapper.apply(start: day("2035-01-08"), end: day("2035-01-15"), days: [1],
                                                        overrides: [day("2035-01-08"), day("2035-01-15")], lessonCount: 1, to: &d))
        XCTAssertEqual(d, before)
    }

    // Final review I-1: the pickers re-key the d2m screen only on what typing cannot change, so the
    // search field keeps its focus; Select resolves through the tracked pick.
    func testGroupScreenKeyIgnoresTheQueryButFollowsTheSourceRowsAndFilters() {
        func group(_ id: String, _ name: String) -> UserGroup {
            UserGroup(id: id, code: "C\(id)", name: name, isPrivate: false, allowInvites: false, memberCount: 1,
                      creatorId: "u-\(id)", createdAt: Date(), updatedAt: Date())
        }
        let base = InviteSelectGroupMapper.Input(groups: [group("a", "Alpha"), group("b", "Bravo")], enrollmentCounts: [:],
                                                 query: "", leaderIds: [], loading: false, failed: false, eligibleOnly: true)
        var typed = base; typed.query = "Br"
        XCTAssertNotEqual(InviteSelectGroupMapper.output(base).groupIds, InviteSelectGroupMapper.output(typed).groupIds)
        XCTAssertEqual(InviteSelectGroupMapper.screenKey(base), InviteSelectGroupMapper.screenKey(typed))
        var loaded = base; loaded.groups.append(group("c", "Charlie"))
        XCTAssertNotEqual(InviteSelectGroupMapper.screenKey(base), InviteSelectGroupMapper.screenKey(loaded))
        var byLeader = base; byLeader.leaderIds = ["u-a"]
        XCTAssertNotEqual(InviteSelectGroupMapper.screenKey(base), InviteSelectGroupMapper.screenKey(byLeader))
        var byOrg = base; byOrg.pickedOrgIds = ["o1"]
        XCTAssertNotEqual(InviteSelectGroupMapper.screenKey(base), InviteSelectGroupMapper.screenKey(byOrg))
    }

    func testProgramScreenKeyIgnoresTheQueryButFollowsTheSourceRowsAndFilters() throws {
        let base = input([try program("p1", "Acts", days: 3), try program("p2", "Zeal", days: 5)])
        var typed = base; typed.query = "Ze"
        XCTAssertNotEqual(EnrollSelectProgramMapper.output(base).programIds, EnrollSelectProgramMapper.output(typed).programIds)
        XCTAssertEqual(EnrollSelectProgramMapper.screenKey(base), EnrollSelectProgramMapper.screenKey(typed))
        var loaded = base; loaded.programs.append(try program("p3", "Mark", days: 2))
        XCTAssertNotEqual(EnrollSelectProgramMapper.screenKey(base), EnrollSelectProgramMapper.screenKey(loaded))
        var byLeader = base; byLeader.leaderIds = ["u1"]
        XCTAssertNotEqual(EnrollSelectProgramMapper.screenKey(base), EnrollSelectProgramMapper.screenKey(byLeader))
    }

    func testSelectCommitsTheTrackedPickWhileListedElseTheRowAtTheIndex() {
        // Picked "b" at index 1, then a query moved it to index 0: the stale index names "c".
        XCTAssertEqual(EnrollPickerSelection.committedId(index: 1, rowIds: ["b", "c"], trackedId: "b"), "b")
        // The pick is filtered out: the row the screen highlights is the one Select names.
        XCTAssertEqual(EnrollPickerSelection.committedId(index: 1, rowIds: ["c", "d"], trackedId: "b"), "d")
        XCTAssertEqual(EnrollPickerSelection.committedId(index: 0, rowIds: ["c"], trackedId: nil), "c")
        XCTAssertNil(EnrollPickerSelection.committedId(index: 2, rowIds: ["c"], trackedId: nil))
    }

    func testSelectCommitsAPickTheQueryFilteredOutOfView() {
        // select-group §3: "a selected row filtered out of view stays selected and Select stays
        // enabled" — the screen reports no row (its highlight follows `selectedIndex`, -1 here).
        XCTAssertEqual(EnrollPickerSelection.committedId(index: -1, rowIds: ["c", "d"], trackedId: "b"), "b")
        XCTAssertEqual(EnrollPickerSelection.committedId(index: 2, rowIds: ["c"], trackedId: "b"), "b")
        XCTAssertNil(EnrollPickerSelection.committedId(index: -1, rowIds: ["c"], trackedId: nil))
    }
}
