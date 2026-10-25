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
    /// Review I-1: the axis is decided by the first movement and kept for the whole gesture.
    func testAxisLocksOnFirstMovement() {
        XCTAssertTrue(TopNavDrag.lockAxis(nil, translation: CGSize(width: 2, height: 9)))
        XCTAssertFalse(TopNavDrag.lockAxis(nil, translation: CGSize(width: 9, height: 2)))
        // Once locked, later movement never flips it.
        XCTAssertTrue(TopNavDrag.lockAxis(true, translation: CGSize(width: 300, height: 1)))
        XCTAssertFalse(TopNavDrag.lockAxis(false, translation: CGSize(width: 1, height: 300)))
    }
    /// Fix round 2: the lock belongs to ONE gesture. A cancelled gesture never reaches onEnded,
    /// so its lock must not leak into the next drag, which has a different start location.
    func testAxisLockIsPerGesture() {
        var lock = TopNavDrag.AxisLock()
        XCTAssertTrue(lock.update(start: CGPoint(x: 10, y: 10), translation: CGSize(width: 1, height: 9)))
        // Same gesture keeps its lock even when it turns sideways.
        XCTAssertTrue(lock.update(start: CGPoint(x: 10, y: 10), translation: CGSize(width: 300, height: 9)))
        // No onEnded (cancelled), then a new horizontal gesture: re-locks, no stale `true`.
        XCTAssertFalse(lock.update(start: CGPoint(x: 200, y: 12), translation: CGSize(width: 9, height: 1)))
        XCTAssertFalse(lock.update(start: CGPoint(x: 200, y: 12), translation: CGSize(width: 1, height: 300)))
    }
    func testAxisLockEndReadsAndClears() {
        var lock = TopNavDrag.AxisLock()
        _ = lock.update(start: CGPoint(x: 10, y: 10), translation: CGSize(width: 1, height: 9))
        XCTAssertTrue(lock.end(start: CGPoint(x: 10, y: 10), translation: CGSize(width: 300, height: 1)))
        // Cleared: an end with no matching start decides from its own translation.
        XCTAssertFalse(lock.end(start: CGPoint(x: 10, y: 10), translation: CGSize(width: 300, height: 1)))
    }
}

