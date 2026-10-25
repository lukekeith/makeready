import XCTest
@testable import MakeReady

final class AuthStatusPolicyTests: XCTestCase {
    /// SPEC D27: only a 401 signs out.
    func testOnly401SignsOut() {
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: NSError(domain: "AuthError", code: 401)))
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: APIError.unauthorized))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.notConnectedToInternet)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.timedOut)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.badServerResponse)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: APIError.serverError("Too many requests")))
    }
}
