import XCTest
@testable import MakeReady

/// horizontal-scroll-yield: the direction rule and the fling projection shared by every
/// sideways pan in MakeReadyUI.
final class HorizontalScrollingTests: XCTestCase {
    func testPanBeginsOnlyWhenMoreSidewaysThanVertical() {
        XCTAssertTrue(HorizontalPanValue.begins(horizontal: 300, vertical: 40))
        XCTAssertTrue(HorizontalPanValue.begins(horizontal: -300, vertical: 40))
        XCTAssertFalse(HorizontalPanValue.begins(horizontal: 40, vertical: 300))
        XCTAssertFalse(HorizontalPanValue.begins(horizontal: 40, vertical: -300))
        // A perfect diagonal goes to the page.
        XCTAssertFalse(HorizontalPanValue.begins(horizontal: 100, vertical: 100))
    }

    func testPredictedEndProjectsVelocityLikeUIKitDeceleration() {
        let value = HorizontalPanValue(translation: -50, velocity: -1000)
        XCTAssertEqual(value.predictedEndTranslation, -50 - 499, accuracy: 0.001)
        XCTAssertEqual(HorizontalPanValue(translation: 20, velocity: 0).predictedEndTranslation, 20)
    }
}
