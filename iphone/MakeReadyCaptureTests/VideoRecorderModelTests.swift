//
//  VideoRecorderModelTests.swift
//  MakeReadyCaptureTests
//
//  video-recorder D1–D7, D9, D19, D26: `VideoRecorderModel` over a spy engine and a clock the test steps.
//

import AVFoundation
import CoreImage
import XCTest
@testable import MakeReady

@MainActor
private final class SpyRecorderEngine: VideoRecorderCapturing {
    var state: VideoCaptureEngine.State = .idle
    var draft: VideoDraft?
    var lastError: Error?
    var previewFilter: CIFilter?
    var onInterrupted: (() -> Void)?
    let displayLayer = CALayer()
    var denies = false
    var startError: Error?
    /// The file's real duration for the next stopped segment; nil loses the segment.
    var fileDuration: TimeInterval? = 3
    private(set) var didStart = false
    private(set) var starts = 0
    private(set) var flips = 0
    private(set) var discards = 0
    private(set) var closes = 0
    private(set) var prepares = 0
    private(set) var savedSettings: [VideoDraftSettings] = []

    func prepare() async throws {
        prepares += 1
        state = denies ? .denied(.camera) : (draft?.segments.isEmpty == false ? .paused : .ready)
    }

    func start() async throws {
        if let startError { throw startError }
        didStart = true
        starts += 1
        lastError = nil
        guard !denies else { state = .denied(.camera); return }
        if draft == nil { draft = Self.draft([]) }
        state = .recording
    }

    func stopSegment() async {
        guard state == .recording else { return }
        if let fileDuration {
            draft = Self.draft((draft?.segments.map(\.duration) ?? []) + [fileDuration])
        } else {
            lastError = VideoCaptureError.recordingFailed
        }
        state = .paused
    }

    func close() async { closes += 1; state = .idle }
    func flip() { flips += 1 }
    func restore(_ draft: VideoDraft) { self.draft = draft }

    func deleteLastSegment() throws {
        draft = Self.draft((draft?.segments.map(\.duration) ?? []).dropLast())
    }

    func discardDraft() { discards += 1; draft = nil }
    func save(settings: VideoDraftSettings) { savedSettings.append(settings) }

    func save(layers: [VideoLayer], transcript: VideoTranscript?) throws {
        guard var current = draft else { throw VideoDraftError.noDraft }
        current.layers = layers
        current.transcript = transcript
        draft = current
    }

    func adopt(imported file: URL, duration: TimeInterval, window: ClosedRange<Double>?, settings: VideoDraftSettings) throws {
        var adopted = Self.draft([duration], settings: settings)
        adopted.source = .imported
        adopted.window = window
        draft = adopted
    }

    static func draft(_ durations: [TimeInterval], settings: VideoDraftSettings = VideoDraftSettings()) -> VideoDraft {
        let folder = URL(fileURLWithPath: "/tmp/draft")
        return VideoDraft(id: UUID(), folder: folder, createdAt: Date(), settings: settings,
                          segments: durations.map { VideoDraftSegment(url: folder, duration: $0) })
    }
}

/// Save is `VideoRecorderSaveTests`'s.
@MainActor
private final class UnusedSaver: VideoSaving {
    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never> { Task {} }
}

/// Suspends every sleep until the test steps it.
@MainActor
private final class StepClock {
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func sleep() async { await withCheckedContinuation { waiting.append($0) } }

    /// Lets one sleeper go, once there is one, and the code after it run.
    func step() async {
        for _ in 0..<100 where waiting.isEmpty { await Task.yield() }
        guard !waiting.isEmpty else { return XCTFail("nothing is sleeping") }
        waiting.removeFirst().resume()
        for _ in 0..<20 { await Task.yield() }
    }

    func releaseAll() {
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

@MainActor
final class VideoRecorderModelTests: XCTestCase {
    private var engine: SpyRecorderEngine!
    private var clock: StepClock!
    private var settings: RecorderSettings!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var beeps: [Double] = []
    private var reports: [String] = []
    private var notesLoads = 0

    override func setUp() async throws {
        engine = SpyRecorderEngine()
        clock = StepClock()
        suiteName = "VideoRecorderModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = RecorderSettings(defaults: defaults)
        beeps = []
        reports = []
        notesLoads = 0
    }

    override func tearDown() async throws {
        clock.releaseAll()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(entry: VideoRecorderEntry = .plusMenu, length: Int = 60, preRoll: PreRoll = .off,
                           endCountdown: Int = 0, recovered: VideoDraft? = nil) -> VideoRecorderModel {
        settings.length = length
        settings.preRoll = preRoll
        settings.endCountdownSeconds = endCountdown
        let clock = clock!
        return VideoRecorderModel(
            entry: entry, engine: engine, settings: settings, player: VideoReviewPlayer(), saver: UnusedSaver(),
            recoverDraft: { recovered }, beep: { [weak self] in self?.beeps.append($0) },
            report: { [weak self] _, message in self?.reports.append(message) },
            loadNotes: { [weak self] in self?.notesLoads += 1 },
            now: { 0 }, sleep: { _ in await clock.sleep() })
    }

    // MARK: the rail (D1)

    func testRailOrder() {
        XCTAssertEqual(VideoRecorderModel.railTools, [.flip, .countdown, .length, .filters, .teleprompter])
    }

    func testRailFlipsAndCountdownOpensItsPanelWithoutCycling() {
        let m = makeModel()
        m.rail(.flip)
        XCTAssertEqual(engine.flips, 1)
        m.rail(.countdown)
        XCTAssertEqual(m.screenState.preRoll, .off, "countdown-sound S4: the tool opens the panel; it no longer cycles")
    }

    // MARK: the Countdown panel (countdown-sound S2–S4)

    func testCountdownPanelSetsAndPersistsTheChoice() {
        let m = makeModel()
        m.setPreRoll(.ten)
        XCTAssertEqual(m.screenState.preRoll, .ten)
        XCTAssertEqual(settings.preRoll, .ten)
        XCTAssertEqual(m.viewState(layout: .fullScreen).countdownValue, "10s")
        m.setPreRoll(.off)
        XCTAssertEqual(m.viewState(layout: .fullScreen).countdownValue, "")
    }

    func testCountdownSoundIsOffByDefaultAndPersists() {
        let m = makeModel()
        XCTAssertFalse(m.viewState(layout: .fullScreen).countdownSound, "S3: silent until the leader turns it on")
        m.setCountdownSound(true)
        XCTAssertTrue(settings.countdownSound)
        XCTAssertTrue(m.viewState(layout: .fullScreen).countdownSound)
        XCTAssertTrue(makeModel().viewState(layout: .fullScreen).countdownSound, "read back from the device setting")
    }

    // MARK: a tap during pre-roll cancels it (D2)

    func testPreRollCancel() {
        let m = makeModel(preRoll: .three)
        m.recordTapped()
        XCTAssertEqual(m.screenState.phase, .preRoll(3))
        m.recordTapped()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertFalse(engine.didStart)
    }

    func testPreRollCountsDownWithBeepsThenRecords() async {
        let m = makeModel(preRoll: .three)
        m.recordTapped()
        await clock.step()
        XCTAssertEqual(m.screenState.phase, .preRoll(2))
        await clock.step()
        XCTAssertEqual(m.screenState.phase, .preRoll(1))
        XCTAssertFalse(engine.didStart)
        await clock.step()
        XCTAssertEqual(m.screenState.phase, .recording)
        await m.settled()
        XCTAssertTrue(engine.didStart)
        XCTAssertEqual(beeps, [1100, 1100, 1660])
    }

    func testACancelledPreRollNeverRecords() async {
        let m = makeModel(preRoll: .three)
        m.recordTapped()
        m.recordTapped()
        await clock.step()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertFalse(engine.didStart)
        XCTAssertEqual(beeps, [1100])
    }

    func testBackgroundingCancelsThePreRoll() {
        let m = makeModel(preRoll: .ten)
        m.recordTapped()
        m.backgrounded()
        XCTAssertEqual(m.screenState.phase, .ready)
    }

    // MARK: the end countdown and auto-stop open Review (D4)

    func testAutoStopOpensReview() async {
        let m = makeModel(length: 30, preRoll: .off, endCountdown: 10)
        m.recordTapped()
        m.tick(recorded: 21)
        XCTAssertEqual(m.screenState.phase, .endCountdown(9))
        m.tick(recorded: 30)
        XCTAssertEqual(m.screenState.phase, .review)
    }

    func testEndCountdownShowsTheNumeralOnTheScreen() {
        let m = makeModel(length: 30, endCountdown: 10)
        m.recordTapped()
        m.tick(recorded: 21)
        let shown = m.viewState(layout: .fullScreen)
        XCTAssertEqual(shown.phase, .endCountdown)
        XCTAssertEqual(shown.countdownNumeral, 9)
        XCTAssertEqual(shown.liveDuration, 21)
    }

    // MARK: delete-last shows only with a segment and nothing recording (D5)

    func testDeleteLastVisibility() {
        let m = makeModel(length: 60, preRoll: .off)
        XCTAssertFalse(m.screenState.showsDeleteLast)
        m.recordTapped(); m.tick(recorded: 3)
        XCTAssertFalse(m.screenState.showsDeleteLast)
        m.recordTapped()
        XCTAssertTrue(m.screenState.showsDeleteLast)
    }

    func testDeleteLastAsksThenRemovesOnlyTheLastClip() async {
        let m = makeModel(recovered: SpyRecorderEngine.draft([4, 2]))
        m.open()
        m.requestDeleteLast()
        XCTAssertEqual(m.confirm, .deleteLast)
        XCTAssertEqual(m.confirm?.title, "Delete the last clip?")
        XCTAssertEqual(m.screenState.segments, [4, 2])
        m.deleteLastConfirmed()
        await m.settled()
        XCTAssertNil(m.confirm)
        XCTAssertEqual(m.screenState.segments, [4])
        XCTAssertEqual(engine.draft?.segments.map(\.duration), [4])
        m.requestDeleteLast()
        m.deleteLastConfirmed()
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertFalse(m.screenState.showsDeleteLast)
    }

    func testDoneNeedsASegmentAndOpensReview() {
        let m = makeModel()
        XCTAssertFalse(m.screenState.canFinish)
        m.done()
        XCTAssertEqual(m.screenState.phase, .ready)
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        XCTAssertTrue(m.screenState.canFinish)
        m.done()
        XCTAssertEqual(m.screenState.phase, .review)
    }

    func testASegmentTakesItsFilesOwnDurationAndTheNextOneAppends() async {
        engine.fileDuration = 2.8
        let m = makeModel()
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        await m.settled()
        XCTAssertEqual(m.screenState.segments, [2.8])
        m.recordTapped()
        await m.settled()
        m.tick(recorded: 5)
        XCTAssertEqual(m.screenState.segments, [2.8])
        XCTAssertEqual(m.screenState.liveDuration, 2.2, accuracy: 0.001)
    }

    func testALostSegmentIsDroppedAndReported() async {
        engine.fileDuration = nil
        let m = makeModel()
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        await m.settled()
        XCTAssertEqual(m.screenState.segments, [])
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertEqual(reports, ["Couldn't save the clip"])
    }

    func testALostClipIsReportedOnce() async {
        engine.fileDuration = nil
        let m = makeModel()
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        await m.settled()
        // Stopped before it began: the engine never starts, so nothing was lost this time.
        m.recordTapped(); m.recordTapped()
        await m.settled()
        XCTAssertEqual(reports, ["Couldn't save the clip"])
    }

    /// The shell's + menu opens it as the lesson editor does.
    func testOpeningWithNoSignedInUserShowsTheBanner() {
        for entry in [VideoRecorderEntry.plusMenu, .lesson(versionId: "v1", activityId: nil)] {
            let app = AppState()
            XCTAssertNil(VideoRecorderModel.live(entry: entry, userId: nil, app: app))
            XCTAssertEqual(app.activeSurfacedError?.message, "Couldn't open the recorder")
        }
    }

    // MARK: an interruption pauses and never resumes (D26)

    func testInterruptionPauses() async {
        let m = makeModel()
        m.recordTapped(); await m.settled(); m.tick(recorded: 3)
        engine.onInterrupted?()
        XCTAssertEqual(m.screenState.phase, .paused)
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .paused)
        XCTAssertEqual(engine.starts, 1)
    }

    func testLowDiskShowsTheBanner() async {
        engine.startError = VideoCaptureError.lowDiskSpace
        let m = makeModel()
        m.recordTapped()
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .ready)
        XCTAssertEqual(reports, ["Not enough free space to record"])
    }

    // MARK: a denied permission (D19)

    func testDeniedPermissionShowsTheEmptyStateAndRetriesOnReturn() async {
        engine.denies = true
        let m = makeModel()
        m.open()
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .permissionDenied)
        m.recordTapped()
        XCTAssertFalse(engine.didStart)
        engine.denies = false
        m.becameActive()
        await m.settled()
        XCTAssertEqual(m.screenState.phase, .ready)
    }

    // MARK: the countdown beep (D2)

    func testTheBeepIsAPlayableTone() throws {
        let player = try AVAudioPlayer(data: CountdownBeeper.wav(hz: 1100))
        XCTAssertEqual(player.duration, 0.12, accuracy: 0.01)
    }

    // MARK: the length (D3)

    func testLengthIsFixedOnceASegmentExists() {
        let m = makeModel(length: 60)
        m.setLength(90)
        XCTAssertEqual(m.screenState.length, 90)
        XCTAssertEqual(settings.length, 90)
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        m.setLength(30)
        XCTAssertEqual(m.screenState.length, 90)
        XCTAssertEqual(settings.length, 90)
    }

    // MARK: video-polish D4, D6 — length mode and the opt-in end countdown

    func testEndCountdownIsOffByDefault() {
        let m = makeModel(length: 30)
        m.recordTapped()
        m.tick(recorded: 25)
        XCTAssertEqual(m.screenState.phase, .recording)
    }

    func testAnyLengthStopsAtTheTwoMinuteCap() {
        let m = makeModel(length: 30)
        m.setLengthMode(.any)
        XCTAssertEqual(settings.lengthMode, .any)
        m.recordTapped()
        m.tick(recorded: 60)
        XCTAssertEqual(m.screenState.phase, .recording)
        m.tick(recorded: 120)
        XCTAssertEqual(m.screenState.phase, .review)
    }

    func testEndCountdownChoicePersists() {
        let m = makeModel(length: 30)
        m.setEndCountdown(3)
        XCTAssertEqual(m.endCountdownSeconds, 3)
        XCTAssertEqual(settings.endCountdownSeconds, 3)
        m.recordTapped()
        m.tick(recorded: 27.5)
        XCTAssertEqual(m.screenState.phase, .endCountdown(3))
    }

    // MARK: a new filter pick resets strength to 100 (D6)

    func testFilterStrengthReset() {
        let m = makeModel(length: 60, preRoll: .off)
        m.setFilterStrength(40)
        m.pickFilter(.allCases[2])
        XCTAssertEqual(m.screenState.filterStrength, 100)
    }

    func testTheFilterDrawsOnThePreview() {
        let m = makeModel()
        m.pickFilter(.vivid)
        XCTAssertNotNil(engine.previewFilter)
        XCTAssertEqual(m.viewState(layout: .fullScreen).filterLook, "Vivid")
        m.pickFilter(.normal)
        XCTAssertNil(engine.previewFilter)
    }

    // MARK: the teleprompter (D7)

    func testTheScriptPersistsAndANoteReplacesIt() {
        let m = makeModel()
        m.rail(.teleprompter)
        XCTAssertFalse(m.screenState.teleprompterOn, "video-polish D3: the tap opens the sheet; it never turns it on")
        m.setScript("Typed")
        XCTAssertTrue(m.screenState.teleprompterOn)
        XCTAssertEqual(settings.script, "Typed")
        m.openNotePicker()
        XCTAssertTrue(m.notePickerOpen)
        m.useNote(content: "# Welcome\n\nGood **morning**")
        XCTAssertFalse(m.notePickerOpen)
        XCTAssertEqual(m.screenState.script, "Welcome\nGood morning")
        XCTAssertEqual(settings.script, "Welcome\nGood morning")
    }

    // MARK: video-polish D3 — on only with text

    func testSavedScriptTurnsTheTeleprompterOn() {
        settings.script = "Welcome"
        let m = makeModel()
        XCTAssertTrue(m.screenState.teleprompterOn)
    }

    func testClearingTheScriptTurnsTheTeleprompterOff() {
        settings.script = "Welcome"
        let m = makeModel()
        m.setScript("   \n")
        XCTAssertFalse(m.screenState.teleprompterOn)
        m.setScript("")
        XCTAssertFalse(m.viewState(layout: .fullScreen).teleprompterOn)
    }

    func testTheLengthPanelStateReachesTheScreen() {
        let m = makeModel(length: 30, endCountdown: 3)
        XCTAssertEqual(m.viewState(layout: .fullScreen).lengthMode, "specify")
        XCTAssertEqual(m.viewState(layout: .fullScreen).endCountdown, 3)
        XCTAssertEqual(m.viewState(layout: .fullScreen).length, 30)
        m.setLengthMode(.any)
        XCTAssertEqual(m.viewState(layout: .fullScreen).lengthMode, "any")
        XCTAssertEqual(m.viewState(layout: .fullScreen).length, 120)
    }

    func testTheBandScrollsOnlyWhileRecordingAndASpeedChangeKeepsTheLine() async {
        let m = makeModel()
        m.setScript("Script")
        XCTAssertEqual(m.screenState.teleprompterOffset, 0)
        m.recordTapped(); await m.settled(); m.tick(recorded: 3)
        let moved = m.screenState.teleprompterOffset
        XCTAssertGreaterThan(moved, 0)
        m.recordTapped()
        await m.settled()
        XCTAssertEqual(m.screenState.teleprompterOffset, moved)
        m.setSpeed(5)
        XCTAssertEqual(m.screenState.teleprompterOffset, moved, accuracy: 0.001)
        XCTAssertEqual(settings.speedStep, 5)
    }

    // MARK: the draft (D26) and closing (D9)

    func testOpenRestoresACrashedDraft() async {
        let draft = SpyRecorderEngine.draft([4], settings: .init(lengthSeconds: 30, filter: "mono", filterStrength: 40))
        let m = makeModel(recovered: draft)
        m.open()
        XCTAssertEqual(m.screenState.phase, .paused)
        XCTAssertEqual(m.screenState.segments, [4])
        XCTAssertEqual(m.screenState.length, 30)
        XCTAssertEqual(m.screenState.filter, .mono)
        XCTAssertEqual(m.screenState.filterStrength, 40)
        await m.settled()
        XCTAssertEqual(engine.draft?.id, draft.id)
        XCTAssertEqual(m.screenState.phase, .paused)
    }

    func testDraftsArePerOwnerAndEnvironment() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) } // Silent: a temp folder
        let folders = try [("local", "a"), ("local", "b"), ("production", "a")].map {
            try VideoDraftStore.folder(environment: $0.0, userId: $0.1, root: root).path
        }
        XCTAssertEqual(Set(folders).count, 3)
    }

    func testRecordingSavesTheChoicesInTheDraft() async {
        let m = makeModel(length: 30)
        m.pickFilter(.noir)
        m.recordTapped()
        await m.settled()
        XCTAssertEqual(engine.savedSettings.last, VideoDraftSettings(lengthSeconds: 30, filter: "noir", filterStrength: 100))
    }

    func testALessonRecordingSavesItsEntryInTheDraft() async {
        let entry = VideoRecorderEntry.lesson(versionId: "ver1", activityId: nil)
        let m = makeModel(entry: entry)
        m.recordTapped()
        await m.settled()
        XCTAssertEqual(engine.savedSettings.last?.entry, entry)
    }

    func testClosingWithNothingRecordedClosesAtOnce() async {
        let m = makeModel()
        m.closeTapped()
        XCTAssertTrue(m.isClosed)
        await m.settled()
        XCTAssertEqual(engine.closes, 1)
    }

    func testClosingWithASegmentAsksThenDiscards() async {
        let m = makeModel(recovered: SpyRecorderEngine.draft([4]))
        m.open()
        m.closeTapped()
        XCTAssertEqual(m.confirm, .discard)
        XCTAssertEqual(m.confirm?.title, "Discard this recording?")
        XCTAssertFalse(m.isClosed)
        m.dismissConfirm()
        XCTAssertFalse(m.isClosed)
        m.closeTapped()
        m.discardConfirmed()
        XCTAssertTrue(m.isClosed)
        await m.settled()
        XCTAssertEqual(engine.discards, 1)
        XCTAssertEqual(engine.closes, 1)
    }
}
