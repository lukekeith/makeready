import XCTest
@testable import MakeReady

final class AuthCallbackParserTests: XCTestCase {
    func testCode() {
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/callback?code=abc")), .code("abc"))
    }

    func testLeaderDenialRedirect() {
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/error?message=No%20access")), .denied("No access"))
    }

    func testMissing() {
        XCTAssertEqual(AuthCallback.parse(nil), .invalid)
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/callback")), .invalid)
    }
}
