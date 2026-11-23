//
//  VideoDetailModelTests.swift
//  MakeReadyCaptureTests
//
//  video-recorder D14, D16, D17: `VideoDetailModel` over a private AppState, a StubAPIClient and a spy player.
//

import XCTest
@testable import MakeReady

@MainActor
private final class SpyVideoPlayer: VideoPlaying {
    var elapsed: Double = 0
    var isPlaying = false
    var isReady = false
    var layer: CALayer? { nil }
    private(set) var loaded: [(url: URL, duration: Double)] = []
    private(set) var seeks: [Double] = []
    private(set) var plays = 0
    private(set) var stops = 0

    func load(url: URL, duration: Double) { loaded.append((url, duration)) }
    func play() { plays += 1; isPlaying = true }
    func pause() { isPlaying = false }
    func seek(to seconds: Double) { seeks.append(seconds) }
    func skip(by seconds: Double) { seek(to: elapsed + seconds) }
    func stop() { stops += 1; isPlaying = false }
}

@MainActor
final class VideoDetailModelTests: XCTestCase {

    private var state: AppState!
    private var api: StubAPIClient!
    private var player: SpyVideoPlayer!
    private var model: VideoDetailModel!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        player = SpyVideoPlayer()
        model = VideoDetailModel(id: "v1", actions: VideoActions(api: api, state: state), player: player, state: state)
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    // MARK: - Fixtures

    private func videoJSON(id: String = "v1", title: String = "Video 1", status: String = "ready",
                           transcriptStatus: String = "ready", transcript: String? = nil,
                           segments: String? = nil, lessonUseCount: Int = 0) -> String {
        let text = transcript.map { #""\#($0)""# } ?? "null"
        let segs = segments ?? "null"
        return #"{"id":"\#(id)","title":"\#(title)","cloudflareUid":"u\#(id)","playbackUrl":"https://x/\#(id).m3u8","thumbnailUrl":"https://x/\#(id).jpg","duration":45,"status":"\#(status)","userId":"me","createdAt":"2026-11-20T10:30:00.000Z","updatedAt":"2026-11-20T10:30:00.000Z","transcriptStatus":"\#(transcriptStatus)","transcript":\#(text),"transcriptSegments":\#(segs),"lessonUseCount":\#(lessonUseCount)}"#
    }

    private func video(transcriptStatus: String = "ready", status: String = "ready", transcript: String? = nil,
                       segments: String? = nil) -> Video {
        try! JSONDecoder.apiDecoder.decode(Video.self, from: Data(videoJSON(
            status: status, transcriptStatus: transcriptStatus, transcript: transcript, segments: segments).utf8))
    }

    private func seed(lessonUseCount: Int = 0, segments: String? = nil) {
        state.videos.upsert(try! JSONDecoder.apiDecoder.decode(Video.self, from: Data(videoJSON(
            transcript: "Hi", segments: segments, lessonUseCount: lessonUseCount).utf8)))
    }

    private func patches() -> [StubAPIClient.RecordedCall] { api.recordedCalls(method: "PATCH") }

    // MARK: - Transcript (D16)

    func testTranscriptState() {
        XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "ready", transcript: "Hi")), "Hi")
        XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "pending", status: "ready")), "Transcribing…")
        XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "pending", status: "pending")), "Processing…")
        XCTAssertNil(VideoDetailModel.transcriptText(video(transcriptStatus: "failed")))
        XCTAssertNil(VideoDetailModel.transcriptText(video(transcriptStatus: "none")))
    }

    func testTheScreenReadsSegmentsOrTheWholeTranscript() {
        seed(segments: #"[{"text":"One","startMs":0,"endMs":4000},{"text":"Two","startMs":16500,"endMs":20000}]"#)
        var screen = model.screenState(now: Date(), calendar: .current)
        XCTAssertEqual(screen.transcript, .paragraphs)
        XCTAssertEqual(screen.paragraphStarts, [0, 16])
        XCTAssertEqual(screen.paragraphTexts, ["One", "Two"])
        XCTAssertEqual(screen.duration, 45)

        seed()
        screen = model.screenState(now: Date(), calendar: .current)
        XCTAssertEqual(screen.paragraphTexts, ["Hi"])
    }

    func testAPendingVideoIsProcessing() {
        let pending = video(transcriptStatus: "pending", status: "pending")
        let screen = VideoDetailModel.screenState(video: pending, elapsed: 0, playing: false, playerReady: false,
                                                  now: Date(), calendar: .current)
        XCTAssertEqual(screen.status, .processing)
        XCTAssertEqual(screen.transcript, .transcribing)
    }

    // MARK: - Rename (D14)

    func testAnEmptyRenameIsNotSent() async {
        seed()
        await model.rename(to: "   ")
        XCTAssertTrue(patches().isEmpty)
    }

    func testARenameIsTrimmedAndSent() async {
        seed()
        api.stub("PATCH", "/api/videos/v1", json: #"{"success":true,"data":\#(videoJSON(title: "Grace"))}"#)
        await model.rename(to: "  Grace \n")
        XCTAssertEqual(patches().count, 1)
        XCTAssertEqual(patches().first?.body?["title"] as? String, "Grace")
        XCTAssertEqual(model.screenState(now: Date(), calendar: .current).title, "Grace")
    }

    // MARK: - Delete (D17)

    func testAnUnusedVideoIsDeletedAndThePageGoesBack() async {
        seed(lessonUseCount: 0)
        api.stub("DELETE", "/api/videos/v1", json: #"{"success":true}"#)
        let pop = await model.requestDelete()
        XCTAssertTrue(pop)
        XCTAssertEqual(api.callCount("DELETE", "/api/videos/v1"), 1)
        XCTAssertEqual(player.stops, 1)
    }

    func testAVideoInLessonsLeavesTheLibraryInstead() async {
        seed(lessonUseCount: 2)
        api.stub("POST", "/api/videos/v1/remove-from-library",
                 json: #"{"success":true,"data":{"id":"v1","libraryRemovedAt":"2026-11-22T00:00:00Z"}}"#)
        let pop = await model.requestDelete()
        XCTAssertTrue(pop)
        XCTAssertEqual(api.callCount("POST", "/api/videos/v1/remove-from-library"), 1)
        XCTAssertEqual(api.callCount("DELETE", "/api/videos/v1"), 0)
    }

    func testAFailedDeleteStaysOnThePage() async {
        seed()
        api.errorToThrow = APIError.serverError("boom")
        let pop = await model.requestDelete()
        XCTAssertFalse(pop)
        XCTAssertEqual(player.stops, 0)
        XCTAssertNotNil(state.videos["v1"])
    }

    // MARK: - Playback (D16)

    func testLoadHandsTheStreamToThePlayerOnce() async {
        api.stub("GET", "/api/videos/v1", json: #"{"success":true,"data":\#(videoJSON())}"#)
        await model.load()
        await model.load()
        XCTAssertEqual(player.loaded.map(\.url.absoluteString), ["https://x/v1.m3u8"])
        XCTAssertEqual(player.loaded.first?.duration, 45)
    }

    func testAProcessingVideoIsNotLoadedIntoThePlayer() async {
        api.stub("GET", "/api/videos/v1", json: #"{"success":true,"data":\#(videoJSON(status: "pending"))}"#)
        await model.load()
        XCTAssertTrue(player.loaded.isEmpty)
    }

    func testAParagraphSeeksAndPlays() {
        seed(segments: #"[{"text":"One","startMs":0,"endMs":4000},{"text":"Two","startMs":16500,"endMs":20000}]"#)
        model.seekParagraph(1)
        XCTAssertEqual(player.seeks, [16])
        XCTAssertEqual(player.plays, 1)
        model.seekParagraph(5)
        XCTAssertEqual(player.seeks, [16])
    }

    func testStopStopsThePlayer() {
        model.stop()
        XCTAssertEqual(player.stops, 1)
    }

    // MARK: - Opening from the Library (D15, D16)

    func testAStoredRowOpensAndAQueuedRowDoesNot() {
        XCTAssertEqual(LibraryHomeContainer.destination(forVideoId: "v1"), .videoDetail(id: "v1"))
        XCTAssertNil(LibraryHomeContainer.destination(forVideoId: "local:q1"))
    }
}
