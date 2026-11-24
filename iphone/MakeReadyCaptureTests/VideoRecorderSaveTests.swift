//
//  VideoRecorderSaveTests.swift
//  MakeReadyCaptureTests
//
//  video-recorder D8, D9, D10, D14: Review, import, trim and Save — the model over the real capture
//  engine, draft store and saver, with the camera, the export, the transcript and the queue doubled.
//

import AVFoundation
import XCTest
@testable import MakeReady

@MainActor
final class QueueSpy: VideoSaveQueue {
    struct Item {
        let localId: String
        let title: String
        let source: String
        let attach: VideoAttach?
        let transcript: VideoTranscript?
        let holdsForTranscript: TimeInterval?
        let hasPoster: Bool
    }

    var error: Error?
    /// What the queue already holds, as after a kill between its taking the video and the draft going.
    var alreadyHolds: VideoQueueItem?
    private(set) var items: [Item] = []
    private(set) var supplied: [VideoTranscript?] = []

    func enqueue(_ video: ExportedVideo, localId: String, title: String, source: VideoSource, transcript: VideoTranscript?,
                 attach: VideoAttach?, transcriptHold: TimeInterval?) throws -> VideoQueueItem {
        if let error { throw error }
        items.append(Item(localId: localId, title: title, source: source.rawValue, attach: attach, transcript: transcript,
                          holdsForTranscript: transcriptHold, hasPoster: video.posterImage != nil))
        return VideoQueueItem(
            localId: localId, fileName: "\(localId).mp4", posterFileName: nil, title: title,
            durationSeconds: video.durationSeconds, source: source, transcript: transcript, createdAt: Date(), streamUid: nil,
            serverId: nil, stage: .queued, failures: 0, polls: 0, nextAttemptAt: nil, attach: attach,
            ownerUserId: "u", environment: "test")
    }

    func queued(localId: String) -> VideoQueueItem? { alreadyHolds?.localId == localId ? alreadyHolds : nil }

    func supplyTranscript(_ transcript: VideoTranscript?, forLocalId localId: String) {
        supplied.append(transcript)
    }
}

@MainActor
final class ReviewPlayerSpy: VideoReviewPlaying {
    let layer = CALayer()
    private(set) var loads: [(clips: [URL], window: ClosedRange<Double>?)] = []
    private(set) var looks: [VideoLook] = []
    private(set) var stops = 0

    func load(clips: [URL], window: ClosedRange<Double>?, look: VideoLook) async throws {
        loads.append((clips, window))
        looks.append(look)
    }

    func show(_ look: VideoLook) { looks.append(look) }
    func move(to window: ClosedRange<Double>) { }
    func play() {}
    func stop() { stops += 1 }
}

/// What an export was asked for, and what it answers. `gate` holds it until released.
@MainActor
private final class ExportSpy {
    struct Call: Equatable { let clips: [URL]; let window: ClosedRange<Double>?; let filter: VideoFilter; let strength: Double; let layers: [VideoLayer] }
    private(set) var calls: [Call] = []
    var failures = 0
    var holds = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func export(_ clips: [URL], _ window: ClosedRange<Double>?, _ filter: VideoFilter, _ strength: Double,
                _ layers: [VideoLayer], _ destination: URL) async throws -> ExportedVideo {
        calls.append(Call(clips: clips, window: window, filter: filter, strength: strength, layers: layers))
        if holds { await withCheckedContinuation { waiting.append($0) } }
        if failures > 0 {
            failures -= 1
            throw VideoExportError.sessionUnavailable
        }
        return ExportedVideo(url: destination, durationSeconds: 4, posterImage: UIImage())
    }

    func release() {
        holds = false
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

@MainActor
final class VideoRecorderSaveTests: XCTestCase {
    private var dir: URL!
    private var drafts: VideoDraftStore!
    private var session: FakeCaptureSession!
    private var player: ReviewPlayerSpy!
    private var exporter: ExportSpy!
    private var reports: [String] = []
    private var retries: [() -> Void] = []
    private var transcript: VideoTranscript?
    private var transcriptTimeouts: [Duration] = []
    private var interruptions = 0
    private var suiteName: String!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoRecorderSaveTests-\(UUID().uuidString)")
        drafts = VideoDraftStore(root: dir.appendingPathComponent("drafts"))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        session = FakeCaptureSession()
        player = ReviewPlayerSpy()
        exporter = ExportSpy()
        reports = []
        retries = []
        transcript = nil
        transcriptTimeouts = []
        interruptions = 0
        suiteName = "VideoRecorderSaveTests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        exporter.release()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try FileManager.default.removeItem(at: dir)
    }

    private var tmpURL: URL {
        let url = dir.appendingPathComponent("\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: url.path, contents: Data([1]))
        return url
    }

    private func makeSaver(queue: QueueSpy, existingTitles: [String] = [],
                           savingTitles: @escaping () -> [String] = { [] }) -> VideoSaver {
        let exporter = exporter!
        return VideoSaver(
            drafts: drafts, queue: queue,
            nextTitle: { MemoActions.nextDefaultTitle(prefix: "Video", existingTitles: existingTitles + queue.items.map(\.title) + savingTitles()) },
            report: { [weak self] _, message, retry in
                self?.reports.append(message)
                self?.retries.append(retry)
            },
            export: { try await exporter.export($0, $1, $2, $3, $4, $5) },
            transcribe: { [weak self] _, timeout in
                self?.transcriptTimeouts.append(timeout)
                return self?.transcript
            },
            waitForForeground: { [weak self] in
                guard let self, self.interruptions > 0 else { return false }
                self.interruptions -= 1
                return true
            })
    }

    private func makeModel(entry: VideoRecorderEntry = .plusMenu, queue: QueueSpy? = nil, existingTitles: [String] = [],
                           saver: VideoSaver? = nil) -> VideoRecorderModel {
        VideoRecorderModel(
            entry: entry,
            engine: VideoCaptureEngine(session: session, drafts: drafts, freeBytes: { nil }, notificationCenter: NotificationCenter()),
            settings: RecorderSettings(defaults: UserDefaults(suiteName: suiteName)!),
            player: player, saver: saver ?? makeSaver(queue: queue ?? QueueSpy(), existingTitles: existingTitles),
            recoverDraft: { [drafts] in drafts!.recoverable().last }, beep: { _ in },
            report: { [weak self] _, message in self?.reports.append(message) }, loadNotes: {}, now: { 0 })
    }

    private func record(_ m: VideoRecorderModel, seconds: TimeInterval = 4) {
        m.recordTapped(); m.tick(recorded: seconds); m.recordTapped()
    }

    // MARK: a clip over 2:00 opens trim; one at or under goes to Review (D8)

    func testImportRouting() {
        let m = makeModel()
        m.imported(url: tmpURL, duration: 120); XCTAssertEqual(m.screenState.phase, .review)
        let n = makeModel()
        n.imported(url: tmpURL, duration: 180); XCTAssertEqual(n.screenState.phase, .trim)
        n.trimmed(range: 30...150); XCTAssertEqual(n.screenState.phase, .review)
    }

    func testTheGalleryButtonShowsOnlyBeforeTheFirstSegment() {
        let m = makeModel()
        XCTAssertTrue(m.screenState.canImport)
        m.recordTapped(); m.tick(recorded: 3)
        XCTAssertFalse(m.screenState.canImport)
        m.recordTapped()
        XCTAssertFalse(m.screenState.canImport)
    }

    func testAnImportThatLandsAfterRecordingBeganIsDropped() {
        let m = makeModel()
        record(m)
        let url = tmpURL
        m.imported(url: url, duration: 10)
        XCTAssertEqual(m.screenState.phase, .paused)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testTheTrimWindowIsAtMostTwoMinutes() {
        let m = makeModel()
        m.imported(url: tmpURL, duration: 300)
        XCTAssertEqual(m.trimWindow, 0...120)
        m.moveTrim(to: 100...290)
        XCTAssertEqual(m.trimWindow, 100...220)
        m.moveTrim(to: 250...400)
        XCTAssertEqual(m.trimWindow, 250...300)
    }

    func testTheTrimHandlesKeepTheWindowInsideTheClipAndTheLimit() {
        let window = 30.0...150.0
        XCTAssertEqual(VideoTrim.window(window, dragging: .start, by: -20, duration: 300), window)
        XCTAssertEqual(VideoTrim.window(window, dragging: .start, by: 20, duration: 300), 50...150)
        XCTAssertEqual(VideoTrim.window(window, dragging: .start, by: 500, duration: 300), 149...150)
        XCTAssertEqual(VideoTrim.window(window, dragging: .end, by: 20, duration: 300), window)
        XCTAssertEqual(VideoTrim.window(window, dragging: .end, by: -20, duration: 300), 30...130)
        XCTAssertEqual(VideoTrim.window(window, dragging: .whole, by: 500, duration: 300), 180...300)
        XCTAssertEqual(VideoTrim.window(window, dragging: .whole, by: -500, duration: 300), 0...120)
    }

    func testCancellingTheTrimReturnsToTheCamera() async {
        let m = makeModel()
        let url = tmpURL
        m.imported(url: url, duration: 180)
        m.trimCancelled()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        await m.settled()
        XCTAssertTrue(session.isOpen)
    }

    func testAPickThatCannotBeReadIsReported() async {
        let m = makeModel()
        await m.importPicked { throw VideoExportError.nothingToExport }
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertEqual(reports, ["Couldn't read that video"])
        XCTAssertFalse(m.isImporting)
    }

    func testImportReadsAMoviesOwnDuration() async throws {
        let url = try await TestMovie.make(seconds: 2, colour: .red, size: CGSize(width: 360, height: 640))
        let clip = try await VideoImportFlow.clip(at: url)
        XCTAssertEqual(clip.duration, 2, accuracy: 0.1)
        let text = tmpURL
        do {
            _ = try await VideoImportFlow.clip(at: text)
            XCTFail("not a video")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: text.path))
        }
    }

    // MARK: Review (D9)

    func testReviewLoopsTheResultWithTheLiveFilterAndTurnsTheCameraOff() async {
        let m = makeModel()
        m.open()
        m.pickFilter(.mono)
        record(m)
        m.done()
        await m.settled()
        await m.playerSettled()
        XCTAssertFalse(session.isOpen)
        XCTAssertEqual(player.loads.count, 1)
        XCTAssertEqual(player.loads.first?.clips.count, 1)
        XCTAssertEqual(player.looks.last, VideoLook(filter: .mono, strength: 1))
        m.setFilterStrength(40)
        XCTAssertEqual(player.looks.last, VideoLook(filter: .mono, strength: 0.4))
    }

    func testReviewOfATrimmedClipPlaysItsWindow() async {
        let m = makeModel()
        m.imported(url: tmpURL, duration: 180)
        m.trimmed(range: 30...150)
        await m.settled()
        await m.playerSettled()
        XCTAssertEqual(player.loads.last?.window, 30...150)
    }

    // MARK: Retake after confirm returns to the camera with no segments (D9)

    func testRetake() async {
        let m = makeModel()
        record(m)
        m.done()
        m.requestRetake()
        XCTAssertEqual(m.confirm, .retake)
        XCTAssertEqual(m.screenState.phase, .review)
        m.retakeConfirmed()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertEqual(m.screenState.segments, [])
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertTrue(drafts.recoverable().isEmpty)
        XCTAssertTrue(session.isOpen)
    }

    func testRetakeOfAnImportDropsIt() async {
        let m = makeModel()
        let url = tmpURL
        m.imported(url: url, duration: 10)
        m.retakeConfirmed()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertTrue(m.screenState.canImport)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testClosingWithAnImportAsksFirst() {
        let m = makeModel()
        m.imported(url: tmpURL, duration: 10)
        m.closeTapped()
        XCTAssertEqual(m.confirm, .discard)
        XCTAssertFalse(m.isClosed)
    }

    // MARK: Save enqueues Video n with source and closes to the Library without waiting (D9, D14)

    func testSaveFromPlus() async {
        let queue = QueueSpy(); var finished: VideoRecorderEntry?
        let m = makeModel(entry: .plusMenu, queue: queue, existingTitles: ["Video 1"])
        m.onFinished = { finished = $0 }
        m.recordTapped(); m.tick(recorded: 4); m.recordTapped()
        await m.save()
        XCTAssertEqual(queue.items.first?.title, "Video 2")
        XCTAssertEqual(queue.items.first?.source, "recording")
        XCTAssertNil(queue.items.first?.attach)
        XCTAssertEqual(finished, .plusMenu)
    }

    func testSaveClosesBeforeTheExportEndsAndNothingRecoversTheDraftMeanwhile() async {
        let queue = QueueSpy()
        exporter.holds = true
        let m = makeModel(queue: queue)
        var finished = 0
        m.onFinished = { _ in finished += 1 }
        record(m)
        let saving = Task { await m.save() }
        for _ in 0..<200 where exporter.calls.isEmpty { await Task.yield() }
        XCTAssertEqual(exporter.calls.count, 1)
        XCTAssertTrue(m.isClosed)
        XCTAssertEqual(finished, 1)
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(drafts.recoverable().isEmpty)
        XCTAssertEqual(drafts.saving().count, 1)
        exporter.release()
        await saving.value
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertTrue(drafts.saving().isEmpty)
    }

    func testSaveTwiceSavesOnce() async {
        let queue = QueueSpy()
        let m = makeModel(queue: queue)
        record(m)
        async let first: Void = m.save()
        async let second: Void = m.save()
        _ = await (first, second)
        XCTAssertEqual(queue.items.count, 1)
    }

    func testSaveWithTheOnlyClipLostStaysOpen() async {
        let queue = QueueSpy()
        session.failure = VideoCaptureError.recordingFailed
        let m = makeModel(queue: queue)
        record(m)
        m.done()
        await m.save()
        XCTAssertFalse(m.isClosed)
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertEqual(reports, ["Couldn't save the clip"])
        XCTAssertTrue(queue.items.isEmpty)
    }

    func testSavePassesTheFilterAtZeroToOneAndHoldsForTheTranscript() async {
        let queue = QueueSpy()
        transcript = VideoTranscript(text: "hello", segments: [])
        let m = makeModel(queue: queue)
        m.pickFilter(.noir)
        m.setFilterStrength(40)
        record(m)
        await m.save()
        XCTAssertEqual(exporter.calls.first?.filter, .noir)
        XCTAssertEqual(exporter.calls.first?.strength, 0.4)
        XCTAssertEqual(queue.items.first?.holdsForTranscript, 4)
        XCTAssertEqual(queue.items.first?.hasPoster, true)
        XCTAssertEqual(transcriptTimeouts, [.seconds(4)])
        XCTAssertEqual(queue.supplied, [transcript])
    }

    func testSavingAnImportKeepsItsWindowAndSource() async {
        let queue = QueueSpy()
        let m = makeModel(queue: queue)
        m.imported(url: tmpURL, duration: 180)
        m.trimmed(range: 30...150)
        await m.save()
        XCTAssertEqual(queue.items.first?.source, "import")
        XCTAssertEqual(exporter.calls.first?.window, 30...150)
        XCTAssertEqual(exporter.calls.first?.clips.count, 1)
    }

    func testSaveFromALessonAttachesTheVideo() async {
        let queue = QueueSpy(); var finished: VideoRecorderEntry?
        let entry = VideoRecorderEntry.lesson(versionId: "ver1", activityId: "act9")
        let m = makeModel(entry: entry, queue: queue)
        m.onFinished = { finished = $0 }
        record(m)
        await m.save()
        XCTAssertEqual(queue.items.first?.attach, VideoAttach(versionId: "ver1", activityId: "act9", title: "Video 1"))
        XCTAssertEqual(finished, entry)
    }

    // MARK: the saver keeps the recording until the queue has it (D26)

    func testAFailedExportShowsTheBannerAndRetrySavesIt() async {
        let queue = QueueSpy()
        exporter.failures = 1
        let saver = makeSaver(queue: queue)
        let m = makeModel(saver: saver)
        record(m)
        await m.save()
        XCTAssertEqual(reports, ["Couldn't save your video"])
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(drafts.saving().count, 1)
        XCTAssertTrue(drafts.recoverable().isEmpty)
        retries[0]()
        await saver.settled()
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertTrue(drafts.saving().isEmpty)
    }

    func testAQueueThatRefusesTheVideoKeepsTheRecording() async {
        let queue = QueueSpy()
        queue.error = CocoaError(.fileWriteOutOfSpace)
        let m = makeModel(queue: queue)
        record(m)
        await m.save()
        XCTAssertEqual(reports, ["Couldn't save your video"])
        XCTAssertEqual(drafts.saving().first?.draft.segments.count, 1)
    }

    func testAnExportCutOffByTheBackgroundRunsAgainWithoutABanner() async {
        let queue = QueueSpy()
        exporter.failures = 1
        interruptions = 1
        let m = makeModel(queue: queue)
        record(m)
        await m.save()
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(reports, [])
    }

    func testARelaunchFinishesASaveThatWasCutOff() async throws {
        let queue = QueueSpy()
        let draft = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        let save = VideoSave(entry: .lesson(versionId: "v", activityId: nil), source: .imported, filter: .warm,
                             strength: 60, window: 1...3)
        try drafts.markSaving(save, in: draft)
        let saver = makeSaver(queue: queue)
        saver.resume()
        saver.resume()
        await saver.settled()
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.attach, VideoAttach(versionId: "v", activityId: nil, title: "Video 1"))
        XCTAssertEqual(exporter.calls, [.init(clips: draft.segments.map(\.url), window: 1...3, filter: .warm, strength: 0.6, layers: [])])
        XCTAssertFalse(drafts.exists(draft))
    }

    /// The kill came after the queue took the video and before the draft went.
    func testARelaunchDoesNotQueueAVideoTheQueueAlreadyHas() async throws {
        let api = FakeVideoAPI()
        let queue = VideoUploadController(api: api, transport: api, banner: BannerSpy(), directory: dir.appendingPathComponent("queue"),
                                          ownerUserId: "u", environment: "test", defaultTitle: { "Video 1" })
        let draft = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        try drafts.markSaving(VideoSave(entry: .plusMenu, source: .recording, filter: .normal, strength: 100, window: nil), in: draft)
        try queue.enqueue(ExportedVideo(url: tmpURL, durationSeconds: 4, posterImage: UIImage()), localId: draft.id.uuidString,
                          attach: nil, transcriptHold: 600)
        let exporter = exporter!
        let spoken = VideoTranscript(text: "hello", segments: [])
        let saver = VideoSaver(drafts: drafts, queue: queue, nextTitle: { "Video 2" }, report: { _, message, _ in XCTFail(message) },
                               export: { try await exporter.export($0, $1, $2, $3, $4, $5) }, transcribe: { _, _ in spoken },
                               waitForForeground: { false })
        saver.resume()
        await saver.settled()
        XCTAssertEqual(queue.pending().map(\.localId), [draft.id.uuidString])
        XCTAssertEqual(queue.pending().first?.transcript, spoken)
        XCTAssertTrue(exporter.calls.isEmpty)
        XCTAssertFalse(drafts.exists(draft))
        XCTAssertTrue(saver.saving.isEmpty)
    }

    func testACancelledSaverEnqueuesNothingAndKeepsTheRecording() async throws {
        let queue = QueueSpy()
        exporter.holds = true
        let saver = makeSaver(queue: queue)
        let m = makeModel(saver: saver)
        record(m)
        let saving = Task { await m.save() }
        for _ in 0..<200 where exporter.calls.isEmpty { await Task.yield() }
        saver.cancel()
        exporter.release()
        await saving.value
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(reports, [])
        XCTAssertEqual(drafts.saving().count, 1)
    }

    // MARK: layers and the corrected transcript (video-editor D12, D27)

    private let heard = VideoTranscript(text: "Jon", segments: [VideoTranscriptSegment(text: "Jon", startMs: 0, endMs: 3000)])

    private let layers = [
        VideoLayer(kind: .text, text: "Title", startMs: 0, endMs: 4000),
        VideoLayer(kind: .caption, text: "John", startMs: 0, endMs: 3000, sourceSegment: 0)
    ]

    /// A 4 s draft holding a title and, with a transcript, its captions, the first reworded "John".
    private func edited(_ transcript: VideoTranscript?) throws -> VideoDraft {
        let draft = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        return try drafts.save(layers: transcript == nil ? [layers[0]] : layers, transcript: transcript, in: draft)
    }

    private var plusSave: VideoSave {
        VideoSave(entry: .plusMenu, source: .recording, filter: .normal, strength: 100, window: nil)
    }

    private func saved(resumed: Bool) async throws -> (QueueSpy, [VideoLayer]) {
        let queue = QueueSpy()
        let saver = makeSaver(queue: queue)
        let draft = try edited(heard)
        if resumed {
            try drafts.markSaving(plusSave, in: draft)
            saver.resume()
        } else {
            _ = try saver.start(plusSave, of: .draft(draft))
        }
        await saver.settled()
        return (queue, layers)
    }

    func testSaveWithATranscript() async throws {
        for resumed in [false, true] {
            exporter = ExportSpy()
            let (queue, layers) = try await saved(resumed: resumed)
            XCTAssertEqual(exporter.calls.last?.layers, layers); XCTAssertEqual(queue.items.map(\.transcript?.text), ["John"])
            XCTAssertNil(queue.items[0].holdsForTranscript); XCTAssertEqual(transcriptTimeouts, []); XCTAssertEqual(queue.supplied, [])
        }
    }

    func testSaveWithoutATranscript() async throws {
        let queue = QueueSpy()
        transcript = heard
        let saver = makeSaver(queue: queue)
        _ = try saver.start(plusSave, of: .draft(try edited(nil)))
        await saver.settled()
        XCTAssertEqual(exporter.calls.map(\.layers), [[layers[0]]]); XCTAssertEqual(queue.supplied, [heard])
        XCTAssertNotNil(queue.items[0].holdsForTranscript); XCTAssertNil(queue.items[0].transcript)
    }

    func testAQueuedVideoWithATranscriptOnlyDiscardsTheDraft() async throws {
        let queue = QueueSpy()
        let draft = try edited(heard)
        queue.alreadyHolds = VideoQueueItem(
            localId: draft.id.uuidString, fileName: "q.mp4", posterFileName: nil, title: "Video 1", durationSeconds: 4,
            source: .recording, transcript: nil, createdAt: Date(), streamUid: nil, serverId: nil, stage: .queued, failures: 0,
            polls: 0, nextAttemptAt: nil, attach: nil, ownerUserId: "u", environment: "test")
        try drafts.markSaving(plusSave, in: draft)
        let saver = makeSaver(queue: queue)
        saver.resume()
        await saver.settled()
        XCTAssertTrue(exporter.calls.isEmpty); XCTAssertEqual(transcriptTimeouts, [])
        XCTAssertTrue(queue.items.isEmpty); XCTAssertEqual(queue.supplied, [])
        XCTAssertFalse(drafts.exists(draft)); XCTAssertTrue(saver.saving.isEmpty)
    }

    func testAStaleDraftValueDrawsTheLayersTheManifestHolds() async throws {
        let queue = QueueSpy()
        let stale = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        _ = try drafts.save(layers: layers, transcript: heard, in: stale)
        let saver = makeSaver(queue: queue)
        _ = try saver.start(plusSave, of: .draft(stale))
        await saver.settled()
        XCTAssertEqual(exporter.calls.last?.layers, layers); XCTAssertEqual(queue.items.map(\.transcript?.text), ["John"])
    }

    // MARK: a video being saved is listed at once (D12)

    func testAVideoBeingSavedIsListedUntilTheQueueHasIt() async {
        let queue = QueueSpy()
        exporter.holds = true
        let saver = makeSaver(queue: queue)
        let m = makeModel(entry: .lesson(versionId: "ver1", activityId: nil), saver: saver)
        var listedOnFinish: [String] = []
        m.onFinished = { _ in listedOnFinish = saver.saving.map(\.title) }
        record(m)
        let saving = Task { await m.save() }
        for _ in 0..<200 where exporter.calls.isEmpty { await Task.yield() }
        XCTAssertEqual(listedOnFinish, ["Video 1"])
        let item = saver.saving.first
        XCTAssertEqual(item?.attach, VideoAttach(versionId: "ver1", activityId: nil, title: "Video 1"))
        exporter.release()
        await saving.value
        XCTAssertTrue(saver.saving.isEmpty)
        XCTAssertEqual(queue.items.map(\.localId), [item?.localId])
        XCTAssertEqual(queue.items.map(\.title), ["Video 1"])
    }

    func testTwoVideosBeingSavedAtOnceTakeDifferentTitles() async {
        let queue = QueueSpy()
        exporter.holds = true
        var saver: VideoSaver!
        saver = makeSaver(queue: queue, savingTitles: { saver.saving.map(\.title) })
        let m = makeModel(saver: saver), n = makeModel(saver: saver)
        record(m)
        record(n)
        let first = Task { await m.save() }
        let second = Task { await n.save() }
        for _ in 0..<200 where exporter.calls.count < 2 { await Task.yield() }
        XCTAssertEqual(saver.saving.map(\.title).sorted(), ["Video 1", "Video 2"])
        exporter.release()
        await first.value
        await second.value
        XCTAssertEqual(queue.items.map(\.title).sorted(), ["Video 1", "Video 2"])
    }

    func testARelaunchKeepsTheTitleTheRowHad() async throws {
        let queue = QueueSpy()
        let draft = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        var save = VideoSave(entry: .plusMenu, source: .recording, filter: .normal, strength: 100, window: nil)
        save.title = "Video 7"
        try drafts.markSaving(save, in: draft)
        let saver = makeSaver(queue: queue)
        saver.resume()
        XCTAssertEqual(saver.saving.map(\.title), ["Video 7"])
        XCTAssertEqual(saver.saving.map(\.durationSeconds), [4])
        await saver.settled()
        XCTAssertEqual(queue.items.map(\.title), ["Video 7"])
    }

    func testAFailedSaveStaysListedAndRemovingItDropsTheRecording() async {
        exporter.failures = 1
        let queue = QueueSpy()
        let saver = makeSaver(queue: queue)
        let m = makeModel(saver: saver)
        record(m)
        await m.save()
        XCTAssertEqual(saver.saving.count, 1)
        XCTAssertTrue(saver.remove(localId: saver.saving[0].localId))
        XCTAssertTrue(saver.saving.isEmpty)
        XCTAssertTrue(drafts.saving().isEmpty)
        retries[0]()
        await saver.settled()
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertFalse(saver.remove(localId: "unknown"))
    }

    func testRemovingAVideoWhileItExportsEnqueuesNothing() async {
        let queue = QueueSpy()
        exporter.holds = true
        let saver = makeSaver(queue: queue)
        let m = makeModel(saver: saver)
        record(m)
        let saving = Task { await m.save() }
        for _ in 0..<200 where exporter.calls.isEmpty { await Task.yield() }
        XCTAssertTrue(saver.remove(localId: saver.saving[0].localId))
        exporter.release()
        await saving.value
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(reports, [])
    }

    // MARK: the looping player

    func testTheReviewPlayerPlaysTheClips() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640))
        let live = VideoReviewPlayer()
        try await live.load(clips: [clip, clip], window: 0.5...1.5, look: VideoLook(filter: .mono, strength: 1))
        let item = try XCTUnwrap(live.item)
        XCTAssertEqual(item.asset.duration.seconds, 2, accuracy: 0.2)
        XCTAssertEqual(item.forwardPlaybackEndTime.seconds, 1.5, accuracy: 0.01)
        XCTAssertNotNil(item.videoComposition)
        live.stop()
        XCTAssertNil(live.item)
    }
}
