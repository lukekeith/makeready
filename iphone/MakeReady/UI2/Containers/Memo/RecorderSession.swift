//
//  RecorderSession.swift
//  MakeReady
//
//  memo-screens D3, D7, D11: one recording's logic over `MemoRecorderEngine`, for the recorder
//  sheet. It starts the engine with no record tap, stamps the start time, hands the finished
//  result to the upload queue and publishes how the recording ended. Dragging the sheet only
//  moves `expansion`; it never reaches the engine.
//

import Foundation

@MainActor @Observable
final class RecorderSession {
    /// How the recording ended; `nil` while it is in progress.
    enum Outcome: Equatable {
        case saved(localId: String)
        case discarded
        case failed
    }

    let title: String
    private(set) var expansion: Double = 0
    private(set) var menu: RecorderExpandedView.Menu = .none
    private(set) var startTime = ""
    private(set) var outcome: Outcome?

    @ObservationIgnored private let engine: MemoRecorderEngine
    @ObservationIgnored private let enqueue: (RecordingResult) throws -> MemoQueueItem
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var began = false
    /// Set synchronously when finish or discard starts, so a second tap or a racing one is a no-op.
    @ObservationIgnored private var ending = false

    init(engine: MemoRecorderEngine, title: String, enqueue: @escaping (RecordingResult) throws -> MemoQueueItem,
         now: @escaping () -> Date, calendar: Calendar) {
        self.engine = engine
        self.title = title
        self.enqueue = enqueue
        self.now = now
        self.calendar = calendar
        engine.onAutoStop = { [weak self] result in self?.save(result) }
    }

    // MARK: Published from the engine

    var phase: RecorderExpandedView.Phase { Self.phase(state: engine.state, error: engine.lastError) }
    var elapsed: TimeInterval { engine.elapsed }
    var samples: [Float] { engine.samples }

    static func phase(state: RecorderState, error: MemoEngineError?) -> RecorderExpandedView.Phase {
        if state == .paused { return .paused }
        if error == .micPermissionDenied { return .micDenied }
        return .recording
    }

    // MARK: Recording

    /// Prepares and starts at once, with no record tap (D3). A denied microphone leaves the engine
    /// idle with `micPermissionDenied`, which `phase` shows; nothing is created or enqueued.
    func begin() async {
        guard !began else { return }
        began = true
        do {
            try await engine.prepare(title: title)
            try await engine.start()
            startTime = format(now())
        } catch MemoEngineError.micPermissionDenied {
            // The mic-denied message (Open Settings, Close) lives in the expanded sheet, and the drag is
            // off in that phase — so the session opens it; left compact, the sheet has no way out.
            expansion = 1
            return
        } catch is CancellationError {
            return
        } catch {
            // The engine already ended itself and removed its partial .caf and draft manifest.
            fail(error)
        }
    }

    func pause() {
        engine.pause()
    }

    func resume() {
        do {
            try engine.resume()
        } catch {
            Log.memo.error("recording not resumed: \(error.localizedDescription)")
        }
    }

    /// Stop and Done both end here (D3): the engine's result goes to the queue and the recording is saved.
    func finish() async {
        guard outcome == nil, !ending else { return }
        ending = true
        do {
            save(try await engine.stop())
        } catch is CancellationError {
            // Nothing to stop: `engineFailed` or `onAutoStop` has already ended (or will end) the session.
            ending = false
            return
        } catch {
            fail(error)
        }
    }

    /// True once the engine has stopped itself after a failed write, with nothing yet reported.
    var engineFailed: Bool { outcome == nil && engine.state == .idle && engine.lastError == .writeFailed }

    func failIfEngineFailed() {
        if engineFailed { fail(MemoEngineError.writeFailed) }
    }

    // MARK: Sheet

    func settle(_ expansion: Double) {
        self.expansion = expansion
    }

    func openMenu() {
        menu = .actions
    }

    func requestDiscard() {
        menu = .discardConfirm
    }

    func dismissMenu() {
        menu = .none
    }

    /// Throws the recording away (D7): nothing is enqueued.
    func confirmDiscard() async {
        guard outcome == nil, !ending else { return }
        ending = true
        await engine.discard()
        menu = .none
        outcome = .discarded
    }

    /// The mic-denied close: nothing was recorded, so nothing is kept.
    func close() {
        guard outcome == nil else { return }
        outcome = .discarded
    }

    // MARK: Helpers

    private func save(_ result: RecordingResult) {
        guard outcome == nil else { return }
        do {
            outcome = .saved(localId: try enqueue(result).localId)
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        guard outcome == nil else { return }
        AppState.shared.recordError(error, context: "RecorderSession", surface: true,
                                    friendlyMessage: "Couldn't save the recording")
        outcome = .failed
    }

    private static let startTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private func format(_ date: Date) -> String {
        let formatter = Self.startTimeFormatter
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        return formatter.string(from: date)
    }
}
