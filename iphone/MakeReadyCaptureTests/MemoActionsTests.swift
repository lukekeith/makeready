//
//  MemoActionsTests.swift
//  MakeReadyCaptureTests
//
//  MemoActions against a StubAPIClient and a private AppState: the stores refresh in the same
//  call (D39), the list persists but details do not, and the default title numbers from the
//  largest `Memo n` (D11, D43).
//

import XCTest
@testable import MakeReady

@MainActor
final class MemoActionsTests: XCTestCase {

    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        // AppState() loads persisted state from disk on init: clear first so the test is deterministic.
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    // MARK: - Fixtures

    private let stamp = "2026-11-20T10:30:00.000Z"

    private func summaryJSON(_ id: String, title: String = "Memo 1") -> String {
        #"{"id":"\#(id)","title":"\#(title)","mimeType":"audio/mp4","fileSize":5000,"durationMs":1000,"transcriptPreview":null,"transcriptStatus":"none","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
    }

    private func memoJSON(_ id: String, title: String = "Memo 1") -> String {
        #"{"id":"\#(id)","title":"\#(title)","url":null,"urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":5000,"durationMs":1000,"waveformPeaks":[0.1],"transcript":null,"transcriptSegments":null,"transcriptStatus":"none","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
    }

    private func memo(id: String, title: String = "Memo 1", transcript: String? = nil) -> VoiceMemo {
        var json = memoJSON(id, title: title)
        if let transcript {
            json = json.replacingOccurrences(of: #""transcript":null"#, with: #""transcript":"\#(transcript)""#)
        }
        return try! JSONDecoder.apiDecoder.decode(VoiceMemo.self, from: Data(json.utf8))
    }

    private func summary(id: String, title: String = "Memo 1") -> VoiceMemoSummary {
        try! JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(summaryJSON(id, title: title).utf8))
    }

    // MARK: - Tests

    func testLoadMemosReplacesTheStore() async throws {
        state.voiceMemos.upsert(summary(id: "stale"))
        api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[\#(summaryJSON("m1"))],"total":1}"#)
        _ = try await MemoActions(api: api, state: state).loadMemos(q: nil)
        XCTAssertEqual(state.voiceMemos.all.map(\.id), ["m1"])
    }

    func testLoadMemosPagesUntilTotal() async throws {
        let first = (1...100).map { summaryJSON("m\($0)") }.joined(separator: ",")
        let second = (101...130).map { summaryJSON("m\($0)") }.joined(separator: ",")
        api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[\#(first)],"total":130}"#)
        api.stub("GET", "/api/memos?limit=100&offset=100", json: #"{"memos":[\#(second)],"total":130}"#)
        let memos = try await MemoActions(api: api, state: state).loadMemos(q: nil)
        XCTAssertEqual(memos.count, 130)
        XCTAssertEqual(state.voiceMemos.all.count, 130)
    }

    func testLoadMemosEmptyPageEndsTheLoop() async throws {
        api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[],"total":5}"#)
        let memos = try await MemoActions(api: api, state: state).loadMemos(q: nil)
        XCTAssertEqual(memos, [])
        XCTAssertEqual(api.calls.filter { $0.method == "GET" }.count, 1)
    }

    func testLoadMemosFailingPageLeavesTheStore() async throws {
        state.voiceMemos.upsert(summary(id: "stale"))
        let first = (1...100).map { summaryJSON("m\($0)") }.joined(separator: ",")
        api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[\#(first)],"total":130}"#)
        api.errorFor = { endpoint, _ in endpoint.hasSuffix("offset=100") ? URLError(.badServerResponse) : nil }
        do {
            _ = try await MemoActions(api: api, state: state).loadMemos(q: nil)
            XCTFail("expected a throw")
        } catch {}
        XCTAssertEqual(state.voiceMemos.all.map(\.id), ["stale"])
    }

    func testRenameUpdatesBothStores() async throws {
        state.voiceMemos.upsert(summary(id: "m1", title: "Old")); state.voiceMemoDetails.upsert(memo(id: "m1", title: "Old"))
        api.stub("PATCH", "/api/memos/m1", json: #"{"memo":\#(memoJSON("m1", title: "New"))}"#)
        try await MemoActions(api: api, state: state).rename(id: "m1", title: "New")
        XCTAssertEqual(state.voiceMemos["m1"]?.title, "New"); XCTAssertEqual(state.voiceMemoDetails["m1"]?.title, "New")
    }

    func testSoftDeleteRemovesFromBothStores() async throws {
        state.voiceMemos.upsert(summary(id: "m1")); state.voiceMemoDetails.upsert(memo(id: "m1"))
        api.stub("DELETE", "/api/memos/m1", json: "")
        try await MemoActions(api: api, state: state).softDelete(id: "m1")
        XCTAssertNil(state.voiceMemos["m1"]); XCTAssertNil(state.voiceMemoDetails["m1"])
        XCTAssertTrue(api.statusEndpoints.contains("/api/memos/m1"))
    }

    func testMemoCompletedUpsertsDetailAndSummary() throws {
        MemoActions(api: api, state: state).memoCompleted(memo(id: "m9", transcript: "hello"))
        XCTAssertEqual(state.voiceMemoDetails["m9"]?.transcript, "hello")
        XCTAssertEqual(state.voiceMemos["m9"]?.transcriptPreview, "hello")
        MemoActions(api: api, state: state).memoCompleted(memo(id: "m8", transcript: String(repeating: "a", count: 400)))
        XCTAssertEqual(state.voiceMemos["m8"]?.transcriptPreview?.count, 280)
    }

    func testVoiceMemosPersistButDetailsDoNot() throws {
        state.voiceMemos.upsert(summary(id: "m1")); state.voiceMemoDetails.upsert(memo(id: "m1"))
        state.persistImmediately()
        StatePersistence.shared.waitForPendingWrites()  // the write lands on a background queue
        let reloaded = AppState()
        XCTAssertNotNil(reloaded.voiceMemos["m1"]); XCTAssertNil(reloaded.voiceMemoDetails["m1"])
    }

    func testNextDefaultTitle() {
        XCTAssertEqual(MemoActions.nextDefaultTitle(existingTitles: []), "Memo 1")
        XCTAssertEqual(MemoActions.nextDefaultTitle(existingTitles: ["Memo 2", "Memo 10", "Memo 3b", "Sermon"]), "Memo 11")
    }
}
