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

    func upload(fileURL: URL, to url: URL) async throws -> Int {
        let boundary = "MakeReady-\(UUID().uuidString)"
        let body = FileManager.default.temporaryDirectory.appendingPathComponent("stream-upload-\(UUID().uuidString).body")
        try Self.writeMultipartBody(file: fileURL, boundary: boundary, to: body)
        defer {
            do {
                try FileManager.default.removeItem(at: body)
            } catch {
                Log.media.error("upload body not removable: \(error.localizedDescription, privacy: .public)")
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let task = await MainActor.run { UIApplication.shared.beginBackgroundTask(withName: "video-upload") }
        do {
            let (_, response) = try await session.upload(for: request, fromFile: body)
            await MainActor.run { UIApplication.shared.endBackgroundTask(task) }
            return (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            await MainActor.run { UIApplication.shared.endBackgroundTask(task) }
            throw error
        }
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
            try output.write(contentsOf: chunk)
        }
        try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
    }
}
