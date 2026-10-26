import XCTest
@testable import MakeReady

/// ui2-members-browse T10: MemberActions writes the in-memory member stores; a 401 signs out,
/// any other failure is recorded and keeps the store (ui2-shell D28); D21 keeps it off disk.
@MainActor
final class MemberActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    private let directoryJSON = #"{"success":true,"data":[{"id":"m1","firstName":"Barry","lastName":"Allen","profilePicture":null,"googlePicture":null,"joinedAt":"2026-10-25T14:03:22.123Z","groupCount":2},{"id":"m2","firstName":"Clark","lastName":"Kent","joinedAt":"2026-07-25T00:00:00.000Z","groupCount":1}],"count":2,"viewerScope":{"all":false,"groupIds":["g1"]}}"#

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

    private func actions(onUnauthorized: @escaping @MainActor () async -> Void = {}) -> MemberActions {
        MemberActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: onUnauthorized)
    }

    func testDirectoryLandsUnderItsOrgWithTheQueryAndScope() async {
        api.stub("GET", "/api/organizations/org1/members", json: directoryJSON)
        await actions().loadDirectory(orgId: "org1")
        let directory = state.orgMembersByOrgId["org1"]
        XCTAssertEqual(directory?.members.map(\.id), ["m1", "m2"])          // server order kept (D6)
        XCTAssertEqual(directory?.search, "")
        XCTAssertNil(directory?.groupId)
        XCTAssertEqual(directory?.viewerScope, ViewerScope(all: false, groupIds: ["g1"]))
    }

    func testDirectoryQuerySendsTrimmedSearchAndBothFilters() async {
        let path = "/api/organizations/org1/members?search=clark%20%20kent&groupId=g1&leaderId=u1"
        api.stub("GET", path, json: directoryJSON)
        await actions().loadDirectory(orgId: "org1", search: "  clark  kent \n", groupId: "g1", leaderId: "u1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.search, "clark  kent")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.leaderId, "u1")
    }

    func testPathDropsEmptyValuesAndEncodesTheRest() {
        XCTAssertEqual(MemberActions.path("/a", [("search", ""), ("groupId", "g1")]), "/a?groupId=g1")
        XCTAssertEqual(MemberActions.path("/a", [("tz", "Etc/GMT+5")]), "/a?tz=Etc/GMT%2B5")
        XCTAssertEqual(MemberActions.path("/a", []), "/a")
    }

    func testFailedDirectoryKeepsTheCachedEntryAndRecords() async {
        let cached = OrgMemberDirectory(members: [OrgMemberListItem(id: "m9", firstName: "Cached")])
        state.orgMembersByOrgId["org1"] = cached
        api.errorFor = { _, _ in APIError.serverError("boom") }
        await actions().loadDirectory(orgId: "org1", search: "x")
        XCTAssertEqual(state.orgMembersByOrgId["org1"], cached)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadDirectory")
    }

    func testUnauthorizedSignsOutAndWritesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        await actions(onUnauthorized: { signedOut = true }).loadMember("m1")
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.memberDetails["m1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// T13: a newer keystroke cancels the older search — the cancelled load is no error.
    func testCancelledLoadWritesAndRecordsNothing() async {
        api.stub("GET", "/api/organizations/org1/members?search=b", json: directoryJSON)
        api.delayFor = { _ in 0.5 }
        let memberActions = actions()
        let task = Task { @MainActor in await memberActions.loadDirectory(orgId: "org1", search: "b") }
        task.cancel()
        await task.value
        XCTAssertNil(state.orgMembersByOrgId["org1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testLoadMemberUpsertsTheDetail() async {
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890","firstName":"Tony","address":"10880 Malibu Point","isGroupLeader":true}}"#)
        await actions().loadMember("m1")
        XCTAssertEqual(state.memberDetails["m1"]?.firstName, "Tony")
        XCTAssertEqual(state.memberDetails["m1"]?.address, "10880 Malibu Point")
        XCTAssertEqual(state.memberDetails["m1"]?.isGroupLeader, true)
    }

    func testOutOfScopeMemberIsRecordedNotSurfaced() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Cached"))
        api.errorFor = { _, _ in APIError.serverError("Member not found") }       // D7: 404 outside scope
        await actions().loadMember("m1")
        XCTAssertEqual(state.memberDetails["m1"]?.firstName, "Cached")
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadMember")
        XCTAssertEqual(state.errors.last?.surface, false)
    }

    func testGroupsAndEngagementLandByMember() async {
        api.stub("GET", "/api/members/m1/groups", json: #"{"success":true,"data":[{"id":"g1","name":"Young professionals","joinedAt":"2025-07-03T16:00:00.000Z","creator":{"id":"u2","name":"Luke Keith"}}],"count":1}"#)
        api.stub("GET", "/api/members/m1/engagement?tz=America/Denver", json: #"{"programs":[{"enrollmentId":"e1","title":"Daily Inspiration","completedCount":12,"totalCount":30,"hours":15,"percent":68}]}"#)
        await actions().loadMemberGroups("m1")
        await actions().loadEngagement("m1")
        XCTAssertEqual(state.memberGroupsById["m1"]?.map(\.name), ["Young professionals"])
        XCTAssertEqual(state.memberEngagementById["m1"]?.programs.first?.hours, 15)
    }

    /// D12: the 30 local days ending today, filtered to the member; the org narrows when known.
    func testDaysCoverTheThirtyDaysEndingToday() async {
        state.organizationId = "org1"
        let path = "/api/home/days?from=2026-09-26&to=2026-10-25&tz=America/Denver&memberId=m1&organizationId=org1"
        api.stub("GET", path, json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0],"lastActivityAt":"2026-10-24T13:20:00.000Z"}]}"#)
        await actions().loadMemberDays("m1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.memberDaysById["m1"]?.first?.lastActivityAt, "2026-10-24T13:20:00.000Z")
    }

    /// A sign-out while the request is in flight retires the old session's result.
    func testSignOutMidLoadDropsTheResult() async {
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","firstName":"Tony"}}"#)
        api.beforeReturn = { _, _ in self.state.clearAllData() }
        await actions().loadMember("m1")
        XCTAssertNil(state.memberDetails["m1"])
    }

    func testFilterOptionsUnauthorizedSignsOut() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = 0
        await actions(onUnauthorized: { signedOut += 1 }).loadFilterOptions()
        XCTAssertGreaterThanOrEqual(signedOut, 1)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testClearAllDataEmptiesEveryMemberStore() {
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m1")])
        state.memberDetails.upsert(MemberDetail(id: "m1"))
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1")]
        state.memberEngagementById["m1"] = MemberEngagement(programs: [MemberEngagementProgram(title: "R")])
        state.memberDaysById["m1"] = [HomeDay(day: "2026-10-25")]
        state.clearAllData()
        XCTAssertEqual(state.orgMembersByOrgId, [:])
        XCTAssertNil(state.memberDetails["m1"])
        XCTAssertTrue(state.memberGroupsById.isEmpty)
        XCTAssertTrue(state.memberEngagementById.isEmpty)
        XCTAssertTrue(state.memberDaysById.isEmpty)
    }

    /// D21: addresses and emergency contacts never reach the device's disk cache.
    func testMemberStoresNeverReachTheDiskCache() throws {
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Tony", address: "10880 Malibu Point",
                                                emergencyContactName: "Pepper Potts"))
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m2", firstName: "Barry")])
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1", name: "Young professionals")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(PersistedState(from: state)), as: UTF8.self)
        for secret in ["Malibu", "Pepper", "Barry", "Tony", "Young professionals"] {
            XCTAssertFalse(json.contains(secret), secret)
        }
    }

    // MARK: - ui2-members-edit Task 8: updateMember (T6, T7 — D13, D15, D21)

    private func isSuccess(_ result: Result<Void, MemberSaveError>) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func failure(_ result: Result<Void, MemberSaveError>) -> MemberSaveError? {
        if case .failure(let error) = result { return error }
        return nil
    }

    private func patchCall() -> StubAPIClient.RecordedCall? { api.calls.first { $0.method == "PATCH" } }

    /// T6: the status survives; 401 stays `.unauthorized` (sign-out policy unchanged).
    func testStatusErrorKeepsTheStatusAndTheServersMessage() {
        XCTAssertNil(APIClient.statusError(status: 200, data: Data()))
        XCTAssertNil(APIClient.statusError(status: 204, data: Data()))
        let unauthorized = APIClient.statusError(status: 401, data: Data(#"{"error":"nope"}"#.utf8))
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: unauthorized ?? APIError.invalidResponse))
        let taken = Data(#"{"success":false,"error":"That number belongs to another member","code":"PHONE_TAKEN"}"#.utf8)
        XCTAssertEqual(APIClient.statusError(status: 409, data: taken) as? APIHTTPError,
                       APIHTTPError(status: 409, message: "That number belongs to another member"))
        XCTAssertEqual(APIClient.statusError(status: 502, data: Data("<html>".utf8)) as? APIHTTPError,
                       APIHTTPError(status: 502, message: nil))
    }

    /// D15: the wire keys, and a clear is JSON null.
    func testPatchKeysAreTheWireKeysAndNilIsNull() {
        let patches: [MemberPatch] = [.email(nil), .phoneNumber("+1"), .birthday(nil), .gender(nil), .address(nil),
                                      .emergencyContactName(nil), .emergencyContactPhone(nil)]
        XCTAssertEqual(patches.map(\.key), ["email", "phoneNumber", "birthday", "gender", "address",
                                            "emergencyContactName", "emergencyContactPhone"])
        XCTAssertTrue(MemberPatch.gender(nil).jsonValue is NSNull)
        XCTAssertEqual(MemberPatch.gender("male").jsonValue as? String, "male")
        XCTAssertEqual(MemberPatch.address("1 Main").body.keys.sorted(), ["address"])
    }

    /// D15: one key PATCHed, then the member re-read with GET (the reload wins).
    func testUpdateMemberPatchesOneKeyThenReloads() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", email: "old@stark.example"))
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1"}}"#)
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","phoneVerified":true,"email":"new@stark.example"}}"#)
        let result = await actions().updateMember("m1", .email("new@stark.example"))
        XCTAssertTrue(isSuccess(result))
        XCTAssertEqual(patchCall()?.endpoint, "/api/members/m1")
        XCTAssertEqual(patchCall()?.body?.keys.sorted(), ["email"])
        XCTAssertEqual(patchCall()?.body?["email"] as? String, "new@stark.example")
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 1)
        XCTAssertEqual(state.memberDetails["m1"]?.email, "new@stark.example")
        XCTAssertEqual(state.memberDetails["m1"]?.phoneVerified, true)
    }

    /// D8 / D15: a clear sends JSON null for the one key.
    func testClearSendsJSONNull() async {
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1"}}"#)
        _ = await actions().updateMember("m1", .address(nil))
        XCTAssertEqual(patchCall()?.body?.keys.sorted(), ["address"])
        XCTAssertTrue(patchCall()?.body?["address"] is NSNull)
    }

    /// D13: 409 → the server's text; nothing written, no reload, nothing recorded.
    func test409ReturnsTheServersMessageAndWritesNothing() async {
        let before = MemberDetail(id: "m1", phoneNumber: "+15550100009")
        state.memberDetails.upsert(before)
        api.errorFor = { _, body in
            body == nil ? nil : APIHTTPError(status: 409, message: "That number belongs to another member") as Error
        }
        let result = await actions().updateMember("m1", .phoneNumber("+15550100001"))
        XCTAssertEqual(failure(result), .validation("That number belongs to another member"))
        XCTAssertEqual(state.memberDetails["m1"], before)
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 0)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D13: 400 carries the server's text; a missing one falls back to the generic line.
    func test400CarriesTheMessageOrTheFallback() async {
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 400, message: "Enter a valid email") as Error }
        let invalid = await actions().updateMember("m1", .email("a@b"))
        XCTAssertEqual(failure(invalid), .validation("Enter a valid email"))
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 400, message: nil) as Error }
        let blank = await actions().updateMember("m1", .phoneNumber("+15550100001"))
        XCTAssertEqual(failure(blank), .validation("Couldn't save. Try again."))
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D13: a 403 is "any other failure" — generic, its server text never shown.
    func test403IsGenericNotTheServerText() async {
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 403, message: "Forbidden by role") as Error }
        let refused = await actions().updateMember("m1", .phoneNumber("+15550100001"))
        XCTAssertEqual(failure(refused), .generic)
    }

    /// D13: anything else — 500, 404, a network failure — is generic, recorded console-only.
    func test500IsGenericAndRecordedConsoleOnly() async {
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 500, message: "Failed to update member") as Error }
        let crashed = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(crashed), .generic)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.updateMember")
        XCTAssertEqual(state.errors.last?.surface, false)
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 404, message: "Member not found") as Error }
        let hidden = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(hidden), .generic)
    }

    /// ui2-shell D27: a 401 signs out and records nothing.
    func testUnauthorizedSaveSignsOut() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let result = await actions(onUnauthorized: { signedOut = true }).updateMember("m1", .gender("male"))
        XCTAssertTrue(signedOut)
        XCTAssertEqual(failure(result), .generic)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// T7: a sign-out while the PATCH is in flight retires the generation — the result writes
    /// nothing and the reload is skipped (as testSignOutMidLoadDropsTheResult does for loads).
    func testSignOutMidSaveWritesNothingAndSkipsTheReload() async {
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.beforeReturn = { _, body in
            guard body != nil else { return }
            self.state.clearAllData()
            self.state.memberDetails.upsert(MemberDetail(id: "m1", gender: "female"))
        }
        let result = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(result), .generic)
        XCTAssertEqual(state.memberDetails["m1"]?.gender, "female")
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 0)
    }

    /// D21: the sent value shows even when the reload fails; a changed phone is unverified (D5).
    func testSavedValueShowsEvenWhenTheReloadFails() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true))
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.errorFor = { _, body in body == nil ? APIError.serverError("boom") as Error : nil }
        let result = await actions().updateMember("m1", .phoneNumber("+15555550123"))
        XCTAssertTrue(isSuccess(result))
        XCTAssertEqual(state.memberDetails["m1"]?.phoneNumber, "+15555550123")
        XCTAssertEqual(state.memberDetails["m1"]?.phoneVerified, false)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadMember")
    }

    /// D21 / D5: only the sent key changes; an unchanged phone keeps its verification.
    func testApplyingWritesTheSentKeyOnly() {
        let d = MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true, email: "a@b.example")
        XCTAssertEqual(MemberActions.applying(.phoneNumber("+15550100009"), to: d).phoneVerified, true)
        XCTAssertEqual(MemberActions.applying(.phoneNumber("+15550100001"), to: d).phoneVerified, false)
        XCTAssertEqual(MemberActions.applying(.birthday("1974-06-25"), to: d).birthday, "1974-06-25T00:00:00.000Z")
        XCTAssertNil(MemberActions.applying(.birthday(nil), to: d).birthday)
        XCTAssertNil(MemberActions.applying(.email(nil), to: d).email)
        XCTAssertEqual(MemberActions.applying(.email(nil), to: d).phoneNumber, "+15550100009")
        XCTAssertEqual(MemberActions.applying(.emergencyContactPhone("555-1234 x2"), to: d).emergencyContactPhone, "555-1234 x2")
    }
}
