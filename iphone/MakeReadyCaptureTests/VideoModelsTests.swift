import XCTest
@testable import MakeReady

/// video-recorder D20, D27: the Video transcript fields and the Library video window.
final class VideoModelsTests: XCTestCase {

    func testWindowReplaceAndAppend() {
        var w = VideoLibraryWindow(ids: ["a", "b", "c"], nextCursor: "x", hasMore: true, query: nil)
        w = w.replacing(with: .init(ids: ["b", "d"], nextCursor: "y", hasMore: true))
        XCTAssertEqual(w.ids, ["b", "d"])
        w = w.appending(page: .init(ids: ["d", "e"], nextCursor: nil, hasMore: false))
        XCTAssertEqual(w.ids, ["b", "d", "e"]); XCTAssertFalse(w.hasMore)
    }

    func testWindowKeepsItsQueryAndTakesTheCursorOfTheLastPage() {
        var w = VideoLibraryWindow(ids: [], nextCursor: nil, hasMore: false, query: "grace")
        w = w.replacing(with: .init(ids: ["a"], nextCursor: "c1", hasMore: true))
        XCTAssertEqual(w.query, "grace")
        XCTAssertEqual(w.nextCursor, "c1")
        XCTAssertTrue(w.hasMore)
    }

    func testVideoSummaryDecodesTheServerRow() throws {
        let json = #"{"id":"v1","title":null,"thumbnailUrl":null,"playbackUrl":"https://x/v1.m3u8","duration":45,"status":"ready","transcriptStatus":"ready","transcriptPreview":"In the beginning","createdAt":"2026-11-01T00:00:00.123Z"}"#
        let row = try JSONDecoder.apiDecoder.decode(VideoSummary.self, from: Data(json.utf8))
        XCTAssertEqual(row.id, "v1")
        XCTAssertNil(row.title)
        XCTAssertEqual(row.transcriptStatus, .ready)
        XCTAssertEqual(row.transcriptPreview, "In the beginning")
    }

    func testVideoDecodesTheTranscriptFields() throws {
        let json = #"{"id":"v1","cloudflareUid":"u","playbackUrl":"","status":"ready","userId":"me","createdAt":"2026-11-01T00:00:00Z","updatedAt":"2026-11-01T00:00:00Z","transcript":"hi","transcriptSegments":[{"text":"hi","startMs":0,"endMs":400}],"transcriptStatus":"ready","transcriptSource":"on_device","libraryRemovedAt":null,"lessonUseCount":2}"#
        let video = try JSONDecoder.apiDecoder.decode(Video.self, from: Data(json.utf8))
        XCTAssertEqual(video.transcriptSegments, [VideoTranscriptSegment(text: "hi", startMs: 0, endMs: 400)])
        XCTAssertEqual(video.transcriptStatus, .ready)
        XCTAssertEqual(video.transcriptSource, "on_device")
        XCTAssertNil(video.libraryRemovedAt)
        XCTAssertEqual(video.lessonUseCount, 2)
    }
}
