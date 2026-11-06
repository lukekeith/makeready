import XCTest
@testable import MakeReady

/// SPEC D27 / §Testing (f): launch-time session validation; §Testing (b): the dev-login gate (D7).
/// Drives the real `AuthManager` through its `AuthIO` seam — no network, no Keychain.
@MainActor
final class AuthManagerLaunchTests: XCTestCase {
    private let userKey = "makeready_current_user"
    private var savedUser: Data?
    private var savedIdentity: String?
    private var savedEnvironment: String?
    private var savedFixture: String?
    private var fixtureKey = ""
    private var sentFixtureKeys: [String: [String]] = [:]
    private var credential: String?
    private var responses: [String: Result<(Int, String), Error>] = [:]
    private var sentBodies: [String: [Data]] = [:]
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        savedUser = UserDefaults.standard.data(forKey: userKey)
        savedIdentity = UserDefaults.standard.string(forKey: "devLoginIdentity")
        savedEnvironment = UserDefaults.standard.string(forKey: "selectedEnvironment")
        savedFixture = UserDefaults.standard.string(forKey: "stagingFixture")
        fixtureKey = ""
        sentFixtureKeys = [:]
        StatePersistence.shared.clear()
        AppState.shared.clearAllData()
        api = StubAPIClient()
        credential = nil
        responses = [:]
        sentBodies = [:]
    }

    override func tearDown() {
        if let savedUser { UserDefaults.standard.set(savedUser, forKey: userKey) } else { UserDefaults.standard.removeObject(forKey: userKey) }
        restore(savedIdentity, forKey: "devLoginIdentity")
        restore(savedEnvironment, forKey: "selectedEnvironment")
        restore(savedFixture, forKey: "stagingFixture")
        AppState.shared.clearAllData()
        super.tearDown()
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
    }

    private func io() -> AuthIO {
        AuthIO(
            send: { [unowned self] request in
                let path = request.url?.path ?? ""
                if let body = request.httpBody { self.sentBodies[path, default: []].append(body) }
                if let key = request.value(forHTTPHeaderField: "X-Fixture-Key") { self.sentFixtureKeys[path, default: []].append(key) }
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
            clearCredential: { [unowned self] in self.credential = nil },
            heal: { .healthy(3010) },
            fixtureKey: { [unowned self] in self.fixtureKey }
        )
    }

    /// The `email` of every `/auth/dev-login` body sent, in order.
    private func devLoginEmails() -> [String] {
        (sentBodies["/auth/dev-login"] ?? []).compactMap { body in
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["email"] as? String
        }
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

    // MARK: - staging-fixtures: C1 / C2

    private let c1Body = #"{"success":true,"user":{"id":"u1","email":"fixtures-new@makeready.local","name":"New","avatarURL":null},"sessionCookie":"s:abc"}"#

    func testSignInUsesC1OnStagingWithAKey() async throws {
        AppConfiguration.selectedEnvironment = .staging
        StagingFixture.current = .newGroup
        fixtureKey = "k"
        responses["/auth/fixture-login"] = .success((200, c1Body))
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        let auth = AuthManager(io: io())
        try await auth.signIn()
        XCTAssertEqual(sentFixtureKeys["/auth/fixture-login"], ["k"])
        let body = try XCTUnwrap(sentBodies["/auth/fixture-login"]?.first)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["fixture": "new-group"])
        XCTAssertEqual(devLoginEmails(), [])
    }

    func testFixtureLoginDecodesAndAuthenticates() async throws {
        fixtureKey = "k"
        responses["/auth/fixture-login"] = .success((200, c1Body))
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        let auth = AuthManager(io: io())
        try await auth.fixtureLogin(.newGroup)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUser?.email, "fixtures-new@makeready.local")
        XCTAssertEqual(credential, "s:abc")
    }

    func testFixturesNotSeededMapsToBeingResetAndKeepsTheFixture() async {
        StagingFixture.current = .newGroup
        responses["/auth/fixture-login"] = .success((404, #"{"success":false,"error":"fixtures_not_seeded"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.fixtureLogin(.newGroup)
            XCTFail("expected a failure")
        } catch {
            guard case AuthError.fixturesBeingReset = error else { return XCTFail("got \(error)") }
        }
        XCTAssertEqual(StagingFixture.current, .newGroup)
        XCTAssertFalse(auth.isAuthenticated)
    }

    func testNonJsonFixture404IsNotBeingReset() {
        let error = AuthManager.fixtureLoginFailure(status: 404, body: Data("<html>Cannot POST</html>".utf8))
        XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
    }

    func testFixtureResetSucceedsOnlyOn202() async throws {
        fixtureKey = "k"
        responses["/auth/fixture-reset"] = .success((202, #"{"success":true}"#))
        let auth = AuthManager(io: io())
        try await auth.fixtureReset(.full)
        XCTAssertEqual(sentFixtureKeys["/auth/fixture-reset"], ["k"])
        responses["/auth/fixture-reset"] = .success((502, #"{"success":false,"error":"reset_unavailable"}"#))
        do {
            try await auth.fixtureReset(.full)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    // MARK: - ui2-fixtures D13/D14: the Local dev-login identity

    func testDevLoginIdentityDefaultsToYouAndPersists() {
        UserDefaults.standard.removeObject(forKey: "devLoginIdentity")
        XCTAssertEqual(DevLoginIdentity.current, .you)
        DevLoginIdentity.current = .fixtures
        XCTAssertEqual(UserDefaults.standard.string(forKey: "devLoginIdentity"), "fixtures")
        XCTAssertEqual(DevLoginIdentity.current, .fixtures)
        XCTAssertEqual(DevLoginIdentity.you.email, "luke@lukekeith.com")
        XCTAssertEqual(DevLoginIdentity.fixtures.email, "fixtures@makeready.local")
        XCTAssertEqual(DevLoginIdentity.allCases.map(\.title), ["You", "Fixtures"])
    }

    func testSignInToReachableLocalDevLogsInAsTheSelectedIdentity() async throws {
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        for identity in DevLoginIdentity.allCases {
            DevLoginIdentity.current = identity
            credential = nil
            let auth = AuthManager(io: io())
            let signedIn = try await auth.signInToReachableLocal()
            XCTAssertTrue(signedIn)
        }
        XCTAssertEqual(devLoginEmails(), ["luke@lukekeith.com", "fixtures@makeready.local"])
    }

    func testSignInDevLogsInAsTheSelectedIdentity() async throws {
        try XCTSkipUnless(AppConfiguration.devMode, "needs the DEV_MODE=YES host build")
        AppConfiguration.selectedEnvironment = .local
        stubDevLogin()
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)
        DevLoginIdentity.current = .fixtures
        let auth = AuthManager(io: io())
        try await auth.signIn()
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(devLoginEmails(), ["fixtures@makeready.local"])
        XCTAssertEqual(AppConfiguration.selectedEnvironment, .local, "a healthy Local must not fall back to Production")
    }

    func testUserNotFoundForFixturesThrowsFixturesNotSeeded() async {
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.fixtures.email)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential)
    }

    func testSignInRevertsFixturesIdentityToYouWhenNotSeeded() async throws {
        try XCTSkipUnless(AppConfiguration.devMode, "needs the DEV_MODE=YES host build")
        AppConfiguration.selectedEnvironment = .local
        stubDevLogin()
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        DevLoginIdentity.current = .fixtures
        let auth = AuthManager(io: io())
        do {
            try await auth.signIn()
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(DevLoginIdentity.current, .you, "D14: the identity reverts so Login is never a dead end")
    }

    func testServerNotInDevelopmentKeepsTodaysError() async {
        responses["/auth/dev-login"] = .success((404, #"{"error":"Not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.fixtures.email)
            XCTFail("expected a URLError")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testUserNotFoundForYouKeepsTodaysError() async {
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            try await auth.devLogin(email: DevLoginIdentity.you.email)
            XCTFail("expected a URLError")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testSignInToReachableLocalLetsFixturesNotSeededThrough() async {
        DevLoginIdentity.current = .fixtures
        responses["/auth/dev-login"] = .success((404, #"{"success":false,"error":"User not found"}"#))
        let auth = AuthManager(io: io())
        do {
            _ = try await auth.signInToReachableLocal()
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testSignInToReachableLocalReturnsFalseOnOtherFailures() async throws {
        DevLoginIdentity.current = .you
        responses["/auth/dev-login"] = .success((500, #"{"success":false,"error":"Login failed"}"#))
        let auth = AuthManager(io: io())
        let signedIn = try await auth.signInToReachableLocal()
        XCTAssertFalse(signedIn)
    }
}
