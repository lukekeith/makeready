import XCTest
@testable import MakeReady

/// ui2-members-browse T13 (member half): D8 role/org, D9, D10 empties, D12 rail, D14 state,
/// email ?? googleEmail, capitalized gender, "L. Keith", whole hours; F5 loading.
final class MemberProfileMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Sun Oct 25, noon MDT

    private func tony(email: String? = nil, isGroupLeader: Bool = true) -> MemberDetail {
        MemberDetail(
            id: "m1", phoneNumber: "+11234567890", phoneVerified: true, firstName: "Tony", lastName: "Stark",
            email: email, googleEmail: "tony@gmail.example", gender: "male", birthday: "1974-06-25T00:00:00.000Z",
            profilePicture: nil, googlePicture: "https://lh3.example/t.jpg", userId: "u1",
            address: "10880 Malibu Point\nMalibu, CA 90265", emergencyContactName: "Pepper Potts",
            emergencyContactPhone: "+11234567891", isGroupLeader: isGroupLeader,
            organizations: [
                MemberDetailOrganization(organizationId: "org2", joinedAt: "2025-03-01T12:00:00.000Z",
                                         organization: MemberOrganizationRef(id: "org2", name: "Grace Church")),
                MemberDetailOrganization(organizationId: "org1", joinedAt: "2026-07-05T14:03:22.123Z",
                                         organization: MemberOrganizationRef(id: "org1", name: "MakeReady"))
            ]
        )
    }

    private func map(_ input: MemberProfileMapper.Input) -> MembersProfileScreen.State {
        MemberProfileMapper.state(input, today: today, timeZone: tz)
    }

    func testIdentityQuickStatsAndFields() {
        let st = map(.init(name: "Tony S.", detail: tony(), organizationId: "org1"))
        XCTAssertEqual(st.memberName, "Tony Stark")                         // the payload wins over the list name
        XCTAssertEqual(st.email, "tony@gmail.example")                      // email ?? googleEmail
        XCTAssertEqual(st.avatarURL, "https://lh3.example/t.jpg")
        XCTAssertEqual(st.initials, "TS")
        XCTAssertEqual(st.age, "52")
        XCTAssertEqual(st.role, "Group leader")                             // D8
        XCTAssertEqual(st.birthday, "Jun 25, 1974")                         // a UTC calendar date — not Jun 24 in Denver
        XCTAssertEqual(st.joined, "Jul 5, 2026")                            // the shell's org's joinedAt
        XCTAssertEqual(st.organization, "Grace Church, MakeReady")          // D8: comma-joined
        XCTAssertEqual(st.phone, "+1 (123) 456-7890")
        XCTAssertTrue(st.phoneVerified)
        XCTAssertEqual(st.gender, "Male")                                   // stored lowercase
        XCTAssertEqual(st.address, "10880 Malibu Point\nMalibu, CA 90265")
        XCTAssertEqual(st.emergencyContactName, "Pepper Potts")
        XCTAssertEqual(st.emergencyContactPhone, "+1 (123) 456-7891")
    }

    func testJoinedFallsBackToTheFirstOrgWhenTheShellOrgIsUnknown() {
        XCTAssertEqual(map(.init(name: "", detail: tony())).joined, "Mar 1, 2025")
    }

    func testEmailPrefersTheMemberEmailAndSkipsAnEmptyOne() {
        XCTAssertEqual(map(.init(name: "", detail: tony(email: "tony@stark.example"))).email, "tony@stark.example")
        XCTAssertEqual(map(.init(name: "", detail: tony(email: ""))).email, "tony@gmail.example")
    }

    func testRoleIsMemberWithoutALedGroup() {
        XCTAssertEqual(map(.init(name: "", detail: tony(isGroupLeader: false))).role, "Member")
    }

    func testAgeAroundTheBirthday() {
        XCTAssertEqual(MemberProfileMapper.age(birthday: "1974-11-02T00:00:00.000Z", today: today, timeZone: tz), "51")
        XCTAssertEqual(MemberProfileMapper.age(birthday: "1974-10-25T00:00:00.000Z", today: today, timeZone: tz), "52")
        XCTAssertEqual(MemberProfileMapper.age(birthday: nil, today: today, timeZone: tz), "")
        XCTAssertEqual(MemberProfileMapper.age(birthday: "garbage", today: today, timeZone: tz), "")
    }

    /// D10: absent values are "" (the row keeps its label); F5: loading shows the list-known name.
    func testLoadingIsTheListNameOverEmptySections() {
        let st = map(.init(name: "Tony Stark"))
        XCTAssertEqual(st.memberName, "Tony Stark")
        XCTAssertEqual(st.initials, "TS")
        for value in [st.email, st.avatarURL, st.age, st.role, st.birthday, st.joined, st.organization,
                      st.phone, st.gender, st.address, st.emergencyContactName, st.emergencyContactPhone] {
            XCTAssertEqual(value, "")
        }
        XCTAssertFalse(st.phoneVerified)
        XCTAssertEqual(st.dayNumbers, [])
        XCTAssertEqual(st.groupTitles, [])
        XCTAssertEqual(st.programTitles, [])
    }

    /// D12: 30 local days, today−29 … today, today the trailing card.
    func testRailIsThirtyDaysEndingToday() {
        let days = [
            HomeDay(day: "2026-10-24", sessionSeconds: 1530, blocks: [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0],
                    lastActivityAt: "2026-10-24T13:20:00.000Z"),
            HomeDay(day: "2026-10-23", sessionSeconds: 300, blocks: [0, 0, 0, 0, 0, 0, 0, 300, 0, 0, 0, 0],
                    lastActivityAt: "2026-10-23T20:05:00.000Z")
        ]
        let st = map(.init(name: "Tony Stark", days: days))
        XCTAssertEqual(st.dayNumbers.count, 30)
        XCTAssertEqual(st.dayNumbers.first, "26")
        XCTAssertEqual(st.dayNumbers.last, "25")
        XCTAssertEqual(st.dayMonths.first, "SEP")
        XCTAssertEqual(st.dayMonths.last, "OCT")
        XCTAssertEqual(st.dayWeekdays.first, "SAT")                         // Sep 26, 2026
        XCTAssertEqual(st.dayWeekdays[28], "SAT")                           // Oct 24
        XCTAssertEqual(st.dayWeekdays.last, "")                             // today's card shows no weekday
        XCTAssertEqual(st.dayDateStates.last, "today")
        XCTAssertEqual(st.dayDateStates.filter { $0 == "today" }.count, 1)
        XCTAssertEqual(st.dayLine1s[28], "26 mins")                         // 1530 s = 25.5 → 26
        XCTAssertEqual(st.dayLine2s[28], "7:20 am")                         // local h:mm a
        XCTAssertEqual(st.dayDetailsStates[28], "muted")
        XCTAssertEqual(st.daySeries[28], [0, 0, 0, 0, 10, 0, 15.5, 0, 0, 0, 0, 0])
        XCTAssertEqual(st.dayLine1s[27], "5 mins")
        XCTAssertEqual(st.dayLine2s[27], "2:05 pm")
        XCTAssertEqual(st.dayLine1s[29], "0 mins")                          // today, no sessions
        XCTAssertEqual(st.dayLine2s[29], "")
        XCTAssertEqual(st.dayDetailsStates[29], "nothing")
        XCTAssertEqual(st.daySeries[29], Array(repeating: 0, count: 12))
    }

    func testMembershipRows() {
        let groups = [
            MemberGroupItem(id: "g1", name: "Young professionals", coverImageUrl: "https://cdn.example/g1.jpg",
                            organizationId: "org1", memberCount: 9, joinedAt: "2025-07-03T16:00:00.000Z",
                            creator: MemberGroupCreator(id: "u2", name: "Luke Keith")),
            MemberGroupItem(id: "g2", name: "The kids", joinedAt: "2025-08-05T16:00:00.000Z",
                            creator: MemberGroupCreator(id: "u3", name: "Cher")),
            MemberGroupItem(id: "g3", name: "Orphans", joinedAt: "garbage")
        ]
        let st = map(.init(name: "", groups: groups))
        XCTAssertEqual(st.groupTitles, ["Young professionals", "The kids", "Orphans"])
        XCTAssertEqual(st.groupPhotoURLs, ["https://cdn.example/g1.jpg", "", ""])
        XCTAssertEqual(st.groupLeaders, ["L. Keith", "Cher", ""])
        XCTAssertEqual(st.groupJoinedDates, ["Jul 3, 2025", "Aug 5, 2025", ""])
    }

    /// D14: `Complete` iff totalCount > 0 and completedCount ≥ totalCount — never from percent alone.
    func testEngagementRowsAndTheCompleteRule() {
        let programs = [
            MemberEngagementProgram(enrollmentId: "e1", programId: "p1", title: "Daily Inspiration",
                                    coverImageUrl: "https://cdn.example/p1.jpg", completedCount: 12, totalCount: 30, hours: 15, percent: 68),
            MemberEngagementProgram(enrollmentId: "e2", programId: "p2", title: "Romans in 30 days",
                                    completedCount: 31, totalCount: 31, hours: 92, percent: 100),
            MemberEngagementProgram(enrollmentId: "e3", programId: "p3", title: "Up to date",
                                    completedCount: 10, totalCount: 20, hours: 3, percent: 100),
            MemberEngagementProgram(enrollmentId: "e4", programId: "p4", title: "Not started")
        ]
        let st = map(.init(name: "", engagement: MemberEngagement(programs: programs)))
        XCTAssertEqual(st.programTitles, ["Daily Inspiration", "Romans in 30 days", "Up to date", "Not started"])
        XCTAssertEqual(st.programStates, ["Progress", "Complete", "Progress", "Progress"])
        XCTAssertEqual(st.programProgress, [0.68, 1, 1, 0])
        XCTAssertEqual(st.programCompleteCounts, ["12", "31", "10", "0"])
        XCTAssertEqual(st.programHours, ["15", "92", "3", "0"])
        XCTAssertEqual(st.programCoverURLs, ["https://cdn.example/p1.jpg", "", "", ""])
    }

    func testLeaderShortNameAndPhoneLabel() {
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Luke Keith"), "L. Keith")
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Mary Ann Smith"), "M. Smith")
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Cher"), "Cher")
        XCTAssertEqual(MemberProfileMapper.leaderShortName(nil), "")
        XCTAssertEqual(MemberProfileMapper.phoneLabel("+11234567890"), "+1 (123) 456-7890")
        XCTAssertEqual(MemberProfileMapper.phoneLabel("+447700900123"), "+447700900123")   // non-NANP as stored
        XCTAssertEqual(MemberProfileMapper.phoneLabel(""), "")
    }

    // MARK: - ui2-members-edit D7: Emergency phone display

    func testEmergencyPhoneDisplayRule() {
        let rows: [(String, String)] = [
            ("5551234567", "+1 (555) 123-4567"),
            ("(555) 123-4567", "+1 (555) 123-4567"),
            ("555.123.4567", "+1 (555) 123-4567"),
            ("1-555-123-4567", "+1 (555) 123-4567"),
            ("+1 555 123 4567", "+1 (555) 123-4567"),       // `+` is a separator
            ("+11234567891", "+1 (123) 456-7891"),
            ("555-1234", "555-1234"),                       // 7 digits: as typed
            ("555-123-4567 x12", "555-123-4567 x12"),       // an extension: as typed
            ("+44 20 7946 0958", "+44 20 7946 0958"),       // 12 digits: as typed
            ("25551234567", "25551234567"),                 // 11 digits not starting 1
            ("", "")
        ]
        for (typed, shown) in rows {
            XCTAssertEqual(MemberProfileMapper.contactPhoneLabel(typed), shown, typed)
        }
    }

    func testEmergencyPhoneRowUsesTheContactRule() {
        var d = tony()
        d.emergencyContactPhone = "555.123.4567"
        XCTAssertEqual(map(.init(name: "Tony S.", detail: d)).emergencyContactPhone, "+1 (555) 123-4567")
        d.emergencyContactPhone = "555-123-4567 ext. 2"
        XCTAssertEqual(map(.init(name: "Tony S.", detail: d)).emergencyContactPhone, "555-123-4567 ext. 2")
    }
}
