import XCTest
@testable import MakeReady

final class EnvironmentActionsTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(EnvironmentHealth.checking.label, "Checking…")
        XCTAssertEqual(EnvironmentHealth.reachable.label, "Reachable")
        XCTAssertEqual(EnvironmentHealth.unreachable.label, "Unreachable")
    }

    func testHealthURLs() {
        XCTAssertEqual(EnvironmentActions.healthURL(for: .staging)?.absoluteString, "https://staging.api.makeready.org/health")
        XCTAssertEqual(EnvironmentActions.healthURL(for: .production)?.absoluteString, "https://api.makeready.org/health")
    }

    /// Final review I-2: the switcher probes all three rows, so Local's URL must not depend on
    /// which environment is selected.
    func testLocalHealthURLIgnoresTheSelectedEnvironment() {
        let previous = AppConfiguration.selectedEnvironment
        defer { AppConfiguration.selectedEnvironment = previous }
        AppConfiguration.selectedEnvironment = .production
        XCTAssertEqual(EnvironmentActions.healthURL(for: .local)?.absoluteString,
                       "\(AppConfiguration.localAPIBaseURL)/health")
    }
}
