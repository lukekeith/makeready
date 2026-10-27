import XCTest
@testable import MakeReady

/// ui2-groups-browse D8: the create call — trimmed name, default flags, stored on success;
/// a failure surfaces "Couldn't create the group"; a 401 signs out and surfaces nothing.
@MainActor
final class CreateGroupSubmitTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"group":{"id":"g9","code":"WALK01","name":"Walk Test Group","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberDirectoryAccess":"ALLOWED","memberCount":0,"creatorId":"u1","creatorName":"Luke Keith","createdAt":"2026-10-27T12:00:00.000Z","updatedAt":"2026-10-27T12:00:00.000Z"}}"#

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func run(_ name: String, onUnauthorized: @MainActor () async -> Void = {}) async -> UserGroup? {
        await CreateGroupSubmit.run(name: name, actions: GroupActions(api: api, state: state), state: state,
                                    onUnauthorized: onUnauthorized)
    }

    func testCreateSendsTheTrimmedNameWithDefaultFlagsAndStoresTheGroup() async {
        api.stub("POST", "/api/groups", json: created)
        let group = await run("  Walk Test Group \n")
        XCTAssertEqual(group?.id, "g9")
        XCTAssertEqual(state.groups["g9"]?.name, "Walk Test Group")
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["name"] as? String, "Walk Test Group")
        XCTAssertEqual(body?["isPrivate"] as? Bool, false)
        XCTAssertEqual(body?["allowInvites"] as? Bool, true)
        XCTAssertEqual(body?["memberDirectory"] as? Bool, true)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testFailureSurfacesTheFriendlyMessage() async {
        api.errorFor = { _, _ in APIError.serverError("Name already taken") }
        let group = await run("Walk Test Group")
        XCTAssertNil(group)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't create the group")
        XCTAssertEqual(state.errors.last?.context, "CreateGroupContainer.create")
    }

    func testUnauthorizedSignsOutAndSurfacesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let group = await run("Walk Test Group", onUnauthorized: { signedOut = true })
        XCTAssertNil(group)
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testBlankNameSendsNothingAndLongNamesAreCapped() async {
        let blank = await run("   ")
        XCTAssertNil(blank)
        XCTAssertTrue(api.calls.isEmpty)
        api.stub("POST", "/api/groups", json: created)
        _ = await run(String(repeating: "a", count: 250))
        XCTAssertEqual((api.calls.first?.body?["name"] as? String)?.count, 200)
    }
}
