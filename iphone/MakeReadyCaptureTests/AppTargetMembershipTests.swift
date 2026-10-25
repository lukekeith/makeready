import XCTest
@testable import MakeReady

final class AppTargetMembershipTests: XCTestCase {
    /// SPEC D29: 2.0 views compile into the app module.
    func testLoginScreenIsInTheAppModule() {
        let state = LoginScreen.State(authenticating: false, errorMessage: "")
        XCTAssertFalse(state.authenticating)
        XCTAssertEqual(String(reflecting: LoginScreen.self), "MakeReady.LoginScreen")
    }
}
