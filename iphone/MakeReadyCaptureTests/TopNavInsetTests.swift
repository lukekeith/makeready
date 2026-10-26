import XCTest
import SwiftUI
@testable import MakeReady

/// topnav-height-env: a pinned element is pushed down by exactly the part of the TopNav's
/// growth that would otherwise cover it, and never moved when it already sits below the row.
final class TopNavInsetTests: XCTestCase {
    func testCollapsedRowMovesNothing() {
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 0, inset: 0), 0)
        XCTAssertEqual(PinnedBelowTopNav.shift(top: -40, inset: 0), 0)
    }

    func testPinnedHeaderIsPushedBelowTheGrownRow() {
        // Pinned at the scroll view's top edge while the row has grown 60 → pushed down 60.
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 0, inset: 60), 60)
        // Half-way through the morph → follows the live value.
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 0, inset: 30), 30)
    }

    func testHeaderAlreadyBelowTheRowIsLeftAlone() {
        // Not pinned yet: the page offset already carried it 60 down.
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 60, inset: 60), 0)
        // Pulled further down than the row grew.
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 90, inset: 60), 0)
        // Partly covered → pushed only by the covered part.
        XCTAssertEqual(PinnedBelowTopNav.shift(top: 20, inset: 60), 40)
    }
}
