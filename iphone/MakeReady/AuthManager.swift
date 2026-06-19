//
//  AuthManager.swift
//  MakeReady
//
//  Authentication lifecycle: Google OAuth via ASWebAuthenticationSession,
//  dev login, session validation, and sign-out. The session credential
//  itself is owned by APIClient (backed by SessionCredentialStore in the
//  Keychain) — AuthManager writes it on login/logout but never caches it.
//
//  Invite creation and QR generation live in InviteActions (Phase 2.6
//  dissolved the former god object).
//

import SwiftUI
import AuthenticationServices

// User model matching server response
struct User: Codable {
    let id: String
    let name: String
    let email: String
    let picture: String?

    var avatarURL: String? { picture }
}

// Authentication state manager
@Observable
class AuthManager: NSObject {
    var currentUser: User?
    var isAuthenticated: Bool = false

    private let userDefaultsKey = "makeready_current_user"

    // Store session for WebAuthenticationSession
    @ObservationIgnored private var authSession: ASWebAuthenticationSession?

    /// Whether a session credential exists. APIClient owns the credential;
    /// this just asks it.
    var hasSessionCookie: Bool {
        APIClient.shared.isAuthenticated
    }

    override init() {
        super.init()
        print("🔧 AuthManager initialized")

        // Restore cached user data immediately for fast UI
        loadUser()

        // If a session credential exists, validate it with the server in background
        if APIClient.shared.isAuthenticated {
            Task {
                print("🔍 Validating session with server...")
                await checkAuthStatus()
                print("✅ Auth status check complete. isAuthenticated: \(self.isAuthenticated)")
            }
        } else {
            // No credential for the CURRENT environment (sessions are
            // per-environment). The cached user loadUser() just restored
            // belongs to whichever environment last signed in — it must not
            // count as signed in here, or the app launches into a main UI
            // where every request fails. The UserDefaults copy is kept so a
            // relaunch on the owning environment still fast-restores.
            currentUser = nil
            isAuthenticated = false
            Log.auth.info("launched with no session credential for this environment — showing login")
        }
    }

    // MARK: - Login Entry Point

    /// Dev-login identity used for the Local environment (dev builds only).
    private static let devLoginEmail = "luke@lukekeith.com"

    /// Login button entry point. When the selected environment is **Local**,
    /// it first confirms the local server is actually reachable — healing the
    /// dev port if it has moved — and transparently falls back to
    /// **Production** when Local is down. It then runs the auth flow
    /// appropriate to the *resolved* environment: dev-login for Local, Google
    /// OAuth otherwise.
    @MainActor
    func signIn() async throws {
        await resolveLoginEnvironment()

        if Configuration.isLocalDevelopment {
            try await devLogin(email: Self.devLoginEmail)
        } else {
            try await signInWithGoogle()
        }
    }

    /// If the user picked Local, verify it's up before we commit the login to
    /// it. `LocalPortHealer` probes `/health` (and adopts a moved dev port).
    /// If nothing answers as a MakeReady server, switch the *active*
    /// environment to Production so the whole app — auth and the data loads
    /// that follow — targets a reachable backend. No-op for non-dev builds and
    /// non-Local selections, where there is nothing to fall back from.
    @MainActor
    private func resolveLoginEnvironment() async {
        guard Configuration.devMode, Configuration.selectedEnvironment == .local else {
            return
        }

        switch await LocalPortHealer.heal() {
        case .healthy, .healed:
            // Local is reachable (port healed if it had moved) — stay on Local.
            return
        case .notFound, .skipped:
            Log.auth.info("Local server unreachable at login — falling back to Production")
            // Flush Local's snapshot to its environment-scoped file, switch,
            // then swap caches to Production's snapshot (mirrors the manual
            // environment switch on the Profile screen).
            AppState.shared.persistImmediately()
            Configuration.selectedEnvironment = .production
            AppState.shared.reloadForEnvironmentSwitch()
        }
    }

    // MARK: - Sign In with Google OAuth
    @MainActor
    func signInWithGoogle() async throws {
        print("🚀 Starting Google Sign In...")
        let authURL = URL(string: "\(Configuration.baseURL)/auth/google?platform=ios")!
        let callbackURLScheme = "makeready"
        print("🔗 Auth URL: \(authURL)")
        print("📱 Callback URL scheme: \(callbackURLScheme)")

        return try await withCheckedThrowingContinuation { continuation in
            print("🔄 Creating ASWebAuthenticationSession...")

            self.authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    print("❌ OAuth error: \(error.localizedDescription)")
                    print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain {
                        if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            print("❌ User cancelled login")
                        } else if nsError.code == ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue {
                            print("❌ Presentation context not provided")
                        } else if nsError.code == ASWebAuthenticationSessionError.presentationContextInvalid.rawValue {
                            print("❌ Presentation context invalid")
                        }
                    }
                    continuation.resume(throwing: error)
                    return
                }

                NSLog("🔵 OAuth callback handler started")

                // Log callback structure for debugging (query withheld — it carries the auth code)
                if let callbackURL = callbackURL {
                    NSLog("🔗 Callback scheme: %@", callbackURL.scheme ?? "none")
                    NSLog("🔗 Callback host: %@", callbackURL.host ?? "none")
                    NSLog("🔗 Callback path: %@", callbackURL.path)
                    NSLog("🔗 Callback has query: %@", callbackURL.query != nil ? "yes" : "no")

                    // Extract auth code from callback URL
                    if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                        NSLog("✅ Auth code received (length: %d)", code.count)

                        // Exchange auth code for session
                        Task {
                            do {
                                try await self?.exchangeAuthCode(code)
                                try await self?.fetchCurrentUser()
                                NSLog("✅ Auth code exchange and user fetch successful")

                                // Request push notification permission after login
                                // Delay slightly to ensure the UI is settled
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                                    await PushNotificationManager.shared.requestPermissionAndRegister()
                                }

                                continuation.resume()
                            } catch {
                                NSLog("❌ Auth code exchange failed: %@", error.localizedDescription)
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        NSLog("❌ No auth code in callback URL")
                        continuation.resume(throwing: NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No auth code in callback"]))
                    }
                } else {
                    NSLog("❌ No callback URL received")
                    continuation.resume(throwing: NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No callback URL"]))
                }
            }

            self.authSession?.presentationContextProvider = self
            self.authSession?.prefersEphemeralWebBrowserSession = false // Share cookies

            // Check if we have a valid window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.keyWindow {
                print("✅ Found key window: \(window)")
            } else {
                print("⚠️ No key window found - this may cause issues")
            }

            print("🌐 Starting auth session...")
            let started = self.authSession?.start() ?? false
            print("🌐 Auth session start returned: \(started)")

            if !started {
                print("❌ Auth session failed to start!")
                continuation.resume(throwing: NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Auth session failed to start"]))
            }
        }
    }

    // MARK: - Session Cookie Management

    /// Write the session credential to its single owner (APIClient's
    /// Keychain-backed store). Never cached here.
    private func storeSessionCookie(_ cookie: String) {
        print("💾 Storing session cookie (length: \(cookie.count))")
        SessionCredentialStore.set(cookie)
    }

    private func clearSessionCookie() {
        print("🗑️ Clearing session cookie")
        SessionCredentialStore.clear()
    }

    // MARK: - Exchange Auth Code
    func exchangeAuthCode(_ code: String) async throws {
        guard let url = URL(string: "\(Configuration.baseURL)/auth/exchange") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)

        NSLog("🔄 Exchanging auth code for session...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            NSLog("❌ Exchange failed with status: %d", httpResponse.statusCode)
            throw URLError(.badServerResponse)
        }

        struct ExchangeResponse: Codable {
            let sessionId: String
            let userId: String
        }

        let exchangeResponse = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        NSLog("✅ Received session ID (length: %d)", exchangeResponse.sessionId.count)

        // Store the full session cookie value (with signature)
        storeSessionCookie(exchangeResponse.sessionId)
    }

    // MARK: - Fetch Current User
    func fetchCurrentUser() async throws {
        // The Keychain credential for the CURRENT environment is the single
        // source of truth. Without one we are not signed in here — don't
        // even ask the server: URLSession's shared cookie jar can carry a
        // stale session from a previous login and make /auth/me answer 200,
        // while APIClient (which requires the credential) rejects every
        // data request. That split-brain is exactly the bug this guard kills.
        guard let sessionCookie = APIClient.shared.sessionCookieValue else {
            Log.auth.info("no session credential for this environment — not signed in")
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.clearUser()
            }
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        guard let url = URL(string: "\(Configuration.baseURL)/auth/me") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Only the explicit Keychain credential authenticates this call —
        // never ambient cookies from the shared jar.
        request.httpShouldHandleCookies = false
        request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        Log.auth.info("attaching session cookie to /auth/me (length: \(sessionCookie.count))")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.clearUser()
            }
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)

        await MainActor.run {
            self.currentUser = userResponse.user
            self.isAuthenticated = true
            self.saveUser()
        }
    }

    // MARK: - Check Auth Status
    func checkAuthStatus() async {
        do {
            print("🔍 Fetching current user for auth check...")
            try await fetchCurrentUser()
            print("✅ User is authenticated")
        } catch {
            // User not authenticated, this is fine
            print("ℹ️ User not authenticated: \(error.localizedDescription)")
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }

    // MARK: - Sign Out
    func signOut() async throws {
        // Remove push notification token from server before logout
        await PushNotificationManager.shared.removeTokenFromServer()

        // Try to notify server, but always clear local state regardless of result
        if let url = URL(string: "\(Configuration.baseURL)/auth/logout") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Add session cookie for authenticated logout
            if let sessionCookie = APIClient.shared.sessionCookieValue {
                request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
            }

            // Attempt server logout, but don't fail if it errors (e.g., for debug bypass users)
            do {
                let (_, _) = try await URLSession.shared.data(for: request)
                print("✅ Server logout successful")
            } catch {
                print("⚠️ Server logout failed (this is OK for debug users): \(error.localizedDescription)")
            }
        }

        // Always clear local authentication state
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.clearUser()
            self.clearSessionCookie()

            // Clear all cached data to prevent data leaking between users
            AppState.shared.clearAllData()

            print("🔓 Local authentication state cleared")
        }
    }

    // MARK: - Dev Login (local development only)

    /// Authenticate against the local dev server using email instead of Google OAuth.
    /// Calls POST /auth/dev-login which creates a real server session.
    /// Only works when the server is running in NODE_ENV=development.
    @MainActor
    func devLogin(email: String) async throws {
        print("🔓 Dev login: \(email) → \(Configuration.baseURL)")

        guard let url = URL(string: "\(Configuration.baseURL)/auth/dev-login") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("❌ Dev login failed: HTTP \(statusCode)")
            throw URLError(.userAuthenticationRequired)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = json?["success"] as? Bool, success,
              let sessionCookie = json?["sessionCookie"] as? String,
              let userDict = json?["user"] as? [String: Any] else {
            print("❌ Dev login: invalid response")
            throw URLError(.userAuthenticationRequired)
        }

        // Store session cookie using the same mechanism as exchangeAuthCode
        storeSessionCookie(sessionCookie)
        print("🍪 Dev login: stored session cookie")

        // Set current user
        let user = User(
            id: userDict["id"] as? String ?? "",
            name: userDict["name"] as? String ?? "",
            email: userDict["email"] as? String ?? "",
            picture: userDict["avatarURL"] as? String
        )
        self.currentUser = user
        self.isAuthenticated = true
        print("✅ Dev login: authenticated as \(user.name)")
    }

    // MARK: - Persistence
    private func saveUser() {
        guard let user = currentUser else { return }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        currentUser = user
        isAuthenticated = true
    }

    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Prefer the key window; fall back through any window to a fresh
        // scene-anchored window rather than force-unwrapping (keyWindow CAN
        // be nil during OAuth; a crash here would kill login entirely).
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            // Unreachable: OAuth only runs foregrounded, and with zero
            // connected window scenes no anchor could present UI anyway.
            preconditionFailure("No connected window scene to anchor OAuth presentation")
        }
        return scene.keyWindow ?? scene.windows.first ?? UIWindow(windowScene: scene)
    }
}

// MARK: - Response Models
struct UserResponse: Codable {
    let user: User
}
