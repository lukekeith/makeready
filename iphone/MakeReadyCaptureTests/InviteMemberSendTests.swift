import XCTest
@testable import MakeReady

/// invite-member D10: a failed send records a surfaced error with the server's message and
/// reports false (the screen stays on step 2); success reports true.
@MainActor
final class InviteMemberSendTests: XCTestCase {
    func testSuccessReturnsTrueAndRecordsNothing() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"inv1"}"#)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada Test", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertTrue(ok)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testFailureSurfacesTheServerMessage() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("POST", "/api/invites/send", json: #"{"success":false,"error":"Rate limited: try later"}"#)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.activeSurfacedError?.message, "Rate limited: try later")
    }

    func testANonServerFailureUsesTheFallbackCopy() async {
        let state = AppState()
        let api = StubAPIClient()
        api.errorToThrow = URLError(.notConnectedToInternet)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't send the invite")
    }
}
