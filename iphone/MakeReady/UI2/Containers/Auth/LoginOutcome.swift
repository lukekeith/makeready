import AuthenticationServices
import Foundation

/// SPEC D7 / login §3: the welcome line becomes the error message. `nil` = return to idle silently.
enum LoginOutcome {
    static func message(for error: Error) -> String? {
        if case AuthError.leaderAccessDenied = error { return "This account doesn't have leader access." }
        // ui2-fixtures D14: the likeliest first-run failure, with what to do about it.
        if case AuthError.fixturesNotSeeded = error {
            return "Fixtures not seeded — run npm run fixtures:reset in the server container."
        }
        let ns = error as NSError
        if ns.domain == ASWebAuthenticationSessionErrorDomain,
           ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return nil }
        return "Authentication failed"
    }
}
