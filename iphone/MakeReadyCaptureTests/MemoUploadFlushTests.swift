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
        controller = try makeController()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func makeController(user: String = "userA", flushesOnEnqueue: Bool = false,
                                sleep: @escaping (Duration) async throws -> Void = { _ in }) throws -> MemoUploadController {
        let folder = try MemoStorage.folder(environment: "Local", userId: user, root: root.appendingPathComponent("storage"))
        return MemoUploadController(api: api, actions: MemoActions(api: api, state: state), transport: transport,
                                    directory: folder, ownerUserId: user, environment: "Local",
                                    flushesOnEnqueue: flushesOnEnqueue, sleep: sleep)
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
        controller = try makeController(sleep: { d in slept.append(d); if slept.count == 3 { self.api.errorFor = nil; self.stubHappyPath(id: "m1") } })
        await controller.flush()
        XCTAssertEqual(slept, [.seconds(5), .seconds(30), .seconds(120)])
        XCTAssertEqual(MemoUploadController.delay(forAttempt: 9), .seconds(600))
        XCTAssertTrue(controller.pending().isEmpty)
    }

    func testA401PausesWithoutBackoffAndKeepsFiles() async throws {
        try controller.enqueue(result); api.errorToThrow = APIError.unauthorized
        var slept: [Duration] = []; controller = try makeController(sleep: { slept.append($0) })
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
        let a = try makeController(user: "userA"); try a.enqueue(result); a.cancel()
        let b = try makeController(user: "userB"); stubHappyPath(id: "m1")
        await b.flush()
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 0)
        XCTAssertEqual(try makeController(user: "userA").pending().count, 1)
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

    func testAnEmptyDraftIsDeletedNotEnqueued() async throws {
        let caf = try MemoAudioFixtures.sineCAF(seconds: 0, in: draftsDir)
        try drafts.write(.init(cafURL: caf, startedAt: Date(), title: "Memo 8", ownerUserId: "userA", environment: "Local"))
        await controller.recoverDrafts(drafts: drafts, transcriber: StubTranscriber(result: nil))
        XCTAssertTrue(controller.pending().isEmpty)
        XCTAssertTrue(drafts.recoverable().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf.deletingPathExtension().appendingPathExtension("json").path))
    }

    func testADraftManifestStoresOnlyTheFileNameAndOldAbsoluteOnesStillResolve() throws {
        let caf = try MemoAudioFixtures.sineCAF(seconds: 1, in: draftsDir)
        let manifestURL = caf.deletingPathExtension().appendingPathExtension("json")
        try drafts.write(.init(cafURL: caf, startedAt: Date(), title: "Memo 9", ownerUserId: "userA", environment: "Local"))
        let stored = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertFalse(stored.contains(draftsDir.path))
        XCTAssertEqual(drafts.recoverable().first?.cafURL.path, draftsDir.appendingPathComponent(caf.lastPathComponent).path)

        // A manifest written before this change held an absolute URL from a container that has since moved.
        let old = #"{"cafURL":"file:///old-container/drafts/\#(caf.lastPathComponent)","startedAt":0,"title":"Memo 9","ownerUserId":"userA","environment":"Local"}"#
        try Data(old.utf8).write(to: manifestURL)
        XCTAssertEqual(drafts.recoverable().first?.cafURL.path, draftsDir.appendingPathComponent(caf.lastPathComponent).path)
    }

    func testSegmentTimesAreClampedIntoTheDurationOnCreate() async throws {
        let base = result
        let transcript = Transcript(text: "a b", segments: [TranscriptSegment(text: "a", startMs: -5, endMs: 400),
                                                           TranscriptSegment(text: "b", startMs: 900, endMs: 1_001)])
        try controller.enqueue(RecordingResult(fileURL: base.fileURL, title: base.title, durationMs: 1_000, waveformPeaks: base.waveformPeaks,
                                               recordedAt: base.recordedAt, transcript: transcript))
        stubHappyPath(id: "m1")
        await controller.flush()
        let segments = try XCTUnwrap(api.calls.first { $0.endpoint == "/api/memos" }?.body?["transcriptSegments"] as? [[String: Any]])
        XCTAssertEqual(segments.map { $0["startMs"] as? Int }, [0, 900])
        XCTAssertEqual(segments.map { $0["endMs"] as? Int }, [400, 1_000])
    }

    func testNextMemoTitleCountsCacheAndQueue() throws {
        state.voiceMemos.upsert(summary(id: "m1", title: "Memo 4"))
        state.memoUploads = try makeController(user: "userA"); try state.memoUploads!.enqueue(makeResult(title: "Memo 6"))
        XCTAssertEqual(state.nextMemoTitle(), "Memo 7")
    }

    func testSignOutAndEnvironmentSwitchReleaseTheControllerAndKeepTheFiles() async throws {
        state.memoUploads = try makeController(user: "userA"); try state.memoUploads!.enqueue(result)
        let kept = try makeController(user: "userA")
        state.clearAllData()
        XCTAssertNil(state.memoUploads)
        XCTAssertEqual(kept.pending().count, 1)

        state.memoUploads = kept
        state.reloadForEnvironmentSwitch()
        XCTAssertNil(state.memoUploads)
        XCTAssertEqual(try makeController(user: "userA").pending().count, 1)
    }

    func testEnqueueTriggersAFlush() async throws {
        stubHappyPath(id: "m1")
        controller = try makeController(flushesOnEnqueue: true)
        try controller.enqueue(result)
        // No explicit flush: only the enqueue itself can start the upload.
        var yields = 0
        while !controller.pending().isEmpty, yields < 5_000 { await Task.yield(); try await Task.sleep(for: .milliseconds(1)); yields += 1 }
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 1)
        XCTAssertTrue(controller.pending().isEmpty)
        controller.cancel()
    }

    func testAPoisonItemDoesNotStarveTheOnesBehindIt() async throws {
        let poison = makeResult(title: "Memo 1"), good = makeResult(title: "Memo 2")
        let early = RecordingResult(fileURL: poison.fileURL, title: poison.title, durationMs: 1_000, waveformPeaks: poison.waveformPeaks,
                                    recordedAt: Date(timeIntervalSince1970: 1_700_000_000), transcript: nil)
        controller = try makeController(sleep: { _ in throw CancellationError() })   // ends the flush at the first backoff wait
        try controller.enqueue(early); try controller.enqueue(good)
        stubHappyPath(id: "m2")
        api.errorFor = { _, body in (body?["title"] as? String) == "Memo 1" ? URLError(.badServerResponse) : nil }
        await controller.flush()
        XCTAssertEqual(controller.pending().map(\.title), ["Memo 1"])
        XCTAssertEqual(controller.pending().first?.attempts, 1)
    }

    func testANetworkReturnWakesABackoffSleep() async throws {
        try controller.enqueue(result)
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        var slept: [Duration] = []
        controller = try makeController(sleep: { d in
            slept.append(d)
            if slept.count == 1 {
                self.api.errorFor = nil; self.stubHappyPath(id: "m1")
                try await Task.sleep(for: .seconds(60))   // only a wake (cancel) ends this
            }
        })
        let flushing = Task { await controller.flush() }
        while slept.isEmpty { await Task.yield() }
        await controller.networkReturned()
        await flushing.value
        XCTAssertEqual(slept, [.seconds(5)])
        XCTAssertTrue(controller.pending().isEmpty)
    }

    func testANetworkReturnRetriesEveryBackedOffItem() async throws {
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        var slept: [Duration] = []
        controller = try makeController(sleep: { d in
            slept.append(d)
            if slept.count == 1 {
                self.api.errorFor = nil; self.stubHappyPath(id: "m1")
                try await Task.sleep(for: .seconds(60))   // only a wake (cancel) ends this
            }
        })
        try controller.enqueue(makeResult(title: "Memo 1")); try controller.enqueue(makeResult(title: "Memo 2"))
        let flushing = Task { await controller.flush() }
        while slept.isEmpty { await Task.yield() }
        XCTAssertEqual(controller.pending().map(\.attempts), [1, 1])   // both backed off
        await controller.networkReturned()
        await flushing.value
        XCTAssertEqual(slept, [.seconds(5)])
        XCTAssertTrue(controller.pending().isEmpty)
    }
}
