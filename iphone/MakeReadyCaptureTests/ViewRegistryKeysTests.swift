import XCTest
@testable import MakeReady

final class ViewRegistryKeysTests: XCTestCase {
    /// SPEC D30: only 2.0 cases remain.
    func testOnlyUI2KeysRemain() {
        let legacy = ViewRegistry.registeredKeys.filter {
            !$0.hasPrefix("component.ui2.") && !$0.hasPrefix("screen.2.0.")
        }
        XCTAssertEqual(legacy, [], "1.0 capture cases must be retired (D30)")
        XCTAssertFalse(ViewRegistry.registeredKeys.isEmpty)
    }
}
