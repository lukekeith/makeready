//
//  VideoUploadControllerTests.swift
//  MakeReadyCaptureTests
//
//  The video upload queue (video-recorder D12, D18, D22, D23, D24): the stage machine, the lost-create
//  retry, the banner after three failures, an attach job across a relaunch and a refused attach.
//  Every test builds its own controller over a temp folder with scripted doubles for the API, the
//  transport and the banner.
//

import UIKit
import XCTest
@testable import MakeReady

/// Scripts the server, Stream and the activity endpoints; records what the controller asked.
final class FakeVideoAPI: VideoUploadAPI, VideoStreamTransport {
    struct ActivityCreate: Equatable { let versionId: String; let title: String; let videoId: String }

    let createdId = "vid-1"
    private let readyAfterPolls: Int
    private let dropFirstCreateResponse: Bool
    private let failUploads: Int
    /// Thrown by the first attaches, in order; later ones succeed.
    private var attachErrors: [Error]
    /// What a failed upload throws.
    var uploadError: Error = URLError(.networkConnectionLost)
    /// Runs as each upload starts, with its 1-based number.
    var onUpload: (@MainActor (Int) throws -> Void)?

    private(set) var mints = 0
    private(set) var uploads: [(url: URL, fileURL: URL)] = []
    private(set) var createCalls = 0
    private(set) var created: [VideoCreateRequest] = []
    private(set) var polls = 0
    private(set) var activityCreates: [ActivityCreate] = []
    private(set) var activityReplaces: [(activityId: String, videoId: String)] = []

    init(readyAfterPolls: Int = 1, dropFirstCreateResponse: Bool = false, failUploads: Int = 0, attachErrors: [Error] = []) {
        self.readyAfterPolls = readyAfterPolls
        self.dropFirstCreateResponse = dropFirstCreateResponse
        self.failUploads = failUploads
        self.attachErrors = attachErrors
    }

    func mintUploadURL(title: String) async throws -> VideoUploadTicket {
        mints += 1
        return VideoUploadTicket(uploadUrl: "https://stream.test/upload/\(mints)", uid: "uid-\(mints)")
    }

    func upload(fileURL: URL, to url: URL) async throws -> Int {
        uploads.append((url, fileURL))
        try await onUpload?(uploads.count)
        if uploads.count <= failUploads { throw uploadError }
        return 200
    }

    func createVideo(_ request: VideoCreateRequest) async throws -> String {
        createCalls += 1
        created.append(request)
        if dropFirstCreateResponse && createCalls == 1 { throw URLError(.networkConnectionLost) }
        return createdId
    }

    func status(ofVideo id: String) async throws -> VideoStatus {
        polls += 1
        return polls > readyAfterPolls ? .ready : .pending
    }

    func attach(_ attach: VideoAttach, videoId: String) async throws {
        if !attachErrors.isEmpty { throw attachErrors.removeFirst() }
        if let activityId = attach.activityId {
            activityReplaces.append((activityId, videoId))
        } else {
            activityCreates.append(ActivityCreate(versionId: attach.versionId, title: attach.title, videoId: videoId))
        }
    }
}

@MainActor
final class BannerSpy: VideoUploadBanner {
    struct Shown { let message: String; let hasRetry: Bool }
    private(set) var shown: [Shown] = []

    func surface(_ error: Error, context: String, message: String, retry: (() -> Void)?) {
        shown.append(Shown(message: message, hasRetry: retry != nil))
    }
}

private extension Array where Element: Equatable {
    /// Drops an element equal to the one before it.
    func removingDuplicates() -> [Element] {
        reduce(into: []) { result, element in if result.last != element { result.append(element) } }
    }
}

@MainActor
final class VideoUploadControllerTests: XCTestCase {

    private var root: URL!
    private var dir: URL!
    private var source: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("video-upload-\(UUID().uuidString)")
        dir = root.appendingPathComponent("queue")
        source = root.appendingPathComponent("exported")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    // MARK: - Fixtures

    private func makeController(api: FakeVideoAPI, banner: BannerSpy? = nil, root: URL? = nil) -> VideoUploadController {
        VideoUploadController(api: api, transport: api, banner: banner ?? BannerSpy(), directory: root ?? dir,
                              ownerUserId: "user-a", environment: "Local", defaultTitle: { "Video 1" })
    }

    private func exported() -> ExportedVideo {
        let url = source.appendingPathComponent("\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 9, count: 4_096))
        let poster = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return ExportedVideo(url: url, durationSeconds: 42.5, posterImage: poster)
    }

    private func drain(_ controller: VideoUploadController) async {
        for _ in 0..<60 where await controller.processNext() != .idle {}
    }

    // MARK: - The stage machine (D12, D23)

    func testHappyPath() async throws {
        let c = makeController(api: FakeVideoAPI(readyAfterPolls: 1))
        _ = try c.enqueue(exported(), attach: nil)
        var stages: [VideoUploadStage] = []
        for _ in 0..<10 { if await c.processNext() == .idle { break }; stages.append(c.pending().first?.stage ?? .done) }
        XCTAssertEqual(stages.removingDuplicates(), [.uploading, .creating, .processing, .done])
    }

    func testEnqueueWritesTheManifestAndFilesWithoutTouchingTheNetwork() throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        let item = try c.enqueue(exported(), title: "Sunday", source: .imported, attach: nil)
        XCTAssertEqual(api.mints, 0)
        XCTAssertEqual(item.title, "Sunday")
        XCTAssertEqual(item.source, .imported)
        XCTAssertEqual(item.stage, .queued)
        XCTAssertEqual(item.durationSeconds, 42.5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.fileURL.path))
        let poster = try XCTUnwrap(item.posterURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: poster.path))
        XCTAssertEqual(c.pending().map(\.localId), [item.localId])
    }

    /// A kill between the queue's copy and the saver dropping its draft runs the save again.
    func testEnqueueingTheSameLocalIdAgainQueuesOneItem() throws {
        let c = makeController(api: FakeVideoAPI())
        let first = try c.enqueue(exported(), localId: "L1", attach: nil)
        let second = try c.enqueue(exported(), localId: "L1", attach: nil)
        XCTAssertEqual(first.localId, "L1")
        XCTAssertEqual(first, second)
        XCTAssertEqual(c.pending().count, 1)
    }

    func testAnOrphanedVideoFileDoesNotBlockTheSaveThatLeftIt() throws {
        let c = makeController(api: FakeVideoAPI())
        let item = try c.enqueue(exported(), localId: "L1", attach: nil)
        try FileManager.default.removeItem(at: item.fileURL.deletingPathExtension().appendingPathExtension("json"))
        XCTAssertEqual(c.pending().count, 0)
        _ = try c.enqueue(exported(), localId: "L1", attach: nil)
        XCTAssertEqual(c.pending().map(\.localId), ["L1"])
    }

    func testRemoveDropsTheQueuedFilesAndAnUnknownIdIsACancellation() throws {
        let c = makeController(api: FakeVideoAPI())
        let item = try c.enqueue(exported(), attach: nil)
        let poster = try XCTUnwrap(item.posterURL)
        try c.remove(localId: item.localId)
        XCTAssertTrue(c.pending().isEmpty)
        XCTAssertTrue(c.pendingItems.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: poster.path))
        XCTAssertThrowsError(try c.remove(localId: item.localId)) { XCTAssertTrue($0 is CancellationError) }
    }

    func testTheUploadStreamsTheQueuedFileAndTheStreamUidIsPersistedBeforeIt() async throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        let item = try c.enqueue(exported(), attach: nil)
        _ = await c.processNext()
        XCTAssertEqual(api.uploads.first?.fileURL, item.fileURL)
        XCTAssertEqual(c.pending().first?.streamUid, "uid-1")
    }

    func testAFailedUploadMintsAFreshUrlAndUidOnTheRetry() async throws {
        let api = FakeVideoAPI(failUploads: 1)
        let c = makeController(api: api)
        _ = try c.enqueue(exported(), attach: nil)
        _ = await c.processNext()
        _ = await c.processNext()
        XCTAssertEqual(api.mints, 2)
        XCTAssertEqual(api.uploads.map(\.url.lastPathComponent), ["1", "2"])
        _ = await c.processNext()
        XCTAssertEqual(api.created.first?.uid, "uid-2")
    }

    func testTheCreateCarriesTheSourceAndTheTranscript() async throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        let transcript = VideoTranscript(text: "hello there", segments: [VideoTranscriptSegment(text: "hello there", startMs: 0, endMs: 900)])
        _ = try c.enqueue(exported(), source: .imported, transcript: transcript, attach: nil)
        await drain(c)
        XCTAssertEqual(api.created.first?.source, .imported)
        XCTAssertEqual(api.created.first?.transcript, transcript)
        XCTAssertEqual(api.created.first?.title, "Video 1")
    }

    // MARK: - The wait for the on-device transcript (D10)

    func testAHeldItemUploadsWithTheTranscriptItWaitedFor() async throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        let transcript = VideoTranscript(text: "hello", segments: [])
        let item = try c.enqueue(exported(), attach: nil, transcriptHold: 600)
        XCTAssertEqual(c.pendingItems.map(\.localId), [item.localId])
        c.supplyTranscript(transcript, forLocalId: item.localId)
        XCTAssertNil(c.pending().first?.transcriptDue)
        await drain(c)
        XCTAssertEqual(api.created.first?.transcript, transcript)
    }

    func testTheFlushLeavesAHeldItemUntilItsTranscriptIsDue() async throws {
        let api = FakeVideoAPI()
        var waits: [Duration] = []
        let start = Date()
        var clock = start
        let c = VideoUploadController(api: api, transport: api, banner: BannerSpy(), directory: dir, ownerUserId: "user-a",
                                      environment: "Local", defaultTitle: { "Video 1" }, now: { clock },
                                      sleep: { wait in
                                          if waits.isEmpty { XCTAssertEqual(api.mints, 0) }
                                          waits.append(wait)
                                          clock = clock.addingTimeInterval(Double(wait.components.seconds) + 1)
                                      })
        _ = try c.enqueue(exported(), attach: nil, transcriptHold: 42)
        await c.networkReturned()
        XCTAssertEqual(Double(waits.first?.components.seconds ?? 0), 42, accuracy: 1)
        XCTAssertEqual(api.created.count, 1)
        XCTAssertNil(api.created.first?.transcript)
    }

    func testATranscriptThatComesAfterTheUploadBeganIsDropped() async throws {
        let c = makeController(api: FakeVideoAPI())
        let item = try c.enqueue(exported(), attach: nil, transcriptHold: 600)
        _ = await c.processNext()
        c.supplyTranscript(VideoTranscript(text: "late", segments: []), forLocalId: item.localId)
        XCTAssertNil(c.pending().first?.transcript)
    }

    func testThePollStopsAfterFifteenTriesAndTheItemLeavesTheQueue() async throws {
        let api = FakeVideoAPI(readyAfterPolls: 99)
        let c = makeController(api: api)
        _ = try c.enqueue(exported(), attach: nil)
        await drain(c)
        XCTAssertEqual(api.polls, 15)
        XCTAssertTrue(c.pending().isEmpty)
    }

    func testRetryAfterLostCreate() async throws {
        let api = FakeVideoAPI(dropFirstCreateResponse: true)
        let c = makeController(api: api)
        let item = try c.enqueue(exported(), attach: nil)
        await drain(c)
        XCTAssertEqual(api.createCalls, 2)
        XCTAssertEqual(api.created.map(\.uid), ["uid-1", "uid-1"])
        XCTAssertEqual(c.serverId(forLocalId: item.localId), api.createdId)
    }

    // MARK: - The banner (D12)

    func testBannerAfterThreeFailures() async throws {
        let banner = BannerSpy()
        let c = makeController(api: FakeVideoAPI(failUploads: 4), banner: banner)
        _ = try c.enqueue(exported(), attach: nil)
        for _ in 0..<3 { _ = await c.processNext() }
        XCTAssertEqual(banner.shown.count, 1)
        XCTAssertEqual(banner.shown.first?.hasRetry, true)
        XCTAssertEqual(VideoUploadController.delay(forAttempt: 1), .seconds(5))
        XCTAssertEqual(VideoUploadController.delay(forAttempt: 2), .seconds(30))
        XCTAssertEqual(VideoUploadController.delay(forAttempt: 3), .seconds(120))
        XCTAssertEqual(VideoUploadController.delay(forAttempt: 4), .seconds(600))
        XCTAssertEqual(VideoUploadController.delay(forAttempt: 9), .seconds(600))
    }

    func testAFourthFailureDoesNotShowTheBannerAgain() async throws {
        let banner = BannerSpy()
        let c = makeController(api: FakeVideoAPI(failUploads: 4), banner: banner)
        _ = try c.enqueue(exported(), attach: nil)
        for _ in 0..<4 { _ = await c.processNext() }
        XCTAssertEqual(banner.shown.count, 1)
        XCTAssertEqual(c.pending().first?.failures, 4)
    }

    // MARK: - Attach jobs (D18)

    func testAttachSurvivesRelaunch() async throws {
        let api = FakeVideoAPI()
        let first = makeController(api: api, root: dir)
        _ = try first.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 1"))
        _ = await first.processNext()
        let second = makeController(api: api, root: dir)
        await drain(second)
        XCTAssertEqual(api.activityCreates.first?.versionId, "ver1")
        XCTAssertEqual(api.activityCreates.first?.videoId, api.createdId)
        XCTAssertTrue(second.pending().isEmpty)
    }

    func testAReplaceAttachSavesTheExistingActivity() async throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        _ = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: "act9", title: "Video 1"))
        await drain(c)
        XCTAssertTrue(api.activityCreates.isEmpty)
        XCTAssertEqual(api.activityReplaces.first?.activityId, "act9")
        XCTAssertEqual(api.activityReplaces.first?.videoId, api.createdId)
    }

    func testARefusedAttachKeepsTheVideoAndSurfacesTheError() async throws {
        let banner = BannerSpy()
        let api = FakeVideoAPI(attachErrors: [ActivityActionsError.notDraft])
        let c = makeController(api: api, banner: banner)
        let item = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 1"))
        await drain(c)
        XCTAssertEqual(banner.shown.count, 1)
        XCTAssertEqual(banner.shown.first?.hasRetry, false)
        XCTAssertTrue(c.pending().isEmpty)
        XCTAssertEqual(c.serverId(forLocalId: item.localId), api.createdId)
    }

    func testEveryPermanentRefusalKeepsTheVideoAndStopsRetrying() async throws {
        let refusals: [(String, Error)] = [
            ("403", APIHTTPError(status: 403, message: nil)),
            ("404", APIHTTPError(status: 404, message: nil, details: ["code": "NOT_FOUND"])),
            ("validation", APIHTTPError(status: 400, message: nil, details: ["code": "VALIDATION"])),
            ("not-draft", ActivityActionsError.notDraft),
            ("gone", ActivityActionsError.gone)
        ]
        for (name, error) in refusals {
            let banner = BannerSpy()
            let api = FakeVideoAPI(attachErrors: [error])
            let c = makeController(api: api, banner: banner, root: root.appendingPathComponent("q-\(name)"))
            _ = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "V"))
            await drain(c)
            XCTAssertEqual(banner.shown.map(\.hasRetry), [false], name)
            XCTAssertTrue(api.activityCreates.isEmpty, name)
            XCTAssertTrue(c.pending().isEmpty, name)
        }
    }

    /// 409 `CONFLICT` is two writes meeting on one version; the retry reloads it.
    func testAConflictRetriesTheAttach() async throws {
        let banner = BannerSpy()
        let api = FakeVideoAPI(attachErrors: [APIHTTPError(status: 409, message: nil, details: ["code": "CONFLICT"])])
        let c = makeController(api: api, banner: banner)
        _ = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "V"))
        await drain(c)
        XCTAssertTrue(banner.shown.isEmpty)
        XCTAssertEqual(api.activityCreates.count, 1)
        XCTAssertTrue(c.pending().isEmpty)
    }

    // MARK: - Cancellations and the end of a flush

    func testACancellationThatIsNotARemovalBacksOff() async throws {
        let api = FakeVideoAPI(failUploads: 1)
        api.uploadError = CancellationError()
        let c = makeController(api: api)
        _ = try c.enqueue(exported(), attach: nil)
        let step = await c.processNext()
        XCTAssertEqual(step, .retryLater)
        XCTAssertEqual(c.pending().first?.failures, 1)
        XCTAssertNotNil(c.pending().first?.nextAttemptAt)
    }

    func testAnItemRemovedWhileItsUploadFailsIsSilent() async throws {
        let banner = BannerSpy()
        let api = FakeVideoAPI(failUploads: 3)
        let c = makeController(api: api, banner: banner)
        let item = try c.enqueue(exported(), attach: nil)
        api.onUpload = { number in
            guard number == 3 else { return }
            try c.remove(localId: item.localId)
        }
        for _ in 0..<3 { _ = await c.processNext() }
        XCTAssertTrue(banner.shown.isEmpty)
        XCTAssertTrue(c.pending().isEmpty)
    }

    /// Queued between a flush ending and its first caller resuming: that flush cannot run it.
    func testAVideoQueuedAsAFlushEndsStillUploads() async throws {
        let api = FakeVideoAPI(readyAfterPolls: 0)
        var late: Task<Void, Error>?
        var controller: VideoUploadController?
        let c = VideoUploadController(api: api, transport: api, banner: BannerSpy(), directory: dir, ownerUserId: "user-a",
                                      environment: "Local", defaultTitle: { "Video 1" }, now: { [self] in
            // The flush's last look at the queue.
            if late == nil, !api.created.isEmpty, let controller, controller.pendingItems.isEmpty {
                late = Task {
                    _ = try controller.enqueue(exported(), attach: nil)
                    await controller.flush()
                }
            }
            return Date()
        })
        controller = c
        _ = try c.enqueue(exported(), attach: nil)
        await c.flush()
        try await XCTUnwrap(late).value
        XCTAssertEqual(api.created.count, 2)
        XCTAssertTrue(c.pending().isEmpty)
    }

    // MARK: - Titles (D14)

    func testNextVideoTitleCountsQueuedItems() throws {
        let state = AppState()
        let c = VideoUploadController(api: FakeVideoAPI(), transport: FakeVideoAPI(), banner: BannerSpy(), directory: dir,
                                      ownerUserId: "user-a", environment: "Local", defaultTitle: { "Video 3" })
        state.videoUploads = c
        XCTAssertEqual(state.nextVideoTitle(), "Video 1")
        _ = try c.enqueue(exported(), attach: nil)
        XCTAssertEqual(c.pending().first?.title, "Video 3")
        XCTAssertEqual(state.nextVideoTitle(), "Video 4")
    }

    // MARK: - Body limits (D24)

    func testTranscriptFitsTheLimitsInsteadOfFailing() {
        let long = String(repeating: "a", count: 2_500)
        let segments = (0..<2_100).map { VideoTranscriptSegment(text: "w", startMs: $0, endMs: $0 + 1) }
            + [VideoTranscriptSegment(text: long, startMs: 0, endMs: 3_000)]
        let fit = VideoTranscriptLimits.fit(VideoTranscript(text: String(repeating: "b", count: 25_000), segments: segments))
        XCTAssertEqual(fit.text.utf16.count, 20_000)
        XCTAssertEqual(fit.segments.count, 2_000)
        XCTAssertTrue(fit.segments.allSatisfy { $0.text.utf16.count <= 1_000 && 0 <= $0.startMs && $0.startMs <= $0.endMs })

        let split = VideoTranscriptLimits.fit(VideoTranscript(text: long, segments: [VideoTranscriptSegment(text: long, startMs: 0, endMs: 3_000)]))
        XCTAssertEqual(split.segments.map(\.text.utf16.count), [1_000, 1_000, 500])
        XCTAssertEqual(split.segments.map(\.startMs), [0, 1_200, 2_400])
        XCTAssertEqual(split.segments.last?.endMs, 3_000)
        XCTAssertEqual(split.segments.map(\.text).joined(), long)
    }

    // MARK: - Live seams: replace job, create body, activity document

    private func liveAPI(_ stub: StubAPIClient, state: AppState) -> LiveVideoUploadAPI {
        LiveVideoUploadAPI(videos: VideoActions(api: stub, state: state),
                           activities: ActivityActions(api: stub, state: state), state: state)
    }

    private static let versionJSON = #"{"id":"ver1","lessonId":"l1","enrollmentId":null,"number":1,"status":"DRAFT","title":"Day one","estimatedSeconds":null,"publishedAt":null}"#
    private static let textDocument = ##"{"schemaVersion":1,"kind":"video","background":{"color":"#000000"},"content":{"type":"video","videoId":"old"},"actions":[]}"##
    private static let activityJSON = #"{"id":"act9","lessonVersionId":"ver1","activityKey":"k","position":0,"kind":"video","title":"Video","document":\#(textDocument),"estimatedSeconds":null}"#

    func testAReplaceJobWithAColdCacheFetchesTheVersionAndSavesTheNewVideoId() async throws {
        let stub = StubAPIClient()
        let state = AppState()
        stub.stub("GET", "/api/lesson-versions/ver1", json: #"{"version":\#(Self.versionJSON),"activities":[\#(Self.activityJSON)],"media":{}}"#)
        stub.stub("PUT", "/api/content-activities/act9", json: #"{"activity":\#(Self.activityJSON),"media":{}}"#)
        XCTAssertNil(state.activities["act9"])
        try await liveAPI(stub, state: state).attach(VideoAttach(versionId: "ver1", activityId: "act9", title: "V"), videoId: "vid-1")
        let put = try XCTUnwrap(stub.recordedStatusCalls.first { $0.method == "PUT" })
        let document = try XCTUnwrap(put.body?["document"] as? [String: Any])
        let content = try XCTUnwrap(document["content"] as? [String: Any])
        XCTAssertEqual(content["videoId"] as? String, "vid-1")
        XCTAssertEqual(content["type"] as? String, "video")
    }

    private func videoActivityJSON(videoId: String) -> String {
        Self.activityJSON.replacingOccurrences(of: #""videoId":"old""#, with: #""videoId":"\#(videoId)""#)
    }

    private func stubVersion(_ stub: StubAPIClient, activity: String) {
        stub.stub("GET", "/api/lesson-versions/ver1", json: #"{"version":\#(Self.versionJSON),"activities":[\#(activity)],"media":{}}"#)
        stub.stub("POST", "/api/lesson-versions/ver1/activities", json: #"{"activity":\#(Self.activityJSON),"media":{}}"#)
    }

    /// The create's response was lost, or the app was killed before it was recorded.
    func testACreateJobWhoseActivityAlreadyExistsDoesNotMakeASecond() async throws {
        let stub = StubAPIClient()
        stubVersion(stub, activity: videoActivityJSON(videoId: "vid-1"))
        try await liveAPI(stub, state: AppState()).attach(VideoAttach(versionId: "ver1", activityId: nil, title: "V"), videoId: "vid-1")
        XCTAssertTrue(stub.recordedCalls(method: "POST").isEmpty)
    }

    func testACreateJobMakesItsActivityBesideOtherVideos() async throws {
        let stub = StubAPIClient()
        stubVersion(stub, activity: videoActivityJSON(videoId: "other"))
        try await liveAPI(stub, state: AppState()).attach(VideoAttach(versionId: "ver1", activityId: nil, title: "V"), videoId: "vid-1")
        XCTAssertEqual(stub.callCount("POST", "/api/lesson-versions/ver1/activities"), 1)
    }

    func testAReplaceJobWhoseVersionIsGone404IsARefusalNotAnOutage() async throws {
        let stub = StubAPIClient()
        stub.errorFor = { endpoint, _ in endpoint == "/api/lesson-versions/ver1" ? APIHTTPError(status: 404, message: nil) : nil }
        do {
            try await liveAPI(stub, state: AppState()).attach(VideoAttach(versionId: "ver1", activityId: "act9", title: "V"), videoId: "vid-1")
            XCTFail("expected a throw")
        } catch let error as APIHTTPError {
            XCTAssertEqual(error.status, 404)
        }
    }

    func testTheCreateBodyCarriesTheSourceTheTranscriptAndTheSegments() async throws {
        let stub = StubAPIClient()
        let state = AppState()
        stub.stub("POST", "/api/videos", json: #"{"success":true,"data":{"id":"vid-1","title":"T","cloudflareUid":"uid-1","playbackUrl":"x","status":"pending","userId":"u","createdAt":"2026-11-22T10:00:00.000Z","updatedAt":"2026-11-22T10:00:00.000Z"}}"#)
        let transcript = VideoTranscript(text: "hello there", segments: [VideoTranscriptSegment(text: "hello there", startMs: 0, endMs: 900)])
        let id = try await liveAPI(stub, state: state).createVideo(
            VideoCreateRequest(uid: "uid-1", title: "T", source: .imported, transcript: transcript))
        XCTAssertEqual(id, "vid-1")
        let body = try XCTUnwrap(stub.recordedCalls(method: "POST").first { $0.endpoint == "/api/videos" }?.body)
        XCTAssertEqual(body["cloudflareUid"] as? String, "uid-1")
        XCTAssertEqual(body["title"] as? String, "T")
        XCTAssertEqual(body["source"] as? String, "import")
        XCTAssertEqual(body["transcript"] as? String, "hello there")
        let segments = try XCTUnwrap(body["transcriptSegments"] as? [[String: Any]])
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0]["text"] as? String, "hello there")
        XCTAssertEqual(segments[0]["startMs"] as? Int, 0)
        XCTAssertEqual(segments[0]["endMs"] as? Int, 900)
    }

    func testACreateWithoutATranscriptSendsNeitherTranscriptKey() async throws {
        let stub = StubAPIClient()
        stub.stub("POST", "/api/videos", json: #"{"success":true,"data":{"id":"vid-1","cloudflareUid":"uid-1","playbackUrl":"x","status":"pending","userId":"u","createdAt":"2026-11-22T10:00:00.000Z","updatedAt":"2026-11-22T10:00:00.000Z"}}"#)
        _ = try await liveAPI(stub, state: AppState()).createVideo(
            VideoCreateRequest(uid: "uid-1", title: "T", source: .recording, transcript: nil))
        let body = try XCTUnwrap(stub.recordedCalls(method: "POST").first?.body)
        XCTAssertEqual(body["source"] as? String, "recording")
        XCTAssertNil(body["transcript"])
        XCTAssertNil(body["transcriptSegments"])
    }

    /// Pins the document against server/src/services/activity-document.ts: the `envelope` zod object
    /// (schemaVersion 1; kind in ACTIVITY_KINDS and equal to the route's kind; background.color a
    /// `#RRGGBB` hex; actions optional with at most one pinned; chrome.topAction share|menu|none;
    /// fallback {title, body} strings) and `CONTENT_BY_KIND.video` (type "video", videoId string).
    /// `estimatedSeconds` is not a document field: the server fills it at save, null for video
    /// (`estimateDocumentSeconds`), so the client must not send one.
    func testTheCreatedVideoDocumentSatisfiesTheServersVideoSchema() throws {
        let document = LiveVideoUploadAPI.videoDocument(videoId: "vid-1", title: "Video 1")
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        XCTAssertEqual(Set(raw.keys), ["schemaVersion", "kind", "background", "content", "actions", "chrome", "fallback"])
        XCTAssertEqual(raw["schemaVersion"] as? Int, 1)
        XCTAssertEqual(raw["kind"] as? String, "video")
        let color = try XCTUnwrap((raw["background"] as? [String: Any])?["color"] as? String)
        XCTAssertNotNil(color.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression))
        let content = try XCTUnwrap(raw["content"] as? [String: Any])
        XCTAssertEqual(content["type"] as? String, "video")
        XCTAssertEqual(content["videoId"] as? String, "vid-1")
        XCTAssertEqual(Set(content.keys), ["type", "videoId"])
        XCTAssertEqual((raw["actions"] as? [Any])?.count, 0)
        XCTAssertTrue(["share", "menu", "none"].contains((raw["chrome"] as? [String: Any])?["topAction"] as? String ?? ""))
        let fallback = try XCTUnwrap(raw["fallback"] as? [String: Any])
        XCTAssertEqual(fallback["title"] as? String, "Video 1")
        XCTAssertTrue(fallback["body"] is String)
        XCTAssertNil(raw["estimatedSeconds"])
    }

    // MARK: - Damaged manifest, banner copy

    func testAnItemPastCreatingWithNoServerIdStepsBackInsteadOfSpinning() async throws {
        let api = FakeVideoAPI()
        let c = makeController(api: api)
        let item = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "V"))
        _ = await c.processNext()
        _ = await c.processNext()
        let manifest = dir.appendingPathComponent("\(item.localId).json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        json["stage"] = "creating"
        json.removeValue(forKey: "serverId")
        try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        let before = api.createCalls
        let step = await c.processNext()
        XCTAssertEqual(step, .advanced)
        XCTAssertEqual(c.pending().first?.stage, .uploading)
        await drain(c)
        XCTAssertEqual(api.createCalls, before + 1)
        XCTAssertEqual(api.activityCreates.count, 1)
        XCTAssertTrue(c.pending().isEmpty)
    }

    func testTheBannerNamesTheLessonOnlyForAnAttachJob() async throws {
        for (attach, expected) in [(VideoAttach(versionId: "v", activityId: nil, title: "V") as VideoAttach?, "Couldn't add your video to the lesson"),
                                   (nil, "Couldn't upload your video")] {
            let banner = BannerSpy()
            let c = makeController(api: FakeVideoAPI(failUploads: 3), banner: banner,
                                   root: root.appendingPathComponent("q-\(expected.count)"))
            _ = try c.enqueue(exported(), attach: attach)
            for _ in 0..<3 { _ = await c.processNext() }
            XCTAssertEqual(banner.shown.first?.message, expected)
        }
    }
}
