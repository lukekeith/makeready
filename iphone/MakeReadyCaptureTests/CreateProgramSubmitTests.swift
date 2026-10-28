import XCTest
@testable import MakeReady

/// ui2-programs D8: create from a title — trimmed, stored on success; a failure is the inline
/// "Couldn't create the program"; a 401 signs out and shows nothing.
@MainActor
final class CreateProgramSubmitTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"program":{"id":"p9","title":"Walk","days":0,"createdAt":"2026-10-28T00:00:00Z","updatedAt":"2026-10-28T00:00:00Z"}}"#

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

    private func run(_ title: String, onUnauthorized: @MainActor () async -> Void = {}) async -> CreateProgramSubmit.Result {
        await CreateProgramSubmit.run(title: title, actions: ProgramActions(api: api, state: state), state: state,
                                      onUnauthorized: onUnauthorized)
    }

    func testCreateSendsTheTrimmedTitleAndStoresTheProgram() async {
        api.stub("POST", "/api/programs", json: created)
        let result = await run("  Walk  ")
        XCTAssertEqual(api.calls.last?.body?["name"] as? String, "Walk")
        XCTAssertEqual(api.calls.last?.body?.count, 1)
        guard case .created(let program) = result else { return XCTFail("expected .created, got \(result)") }
        XCTAssertEqual(program.id, "p9")
        XCTAssertNotNil(state.programs["p9"])
    }

    func testABlankTitleCallsNothing() async {
        let result = await run("   ")
        XCTAssertEqual(result, .silent)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testATitleOver200IsCut() async {
        api.stub("POST", "/api/programs", json: created)
        _ = await run(String(repeating: "a", count: 250))
        XCTAssertEqual((api.calls.last?.body?["name"] as? String)?.count, 200)
    }

    func testAFailureIsTheInlineError() async {
        api.errorFor = { _, _ in APIHTTPError(status: 500, message: nil) }
        let result = await run("Walk")
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(CreateProgramSubmit.failedMessage, "Couldn't create the program")
    }

    func testA401SignsOutAndShowsNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let result = await run("Walk", onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
        XCTAssertEqual(result, .silent)
    }
}
