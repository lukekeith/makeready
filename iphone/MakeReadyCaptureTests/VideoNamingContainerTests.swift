import XCTest
@testable import MakeReady

/// video-naming D1, D3, D16: every block the model reports names the view's state.
@MainActor
final class VideoNamingContainerTests: XCTestCase {
    func testEveryBlockMapsToTheViewsState() {
        let blocks: [VideoNamingModel.Block] = [.generating, .list, .regenerating, .prompt, .empty]
        XCTAssertEqual(blocks.map(VideoNamingContainer.blockState).map(\.rawValue), ["generating", "list", "regenerating", "prompt", "empty"])
    }
}
