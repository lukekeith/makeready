import XCTest
@testable import MakeReady

/// text-activity Task 27 (D24): the YouTube page's web view goes nowhere but YouTube's embed player.
@MainActor
final class ViewerYouTubeHostTests: XCTestCase {

    func testYouTubeHostAllowsOnlyTheEmbedPlayer() {
        XCTAssertTrue(ViewerYouTubeHost.allows(URL(string: "https://www.youtube.com/embed/abc?enablejsapi=1")!))
        XCTAssertTrue(ViewerYouTubeHost.allows(URL(string: "https://www.youtube-nocookie.com/embed/abc")!))
        XCTAssertFalse(ViewerYouTubeHost.allows(URL(string: "https://www.youtube.com/watch?v=abc")!))
        XCTAssertFalse(ViewerYouTubeHost.allows(URL(string: "https://example.com/embed/abc")!))
        XCTAssertFalse(ViewerYouTubeHost.allows(URL(string: "http://www.youtube.com/embed/abc")!))
    }

    /// The page loads the embed player with the IFrame API on, inline, from its start second.
    func testEmbedURLEnablesTheIFrameAPI() {
        let url = ViewerYouTubeHost.embedURL(videoId: "abc", startSeconds: 12)
        XCTAssertEqual(url?.absoluteString, "https://www.youtube-nocookie.com/embed/abc?enablejsapi=1&playsinline=1&start=12")
        XCTAssertTrue(url.map(ViewerYouTubeHost.allows) ?? false)
    }
}
