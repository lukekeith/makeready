import XCTest
@testable import MakeReady

@MainActor
final class InvitationDetailActionsTests: XCTestCase {
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

    func testBothDecisionsConfirmAndCancelSendsNothingThenCommittedSuccessPopsDespiteRefreshFailure() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        for action in [InvitationDetailInteraction.Mutation.accept, .reject] {
            interaction.requestConfirmation(action, id: "i1")
            XCTAssertEqual(interaction.confirmation, action)
            interaction.cancelConfirmation()
            await interaction.confirm(id: "i1", navigator: UI2Navigator())
            XCTAssertTrue(api.calls.isEmpty)
        }
        api.stub("POST", "/api/groups/g1/join-requests/i1/approve", json: #"{"success":true}"#)
        // No GET response is supplied: the committed decision must still be a success.
        var popped: [UI2Destination] = []
        interaction.requestConfirmation(.accept, id: "i1")
        await interaction.confirm(id: "i1", navigator: UI2Navigator(popIfTop: { popped.append($0) }))
        XCTAssertEqual(api.callCount("POST", "/api/groups/g1/join-requests/i1/approve"), 1)
        XCTAssertEqual(popped, [.requestDetail(id: "i1")])
        XCTAssertNil(interaction.operation)
        XCTAssertNil(state.activeSurfacedError)
    }
    func testCoalescedSameIDReplacementSuppressesActualActionBannerWithoutLifecycleCallback() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.inviteDetail(id: "i1"))
        let gate = DetailResponseGate()
        api.responseFor = { _, _ in try await gate.response() }
        let task = Task { await interaction.resend(id: "i1", navigator: navigation.navigator) }
        await gate.waitUntilStarted()
        navigation.model.pop(on: .home)
        navigation.model.push(.inviteDetail(id: "i1"), on: .home)
        // No interaction.retire or SwiftUI disappearance callback: the actual model must protect the replacement.
        gate.resolve(.failure(APIHTTPError(status: 502, message: "Delivery failed")))
        await task.value
        XCTAssertNil(state.activeSurfacedError)
        XCTAssertEqual(state.errors.last?.surface, false)
        XCTAssertEqual(navigation.model.path(for: .home), [.inviteDetail(id: "i1")])
        XCTAssertFalse(state.invitationMutationPending("i1"))
    }

    func testCoalescedSameIDReplacementKeepsCommittedReconciliationButNeverPopsNewPage() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.requestDetail(id: "i1"))
        let gate = DetailResponseGate()
        api.responseFor = { method, _ in
            if method == "POST" { return try await gate.response() }
            throw APIHTTPError(status: 503, message: "Refresh failed")
        }
        interaction.requestConfirmation(.accept, id: "i1")
        let task = Task { await interaction.confirm(id: "i1", navigator: navigation.navigator) }
        await gate.waitUntilStarted()
        navigation.model.pop(on: .home)
        navigation.model.push(.requestDetail(id: "i1"), on: .home)
        gate.resolve(.success(Data(#"{"success":true}"#.utf8)))
        await task.value
        XCTAssertNil(state.invitationDetails["i1"])
        XCTAssertTrue(state.invitationDetailsStale.contains("i1"))
        XCTAssertEqual(navigation.model.path(for: .home), [.requestDetail(id: "i1")])
        XCTAssertEqual(navigation.pops, 0)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testDoubleConfirmSendsOnceAndCurrent401StillUsesRealInjectedHandler() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.requestDetail(id: "i1"))
        let gate = DetailResponseGate()
        var signOuts = 0
        api.responseFor = { _, _ in try await gate.response() }
        interaction.requestConfirmation(.reject, id: "i1")
        let task = Task { await interaction.confirm(id: "i1", navigator: navigation.navigator, onUnauthorized: { signOuts += 1 }) }
        await gate.waitUntilStarted()
        await interaction.confirm(id: "i1", navigator: navigation.navigator, onUnauthorized: { signOuts += 1 })
        XCTAssertEqual(api.calls.filter { $0.method == "POST" }.count, 1)
        navigation.model.pop(on: .home)
        gate.resolve(.failure(APIError.unauthorized))
        await task.value
        XCTAssertEqual(signOuts, 1) // Page ownership gates banners, never the current-session 401 policy.
        XCTAssertNil(state.activeSurfacedError)
    }

    func testDispatchCapturesOwnershipBeforeTaskGetsToRun() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.inviteDetail(id: "i1"))
        let task = interaction.startResend(id: "i1", navigator: navigation.navigator)
        navigation.model.pop(on: .home)
        navigation.model.push(.inviteDetail(id: "i1"), on: .home)
        await task?.value
        XCTAssertTrue(api.calls.isEmpty)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testExpiredPendingCapabilitiesAndWithdrawalCancellationThenAuthoritativeChips() async throws {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(status: .expired, canResend: false)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        await interaction.resend(id: "i1", navigator: UI2Navigator())
        XCTAssertTrue(api.calls.isEmpty)
        interaction.requestConfirmation(.withdraw, id: "i1")
        XCTAssertEqual(interaction.prompt(id: "i1")?.title, "Withdraw invitation?")
        XCTAssertEqual(interaction.prompt(id: "i1")?.label, "Withdraw")
        XCTAssertEqual(interaction.prompt(id: "i1")?.destructive, true)
        interaction.cancelConfirmation()
        await interaction.confirm(id: "i1", navigator: UI2Navigator())
        XCTAssertTrue(api.calls.isEmpty)
        let withdrawn = InvitationDetailFixtures.detail(status: .withdrawn, canResend: false, canWithdraw: false)
        api.responses["POST /api/invitations/i1/withdraw"] = try JSONEncoder().encode(withdrawn)
        api.stub("GET", "/api/groups/g1/join-requests", json: #"{"success":true,"requests":[]}"#)
        interaction.requestConfirmation(.withdraw, id: "i1")
        await interaction.confirm(id: "i1", navigator: UI2Navigator())
        let detail = try XCTUnwrap(state.invitationDetails["i1"])
        let output = try XCTUnwrap(InviteDetailMapper.output(detail, busy: false, timeZone: .current))
        XCTAssertEqual(output.state.groupStatuses, ["Withdrawn"])
        XCTAssertFalse(output.canWithdraw)
        XCTAssertEqual(api.callCount("POST", "/api/invitations/i1/withdraw"), 1)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testResendShowsOneNoticeAndCurrentFailureShowsOneActionBannerAfterCleanup() async throws {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let interaction = InvitationDetailInteraction(api: api, state: state)
        api.responses["POST /api/invitations/i1/resend"] = try JSONEncoder().encode(InvitationDetailFixtures.detail())
        api.stub("GET", "/api/groups/g1/join-requests", json: #"{"success":true,"requests":[]}"#)
        await interaction.resend(id: "i1", navigator: UI2Navigator())
        XCTAssertEqual(state.activeSurfacedError?.message, "Invitation resent")
        XCTAssertEqual(state.activeSurfacedError?.kind, .notice)
        XCTAssertTrue(state.errors.isEmpty)
        XCTAssertEqual(api.callCount("POST", "/api/invitations/i1/resend"), 1)
        state.clearErrors()
        api.errorToThrow = APIHTTPError(status: 502, message: "No delivery")
        await interaction.resend(id: "i1", navigator: UI2Navigator())
        XCTAssertEqual(state.errors.count, 1)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't resend the invitation")
        XCTAssertEqual(state.activeSurfacedError?.kind, .error)
        XCTAssertNil(interaction.operation)
        XCTAssertFalse(state.invitationMutationPending("i1"))
    }

    func testRetiredCompletionCannotClearNewOperationOrSignOutNewSession() async throws {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let oldGate = DetailResponseGate(), newGate = DetailResponseGate()
        var posts = 0, signOuts = 0
        api.responseFor = { method, _ in
            if method != "POST" { return Data(#"{"success":true,"requests":[]}"#.utf8) }
            posts += 1
            return try await (posts == 1 ? oldGate : newGate).response()
        }
        let old = interaction.startResend(id: "i1", navigator: UI2Navigator(), onUnauthorized: { signOuts += 1 })
        await oldGate.waitUntilStarted()
        state.clearAllData()
        interaction.retire()
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let next = interaction.startResend(id: "i1", navigator: UI2Navigator(), onUnauthorized: { signOuts += 1 })
        await newGate.waitUntilStarted()
        oldGate.resolve(.failure(APIError.unauthorized))
        await old?.value
        XCTAssertEqual(signOuts, 0)
        XCTAssertEqual(interaction.operation, .resend)
        XCTAssertTrue(state.invitationMutationPending("i1"))
        XCTAssertNil(state.activeSurfacedError)
        newGate.resolve(.success(try JSONEncoder().encode(InvitationDetailFixtures.detail())))
        await next?.value
        XCTAssertNil(interaction.operation)
        XCTAssertFalse(state.invitationMutationPending("i1"))
        XCTAssertEqual(state.activeSurfacedError?.message, "Invitation resent")
    }

    func testResendAfterBackReconcilesWithoutToastAndSharedBusyPreventsAnotherPost() async throws {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail()
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.inviteDetail(id: "i1"))
        let gate = DetailResponseGate()
        api.responseFor = { method, _ in
            if method == "POST" { return try await gate.response() }
            return Data(#"{"success":true,"requests":[]}"#.utf8)
        }
        let task = interaction.startResend(id: "i1", navigator: navigation.navigator)
        await gate.waitUntilStarted()
        let other = InvitationDetailInteraction(api: api, state: state)
        await other.resend(id: "i1", navigator: navigation.navigator)
        XCTAssertEqual(api.calls.filter { $0.method == "POST" }.count, 1)
        navigation.model.pop(on: .home)
        interaction.retire()
        let event = InvitationDetail.Event(id: "event", type: .resent, at: InvitationDetailFixtures.date,
            groupId: "g1", groupName: "Selected group", invitationId: "i1")
        gate.resolve(.success(try JSONEncoder().encode(InvitationDetailFixtures.detail(events: [event]))))
        await task?.value
        XCTAssertEqual(state.invitationDetails["i1"]?.events.first?.type, .resent)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testDecisionCopyAndReviewedRequestCannotOfferAnotherDecision() {
        let interaction = InvitationDetailInteraction(api: api, state: state)
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested, siblingFirst: true)
        interaction.requestConfirmation(.accept, id: "i1")
        XCTAssertEqual(interaction.prompt(id: "i1")?.title, "Accept join request?")
        XCTAssertEqual(interaction.prompt(id: "i1")?.message, "(202) 555-0100 will be added to Selected group.")
        XCTAssertEqual(interaction.prompt(id: "i1")?.destructive, false)
        interaction.requestConfirmation(.reject, id: "i1")
        XCTAssertEqual(interaction.prompt(id: "i1")?.title, "Reject join request?")
        XCTAssertEqual(interaction.prompt(id: "i1")?.message, "(202) 555-0100 will not be added to Selected group.")
        XCTAssertEqual(interaction.prompt(id: "i1")?.destructive, true)
        interaction.cancelConfirmation()
        for status in [InvitationStatus.accepted, .rejected] {
            state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: status)
            interaction.requestConfirmation(.accept, id: "i1")
            XCTAssertNil(interaction.confirmation)
        }
    }

    func testCancelledConfirmationRetainsItsCopyForTheExistingHostDismissal() async {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        interaction.requestConfirmation(.reject, id: "i1")
        interaction.cancelConfirmation()
        XCTAssertNil(interaction.confirmation)
        XCTAssertEqual(interaction.prompt(id: "i1")?.title, "Reject join request?")
        await interaction.confirm(id: "i1", navigator: UI2Navigator())
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testConfirmedRejectPopsAndReopensAsReviewedRequest() async throws {
        state.invitationDetails["i1"] = InvitationDetailFixtures.detail(kind: .request, status: .requested, siblingFirst: true)
        let interaction = InvitationDetailInteraction(api: api, state: state)
        let navigation = DetailNavigationHarness(.requestDetail(id: "i1"))
        api.stub("POST", "/api/groups/g1/join-requests/i1/reject", json: #"{"success":true}"#)
        api.responses["GET /api/invitations/i1"] = try JSONEncoder().encode(
            InvitationDetailFixtures.detail(kind: .request, status: .rejected))
        api.stub("GET", "/api/groups/g1/join-requests", json: #"{"success":true,"requests":[]}"#)
        interaction.requestConfirmation(.reject, id: "i1")
        await interaction.startConfirmation(id: "i1", navigator: navigation.navigator)?.value
        XCTAssertEqual(navigation.pops, 1)
        XCTAssertEqual(api.callCount("POST", "/api/groups/g1/join-requests/i1/reject"), 1)
        let detail = try XCTUnwrap(state.invitationDetails["i1"])
        XCTAssertEqual(try XCTUnwrap(RequestDetailMapper.output(detail, busy: false, timeZone: .current)).state.status, "rejected")
        interaction.requestConfirmation(.reject, id: "i1")
        XCTAssertNil(interaction.confirmation)
    }

}


@MainActor
private final class DetailNavigationHarness {
    var model = UI2ShellModel()
    var pops = 0
    init(_ page: UI2Destination) { model.push(page, on: .home) }
    var navigator: UI2Navigator {
        UI2Navigator(popIfTop: { [self] page in
            let before = model.path(for: .home)
            model.popIfTop(page, on: .home)
            if model.path(for: .home) != before { pops += 1 }
        }, ownership: { [self] in model.navigationOwnership(for: .home) })
    }
}

@MainActor
private final class DetailResponseGate {
    private var pending: CheckedContinuation<Data, Error>?
    private var started: CheckedContinuation<Void, Never>?
    func response() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation; started?.resume(); started = nil
        }
    }
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func resolve(_ result: Result<Data, Error>) { pending?.resume(with: result); pending = nil }
}
