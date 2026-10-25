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
}
