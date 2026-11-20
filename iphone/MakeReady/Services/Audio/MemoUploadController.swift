//
//  MemoUploadController.swift
//  MakeReady
//
//  The persistent per-user upload queue (D13, D22). `enqueue` moves a recording and its JSON
//  manifest into `directory` and never touches the network. `processNext` runs the oldest due
//  item through create -> PUT -> complete, persisting the manifest after every server step, so a
//  kill resumes where it stopped and a created row is never created twice. The local file goes
//  only after `complete` returns 200. Backoff and the flush triggers are layered on top.
//

import Foundation

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
    private var isProcessing = false

    init(api: APIClientProtocol, actions: MemoActions, transport: MemoPutTransport, directory: URL,
         ownerUserId: String, environment: String, now: @escaping () -> Date = { Date() }) {
        self.api = api
        self.actions = actions
        self.transport = transport
        self.directory = directory
        self.ownerUserId = ownerUserId
        self.environment = environment
        self.now = now
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

    // MARK: Lifecycle

    /// Runs the oldest due item as far as it goes. Serial: a call while another is in flight is idle.
    func processNext() async -> MemoUploadStep {
        guard !isProcessing else { return .idle }
        isProcessing = true
        defer { isProcessing = false }
        guard var item = pending().first(where: { ($0.nextAttemptAt ?? .distantPast) <= now() }) else { return .idle }
        do {
            return try await run(&item)
        } catch {
            if Self.isUnauthorized(error) { return .paused }
            // Console-only: a background flush, never a user-initiated action (D21).
            Log.memo.error("memo upload failed: \(error.localizedDescription)")
            return .retryLater
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
            body["transcriptSegments"] = transcript.segments.map { ["text": $0.text, "startMs": $0.startMs, "endMs": $0.endMs] as [String: Any] }
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
            guard let ticket = item.upload, let url = URL(string: ticket.url) else { return .retryLater }
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
