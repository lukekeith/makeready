//
//  AuthManager.swift
//  MakeReady
//
//  Authentication manager for Google Sign In
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

// Invite model matching server response
struct Invite: Codable {
    let id: String
    let code: String
    let groupId: String?
    let createdAt: String  // ISO date string
    let expiresAt: String?  // ISO date string
    let userId: String
}

// Authentication state manager
class AuthManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false

    private let userDefaultsKey = "makeready_current_user"
    private let sessionCookieKey = "makeready_session_cookie"

    // Store session for WebAuthenticationSession
    private var authSession: ASWebAuthenticationSession?
    private var sessionCookie: String?

    /// Whether the user has a valid session cookie
    var hasSessionCookie: Bool {
        return sessionCookie != nil
    }

    override init() {
        super.init()
        print("🔧 AuthManager initialized")
        // Load session cookie from UserDefaults
        self.sessionCookie = UserDefaults.standard.string(forKey: sessionCookieKey)
        if let cookie = sessionCookie {
            print("📦 Loaded session cookie from UserDefaults: \(cookie.prefix(20))...")
        }

        // Restore cached user data immediately for fast UI
        loadUser()

        // If we have a session cookie, validate it with the server in background
        if sessionCookie != nil {
            Task {
                print("🔍 Validating session with server...")
                await checkAuthStatus()
                print("✅ Auth status check complete. isAuthenticated: \(self.isAuthenticated)")
            }
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

                // Log the entire callback URL for debugging
                if let callbackURL = callbackURL {
                    NSLog("🔗 Full callback URL: %@", callbackURL.absoluteString)
                    NSLog("🔗 Callback scheme: %@", callbackURL.scheme ?? "none")
                    NSLog("🔗 Callback host: %@", callbackURL.host ?? "none")
                    NSLog("🔗 Callback path: %@", callbackURL.path)
                    NSLog("🔗 Callback query: %@", callbackURL.query ?? "none")

                    // Extract auth code from callback URL
                    if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                        NSLog("✅ Auth code received: %@", code)

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
    private func storeSessionCookie(_ cookie: String) {
        // Cookie is already URL-decoded by URLComponents
        print("💾 Storing session cookie: \(cookie.prefix(20))...")
        self.sessionCookie = cookie
        UserDefaults.standard.set(cookie, forKey: sessionCookieKey)
    }

    private func clearSessionCookie() {
        print("🗑️ Clearing session cookie")
        self.sessionCookie = nil
        UserDefaults.standard.removeObject(forKey: sessionCookieKey)
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
        NSLog("✅ Received session ID: %@", String(exchangeResponse.sessionId.prefix(20)))

        // Store the full session cookie value (with signature)
        storeSessionCookie(exchangeResponse.sessionId)
    }

    // MARK: - Fetch Current User
    func fetchCurrentUser() async throws {
        guard let url = URL(string: "\(Configuration.baseURL)/auth/me") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie if available
        if let sessionCookie = sessionCookie {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
            print("🍪 Adding session cookie to request: connect.sid=\(sessionCookie.prefix(20))...")
        } else {
            print("⚠️ No session cookie available for request")
        }

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
            if let sessionCookie = sessionCookie {
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

    // MARK: - Invite Management

    func createInvite(groupId: String? = nil, expiresAt: String? = nil) async throws -> Invite {
        guard let url = URL(string: "\(Configuration.baseURL)/api/invites") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie for authentication
        if let sessionCookie = sessionCookie {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        // Request body
        var body: [String: Any] = [:]
        if let groupId = groupId {
            body["groupId"] = groupId
        }
        if let expiresAt = expiresAt {
            body["expiresAt"] = expiresAt
        }

        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        NSLog("📡 Sending request with cookie: %@", sessionCookie != nil ? "YES" : "NO")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NSLog("❌ Bad server response - not HTTP")
            throw URLError(.badServerResponse)
        }

        NSLog("📥 Response status: %d", httpResponse.statusCode)

        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            NSLog("📥 Response body: %@", responseString)
        }

        // Check for authentication error
        if httpResponse.statusCode == 401 {
            NSLog("❌ 401 Unauthorized - Session expired or invalid")
            throw NSError(domain: "AuthManager", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Not authenticated. Please sign in."
            ])
        }

        guard httpResponse.statusCode == 200 else {
            NSLog("❌ Non-200 status code: %d", httpResponse.statusCode)
            throw URLError(.badServerResponse)
        }

        // Parse response
        struct CreateInviteResponse: Codable {
            let success: Bool
            let invite: Invite?
            let error: String?
        }

        let inviteResponse = try JSONDecoder().decode(CreateInviteResponse.self, from: data)

        guard inviteResponse.success, let invite = inviteResponse.invite else {
            throw NSError(domain: "AuthManager", code: 0, userInfo: [
                NSLocalizedDescriptionKey: inviteResponse.error ?? "Failed to create invite"
            ])
        }

        return invite
    }

    // MARK: - QR Code Generation
    func generateQRCode(
        data: String,
        color: String = "#6c47ff",
        backgroundColor: String = "#ffffff",
        size: Int = 600,
        errorCorrectionLevel: String = "M",
        includeLogo: Bool = true
    ) async throws -> UIImage {
        guard let url = URL(string: "\(Configuration.baseURL)/api/qrcode/generate") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData  // Never cache QR codes
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie for authentication
        if let sessionCookie = sessionCookie {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        // Request body
        let body: [String: Any] = [
            "data": data,
            "color": color,
            "backgroundColor": backgroundColor,
            "size": size,
            "errorCorrectionLevel": errorCorrectionLevel,
            "includeLogo": includeLogo
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Check for authentication errors
        if httpResponse.statusCode == 401 {
            print("❌ QR generation requires authentication")
            throw URLError(.userAuthenticationRequired)
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Server error: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }

        // Parse response
        let qrResponse = try JSONDecoder().decode(QRCodeResponse.self, from: responseData)

        guard qrResponse.success, let qrCodeDataURL = qrResponse.qrCode else {
            throw NSError(domain: "QRCode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: qrResponse.error ?? "Failed to generate QR code"
            ])
        }

        // Convert data URL to UIImage
        // Format: "data:image/png;base64,..."
        guard let base64String = qrCodeDataURL.components(separatedBy: ",").last,
              let imageData = Data(base64Encoded: base64String),
              let image = UIImage(data: imageData) else {
            throw NSError(domain: "QRCode", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode QR code image"
            ])
        }

        print("✅ QR code generated successfully for data: \(data.prefix(50))\(data.count > 50 ? "..." : "")")
        return image
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
        // Return existing key window — always present during OAuth since app is in foreground
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!
        return scene.keyWindow!
    }
}

// MARK: - Response Models
struct UserResponse: Codable {
    let user: User
}

struct QRCodeResponse: Codable {
    let success: Bool
    let qrCode: String?
    let data: String?
    let error: String?
}
