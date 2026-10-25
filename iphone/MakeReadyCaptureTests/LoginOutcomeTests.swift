import AuthenticationServices
import XCTest
@testable import MakeReady

final class LoginOutcomeTests: XCTestCase {
    func testLeaderDenied() {
        XCTAssertEqual(LoginOutcome.message(for: AuthError.leaderAccessDenied), "This account doesn't have leader access.")
    }

    func testCancelIsSilent() {
        let cancel = NSError(domain: ASWebAuthenticationSessionErrorDomain,
                             code: ASWebAuthenticationSessionError.canceledLogin.rawValue)
        XCTAssertNil(LoginOutcome.message(for: cancel))
    }

    func testAnythingElse() {
        XCTAssertEqual(LoginOutcome.message(for: URLError(.timedOut)), "Authentication failed")
        XCTAssertEqual(LoginOutcome.message(for: NSError(domain: "AuthError", code: -1)), "Authentication failed")
    }

    func testFixturesNotSeeded() {
        XCTAssertEqual(LoginOutcome.message(for: AuthError.fixturesNotSeeded),
                       "Fixtures not seeded — run npm run fixtures:reset in the server container.")
        XCTAssertEqual(AuthError.fixturesNotSeeded.errorDescription,
                       "Fixtures not seeded — run npm run fixtures:reset in the server container.")
    }
}
