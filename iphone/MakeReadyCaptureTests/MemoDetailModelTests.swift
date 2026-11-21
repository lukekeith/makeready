//
//  MemoDetailModelTests.swift
//  MakeReadyCaptureTests
//
//  `MemoDetailModel` (D4, D8, D17) over a private AppState, a StubAPIClient, a temp-directory
//  MemoUploadController and a MemoPlayer on a spy backend.
//

import XCTest
@testable import MakeReady

@MainActor
private final class DetailSpyBackend: MemoPlaybackBackend {
    var onFailure: ((Int?) -> Void)?
    var onEnded: (() -> Void)?
    var currentTime: Double = 0
    private(set) var loaded: [URL] = []
    private(set) var seeks: [Double] = []
    private(set) var plays = 0

    func load(url: URL) { loaded.append(url) }
    func play() { plays += 1 }
    func pause() {}
    func seek(to seconds: Double) { seeks.append(seconds) }
}

@MainActor
private final class DetailSpySession: MemoPlaybackSessionControlling {
    private(set) var calls: [String] = []
    func activatePlayback() throws { calls.append("activatePlayback") }
    func restore() { calls.append("restore") }
}

@MainActor
final class MemoDetailModelTests: XCTestCase {

    private var root: URL!
    private var state: AppState!
    private var api: StubAPIClient!
    private var transport: SpyTransport!
    private var uploads: MemoUploadController!
    private var backend: DetailSpyBackend!
    private var session: DetailSpySession!

    override func setUpWithError() throws {
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        transport = SpyTransport()
        backend = DetailSpyBackend()
        session = DetailSpySession()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("memo-detail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("recorded"), withIntermediateDirectories: true)
        uploads = MemoUploadController(api: api, actions: MemoActions(api: api, state: state), transport: transport,
                                       directory: root.appendingPathComponent("queue"), ownerUserId: "user-a",
                                       environment: "Local")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        StatePersistence.shared.clear()
        super.tearDown()
    }

    // MARK: - Fixtures

    private func makeModel(memoId: String) -> MemoDetailModel {
        let actions = MemoActions(api: api, state: state)
        let player = MemoPlayer(backend: backend, session: session,
                                fetchDetail: { try await actions.loadMemo(id: $0) })
        return MemoDetailModel(memoId: memoId, actions: actions, uploads: uploads, player: player, state: state)
    }

    private static let stampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()

    private func memoJSON(_ id: String, title: String = "Memo 1", status: String = "ready") -> String {
        let stamp = Self.stampFormatter.string(from: Date())
        return #"{"id":"\#(id)","title":"\#(title)","url":"https://r2.test/\#(id).m4a","urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":4096,"durationMs":1000,"waveformPeaks":[0.5],"transcript":null,"transcriptSegments":null,"transcriptStatus":"pending","transcriptSource":null,"uploadStatus":"\#(status)","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
    }

    private func summary(_ id: String) throws -> VoiceMemoSummary {
        let memo = try JSONDecoder.apiDecoder.decode(VoiceMemo.self, from: Data(memoJSON(id).utf8))
        return VoiceMemoSummary(memo)
    }

    private func enqueueItem() throws -> MemoQueueItem {
        let url = root.appendingPathComponent("recorded/\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 7, count: 4_096))
        let result = RecordingResult(fileURL: url, title: "Memo 1", durationMs: 1_000, waveformPeaks: [0.5],
                                     recordedAt: Date(), transcript: nil)
        return try uploads.enqueue(result)
    }

    /// Drives the stubbed create -> PUT -> complete for the queue's oldest item.
    private func completeUpload(_ item: MemoQueueItem, serverId: String) async {
        let stamp = Self.stampFormatter.string(from: Date().addingTimeInterval(900))
        let ticket = #"{"url":"https://r2.test/\#(serverId)","method":"PUT","headers":{"Content-Type":"audio/mp4","Content-Length":"4096"},"expiresAt":"\#(stamp)"}"#
        api.stub("POST", "/api/memos", json: #"{"memo":\#(memoJSON(serverId, status: "pending")),"upload":\#(ticket)}"#)
        api.stub("PATCH", "/api/memos/\(serverId)/complete", json: #"{"memo":\#(memoJSON(serverId))}"#)
        _ = await uploads.processNext()
    }

    // MARK: - Tests

    func testALocalIdTargetsTheQueueAnyOtherIdTheServer() {
        XCTAssertEqual(MemoDetailModel.target("local:q1"), .local("q1"))
        XCTAssertEqual(MemoDetailModel.target("m1"), .server("m1"))
    }

    func testAnEmptyRenameRevertsAndSendsNothing() async {
        let model = makeModel(memoId: "m1")
        await model.rename("   ")
        XCTAssertTrue(api.recordedCalls(method: "PATCH").isEmpty)
    }

    func testARenameIsTrimmedAndCutTo120Characters() async {
        api.stub("PATCH", "/api/memos/m1", json: #"{"memo":\#(memoJSON("m1"))}"#)
        await makeModel(memoId: "m1").rename("  " + String(repeating: "a", count: 130) + "  ")
        let title = api.recordedCalls(method: "PATCH").first?.body?["title"] as? String
        XCTAssertEqual(title, String(repeating: "a", count: 120))
    }

    func testDeleteRemovesTheMemoFromLibraryAndAsksToPop() async throws {
        state.voiceMemos.upsert(try summary("m1"))
        api.stubStatus("DELETE", "/api/memos/m1", status: 204)
        let popped = await makeModel(memoId: "m1").delete()
        XCTAssertTrue(popped)
        XCTAssertNil(state.voiceMemos["m1"])
    }

    func testAFailedDeleteStaysOnThePageAndSurfacesTheError() async throws {
        state.voiceMemos.upsert(try summary("m1"))
        api.errorToThrow = URLError(.notConnectedToInternet)
        let popped = await makeModel(memoId: "m1").delete()
        XCTAssertFalse(popped)
        XCTAssertNotNil(state.voiceMemos["m1"])
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't delete this memo")
    }

    func testAServerLoadPlaysTheMemosUrl() async {
        api.stub("GET", "/api/memos/m1", json: #"{"memo":\#(memoJSON("m1"))}"#)
        let model = makeModel(memoId: "m1")
        await model.load()
        XCTAssertEqual(backend.loaded.map(\.absoluteString), ["https://r2.test/m1.m4a"])
        XCTAssertEqual(model.screenState(now: Date(), calendar: .current).title, "Memo 1")
    }

    func testAFailedLoadSurfacesTheError() async {
        let model = makeModel(memoId: "m1")
        await model.load()
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't load this memo")
        XCTAssertTrue(backend.loaded.isEmpty)
    }

    func testALocalLoadPlaysTheQueuedFile() async throws {
        let item = try enqueueItem()
        let model = makeModel(memoId: "local:\(item.localId)")
        await model.load()
        XCTAssertEqual(backend.loaded, [uploads.fileURL(for: item)])
    }

    func testALocalPageSwitchesToTheServerMemoOnceTheUploadCompletes() async throws {
        let item = try enqueueItem()
        let model = makeModel(memoId: "local:\(item.localId)")
        await model.load()
        api.stub("GET", "/api/memos/m9", json: #"{"memo":\#(memoJSON("m9"))}"#)
        await completeUpload(item, serverId: "m9")
        await model.syncQueued()
        XCTAssertEqual(model.target, .server("m9"))
        XCTAssertEqual(backend.loaded.last?.absoluteString, "https://r2.test/m9.m4a")
    }

    /// Walk round 1 (E2): the page's first state already carries the queued memo's title — the screen
    /// copies its title into the rename field once, when it is created.
    func testALocalPagesFirstStateCarriesTheQueuedTitle() throws {
        let item = try enqueueItem()
        let model = makeModel(memoId: "local:\(item.localId)")
        XCTAssertEqual(model.screenState(now: Date(), calendar: .current).title, "Memo 1")
    }

    /// Walk round 2 (E2): the toast's View is tapped after the upload already finished — the item has left
    /// the queue, so the page opens on the server memo with its title in the first state.
    func testALocalPageWhoseUploadAlreadyFinishedOpensTitledOnTheServerMemo() async throws {
        let item = try enqueueItem()
        await completeUpload(item, serverId: "m9")
        XCTAssertNil(uploads.item(localId: item.localId))
        let model = makeModel(memoId: "local:\(item.localId)")
        XCTAssertEqual(model.target, .server("m9"))
        XCTAssertEqual(model.screenState(now: Date(), calendar: .current).title, "Memo 1")
    }

    /// Walk round 1 (item 3): the create POST has returned (the item has a server id) but the PUT has not
    /// succeeded — the page keeps playing the local file.
    func testALocalPageStaysLocalUntilTheUploadCompletes() async throws {
        let item = try enqueueItem()
        let model = makeModel(memoId: "local:\(item.localId)")
        await model.load()
        let stamp = Self.stampFormatter.string(from: Date().addingTimeInterval(900))
        let ticket = #"{"url":"https://r2.test/m9","method":"PUT","headers":{"Content-Type":"audio/mp4","Content-Length":"4096"},"expiresAt":"\#(stamp)"}"#
        api.stub("POST", "/api/memos", json: #"{"memo":\#(memoJSON("m9", status: "pending")),"upload":\#(ticket)}"#)
        transport.nextStatus = 500
        _ = await uploads.processNext()
        XCTAssertEqual(uploads.item(localId: item.localId)?.serverId, "m9")
        await model.syncQueued()
        XCTAssertEqual(model.target, .local(item.localId))
        XCTAssertEqual(backend.loaded, [uploads.fileURL(for: item)])
    }

    func testRenamingAQueuedMemoRewritesItsManifest() async throws {
        let item = try enqueueItem()
        await makeModel(memoId: "local:\(item.localId)").rename("Retreat ideas")
        XCTAssertEqual(uploads.item(localId: item.localId)?.title, "Retreat ideas")
    }

    func testDeletingAQueuedMemoRemovesItsFileAndPops() async throws {
        let item = try enqueueItem()
        let popped = await makeModel(memoId: "local:\(item.localId)").delete()
        XCTAssertTrue(popped)
        XCTAssertNil(uploads.item(localId: item.localId))
        XCTAssertFalse(FileManager.default.fileExists(atPath: uploads.fileURL(for: item).path))
    }

    func testSeekingAParagraphSeeksToItsStartAndPlays() async throws {
        let stamp = Self.stampFormatter.string(from: Date())
        let json = #"{"id":"m1","title":"Memo 1","url":"https://r2.test/m1.m4a","urlExpiresAt":null,"mimeType":"audio/mp4","fileSize":4096,"durationMs":60000,"waveformPeaks":null,"transcript":"a b","transcriptSegments":[{"text":"a","startMs":0,"endMs":5000},{"text":"b","startMs":12000,"endMs":20000}],"transcriptStatus":"ready","transcriptSource":"server","uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
        api.stub("GET", "/api/memos/m1", json: #"{"memo":\#(json)}"#)
        let model = makeModel(memoId: "m1")
        await model.load()
        model.seekParagraph(1)
        XCTAssertEqual(backend.seeks, [12])
        XCTAssertEqual(backend.plays, 1)
    }

    func testStopRestoresTheAudioSession() {
        makeModel(memoId: "m1").stop()
        XCTAssertEqual(session.calls, ["restore"])
    }
}
