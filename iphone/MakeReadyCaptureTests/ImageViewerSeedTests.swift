import XCTest
import UIKit
@testable import MakeReady

/// media-page D12: the open flight starts from the tile's loaded image, not a spinner.
final class ImageViewerSeedTests: XCTestCase {
    func testTheFullImageWinsOverThePlaceholder() {
        let full = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        let tile = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        XCTAssertTrue(ImageViewer.openingImage(cached: full, placeholder: tile) === full)
        XCTAssertTrue(ImageViewer.openingImage(cached: nil, placeholder: tile) === tile)
        XCTAssertNil(ImageViewer.openingImage(cached: nil, placeholder: nil))
    }
}
