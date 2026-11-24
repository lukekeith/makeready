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
    /// Save was tapped and the recorder is done (D9).
    @ObservationIgnored var onFinished: (VideoRecorderEntry) -> Void = { _ in }
    /// The recorder closed with nothing saved.
    @ObservationIgnored var onDiscarded: () -> Void = {}

    private var timeline: RecordingTimeline
    /// Total recorded time, the segment in progress included.
    private var recorded: TimeInterval = 0
    private var preRoll: PreRoll
    private var filter: VideoFilter = .normal
    private var filterStrength = 100
    private var teleprompterOn = false
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

    init(entry: VideoRecorderEntry, engine: VideoRecorderCapturing, settings: RecorderSettings,
         player: VideoReviewPlaying, saver: VideoSaving, recoverDraft: @escaping () -> VideoDraft?, beep: @escaping (Double) -> Void,
         report: @escaping (Error, String) -> Void, loadNotes: @escaping () async throws -> Void,
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
        timeline = RecordingTimeline(lengthSeconds: settings.length)
        preRoll = settings.preRoll
        script = settings.script
        speed = settings.speedStep
        textSizeStep = settings.sizeStep
        engine.onInterrupted = { [weak self] in self?.interrupted() }
    }

    // MARK: Published

    var displayLayer: CALayer { engine.displayLayer }

    var playerLayer: CALayer { player.layer }

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
        case .ready, .preRoll, .paused, .permissionDenied, .review, .trim: false
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
            timeline = RecordingTimeline(lengthSeconds: draft.settings.lengthSeconds)
            filter = draft.settings.filter.flatMap(VideoFilter.init(rawValue:)) ?? .normal
            filterStrength = Int(draft.settings.filterStrength)
            syncTimeline()
            phase = idlePhase
        }
        applyFilter()
        prepare()
    }

    /// Back from Settings the camera may be allowed now (D19); back in Review the video plays on.
    func becameActive() {
        guard opened, !isClosed else { return }
        switch phase {
        case .permissionDenied: prepare()
        case .review, .trim: player.play()
        case .ready, .preRoll, .recording, .endCountdown, .paused: break
        }
    }

    /// The engine ends a segment itself (D26); a countdown has no segment yet.
    func backgrounded() {
        cancelPreRoll()
    }

    /// Asks first when something would be lost (D9).
    func closeTapped() {
        guard !isSaving, !isClosed else { return }
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
        case .permissionDenied, .review, .trim:
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
        recorded = min(total, Double(timeline.lengthSeconds))
        guard !timeline.shouldAutoStop(atRecorded: recorded) else {
            endSegment()
            openReview()
            return
        }
        let next: Phase = timeline.endCountdown(atRecorded: recorded).map(Phase.endCountdown) ?? .recording
        if phase != next { phase = next }
    }

    // MARK: Rail (D1)

    /// Length, Filters and Teleprompter open their own panels on the screen.
    func rail(_ tool: RailTool.Tool) {
        switch tool {
        case .flip:
            engine.flip()
        case .countdown:
            let choices = PreRoll.allCases
            let index = choices.firstIndex(of: preRoll) ?? 0
            preRoll = choices[(index + 1) % choices.count]
            settings.preRoll = preRoll
        case .length, .filters, .edit:
            break
        case .teleprompter:
            teleprompterOn = true
        }
    }

    /// Ignored once a segment exists (D3).
    func setLength(_ seconds: TimeInterval) {
        guard phase == .ready, timeline.canChangeLength else { return }
        timeline.setLength(Int(seconds))
        settings.length = timeline.lengthSeconds
    }

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
        teleprompterOn = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        case .preRoll, .recording, .endCountdown, .permissionDenied, .review, .trim:
            break
        }
    }

    private func syncTimeline() {
        guard let draft = engine.draft else { return }
        var synced = RecordingTimeline(lengthSeconds: timeline.lengthSeconds)
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
        timeline = RecordingTimeline(lengthSeconds: timeline.lengthSeconds)
        recorded = 0
        teleprompterShift = 0
        phase = .ready
        perform { [self] in
            await engine.stopSegment()
            engine.discardDraft()
        }
        prepare()
    }

    /// Returns once the player has loaded what it was last given.
    func playerSettled() async {
        await playerWork?.value
    }

    // MARK: Save (D9)

    /// Closes the recorder once the recording is safely handed over, and returns when its video is in
    /// the upload queue, or has failed to get there.
    func save() async {
        guard !isSaving, !isClosed, phase == .review || screenState.canFinish else { return }
        isSaving = true
        defer { isSaving = false }
        await settled()
        guard !isClosed, let clip = clipToSave else { return }
        let work: Task<Void, Never>
        do {
            work = try saver.start(
                VideoSave(entry: entry, source: importedClip == nil ? .recording : .imported, filter: filter,
                          strength: Double(filterStrength), window: trimWindow), of: clip)
        } catch {
            report(error, "Couldn't save your video")
            return
        }
        importedClip = nil
        isClosed = true
        stopPlaying()
        perform { [self] in await engine.close() }
        onFinished(entry)
        await work.value
    }

    private var clipToSave: VideoClip? {
        if let importedClip { return .file(importedClip.url, duration: importedClip.duration) }
        guard let draft = engine.draft, !draft.segments.isEmpty else { return nil }
        return .draft(draft)
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
        engine.save(settings: VideoDraftSettings(lengthSeconds: timeline.lengthSeconds,
                                                 filter: filter == .normal ? nil : filter.rawValue,
                                                 filterStrength: Double(filterStrength),
                                                 entry: entry == .plusMenu ? nil : entry))
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
        }
        view.segments = shown.segments
        view.liveDuration = shown.liveDuration
        view.length = Double(shown.length)
        view.countdownValue = shown.preRoll == .off ? "" : "\(shown.preRoll.seconds)s"
        view.filterLook = shown.filter.name
        view.strength = shown.filterStrength
        view.teleprompterOn = shown.teleprompterOn
        view.script = shown.script
        view.speed = shown.speed
        view.textSize = TeleprompterBand.TextSize.allCases[shown.textSizeStep - 1].label
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
