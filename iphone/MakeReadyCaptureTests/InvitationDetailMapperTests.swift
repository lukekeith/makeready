import XCTest
@testable import MakeReady

final class InvitationDetailMapperTests: XCTestCase {
    private let zone = TimeZone(secondsFromGMT: 0) ?? .current

    func testSelectedRequestAndNullableInviteUseActualMetadata() throws {
        let request = InvitationDetailFixtures.detail(kind: .request, status: .accepted, siblingFirst: true)
        let mapped = try XCTUnwrap(RequestDetailMapper.output(request, busy: false, timeZone: zone))
        XCTAssertEqual(mapped.groupID, "g1")
        XCTAssertEqual(mapped.state.groupName, "Selected group")
        XCTAssertEqual(mapped.state.status, "approved")
        XCTAssertEqual(mapped.groupDestination, .groupDetail(id: "g1", name: "Selected group"))
        let invite = InvitationDetailFixtures.detail(phone: nil, group: nil, member: .init(
            id: "m1", name: "Ada Lovelace", picture: nil, age: nil, role: nil, birthday: nil, joinedAt: nil))
        let output = try XCTUnwrap(InviteDetailMapper.output(invite, busy: false, timeZone: zone))
        XCTAssertEqual(output.state.phone, "No phone number")
        XCTAssertEqual(output.state.groupTitles, ["No group"])
        XCTAssertNil(output.state.age)
        XCTAssertEqual(output.state.role, "—")
        XCTAssertEqual(output.state.birthday, "—")
        XCTAssertEqual(output.state.joined, "—")
        XCTAssertEqual(output.state.invitedBy, "Fixture Leader")
        XCTAssertEqual(output.memberDestination, .memberDetail(id: "m1", name: "Ada Lovelace"))
    }
    /// Owner 2026-11-02: an event a leader performed names that leader; others read as before.
    func testLeaderPerformedEventsNameTheLeader() {
        let rejected = InvitationDetail.Event(id: "e1", type: .rejected, at: InvitationDetailFixtures.date,
                                              groupId: "g1", groupName: "Young Adults", invitationId: "i1",
                                              actorName: "John Smith")
        XCTAssertEqual(InviteDetailMapper.event(rejected, phone: "(555) 000-1111", timeZone: zone).text,
                       "Request rejected for Young Adults by John Smith")
        let requested = InvitationDetail.Event(id: "e2", type: .requested, at: InvitationDetailFixtures.date,
                                               groupId: "g1", groupName: "Young Adults", invitationId: "i1")
        XCTAssertEqual(InviteDetailMapper.event(requested, phone: "(555) 000-1111", timeZone: zone).text,
                       "Requested to join Young Adults")
        let blank = InvitationDetail.Event(id: "e3", type: .approved, at: InvitationDetailFixtures.date,
                                           groupId: "g1", groupName: "Young Adults", invitationId: "i1", actorName: "  ")
        XCTAssertEqual(InviteDetailMapper.event(blank, phone: "(555) 000-1111", timeZone: zone).text,
                       "Request approved for Young Adults")
    }
    func testIndependentCapabilitiesBusyAndParallelHistoryArrays() throws {
        let events = InvitationEventType.allForDetailTests.enumerated().map { index, type in
            InvitationDetail.Event(id: "e\(index)", type: type, at: InvitationDetailFixtures.date,
                                   groupId: nil, groupName: nil, invitationId: "i1")
        }
        let detail = InvitationDetailFixtures.detail(status: .expired, canResend: false, canWithdraw: true, events: events)
        let output = try XCTUnwrap(InviteDetailMapper.output(detail, busy: true, timeZone: zone))
        XCTAssertFalse(output.canResend)
        XCTAssertTrue(output.canWithdraw)
        XCTAssertFalse(output.actionsEnabled)
        XCTAssertFalse(output.state.memberLinked)
        XCTAssertNil(output.memberDestination)
        XCTAssertEqual(output.state.groupTitles.count, output.state.groupStatuses.count)
        XCTAssertEqual(output.state.groupTitles.count, output.state.groupStatusDates.count)
        XCTAssertEqual(output.state.groupTitles.count, output.state.groupPhotoURLs.count)
        XCTAssertEqual(output.state.eventDates.count, events.count)
        XCTAssertEqual(output.state.eventTexts.count, events.count)
        XCTAssertEqual(output.state.eventHighlights.count, events.count)
        XCTAssertEqual(output.state.eventTones.count, events.count)
        XCTAssertEqual(output.state.eventTexts[1], "Invitation resent to (202) 555-0100 for No group")
        XCTAssertEqual(output.state.eventTones[3], "positive")
        let nullPhone = InvitationDetailFixtures.detail(phone: nil, canResend: false, canWithdraw: false)
        XCTAssertFalse(try XCTUnwrap(InviteDetailMapper.output(nullPhone, busy: false, timeZone: zone)).canWithdraw)
    }

    func testReviewedRequestVocabularyAndStableMemberLink() throws {
        for (status, expected) in [(InvitationStatus.requested, "pending"), (.accepted, "approved"), (.rejected, "rejected")] {
            let detail = InvitationDetailFixtures.detail(kind: .request, status: status, siblingFirst: true)
            let output = try XCTUnwrap(RequestDetailMapper.output(detail, busy: true, timeZone: zone))
            XCTAssertEqual(output.state.status, expected)
            XCTAssertTrue(output.state.responding)
            XCTAssertEqual(output.state.requestTime, "12:30pm")
            XCTAssertEqual(output.groupID, "g1")
        }
        let member = InvitationDetail.Member(id: "m1", name: "Ada", picture: nil, age: 52,
                                              role: "Member", birthday: "1974-06-25T00:00:00Z", joinedAt: InvitationDetailFixtures.date)
        let output = try XCTUnwrap(InviteDetailMapper.output(InvitationDetailFixtures.detail(member: member), busy: false, timeZone: zone))
        XCTAssertEqual(output.state.age, 52)
        XCTAssertEqual(output.state.birthday, "Jun 25, 1974")
        XCTAssertEqual(output.memberDestination, .memberDetail(id: "m1", name: "Ada"))
    }

}

enum InvitationDetailFixtures {
    static let date = "2026-11-02T12:30:00Z"
    static func detail(id: String = "i1", kind: InvitationKind = .invite, status: InvitationStatus = .sent,
                       phone: String? = "+12025550100", group: String? = "g1", member: InvitationDetail.Member? = nil,
                       siblingFirst: Bool = false, canResend: Bool = true, canWithdraw: Bool = true,
                       events: [InvitationDetail.Event] = []) -> InvitationDetail {
        let selected = InvitationDetail.Invitation(id: id, kind: kind, groupId: group,
            groupName: group == nil ? nil : "Selected group", groupPicture: nil, status: status, date: date)
        let sibling = InvitationDetail.Invitation(id: "other", kind: .invite, groupId: "wrong",
            groupName: "Wrong group", groupPicture: nil, status: .sent, date: date)
        return InvitationDetail(id: id, kind: kind, status: status, recipientPhone: phone, recipientName: nil,
            inviterName: "Fixture Leader", message: nil, createdAt: date, member: member,
            invitations: siblingFirst ? [sibling, selected] : [selected], events: events,
            canResend: canResend, canWithdraw: canWithdraw)
    }
}

private extension InvitationEventType {
    static let allForDetailTests: [Self] = [.sent, .resent, .linkClicked, .accepted, .withdrawn, .expired, .requested, .approved, .rejected]
}
