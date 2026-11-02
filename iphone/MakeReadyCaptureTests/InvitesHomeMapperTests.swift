import XCTest
@testable import MakeReady

final class InvitesHomeMapperTests: XCTestCase {
    func testStatusesAndRequestIdentity() {
        let statuses: [InvitationDisplayStatus] = [.sent, .requested, .accepted, .rejected, .expired]
        let items = statuses.enumerated().map { index, status in
            InvitationFeedItem(id: "id\(index)", kind: index == 2 ? .request : .invite, status: status,
                               recipientPhone: "555\(index)", recipientName: nil, memberId: nil,
                               groupId: nil, groupName: "Group", organizationId: "org", inviterId: nil,
                               inviterName: nil, date: "2026-11-02T12:00:00Z", createdAt: "2026-11-02T12:00:00Z")
        }
        let window = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: items.map(\.id), total: 5)
        let output = InvitesHomeMapper.output(window: window, entities: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }), filters: nil, selection: .init(), now: Date(), timeZone: .gmt)
        XCTAssertEqual(output.state.inviteStatuses, statuses.map(\.rawValue))
        XCTAssertEqual(output.selection(atRow: 2), .request(id: "id2"))
    }
    func testSearchAndDatesPreserveRequestIdentity() {
        let item = InvitationFeedItem(id: "accepted-request", kind: .request, status: .accepted,
            recipientPhone: "5551234", recipientName: nil, memberId: nil, groupId: "g", groupName: "Alpha",
            organizationId: "o", inviterId: nil, inviterName: nil, date: "2026-11-02T12:00:00Z", createdAt: "2026-11-02T12:00:00Z")
        let window = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: [item.id], total: 1)
        let now = ISO8601DateFormatter().date(from: "2026-11-02T12:00:30Z")!
        var selection = InvitesHomeMapper.Selection()
        selection.search = "alpha"
        let output = InvitesHomeMapper.output(window: window, entities: [item.id: item], filters: nil,
                                              selection: selection, now: now, timeZone: .gmt)
        XCTAssertEqual(output.selection(atRow: 0), .request(id: "accepted-request"))
        XCTAssertEqual(output.rowDate(at: 0), "Just now")
        selection.search = "missing"
        let noResults = InvitesHomeMapper.output(window: window, entities: [item.id: item], filters: nil,
                                                 selection: selection, now: now, timeZone: .gmt)
        XCTAssertEqual(noResults.mode, .noResults)
        let empty = InvitesHomeMapper.output(window: nil, entities: [:], filters: nil,
                                             selection: .init(), now: now, timeZone: .gmt)
        XCTAssertEqual(empty.mode, .empty)
        XCTAssertEqual(InvitesHomeMapper.dateLabel("2026-11-01T12:00:00Z", now: now, timeZone: .gmt), "Nov 1, 2026")
        XCTAssertFalse(selection.query.path.contains("q="))
        XCTAssertEqual(InvitesHomeContainer.searchDebounce, .milliseconds(300))
    }
    func testDraftClearAndSaveLeaveAppliedSelectionAloneUntilSave() {
        var applied = InvitesHomeMapper.Selection()
        applied.orgID = "original"
        let draft = FilterMenuOverlay.drafted(["original"], InvitesHomeMapper.allID, mode: .single)
        XCTAssertEqual(applied.orgID, "original")
        let cleared = InvitesHomeMapper.saving([], in: .org, selection: applied)
        XCTAssertNil(cleared.orgID)
        let saved = InvitesHomeMapper.saving(draft, in: .org, selection: applied)
        XCTAssertNil(saved.orgID)
        XCTAssertEqual(applied.orgID, "original")
        XCTAssertEqual(InvitesHomeMapper.options(.org, filters: nil).first?.id, InvitesHomeMapper.allID)
    }

}
