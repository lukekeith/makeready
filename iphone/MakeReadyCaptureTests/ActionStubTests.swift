//
//  ActionStubTests.swift
//  MakeReadyCaptureTests
//
//  First stubbed Action tests (Phase 2.7), using the DI seam from 2.3:
//  Actions constructed with a StubAPIClient and a private AppState so no
//  network or singleton state is touched. Covers load/create/delete happy
//  paths and error recording from 2.5.
//

import XCTest
@testable import MakeReady

@MainActor
final class ActionStubTests: XCTestCase {

    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        // AppState() loads persisted state from disk on init — clear first
        // so tests are deterministic regardless of what captures persisted.
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    private func groupJSON(id: String, name: String) -> String {
        """
        {"id":"\(id)","code":"ABC123","name":"\(name)","isPrivate":false,
         "allowInvites":true,"memberCount":3,"creatorId":"u1",
         "createdAt":"2025-01-15T10:30:00Z","updatedAt":"2025-01-15T10:30:00Z"}
        """
    }

    // MARK: - Load (happy path)

    func testLoadGroupsPopulatesInjectedState() async throws {
        api.stub("GET", "/api/groups", json: """
        {"success":true,"groups":[\(groupJSON(id: "g1", name: "Alpha")),\(groupJSON(id: "g2", name: "Beta"))]}
        """)

        try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true)

        XCTAssertEqual(state.groups.count, 2)
        XCTAssertEqual(state.groups["g1"]?.name, "Alpha")
        XCTAssertEqual(state.groups["g2"]?.memberCount, 3)
        XCTAssertEqual(api.callCount("GET", "/api/groups"), 1)
        // Loading state resolved
        XCTAssertFalse(state.loadingStates.isLoading(.groups))
    }

    // MARK: - Create (happy path)

    func testCreateGroupUpsertsIntoState() async throws {
        api.stub("POST", "/api/groups", json: """
        {"success":true,"group":\(groupJSON(id: "g9", name: "Created"))}
        """)

        let group = try await GroupActions(api: api, state: state).createGroup(name: "Created")

        XCTAssertEqual(group.id, "g9")
        XCTAssertEqual(state.groups["g9"]?.name, "Created")
        // The request carried the name in its body
        let call = try XCTUnwrap(api.calls.first)
        XCTAssertEqual(call.body?["name"] as? String, "Created")
    }

    // MARK: - Delete (happy path)

    func testDeleteGroupRemovesGroupAndRelatedData() async throws {
        // Seed a group with an enrollment relationship
        api.stub("GET", "/api/groups", json: """
        {"success":true,"groups":[\(groupJSON(id: "g1", name: "Alpha"))]}
        """)
        try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true)
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")

        api.stub("DELETE", "/api/groups/g1", json: """
        {"success":true}
        """)
        try await GroupActions(api: api, state: state).deleteGroup(id: "g1")

        XCTAssertNil(state.groups["g1"])
        XCTAssertEqual(state.groupEnrollmentIndex.get("g1"), [])
    }

    // MARK: - Server-reported failure throws

    func testLoadGroupsThrowsOnServerError() async {
        api.stub("GET", "/api/groups", json: """
        {"success":false,"error":"nope"}
        """)

        do {
            try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(state.groups.count, 0)
        }
    }

    // MARK: - Error recording (Phase 2.5 channel)

    func testBackgroundRefreshRecordsErrorIntoChannel() async throws {
        // Cached data present → loadGroups returns immediately and refreshes
        // in a background task; a refresh failure must land in state.errors.
        api.stub("GET", "/api/groups", json: """
        {"success":true,"groups":[\(groupJSON(id: "g1", name: "Alpha"))]}
        """)
        try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true)

        api.errorToThrow = APIError.serverError("boom")
        try await GroupActions(api: api, state: state).loadGroups(forceRefresh: false)

        // The refresh runs in an unstructured Task — yield until it lands.
        for _ in 0..<2000 where state.errors.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(state.errors.count, 1)
        XCTAssertEqual(state.errors.first?.context, "GroupActions.loadGroups (background refresh)")
        // Cached data untouched by the failed refresh
        XCTAssertEqual(state.groups["g1"]?.name, "Alpha")
    }

    // MARK: - Error channel unit behavior

    func testRecordErrorAppendsCapsAndClears() {
        for i in 0..<60 {
            state.recordError(APIError.serverError("e\(i)"), context: "ctx\(i)")
        }
        XCTAssertEqual(state.errors.count, 50, "queue caps at 50")
        XCTAssertEqual(state.errors.first?.context, "ctx10", "oldest dropped first")
        XCTAssertEqual(state.errors.last?.context, "ctx59")

        state.clearErrors()
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testLogoutClearsErrorChannel() {
        state.recordError(APIError.serverError("x"), context: "ctx")
        XCTAssertFalse(state.errors.isEmpty)
        state.clearAllData()
        XCTAssertTrue(state.errors.isEmpty)
    }
}
