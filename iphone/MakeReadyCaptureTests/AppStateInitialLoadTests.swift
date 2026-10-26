import XCTest
@testable import MakeReady

/// SPEC D24/D26: sign-out re-arms the initial load, and a load still in flight at sign-out
/// cannot write the old user's organization into the cleared state.
@MainActor
final class AppStateInitialLoadTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    func testSignOutClearReArmsTheInitialLoad() async {
        var runs = 0
        await state.initialLoad.run { _ in runs += 1 }   // the first sign-in's load
        state.clearAllData()                              // AuthManager.signOut
        await state.initialLoad.run { _ in runs += 1 }   // the next sign-in's load
        XCTAssertEqual(runs, 2)
    }

    func testALoadInFlightAtSignOutCannotWriteTheOldOrganization() async throws {
        let org = try JSONDecoder().decode(OrganizationData.self, from: Data(#"{"id":"old-org","name":"Old"}"#.utf8))
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        state.clearAllData()
        state.adoptOrganization(org, generation: startedIn)   // the stale response lands late
        XCTAssertNil(state.organizationId)
        XCTAssertTrue(state.userOrganizations.isEmpty)
    }

    func testTheCurrentLoadAdoptsItsOrganization() async throws {
        let org = try JSONDecoder().decode(OrganizationData.self, from: Data(#"{"id":"org1","name":"Org"}"#.utf8))
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        state.adoptOrganization(org, generation: startedIn)
        XCTAssertEqual(state.organizationId, "org1")
    }

    // MARK: - ui2-members-browse D18 / T16: a non-owner leader still gets an org

    private let ownedJSON = #"{"success":true,"data":{"id":"org1","name":"MakeReady","ownerId":"u1"}}"#
    private let listJSON = #"{"success":true,"data":[{"id":"org2","name":"Grace Church","ownerId":"u9"},{"id":"org3","name":"Second Org"}]}"#

    func testAnOwnerAdoptsTheOwnedOrgWithoutTheFallback() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organization", json: ownedJSON)
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertEqual(state.organizationId, "org1")
        XCTAssertEqual(api.callCount("GET", "/api/organizations/my/organizations"), 0)
    }

    /// `/my/organization` 404s for an Admin or Group Leader (organization.ts:73) — the first org
    /// they hold a role in is adopted instead.
    func testANonOwnerAdoptsTheFirstRoleHeldOrg() async {
        let api = StubAPIClient()   // no canned /my/organization → it throws, as the 404 does
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertEqual(state.organizationId, "org2")
        XCTAssertEqual(state.userOrganizations.map(\.id), ["org2", "org3"])
    }

    func testTheFallbackIsGenerationGuarded() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        state.clearAllData()                                     // signed out mid-load
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertNil(state.organizationId)
        XCTAssertTrue(state.userOrganizations.isEmpty)
    }

    func testNoOrgAnywhereLeavesTheOrgUnset() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organizations", json: #"{"success":true,"data":[]}"#)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertNil(state.organizationId)
        XCTAssertTrue(state.userOrganizations.isEmpty)
    }
}
