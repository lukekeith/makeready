import XCTest
@testable import MakeReady

/// invite-member T7: sendInvite posts the §Contract body and maps the server's failure.
@MainActor
final class InviteActionsTests: XCTestCase {
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        api = StubAPIClient()
    }

    func testPostsTheContractBodyAndReturnsTheInviteId() async throws {
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"inv1","inviteUrl":"http://x","message":"Invite sent successfully"}"#)
        let id = try await InviteActions(api: api).sendInvite(groupId: "g1", recipientPhone: "+15555550123", recipientName: "Ada Test")
        XCTAssertEqual(id, "inv1")
        let body = try XCTUnwrap(api.calls.first?.body)
        XCTAssertEqual(body["groupId"] as? String, "g1")
        XCTAssertEqual(body["recipientPhone"] as? String, "+15555550123")
        XCTAssertEqual(body["recipientName"] as? String, "Ada Test")
        XCTAssertEqual(body.count, 3)
    }

    func testSuccessFalseThrowsTheServerError() async {
        api.stub("POST", "/api/invites/send", json: #"{"success":false,"error":"Rate limited"}"#)
        do {
            _ = try await InviteActions(api: api).sendInvite(groupId: "g1", recipientPhone: "+15555550123", recipientName: "Ada")
            XCTFail("expected a throw")
        } catch APIError.serverError(let message) {
            XCTAssertEqual(message, "Rate limited")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
