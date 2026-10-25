import XCTest
@testable import MakeReady

final class ProfileStopgapTests: XCTestCase {
    func testSwitcherOnlyInDevMode() {
        XCTAssertTrue(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: true))
        XCTAssertFalse(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: false))
    }
}
