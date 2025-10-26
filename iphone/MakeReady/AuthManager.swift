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

// Authentication state manager
class AuthManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false

    private let baseURL = "http://127.0.0.1:3001"
    private let userDefaultsKey = "makeready_current_user"
    private let sessionCookieKey = "makeready_session_cookie"

    // Store session for WebAuthenticationSession
    private var authSession: ASWebAuthenticationSession?
    private var sessionCookie: String?

    override init() {
        super.init()
        print("🔧 AuthManager initialized")
        // Load session cookie from UserDefaults
        self.sessionCookie = UserDefaults.standard.string(forKey: sessionCookieKey)
        if let cookie = sessionCookie {
            print("📦 Loaded session cookie from UserDefaults: \(cookie.prefix(20))...")
        }
        // Temporarily disabled for debugging
        // Task {
        //     print("🔍 Checking auth status...")
        //     await checkAuthStatus()
        //     print("✅ Auth status check complete. isAuthenticated: \(self.isAuthenticated)")
        // }
    }

    // MARK: - Sign In with Google OAuth
    @MainActor
    func signInWithGoogle() async throws {
        print("🚀 Starting Google Sign In...")
        let authURL = URL(string: "\(baseURL)/auth/google?platform=ios")!
        let callbackURLScheme = "makeready"
        print("🔗 Auth URL: \(authURL)")

        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    print("❌ OAuth error: \(error.localizedDescription)")
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

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false // Share cookies
            print("🌐 Starting auth session...")
            authSession?.start()
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
        guard let url = URL(string: "\(baseURL)/auth/exchange") else {
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
        guard let url = URL(string: "\(baseURL)/auth/me") else {
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
        guard let url = URL(string: "\(baseURL)/auth/logout") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.clearUser()
            self.clearSessionCookie()
        }
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
        return ASPresentationAnchor()
    }
}

// MARK: - Response Models
struct UserResponse: Codable {
    let user: User
}
