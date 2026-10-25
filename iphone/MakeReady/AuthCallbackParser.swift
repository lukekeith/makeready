import Foundation

/// What the OAuth web session handed back (SPEC D7). The server's iOS leader
/// gate redirects a non-leader to makeready://auth/error?message=… with no code.
enum AuthCallback: Equatable {
    case code(String)
    case denied(String?)
    case invalid

    static func parse(_ url: URL?) -> AuthCallback {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return .invalid }
        let items = parts.queryItems ?? []
        if url.host == "auth", url.path == "/error" {
            return .denied(items.first { $0.name == "message" }?.value)
        }
        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty { return .code(code) }
        return .invalid
    }
}

/// SPEC D27: a launch/refresh error signs the user out only when the server
/// said the session is gone (401). Offline, timeouts, 5xx and 429 keep them in.
enum AuthStatusPolicy {
    static func shouldSignOut(after error: Error) -> Bool {
        if case APIError.unauthorized = error { return true }
        let ns = error as NSError
        return ns.domain == "AuthError" && ns.code == 401
    }
}
