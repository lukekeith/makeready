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
    /// The leader's description once naming has ended; nil when none (D4).
    var description: String?
    /// True while the naming page is open: the queue holds the video until the check (D13).
    var namingHold: Bool?

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
    /// The title a held save would get unnamed ("Video N"); nil when `localId` is not being named.
    func automaticTitle(_ localId: String) -> String?
    /// The kept clip's words: the editor's with its corrections, else the one transcription of the clip. Nil when
    /// there are none (D5, D15).
    func namingTranscript(_ localId: String) async -> VideoTranscript?
    /// The check: trims both, saves under them and releases the hold. Throws with the hold kept.
    func finishNaming(_ localId: String, title: String, description: String) throws
    /// Back: no video is kept; the draft, its layers and its transcript stay as they were. Throws, changing nothing,
    /// when the save mark cannot be cleared.
    func cancelNaming(_ localId: String) throws
}

/// What the saver needs of `VideoUploadController`.
@MainActor
protocol VideoSaveQueue: AnyObject {
    /// With a `transcript` the video needs no hold; without one `transcriptHold` is how long to wait for it.
    func enqueue(_ video: ExportedVideo, localId: String, title: String, source: VideoSource, transcript: VideoTranscript?,
                 attach: VideoAttach?, transcriptHold: TimeInterval?, description: String?,
                 namingHold: Bool) throws -> VideoQueueItem
    /// The item the queue holds under `localId`, if any.
    func queued(localId: String) -> VideoQueueItem?
    func supplyTranscript(_ transcript: VideoTranscript?, forLocalId localId: String)
    /// Ends a naming hold with the leader's details; `title` nil keeps the item's. Throws when the manifest cannot be written.
    func endNamingHold(localId: String, title: String?, description: String?) throws
    /// The local ids still held for naming.
    var heldIds: [String] { get }
    func remove(localId: String) throws
}

extension VideoUploadController: VideoSaveQueue {
    func enqueue(_ video: ExportedVideo, localId: String, title: String, source: VideoSource, transcript: VideoTranscript?,
                 attach: VideoAttach?, transcriptHold: TimeInterval?, description: String?,
                 namingHold: Bool) throws -> VideoQueueItem {
        try enqueue(video, localId: localId, title: Optional(title), source: source, transcript: transcript, attach: attach,
                    transcriptHold: transcriptHold, description: description, namingHold: namingHold)
    }
}

@MainActor
@Observable
final class VideoSaver: VideoSaving {
    /// The clips, the window, the filter, its strength (0–1), the layers and the destination.
    typealias Export = @MainActor ([URL], ClosedRange<Double>?, VideoFilter, Double, [VideoLayer], URL) async throws -> ExportedVideo
    /// The clips, the window kept and the timeout; the shape of `VideoTranscriber.transcribe(clips:window:timeout:)`.
    typealias TranscribeClips = @MainActor ([URL], ClosedRange<Double>?, Duration) async -> VideoTranscript?

    /// A save whose naming page has been opened (D13); it lasts until naming, the enqueue and the clip's
    /// transcription have all ended, then the draft goes.
    private struct Naming {
        let draft: VideoDraft
        let automaticTitle: String?
        /// False once the check has been made.
        var open = true
        /// The queue has the video.
        var enqueued = false
        /// The kept clip's transcription (D15) is still running; there is none when the editor had a transcript.
        var clipPending = false
        var clip: Task<VideoTranscript?, Never>?
        /// What the transcription landed with, once it has.
        var landed: VideoTranscript?
    }

    private static let exportName = "export.mp4"

    private let drafts: VideoDraftStore
    private let queue: VideoSaveQueue
    private let nextTitle: () -> String
    private let report: (Error, String, @escaping () -> Void) -> Void
    private let export: Export
    private let transcribe: @MainActor (URL, Duration) async -> VideoTranscript?
    private let transcribeClips: TranscribeClips
    private let waitForForeground: @MainActor () async -> Bool
    @ObservationIgnored private var jobs: [UUID: Task<Void, Never>] = [:]
    /// Which run `jobs` holds, so a job that ends late never removes its successor.
    @ObservationIgnored private var tokens: [UUID: UUID] = [:]
    /// A cancelled job still ending; a save started again waits for it.
    @ObservationIgnored private var retired: [UUID: (token: UUID, task: Task<Void, Never>)] = [:]
    /// The save mark as it is now, which a retry and the enqueue use (D13).
    @ObservationIgnored private var marks: [UUID: VideoSave] = [:]
    @ObservationIgnored private var namings: [UUID: Naming] = [:]
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
         transcribeClips: @escaping TranscribeClips = {
             await VideoTranscriber().transcribe(clips: $0, window: $1, timeout: $2)
         },
         waitForForeground: @escaping @MainActor () async -> Bool = VideoSaver.liveWaitForForeground) {
        self.drafts = drafts
        self.queue = queue
        self.nextTitle = nextTitle
        self.report = report
        self.export = export
        self.transcribe = transcribe
        self.transcribeClips = transcribeClips
        self.waitForForeground = waitForForeground
    }

    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never> {
        let save = titled(save)
        switch clip {
        case let .draft(draft):
            try drafts.markSaving(save, in: draft)
            return launch(save, draft)
        case let .file(url, duration):
            let draft = drafts.begin()
            do {
                try drafts.markSaving(save, in: draft)
                return launch(save, try drafts.finalize(segment: url, duration: duration, in: draft))
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

    /// Launch: finishes every save a kill cut off. A held save, and any queue item still held that this saver did
    /// not start, ends its hold and goes up as "Video N" (D8, D13).
    func resume() {
        for cut in drafts.saving() where namings[cut.draft.id] == nil {
            var save = cut.save
            if save.namingHold == true {
                save.namingHold = nil
                release(cut.draft.id.uuidString)
                do {
                    try drafts.markSaving(save, in: cut.draft)
                } catch {
                    // Recovered: the next launch ends the hold again.
                    Log.media.error("video save mark not rewritten: \(error.localizedDescription, privacy: .public)")
                }
            }
            _ = run(save, cut.draft)
        }
        for localId in queue.heldIds where !namings.keys.contains(where: { $0.uuidString == localId }) { release(localId) }
    }

    /// Sign-out and environment switch. The recordings stay, for the next `resume`.
    func cancel() {
        isCancelled = true
        jobs.values.forEach { $0.cancel() }
        namings.values.forEach { $0.clip?.cancel() }
        namings = [:]
        marks = [:]
        saving = []
    }

    /// Deletes a video before the queue has it, recording included. False when it is not being saved.
    func remove(localId: String) -> Bool {
        guard saving.contains(where: { $0.localId == localId }) else { return false }
        for cut in drafts.saving() where cut.draft.id.uuidString == localId {
            jobs[cut.draft.id]?.cancel()
            namings[cut.draft.id]?.clip?.cancel()
            namings[cut.draft.id] = nil
            marks[cut.draft.id] = nil
            drafts.discard(cut.draft)
        }
        saving.removeAll { $0.localId == localId }
        return true
    }

    // MARK: Naming (D13, D15)

    func automaticTitle(_ localId: String) -> String? {
        UUID(uuidString: localId).flatMap { namings[$0]?.automaticTitle }
    }

    func namingTranscript(_ localId: String) async -> VideoTranscript? {
        guard let id = UUID(uuidString: localId), let naming = namings[id] else { return nil }
        let edit = drafts.current(naming.draft) ?? naming.draft
        let heard: VideoTranscript?
        if let edited = edit.transcript {
            heard = VideoCaptions.corrected(edited, with: edit.layers)
        } else {
            heard = await naming.clip?.value
        }
        return Self.spoken(heard)
    }

    func finishNaming(_ localId: String, title: String, description: String) throws {
        guard let id = UUID(uuidString: localId), var naming = namings[id], naming.open, let was = marks[id] else { return }
        var mark = was
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { mark.title = name }
        mark.description = details.isEmpty ? nil : details
        mark.namingHold = nil
        try drafts.markSaving(mark, in: naming.draft)
        if naming.enqueued {
            do {
                try queue.endNamingHold(localId: localId, title: name.isEmpty ? nil : name, description: mark.description)
            } catch {
                do {
                    try drafts.markSaving(was, in: naming.draft)
                } catch {
                    Log.media.error("video save mark not restored: \(error.localizedDescription, privacy: .public)")
                }
                throw error
            }
        }
        marks[id] = mark
        naming.open = false
        namings[id] = naming
        if let title = mark.title, let row = saving.firstIndex(where: { $0.localId == localId }) {
            let old = saving[row]
            saving[row] = VideoSavingItem(localId: localId, title: title, durationSeconds: old.durationSeconds, savedAt: old.savedAt,
                                          attach: mark.attach(title: title))
        }
        settle(id)
    }

    func cancelNaming(_ localId: String) throws {
        guard let id = UUID(uuidString: localId), let naming = namings[id] else { return }
        try drafts.clearSaving(naming.draft)
        naming.clip?.cancel()
        if let job = jobs[id], let token = tokens[id] {
            job.cancel()
            retired[id] = (token, job)
            jobs[id] = nil
            tokens[id] = nil
        }
        if naming.enqueued {
            do {
                try queue.remove(localId: localId)
            } catch {
                // Silent: the queue no longer has it, which is what Back wants.
            }
        }
        namings[id] = nil
        marks[id] = nil
        saving.removeAll { $0.localId == localId }
    }

    /// Ends a queue item's hold as "Video N" (D8): the item keeps its own title.
    private func release(_ localId: String) {
        do {
            try queue.endNamingHold(localId: localId, title: nil, description: nil)
        } catch {
            // Recovered: the item stays held and the next launch ends it again.
            Log.media.error("video naming hold not ended: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func spoken(_ transcript: VideoTranscript?) -> VideoTranscript? {
        transcript.flatMap { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    /// Opens the naming of a held save and starts the one transcription of its clip when the editor made none (D15).
    private func open(_ save: VideoSave, _ draft: VideoDraft) {
        guard namings[draft.id] == nil else { return }
        var naming = Naming(draft: draft, automaticTitle: save.title)
        if (drafts.current(draft) ?? draft).transcript == nil {
            let kept = keptSeconds(save, draft)
            naming.clipPending = true
            naming.clip = Task {
                let heard = Self.spoken(await transcribeClips(draft.segments.map(\.url), save.window, .seconds(kept)))
                guard !Task.isCancelled else { return nil }
                landed(draft.id, heard)
                return heard
            }
        }
        namings[draft.id] = naming
    }

    /// The clip's words are in: they go along with the enqueue, or reach the item it already made.
    private func landed(_ id: UUID, _ transcript: VideoTranscript?) {
        guard var naming = namings[id] else { return }
        naming.clipPending = false
        naming.landed = transcript
        namings[id] = naming
        if naming.enqueued { queue.supplyTranscript(transcript, forLocalId: id.uuidString) }
        settle(id)
    }

    /// Once naming, the enqueue and the transcription (which reads the draft's files) have all ended, the draft goes.
    private func settle(_ id: UUID) {
        guard let naming = namings[id], !naming.open, naming.enqueued, !naming.clipPending else { return }
        drafts.discard(naming.draft)
        namings[id] = nil
        marks[id] = nil
    }

    private func keptSeconds(_ save: VideoSave, _ draft: VideoDraft) -> Double {
        save.window.map { $0.upperBound - $0.lowerBound } ?? draft.segments.reduce(0) { $0 + $1.duration }
    }

    private func titled(_ save: VideoSave) -> VideoSave {
        var save = save
        save.title = save.title ?? nextTitle()
        return save
    }

    /// Returns once nothing is being saved.
    func settled() async {
        for job in Array(jobs.values) { await job.value }
        for clip in namings.values.compactMap(\.clip) { _ = await clip.value }
    }

    private func launch(_ save: VideoSave, _ draft: VideoDraft) -> Task<Void, Never> {
        if save.namingHold == true { open(save, draft) }
        return run(save, draft)
    }

    private func run(_ save: VideoSave, _ draft: VideoDraft) -> Task<Void, Never> {
        if let job = jobs[draft.id] { return job }
        guard !isCancelled, drafts.exists(draft) else { return Task {} }
        let save = titled(save)
        marks[draft.id] = save
        list(save, draft)
        // A job Back cancelled may still be ending: this one starts after it.
        let predecessor = retired[draft.id]?.task
        let token = UUID()
        let job = Task {
            await predecessor?.value
            if !Task.isCancelled { await work(save, draft) }
            if tokens[draft.id] == token {
                jobs[draft.id] = nil
                tokens[draft.id] = nil
            } else if retired[draft.id]?.token == token {
                retired[draft.id] = nil
            }
        }
        jobs[draft.id] = job
        tokens[draft.id] = token
        retired[draft.id] = nil
        return job
    }

    private func list(_ save: VideoSave, _ draft: VideoDraft) {
        let localId = draft.id.uuidString
        guard let title = save.title, !saving.contains(where: { $0.localId == localId }) else { return }
        saving.append(VideoSavingItem(localId: localId, title: title, durationSeconds: keptSeconds(save, draft), savedAt: Date(),
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
                // The mark as it is now: naming may have ended during the export (D13).
                let latest = marks[draft.id] ?? save
                let title = latest.title ?? nextTitle()
                timeout = video.durationSeconds
                let naming = namings[draft.id]
                var spoken = edit.transcript.map { VideoCaptions.corrected($0, with: edit.layers) }
                if spoken == nil { spoken = naming?.landed }
                let waits = spoken == nil && (naming == nil || naming?.clipPending == true)
                item = try queue.enqueue(video, localId: draft.id.uuidString, title: title, source: latest.source, transcript: spoken,
                                         attach: latest.attach(title: title), transcriptHold: waits ? timeout : nil,
                                         description: latest.description, namingHold: latest.namingHold == true)
            }
            // A named save keeps its draft until naming and the clip's transcription have ended (D13, D15).
            if namings[draft.id] != nil {
                namings[draft.id]?.enqueued = true
            } else {
                drafts.discard(draft)
                marks[draft.id] = nil
            }
            saving.removeAll { $0.localId == item.localId }
        } catch {
            guard !Task.isCancelled else { return }
            time.end()
            if await waitForForeground() {
                // iOS stops an export in the background; nothing is lost, so it runs again.
                guard !Task.isCancelled else { return }
                await work(save, draft)
            } else {
                report(error, "Couldn't save your video") { [weak self] in
                    guard let self, let latest = self.marks[draft.id] else { return }
                    _ = self.run(latest, draft)
                }
            }
            return
        }
        // A named save's transcript came with the naming (D15); a held one never transcribes the video again.
        if namings[draft.id] != nil {
            settle(draft.id)
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
