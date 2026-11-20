//
//  MemoPutTransport.swift
//  MakeReady
//
//  The presigned PUT to R2 (D40). It never goes through `APIClient`: that prefixes the base URL
//  and adds the session cookie, which would break the signature and leak the cookie to R2.
//

import Foundation
import UIKit

protocol MemoPutTransport {
    /// PUTs the file's bytes to `url` with `headers`; returns the HTTP status.
    func put(fileURL: URL, to url: URL, headers: [String: String]) async throws -> Int
}

/// A plain `URLSession` (ephemeral: no cookie jar, no cache) wrapped in a background task so a
/// PUT that starts as the app leaves the foreground can finish. No background session in v1.
struct URLSessionMemoPutTransport: MemoPutTransport {
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func put(fileURL: URL, to url: URL, headers: [String: String]) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (name, value) in headers where name.caseInsensitiveCompare("Content-Length") != .orderedSame {
            // Silent: URLSession derives Content-Length from the file itself.
            request.setValue(value, forHTTPHeaderField: name)
        }
        let task = await MainActor.run { UIApplication.shared.beginBackgroundTask(withName: "memo-put") }
        do {
            let (_, response) = try await session.upload(for: request, fromFile: fileURL)
            await MainActor.run { UIApplication.shared.endBackgroundTask(task) }
            return (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            await MainActor.run { UIApplication.shared.endBackgroundTask(task) }
            throw error
        }
    }
}
