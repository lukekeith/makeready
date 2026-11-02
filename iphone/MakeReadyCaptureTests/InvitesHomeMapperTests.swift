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
        let draft = FilterMenuOverlay.drafted(["original"], "other", mode: .single)
        XCTAssertEqual(applied.orgID, "original")
        let cleared = InvitesHomeMapper.saving([], in: .org, selection: applied)
        XCTAssertNil(cleared.orgID)
        let saved = InvitesHomeMapper.saving(draft, in: .org, selection: applied)
        XCTAssertEqual(saved.orgID, "other")
        XCTAssertEqual(applied.orgID, "original")
        // Owner 2026-10-30: no "All …" row in any menu, and every chip at rest names its dimension.
        XCTAssertTrue(InvitesHomeMapper.options(.status, filters: nil).allSatisfy { !$0.label.hasPrefix("All") })
        let rest = InvitesHomeMapper.output(window: nil, entities: [:], filters: nil, selection: .init(),
                                            now: .now, timeZone: .gmt).state
        XCTAssertEqual([rest.orgFilterLabel, rest.groupFilterLabel, rest.leaderFilterLabel, rest.statusFilterLabel],
                       ["Orgs", "Groups", "Leaders", "Status"])
    }

    func testMismatchedWindowIsNeverDisplayedDuringLoadFailureOrReentry() {
        let item = InvitationFeedItem(id: "old", kind: .invite, status: .sent, recipientPhone: "5551234567",
            recipientName: nil, memberId: nil, groupId: nil, groupName: "Alpha", organizationId: "o",
            inviterId: nil, inviterName: nil, date: "2026-11-02T12:00:00Z", createdAt: "2026-11-02T12:00:00Z")
        let old = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: [item.id], total: 1)
        var selection = InvitesHomeMapper.Selection()
        selection.orgID = "new"
        func output(_ window: InvitationFeedWindow, _ loading: Bool) -> InvitesHomeMapper.Output {
            InvitesHomeMapper.output(window: window, entities: [item.id: item], filters: nil,
                                    selection: selection, now: Date(), timeZone: .gmt, loading: loading)
        }
        XCTAssertTrue(output(old, true).rows.isEmpty)
        XCTAssertTrue(output(old, true).state.loading)
        XCTAssertTrue(output(old, false).rows.isEmpty)
        XCTAssertFalse(output(old, false).state.loading)
        let matching = InvitationFeedWindow(query: selection.query, orderedIDs: [item.id], total: 1)
        XCTAssertEqual(output(matching, true).selection(atRow: 0), .invite(id: "old"))
        XCTAssertFalse(output(matching, true).state.loading)
        selection = .init()
        XCTAssertTrue(output(matching, true).rows.isEmpty)
    }
    func testPhoneSearchFormatsAndRejectedRequestIdentity() {
        let item = InvitationFeedItem(id: "rejected-request", kind: .request, status: .rejected,
            recipientPhone: "+15551234567", recipientName: nil, memberId: nil, groupId: nil,
            groupName: "Alpha", organizationId: "o", inviterId: nil, inviterName: nil,
            date: "2026-11-02T12:00:00Z", createdAt: "2026-11-02T12:00:00Z")
        let window = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: [item.id], total: 1)
        var selection = InvitesHomeMapper.Selection()
        for query in ["(555)", "555-123", "555123", "alpha"] {
            selection.search = query
            let output = InvitesHomeMapper.output(window: window, entities: [item.id: item], filters: nil,
                                                  selection: selection, now: Date(), timeZone: .gmt)
            XCTAssertEqual(output.selection(atRow: 0), .request(id: item.id), query)
        }
        for query in ["Alpha 555", "abc", "---"] {
            selection.search = query
            let output = InvitesHomeMapper.output(window: window, entities: [item.id: item], filters: nil,
                                                  selection: selection, now: Date(), timeZone: .gmt)
            XCTAssertTrue(output.rows.isEmpty, query)
        }
    }

    @MainActor func testFailedFilterReloadKeepsOldWindowInvisibleAndDoesNotSendSearch() async {
        let state = AppState()
        let api = StubAPIClient()
        var paths: [String] = []
        api.responseFor = { _, path in
            paths.append(path)
            if paths.count > 1 { throw URLError(.notConnectedToInternet) }
            return Data(#"{"items":[{"id":"old","kind":"invite","status":"sent","recipientPhone":"5551234567","recipientName":null,"memberId":null,"groupId":null,"groupName":"Alpha","organizationId":"org","inviterId":null,"inviterName":null,"date":"2026-11-02T12:00:00Z","createdAt":"2026-11-02T12:00:00Z"}],"total":1,"filters":{"orgs":[],"groups":[],"leaders":[]}}"#.utf8)
        }
        let actions = InvitationActions(api: api, state: state)
        _ = await actions.loadInvitationFeed(InvitationQuery())
        var selection = InvitesHomeMapper.Selection()
        selection.orgID = "new"
        selection.search = "Alpha"
        _ = await actions.loadInvitationFeed(selection.query)
        XCTAssertEqual(state.invitationFeedWindow?.orderedIDs, ["old"])
        let output = InvitesHomeMapper.output(window: state.invitationFeedWindow,
            entities: Dictionary(uniqueKeysWithValues: state.invitations.all.map { ($0.id, $0) }),
            filters: state.invitationFilters, selection: selection, now: Date(), timeZone: .gmt)
        XCTAssertTrue(output.rows.isEmpty)
        XCTAssertEqual(paths.count, 2)
        XCTAssertFalse(paths.contains { $0.contains("q=") })
    }

}
