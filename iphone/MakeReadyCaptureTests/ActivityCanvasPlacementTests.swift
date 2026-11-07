import XCTest
import SwiftUI
@testable import MakeReady

/// C-091 §2 Placement function (OQ-C-091-006) against 02 §4's three cases: the content fits,
/// it does not fit, and the `center` versus `top` anchor. All figures are wu unless named points.
final class ActivityCanvasPlacementTests: XCTestCase {
    private typealias Canvas = ActivityCanvas<AnyView>

    // MARK: Fits — page height is the viewport

    func testFitsKeepsTheAnchorOffsetAndTheViewportHeight() {
        let placed = Canvas.placement(viewportHeight: 956, contentExtent: 400...560, unit: 1)
        XCTAssertEqual(placed.offset, 0)
        XCTAssertEqual(placed.pageHeight, 956)
    }

    func testFitsNudgesBelowTheTopChrome() {
        // The box starts above T 107: nudged down by the smallest amount that puts it inside.
        let placed = Canvas.placement(viewportHeight: 956, contentExtent: 20...120, unit: 1)
        XCTAssertEqual(placed.offset, 87)
        XCTAssertEqual(placed.pageHeight, 956)
    }

    func testFitsNudgesAboveTheEndSpace() {
        // The box ends below V − B (956 − 85 = 871): nudged up to end there.
        let placed = Canvas.placement(viewportHeight: 956, contentExtent: 800...900, unit: 1)
        XCTAssertEqual(placed.offset, -29)
        XCTAssertEqual(placed.pageHeight, 956)
    }

    func testNoContentIsExactlyTheViewport() {
        let placed = Canvas.placement(viewportHeight: 874, contentExtent: nil, unit: 1)
        XCTAssertEqual(placed.offset, -41)
        XCTAssertEqual(placed.pageHeight, 874)
    }

    // MARK: Does not fit — the page grows

    func testDoesNotFitGrowsThePage() {
        let placed = Canvas.placement(viewportHeight: 956, contentExtent: 0...1000, unit: 1)
        XCTAssertEqual(placed.offset, 107)
        XCTAssertEqual(placed.pageHeight, 1000 + 107 + 85)
    }

    func testPinnedActionAddsItsHeightToTheEndSpace() {
        let placed = Canvas.placement(viewportHeight: 956, contentExtent: 0...1000,
                                      pinnedAction: true, unit: 1)
        XCTAssertEqual(placed.offset, 107)
        XCTAssertEqual(placed.pageHeight, 1000 + 107 + 85 + 46)
    }

    // MARK: Centre versus top anchor

    func testCenterAnchorShiftsByHalfTheViewportDifference() {
        let placed = Canvas.placement(viewportHeight: 874, contentExtent: 400...500,
                                      verticalAnchor: .center, unit: 1)
        XCTAssertEqual(placed.offset, (874 - 956) / 2)
        XCTAssertEqual(placed.pageHeight, 874)
    }

    func testTopAnchorStartsAtZero() {
        let placed = Canvas.placement(viewportHeight: 874, contentExtent: 400...500,
                                      verticalAnchor: .top, unit: 1)
        XCTAssertEqual(placed.offset, 0)
        XCTAssertEqual(placed.pageHeight, 874)
    }

    // MARK: Units

    func testViewportPointsAreConvertedToWidthUnits() {
        // 1912 pt at 2 pt per wu is a 956 wu viewport; the answer comes back in wu.
        let placed = Canvas.placement(viewportHeight: 1912, contentExtent: 0...1000, unit: 2)
        XCTAssertEqual(placed.offset, 107)
        XCTAssertEqual(placed.pageHeight, 1192)
    }
}
