import XCTest
@testable import MakeReady

final class TopNavDragTests: XCTestCase {
    func testDragDownExpands() {
        XCTAssertEqual(TopNavDrag.expansion(from: 0, translation: 32, travel: 64), 0.5, accuracy: 0.001)
    }
    func testClamped() {
        XCTAssertEqual(TopNavDrag.expansion(from: 0, translation: 500, travel: 64), 1)
        XCTAssertEqual(TopNavDrag.expansion(from: 1, translation: -500, travel: 64), 0)
    }
    func testSettleByPositionAndVelocity() {
        XCTAssertEqual(TopNavDrag.settle(0.6, velocity: 0), 1)
        XCTAssertEqual(TopNavDrag.settle(0.4, velocity: 0), 0)
        XCTAssertEqual(TopNavDrag.settle(0.3, velocity: 900), 1)
        XCTAssertEqual(TopNavDrag.settle(0.7, velocity: -900), 0)
    }
    /// C-019 §2: the drag travel is the expanded row height minus the collapsed one (96 − 32).
    func testTravelIsTheRowHeightDelta() {
        XCTAssertEqual(TopNavDrag.travel, 64)
    }
}
