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

    func attach(title: String) -> VideoAttach? {
        switch entry {
        case .plusMenu: nil
        case let .lesson(versionId, activityId): VideoAttach(versionId: versionId, activityId: activityId, title: title)
        }
    }
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
    func enqueue(_ video: ExportedVideo, title: String, source: VideoSource, attach: VideoAttach?,
                 transcriptHold: TimeInterval) throws -> VideoQueueItem
    func supplyTranscript(_ transcript: VideoTranscript?, forLocalId localId: String)
}

extension VideoUploadController: VideoSaveQueue {
    func enqueue(_ video: ExportedVideo, title: String, source: VideoSource, attach: VideoAttach?,
                 transcriptHold: TimeInterval) throws -> VideoQueueItem {
        try enqueue(video, title: title, source: source, transcript: nil, attach: attach, transcriptHold: transcriptHold)
    }
}

@MainActor
final class VideoSaver: VideoSaving {
    /// The clips, the window, the filter, its strength (0–1) and the destination.
    typealias Export = @MainActor ([URL], ClosedRange<Double>?, VideoFilter, Double, URL) async throws -> ExportedVideo

    private static let exportName = "export.mp4"

    private let drafts: VideoDraftStore
    private let queue: VideoSaveQueue
    private let nextTitle: () -> String
    private let report: (Error, String, @escaping () -> Void) -> Void
    private let export: Export
    private let transcribe: @MainActor (URL, Duration) async -> VideoTranscript?
    private let waitForForeground: @MainActor () async -> Bool
    private var jobs: [UUID: Task<Void, Never>] = [:]
    private var isCancelled = false

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
    }

    /// Returns once nothing is being saved.
    func settled() async {
        for job in Array(jobs.values) { await job.value }
    }

    private func run(_ save: VideoSave, _ draft: VideoDraft) -> Task<Void, Never> {
        if let job = jobs[draft.id] { return job }
        guard !isCancelled, drafts.exists(draft) else { return Task {} }
        let job = Task {
            await work(save, draft)
            jobs[draft.id] = nil
        }
        jobs[draft.id] = job
        return job
    }

    private func work(_ save: VideoSave, _ draft: VideoDraft) async {
        let time = BackgroundTime(name: "video-save")
        defer { time.end() }
        let item: VideoQueueItem
        let timeout: TimeInterval
        do {
            let video = try await export(draft.segments.map(\.url), save.window, save.filter, save.strength / 100,
                                         draft.folder.appendingPathComponent(Self.exportName))
            try Task.checkCancellation()
            let title = nextTitle()
            timeout = video.durationSeconds
            item = try queue.enqueue(video, title: title, source: save.source, attach: save.attach(title: title),
                                     transcriptHold: timeout)
            drafts.discard(draft)
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
        let transcript = await transcribe(item.fileURL, .seconds(timeout))
        guard !Task.isCancelled else { return }
        queue.supplyTranscript(transcript, forLocalId: item.localId)
    }

    // MARK: Live

    static func liveExport(_ clips: [URL], window: ClosedRange<Double>?, filter: VideoFilter, strength: Double,
                           to destination: URL) async throws -> ExportedVideo {
        let range = window.map {
            CMTimeRange(start: CMTime(seconds: $0.lowerBound, preferredTimescale: 600),
                        end: CMTime(seconds: $0.upperBound, preferredTimescale: 600))
        }
        return try await VideoExporter.export(segments: clips, timeRange: range, filter: filter, strength: strength, to: destination)
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
