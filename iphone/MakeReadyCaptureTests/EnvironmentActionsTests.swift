import XCTest
@testable import MakeReady

final class EnvironmentActionsTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(EnvironmentHealth.checking.label, "Checking…")
        XCTAssertEqual(EnvironmentHealth.reachable.label, "Reachable")
        XCTAssertEqual(EnvironmentHealth.unreachable.label, "Unreachable")
    }

    func testHealthURLs() {
        XCTAssertEqual(EnvironmentActions.healthURL(for: .staging)?.absoluteString, "https://staging.api.makeready.org/health")
        XCTAssertEqual(EnvironmentActions.healthURL(for: .production)?.absoluteString, "https://api.makeready.org/health")
    }

    /// Final review I-2: the switcher probes all three rows, so Local's URL must not depend on
    /// which environment is selected.
    func testLocalHealthURLIgnoresTheSelectedEnvironment() {
        let previous = AppConfiguration.selectedEnvironment
        defer { AppConfiguration.selectedEnvironment = previous }
        AppConfiguration.selectedEnvironment = .production
        XCTAssertEqual(EnvironmentActions.healthURL(for: .local)?.absoluteString,
                       "\(AppConfiguration.localAPIBaseURL)/health")
    }
}

/// ui2-fixtures D13/D14, F17: the Local dev-identity switch, driven through the real
/// `AuthManager` `AuthIO` seam — no network, no Keychain.
@MainActor
final class EnvironmentIdentitySwitchTests: XCTestCase {
    private let notSeeded = "Fixtures not seeded — run npm run fixtures:reset in the server container."
    private let userKey = "makeready_current_user"
    private var savedUser: Data?
    private var savedIdentity: String?
    private var savedEnvironment: String?
    private var credential: String?
    private var responses: [String: (Int, String)] = [:]
    private var devLoginEmails: [String] = []
    private var api: StubAPIClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedUser = UserDefaults.standard.data(forKey: userKey)
        savedIdentity = UserDefaults.standard.string(forKey: "devLoginIdentity")
        savedEnvironment = UserDefaults.standard.string(forKey: "selectedEnvironment")
        try XCTSkipUnless(AppConfiguration.devMode, "needs the DEV_MODE=YES host build")
        AppConfiguration.selectedEnvironment = .local
        DevLoginIdentity.current = .you
        StatePersistence.shared.clear()
        AppState.shared.clearAllData()
        api = StubAPIClient()
        credential = nil
        responses = [:]
        devLoginEmails = []
    }

    override func tearDown() {
        if let savedUser { UserDefaults.standard.set(savedUser, forKey: userKey) } else { UserDefaults.standard.removeObject(forKey: userKey) }
        restore(savedIdentity, forKey: "devLoginIdentity")
        restore(savedEnvironment, forKey: "selectedEnvironment")
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
                if path == "/auth/dev-login", let body = request.httpBody,
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let email = json["email"] as? String {
                    self.devLoginEmails.append(email)
                }
                let (status, text) = self.responses[path] ?? (404, "{}")
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (Data(text.utf8), response)
            },
            api: api,
            credential: { [unowned self] in self.credential },
            storeCredential: { [unowned self] in self.credential = $0 },
            clearCredential: { [unowned self] in self.credential = nil },
            heal: { .healthy(3010) }
        )
    }

    /// Signed in on Local as You, as before the owner picks Fixtures.
    private func signedInAsYou() async -> AuthManager {
        credential = "you-cookie"
        responses["/auth/me"] = (200, #"{"user":{"id":"u-you","name":"You","email":"luke@lukekeith.com"}}"#)
        responses["/auth/logout"] = (200, #"{"success":true}"#)
        let auth = AuthManager(io: io())
        await auth.launchValidation?.value
        return auth
    }

    func testSwitchIdentitySignsInAsTheChosenIdentity() async throws {
        let auth = await signedInAsYou()
        XCTAssertTrue(auth.isAuthenticated)
        responses["/auth/dev-login"] = (200, #"{"success":true,"sessionCookie":"fx-cookie","user":{"id":"u-fx","email":"fixtures@makeready.local","name":"Fixture Leader"}}"#)
        api.stub("GET", "/auth/leader-access", json: #"{"canAccess":true}"#)

        try await EnvironmentActions().switchIdentity(.fixtures, auth: auth)

        XCTAssertEqual(DevLoginIdentity.current, .fixtures)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUser?.email, "fixtures@makeready.local")
        XCTAssertEqual(credential, "fx-cookie")
        XCTAssertEqual(devLoginEmails, ["fixtures@makeready.local"])
        XCTAssertNil(auth.loginNotice)
    }

    func testSwitchIdentityRevertsToYouOnFailureAndWritesNoSnapshot() async throws {
        let auth = await signedInAsYou()
        responses["/auth/dev-login"] = (404, #"{"success":false,"error":"User not found"}"#)
        AppState.shared.organizationId = "org-you"
        AppState.shared.persist()   // F17: a debounced save is pending when the switch starts

        do {
            try await EnvironmentActions().switchIdentity(.fixtures, auth: auth)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error)")
        }

        XCTAssertEqual(DevLoginIdentity.current, .you, "D13: the identity reverts to You")
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(credential)
        XCTAssertEqual(auth.loginNotice, notSeeded, "D14: Login shows the message")
        XCTAssertNil(AppState.shared.organizationId, "the old identity's state is cleared")
        try await Task.sleep(nanoseconds: 800_000_000)   // past StatePersistence's 0.5 s debounce
        XCTAssertNil(StatePersistence.shared.load(), "F17: no snapshot may be written after clearAllData()")
    }

    func testSwitchIdentityToTheCurrentIdentityDoesNothing() async throws {
        let auth = await signedInAsYou()
        try await EnvironmentActions().switchIdentity(.you, auth: auth)
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(credential, "you-cookie")
        XCTAssertTrue(devLoginEmails.isEmpty)
    }

    func testSwitchToLocalLetsFixturesNotSeededThrough() async {
        AppConfiguration.selectedEnvironment = .production
        DevLoginIdentity.current = .fixtures
        responses["/auth/dev-login"] = (404, #"{"success":false,"error":"User not found"}"#)
        let auth = AuthManager(io: io())

        do {
            try await EnvironmentActions(heal: { .healthy(3010) }).switchTo(.local, auth: auth)
            XCTFail("expected fixturesNotSeeded")
        } catch AuthError.fixturesNotSeeded {
        } catch {
            XCTFail("unexpected \(error) — must not be mapped to localServerUnreachable")
        }

        XCTAssertEqual(AppConfiguration.selectedEnvironment, .production, "the switch is rolled back")
        XCTAssertEqual(DevLoginIdentity.current, .you, "D14: the identity reverts to You")
    }

    func testSwitchToUnreachableLocalStillSaysUnreachable() async {
        AppConfiguration.selectedEnvironment = .production
        let auth = AuthManager(io: io())
        do {
            try await EnvironmentActions(heal: { .notFound(base: 3010) }).switchTo(.local, auth: auth)
            XCTFail("expected localServerUnreachable")
        } catch AuthError.localServerUnreachable {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(AppConfiguration.selectedEnvironment, .production)
    }
}
