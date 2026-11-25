import XCTest
@testable import MakeReady

/// video-naming D5/D16: the AI suggestions block gains an `empty` state; the four others stay.
final class VideoNamingScreenTests: XCTestCase {
    func testTheBlockHasAnEmptyState() {
        XCTAssertEqual(["prompt", "generating", "list", "regenerating", "empty"].compactMap(AISuggestionsBlock.State.init(rawValue:)).count, 5)
    }
}
