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
    private let attachStatus: Int?

    private(set) var mints = 0
    private(set) var uploads: [(url: URL, fileURL: URL)] = []
    private(set) var createCalls = 0
    private(set) var created: [VideoCreateRequest] = []
    private(set) var polls = 0
    private(set) var activityCreates: [ActivityCreate] = []
    private(set) var activityReplaces: [(activityId: String, videoId: String)] = []

    init(readyAfterPolls: Int = 1, dropFirstCreateResponse: Bool = false, failUploads: Int = 0, attachStatus: Int? = nil) {
        self.readyAfterPolls = readyAfterPolls
        self.dropFirstCreateResponse = dropFirstCreateResponse
        self.failUploads = failUploads
        self.attachStatus = attachStatus
    }

    func mintUploadURL(title: String) async throws -> VideoUploadTicket {
        mints += 1
        return VideoUploadTicket(uploadUrl: "https://stream.test/upload/\(mints)", uid: "uid-\(mints)")
    }

    func upload(fileURL: URL, to url: URL) async throws -> Int {
        uploads.append((url, fileURL))
        if uploads.count <= failUploads { throw URLError(.networkConnectionLost) }
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
        if let attachStatus { throw APIHTTPError(status: attachStatus, message: nil) }
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
        let api = FakeVideoAPI(attachStatus: 409)
        let c = makeController(api: api, banner: banner)
        let item = try c.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 1"))
        await drain(c)
        XCTAssertEqual(banner.shown.count, 1)
        XCTAssertEqual(banner.shown.first?.hasRetry, false)
        XCTAssertTrue(c.pending().isEmpty)
        XCTAssertEqual(c.serverId(forLocalId: item.localId), api.createdId)
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
}
