import XCTest
@testable import MakeReady

final class ProfileStopgapTests: XCTestCase {
    func testSwitcherOnlyInDevMode() {
        XCTAssertTrue(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: true))
        XCTAssertFalse(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: false))
    }

    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    func testIdentityPickerOnlyForDevModeOnLocal() {
        XCTAssertTrue(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .local))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .staging))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .production))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: false, env: .local))
    }
}
