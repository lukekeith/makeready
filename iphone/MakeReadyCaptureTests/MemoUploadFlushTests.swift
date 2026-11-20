//
//  MemoUploadFlushTests.swift
//  MakeReadyCaptureTests
//
//  The flush policy on top of the upload queue: backoff (D22), the 401 pause (D41), per-user
//  folders (D37), draft recovery (D16) and the numbering `AppState` owns (D43). The injected
//  `sleep` records durations instead of sleeping.
//

import AVFoundation
import Speech
import XCTest
@testable import MakeReady

/// Answers a canned transcript for a salvaged file; never live.
private final class StubTranscriber: MemoTranscribing, @unchecked Sendable {
    let analyzerFormat: AVAudioFormat? = nil
    private let result: Transcript?

    init(result: Transcript?) { self.result = result }

    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool { false }
    func finish() async -> Transcript? { nil }
    func transcribeFile(_ url: URL) async -> Transcript? { result }
}

@MainActor
final class MemoUploadFlushTests: XCTestCase {

    private var root: URL!
    private var source: URL!
    private var draftsDir: URL!
    private var state: AppState!
    private var api: StubAPIClient!
    private var transport: SpyTransport!
    private var drafts: MemoDraftStore!
    private var controller: MemoUploadController!
    private let fixtureBytes = 4_096

    override func setUpWithError() throws {
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        transport = SpyTransport()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("memo-flush-\(UUID().uuidString)")
        source = root.appendingPathComponent("recorded")
        draftsDir = root.appendingPathComponent("drafts")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draftsDir, withIntermediateDirectories: true)
        drafts = MemoDraftStore(directory: draftsDir, ownerUserId: "userA", environment: "Local")
        controller = makeController()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func makeController(user: String = "userA",
                                sleep: @escaping (Duration) async throws -> Void = { _ in }) -> MemoUploadController {
        let folder = try! MemoStorage.folder(environment: "Local", userId: user, root: root.appendingPathComponent("storage"))
        return MemoUploadController(api: api, actions: MemoActions(api: api, state: state), transport: transport,
                                    directory: folder, ownerUserId: user, environment: "Local", sleep: sleep)
    }

    // MARK: - Fixtures

    private func makeResult(title: String) -> RecordingResult {
        let url = source.appendingPathComponent("\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 7, count: fixtureBytes))
        return RecordingResult(fileURL: url, title: title, durationMs: 1_000, waveformPeaks: Array(repeating: 0.5, count: 10),
                               recordedAt: Date(timeIntervalSince1970: 1_800_000_000.123), transcript: nil)
    }

    private var result: RecordingResult { makeResult(title: "Memo 1") }

    private static let stampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()

    private func stamp(_ offset: TimeInterval = 0) -> String { Self.stampFormatter.string(from: Date().addingTimeInterval(offset)) }

    private func memoJSON(_ id: String, status: String = "pending") -> String {
        #"{"id":"\#(id)","title":"Memo 1","url":null,"urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":\#(fixtureBytes),"durationMs":1000,"waveformPeaks":[0.5],"transcript":null,"transcriptSegments":null,"transcriptStatus":"pending","transcriptSource":null,"uploadStatus":"\#(status)","recordedAt":"\#(stamp())","createdAt":"\#(stamp())","updatedAt":"\#(stamp())"}"#
    }

    private func stubHappyPath(id: String) {
        let ticket = #"{"url":"https://r2.test/\#(id)","method":"PUT","headers":{"Content-Type":"audio/mp4","Content-Length":"\#(fixtureBytes)"},"expiresAt":"\#(stamp(900))"}"#
        api.stub("POST", "/api/memos", json: #"{"memo":\#(memoJSON(id)),"upload":\#(ticket)}"#)
        api.stub("PATCH", "/api/memos/\(id)/complete", json: #"{"memo":\#(memoJSON(id, status: "ready"))}"#)
    }

    private func summary(id: String, title: String) -> VoiceMemoSummary {
        let json = #"{"id":"\#(id)","title":"\#(title)","mimeType":"audio/mp4","fileSize":5000,"durationMs":1000,"transcriptPreview":null,"transcriptStatus":"none","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp())","createdAt":"\#(stamp())","updatedAt":"\#(stamp())"}"#
        return try! JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(json.utf8))
    }

    // MARK: - Tests

    func testOfflineBacksOffThenFlushes() async throws {
        try controller.enqueue(result)
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        var slept: [Duration] = []
        controller = makeController(sleep: { d in slept.append(d); if slept.count == 3 { self.api.errorFor = nil; self.stubHappyPath(id: "m1") } })
        await controller.flush()
        XCTAssertEqual(slept, [.seconds(5), .seconds(30), .seconds(120)])
        XCTAssertEqual(MemoUploadController.delay(forAttempt: 9), .seconds(600))
        XCTAssertTrue(controller.pending().isEmpty)
    }

    func testA401PausesWithoutBackoffAndKeepsFiles() async throws {
        try controller.enqueue(result); api.errorToThrow = APIError.unauthorized
        var slept: [Duration] = []; controller = makeController(sleep: { slept.append($0) })
        await controller.flush()
        XCTAssertTrue(controller.isPausedForAuth); XCTAssertTrue(slept.isEmpty)
        XCTAssertEqual(controller.pending().first?.attempts, 0); XCTAssertEqual(controller.pending().count, 1)
    }

    func testResumeAfterSignInClearsThePauseAndFlushes() async throws {
        try controller.enqueue(result); api.errorToThrow = APIError.unauthorized
        await controller.flush()
        api.errorToThrow = nil; stubHappyPath(id: "m1")
        await controller.resumeAfterSignIn()
        XCTAssertFalse(controller.isPausedForAuth)
        XCTAssertTrue(controller.pending().isEmpty)
    }

    func testUserBSignsInAndUploadsNoneOfUserAsMemos() async throws {
        let a = makeController(user: "userA"); try a.enqueue(result); a.cancel()
        let b = makeController(user: "userB"); stubHappyPath(id: "m1")
        await b.flush()
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 0)
        XCTAssertEqual(makeController(user: "userA").pending().count, 1)
        let folder = try MemoStorage.folder(environment: "Local", userId: "userA", root: root.appendingPathComponent("storage"))
        XCTAssertTrue(folder.path.hasSuffix("memos/Local/userA"))
        XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testCancelKeepsTheFilesAndManifests() async throws {
        try controller.enqueue(result)
        controller.cancel()
        XCTAssertEqual(controller.pending().count, 1)
    }

    func testALeftoverDraftIsRecoveredAndEnqueued() async throws {
        let caf = try MemoAudioFixtures.sineCAF(seconds: 1, in: draftsDir)
        try drafts.write(.init(cafURL: caf, startedAt: Date(), title: "Memo 3", ownerUserId: "userA", environment: "Local"))
        await controller.recoverDrafts(drafts: drafts, transcriber: StubTranscriber(result: nil))
        XCTAssertEqual(controller.pending().map(\.title), ["Memo 3"])
        XCTAssertNil(controller.pending().first?.transcript)
        XCTAssertTrue(drafts.recoverable().isEmpty)
    }

    func testNextMemoTitleCountsCacheAndQueue() throws {
        state.voiceMemos.upsert(summary(id: "m1", title: "Memo 4"))
        state.memoUploads = makeController(user: "userA"); try state.memoUploads!.enqueue(makeResult(title: "Memo 6"))
        XCTAssertEqual(state.nextMemoTitle(), "Memo 7")
    }
}
