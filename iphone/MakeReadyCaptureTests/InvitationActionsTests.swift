import XCTest
@testable import MakeReady

@MainActor
final class InvitationActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

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

    private func actions(onUnauthorized: @escaping @MainActor () async -> Void = {}) -> InvitationActions {
        InvitationActions(api: api, state: state, onUnauthorized: onUnauthorized)
    }

    private func feed(_ id: String) -> String {
        #"{"items":[{"id":"\#(id)","kind":"invite","status":"sent","recipientPhone":null,"recipientName":null,"memberId":null,"groupId":null,"groupName":null,"organizationId":"org1","inviterId":null,"inviterName":null,"date":"2026-11-02T12:00:00.000Z","createdAt":"2026-11-02T12:00:00.000Z"}],"total":1,"filters":{"orgs":[],"groups":[],"leaders":[]}}"#
    }

    func testNewQueryReplacesOrderedWindowWhileRetainingEntities() async {
        let query = InvitationQuery(status: .requested)
        api.stub("GET", InvitationQuery().path, json: feed("old"))
        api.stub("GET", query.path, json: feed("new"))
        _ = await actions().loadInvitationFeed(InvitationQuery())
        _ = await actions().loadInvitationFeed(query)
        XCTAssertEqual(state.invitationFeedWindow?.orderedIDs, ["new"])
        XCTAssertEqual(state.invitationFeedWindow?.query, query)
        XCTAssertTrue(state.invitations.contains("old"))
        XCTAssertFalse(state.invitationFeedIsStale)
    }

    private func detail(_ id: String = "r1", status: String = "requested", phone: String? = "+12025550100") -> String {
        let phoneJSON = phone.map { "\"\($0)\"" } ?? "null"
        return #"{"id":"\#(id)","kind":"request","status":"\#(status)","recipientPhone":\#(phoneJSON),"recipientName":null,"inviterName":null,"message":"Private request","createdAt":"2025-01-02T03:04:05.000Z","member":null,"invitations":[{"id":"\#(id)","kind":"request","groupId":"g1","groupName":"Group","groupPicture":null,"status":"\#(status)","date":"2025-01-02T03:04:05.000Z"}],"events":[],"canResend":false,"canWithdraw":false}"#
    }

    private func seedDetail(_ id: String = "r1", status: String = "requested", phone: String? = "+12025550100") throws {
        state.invitationDetails[id] = try JSONDecoder.apiDecoder.decode(InvitationDetail.self, from: Data(detail(id, status: status, phone: phone).utf8))
    }

    private func seedPending(_ id: String = "r1") {
        state.pendingJoinRequestsByGroupId["g1"] = [JoinRequest(
            id: id, status: "pending", message: nil, createdAt: Date(),
            member: JoinRequestMember(id: "m1", firstName: "Ada", lastName: nil, avatarUrl: nil)
        )]
    }

    func testCommittedApprovalRemainsSuccessfulWhenRefreshFails() async throws {
        try seedDetail()
        try seedDetail("sibling")
        seedPending()
        state.groupMemberIndex.add(parentId: "g1", childId: "membership")
        state.invitationFeedWindow = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: ["r1"], total: 1)
        state.invitationFeedQuery = InvitationQuery()
        api.stub("POST", "/api/groups/g1/join-requests/r1/approve", json: #"{"success":true}"#)
        let result = await actions().approveRequest(id: "r1", groupId: "g1")
        guard case .success = result else { return XCTFail("committed approval must remain successful: \(result)") }
        XCTAssertFalse(state.pendingJoinRequestsByGroupId["g1", default: []].contains { $0.id == "r1" })
        XCTAssertNil(state.invitationDetails["r1"])
        XCTAssertNil(state.invitationDetails["sibling"])
        XCTAssertFalse(state.groupMemberIndex.hasChildren("g1"))
        XCTAssertTrue(state.invitationFeedIsStale)
        XCTAssertFalse(state.invitationFeedWindow?.orderedIDs.contains("r1") ?? false)
        XCTAssertTrue(state.errors.allSatisfy { !$0.surface })
    }

    func testPhoneMutationsMergeReturnedDetailAndInvalidateSiblingOnRefreshFailure() async throws {
        for operation in ["resend", "withdraw"] {
            try seedDetail("i1", status: "sent")
            try seedDetail("sibling", status: "accepted")
            try seedDetail("unrelated", status: "sent", phone: nil)
            state.invitationFeedWindow = InvitationFeedWindow(query: InvitationQuery(), orderedIDs: ["i1", "unrelated"], total: 2)
            state.invitationFeedQuery = InvitationQuery()
            let status = operation == "withdraw" ? "withdrawn" : "sent"
            api.stub("POST", "/api/invitations/i1/\(operation)", json: detail("i1", status: status))
            let result = operation == "withdraw" ? await actions().withdrawInvitation("i1") : await actions().resendInvitation("i1")
            guard case .success = result else { return XCTFail("committed mutation must remain successful: \(result)") }
            XCTAssertEqual(state.invitationDetails["i1"]?.status.rawValue, status)
            XCTAssertNil(state.invitationDetails["sibling"])
            XCTAssertNotNil(state.invitationDetails["unrelated"])
            XCTAssertTrue(state.invitationFeedIsStale)
            XCTAssertFalse(state.invitationMutationPending("i1"))
            if operation == "withdraw" { XCTAssertEqual(state.invitationFeedWindow?.orderedIDs, ["unrelated"]) }
        }
    }

    func testOlderAResponseCannotReplaceNewAAfterSwitchingThroughB() async throws {
        let gate = InvitationResponseGate()
        var count = 0
        api.responseFor = { _, _ in
            count += 1
            if count == 1 { return try await gate.response() }
            return Data(self.feed(count == 2 ? "b" : "new-a").utf8)
        }
        let old = Task { await actions().loadInvitationFeed(InvitationQuery()) }
        await gate.waitUntilStarted()
        _ = await actions().loadInvitationFeed(InvitationQuery(groupId: "g1"))
        _ = await actions().loadInvitationFeed(InvitationQuery())
        gate.resolve(.success(Data(feed("old-a").utf8)))
        _ = await old.value
        XCTAssertEqual(state.invitationFeedWindow?.orderedIDs, ["new-a"])
        XCTAssertNil(state.invitations["old-a"])
        XCTAssertEqual(api.statusEndpoints.count, 3)
    }

    func testCancelledNonCooperativeFeedCompletionIsQuietAndCannotMerge() async {
        let gate = InvitationResponseGate()
        api.responseFor = { _, _ in try await gate.response() }
        let task = Task { await actions().loadInvitationFeed(InvitationQuery()) }
        await gate.waitUntilStarted()
        task.cancel()
        gate.resolve(.success(Data(feed("cancelled").utf8)))
        let result = await task.value
        assertFailure(result, .cancelled)
        XCTAssertNil(state.invitationFeedWindow)
        XCTAssertTrue(state.invitations.isEmpty)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testRetiredUnauthorizedMutationCannotSignOutOrClearReplacementBusyState() async throws {
        try seedDetail("i1", status: "sent")
        let oldGate = InvitationResponseGate()
        let newGate = InvitationResponseGate()
        var writes = 0
        var signOuts = 0
        api.responseFor = { method, _ in
            if method == "GET" { return Data(#"{"success":true,"requests":[]}"#.utf8) }
            writes += 1
            return try await (writes == 1 ? oldGate : newGate).response()
        }
        let old = Task { await actions(onUnauthorized: { signOuts += 1 }).withdrawInvitation("i1") }
        await oldGate.waitUntilStarted()
        state.clearAllData()
        try seedDetail("i1", status: "sent")
        let replacement = Task { await actions(onUnauthorized: { signOuts += 1 }).withdrawInvitation("i1") }
        await newGate.waitUntilStarted()
        oldGate.resolve(.failure(APIError.unauthorized))
        assertFailure(await old.value, .cancelled)
        XCTAssertEqual(signOuts, 0)
        XCTAssertTrue(state.invitationMutationPending("i1"))
        XCTAssertTrue(state.errors.isEmpty)
        newGate.resolve(.success(Data(detail("i1", status: "withdrawn").utf8)))
        assertSuccess(await replacement.value)
        XCTAssertFalse(state.invitationMutationPending("i1"))
        XCTAssertEqual(state.invitationDetails["i1"]?.status, .withdrawn)
    }

    func testCurrentUnauthorizedIsHandledOncePerEpochAndForbiddenDoesNotSignOut() async {
        var signOuts = 0
        api.errorToThrow = APIError.unauthorized
        assertFailure(await actions(onUnauthorized: { signOuts += 1 }).loadInvitationFeed(InvitationQuery()), .unauthorized)
        assertFailure(await actions(onUnauthorized: { signOuts += 1 }).loadInvitation("i1"), .unauthorized)
        XCTAssertEqual(signOuts, 1)
        XCTAssertTrue(state.errors.isEmpty)
        api.errorToThrow = APIHTTPError(status: 403, message: "Denied")
        assertFailure(await actions(onUnauthorized: { signOuts += 1 }).loadInvitation("i1"), .forbidden)
        XCTAssertEqual(signOuts, 1)
        XCTAssertEqual(state.errors.last?.surface, false)
    }

    func testWrappedTransportCancellationIsQuiet() async {
        api.errorToThrow = APIError.networkError(URLError(.cancelled))
        assertFailure(await actions().loadInvitationFeed(InvitationQuery()), .cancelled)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testOldDetailAndPendingReadsCannotResurrectReviewedRequest() async throws {
        try seedDetail()
        seedPending()
        let detailGate = InvitationResponseGate()
        let pendingGate = InvitationResponseGate()
        var detailReads = 0
        var pendingReads = 0
        api.responseFor = { method, path in
            if method == "POST" { return Data(#"{"success":true}"#.utf8) }
            if path == "/api/invitations/r1" {
                detailReads += 1
                if detailReads == 1 { return try await detailGate.response() }
                return Data(self.detail(status: "rejected").utf8)
            }
            pendingReads += 1
            if pendingReads == 1 { return try await pendingGate.response() }
            return Data(#"{"success":true,"requests":[]}"#.utf8)
        }
        let detailRead = Task { await actions().loadInvitation("r1") }
        let pendingRead = Task { try await GroupActions(api: api, state: state).loadJoinRequests(groupId: "g1") }
        await detailGate.waitUntilStarted()
        await pendingGate.waitUntilStarted()
        assertSuccess(await actions().rejectRequest(id: "r1", groupId: "g1"))
        detailGate.resolve(.success(Data(detail().utf8)))
        pendingGate.resolve(.success(Data(#"{"success":true,"requests":[{"id":"r1","status":"pending","message":null,"createdAt":"2026-11-02T12:00:00Z","member":{"id":"m1","firstName":"Ada","lastName":null,"avatarUrl":null}}]}"#.utf8)))
        assertFailure(await detailRead.value, .cancelled)
        do { _ = try await pendingRead.value; XCTFail("old pending read must retire") } catch is CancellationError {
            // Expected: a committed decision retired this older same-session request read.
        } catch { XCTFail("Unexpected \(error)") }
        XCTAssertEqual(state.invitationDetails["r1"]?.status, .rejected)
        XCTAssertTrue(state.pendingJoinRequestsByGroupId["g1", default: []].isEmpty)
    }

    func testDirectLegacyDecisionsCannotMutateReplacementSession() async {
        for approving in [true, false] {
            api.beforeReturn = { _, _ in
                self.state.clearAllData()
                self.seedPending()
            }
            api.stub("POST", "/api/groups/g1/join-requests/r1/\(approving ? "approve" : "reject")", json: #"{"success":true}"#)
            do {
                let groups = GroupActions(api: api, state: state)
                if approving { try await groups.approveJoinRequest(groupId: "g1", requestId: "r1") }
                else { try await groups.rejectJoinRequest(groupId: "g1", requestId: "r1") }
                XCTFail("retired mutation must not return navigable success")
            } catch is CancellationError {
                // Expected: reused GroupActions guards its own writes, not just the new wrapper.
            } catch { XCTFail("Unexpected \(error)") }
            XCTAssertEqual(state.pendingJoinRequestsByGroupId["g1"]?.first?.id, "r1")
        }
    }

    func testLegacyCreateAndSendInvalidateProjectionsWithoutWireChanges() async throws {
        api.stub("POST", "/api/invites", json: #"{"success":true,"invite":{"id":"i1","code":"CODE","groupId":"g1","createdAt":"2026-11-02T12:00:00Z","expiresAt":null,"userId":"u1"}}"#)
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"i1"}"#)
        for creating in [true, false] {
            try seedDetail()
            seedPending()
            state.invitationFeedIsStale = false
            state.groupMemberIndex.add(parentId: "g1", childId: "membership")
            let legacy = InviteActions(api: api, state: state)
            let id: String
            if creating { id = try await legacy.createInvite(groupId: "g1").id }
            else { id = try await legacy.sendInvite(groupId: "g1", recipientPhone: "+12025550100", recipientName: "Ada") }
            XCTAssertEqual(id, "i1")
            XCTAssertTrue(state.invitationFeedIsStale)
            XCTAssertTrue(state.invitationDetails.isEmpty)
            XCTAssertNil(state.pendingJoinRequestsByGroupId["g1"])
            XCTAssertFalse(state.groupMemberIndex.hasChildren("g1"))
        }
    }

    func testRetiredLegacySendDoesNotInvalidateNewSession() async throws {
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"i1"}"#)
        api.beforeReturn = { _, _ in
            self.state.clearAllData()
            self.state.invitationFeedIsStale = false
            self.seedPending()
        }
        do {
            _ = try await InviteActions(api: api, state: state).sendInvite(groupId: "g1", recipientPhone: "+12025550100", recipientName: "Ada")
            XCTFail("retired send must not report current success")
        } catch is CancellationError {
            // Expected: old send cannot invalidate the replacement session's pending requests.
        }
        XCTAssertFalse(state.invitationFeedIsStale)
        XCTAssertEqual(state.pendingJoinRequestsByGroupId["g1"]?.first?.id, "r1")
    }

    func testPhoneSiblingMutationIsBusyUntilFirstOperationFinishes() async throws {
        try seedDetail("i1", status: "sent")
        try seedDetail("sibling", status: "sent")
        let gate = InvitationResponseGate()
        api.responseFor = { method, _ in
            if method == "POST" { return try await gate.response() }
            return Data(#"{"success":true,"requests":[]}"#.utf8)
        }
        let first = Task { await actions().resendInvitation("i1") }
        await gate.waitUntilStarted()
        assertFailure(await actions().withdrawInvitation("sibling"), .busy)
        XCTAssertEqual(api.calls.filter { $0.method == "POST" }.count, 1)
        gate.resolve(.success(Data(detail("i1", status: "sent").utf8)))
        assertSuccess(await first.value)
        XCTAssertFalse(state.invitationMutationPending("i1"))
    }

    func testMutationHTTPErrorsSurfaceAfterBusyCleanup() async throws {
        let cases: [(Int, InvitationActionError)] = [(403, .forbidden), (404, .notFound), (409, .conflict), (502, .deliveryFailed)]
        for (status, expected) in cases {
            try seedDetail("i1", status: "sent")
            state.clearErrors()
            api.errorToThrow = APIHTTPError(status: status, message: "Wire error")
            assertFailure(await actions().resendInvitation("i1"), expected)
            XCTAssertFalse(state.invitationMutationPending("i1"))
            XCTAssertEqual(state.errors.last?.surface, true)
            XCTAssertEqual(state.errors.last?.message, "Couldn't resend the invitation")
        }
    }

    func testRequestDecisionsPreserveHTTPStatusThroughReusedGroupActions() async {
        api.errorToThrow = APIHTTPError(status: 409, message: "Already reviewed")
        assertFailure(await actions().approveRequest(id: "r1", groupId: "g1"), .conflict)
        assertFailure(await actions().rejectRequest(id: "r1", groupId: "g1"), .conflict)
        XCTAssertTrue(api.statusEndpoints.contains("/api/groups/g1/join-requests/r1/approve"))
        XCTAssertTrue(api.statusEndpoints.contains("/api/groups/g1/join-requests/r1/reject"))
    }

    func testNullPhoneConflictDoesNotInvalidateAnotherNullPhoneIdentity() async throws {
        try seedDetail("i1", status: "sent", phone: nil)
        try seedDetail("other", status: "sent", phone: nil)
        api.errorToThrow = APIHTTPError(status: 409, message: "Nothing eligible")
        assertFailure(await actions().withdrawInvitation("i1"), .conflict)
        XCTAssertNotNil(state.invitationDetails["i1"])
        XCTAssertNotNil(state.invitationDetails["other"])
    }

    func testEnvironmentTeardownRejectsLateReadAndPersonalDataNeverPersists() async throws {
        api.stub("GET", InvitationQuery().path, json: feed("private-id"))
        _ = await actions().loadInvitationFeed(InvitationQuery())
        try seedDetail("private-detail")
        let persisted = String(decoding: try JSONEncoder().encode(PersistedState(from: state)), as: UTF8.self)
        for marker in ["private-id", "private-detail", "+12025550100", "Private request"] { XCTAssertFalse(persisted.contains(marker)) }
        let gate = InvitationResponseGate()
        api.responseFor = { _, _ in try await gate.response() }
        let read = Task { await actions().loadInvitationFeed(InvitationQuery()) }
        await gate.waitUntilStarted()
        state.reloadForEnvironmentSwitch()
        gate.resolve(.success(Data(feed("old-environment").utf8)))
        assertFailure(await read.value, .cancelled)
        XCTAssertTrue(state.invitations.isEmpty)
        XCTAssertTrue(state.invitationDetails.isEmpty)
        XCTAssertNil(state.invitationFilters)
        XCTAssertNil(state.invitationFeedWindow)
        XCTAssertNil(state.invitationFeedQuery)
        XCTAssertTrue(state.invitationMutationOperations.isEmpty)
        XCTAssertTrue(state.invitationDetailsStale.isEmpty)
    }

    private func assertSuccess(_ result: Result<Void, InvitationActionError>, file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let error) = result { XCTFail("Expected success, got \(error)", file: file, line: line) }
    }

    func testDetailOnlySiblingStaysBusyAfterExternalCacheInvalidation() async throws {
        try seedDetail("a", status: "sent")
        try seedDetail("b", status: "sent")
        let gate = InvitationResponseGate()
        api.responseFor = { method, path in
            if path == "/api/invitations/a/resend" { return try await gate.response() }
            if method == "POST" { throw APIHTTPError(status: 409, message: "Unexpected second mutation") }
            return Data(#"{"success":true,"requests":[]}"#.utf8)
        }
        let first = Task { await actions().resendInvitation("a") }
        await gate.waitUntilStarted()
        state.invalidateInvitationSend(groupId: "g1")
        XCTAssertTrue(state.invitationMutationPending("b"))
        assertFailure(await actions().withdrawInvitation("b"), .busy)
        XCTAssertEqual(api.calls.filter { $0.method == "POST" }.count, 1)
        gate.resolve(.success(Data(detail("a", status: "sent").utf8)))
        assertSuccess(await first.value)
        XCTAssertFalse(state.invitationMutationPending("a"))
        XCTAssertFalse(state.invitationMutationPending("b"))
    }

    func testDetailOnlySiblingStaysBusyDuringPostCommitReconciliation() async throws {
        try seedDetail("a", status: "sent")
        try seedDetail("b", status: "sent")
        let gate = InvitationResponseGate()
        api.responseFor = { method, path in
            if path == "/api/invitations/a/resend" { return Data(self.detail("a", status: "sent").utf8) }
            if method == "POST" { throw APIHTTPError(status: 409, message: "Unexpected second mutation") }
            return try await gate.response()
        }
        let first = Task { await actions().resendInvitation("a") }
        await gate.waitUntilStarted()
        XCTAssertNil(state.invitationDetails["b"])
        XCTAssertTrue(state.invitationMutationPending("b"))
        assertFailure(await actions().withdrawInvitation("b"), .busy)
        XCTAssertEqual(api.calls.filter { $0.method == "POST" }.count, 1)
        gate.resolve(.success(Data(#"{"success":true,"requests":[]}"#.utf8)))
        assertSuccess(await first.value)
        XCTAssertFalse(state.invitationMutationPending("b"))
    }

    func testActualSendCallerDiscardsRetiredSuccessWithoutBanner() async {
        let gate = InvitationResponseGate()
        api.responseFor = { _, _ in try await gate.response() }
        let send = Task {
            await InviteMemberSend.run(groupId: "g1", name: "Ada", phone: "+12025550100",
                                       actions: InviteActions(api: api, state: state), state: state)
        }
        await gate.waitUntilStarted()
        state.clearAllData()
        gate.resolve(.success(Data(#"{"success":true,"inviteId":"i1"}"#.utf8)))
        let result = await send.value
        XCTAssertFalse(result)
        XCTAssertTrue(state.errors.isEmpty)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testDirectPendingReadAttemptCannotSignOutReplacementOnLate401() async {
        let gate = InvitationResponseGate()
        var signOuts = 0
        api.responseFor = { _, _ in try await gate.response() }
        let read = Task {
            await GroupDetailContainer.attempt("loadJoinRequests", state: state, onUnauthorized: { signOuts += 1 }) {
                _ = try await GroupActions(api: api, state: state).loadJoinRequests(groupId: "g1")
            }
        }
        await gate.waitUntilStarted()
        state.clearAllData()
        gate.resolve(.failure(APIError.unauthorized))
        await read.value
        XCTAssertEqual(signOuts, 0)
        XCTAssertTrue(state.errors.isEmpty)
        api.responseFor = nil
        api.errorToThrow = APIError.unauthorized
        await GroupDetailContainer.attempt("loadJoinRequests", state: state, onUnauthorized: { signOuts += 1 }) {
            _ = try await GroupActions(api: api, state: state).loadJoinRequests(groupId: "g1")
        }
        XCTAssertEqual(signOuts, 1)
    }

    func testSupersededPendingReadNormalizesLate401BeforeCallerRouting() async {
        let gate = InvitationResponseGate()
        var reads = 0
        var signOuts = 0
        api.responseFor = { _, _ in
            reads += 1
            if reads == 1 { return try await gate.response() }
            return Data(#"{"success":true,"requests":[]}"#.utf8)
        }
        let old = Task {
            await GroupDetailContainer.attempt("loadJoinRequests", state: state, onUnauthorized: { signOuts += 1 }) {
                _ = try await GroupActions(api: api, state: state).loadJoinRequests(groupId: "g1")
            }
        }
        await gate.waitUntilStarted()
        do { _ = try await GroupActions(api: api, state: state).loadJoinRequests(groupId: "g1") }
        catch { XCTFail("Unexpected \(error)") }
        gate.resolve(.failure(APIError.unauthorized))
        await old.value
        XCTAssertEqual(signOuts, 0)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testRetiredTransportFailuresNormalizeAtAllTouchedLegacyBoundaries() async {
        api.errorToThrow = APIError.unauthorized
        api.beforeReturn = { _, _ in self.state.clearAllData() }
        let operations: [() async throws -> Void] = [
            { _ = try await InviteActions(api: self.api, state: self.state).createInvite() },
            { _ = try await InviteActions(api: self.api, state: self.state).sendInvite(groupId: "g1", recipientPhone: "+12025550100", recipientName: "Ada") },
            { try await GroupActions(api: self.api, state: self.state).approveJoinRequest(groupId: "g1", requestId: "r1") },
            { try await GroupActions(api: self.api, state: self.state).rejectJoinRequest(groupId: "g1", requestId: "r1") },
            { _ = try await GroupActions(api: self.api, state: self.state).loadJoinRequests(groupId: "g1") }
        ]
        for operation in operations {
            do { try await operation(); XCTFail("Expected retired operation") }
            catch { XCTAssertTrue(GroupActions.isCancellation(error), "Unexpected \(error)") }
        }
    }

    private func assertFailure(_ result: Result<Void, InvitationActionError>, _ expected: InvitationActionError,
                               file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let error) = result { XCTAssertEqual(error, expected, file: file, line: line) }
        else { XCTFail("Expected \(expected)", file: file, line: line) }
    }
}

/// External HTTP barrier: deliberately non-cooperative so cancellation and retirement are tested.
@MainActor
private final class InvitationResponseGate {
    private var pending: CheckedContinuation<Data, Error>?
    private var started: CheckedContinuation<Void, Never>?

    func response() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func resolve(_ result: Result<Data, Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}
