//
//  VideoStreamTransport.swift
//  MakeReady
//
//  The upload to Cloudflare Stream's direct-upload URL (video-recorder D12). A plain ephemeral
//  `URLSession` (no cookie jar, no cache) streams a multipart body from disk inside a background
//  task, so an upload that starts as the app leaves the foreground can finish. The video is never
//  loaded into `Data`: the body file is built in 1 MB chunks and the session reads it from there.
//  Like `MemoPutTransport` it never goes through `APIClient`, which would add the session cookie.
//

import Foundation
import UIKit

protocol VideoStreamTransport {
    /// POSTs the file to `url` as multipart form data (`file` field); returns the HTTP status.
    func upload(fileURL: URL, to url: URL) async throws -> Int
}

struct URLSessionVideoStreamTransport: VideoStreamTransport {
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    /// The background task opens first, so it covers the body copy too; if iOS is about to suspend the
    /// app the expiration handler cancels the transfer (the queue retries) and ends the task.
    func upload(fileURL: URL, to url: URL) async throws -> Int {
        let work = BackgroundWork()
        await work.begin(name: "video-upload")
        let task = Task { try await send(fileURL: fileURL, to: url) }
        work.attach(task)
        do {
            let status = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            await work.end()
            return status
        } catch {
            await work.end()
            throw error
        }
    }

    private func send(fileURL: URL, to url: URL) async throws -> Int {
        let boundary = "MakeReady-\(UUID().uuidString)"
        let body = FileManager.default.temporaryDirectory.appendingPathComponent("stream-upload-\(UUID().uuidString).body")
        defer {
            do {
                try FileManager.default.removeItem(at: body)
            } catch {
                // Silent: a cancelled copy may never have created the file.
                Log.media.debug("upload body not removed: \(error.localizedDescription, privacy: .public)")
            }
        }
        try Self.writeMultipartBody(file: fileURL, boundary: boundary, to: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, fromFile: body)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    /// Writes `--boundary` headers, the file's bytes and the closing boundary to `body`, copying the
    /// file in 1 MB chunks so memory stays flat however long the video is.
    static func writeMultipartBody(file: URL, boundary: String, to body: URL) throws {
        FileManager.default.createFile(atPath: body.path, contents: nil)
        let output = try FileHandle(forWritingTo: body)
        defer { try? output.close() }
        let head = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"video.mp4\"\r\nContent-Type: video/mp4\r\n\r\n"
        try output.write(contentsOf: Data(head.utf8))
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            try output.write(contentsOf: chunk)
        }
        try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
    }
}

/// One `beginBackgroundTask`, ended exactly once, whose expiration handler cancels the transfer.
private final class BackgroundWork: @unchecked Sendable {
    private let lock = NSLock()
    private var identifier = UIBackgroundTaskIdentifier.invalid
    private var transfer: Task<Int, Error>?
    private var expired = false
    private var ended = false

    @MainActor
    func begin(name: String) {
        let id = UIApplication.shared.beginBackgroundTask(withName: name) { [self] in
            cancelTransfer()
            end()
        }
        lock.withLock { identifier = id }
    }

    func attach(_ task: Task<Int, Error>) {
        let cancelNow = lock.withLock { () -> Bool in
            transfer = task
            return expired
        }
        if cancelNow { task.cancel() }
    }

    private func cancelTransfer() {
        let task = lock.withLock { () -> Task<Int, Error>? in
            expired = true
            return transfer
        }
        task?.cancel()
    }

    @MainActor
    func end() {
        let id = lock.withLock { () -> UIBackgroundTaskIdentifier? in
            guard !ended else { return nil }
            ended = true
            return identifier
        }
        if let id { UIApplication.shared.endBackgroundTask(id) }
    }
}
