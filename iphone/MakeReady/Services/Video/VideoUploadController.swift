//
//  VideoUploadController.swift
//  MakeReady
//
//  The persistent per-user video upload queue (video-recorder D12, D18, D22, D23, D24). `enqueue`
//  moves an exported video, its poster and a JSON manifest into `directory` and never touches the
//  network. `processNext` runs the oldest item one stage further, persisting the manifest after
//  every stage, so a kill resumes where it stopped:
//
//      queued -> uploading   mint a Stream URL, persist its uid, stream the file
//             -> creating    POST /api/videos (a duplicate on retry answers 200 with the same row)
//             -> attaching   create or replace the lesson's video activity (only with `attach`)
//             -> processing  poll the Stream status, 15 tries 2 s apart
//             -> done        the files and manifest go
//
//  A stage names the last phase that finished. `flush` runs the queue serially with backoff, and is
//  triggered by enqueue, launch and the network coming back. Only this owner's folder is read.
//

import Foundation
import Network
import Observation
import UIKit

// MARK: - Seams

/// What one `processNext` pass did.
enum VideoUploadStep: Equatable {
    case idle
    case advanced
    case retryLater
    /// A 401: nothing backs off; the queue waits for the next sign-in.
    case paused
}

enum VideoUploadStage: String, Codable, Equatable {
    case queued, uploading, creating, processing, attaching, done
}

/// Where a video came from: `source` on `POST /api/videos` (accepted, not persisted).
enum VideoSource: String, Codable, Equatable {
    case recording
    case imported = "import"
}

/// The lesson activity a saved video joins (D18): a new one in `versionId`, or `activityId`'s video replaced.
struct VideoAttach: Codable, Equatable {
    let versionId: String
    let activityId: String?
    let title: String
}

struct VideoUploadTicket: Equatable {
    let uploadUrl: String
    let uid: String
}

struct VideoCreateRequest: Equatable {
    let uid: String
    let title: String
    let source: VideoSource
    let transcript: VideoTranscript?
}

/// The server calls the controller makes, so a test can script them.
protocol VideoUploadAPI {
    func mintUploadURL(title: String) async throws -> VideoUploadTicket
    /// Returns the `Video.id`; a same-owner duplicate uid answers the same id (D22).
    func createVideo(_ request: VideoCreateRequest) async throws -> String
    func status(ofVideo id: String) async throws -> VideoStatus
    func attach(_ attach: VideoAttach, videoId: String) async throws
}

/// Where the controller's errors surface: the top error banner (`/ios-error-surface`).
@MainActor
protocol VideoUploadBanner {
    /// `itemId` names the queue item whose failure this is; nil for an error no later stage of that
    /// item should take down.
    func surface(_ error: Error, context: String, message: String, itemId: String?, retry: (() -> Void)?)
    /// Takes down the banner `itemId` surfaced, if it is still on screen; never another error's.
    func withdraw(itemId: String)
}

// MARK: - The item

/// One unsent video: the manifest persisted beside its `.mp4` as `<localId>.json`.
struct VideoQueueItem: Codable, Equatable {
    let localId: String
    let fileName: String
    let posterFileName: String?
    var title: String
    let durationSeconds: Double
    let source: VideoSource
    var transcript: VideoTranscript?
    let createdAt: Date
    var streamUid: String?
    var serverId: String?
    var stage: VideoUploadStage
    /// Consecutive failures of this item; reset by any stage that succeeds.
    var failures: Int
    var polls: Int
    var nextAttemptAt: Date?
    var attach: VideoAttach?
    let ownerUserId: String
    let environment: String
    /// Until then the item waits for its on-device transcript (D10); nil when it waits no more.
    var transcriptDue: Date?
    /// The queue folder, filled in when the controller reads the item; never written to the manifest.
    var folder = URL(fileURLWithPath: "/")

    private enum CodingKeys: String, CodingKey {
        case localId, fileName, posterFileName, title, durationSeconds, source, transcript, createdAt, streamUid
        case serverId, stage, failures, polls, nextAttemptAt, attach, ownerUserId, environment
        case transcriptDue
    }

    /// The exported video in the queue folder.
    var fileURL: URL { folder.appendingPathComponent(fileName) }

    /// The first-frame image, when it could be written.
    var posterURL: URL? { posterFileName.map { folder.appendingPathComponent($0) } }

    /// When the queue may run the item; nil is now. Neither the network's return nor Retry shortens
    /// the wait for the transcript.
    var dueAt: Date? { [nextAttemptAt, transcriptDue].compactMap { $0 }.max() }

    /// True once the server has the row: the Library shows "Processing…", not "Uploading…".
    var isOnServer: Bool { serverId != nil }
}

// MARK: - Controller

@MainActor
@Observable
final class VideoUploadController {

    private static let pollLimit = 15
    private static let pollInterval: TimeInterval = 2
    private static let surfaceAfterFailures = 3
    /// 5 s, 30 s, 2 min, 10 min; every later attempt waits 10 min (D12).
    private static let backoff: [Duration] = [.seconds(5), .seconds(30), .seconds(120), .seconds(600)]

    private let api: VideoUploadAPI
    private let transport: VideoStreamTransport
    private let banner: VideoUploadBanner
    private let directory: URL
    private let ownerUserId: String
    private let environment: String
    private let defaultTitle: () -> String
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private let flushesOnEnqueue: Bool
    private var isProcessing = false
    private var flushTask: Task<Void, Never>?
    /// Which flush `flushTask` is: one that was cancelled must not clear its successor.
    private var flushNumber = 0
    private var sleepTask: Task<Void, Error>?
    private var wakeRequested = false
    private var pathMonitor: NWPathMonitor?
    /// `localId -> serverId` for items that finished this session.
    private var completedServerIds: [String: String] = [:]

    /// True after a 401 until `resumeAfterSignIn`.
    private(set) var isPausedForAuth = false

    /// The queue as views read it: refreshed by every manifest write and delete.
    private(set) var pendingItems: [VideoQueueItem] = []

    /// `flushesOnEnqueue` is off by default so a test that enqueues stays in control of the network;
    /// `AppState` turns it on for the real queue.
    init(api: VideoUploadAPI, transport: VideoStreamTransport, banner: VideoUploadBanner, directory: URL,
         ownerUserId: String, environment: String, defaultTitle: @escaping () -> String,
         now: @escaping () -> Date = { Date() }, flushesOnEnqueue: Bool = false,
         sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.api = api
        self.transport = transport
        self.banner = banner
        self.directory = directory
        self.ownerUserId = ownerUserId
        self.environment = environment
        self.defaultTitle = defaultTitle
        self.now = now
        self.flushesOnEnqueue = flushesOnEnqueue
        self.sleep = sleep
        pendingItems = pending()
    }

    /// The wait after the `attempt`th consecutive failure (1-based), capped at the last step.
    static func delay(forAttempt attempt: Int) -> Duration {
        backoff[min(max(attempt, 1), backoff.count) - 1]
    }

    /// Where a user's queue lives: Application Support, per environment and user, kept out of backup.
    nonisolated static func folder(environment: String, userId: String, root: URL? = nil) throws -> URL {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
        return base.appendingPathComponent("videos", isDirectory: true)
            .appendingPathComponent(environment, isDirectory: true)
            .appendingPathComponent(userId, isDirectory: true)
    }

    // MARK: Queue

    /// Moves the exported video into the queue folder and writes its manifest. No network. A nil
    /// `title` is the next `Video n`. With `transcriptHold` the upload waits that long for
    /// `supplyTranscript`, then goes without one (D10).
    /// A `localId` already queued answers its item, so a save a kill cut off can run again.
    @discardableResult
    func enqueue(_ video: ExportedVideo, localId: String = UUID().uuidString, title: String? = nil, source: VideoSource = .recording,
                 transcript: VideoTranscript? = nil, attach: VideoAttach?,
                 transcriptHold: TimeInterval? = nil) throws -> VideoQueueItem {
        let fm = FileManager.default
        try prepareDirectory()
        if let queued = pending().first(where: { $0.localId == localId }) { return queued }
        let fileName = "\(localId).mp4"
        let destination = directory.appendingPathComponent(fileName)
        // No manifest names it: a kill came between the move and the manifest.
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: video.url, to: destination)
        let posterFileName = writePoster(video.posterImage, localId: localId)
        let item = VideoQueueItem(
            localId: localId, fileName: fileName, posterFileName: posterFileName, title: title ?? defaultTitle(),
            durationSeconds: video.durationSeconds, source: source, transcript: transcript, createdAt: now(),
            streamUid: nil, serverId: nil, stage: .queued, failures: 0, polls: 0, nextAttemptAt: nil, attach: attach,
            ownerUserId: ownerUserId, environment: environment,
            transcriptDue: transcriptHold.map { now().addingTimeInterval($0) }, folder: directory)
        do {
            try persist(item)
        } catch {
            try? fm.moveItem(at: destination, to: video.url)
            if let posterFileName { try? fm.removeItem(at: directory.appendingPathComponent(posterFileName)) }
            throw error
        }
        guard flushesOnEnqueue else { return item }
        startPathMonitoring()
        Task { await flush() }
        return item
    }

    /// Ends an item's wait for its transcript, nil included. Dropped once the upload has begun.
    func supplyTranscript(_ transcript: VideoTranscript?, forLocalId localId: String) {
        guard var item = pending().first(where: { $0.localId == localId }), item.transcriptDue != nil else { return }
        item.transcript = transcript
        item.transcriptDue = nil
        do {
            try update(item)
        } catch {
            // Recovered: the item uploads without it when its wait is over, and the server transcribes.
            Log.media.error("video transcript not persisted: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard flushesOnEnqueue else { return }
        if flushTask != nil { wake() } else { Task { await flush() } }
    }

    /// This owner's and this environment's unsent items, oldest first.
    func pending() -> [VideoQueueItem] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            // Silent: no folder yet means nothing queued.
            return []
        }
        let decoder = JSONDecoder()
        return names.filter { $0.hasSuffix(".json") }.compactMap { name -> VideoQueueItem? in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
                  var item = try? decoder.decode(VideoQueueItem.self, from: data),
                  item.ownerUserId == ownerUserId, item.environment == environment else { return nil }
            item.folder = directory
            return item
        }.sorted { ($0.createdAt, $0.localId) < ($1.createdAt, $1.localId) }
    }

    func queued(localId: String) -> VideoQueueItem? {
        pending().first { $0.localId == localId }
    }

    /// A pending item's `serverId`, or the one recorded when that item finished this session.
    func serverId(forLocalId localId: String) -> String? {
        pending().first { $0.localId == localId }?.serverId ?? completedServerIds[localId]
    }

    /// Drops a queued video: its `.mp4`, poster and manifest go, as a memo's do (`MemoUploadController.remove`).
    /// A stage in flight finds the manifest gone and stops. The caller deletes a server row first.
    /// Unknown `localId` (the item finished): `CancellationError`.
    func remove(localId: String) throws {
        guard let item = pending().first(where: { $0.localId == localId }) else { throw CancellationError() }
        discard(item)
    }

    // MARK: Flush

    /// Runs the queue serially until it is empty or paused. A failed item waits out its backoff while
    /// the rest go on; a call during a flush joins it.
    func flush() async {
        if let flushTask {
            wake()
            await flushTask.value
            return
        }
        guard !isPausedForAuth else { return }
        flushNumber += 1
        let number = flushNumber
        let task = Task { await runFlush(number) }
        flushTask = task
        await task.value
        if pending().isEmpty { stopPathMonitoring() }
    }

    /// Stops the in-flight flush and the network trigger. Files and manifests stay.
    func cancel() {
        flushTask?.cancel()
        flushTask = nil
        stopPathMonitoring()
    }

    /// After the next sign-in: clears the pause and flushes.
    func resumeAfterSignIn() async {
        isPausedForAuth = false
        await flush()
    }

    /// The banner's Retry: every waiting item is due now.
    func retryNow() async {
        isPausedForAuth = false
        makeEveryItemDue()
        await flush()
    }

    /// An `NWPathMonitor` that retries whenever the network becomes satisfied. It exists only while
    /// something is queued.
    func startPathMonitoring() {
        guard pathMonitor == nil, !pending().isEmpty else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.networkReturned() }
        }
        monitor.start(queue: DispatchQueue(label: "video.upload.path"))
        pathMonitor = monitor
    }

    private func stopPathMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    /// The network came back: every backed-off item is due now.
    func networkReturned() async {
        makeEveryItemDue()
        if flushTask != nil { wake() } else { await flush() }
    }

    private func makeEveryItemDue() {
        for var item in pending() where item.nextAttemptAt != nil {
            item.nextAttemptAt = nil
            do {
                try update(item)
            } catch {
                // Silent: the item left the queue while this ran; there is nothing to make due.
            }
        }
    }

    private func wake() {
        guard let sleepTask else { return }
        wakeRequested = true
        sleepTask.cancel()
    }

    /// Ends its turn in the same step as its last look at the queue, so a video queued after that look
    /// gets a flush of its own.
    private func runFlush(_ number: Int) async {
        defer { if flushNumber == number { flushTask = nil } }
        while !Task.isCancelled {
            switch await step(onlyDue: true) {
            case .advanced, .retryLater:
                continue
            case .paused:
                isPausedForAuth = true
                return
            case .idle:
                guard let due = pending().compactMap(\.dueAt).min() else { return }
                let wait = max(0, due.timeIntervalSince(now()))
                guard await sleeps(.seconds(wait)) else { return }
                await Task.yield()
            }
        }
    }

    /// False when the flush was cancelled or the sleep failed; true when it ended or was woken.
    private func sleeps(_ duration: Duration) async -> Bool {
        let sleeper = Task { [sleep] in try await sleep(duration) }
        sleepTask = sleeper
        defer { sleepTask = nil; wakeRequested = false }
        return await withTaskCancellationHandler {
            do {
                try await sleeper.value
                return !Task.isCancelled
            } catch {
                // Silent: a sleep that throws ends the flush, unless `wake` cancelled it.
                return wakeRequested && !Task.isCancelled
            }
        } onCancel: {
            sleeper.cancel()
        }
    }

    // MARK: Lifecycle

    /// Runs the oldest item one stage further, whether or not its backoff is over. Serial: a call
    /// while another is in flight is idle.
    func processNext() async -> VideoUploadStep {
        await step(onlyDue: false)
    }

    private func step(onlyDue: Bool) async -> VideoUploadStep {
        guard !isProcessing else { return .idle }
        isProcessing = true
        defer { isProcessing = false }
        let cutoff = now()
        guard var item = pending().first(where: { !onlyDue || ($0.dueAt ?? .distantPast) <= cutoff }) else { return .idle }
        // A retry never shows the failure it is retrying (D9, D20).
        banner.withdraw(itemId: item.localId)
        do {
            try await run(&item)
            return .advanced
        } catch {
            if case .unauthorized? = error as? APIError { return .paused }
            // Silent: the item was removed while this pass was in flight.
            if error is ItemRemoved { return .retryLater }
            recordFailure(&item, error)
            return .retryLater
        }
    }

    private func run(_ item: inout VideoQueueItem) async throws {
        if item.transcriptDue != nil {
            item.transcriptDue = nil
            try update(item)
        }
        switch item.stage {
        case .queued:
            try await upload(&item)
        case .uploading:
            try await create(&item)
        case .creating:
            if item.attach != nil { try await attach(&item) } else { try await poll(&item) }
        case .attaching, .processing:
            try await poll(&item)
        case .done:
            finish(item)
        }
    }

    /// A fresh Stream URL each time (a spent one is no use on a retry); its uid is stored before the
    /// bytes move, so a kill mid-upload leaves a record of what was started.
    private func upload(_ item: inout VideoQueueItem) async throws {
        let ticket = try await api.mintUploadURL(title: item.title)
        item.streamUid = ticket.uid
        try update(item)
        guard let url = URL(string: ticket.uploadUrl) else { throw VideoUploadError.badUploadURL }
        let status = try await transport.upload(fileURL: item.fileURL, to: url)
        guard (200..<300).contains(status) else { throw VideoUploadError.uploadRejected(status: status) }
        try advance(&item, to: .uploading)
    }

    private func create(_ item: inout VideoQueueItem) async throws {
        guard let uid = item.streamUid else {
            // The uid is persisted before the upload, so this is a damaged manifest: start over.
            item.stage = .queued
            try update(item)
            return
        }
        item.serverId = try await api.createVideo(
            VideoCreateRequest(uid: uid, title: item.title, source: item.source, transcript: item.transcript))
        try advance(&item, to: .creating)
    }

    /// Creates or replaces the activity. A refusal (`isRefusal`) keeps the video in the Library and
    /// surfaces the banner; any other failure retries.
    private func attach(_ item: inout VideoQueueItem) async throws {
        guard let attach = item.attach else { return }
        guard let serverId = item.serverId else { return try restartAtCreate(&item) }
        do {
            try await api.attach(attach, videoId: serverId)
        } catch where Self.isRefusal(error) {
            banner.surface(error, context: "VideoUploadController.attach",
                           message: "Couldn't add the video to the lesson. It's in your Library.", itemId: nil, retry: nil)
        }
        try advance(&item, to: .attaching)
    }

    /// One `refresh` poll (D23). Ready, errored or out of tries, the item is finished: the Library
    /// shows the server's state from here, and the server job is the backstop.
    private func poll(_ item: inout VideoQueueItem) async throws {
        guard let serverId = item.serverId else { return try restartAtCreate(&item) }
        item.polls += 1
        let status: VideoStatus
        do {
            status = try await api.status(ofVideo: serverId)
        } catch {
            // Silent: a poll that fails is one try used; the server job moves the video on regardless.
            status = .pending
        }
        if status != .pending || item.polls >= Self.pollLimit {
            finish(item)
        } else {
            item.stage = .processing
            item.failures = 0
            item.nextAttemptAt = now().addingTimeInterval(Self.pollInterval)
            try update(item)
        }
    }

    /// A manifest past `creating` with no `serverId` is damaged: step back so the create runs again
    /// (a duplicate uid answers 200 with the same row, D22). The stage changes, so the flush moves on.
    private func restartAtCreate(_ item: inout VideoQueueItem) throws {
        item.stage = .uploading
        item.nextAttemptAt = nil
        try update(item)
    }

    private func advance(_ item: inout VideoQueueItem, to stage: VideoUploadStage) throws {
        item.stage = stage
        item.failures = 0
        item.nextAttemptAt = nil
        try update(item)
    }

    /// A user-initiated upload that did not go through: back off, and after three in a row surface
    /// the banner once with Retry (`/ios-error-surface`).
    /// A transfer iOS suspended (`VideoUploadError.suspended`) backs off by the next failure's delay but is
    /// not counted and never surfaces (D20).
    private func recordFailure(_ item: inout VideoQueueItem, _ error: Error) {
        let suspended = (error as? VideoUploadError) == .suspended
        if !suspended { item.failures += 1 }
        let attempt = suspended ? item.failures + 1 : item.failures
        item.nextAttemptAt = now().addingTimeInterval(Double(Self.delay(forAttempt: attempt).components.seconds))
        do {
            try update(item)
        } catch is ItemRemoved {
            return // Silent: the leader deleted it; its failure no longer matters
        } catch {
            Log.media.error("video backoff not persisted: \(error.localizedDescription, privacy: .public)")
        }
        guard !suspended, item.failures == Self.surfaceAfterFailures else { return }
        banner.surface(error, context: "VideoUploadController.run",
                       message: item.attach != nil ? "Couldn't add your video to the lesson" : "Couldn't upload your video",
                       itemId: item.localId, retry: { [weak self] in Task { await self?.retryNow() } })
    }

    /// An attach no retry can make: no access, a document the server rejects, or a version or activity
    /// that is gone or published. A 409 `CONFLICT` is two writes meeting; the retry reloads the version.
    private static func isRefusal(_ error: Error) -> Bool {
        if let http = error as? APIHTTPError {
            switch http.status {
            case 403, 404: return true
            case 400: return http.details["code"] == "VALIDATION"
            default: return false
            }
        }
        if let activity = error as? ActivityActionsError { return activity == .notDraft || activity == .gone }
        return false
    }

    // MARK: Persistence

    private func manifestURL(_ item: VideoQueueItem) -> URL {
        directory.appendingPathComponent("\(item.localId).json")
    }

    private func persist(_ item: VideoQueueItem) throws {
        try JSONEncoder().encode(item).write(to: manifestURL(item), options: .atomic)
        pendingItems = pending()
    }

    /// Rewrites the manifest of an item that is already queued. A manifest that is gone (the item
    /// finished, or was removed, while a stage was awaiting the server) throws `ItemRemoved` instead of
    /// being resurrected.
    private func update(_ item: VideoQueueItem) throws {
        guard FileManager.default.fileExists(atPath: manifestURL(item).path) else { throw ItemRemoved() }
        try persist(item)
    }

    private func finish(_ item: VideoQueueItem) {
        if let serverId = item.serverId { completedServerIds[item.localId] = serverId }
        discard(item)
    }

    /// Deletes the item's files and manifest, then refreshes `pendingItems`. Its banner goes with it (D20).
    private func discard(_ item: VideoQueueItem) {
        banner.withdraw(itemId: item.localId)
        for url in [item.fileURL, manifestURL(item)] + (item.posterURL.map { [$0] } ?? []) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Log.media.error("video queue file not removable: \(error.localizedDescription, privacy: .public)")
            }
        }
        pendingItems = pending()
    }

    private func writePoster(_ image: UIImage?, localId: String) -> String? {
        guard let data = image?.jpegData(compressionQuality: 0.8) else { return nil }
        let name = "\(localId).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            // Silent: the poster only dresses the pending row; the upload does not need it.
            return nil
        }
    }

    /// Creates the folder and keeps it out of iCloud backup.
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = directory
        try folder.setResourceValues(values)
    }
}

/// The item's manifest is gone: it finished or was deleted while a stage was in flight.
private struct ItemRemoved: Error {}

enum VideoUploadError: Error, Equatable {
    case badUploadURL
    case uploadRejected(status: Int)
    /// iOS ended the transfer's background time: the queue backs off but the attempt is not counted (D20).
    case suspended
}

// MARK: - D24 limits

enum VideoTranscriptLimits {
    static let maxTextUnits = 20_000
    static let maxSegments = 2_000
    static let maxSegmentUnits = 1_000

    /// The transcript as `POST /api/videos` accepts it: the text cut to 20 000 UTF-16 units, any
    /// segment over 1 000 split into pieces (its time shared by characters), at most 2 000 segments,
    /// each with `0 <= startMs <= endMs`. Never throws: an oversized transcript is trimmed, not refused.
    static func fit(_ transcript: VideoTranscript) -> (text: String, segments: [VideoTranscriptSegment]) {
        var segments: [VideoTranscriptSegment] = []
        for segment in transcript.segments {
            let start = max(segment.startMs, 0)
            let end = max(segment.endMs, start)
            segments += pieces(of: segment.text, startMs: start, endMs: end)
            if segments.count >= maxSegments { break }
        }
        return (prefix(transcript.text, units: maxTextUnits), Array(segments.prefix(maxSegments)))
    }

    private static func pieces(of text: String, startMs: Int, endMs: Int) -> [VideoTranscriptSegment] {
        guard text.utf16.count > maxSegmentUnits else { return [VideoTranscriptSegment(text: text, startMs: startMs, endMs: endMs)] }
        var chunks: [String] = []
        var current = ""
        var units = 0
        for character in text {
            let width = String(character).utf16.count
            if units + width > maxSegmentUnits {
                chunks.append(current)
                current = ""
                units = 0
            }
            current.append(character)
            units += width
        }
        if !current.isEmpty { chunks.append(current) }
        let total = Double(text.utf16.count)
        var offset = 0
        return chunks.enumerated().map { index, chunk in
            let from = startMs + Int((Double(endMs - startMs) * Double(offset) / total).rounded())
            offset += chunk.utf16.count
            let to = index == chunks.count - 1 ? endMs : startMs + Int((Double(endMs - startMs) * Double(offset) / total).rounded())
            return VideoTranscriptSegment(text: chunk, startMs: from, endMs: to)
        }
    }

    private static func prefix(_ text: String, units: Int) -> String {
        guard text.utf16.count > units else { return text }
        var result = ""
        var used = 0
        for character in text {
            let width = String(character).utf16.count
            if used + width > units { break }
            result.append(character)
            used += width
        }
        return result
    }
}

// MARK: - Live seams

/// The real server calls: `VideoActions` for Stream and the create, `ActivityActions` for the attach.
struct LiveVideoUploadAPI: VideoUploadAPI {
    let videos: VideoActions
    let activities: ActivityActions
    let state: AppState

    func mintUploadURL(title: String) async throws -> VideoUploadTicket {
        let ticket = try await videos.getUploadUrl(title: title)
        return VideoUploadTicket(uploadUrl: ticket.uploadUrl, uid: ticket.uid)
    }

    func createVideo(_ request: VideoCreateRequest) async throws -> String {
        try await videos.createVideoRecord(cloudflareUid: request.uid, title: request.title,
                                           source: request.source, transcript: request.transcript).id
    }

    func status(ofVideo id: String) async throws -> VideoStatus {
        try await videos.refreshVideoStatus(id: id).videoStatus
    }

    /// Reads the server's current version first, never a cached one: the cache may be cold after a
    /// relaunch, or stale. A version or activity that is gone is a refusal (D18). A create whose answer
    /// was lost has left its activity there, so a retry finds it and makes no second one.
    func attach(_ attach: VideoAttach, videoId: String) async throws {
        try await activities.loadVersionKeepingStatus(id: attach.versionId)
        guard let activityId = attach.activityId else {
            let attached = await state.activities(forVersion: attach.versionId)
                .contains { ActivitiesEditorMapper.videoId(of: $0) == videoId }
            guard !attached else { return }
            try await activities.create(versionId: attach.versionId, kind: "video", title: attach.title,
                                        document: Self.videoDocument(videoId: videoId, title: attach.title))
            return
        }
        guard let existing = await state.activities[activityId] else { throw ActivityActionsError.gone }
        let document = existing.document.updating { $0[path: ["content", "videoId"]] = .string(videoId) }
        try await activities.save(activityId: activityId, title: nil, document: document)
    }

    /// A video activity's document: `content.videoId` and no duration (the server reads it from the video).
    static func videoDocument(videoId: String, title: String) -> ActivityDocument {
        ActivityDocument(raw: .object([
            "schemaVersion": .number(1),
            "kind": .string("video"),
            "background": .object(["color": .string("#000000")]),
            "content": .object(["type": .string("video"), "videoId": .string(videoId)]),
            "actions": .array([]),
            "chrome": .object(["topAction": .string("share")]),
            "fallback": .object(["title": .string(title), "body": .string(ActivityDocument.fallbackBody)])
        ]))
    }
}

/// The real banner: the app's one error channel, surfaced because the leader tapped Save. It
/// remembers which error each item put up, so a withdrawal never takes down another's.
@MainActor
final class AppStateVideoUploadBanner: VideoUploadBanner {
    private let state: AppState
    /// `itemId -> AppError.id` of the error that item surfaced.
    private var surfaced: [String: UUID] = [:]

    init(state: AppState) {
        self.state = state
    }

    func surface(_ error: Error, context: String, message: String, itemId: String?, retry: (() -> Void)?) {
        state.recordError(error, context: context, surface: true, friendlyMessage: message, retry: retry)
        if let itemId { surfaced[itemId] = state.activeSurfacedError?.id }
    }

    func withdraw(itemId: String) {
        guard let errorId = surfaced.removeValue(forKey: itemId), state.activeSurfacedError?.id == errorId else { return }
        state.activeSurfacedError = nil
    }
}
