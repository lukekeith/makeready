import AuthenticationServices
import Foundation

/// SPEC D7 / login §3: the welcome line becomes the error message. `nil` = return to idle silently.
enum LoginOutcome {
    static func message(for error: Error) -> String? {
        if case AuthError.leaderAccessDenied = error { return "This account doesn't have leader access." }
        let ns = error as NSError
        if ns.domain == ASWebAuthenticationSessionErrorDomain,
           ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return nil }
        return "Authentication failed"
    }
}
