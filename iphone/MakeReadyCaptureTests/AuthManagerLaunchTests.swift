import XCTest
@testable import MakeReady

/// SPEC D27 / §Testing (f): launch-time session validation; §Testing (b): the dev-login gate (D7).
/// Drives the real `AuthManager` through its `AuthIO` seam — no network, no Keychain.
@MainActor
final class AuthManagerLaunchTests: XCTestCase {
    private let userKey = "makeready_current_user"
    private var savedUser: Data?
    private var credential: String?
    private var responses: [String: Result<(Int, String), Error>] = [:]
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        savedUser = UserDefaults.standard.data(forKey: userKey)
        StatePersistence.shared.clear()
        AppState.shared.clearAllData()
        api = StubAPIClient()
        credential = nil
        responses = [:]
    }

    override func tearDown() {
        if let savedUser { UserDefaults.standard.set(savedUser, forKey: userKey) } else { UserDefaults.standard.removeObject(forKey: userKey) }
        AppState.shared.clearAllData()
        super.tearDown()
    }

    private func io() -> AuthIO {
        AuthIO(
            send: { [unowned self] request in
                let path = request.url?.path ?? ""
                switch self.responses[path] ?? .success((404, "{}")) {
                case .failure(let error): throw error
                case .success(let (status, body)):
                    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                    return (Data(body.utf8), response)
                }
            },
            api: api,
            credential: { [unowned self] in self.credential },
            storeCredential: { [unowned self] in self.credential = $0 },
            clearCredential: { [unowned self] in self.credential = nil }
        )
    }

    /// A signed-in previous launch: a cached user and a stored credential.
    private func cacheSignedInUser() throws {
        let user = User(id: "u1", name: "Old User", email: "old@example.com", picture: nil)
        UserDefaults.standard.set(try JSONEncoder().encode(user), forKey: userKey)
        credential = "old-cookie"
    }

    /// Runs one initial load, as the shell does on mount.
    private func runInitialLoad(_ counter: inout Int) async {
        var ran = false
        await AppState.shared.initialLoad.run { _ in ran = true }
        if ran { counter += 1 }
    }

    // MARK: - (f) launch

    func test401AtLaunchFullySignsOut() async throws {
        try cacheSignedInUser()
        responses["/auth/me"] = .success((401, #"{"error":"Not authenticated"}"#))
        AppState.shared.organizationId = "old-org"
        var loads = 0
        await runInitialLoad(&loads)   // the old session's load already ran

        let auth = AuthManager(io: io())
        await auth.launchValidation?.value

        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentUser)
        XCTAssertNil(credential, "the session cookie must be cleared")
        XCTAssertNil(UserDefaults.standard.data(forKey: userKey))
        XCTAssertNil(AppState.shared.organizationId, "the old session's state must be cleared")
        await runInitialLoad(&loads)
        XCTAssertEqual(loads, 2, "the next sign-in must re-run the initial load")
    }

    func testOfflineAtLaunchKeepsTheCachedUser() async throws {
        try cacheSignedInUser()
        responses["/auth/me"] = .failure(URLError(.notConnectedToInternet))
        AppState.shared.organizationId = "org1"
        var loads = 0
        await runInitialLoad(&loads)

        let auth = AuthManager(io: io())
        await auth.launchValidation?.value

        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUser?.id, "u1")
        XCTAssertEqual(credential, "old-cookie")
        XCTAssertEqual(AppState.shared.organizationId, "org1")
        await runInitialLoad(&loads)
        XCTAssertEqual(loads, 1, "an offline launch keeps the session's initial load")
    }

    func testServerErrorAtLaunchKeepsTheCachedUser() async throws {
        try cacheSignedInUser()
        responses["/auth/me"] = .success((503, "{}"))
        let auth = AuthManager(io: io())
        await auth.launchValidation?.value
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(credential, "old-cookie")
    }

    // MARK: - (b) dev-login gate

    private func stubDevLogin() {
        responses["/auth/dev-login"] = .success((200, #"{"success":true,"sessionCookie":"dev-cookie","user":{"id":"u2","email":"m@example.com","name":"Member"}}"#))
        responses["/auth/logout"] = .success((200, #"{"success":true}"#))
    }

    func testDevLoginDeniedNeverAuthenticates() async {
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":false}"#)
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: "m@example.com")
            XCTFail("expected leaderAccessDenied")
        } catch AuthError.leaderAccessDenied {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential)
    }

    func testDevLoginLeaderCheckFailureClearsTheCookie() async {
        stubDevLogin()
        api.errorToThrow = URLError(.timedOut)
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: "m@example.com")
            XCTFail("expected the leader-access failure to rethrow")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential, "a cookie left behind would be validated next launch with no leader check")
    }

    func testDevLoginLeaderSucceeds() async throws {
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        let auth = AuthManager(io: io())
        try await auth.devLogin(email: "m@example.com")
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(credential, "dev-cookie")
    }
}
