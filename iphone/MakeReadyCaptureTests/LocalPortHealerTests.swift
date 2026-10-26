import XCTest
@testable import MakeReady

final class LocalPortHealerTests: XCTestCase {
    func testAStrandedPortAlsoProbesTheDefaultWindow() {
        let ports = LocalPortHealer.candidatePorts(base: 3110, defaultPort: 3010)
        XCTAssertEqual(ports.first, 3010)
        XCTAssertTrue(ports.contains(3020))
        XCTAssertTrue(ports.contains(3111))
        XCTAssertTrue(ports.contains(3120))
        XCTAssertFalse(ports.contains(3110))
    }

    func testTheDefaultPortProbesOnlyItsOwnWindowAboveIt() {
        XCTAssertEqual(LocalPortHealer.candidatePorts(base: 3010, defaultPort: 3010), Array(3011...3020))
    }
}
