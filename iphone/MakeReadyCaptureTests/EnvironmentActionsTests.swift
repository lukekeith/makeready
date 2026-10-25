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
}
