import XCTest
@testable import MakeReady

/// group-cover-image D8: the viewer shows the original when there is one, else the cover.
final class CoverViewerOverlayTests: XCTestCase {
    private func group(cover: String?, original: String?) -> UserGroup {
        UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original,
                  isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testViewerShowsTheOriginalFirst() {
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "o")), "o")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: nil)), "c")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "")), "c")
        XCTAssertNil(CoverViewerOverlay.viewerURL(group: group(cover: nil, original: nil)))
    }

    func testSwipeDownPastTheThresholdCloses() {
        XCTAssertTrue(CoverViewerOverlay.closes(dragHeight: 81))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: 40))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: -200))
    }
}
