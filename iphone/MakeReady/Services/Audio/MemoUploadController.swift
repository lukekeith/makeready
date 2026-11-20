//
//  MemoUploadController.swift
//  MakeReady
//
//  The persistent per-user upload queue (D13, D22). `enqueue` moves a recording and its JSON
//  manifest into `directory` and never touches the network. `processNext` runs the oldest due
//  item through create -> PUT -> complete, persisting the manifest after every server step, so a
//  kill resumes where it stopped and a created row is never created twice. The local file goes
//  only after `complete` returns 200. `flush` runs the queue serially with backoff (D22), pauses on
//  a 401 without counting it (D41), and is triggered by enqueue, launch and the network coming
//  back. Only this owner's folder is ever read (D37).
//

import Foundation
import Network

/// What one `processNext` pass did.
enum MemoUploadStep: Equatable {
    case idle
    case completed(String)
    case retryLater
    /// A 401 (D41): nothing is deleted, nothing backs off; the queue waits for the next sign-in.
    case paused
}

/// One unsent memo: the manifest persisted beside its `.m4a` as `<localId>.json`.
struct MemoQueueItem: Codable, Equatable {
    let localId: String
    let fileName: String
    let title: String
    let durationMs: Int
    let waveformPeaks: [Double]
    /// ISO-8601 with fractional seconds, formatted once at enqueue and re-POSTed verbatim, so a
    /// re-create after a 404 carries the identical instant (F25).
    let recordedAt: String
    let transcript: Transcript?
    let fileSize: Int
    var serverId: String?
    var upload: MemoUploadTicket?
    let ownerUserId: String
    let environment: String
    var attempts: Int
    var nextAttemptAt: Date?
}

@MainActor
final class MemoUploadController {

    private static let recordedAtFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Where a lifecycle stage leaves the pass.
    private enum Stage {
        case proceed
        case retryLater
        /// The server no longer has the row (404): the next pass re-POSTs (D29).
        case memoGone
        /// The server already has the object (409 on re-mint): only `complete` is left.
        case alreadyUploaded
    }

    private let api: APIClientProtocol
    private let actions: MemoActions
    private let transport: MemoPutTransport
    private let directory: URL
    private let ownerUserId: String
    private let environment: String
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private let flushesOnEnqueue: Bool
    private var isProcessing = false
    private var flushTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var sleepTask: Task<Void, Error>?
    private var backoffSteps: [String: (attempts: Int, wait: Duration)] = [:]
    private var wakeRequested = false
    private var wakeRetriesAll = false

    /// 5 s, 30 s, 2 min, 10 min; every later attempt waits 10 min (D22).
    private static let backoff: [Duration] = [.seconds(5), .seconds(30), .seconds(120), .seconds(600)]

    /// True after a 401 until `resumeAfterSignIn` (D41).
    private(set) var isPausedForAuth = false

    /// `flushesOnEnqueue` is off by default so a test that enqueues stays in control of the
    /// network; `AppState` turns it on for the real queue (D22).
    init(api: APIClientProtocol, actions: MemoActions, transport: MemoPutTransport, directory: URL,
         ownerUserId: String, environment: String, now: @escaping () -> Date = { Date() },
         flushesOnEnqueue: Bool = false,
         sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.api = api
        self.actions = actions
        self.transport = transport
        self.directory = directory
        self.ownerUserId = ownerUserId
        self.environment = environment
        self.now = now
        self.flushesOnEnqueue = flushesOnEnqueue
        self.sleep = sleep
    }

    /// The wait after the `attempt`th failure (1-based), capped at the last backoff step.
    static func delay(forAttempt attempt: Int) -> Duration {
        backoff[min(max(attempt, 1), backoff.count) - 1]
    }

    // MARK: Queue

    /// Moves the `.m4a` into the queue folder and writes its manifest. No network (D22).
    func enqueue(_ result: RecordingResult) throws {
        let fm = FileManager.default
        try prepareDirectory()
        let localId = UUID().uuidString
        let fileName = "\(localId).m4a"
        let destination = directory.appendingPathComponent(fileName)
        try fm.moveItem(at: result.fileURL, to: destination)
        let size = (try fm.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
        let item = MemoQueueItem(
            localId: localId, fileName: fileName, title: result.title, durationMs: result.durationMs,
            waveformPeaks: result.waveformPeaks, recordedAt: Self.recordedAtFormatter.string(from: result.recordedAt),
            transcript: result.transcript, fileSize: size, serverId: nil, upload: nil,
            ownerUserId: ownerUserId, environment: environment, attempts: 0, nextAttemptAt: nil)
        do {
            try persist(item)
        } catch {
            try? fm.moveItem(at: destination, to: result.fileURL)
            throw error
        }
        guard flushesOnEnqueue else { return }
        startPathMonitoring()
        Task { await flush() }
    }

    /// This owner's and this environment's unsent items, oldest first (D37).
    func pending() -> [MemoQueueItem] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            // Silent: no folder yet means nothing queued.
            return []
        }
        return names.filter { $0.hasSuffix(".json") }.compactMap { name -> MemoQueueItem? in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
                  let item = try? JSONDecoder.apiDecoder.decode(MemoQueueItem.self, from: data),
                  item.ownerUserId == ownerUserId, item.environment == environment else { return nil }
            return item
        }.sorted { ($0.recordedAt, $0.localId) < ($1.recordedAt, $1.localId) }
    }

    // MARK: Flush

    /// Runs the queue serially until it is empty or paused. A failed item backs off (attempts +1,
    /// `nextAttemptAt`, a sleep) and goes again; a call during a flush joins it.
    func flush() async {
        if let flushTask {
            // A flush asked for mid-backoff (a new memo): wake it so it re-checks what is due.
            wakeSleeper(retryAll: false)
            await flushTask.value
            return
        }
        guard !isPausedForAuth else { return }
        let task = Task { await runFlush() }
        flushTask = task
        await task.value
        flushTask = nil
        if pending().isEmpty { stopPathMonitoring() }
    }

    /// Stops the in-flight flush and the network trigger. Files and manifests stay (D37).
    func cancel() {
        flushTask?.cancel()
        flushTask = nil
        stopPathMonitoring()
    }

    /// After the next sign-in (D41): clears the pause and flushes.
    func resumeAfterSignIn() async {
        isPausedForAuth = false
        await flush()
    }

    /// An `NWPathMonitor` that flushes whenever the network becomes satisfied. It exists only
    /// while something is queued (D22, F24).
    func startPathMonitoring() {
        guard pathMonitor == nil, !pending().isEmpty else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.networkReturned() }
        }
        monitor.start(queue: DispatchQueue(label: "memo.upload.path"))
        pathMonitor = monitor
    }

    private func stopPathMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    /// Wakes a backoff sleep early. `retryAll` (the network came back) makes every backed-off item
    /// due; otherwise only what is due by the clock runs.
    private func wakeSleeper(retryAll: Bool) {
        guard let sleepTask else { return }
        wakeRequested = true
        wakeRetriesAll = wakeRetriesAll || retryAll
        sleepTask.cancel()
    }

    /// The network became satisfied (D22): ends a backoff sleep and retries everything now, or
    /// starts a flush when none is running.
    func networkReturned() async {
        if sleepTask != nil { wakeSleeper(retryAll: true) } else { await flush() }
    }

    private func runFlush() async {
        // `dueBy` is a retry-all cutoff (a network return) held for the whole pass; `tried` keeps an
        // item that fails inside the pass from being picked again until the pass ends.
        var dueBy: Date?
        var tried: Set<String> = []
        while !Task.isCancelled {
            let (step, localId) = await runDue(dueBy: dueBy ?? now(), skipping: tried)
            if dueBy != nil, let localId { tried.insert(localId) }
            switch step {
            case .completed:
                continue
            case .paused:
                isPausedForAuth = true
                return
            case .retryLater:
                // The item now waits out its own backoff; the loop moves on to whatever else is
                // due, so one failing memo never starves the ones behind it.
                guard !Task.isCancelled else { return }
                let (wait, persisted) = recordFailure(localId: localId)
                if let wait, !persisted {
                    guard await sleeps(wait) else { return }
                    wakeRequested = false
                    wakeRetriesAll = false
                }
            case .idle:
                if dueBy != nil {
                    // The retry-all pass has been through everything: back to the normal schedule.
                    dueBy = nil
                    tried = []
                    continue
                }
                // Everything left waits out a backoff: sleep until the earliest is due.
                let waiting = pending().compactMap { item in item.nextAttemptAt.map { (item: item, due: $0) } }
                guard let (next, earliest) = waiting.min(by: { $0.due < $1.due }) else { return }
                // A backoff recorded by this flush sleeps its exact step; a persisted one (after a relaunch) the time left.
                let recorded = backoffSteps[next.localId].flatMap { $0.attempts == next.attempts ? $0.wait : nil }
                let wait = recorded ?? .seconds(max(0, earliest.timeIntervalSince(now())).rounded())
                guard await sleeps(wait) else { return }
                dueBy = wakeRetriesAll ? .distantFuture : (wakeRequested ? now() : earliest)
                tried = []
                wakeRequested = false
                wakeRetriesAll = false
            }
        }
    }

    /// False when the flush was cancelled or the sleep failed; true when it ended or was woken.
    private func sleeps(_ duration: Duration) async -> Bool {
        let sleeper = Task { [sleep] in try await sleep(duration) }
        sleepTask = sleeper
        defer { sleepTask = nil }
        return await withTaskCancellationHandler {
            do {
                try await sleeper.value
                return !Task.isCancelled
            } catch {
                // Silent: a sleep that throws ends the flush, unless `wakeSleeper` cancelled it.
                return wakeRequested && !Task.isCancelled
            }
        } onCancel: {
            sleeper.cancel()
        }
    }

    /// attempts +1 and `nextAttemptAt` for the item that just failed; returns how long it waits and
    /// whether that was persisted (when not, the caller sleeps the wait itself).
    private func recordFailure(localId: String?) -> (wait: Duration?, persisted: Bool) {
        guard let localId, var item = pending().first(where: { $0.localId == localId }) else { return (nil, true) }
        item.attempts += 1
        let wait = Self.delay(forAttempt: item.attempts)
        let due = now().addingTimeInterval(Double(wait.components.seconds))
        item.nextAttemptAt = due
        backoffSteps[item.localId] = (item.attempts, wait)
        do {
            try persist(item)
            return (wait, true)
        } catch {
            Log.memo.error("backoff not persisted: \(error.localizedDescription)")
            return (wait, false)
        }
    }

    // MARK: Salvage

    /// Launch recovery (D16): each draft of this owner is exported, transcribed from its file and
    /// enqueued. A draft that fails is logged and the rest go on.
    func recoverDrafts(drafts: MemoDraftStore, transcriber: any MemoTranscribing) async {
        for manifest in drafts.recoverable() {
            do {
                guard let salvaged = try await drafts.salvage(manifest) else { continue }
                let transcript = await transcriber.transcribeFile(salvaged.m4a)
                try enqueue(RecordingResult(fileURL: salvaged.m4a, title: manifest.title, durationMs: salvaged.durationMs,
                                            waveformPeaks: salvaged.peaks, recordedAt: manifest.startedAt, transcript: transcript))
            } catch {
                Log.memo.error("draft not recovered: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Lifecycle

    /// Runs the oldest due item as far as it goes. Serial: a call while another is in flight is idle.
    func processNext() async -> MemoUploadStep {
        await runDue(dueBy: now()).step
    }

    /// One pass over the oldest item that is due by `dueBy`.
    private func runDue(dueBy: Date, skipping: Set<String> = []) async -> (step: MemoUploadStep, localId: String?) {
        guard !isProcessing else { return (.idle, nil) }
        isProcessing = true
        defer { isProcessing = false }
        guard var item = pending().first(where: { !skipping.contains($0.localId) && ($0.nextAttemptAt ?? .distantPast) <= dueBy }) else { return (.idle, nil) }
        do {
            return (try await run(&item), item.localId)
        } catch {
            if Self.isUnauthorized(error) { return (.paused, item.localId) }
            // Console-only: a background flush, never a user-initiated action (D21). A 400/403 from
            // the server is retried at the capped backoff rather than dropped: the recording is kept.
            AppState.shared.recordError(error, context: "MemoUploadController.runDue")
            return (.retryLater, item.localId)
        }
    }

    private func run(_ item: inout MemoQueueItem) async throws -> MemoUploadStep {
        if item.serverId == nil { try await create(&item) }
        guard let serverId = item.serverId else { return .retryLater }

        var stage = Stage.proceed
        if item.upload.map({ $0.expiresAt <= now() }) ?? true {
            stage = try await remint(&item, serverId)
        }
        if stage == .proceed { stage = try await put(&item, serverId) }
        switch stage {
        case .retryLater:
            return .retryLater
        case .memoGone:
            try forget(&item)
            return .retryLater
        case .proceed, .alreadyUploaded:
            return try await complete(&item, serverId)
        }
    }

    /// `POST /api/memos`; the row and its first ticket are stored before any PUT (D13, D22).
    private func create(_ item: inout MemoQueueItem) async throws {
        var body: [String: Any] = [
            "title": item.title, "durationMs": item.durationMs, "fileSize": item.fileSize,
            "recordedAt": item.recordedAt, "waveformPeaks": item.waveformPeaks,
        ]
        if let transcript = item.transcript {
            body["transcript"] = transcript.text
            // The server needs 0 <= startMs <= endMs <= durationMs; on-device rounding can overshoot by 1.
            body["transcriptSegments"] = transcript.segments.map { segment -> [String: Any] in
                let end = min(max(segment.endMs, 0), item.durationMs)
                let start = min(max(segment.startMs, 0), end)
                return ["text": segment.text, "startMs": start, "endMs": end]
            }
        }
        let data = try await api.requestWithStatus(endpoint: "/api/memos", method: "POST", body: body, timeout: 30)
        let response = try JSONDecoder.apiDecoder.decode(MemoCreateResponse.self, from: data)
        item.serverId = response.memo.id
        item.upload = response.upload
        try persist(item)
    }

    /// `POST /api/memos/:id/upload` — a fresh ticket (D29). 404: the row is gone; 409: already uploaded.
    private func remint(_ item: inout MemoQueueItem, _ serverId: String) async throws -> Stage {
        do {
            let data = try await api.requestWithStatus(endpoint: "/api/memos/\(serverId)/upload", method: "POST", body: [:], timeout: 30)
            item.upload = try JSONDecoder.apiDecoder.decode(MemoUploadResponse.self, from: data).upload
            try persist(item)
            return .proceed
        } catch let error as APIHTTPError where error.status == 404 {
            return .memoGone
        } catch let error as APIHTTPError where error.status == 409 {
            return .alreadyUploaded
        }
    }

    /// The PUT through the transport. A 403 (an expired or rejected signature) re-mints once.
    private func put(_ item: inout MemoQueueItem, _ serverId: String) async throws -> Stage {
        var remintedAfter403 = false
        while true {
            guard let ticket = item.upload else { return .retryLater }
            guard let url = URL(string: ticket.url) else {
                // A ticket URL that never parses would loop forever: drop it so the next pass re-mints.
                Log.memo.error("memo upload ticket has an unparseable URL; re-minting next pass")
                item.upload = nil
                try persist(item)
                return .retryLater
            }
            let status = try await transport.put(fileURL: directory.appendingPathComponent(item.fileName), to: url, headers: ticket.headers)
            if (200..<300).contains(status) { return .proceed }
            guard status == 403, !remintedAfter403 else { return .retryLater }
            remintedAfter403 = true
            let stage = try await remint(&item, serverId)
            if stage != .proceed { return stage }
        }
    }

    /// `PATCH /api/memos/:id/complete`. 200 hands the memo to the stores and deletes the files;
    /// 404 forgets the row (re-POST next pass); 409 drops the ticket (re-mint and re-PUT next pass).
    private func complete(_ item: inout MemoQueueItem, _ serverId: String) async throws -> MemoUploadStep {
        do {
            let data = try await api.requestWithStatus(endpoint: "/api/memos/\(serverId)/complete", method: "PATCH", body: [:], timeout: 30)
            let memo = try JSONDecoder.apiDecoder.decode(MemoResponse.self, from: data).memo
            actions.memoCompleted(memo)
            remove(item)
            return .completed(serverId)
        } catch let error as APIHTTPError where error.status == 404 {
            try forget(&item)
            return .retryLater
        } catch let error as APIHTTPError where error.status == 409 {
            item.upload = nil
            try persist(item)
            return .retryLater
        }
    }

    // MARK: Persistence

    private func forget(_ item: inout MemoQueueItem) throws {
        item.serverId = nil
        item.upload = nil
        try persist(item)
    }

    private func manifestURL(_ item: MemoQueueItem) -> URL {
        directory.appendingPathComponent("\(item.localId).json")
    }

    private func persist(_ item: MemoQueueItem) throws {
        try JSONEncoder.apiEncoder.encode(item).write(to: manifestURL(item), options: .atomic)
    }

    private func remove(_ item: MemoQueueItem) {
        for url in [directory.appendingPathComponent(item.fileName), manifestURL(item)] {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Log.memo.error("queue file not removable: \(error.localizedDescription)")
            }
        }
    }

    /// Creates the folder and keeps it out of iCloud backup (D37).
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = directory
        try folder.setResourceValues(values)
    }

    private static func isUnauthorized(_ error: Error) -> Bool {
        if case .unauthorized? = error as? APIError { return true }
        return false
    }
}
