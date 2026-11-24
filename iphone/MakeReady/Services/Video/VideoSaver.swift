//
//  VideoSaver.swift
//  MakeReady
//
//  What happens after Save (video-recorder D9, D10, D14): export, hand the video to the upload queue,
//  then its transcript. Owned by `AppState`, so it outlives the recorder. The draft is marked before
//  the recorder closes and kept until the queue has the video, so a kill resumes here at the next
//  launch (`resume`) and no recorder picks the draft up meanwhile.
//

import CoreMedia
import UIKit

/// A saved recording, as its draft keeps it until the queue has the video.
struct VideoSave: Codable, Equatable {
    let entry: VideoRecorderEntry
    let source: VideoSource
    let filter: VideoFilter
    /// 0–100 (D6).
    let strength: Double
    /// Seconds of the clips kept (D8); nil is all of them.
    let window: ClosedRange<Double>?
    /// Given when the save starts, and kept through a relaunch.
    var title: String?

    func attach(title: String) -> VideoAttach? {
        switch entry {
        case .plusMenu: nil
        case let .lesson(versionId, activityId): VideoAttach(versionId: versionId, activityId: activityId, title: title)
        }
    }
}

/// A saved video the upload queue does not have yet; its id is the queue item's to be.
struct VideoSavingItem: Equatable {
    let localId: String
    let title: String
    let durationSeconds: Double
    let savedAt: Date
    let attach: VideoAttach?
}

enum VideoClip {
    case draft(VideoDraft)
    /// An imported file, moved into a draft of its own.
    case file(URL, duration: TimeInterval)
}

/// What the recorder needs of `VideoSaver`.
@MainActor
protocol VideoSaving: AnyObject {
    /// Returns once the recording is safely marked; the work goes on in the task. Throws, changing
    /// nothing, when it cannot be marked.
    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never>
}

/// What the saver needs of `VideoUploadController`.
@MainActor
protocol VideoSaveQueue: AnyObject {
    /// With a `transcript` the video needs no hold; without one `transcriptHold` is how long to wait for it.
    func enqueue(_ video: ExportedVideo, localId: String, title: String, source: VideoSource, transcript: VideoTranscript?,
                 attach: VideoAttach?, transcriptHold: TimeInterval?) throws -> VideoQueueItem
    /// The item the queue holds under `localId`, if any.
    func queued(localId: String) -> VideoQueueItem?
    func supplyTranscript(_ transcript: VideoTranscript?, forLocalId localId: String)
}

extension VideoUploadController: VideoSaveQueue {
    func enqueue(_ video: ExportedVideo, localId: String, title: String, source: VideoSource, transcript: VideoTranscript?,
                 attach: VideoAttach?, transcriptHold: TimeInterval?) throws -> VideoQueueItem {
        try enqueue(video, localId: localId, title: Optional(title), source: source, transcript: transcript, attach: attach,
                    transcriptHold: transcriptHold)
    }
}

@MainActor
@Observable
final class VideoSaver: VideoSaving {
    /// The clips, the window, the filter, its strength (0–1), the layers and the destination.
    typealias Export = @MainActor ([URL], ClosedRange<Double>?, VideoFilter, Double, [VideoLayer], URL) async throws -> ExportedVideo

    private static let exportName = "export.mp4"

    private let drafts: VideoDraftStore
    private let queue: VideoSaveQueue
    private let nextTitle: () -> String
    private let report: (Error, String, @escaping () -> Void) -> Void
    private let export: Export
    private let transcribe: @MainActor (URL, Duration) async -> VideoTranscript?
    private let waitForForeground: @MainActor () async -> Bool
    @ObservationIgnored private var jobs: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var isCancelled = false

    /// Oldest save first (D12: a saved video shows at once). An item leaves as the queue takes it.
    private(set) var saving: [VideoSavingItem] = []

    /// `report`'s last argument is Retry. `waitForForeground` answers false at once in the foreground,
    /// else true once the app is back.
    init(drafts: VideoDraftStore, queue: VideoSaveQueue, nextTitle: @escaping () -> String,
         report: @escaping (Error, String, @escaping () -> Void) -> Void,
         export: @escaping Export = VideoSaver.liveExport,
         transcribe: @escaping @MainActor (URL, Duration) async -> VideoTranscript? = {
             await VideoTranscriber().transcribe(video: $0, timeout: $1)
         },
         waitForForeground: @escaping @MainActor () async -> Bool = VideoSaver.liveWaitForForeground) {
        self.drafts = drafts
        self.queue = queue
        self.nextTitle = nextTitle
        self.report = report
        self.export = export
        self.transcribe = transcribe
        self.waitForForeground = waitForForeground
    }

    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never> {
        let save = titled(save)
        switch clip {
        case let .draft(draft):
            try drafts.markSaving(save, in: draft)
            return run(save, draft)
        case let .file(url, duration):
            let draft = drafts.begin()
            do {
                try drafts.markSaving(save, in: draft)
                return run(save, try drafts.finalize(segment: url, duration: duration, in: draft))
            } catch {
                let moved = draft.folder.appendingPathComponent(url.lastPathComponent)
                if !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: moved.path) {
                    try FileManager.default.moveItem(at: moved, to: url)
                }
                drafts.discard(draft)
                throw error
            }
        }
    }

    /// Launch: finishes every save a kill cut off.
    func resume() {
        for cut in drafts.saving() { _ = run(cut.save, cut.draft) }
    }

    /// Sign-out and environment switch. The recordings stay, for the next `resume`.
    func cancel() {
        isCancelled = true
        jobs.values.forEach { $0.cancel() }
        saving = []
    }

    /// Deletes a video before the queue has it, recording included. False when it is not being saved.
    func remove(localId: String) -> Bool {
        guard saving.contains(where: { $0.localId == localId }) else { return false }
        for cut in drafts.saving() where cut.draft.id.uuidString == localId {
            jobs[cut.draft.id]?.cancel()
            drafts.discard(cut.draft)
        }
        saving.removeAll { $0.localId == localId }
        return true
    }

    private func titled(_ save: VideoSave) -> VideoSave {
        var save = save
        save.title = save.title ?? nextTitle()
        return save
    }

    /// Returns once nothing is being saved.
    func settled() async {
        for job in Array(jobs.values) { await job.value }
    }

    private func run(_ save: VideoSave, _ draft: VideoDraft) -> Task<Void, Never> {
        if let job = jobs[draft.id] { return job }
        guard !isCancelled, drafts.exists(draft) else { return Task {} }
        let save = titled(save)
        list(save, draft)
        let job = Task {
            await work(save, draft)
            jobs[draft.id] = nil
        }
        jobs[draft.id] = job
        return job
    }

    private func list(_ save: VideoSave, _ draft: VideoDraft) {
        let localId = draft.id.uuidString
        guard let title = save.title, !saving.contains(where: { $0.localId == localId }) else { return }
        let duration = save.window.map { $0.upperBound - $0.lowerBound } ?? draft.segments.reduce(0) { $0 + $1.duration }
        saving.append(VideoSavingItem(localId: localId, title: title, durationSeconds: duration, savedAt: Date(),
                                      attach: save.attach(title: title)))
    }

    private func work(_ save: VideoSave, _ draft: VideoDraft) async {
        let time = BackgroundTime(name: "video-save")
        defer { time.end() }
        // The edit is read from the manifest now, so a save resumed after a kill draws the same layers (D27).
        let edit = drafts.current(draft) ?? draft
        let item: VideoQueueItem
        let timeout: TimeInterval
        do {
            if let queued = queue.queued(localId: draft.id.uuidString) {
                // A kill came after the queue took the video: only its transcript is left to do.
                (item, timeout) = (queued, queued.durationSeconds)
            } else {
                let video = try await export(draft.segments.map(\.url), save.window, save.filter, save.strength / 100,
                                             edit.layers, draft.folder.appendingPathComponent(Self.exportName))
                try Task.checkCancellation()
                let title = save.title ?? nextTitle()
                timeout = video.durationSeconds
                let spoken = edit.transcript.map { VideoCaptions.corrected($0, with: edit.layers) }
                item = try queue.enqueue(video, localId: draft.id.uuidString, title: title, source: save.source, transcript: spoken,
                                         attach: save.attach(title: title), transcriptHold: spoken == nil ? timeout : nil)
            }
            drafts.discard(draft)
            saving.removeAll { $0.localId == draft.id.uuidString }
        } catch {
            guard !Task.isCancelled else { return }
            time.end()
            if await waitForForeground() {
                // iOS stops an export in the background; nothing is lost, so it runs again.
                guard !Task.isCancelled else { return }
                await work(save, draft)
            } else {
                report(error, "Couldn't save your video") { [weak self] in _ = self?.run(save, draft) }
            }
            return
        }
        // With the transcript already sent there is nothing to transcribe (D27).
        guard edit.transcript == nil else { return }
        let transcript = await transcribe(item.fileURL, .seconds(timeout))
        guard !Task.isCancelled else { return }
        queue.supplyTranscript(transcript, forLocalId: item.localId)
    }

    // MARK: Live

    static func liveExport(_ clips: [URL], window: ClosedRange<Double>?, filter: VideoFilter, strength: Double,
                           layers: [VideoLayer], to destination: URL) async throws -> ExportedVideo {
        let range = window.map {
            CMTimeRange(start: CMTime(seconds: $0.lowerBound, preferredTimescale: 600),
                        end: CMTime(seconds: $0.upperBound, preferredTimescale: 600))
        }
        return try await VideoExporter.export(segments: clips, timeRange: range, filter: filter, strength: strength, layers: layers, to: destination)
    }

    static func liveWaitForForeground() async -> Bool {
        let returns = NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification)
        guard UIApplication.shared.applicationState != .active else { return false }
        for await _ in returns { return true }
        return false
    }
}

/// Keeps the app running for a while after it leaves the foreground.
@MainActor
private final class BackgroundTime {
    private var task: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        task = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
