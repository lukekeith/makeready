import XCTest
@testable import MakeReady

/// ui2-groups-edit D6/T3: one key per request; nil reaches the server as JSON null.
@MainActor
final class GroupPatchTests: XCTestCase {
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

    private func json(_ patch: GroupPatch) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: patch.body, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func testEachPatchEncodesOneKey() throws {
        XCTAssertEqual(try json(.name("Alpha")), #"{"name":"Alpha"}"#)
        XCTAssertEqual(try json(.description("Hi")), #"{"description":"Hi"}"#)
        XCTAssertEqual(try json(.description(nil)), #"{"description":null}"#)
        XCTAssertEqual(try json(.isPrivate(true)), #"{"isPrivate":true}"#)
        XCTAssertEqual(try json(.maxMembers(40)), #"{"maxMembers":40}"#)
        XCTAssertEqual(try json(.maxMembers(nil)), #"{"maxMembers":null}"#)
        XCTAssertEqual(try json(.memberDirectoryAccess("NAMES_ONLY")), #"{"memberDirectoryAccess":"NAMES_ONLY"}"#)
    }

    func testAgeRangeEncodesNullRangeAndNullBounds() throws {
        XCTAssertEqual(try json(.ageRange(nil)), #"{"ageRange":null}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 26, max: 35))), #"{"ageRange":{"max":35,"min":26}}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 18, max: nil))), #"{"ageRange":{"max":null,"min":18}}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: nil, max: 50))), #"{"ageRange":{"max":50,"min":null}}"#)
    }

    private let groupJSON = #"{"id":"g1","code":"ABC123","name":"Alpha","description":null,"isPrivate":false,"allowInvites":true,"memberDirectory":false,"memberDirectoryAccess":"NAMES_ONLY","ageRange":null,"maxMembers":null,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-01T10:00:00Z","updatedAt":"2026-10-27T10:00:00Z"}"#

    func testUpdateGroupSendsThePatchAndMergesKeepingTheOrg() async throws {
        state.groups.upsert(UserGroup(id: "g1", code: "ABC123", name: "Alpha", isPrivate: false, allowInvites: true,
                                      maxMembers: 40, memberCount: 3, creatorId: "u1", organizationId: "o1",
                                      organizationName: "Grace Church", memberDirectoryAccess: "ALLOWED",
                                      createdAt: Date(), updatedAt: Date()))
        api.stub("PATCH", "/api/groups/g1", json: #"{"success":true,"group":"# + groupJSON + "}")
        let group = try await GroupActions(api: api, state: state).updateGroup(id: "g1", patch: .memberDirectoryAccess("NAMES_ONLY"))
        XCTAssertEqual(api.calls.last?.method, "PATCH")
        XCTAssertEqual(api.calls.last?.body?["memberDirectoryAccess"] as? String, "NAMES_ONLY")
        XCTAssertEqual(api.calls.last?.body?.count, 1)
        XCTAssertEqual(group.memberDirectoryAccess, "NAMES_ONLY")
        XCTAssertNil(state.groups["g1"]?.maxMembers)                 // the response wins
        XCTAssertEqual(state.groups["g1"]?.organizationId, "o1")     // the cached org is kept
    }

    func testUpdateGroupKeepsTheHTTPStatusOfAFailure() async {
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        do {
            _ = try await GroupActions(api: api, state: state).updateGroup(id: "g1", patch: .name("Beta"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: 404, message: "Group not found"))
        }
    }
}
