//
//  VideoRecorderModel.swift
//  MakeReady
//
//  video-recorder D1–D9, D19, D26: one recorder's logic for both layouts — the record button's
//  state machine, the timeline, the rail tools, import, Review, Save and the confirms — over the capture engine. The screen
//  answers a tap at once; the engine's work runs behind it, one call at a time, and the segments then
//  take their files' own durations.
//

import CoreImage
import Foundation
import QuartzCore

/// Where the recorder was opened from, which is where Save returns to (D9).
enum VideoRecorderEntry: Equatable, Codable {
    case plusMenu
    /// `activityId` is the activity whose video is replaced; nil makes a new one (D18).
    case lesson(versionId: String, activityId: String?)

    /// The Add menu's row.
    static let rowLabel = "Record a video"
}

/// What the recorder needs of `VideoCaptureEngine`, so its logic runs without a camera.
@MainActor
protocol VideoRecorderCapturing: AnyObject {
    var state: VideoCaptureEngine.State { get }
    var draft: VideoDraft? { get }
    /// The last lost segment's, until the recorder has reported it.
    var lastError: Error? { get set }
    var displayLayer: CALayer { get }
    var previewFilter: CIFilter? { get set }
    var onInterrupted: (() -> Void)? { get set }
    func prepare() async throws
    func start() async throws
    func stopSegment() async
    func close() async
    func flip()
    func restore(_ draft: VideoDraft)
    func deleteLastSegment() throws
    func discardDraft()
    func save(settings: VideoDraftSettings)
    func save(layers: [VideoLayer], transcript: VideoTranscript?) throws
    func adopt(imported file: URL, duration: TimeInterval, window: ClosedRange<Double>?, settings: VideoDraftSettings) throws
}

extension VideoCaptureEngine: VideoRecorderCapturing {}

@MainActor @Observable
final class VideoRecorderModel {
    enum Phase: Equatable {
        case ready
        /// The numeral shown (D2).
        case preRoll(Int)
        case recording
        /// Still recording, with the numeral shown (D4).
        case endCountdown(Int)
        case paused
        case permissionDenied
        case review
        case trim
        /// The naming page is open over Review, after a + menu save (video-naming D13, D14).
        case naming
    }

    /// The C-066 confirms.
    enum Confirm: Equatable {
        case deleteLast, discard, retake

        var title: String {
            switch self {
            case .deleteLast: "Delete the last clip?"
            case .discard: "Discard this recording?"
            case .retake: "Discard this video and start over?"
            }
        }

        var actionLabel: String {
            switch self {
            case .deleteLast: "Delete clip"
            case .discard: "Discard recording"
            case .retake: "Retake"
            }
        }
    }

    /// Makes the editor for a clip. The clip's `frame` is not measured: the maker sizes it.
    typealias MakeEditor = @MainActor (VideoEditorModel.Clip, [VideoLayer], VideoTranscript?,
                                       @escaping ([VideoLayer], VideoTranscript?) -> Void) async throws -> VideoEditorModel

    /// Everything the recorder shows, as values.
    struct ScreenState: Equatable {
        var phase: Phase
        var segments: [TimeInterval]
        var liveDuration: TimeInterval
        var length: Int
        var preRoll: PreRoll
        var filter: VideoFilter
        /// 0–100 (D6).
        var filterStrength: Int
        var teleprompterOn: Bool
        var script: String
        /// 1…5.
        var speed: Int
        /// 1…3.
        var textSizeStep: Int
        var teleprompterOffset: CGFloat
        /// D5: at least one segment and nothing recording.
        var showsDeleteLast: Bool
        /// D5: the checkmark opens Review.
        var canFinish: Bool
        /// D8: only before the first segment.
        var canImport: Bool
        /// The full-screen close is hidden while recording or counting down.
        var showsClose: Bool
    }

    /// Top to bottom (D1).
    static let railTools: [RailTool.Tool] = [.flip, .countdown, .length, .filters, .teleprompter]
    static let lowDiskMessage = "Not enough free space to record"
    /// How often the elapsed time, the countdown and the teleprompter move while recording.
    private static let tickInterval: Duration = .milliseconds(33)

    let entry: VideoRecorderEntry
    private(set) var phase: Phase = .ready
    private(set) var confirm: Confirm?
    private(set) var notePickerOpen = false
    /// True once the recorder is done; its host takes it off the screen.
    private(set) var isClosed = false
    /// A picked video is being read.
    private(set) var isImporting = false
    /// The imported clip Review or Trim shows; nil for a recording.
    private(set) var importedClip: VideoImportFlow.Clip?
    /// The part of `importedClip` kept; nil is all of it (D8).
    private(set) var trimWindow: ClosedRange<Double>?
    /// The editor over Review while it is open (video-editor D7); its host drops it with `editorHidden`.
    private(set) var editor: VideoEditorModel?
    /// The edit's layers, kept in memory even when the draft cannot be written (D16, D28).
    private(set) var layers: [VideoLayer] = []
    /// The naming page's model while it is open; its host drops it with `namingHidden` once the page is off the screen.
    /// After Back the phase is `review` while this is still set: the page is sliding out.
    private(set) var naming: VideoNamingModel?
    /// Save was tapped and the recorder is done (D9).
    @ObservationIgnored var onFinished: (VideoRecorderEntry) -> Void = { _ in }
    /// The recorder closed with nothing saved.
    @ObservationIgnored var onDiscarded: () -> Void = {}

    private var timeline: RecordingTimeline
    /// Total recorded time, the segment in progress included.
    private var recorded: TimeInterval = 0
    private var preRoll: PreRoll
    /// The Countdown panel's Sound switch (countdown-sound S2, S3): off until the leader turns it on.
    private var countdownSound: Bool
    private var filter: VideoFilter = .normal
    private var filterStrength = 100
    /// On exactly when the script has text (video-polish D3).
    private var teleprompterOn: Bool { !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// Review's playback, for the screen's play state and scrub bar (video-polish D9).
    private(set) var reviewPlaying = false
    private(set) var reviewElapsed: TimeInterval = 0
    private(set) var reviewScrubbing = false
    @ObservationIgnored private var playingBeforeScrub = false
    private var script: String
    private var speed: Int
    private var textSizeStep: Int
    /// Added to the scroller's position, so a new speed continues from the same line and a new note
    /// starts at its top.
    private var teleprompterShift: CGFloat = 0

    @ObservationIgnored private let engine: VideoRecorderCapturing
    @ObservationIgnored private let settings: RecorderSettings
    @ObservationIgnored private let player: VideoReviewPlaying
    @ObservationIgnored private let saver: VideoSaving
    @ObservationIgnored private let recoverDraft: () -> VideoDraft?
    @ObservationIgnored private let beep: (Double) -> Void
    @ObservationIgnored private let report: (Error, String) -> Void
    @ObservationIgnored private let loadNotes: () async throws -> Void
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private let suggest: (String) async throws -> [VideoDetailSuggestion]
    @ObservationIgnored private let onUnauthorized: () -> Void

    @ObservationIgnored private var opened = false
    @ObservationIgnored private var preRollTask: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Counts segments, so a segment stopped before it began is never started.
    @ObservationIgnored private var segmentNumber = 0
    @ObservationIgnored private var cancelledSegment: Int?
    @ObservationIgnored private var engineWork: Task<Void, Never>?
    @ObservationIgnored private var pendingWork = 0
    @ObservationIgnored private var playerWork: Task<Void, Never>?
    @ObservationIgnored private var isSaving = false
    @ObservationIgnored private var isOpeningEditor = false
    @ObservationIgnored private var backgroundedWhileOpening = false
    @ObservationIgnored private var transcript: VideoTranscript?
    @ObservationIgnored private let makeEditor: MakeEditor

    init(entry: VideoRecorderEntry, engine: VideoRecorderCapturing, settings: RecorderSettings,
         player: VideoReviewPlaying, saver: VideoSaving, recoverDraft: @escaping () -> VideoDraft?, beep: @escaping (Double) -> Void,
         report: @escaping (Error, String) -> Void, loadNotes: @escaping () async throws -> Void,
         makeEditor: MakeEditor? = nil,
         suggest: @escaping (String) async throws -> [VideoDetailSuggestion] = { _ in [] },
         onUnauthorized: @escaping () -> Void = {},
         now: @escaping () -> TimeInterval = CACurrentMediaTime,
         sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.entry = entry
        self.engine = engine
        self.settings = settings
        self.player = player
        self.saver = saver
        self.recoverDraft = recoverDraft
        self.beep = beep
        self.report = report
        self.loadNotes = loadNotes
        self.now = now
        self.sleep = sleep
        self.suggest = suggest
        self.onUnauthorized = onUnauthorized
        self.makeEditor = makeEditor ?? Self.liveEditor(report: report)
        timeline = RecordingTimeline(lengthSeconds: settings.length, mode: settings.lengthMode,
                                     endCountdownSeconds: settings.endCountdownSeconds)
        preRoll = settings.preRoll
        countdownSound = settings.countdownSound
        script = settings.script
        speed = settings.speedStep
        textSizeStep = settings.sizeStep
        engine.onInterrupted = { [weak self] in self?.interrupted() }
    }

    // MARK: Published

    var displayLayer: CALayer { engine.displayLayer }

    var playerLayer: CALayer { player.layer }

    /// Review, with nothing saving and no editor open (D7).
    var canEdit: Bool { phase == .review && !isSaving && editor == nil }

    /// The purple check: Review with no text editor open over it, and not closed (D18).
    var showsSaveCheck: Bool { phase == .review && editor == nil && !isClosed }

    var screenState: ScreenState {
        ScreenState(
            phase: phase, segments: timeline.segments,
            liveDuration: isCapturing ? max(recorded - timeline.total, 0) : 0,
            length: timeline.lengthSeconds, preRoll: preRoll, filter: filter, filterStrength: filterStrength,
            teleprompterOn: teleprompterOn, script: script, speed: speed, textSizeStep: textSizeStep,
            teleprompterOffset: teleprompterOffset,
            showsDeleteLast: phase == .paused && !timeline.segments.isEmpty,
            canFinish: phase == .paused && !timeline.segments.isEmpty,
            canImport: phase == .ready && timeline.segments.isEmpty,
            showsClose: !isCapturing && !isCountingDown)
    }

    /// A segment is being recorded.
    var isCapturing: Bool {
        switch phase {
        case .recording, .endCountdown: true
        case .ready, .preRoll, .paused, .permissionDenied, .review, .trim, .naming: false
        }
    }

    var isCountingDown: Bool {
        if case .preRoll = phase { true } else { false }
    }

    // MARK: Opening and closing

    /// Brings back a recording a crash cut off (D26) and turns the camera on. Nothing is recording
    /// yet, which is when drafts may be salvaged.
    func open() {
        guard !opened else { return }
        opened = true
        if let draft = recoverDraft() {
            engine.restore(draft)
            timeline = RecordingTimeline(lengthSeconds: draft.settings.lengthSeconds, mode: timeline.mode,
                                         endCountdownSeconds: timeline.endCountdownSeconds)
            filter = draft.settings.filter.flatMap(VideoFilter.init(rawValue:)) ?? .normal
            filterStrength = Int(draft.settings.filterStrength)
            layers = draft.layers
            transcript = draft.transcript
            syncTimeline()
            if draft.source == .imported, let segment = draft.segments.first {
                importedClip = VideoImportFlow.Clip(url: segment.url, duration: segment.duration)
                trimWindow = draft.window
                resumeReview()
                return
            }
            if !draft.layers.isEmpty || draft.transcript != nil {
                resumeReview()
                return
            }
            phase = idlePhase
        }
        applyFilter()
        prepare()
    }

    /// A kill mid-edit comes back to Review with its layers (D16, D19).
    private func resumeReview() {
        applyFilter()
        player.show(layers: layers)
        showClip(in: .review)
    }

    /// Back from Settings the camera may be allowed now (D19); back in Review the video plays on.
    func becameActive() {
        guard opened, !isClosed else { return }
        switch phase {
        case .permissionDenied: prepare()
        case .review, .trim:
            if editor == nil, phase == .trim || reviewPlaying { player.play() }
        case .ready, .preRoll, .recording, .endCountdown, .paused, .naming: break
        }
    }

    /// The engine ends a segment itself (D26); a countdown has no segment yet.
    func backgrounded() {
        guard phase != .naming else {
            leaveNaming()
            return
        }
        cancelPreRoll()
        if isOpeningEditor { backgroundedWhileOpening = true }
        editor?.backgrounded()
    }

    /// Asks first when something would be lost (D9).
    func closeTapped() {
        guard !isSaving, !isClosed else { return }
        guard phase != .naming else {
            leaveNaming()
            return
        }
        cancelPreRoll()
        if isCapturing { endSegment() }
        if timeline.segments.isEmpty && importedClip == nil {
            discardAndClose()
        } else {
            confirm = .discard
        }
    }

    func discardConfirmed() {
        confirm = nil
        guard !isSaving else { return }
        discardAndClose()
    }

    func dismissConfirm() {
        confirm = nil
    }

    private func discardAndClose() {
        guard !isClosed else { return }
        isClosed = true
        stopPlaying()
        dropImport()
        layers = []
        transcript = nil
        perform { [self] in
            await engine.stopSegment()
            engine.discardDraft()
            await engine.close()
        }
        onDiscarded()
    }

    // MARK: Record button

    func recordTapped() {
        switch phase {
        case .ready, .paused:
            if preRoll == .off { beginSegment() } else { startPreRoll() }
        case .preRoll:
            cancelPreRoll()
        case .recording, .endCountdown:
            endSegment()
        case .permissionDenied, .review, .trim, .naming:
            break
        }
    }

    func pauseTapped() {
        if isCapturing { endSegment() }
    }

    /// Opens Review (D5).
    func done() {
        guard screenState.canFinish else { return }
        openReview()
    }

    func requestDeleteLast() {
        guard screenState.showsDeleteLast else { return }
        confirm = .deleteLast
    }

    func deleteLastConfirmed() {
        confirm = nil
        guard screenState.showsDeleteLast else { return }
        timeline.deleteLast()
        recorded = timeline.total
        phase = idlePhase
        perform { [self] in
            do {
                try engine.deleteLastSegment()
            } catch {
                report(error, "Couldn't delete the clip")
            }
            settleSegments()
        }
    }

    /// `recorded` is the total recorded time, across segments (D4).
    func tick(recorded total: TimeInterval) {
        guard isCapturing else { return }
        recorded = min(total, Double(timeline.effectiveLength))
        guard !timeline.shouldAutoStop(atRecorded: recorded) else {
            endSegment()
            openReview()
            return
        }
        let next: Phase = timeline.endCountdown(atRecorded: recorded).map(Phase.endCountdown) ?? .recording
        if phase != next { phase = next }
    }

    // MARK: Rail (D1)

    /// Countdown, Length, Filters and Teleprompter open their own panels on the screen.
    func rail(_ tool: RailTool.Tool) {
        switch tool {
        case .flip:
            engine.flip()
        case .countdown, .length, .filters, .edit:
            break
        case .teleprompter:
            // video-polish D3: the tap opens the sheet; text turns the teleprompter on.
            break
        }
    }

    /// The Countdown panel's Off · 3 s · 10 s choice (D2; countdown-sound S4).
    func setPreRoll(_ choice: PreRoll) {
        preRoll = choice
        settings.preRoll = choice
    }

    /// The Countdown panel's Sound switch (countdown-sound S2). The beeper reads the same setting.
    func setCountdownSound(_ on: Bool) {
        countdownSound = on
        settings.countdownSound = on
    }

    /// Ignored once a segment exists (D3).
    func setLength(_ seconds: TimeInterval) {
        guard phase == .ready, timeline.canChangeLength else { return }
        timeline.setLength(Int(seconds))
        settings.length = timeline.lengthSeconds
    }

    /// The Length panel's Any length / Specify length; ignored once a segment exists (video-polish D4).
    func setLengthMode(_ mode: LengthMode) {
        guard phase == .ready, timeline.canChangeLength else { return }
        timeline.setMode(mode)
        settings.lengthMode = mode
    }

    /// The Length panel's End countdown: 0 (off), 3 or 10 seconds (video-polish D6).
    func setEndCountdown(_ seconds: Int) {
        timeline.setEndCountdown(seconds)
        settings.endCountdownSeconds = timeline.endCountdownSeconds
    }

    /// The Length panel's current choices, for the screen.
    var lengthMode: LengthMode { timeline.mode }
    var endCountdownSeconds: Int { timeline.endCountdownSeconds }

    /// A new pick starts at full strength (D6).
    func pickFilter(_ look: VideoFilter) {
        filter = look
        filterStrength = 100
        applyFilter()
        saveChoices()
    }

    func setFilterStrength(_ strength: Int) {
        filterStrength = min(max(strength, 0), 100)
        applyFilter()
        saveChoices()
    }

    // MARK: Teleprompter (D7)

    /// Clearing the script turns the teleprompter off.
    func setScript(_ text: String) {
        script = text
        settings.script = text
    }

    func setSpeed(_ step: Int) {
        let line = teleprompterOffset
        settings.speedStep = step
        speed = settings.speedStep
        teleprompterShift = line - scrollPosition
    }

    func setTextSize(step: Int) {
        settings.sizeStep = step
        textSizeStep = settings.sizeStep
    }

    func openNotePicker() {
        notePickerOpen = true
        Task {
            do {
                try await loadNotes()
            } catch is CancellationError {
                return
            } catch {
                report(error, "Couldn't load your notes")
            }
        }
    }

    func closeNotePicker() {
        notePickerOpen = false
    }

    /// The note's text becomes the script, from its first line.
    func useNote(content: String) {
        notePickerOpen = false
        setScript(String(NoteDocumentCodec.parse(content).characters))
        teleprompterShift = -scrollPosition
    }

    private var teleprompterOffset: CGFloat { max(scrollPosition + teleprompterShift, 0) }

    private var scrollPosition: CGFloat {
        let style = TeleprompterBand.TextSize.allCases[textSizeStep - 1].style
        return TeleprompterScroller(speedStep: speed).offset(atRecorded: recorded, lineHeight: style.lineHeight ?? style.size)
    }

    // MARK: Pre-roll (D2)

    private func startPreRoll() {
        let seconds = preRoll.seconds
        showPreRoll(seconds)
        preRollTask = Task { [weak self, sleep] in
            for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                do {
                    try await sleep(.seconds(1))
                } catch {
                    return // Silent: the countdown was cancelled
                }
                guard let self, !Task.isCancelled else { return }
                if remaining > 0 { self.showPreRoll(remaining) } else { self.beginSegment() }
            }
        }
    }

    private func showPreRoll(_ remaining: Int) {
        phase = .preRoll(remaining)
        beep(preRoll.beepHz(remaining: remaining))
    }

    private func cancelPreRoll() {
        preRollTask?.cancel()
        preRollTask = nil
        if isCountingDown { phase = idlePhase }
    }

    // MARK: Segments

    private func beginSegment() {
        guard !timeline.shouldAutoStop(atRecorded: timeline.total) else {
            openReview()
            return
        }
        segmentNumber += 1
        let number = segmentNumber
        recorded = timeline.total
        phase = .recording
        perform { [self] in
            guard cancelledSegment != number, !isClosed else { return }
            do {
                try await engine.start()
            } catch {
                segmentNotStarted(error)
                return
            }
            guard engine.state == .recording else {
                segmentNotStarted(nil)
                return
            }
            saveChoices()
            guard isCapturing, segmentNumber == number else { return }
            startTicker()
        }
    }

    private func segmentNotStarted(_ error: Error?) {
        if isCapturing {
            recorded = timeline.total
            phase = deniedPhase ?? idlePhase
        }
        guard let error else { return }
        let lowDisk = error as? VideoCaptureError == .lowDiskSpace
        report(error, lowDisk ? Self.lowDiskMessage : "Couldn't start recording")
    }

    private func startTicker() {
        ticker?.cancel()
        let base = timeline.total
        let started = now()
        ticker = Task { [weak self, sleep, now] in
            while !Task.isCancelled {
                do {
                    try await sleep(Self.tickInterval)
                } catch {
                    return // Silent: the segment ended
                }
                guard let self, !Task.isCancelled else { return }
                self.tick(recorded: base + now() - started)
            }
        }
    }

    /// Ends the segment on the screen at once and in the engine behind it.
    private func endSegment() {
        ticker?.cancel()
        ticker = nil
        let live = recorded - timeline.total
        if live > 0 {
            timeline.append(live)
        } else {
            cancelledSegment = segmentNumber
        }
        recorded = timeline.total
        phase = idlePhase
        perform { [self] in
            await engine.stopSegment()
            if let error = engine.lastError {
                engine.lastError = nil
                report(error, "Couldn't save the clip")
            }
            settleSegments()
        }
    }

    /// The engine has already ended the segment.
    private func interrupted() {
        guard isCapturing else { return }
        endSegment()
    }

    /// Takes the files' own durations once the engine has nothing left to do.
    private func settleSegments() {
        guard pendingWork == 1 else { return }
        syncTimeline()
        switch phase {
        case .ready, .paused:
            phase = idlePhase
        case .review where timeline.segments.isEmpty && engine.draft != nil && importedClip == nil:
            phase = .ready // the only segment was lost
            prepare()
        case .preRoll, .recording, .endCountdown, .permissionDenied, .review, .trim, .naming:
            break
        }
    }

    private func syncTimeline() {
        guard let draft = engine.draft, draft.source == .recording else { return }
        var synced = timeline.withoutSegments
        draft.segments.forEach { synced.append($0.duration) }
        timeline = synced
        recorded = timeline.total
    }

    private var idlePhase: Phase { timeline.segments.isEmpty ? .ready : .paused }

    private var deniedPhase: Phase? {
        if case .denied = engine.state { .permissionDenied } else { nil }
    }

    // MARK: Import and trim (D8)

    /// Reads a pick; a recording begun meanwhile wins.
    func importPicked(_ load: () async throws -> VideoImportFlow.Clip) async {
        guard !isImporting, screenState.canImport else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let clip = try await load()
            imported(url: clip.url, duration: clip.duration)
        } catch is CancellationError {
            return
        } catch {
            if !isClosed { report(error, "Couldn't read that video") }
        }
    }

    /// The recorder owns the file from here.
    func imported(url: URL, duration: TimeInterval) {
        guard screenState.canImport, !isClosed else {
            VideoImportFlow.delete(url)
            return
        }
        importedClip = VideoImportFlow.Clip(url: url, duration: duration)
        if duration > VideoTrim.maxLength {
            trimWindow = VideoTrim.window(0...duration, duration: duration)
            showClip(in: .trim)
        } else {
            trimWindow = nil
            showClip(in: .review)
        }
    }

    func moveTrim(to range: ClosedRange<Double>) {
        guard phase == .trim, let importedClip else { return }
        let window = VideoTrim.window(range, duration: importedClip.duration)
        trimWindow = window
        player.move(to: window)
    }

    func trimmed(range: ClosedRange<Double>) {
        guard phase == .trim else { return }
        moveTrim(to: range)
        phase = .review
        player.loops = false
    }

    func trimCancelled() {
        guard phase == .trim else { return }
        returnToCamera()
    }

    private func dropImport() {
        if let importedClip { VideoImportFlow.delete(importedClip.url) }
        importedClip = nil
        trimWindow = nil
    }

    // MARK: Review (D9)

    private var isPlayback: Bool { phase == .review || phase == .trim }

    private func openReview() {
        showClip(in: .review)
    }

    /// Turns the camera off, so the player has the audio session, then plays the clips in a loop.
    private func showClip(in shown: Phase) {
        phase = shown
        perform { [self] in
            guard isPlayback, !isClosed else { return }
            await engine.close()
            settleSegments()
            startPlaying()
        }
    }

    private func startPlaying() {
        guard isPlayback, !isClosed else { return }
        let clips = importedClip.map { [$0.url] } ?? engine.draft?.segments.map(\.url) ?? []
        guard !clips.isEmpty else { return }
        let window = trimWindow
        let look = look
        // video-polish D9: Review plays once and stops at the end; Trim keeps looping its window.
        player.loops = phase == .trim
        player.onEnd = { [weak self] in self?.reviewEnded() }
        reviewPlaying = player.autoplays
        reviewElapsed = 0
        player.show(layers: layers)
        playerWork = Task { [player, report] in
            do {
                try await player.load(clips: clips, window: window, look: look)
                // Dragged while it loaded.
                if !Task.isCancelled, let trimWindow, trimWindow != window { player.move(to: trimWindow) }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled { report(error, "Couldn't play this video") }
            }
        }
    }

    private func stopPlaying() {
        playerWork?.cancel()
        playerWork = nil
        player.stop()
        reviewPlaying = false
        reviewElapsed = 0
    }

    /// The length Review's scrub bar spans: the trim window, the import, or the takes.
    var reviewDuration: TimeInterval {
        if let trimWindow { return trimWindow.upperBound - trimWindow.lowerBound }
        return importedClip?.duration ?? timeline.total
    }

    /// A tap on Review's video: plays or pauses; at the end, plays from the start (video-polish D9).
    func reviewTapped() {
        guard phase == .review, editor == nil else { return }
        if reviewPlaying {
            player.pause()
            reviewPlaying = false
        } else {
            player.play()
            reviewPlaying = true
        }
    }

    /// The scrub bar moved the playhead.
    func reviewSeek(to seconds: TimeInterval) {
        guard phase == .review else { return }
        let clamped = min(max(seconds, 0), reviewDuration)
        player.seek(to: clamped)
        reviewElapsed = clamped
    }

    /// Held while scrubbing; playback resumes as it was on release (video-polish D9).
    func setReviewScrubbing(_ on: Bool) {
        guard phase == .review, on != reviewScrubbing else { return }
        reviewScrubbing = on
        if on {
            playingBeforeScrub = reviewPlaying
            if reviewPlaying { player.pause(); reviewPlaying = false }
        } else if playingBeforeScrub {
            player.play()
            reviewPlaying = true
        }
    }

    /// The scrub bar follows the player while Review plays.
    func reviewTick() {
        guard phase == .review, reviewPlaying, !reviewScrubbing else { return }
        reviewElapsed = player.currentTime
    }

    private func reviewEnded() {
        reviewPlaying = false
        reviewElapsed = reviewDuration
    }

    func requestRetake() {
        guard phase == .review, !isSaving else { return }
        confirm = .retake
    }

    /// Discards everything and returns to the camera.
    func retakeConfirmed() {
        confirm = nil
        guard phase == .review, !isSaving, !isClosed else { return }
        returnToCamera()
    }

    private func returnToCamera() {
        stopPlaying()
        dropImport()
        layers = []
        transcript = nil
        timeline = timeline.withoutSegments
        recorded = 0
        teleprompterShift = 0
        phase = .ready
        perform { [self] in
            await engine.stopSegment()
            engine.discardDraft()
        }
        prepare()
    }

    // MARK: Edit (video-editor D7, D16, D19, D23)

    /// Opens the editor over Review on the draft's edit; a failure is reported and Review plays on.
    func editTapped() async {
        guard canEdit, !isClosed, !isOpeningEditor else { return }
        isOpeningEditor = true
        backgroundedWhileOpening = false
        defer { isOpeningEditor = false }
        await settled()
        guard canEdit, !isClosed else { return }
        stopPlaying()
        do {
            let draft = try draftToEdit()
            let clip = VideoEditorModel.Clip(
                urls: draft.segments.map(\.url), window: trimWindow,
                duration: trimWindow.map { $0.upperBound - $0.lowerBound } ?? draft.segments.reduce(0) { $0 + $1.duration },
                frame: .zero, look: look)
            let opened = try await makeEditor(clip, layers, transcript) { [weak self] layers, transcript in
                self?.editorSaved(layers, transcript)
            }
            // Retake, Save or Close may have landed while the editor was being made: it is not wanted then.
            guard phase == .review, !isClosed, !isSaving else { return }
            opened.onFinished = { [weak self] layers in self?.editorFinished(layers) }
            editor = opened
            opened.open()
            if backgroundedWhileOpening { opened.backgrounded() }
        } catch {
            if phase == .review, !isClosed, !isSaving { startPlaying() }
            report(error, "Couldn't open the editor")
        }
    }

    /// The editor's host has taken it off the screen.
    func editorHidden() {
        editor = nil
    }

    /// An import has no draft until its first edit (D19).
    private func draftToEdit() throws -> VideoDraft {
        if let importedClip, engine.draft?.source != .imported {
            // What is left of a recording with no clips: an import is only taken then.
            engine.discardDraft()
            try engine.adopt(imported: importedClip.url, duration: importedClip.duration, window: trimWindow, settings: draftSettings)
            if let segment = engine.draft?.segments.first {
                self.importedClip = VideoImportFlow.Clip(url: segment.url, duration: segment.duration)
            }
        }
        guard let draft = engine.draft else { throw VideoDraftError.noDraft }
        return draft
    }

    private func editorSaved(_ layers: [VideoLayer], _ transcript: VideoTranscript?) {
        self.layers = layers
        self.transcript = transcript
        do {
            try engine.save(layers: layers, transcript: transcript)
        } catch {
            // Recovered: memory keeps the edit, and Save writes it again and reports a failure (D28).
            Log.media.error("video edit not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func editorFinished(_ layers: [VideoLayer]) {
        self.layers = layers
        startPlaying()
    }

    /// Returns once the player has loaded what it was last given.
    func playerSettled() async {
        await playerWork?.value
    }

    // MARK: Save (D9)

    /// Closes the recorder once the recording is safely handed over, and returns when its video is in
    /// the upload queue, or has failed to get there. From Review in the + menu's recorder it opens the naming page
    /// instead, and returns once the save has started (D2, D7, D14).
    func save() async {
        guard !isSaving, !isClosed, phase == .review || screenState.canFinish else { return }
        let names = entry == .plusMenu && phase == .review
        isSaving = true
        defer { isSaving = false }
        await settled()
        guard !isClosed else { return }
        if names {
            // D13: an import is a draft before the save starts, so Back has a clip to return to.
            do { if importedClip != nil { _ = try draftToEdit() } } catch {
                report(error, "Couldn't save your video")
                return
            }
        }
        guard let clip = clipToSave else { return }
        let work: Task<Void, Never>
        do {
            if case .draft = clip { try engine.save(layers: layers, transcript: transcript) }
            work = try saver.start(
                VideoSave(entry: entry, source: importedClip == nil ? .recording : .imported, filter: filter,
                          strength: Double(filterStrength), window: trimWindow, namingHold: names ? true : nil),
                of: savedClip(clip))
        } catch {
            report(error, "Couldn't save your video")
            return
        }
        if names, case let .draft(draft) = clip {
            stopPlaying()
            openNaming(localId: draft.id.uuidString)
            return
        }
        importedClip = nil
        isClosed = true
        stopPlaying()
        perform { [self] in await engine.close() }
        onFinished(entry)
        await work.value
    }

    // MARK: Naming (video-naming D2, D8, D13)

    private func openNaming(localId: String) {
        let saver = saver
        let opened = VideoNamingModel(
            titlePlaceholder: saver.automaticTitle(localId) ?? "Video",
            transcript: { await saver.namingTranscript(localId)?.text },
            suggest: suggest,
            save: { [weak self] title, description in self?.finishNaming(localId, title: title, description: description) ?? false },
            back: { [weak self] in self?.cancelNaming(localId) },
            onUnauthorized: onUnauthorized)
        naming = opened
        namingLocalId = localId
        phase = .naming
        opened.open()
    }

    /// The check: the details go with the video, then the recorder closes (D13).
    private func finishNaming(_ localId: String, title: String, description: String) -> Bool {
        guard phase == .naming, !isClosed else { return false }
        do {
            try saver.finishNaming(localId, title: title, description: description)
        } catch {
            report(error, "Couldn't save your video")
            return false
        }
        closeAfterNaming()
        return true
    }

    /// Back: nothing is saved and Review plays on, as it was (D2).
    private func cancelNaming(_ localId: String) {
        guard phase == .naming, !isClosed else { return }
        do {
            try saver.cancelNaming(localId)
        } catch {
            report(error, "Couldn't go back")
            return
        }
        phase = .review
        startPlaying()
    }

    /// The app went to the background or the recorder was closed: the video keeps "Video N" and the recorder closes (D8).
    private func leaveNaming() {
        guard !isClosed, let naming, let localId = namingLocalId else { return }
        naming.leave()
        do {
            try saver.finishNaming(localId, title: "", description: "")
        } catch {
            // Recovered: the video stays held and the next launch ends the hold as "Video N".
            Log.media.error("video naming not ended: \(error.localizedDescription, privacy: .public)")
        }
        closeAfterNaming()
    }

    private func closeAfterNaming() {
        importedClip = nil
        isClosed = true
        perform { [self] in await engine.close() }
        onFinished(entry)
    }

    /// The naming page's host has taken it off the screen.
    func namingHidden() {
        naming = nil
    }

    @ObservationIgnored private var namingLocalId: String?

    private var clipToSave: VideoClip? {
        if let importedClip {
            if let draft = engine.draft, draft.source == .imported { return .draft(draft) }
            return .file(importedClip.url, duration: importedClip.duration)
        }
        guard let draft = engine.draft, !draft.segments.isEmpty else { return nil }
        return .draft(draft)
    }

    /// The draft as the engine holds it once the edit is written again.
    private func savedClip(_ clip: VideoClip) -> VideoClip {
        if case .draft = clip, let draft = engine.draft { return .draft(draft) }
        return clip
    }

    // MARK: Engine

    private func prepare() {
        perform { [self] in
            guard !isClosed else { return }
            do {
                try await engine.prepare()
            } catch {
                report(error, "Couldn't open the camera")
                return
            }
            if let deniedPhase {
                cancelPreRoll()
                if phase == .ready || phase == .paused { phase = deniedPhase }
            } else if phase == .permissionDenied {
                phase = idlePhase
            }
        }
    }

    private func applyFilter() {
        engine.previewFilter = filter.previewFilter(strength: look.strength)
        player.show(look)
    }

    private var look: VideoLook { VideoLook(filter: filter, strength: Double(filterStrength) / 100) }

    private func saveChoices() {
        engine.save(settings: draftSettings)
    }

    private var draftSettings: VideoDraftSettings {
        VideoDraftSettings(lengthSeconds: timeline.lengthSeconds,
                           filter: filter == .normal ? nil : filter.rawValue,
                           filterStrength: Double(filterStrength),
                           entry: entry == .plusMenu ? nil : entry)
    }

    /// Runs engine work after all the work asked for before it.
    private func perform(_ work: @escaping @MainActor () async -> Void) {
        let previous = engineWork
        pendingWork += 1
        engineWork = Task {
            await previous?.value
            await work()
            pendingWork -= 1
        }
    }

    /// Returns once the engine has done everything asked of it so far.
    func settled() async {
        await engineWork?.value
    }
}

// MARK: - The screen's inputs

extension VideoRecorderModel {
    func viewState(layout: VideoRecorderScreen.State.Layout) -> VideoRecorderScreen.State {
        let shown = screenState
        var view = VideoRecorderScreen.State(layout: layout)
        switch shown.phase {
        case .ready: view.phase = .ready
        case let .preRoll(numeral): view.phase = .preRoll; view.countdownNumeral = numeral
        case .recording: view.phase = .recording
        case let .endCountdown(numeral): view.phase = .endCountdown; view.countdownNumeral = numeral
        case .paused: view.phase = .paused
        case .permissionDenied: view.phase = .permissionDenied
        case .review: view.phase = .review
        case .trim: view.phase = .trim
        case .naming: view.phase = .review // the page over it is the host's
        }
        view.segments = shown.segments
        view.liveDuration = shown.liveDuration
        view.length = Double(shown.length)
        view.countdownValue = shown.preRoll == .off ? "" : "\(shown.preRoll.seconds)s"
        view.countdownSound = countdownSound
        view.filterLook = shown.filter.name
        view.strength = shown.filterStrength
        view.teleprompterOn = shown.teleprompterOn
        view.script = shown.script
        view.speed = shown.speed
        view.textSize = TeleprompterBand.TextSize.allCases[shown.textSizeStep - 1].label
        view.lengthMode = lengthMode.rawValue
        view.endCountdown = endCountdownSeconds
        if lengthMode == .any { view.length = Double(RecordingTimeline.maxLength) }
        view.reviewPlaying = reviewPlaying
        view.reviewElapsed = reviewElapsed
        view.reviewDuration = reviewDuration
        view.reviewScrubbing = reviewScrubbing
        return view
    }

    func pickFilter(named name: String) {
        pickFilter(VideoFilter.allCases.first { $0.name == name } ?? .normal)
    }

    func setTextSize(named label: String) {
        guard let index = TeleprompterBand.TextSize.allCases.firstIndex(where: { $0.label == label }) else { return }
        setTextSize(step: index + 1)
    }
}
