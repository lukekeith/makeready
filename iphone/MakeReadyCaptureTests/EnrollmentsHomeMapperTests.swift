import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D7, D8, D12, D13, D15, D16, D19, D27: the feed → the Enrollments section.
@MainActor
final class EnrollmentsHomeMapperTests: XCTestCase {
    /// Agent walk round 1 (E2/E3): no Enrollments chip opened its menu. A `Menu` chip fires `onTap`,
    /// and an unlabelled trailing closure on FilterChip binds to `onSelect` (Swift 5's backward scan).
    func testEnrollmentsHomeMenuChipTapPresentsTheMenu() {
        var tapped = false
        EnrollmentsHomeScreen.menuChip(label: "Active") { tapped = true }.onTap()
        XCTAssertTrue(tapped)
    }

    private let zone = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2035-01-06T18:00:00Z")!     // Sat Jan 6, 12:00 local

    private func draft(_ id: String, start: String? = nil, schedule: [String]? = nil, sms: String? = nil,
                       sync: String? = nil, access: String? = nil, by name: String? = "Luke Keith") -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: "p2", startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: sms, timezone: sms == nil ? nil : "America/Chicago",
                  syncMode: sync, lessonAccess: access, createdBy: name.map { EnrollmentWireRef(id: "u1", name: $0) },
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-04T00:00:00.000Z")
    }

    private func enrollment(_ id: String, name: String, progress: Double, done: Int, members: Int, minutes: Int) -> EnrollmentFeedItem {
        EnrollmentFeedItem(kind: "enrollment", id: id, draft: nil,
                           studyProgram: EnrollmentFeedProgram(id: "p-\(id)", name: name, coverImageUrl: "https://x/\(id).png"),
                           startDate: "2035-01-08", endDate: "2035-02-01", enrolledAt: "2035-01-01T15:00:00.000Z",
                           progress: progress, completedMembers: done, memberCount: members, plannedMinutes: minutes,
                           recencyAt: "2035-01-05T00:00:00.000Z")
    }

    private func draftItem(_ wire: DraftWire, name: String = "John") -> EnrollmentFeedItem {
        EnrollmentFeedItem(kind: "draft", id: nil, draft: wire,
                           studyProgram: EnrollmentFeedProgram(id: wire.studyProgramId, name: name, coverImageUrl: nil),
                           startDate: nil, endDate: nil, enrolledAt: nil, progress: nil, completedMembers: nil,
                           memberCount: nil, plannedMinutes: nil, recencyAt: wire.updatedAt)
    }

    private func feed(_ items: [EnrollmentFeedItem]) -> EnrollmentFeed {
        EnrollmentFeed(
            sections: [
                EnrollmentFeedSection(group: .init(id: "g1", name: "Young Professionals", coverImageUrl: "https://x/g1.png",
                                                   leader: EnrollmentWireRef(id: "u1", name: "Luke Keith")), items: items),
                EnrollmentFeedSection(group: .init(id: "g2", name: "Stickane Family", coverImageUrl: nil, leader: nil),
                                      items: [enrollment("e2", name: "Daily Inspiration", progress: 1, done: 4, members: 4, minutes: 720)])
            ],
            options: EnrollmentFeedOptions(groups: [EnrollmentWireRef(id: "g1", name: "Young Professionals")],
                                           leaders: [EnrollmentWireRef(id: "u1", name: "Luke Keith")]))
    }

    private func output(_ feed: EnrollmentFeed?, selection: EnrollmentsHomeMapper.Selection = .init()) -> EnrollmentsHomeMapper.Output {
        EnrollmentsHomeMapper.output(.init(feed: feed, options: feed?.options, selection: selection),
                                     today: today, timeZone: zone)
    }

    func testSectionsRowsAndNumbers() {
        let o = output(feed([enrollment("e1", name: "Romans", progress: 0.5, done: 3, members: 12, minutes: 90),
                             draftItem(draft("d1"))]))
        let s = o.state
        XCTAssertEqual(s.groupNames, ["Young Professionals", "Stickane Family"])
        XCTAssertEqual(s.groupLeaderNames, ["Luke Keith", ""])
        XCTAssertEqual(s.groupPhotoURLs, ["https://x/g1.png", ""])
        XCTAssertEqual(s.programGroupIndexes, [0, 0, 1])
        XCTAssertEqual(s.programTitles, ["Romans", "John", "Daily Inspiration"])
        XCTAssertEqual(s.programProgress, [0.5, 2.0 / 6, 1])                  // a draft: its checklist steps
        XCTAssertEqual(s.programLayout, .rail)                                 // owner 2026-10-30: ObjectCards
        XCTAssertEqual(s.programMemberCounts, ["12", "", "4"])
        XCTAssertEqual(s.programDayCounts, ["", "", ""])                       // no program in the store
        XCTAssertEqual(s.programCompleteCounts, ["3/12", "", "4/4"])          // D16
        XCTAssertEqual(s.programHours, ["1.5", "", "12"])                      // D12
        XCTAssertEqual(s.programEnrolledDates, ["Jan 1, 2035", "", "Jan 1, 2035"])
        XCTAssertEqual(s.programCoverURLs, ["https://x/e1.png", "", "https://x/e2.png"])
        XCTAssertEqual(s.programDraftLabels, ["", "Draft · 2/6", ""])          // D7: group + program only
        XCTAssertEqual(s.programDraftStarters, ["", "Started by Luke Keith", ""])
        XCTAssertFalse(s.loading); XCTAssertFalse(s.failed)
        XCTAssertEqual(s.searchText, "")                                       // D27: the screen filters locally
    }

    func testADraftCardShowsItsProgramsDays() {
        let program = StudyProgram(id: "p2", name: "John", days: 21)
        let o = EnrollmentsHomeMapper.output(.init(feed: feed([draftItem(draft("d1"))]), program: { $0 == "p2" ? program : nil }),
                                             today: today, timeZone: zone)
        XCTAssertEqual(o.state.programDayCounts, ["21", ""])
    }

    func testRowTargetsAndGroupArrow() {
        let wire = draft("d1")
        let o = output(feed([enrollment("e1", name: "Romans", progress: 0.5, done: 3, members: 12, minutes: 90), draftItem(wire)]))
        XCTAssertEqual(o.target(atRow: 0), .enrollment(id: "e1", name: "Romans"))
        XCTAssertEqual(o.target(atRow: 1), .draft(wire, groupName: "Young Professionals", programName: "John"))
        XCTAssertNil(o.target(atRow: 9))
        XCTAssertEqual(o.groupDestination(section: 1), .groupDetail(id: "g2", name: "Stickane Family"))   // D7(d)
        XCTAssertNil(o.groupDestination(section: 5))
    }

    func testHoursHaveAtMostOneDecimalAndNoTrailingZero() {                    // D12
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 0), "0")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 60), "1")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 90), "1.5")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 100), "1.7")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 720), "12")
    }

    func testDraftCountAppliesTheStaleRule() {                                 // D9 + D19
        let future = draft("d1", start: "2035-01-08", schedule: ["2035-01-08"], sms: "07:30", sync: "AUTO", access: "ALL_AT_ONCE")
        let stale = draft("d2", start: "2035-01-01", schedule: ["2035-01-01"], sms: "07:30", sync: "AUTO", access: "ALL_AT_ONCE")
        func count(_ w: DraftWire) -> Int {
            EnrollmentsHomeMapper.draftCompletedSteps(w, group: nil, program: nil, groupName: "Young Professionals",
                                                      programName: "John", today: today, timeZone: zone)
        }
        XCTAssertEqual(count(future), 6)
        XCTAssertEqual(count(stale), 5)
        XCTAssertEqual(EnrollmentsHomeMapper.draftLabel(completed: 5), "Draft · 5/6")
        XCTAssertEqual(EnrollmentsHomeMapper.starterLabel(nil), "")             // F9
    }

    func testLoadingAndFailedOnlyWithNothingToShow() {
        let loading = EnrollmentsHomeMapper.output(.init(feed: nil, options: nil, loading: true), today: today, timeZone: zone).state
        XCTAssertTrue(loading.loading)
        XCTAssertEqual(loading.groupNames, [])
        let failed = EnrollmentsHomeMapper.output(.init(feed: nil, options: nil, failed: true), today: today, timeZone: zone).state
        XCTAssertTrue(failed.failed)
    }

    func testChipsRestAndNarrow() {                                            // D8, D13, D15
        var sel = EnrollmentsHomeMapper.Selection()
        var s = output(nil, selection: sel).state
        XCTAssertEqual([s.orgFilterLabel, s.groupFilterLabel, s.leaderFilterLabel, s.statusFilterLabel],
                       ["Orgs", "Groups", "Leaders", "Status"])                // owner 2026-10-30: no "All"
        let orgs: [FilterMenuOverlay.Option] = [.init(id: "o1", label: "Grace Church"), .init(id: "o2", label: "Hope")]
        sel = EnrollmentsHomeMapper.saving(["o1"], in: .orgs, options: orgs, sel)
        sel = EnrollmentsHomeMapper.saving(["draft"], in: .status, options: [], sel)
        s = output(nil, selection: sel).state
        XCTAssertEqual(s.orgFilterLabel, "Grace Church")
        XCTAssertEqual(s.statusFilterLabel, "Draft")
        XCTAssertEqual(sel.filter, EnrollmentFeedFilter(orgIds: ["o1"], statuses: [.draft]))
        sel = EnrollmentsHomeMapper.clearing(.orgs, sel)
        XCTAssertEqual(sel.filter.orgIds, [])
        XCTAssertTrue(EnrollmentsHomeMapper.isAtRest(.orgs, sel))
        sel = EnrollmentsHomeMapper.clearing(.status, sel)
        XCTAssertEqual(sel.filter.statuses, [])
        XCTAssertTrue(EnrollmentsHomeMapper.isAtRest(.status, sel))
    }

    func testEveryChipIsMultiSelect() {                                       // owner 2026-10-29/30
        var sel = EnrollmentsHomeMapper.Selection()
        XCTAssertEqual(sel.filter.statusParam, "all")
        sel = EnrollmentsHomeMapper.saving(["draft", "active"], in: .status, options: [], sel)
        XCTAssertEqual(sel.filter.statusParam, "active,draft")
        XCTAssertEqual(output(nil, selection: sel).state.statusFilterLabel, "2 statuses")
        let groups: [FilterMenuOverlay.Option] = [.init(id: "g1", label: "Young Adults"), .init(id: "g2", label: "Prayer Team")]
        sel = EnrollmentsHomeMapper.saving(["g1", "g2"], in: .groups, options: groups, sel)
        XCTAssertEqual(output(nil, selection: sel).state.groupFilterLabel, "2 groups")
        XCTAssertEqual(EnrollmentsHomeMapper.selectedIds(.groups, sel), ["g1", "g2"])
        let leaders: [FilterMenuOverlay.Option] = [.init(id: "u1", label: "Luke Keith")]
        sel = EnrollmentsHomeMapper.saving(["u1"], in: .leaders, options: leaders, sel)
        XCTAssertEqual(output(nil, selection: sel).state.leaderFilterLabel, "Luke Keith")
        XCTAssertEqual(sel.filter.path(timeZone: zone),
                       "/api/enrollments-feed?groupId=g1,g2&leaderId=u1&status=active,draft&tz=America/Chicago")
        sel = EnrollmentsHomeMapper.saving([], in: .status, options: [], sel)
        XCTAssertEqual(output(nil, selection: sel).state.statusFilterLabel, "Status")
    }

    func testMenus() throws {
        let orgs = try JSONDecoder.apiDecoder.decode([OrganizationData].self, from: Data(#"[{"id":"o1","name":"Grace Church"}]"#.utf8))
        let options = feed([]).options
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.orgs, options: options, organizations: orgs).map(\.label), ["Grace Church"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.groups, options: options, organizations: orgs).map(\.id), ["g1"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.leaders, options: options, organizations: orgs).map(\.label), ["Luke Keith"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.status, options: nil, organizations: []).map(\.label),
                       ["Active", "Upcoming", "Completed", "Draft"])
        XCTAssertEqual(EnrollmentsHomeMapper.selectedIds(.orgs, .init()), [])
        XCTAssertEqual(EnrollmentsHomeMapper.selectedIds(.status, .init()), [])
    }
}
