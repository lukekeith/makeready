import XCTest
@testable import MakeReady

/// memo-screens D5, T5: the notes and memos searches run together; one failing still shows the other.
final class LibraryHomeSearchTests: XCTestCase {

    private func summary(_ id: String) -> VoiceMemoSummary {
        let stamp = "2026-11-20T16:00:00.000Z"
        let json = #"{"id":"\#(id)","title":"Memo","mimeType":"audio/mp4","fileSize":5000,"durationMs":42000,"transcriptPreview":null,"transcriptStatus":"none","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
        return try! JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(json.utf8))
    }

    func testOneSourceFailingStillShowsTheOther() async throws {
        let both = try await LibraryHomeSearch.run(q: "grace", loadNotes: { ["n1"] }, loadMemos: { [self.summary("m1")] })
        XCTAssertEqual(both.noteIds, ["n1"]); XCTAssertEqual(both.memos.map(\.id), ["m1"]); XCTAssertFalse(both.failed)
        let half = try await LibraryHomeSearch.run(q: "grace", loadNotes: { throw URLError(.notConnectedToInternet) }, loadMemos: { [self.summary("m1")] })
        XCTAssertEqual(half.noteIds, []); XCTAssertEqual(half.memos.map(\.id), ["m1"]); XCTAssertTrue(half.failed)
        let other = try await LibraryHomeSearch.run(q: "grace", loadNotes: { ["n1"] }, loadMemos: { throw URLError(.timedOut) })
        XCTAssertEqual(other.noteIds, ["n1"]); XCTAssertEqual(other.memos, []); XCTAssertTrue(other.failed)
    }

    func testACancelledSideIsRethrownNotCountedAsAFailure() async {
        do {
            _ = try await LibraryHomeSearch.run(q: "grace", loadNotes: { throw CancellationError() }, loadMemos: { [self.summary("m1")] })
            XCTFail("expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
    }

    func testAFailedVideoSearchStillShowsNotesAndMemos() async throws {
        let result = try await LibraryHomeSearch.run(
            q: "grace", loadNotes: { ["n1"] }, loadMemos: { [self.summary("m1")] }, loadVideos: { throw URLError(.timedOut) })
        XCTAssertEqual(result.noteIds, ["n1"]); XCTAssertEqual(result.memos.map(\.id), ["m1"]); XCTAssertTrue(result.failed)
    }

    func testTheVideoSearchRunsWithTheOthers() async throws {
        let ran = VideoRan()
        let result = try await LibraryHomeSearch.run(
            q: "grace", loadNotes: { [] }, loadMemos: { [] }, loadVideos: { await ran.mark() })
        let didRun = await ran.value
        XCTAssertTrue(didRun); XCTAssertFalse(result.failed)
    }

    private actor VideoRan {
        var value = false
        func mark() { value = true }
    }
}
