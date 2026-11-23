import XCTest
@testable import MakeReady

/// video-recorder D27: the disk snapshot decodes an old cache and keeps the Library window small.
@MainActor
final class PersistedVideoSnapshotTests: XCTestCase {

    private func video(id: String) -> Video {
        Video(
            id: id, cloudflareUid: "u-\(id)", playbackUrl: "", status: "ready", userId: "me",
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func summary(_ id: String) -> VideoSummary {
        VideoSummary(
            id: id, title: nil, thumbnailUrl: nil, playbackUrl: "", duration: nil, status: "ready",
            transcriptStatus: .none, transcriptPreview: nil, createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// An old snapshot: every key a pre-video-recorder build wrote, none of the new ones.
    func testOldSnapshotDecodes() throws {
        let json = #"{"programs":[],"groups":[],"enrollments":[],"postsByGroup":{},"membersByGroup":{},"lessonsByProgram":{},"programEnrollmentIndex":{},"groupEnrollmentIndex":{},"programLessonIndex":{},"persistedAt":"2026-11-01T00:00:00Z","schemaVersion":2,"videos":[{"id":"v1","cloudflareUid":"u","playbackUrl":"","status":"ready","userId":"me","createdAt":"2026-11-01T00:00:00Z","updatedAt":"2026-11-01T00:00:00Z"}]}"#
        let state = try JSONDecoder.apiDecoder.decode(PersistedState.self, from: Data(json.utf8))
        XCTAssertEqual(state.videos.first?.id, "v1")
        XCTAssertNil(state.videos.first?.transcriptStatus)
        XCTAssertEqual(state.libraryVideos, [])
        XCTAssertNil(state.videoLibraryWindow)
    }

    func testSnapshotDropsSegments() throws {
        var v = video(id: "v1"); v.transcriptSegments = [VideoTranscriptSegment(text: "a", startMs: 0, endMs: 1)]
        v.transcript = "a"
        var state = PersistedState(); state.videos = [v]
        let data = try JSONEncoder.apiEncoder.encode(state)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("startMs"))
        let decoded = try JSONDecoder.apiDecoder.decode(PersistedState.self, from: data)
        XCTAssertEqual(decoded.videos.first?.transcript, "a")
        XCTAssertNil(decoded.videos.first?.transcriptSegments)
    }

    func testSnapshotKeepsTheFirstHundredLibraryVideosOfTheWindow() {
        let appState = AppState()
        let ids = (0..<130).map { "v\($0)" }
        appState.libraryVideos.replaceAll(ids.map(summary))
        appState.videoLibraryWindow = VideoLibraryWindow(ids: ids, nextCursor: "c", hasMore: true, query: nil)
        let state = PersistedState(from: appState)
        XCTAssertEqual(state.libraryVideos.map(\.id), Array(ids.prefix(100)))
        XCTAssertEqual(state.videoLibraryWindow?.ids, Array(ids.prefix(100)))
    }

    func testSnapshotRoundTripsTheWindow() throws {
        var state = PersistedState()
        state.libraryVideos = [summary("a")]
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["a"], nextCursor: "c", hasMore: true, query: nil)
        let decoded = try JSONDecoder.apiDecoder.decode(PersistedState.self, from: JSONEncoder.apiEncoder.encode(state))
        XCTAssertEqual(decoded.libraryVideos.map(\.id), ["a"])
        XCTAssertEqual(decoded.videoLibraryWindow, state.videoLibraryWindow)
    }
}
