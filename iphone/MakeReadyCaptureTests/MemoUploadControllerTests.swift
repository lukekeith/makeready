//
//  MemoUploadControllerTests.swift
//  MakeReadyCaptureTests
//
//  The persistent upload queue (D13, D22, D29, D37, D40, D41) against a StubAPIClient, a
//  SpyTransport and a private AppState. Every test builds its own controller over a temp
//  directory; nothing here touches `AppState.shared`'s controller.
//

import XCTest
@testable import MakeReady

/// Records each PUT and answers with a scripted status: `statuses` first, then `nextStatus`.
final class SpyTransport: MemoPutTransport {
    struct Put { let fileURL: URL; let url: URL; let headers: [String: String] }
    private(set) var puts: [Put] = []
    var nextStatus = 200
    var statuses: [Int] = []
    var error: Error?

    func put(fileURL: URL, to url: URL, headers: [String: String]) async throws -> Int {
        puts.append(Put(fileURL: fileURL, url: url, headers: headers))
        if let error { throw error }
        return statuses.isEmpty ? nextStatus : statuses.removeFirst()
    }
}

@MainActor
final class MemoUploadControllerTests: XCTestCase {

    private var dir: URL!
    private var source: URL!
    private var state: AppState!
    private var api: StubAPIClient!
    private var transport: SpyTransport!
    private var controller: MemoUploadController!
    private let fixtureBytes = 4_096

    override func setUpWithError() throws {
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        transport = SpyTransport()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("memo-upload-\(UUID().uuidString)")
        dir = root.appendingPathComponent("queue")
        source = root.appendingPathComponent("recorded")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        controller = makeController()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir.deletingLastPathComponent())
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func makeController(owner: String = "user-a", environment: String = "Local") -> MemoUploadController {
        MemoUploadController(api: api, actions: MemoActions(api: api, state: state), transport: transport,
                             directory: dir, ownerUserId: owner, environment: environment, now: { Date() })
    }

    // MARK: - Fixtures

    private func makeResult(transcript: Transcript?) -> RecordingResult {
        let url = source.appendingPathComponent("\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 7, count: fixtureBytes))
        return RecordingResult(fileURL: url, title: "Memo 1", durationMs: 1_000, waveformPeaks: Array(repeating: 0.5, count: 10),
                               recordedAt: Date(timeIntervalSince1970: 1_800_000_000.123), transcript: transcript)
    }

    private var result: RecordingResult {
        makeResult(transcript: Transcript(text: "hello", segments: [TranscriptSegment(text: "hello", startMs: 0, endMs: 500)]))
    }

    private var resultWithoutTranscript: RecordingResult { makeResult(transcript: nil) }

    private static let stampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()

    private func stamp(_ offset: TimeInterval = 0) -> String { Self.stampFormatter.string(from: Date().addingTimeInterval(offset)) }

    private func memoJSON(_ id: String, status: String = "pending") -> String {
        #"{"id":"\#(id)","title":"Memo 1","url":null,"urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":\#(fixtureBytes),"durationMs":1000,"waveformPeaks":[0.5],"transcript":null,"transcriptSegments":null,"transcriptStatus":"pending","transcriptSource":null,"uploadStatus":"\#(status)","recordedAt":"\#(stamp())","createdAt":"\#(stamp())","updatedAt":"\#(stamp())"}"#
    }

    private func ticketJSON(url: String, expiresIn: TimeInterval) -> String {
        #"{"url":"\#(url)","method":"PUT","headers":{"Content-Type":"audio/mp4","Content-Length":"\#(fixtureBytes)"},"expiresAt":"\#(stamp(expiresIn))"}"#
    }

    private func stubCreate(id: String, expiresIn: TimeInterval) {
        api.stub("POST", "/api/memos", json: #"{"memo":\#(memoJSON(id)),"upload":\#(ticketJSON(url: "https://r2.test/\(id)", expiresIn: expiresIn))}"#)
    }

    private func stubRemint(id: String, url: String) {
        api.stub("POST", "/api/memos/\(id)/upload", json: #"{"upload":\#(ticketJSON(url: url, expiresIn: 900))}"#)
    }

    private func stubComplete(id: String) {
        api.stub("PATCH", "/api/memos/\(id)/complete", json: #"{"memo":\#(memoJSON(id, status: "ready"))}"#)
    }

    private func queueFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    // MARK: - Tests

    func testCreatePutCompleteThenDeletesTheFile() async throws {
        try controller.enqueue(result)
        let size = try XCTUnwrap(controller.pending().first?.fileSize)
        stubCreate(id: "m1", expiresIn: 900); stubComplete(id: "m1")
        let step = await controller.processNext()
        XCTAssertEqual(step, .completed("m1"))
        XCTAssertEqual(transport.puts.count, 1)
        XCTAssertEqual(transport.puts[0].headers["Content-Length"], String(size))
        XCTAssertTrue(controller.pending().isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
        XCTAssertNotNil(state.voiceMemos["m1"])
    }

    func testAfterACrashBetweenPostAndPutItResumesWithoutASecondCreate() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
        transport.nextStatus = 500
        _ = await controller.processNext()
        let relaunched = makeController()
        transport.nextStatus = 200; stubComplete(id: "m1")
        let step = await relaunched.processNext()
        XCTAssertEqual(step, .completed("m1"))
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 1)
    }

    func testAnExpiredTicketOrA403IsReMinted() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: -1); stubRemint(id: "m1", url: "https://r2.test/fresh"); stubComplete(id: "m1")
        _ = await controller.processNext()
        XCTAssertEqual(api.callCount("POST", "/api/memos/m1/upload"), 1)
        XCTAssertEqual(transport.puts.last?.url.absoluteString, "https://r2.test/fresh")
        try controller.enqueue(result); stubCreate(id: "m2", expiresIn: 900); stubRemint(id: "m2", url: "https://r2.test/f2"); stubComplete(id: "m2")
        transport.statuses = [403, 200]  // a 403 PUT re-mints once
        let step = await controller.processNext(); XCTAssertEqual(step, .completed("m2")); XCTAssertEqual(api.callCount("POST", "/api/memos/m2/upload"), 1)
    }

    func testA404OnCompleteRePostsTheMemo() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/complete" ? APIHTTPError(status: 404, message: "Memo not found", details: [:]) : nil }
        _ = await controller.processNext()
        api.errorFor = nil; stubCreate(id: "m2", expiresIn: 900); stubComplete(id: "m2")
        let step = await controller.processNext(); XCTAssertEqual(step, .completed("m2"))
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 2)
    }

    func testTheTranscriptIsSentOnlyWhenPresent() async throws {
        try controller.enqueue(resultWithoutTranscript); stubCreate(id: "m1", expiresIn: 900); stubComplete(id: "m1")
        _ = await controller.processNext()
        let body = try XCTUnwrap(api.calls.first { $0.endpoint == "/api/memos" }?.body)
        XCTAssertNil(body["transcript"]); XCTAssertNil(body["transcriptSegments"])
        XCTAssertTrue((body["recordedAt"] as? String)?.hasSuffix("Z") == true)
    }

    func testTheTranscriptAndAStableRecordedAtAreSentAcrossARelaunch() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/complete" ? APIHTTPError(status: 404, message: nil, details: [:]) : nil }
        _ = await controller.processNext()  // 404 on complete clears serverId; the next pass re-POSTs
        stubCreate(id: "m2", expiresIn: 900); stubComplete(id: "m2"); api.errorFor = nil
        _ = await makeController().processNext()
        let posts = api.calls.filter { $0.endpoint == "/api/memos" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(posts[0].body?["recordedAt"] as? String, "2027-01-15T08:00:00.123Z")
        XCTAssertEqual(posts[1].body?["recordedAt"] as? String, posts[0].body?["recordedAt"] as? String)
        XCTAssertEqual(posts[1].body?["transcript"] as? String, "hello")
        XCTAssertEqual((posts[1].body?["transcriptSegments"] as? [[String: Any]])?.count, 1)
    }

    func testA409OnCompleteReMintsAndRePutsWithoutACreate() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900); stubRemint(id: "m1", url: "https://r2.test/again")
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/complete" ? APIHTTPError(status: 409, message: "missing", details: [:]) : nil }
        let step = await controller.processNext(); XCTAssertEqual(step, .retryLater)
        XCTAssertNil(controller.pending().first?.upload); XCTAssertEqual(controller.pending().first?.serverId, "m1")
        api.errorFor = nil; stubComplete(id: "m1")
        let second = await controller.processNext(); XCTAssertEqual(second, .completed("m1"))
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 1)
        XCTAssertEqual(transport.puts.map(\.url.absoluteString), ["https://r2.test/m1", "https://r2.test/again"])
    }

    func testA404OnReMintForgetsTheMemoAndTheNextPassRePosts() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: -1)
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/upload" ? APIHTTPError(status: 404, message: "Memo not found", details: [:]) : nil }
        let step = await controller.processNext(); XCTAssertEqual(step, .retryLater)
        XCTAssertNil(controller.pending().first?.serverId); XCTAssertNil(controller.pending().first?.upload)
        XCTAssertTrue(transport.puts.isEmpty)
        api.errorFor = nil; stubCreate(id: "m2", expiresIn: 900); stubComplete(id: "m2")
        let second = await controller.processNext(); XCTAssertEqual(second, .completed("m2"))
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 2)
    }

    func testA403ThenA404OnReMintForgetsTheMemo() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
        transport.statuses = [403]
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/upload" ? APIHTTPError(status: 404, message: "Memo not found", details: [:]) : nil }
        let step = await controller.processNext(); XCTAssertEqual(step, .retryLater)
        XCTAssertNil(controller.pending().first?.serverId); XCTAssertNil(controller.pending().first?.upload)
        XCTAssertEqual(transport.puts.count, 1)
        api.errorFor = nil; stubCreate(id: "m2", expiresIn: 900); stubComplete(id: "m2")
        _ = await controller.processNext()
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 2)
    }

    func testA409OnReMintGoesStraightToCompleteWithoutAPut() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: -1); stubComplete(id: "m1")
        api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/upload" ? APIHTTPError(status: 409, message: "already uploaded", details: [:]) : nil }
        let step = await controller.processNext(); XCTAssertEqual(step, .completed("m1"))
        XCTAssertTrue(transport.puts.isEmpty)
        XCTAssertTrue(controller.pending().isEmpty)
    }

    func testAnUnparseableTicketURLIsDroppedSoTheNextPassReMints() async throws {
        try controller.enqueue(result)
        api.stub("POST", "/api/memos", json: #"{"memo":\#(memoJSON("m1")),"upload":\#(ticketJSON(url: "", expiresIn: 900))}"#)
        let step = await controller.processNext(); XCTAssertEqual(step, .retryLater)
        XCTAssertEqual(controller.pending().first?.serverId, "m1"); XCTAssertNil(controller.pending().first?.upload)
        XCTAssertTrue(transport.puts.isEmpty)
        stubRemint(id: "m1", url: "https://r2.test/good"); stubComplete(id: "m1")
        let second = await controller.processNext(); XCTAssertEqual(second, .completed("m1"))
        XCTAssertEqual(transport.puts.map(\.url.absoluteString), ["https://r2.test/good"])
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 1)
    }

    func testAFailedPutKeepsTheFileAndTheManifest() async throws {
        try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
        transport.nextStatus = 500
        let step = await controller.processNext(); XCTAssertEqual(step, .retryLater)
        XCTAssertEqual(try queueFiles().count, 2)
        XCTAssertEqual(controller.pending().first?.serverId, "m1")
    }

    func testA401PausesAndKeepsEverything() async throws {
        try controller.enqueue(result)
        api.errorToThrow = APIError.unauthorized
        let step = await controller.processNext(); XCTAssertEqual(step, .paused)
        XCTAssertEqual(controller.pending().count, 1); XCTAssertEqual(try queueFiles().count, 2)
        XCTAssertTrue(transport.puts.isEmpty)
    }

    func testAnotherUsersItemsAreNeitherListedNorUploaded() async throws {
        try controller.enqueue(result)
        let userB = makeController(owner: "user-b")
        XCTAssertTrue(userB.pending().isEmpty)
        let step = await userB.processNext(); XCTAssertEqual(step, .idle)
        XCTAssertEqual(api.callCount("POST", "/api/memos"), 0)
        XCTAssertEqual(makeController(environment: "Staging").pending().count, 0)
        XCTAssertEqual(controller.pending().count, 1)
    }

    func testEnqueueTouchesNoNetworkAndMovesTheFile() throws {
        let item = result
        try controller.enqueue(item)
        XCTAssertTrue(api.calls.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.fileURL.path))
        XCTAssertEqual(try queueFiles().count, 2)
        XCTAssertEqual(controller.pending().first?.fileSize, fixtureBytes)
    }

    func testAnItemNotYetDueIsSkipped() async throws {
        var clock = Date()
        let timed = MemoUploadController(api: api, actions: MemoActions(api: api, state: state), transport: transport,
                                         directory: dir, ownerUserId: "user-a", environment: "Local", now: { clock })
        try timed.enqueue(result)
        let manifest = dir.appendingPathComponent("\(try XCTUnwrap(timed.pending().first?.localId)).json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        json["nextAttemptAt"] = Self.stampFormatter.string(from: clock.addingTimeInterval(60))
        try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        let step = await timed.processNext(); XCTAssertEqual(step, .idle)
        clock = clock.addingTimeInterval(61)
        stubCreate(id: "m1", expiresIn: 900); stubComplete(id: "m1")
        let later = await timed.processNext(); XCTAssertEqual(later, .completed("m1"))
    }
}
