//
//  VideoActions.swift
//  MakeReady
//
//  Actions for video operations.
//  Handles API calls, state mutations, and upload progress.
//

import Foundation
import AVFoundation
import Photos
import UIKit

/// Actions for video library management and uploads.
struct VideoActions {

private let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // Shared upload state (for cancellation)
    private static var currentUploadTask: URLSessionUploadTask?

    // MARK: - Load Videos

    /// Load user's video library
    @MainActor
    func loadVideos(forceRefresh: Bool = false) async throws {
        if state.hasCachedVideos && !forceRefresh {
            state.loadingStates.startLoading(.videos, hasCachedData: true)
            Task {
                do {
                    try await fetchVideos()
                } catch {
                    state.recordError(error, context: "VideoActions.loadVideos (background refresh)")
                }
            }
            return
        }

        state.loadingStates.startLoading(.videos, hasCachedData: state.hasCachedVideos)
        try await fetchVideos()
    }

    @MainActor
    private func fetchVideos() async throws {
        defer {
            state.loadingStates.finishLoading(.videos)
        }

        let response: VideoListResponse = try await api.get("/api/videos/me", responseType: VideoListResponse.self)

        guard response.success, let videos = response.data else {
            throw APIError.serverError(response.error ?? "Failed to fetch videos")
        }

        state.videos.replaceAll(videos)
        state.persist()

        NSLog("🎬 VideoActions: Loaded \(videos.count) videos")
    }

    // MARK: - Get Single Video

    /// Get a video by ID
    @MainActor
    func getVideo(id: String) async throws -> Video {
        let response: VideoResponse = try await api.get("/api/videos/\(id)", responseType: VideoResponse.self)

        guard response.success, let video = response.data else {
            throw APIError.serverError(response.error ?? "Failed to get video")
        }

        state.videos.upsert(video)
        state.persist()

        return video
    }

    // MARK: - Upload Flow

    /// Get a direct upload URL from Cloudflare
    func getUploadUrl(maxDuration: Int = 300, title: String? = nil) async throws -> (uploadUrl: String, uid: String) {
        var body: [String: Any] = ["maxDurationSeconds": maxDuration]
        if let title = title {
            body["title"] = title
        }

        let response: UploadUrlResponse = try await api.post(
            "/api/videos/upload-url",
            body: body,
            responseType: UploadUrlResponse.self
        )

        guard response.success, let data = response.data else {
            throw APIError.serverError(response.error ?? "Failed to get upload URL")
        }

        return (data.uploadUrl, data.uid)
    }

    /// Create video record in database after upload
    @MainActor
    func createVideoRecord(cloudflareUid: String, title: String? = nil, description: String? = nil,
                           source: VideoSource? = nil, transcript: VideoTranscript? = nil) async throws -> Video {
        var body: [String: Any] = ["cloudflareUid": cloudflareUid]
        if let source {
            body["source"] = source.rawValue
        }
        if let transcript {
            // D24: trimmed to the server's limits, never refused.
            let fit = VideoTranscriptLimits.fit(transcript)
            body["transcript"] = fit.text
            body["transcriptSegments"] = fit.segments.map { ["text": $0.text, "startMs": $0.startMs, "endMs": $0.endMs] as [String: Any] }
        }
        if let title = title {
            body["title"] = title
        }
        if let description = description {
            body["description"] = description
        }

        let response: VideoResponse = try await api.post("/api/videos", body: body, responseType: VideoResponse.self)

        guard response.success, let video = response.data else {
            throw APIError.serverError(response.error ?? "Failed to create video record")
        }

        state.videos.upsert(video)
        state.persist()

        return video
    }

    // MARK: - Library window (D20, D27)

    /// `GET /api/videos/library`. No cursor replaces the window (page 1), so videos removed or deleted
    /// elsewhere drop out; a cursor appends. Both upsert `libraryVideos`.
    @MainActor
    func loadLibrary(cursor: String?, q: String?) async throws {
        var endpoint = "/api/videos/library?limit=\(Self.libraryPageSize)"
        if let cursor { endpoint += "&cursor=\(Self.encoded(cursor))" }
        if let q, !q.isEmpty { endpoint += "&q=\(Self.encoded(q))" }

        let response: VideoLibraryResponse = try await api.get(endpoint, responseType: VideoLibraryResponse.self)
        guard response.success, let rows = response.data else {
            throw APIError.serverError(response.error ?? "Failed to load the video library")
        }

        state.libraryVideos.upsertMany(rows)
        let page = VideoLibraryWindow.Page(ids: rows.map(\.id), nextCursor: response.nextCursor, hasMore: response.hasMore ?? false)
        let query = (q?.isEmpty ?? true) ? nil : q
        if cursor == nil {
            state.videoLibraryWindow = VideoLibraryWindow(query: query).replacing(with: page)
        } else {
            state.videoLibraryWindow = state.videoLibraryWindow.appending(page: page)
        }
        state.persist()
    }

    /// The next page of the window the Library shows. A window with no cursor (a restored, capped one)
    /// has no page to append to, so it loads page 1; a window with no more pages loads nothing.
    @MainActor
    func loadNextLibraryPage() async throws {
        let window = state.videoLibraryWindow
        guard window.hasMore else { return }
        try await loadLibrary(cursor: window.nextCursor, q: window.query)
    }

    // MARK: - Detail, rename, delete or remove

    /// `GET /api/videos/:id` into `videos`: the transcript, segments and `lessonUseCount`.
    @MainActor
    func loadDetail(id: String) async throws {
        _ = try await getVideo(id: id)
    }

    /// `PATCH /api/videos/:id` with the title; the Library row follows in the same call (D27).
    @MainActor
    func rename(id: String, title: String) async throws {
        let video = try await updateVideo(id: id, title: title)
        _ = state.libraryVideos.update(id) { $0.title = video.title }
        state.persist()
    }

    /// `POST /api/videos/:id/remove-from-library`: the video leaves the Library but stays in lessons (D17).
    @MainActor
    func removeFromLibrary(id: String) async throws {
        let response: RemoveFromLibraryResponse = try await api.post(
            "/api/videos/\(id)/remove-from-library",
            responseType: RemoveFromLibraryResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to remove the video from your Library")
        }
        dropFromLibrary(id: id)
    }

    /// Which confirm a delete shows (D17): from `lessonUseCount` on `GET /api/videos/:id`.
    /// A failed read throws, for the caller's error banner, and changes nothing.
    @MainActor
    func deleteDecision(id: String) async throws -> VideoDeleteDecision {
        let video = try await getVideo(id: id)
        let count = video.lessonUseCount ?? 0
        return count > 0 ? .removeFromLibrary(lessonCount: count) : .delete
    }

    /// Runs the call the decision names; the id leaves both stores and the window in the same Action (D27).
    @MainActor
    func deleteOrRemove(id: String, decision: VideoDeleteDecision) async throws {
        switch decision {
        case .delete: try await deleteVideo(id: id)
        case .removeFromLibrary: try await removeFromLibrary(id: id)
        }
        dropFromLibrary(id: id)
    }

    @MainActor
    private func dropFromLibrary(id: String) {
        _ = state.videos.remove(id)
        _ = state.libraryVideos.remove(id)
        state.videoLibraryWindow.ids.removeAll { $0 == id }
        state.persist()
    }

    private static let libraryPageSize = 50

    private static func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
    }

    // MARK: - Update Video

    /// Update video metadata
    @MainActor
    func updateVideo(id: String, title: String? = nil, description: String? = nil) async throws -> Video {
        var body: [String: Any] = [:]
        if let title = title {
            body["title"] = title
        }
        if let description = description {
            body["description"] = description
        }

        let response: VideoResponse = try await api.patch("/api/videos/\(id)", body: body, responseType: VideoResponse.self)

        guard response.success, let video = response.data else {
            throw APIError.serverError(response.error ?? "Failed to update video")
        }

        state.videos.upsert(video)
        state.persist()

        return video
    }

    /// Refresh video status from Cloudflare
    @MainActor
    func refreshVideoStatus(id: String) async throws -> Video {
        let response: VideoResponse = try await api.post(
            "/api/videos/\(id)/refresh",
            responseType: VideoResponse.self
        )

        guard response.success, let video = response.data else {
            throw APIError.serverError(response.error ?? "Failed to refresh video status")
        }

        state.videos.upsert(video)
        state.persist()

        return video
    }

    // MARK: - Delete Video

    /// Delete a video
    @MainActor
    func deleteVideo(id: String) async throws {
        let response: DeleteVideoResponse = try await api.delete(
            "/api/videos/\(id)",
            responseType: DeleteVideoResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete video")
        }

        state.videos.remove(id)
        state.persist()

        NSLog("🎬 VideoActions: Deleted video \(id)")
    }

    // MARK: - Poll for Ready Status

    /// Poll for video processing to complete
    @MainActor
    func waitForVideoReady(video: Video, maxAttempts: Int = 15, delaySeconds: Double = 2.0) async -> Video {
        guard video.videoStatus == .pending else {
            return video
        }

        NSLog("🎬 VideoActions: Waiting for video processing...")

        for attempt in 1...maxAttempts {
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))

                let refreshed = try await refreshVideoStatus(id: video.id)

                if refreshed.videoStatus == .ready {
                    NSLog("🎬 VideoActions: Video ready after \(attempt) attempts")
                    return refreshed
                } else if refreshed.videoStatus == .error {
                    NSLog("❌ VideoActions: Video processing failed")
                    return refreshed
                }

                NSLog("🎬 VideoActions: Still processing... (attempt \(attempt)/\(maxAttempts))")
            } catch {
                NSLog("❌ VideoActions: Error polling video status: \(error.localizedDescription)")
            }
        }

        NSLog("⚠️ VideoActions: Timeout waiting for video processing")
        return video
    }

    // MARK: - Complete Upload Flow

    /// Upload a video from a local URL, create database record, and wait for processing
    @MainActor
    func uploadAndCreateVideo(from videoURL: URL, title: String? = nil, description: String? = nil, progressHandler: ((UploadProgress) -> Void)? = nil) async throws -> Video {
        // Step 1: Get upload URL
        let (uploadUrl, uid) = try await getUploadUrl(title: title)

        // Step 2: Upload to Cloudflare
        try await uploadVideo(from: videoURL, to: uploadUrl, progressHandler: progressHandler)

        // Step 3: Create database record
        var video = try await createVideoRecord(cloudflareUid: uid, title: title, description: description)

        // Step 4: Poll for video processing completion (for thumbnail generation)
        video = await waitForVideoReady(video: video)

        return video
    }

    /// Upload video data to Cloudflare
    func uploadVideo(from videoURL: URL, to uploadUrl: String, progressHandler: ((UploadProgress) -> Void)? = nil) async throws {
        guard let url = URL(string: uploadUrl) else {
            throw VideoError.uploadFailed("Invalid upload URL")
        }

        await MainActor.run {
            state.loadingStates.startLoading("video-upload", hasCachedData: false)
        }

        defer {
            Task { @MainActor in
                state.loadingStates.finishLoading("video-upload")
                state.uploadProgress = nil
            }
        }

        // Read video file data
        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            throw VideoError.uploadFailed("Failed to read video file: \(error.localizedDescription)")
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var bodyData = Data()

        // Add file field
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"video.mov\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
        bodyData.append(videoData)
        bodyData.append("\r\n".data(using: .utf8)!)
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Get total size for progress
        let totalBytes = Int64(bodyData.count)

        // Create upload session with delegate for progress
        let configuration = URLSessionConfiguration.default
        let delegate = UploadDelegate(totalBytes: totalBytes) { progress in
            Task { @MainActor in
                AppState.shared.uploadProgress = progress
                progressHandler?(progress)
            }
        }

        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        do {
            let (responseData, response) = try await session.upload(for: request, from: bodyData)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to get error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let errors = errorJson["errors"] as? [[String: Any]],
                   let firstError = errors.first,
                   let message = firstError["message"] as? String {
                    throw VideoError.uploadFailed(message)
                }
                throw VideoError.uploadFailed("Upload failed with status \(httpResponse.statusCode)")
            }

            NSLog("🎬 VideoActions: Upload completed successfully")
        } catch let error as VideoError {
            throw error
        } catch {
            throw VideoError.networkError(error)
        }
    }

    /// Cancel current upload
    func cancelUpload() {
        VideoActions.currentUploadTask?.cancel()
        VideoActions.currentUploadTask = nil
        Task { @MainActor in
            state.loadingStates.finishLoading("video-upload")
            state.uploadProgress = nil
        }
    }

    // MARK: - Video Export

    /// Export a video file URL with correct orientation applied
    func exportVideoWithOrientation(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        return try await withCheckedThrowingContinuation { continuation in
            exportAsset(asset) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Export a PHAsset to a local file URL for upload
    func exportAssetToURL(_ asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                guard let avAsset = avAsset else {
                    let errorInfo = info?[PHImageErrorKey] as? Error
                    continuation.resume(throwing: VideoError.uploadFailed("Failed to load video asset: \(errorInfo?.localizedDescription ?? "Unknown error")"))
                    return
                }

                // Always export through AVAssetExportSession to apply orientation transform
                self.exportAsset(avAsset) { result in
                    continuation.resume(with: result)
                }
            }
        }
    }

    /// Export an AVAsset to a file with correct orientation applied
    private func exportAsset(_ asset: AVAsset, completion: @escaping (Result<URL, Error>) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")

        Task {
            do {
                // Auto-configure video composition from asset (handles orientation transform)
                let videoComposition = try await AVVideoComposition.videoComposition(withPropertiesOf: asset)

                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                    completion(.failure(VideoError.uploadFailed("Failed to create export session")))
                    return
                }

                exportSession.videoComposition = videoComposition
                exportSession.shouldOptimizeForNetworkUse = true

                try await exportSession.export(to: tempURL, as: .mov)

                NSLog("📹 Export completed successfully")
                completion(.success(tempURL))
            } catch {
                NSLog("📹 Export error: \(error)")
                completion(.failure(VideoError.uploadFailed("Failed to load video track: \(error.localizedDescription)")))
            }
        }
    }
}

// MARK: - Library types

/// What deleting a Library video does (D17): delete it, or take it out of the Library when lessons use it.
enum VideoDeleteDecision: Equatable {
    case delete
    case removeFromLibrary(lessonCount: Int)

    /// The confirm's title, word for word from the spec.
    var confirmTitle: String {
        switch self {
        case .delete:
            return "Delete this video?"
        case .removeFromLibrary(let n):
            return "This video is used in \(n) lesson activities. It will stay in them and leave your Library."
        }
    }
}

/// `GET /api/videos/library`.
struct VideoLibraryResponse: Decodable {
    let success: Bool
    let data: [VideoSummary]?
    let nextCursor: String?
    let hasMore: Bool?
    let error: String?
}

/// `POST /api/videos/:id/remove-from-library`.
struct RemoveFromLibraryResponse: Decodable {
    let success: Bool
    let error: String?
}

private extension CharacterSet {
    /// Query-value characters left as they are; `&`, `=`, `+`, `#` and spaces are escaped.
    static let urlQueryValueAllowed: CharacterSet = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#"))
}

// MARK: - Upload Delegate

private class UploadDelegate: NSObject, URLSessionTaskDelegate {
    let totalBytes: Int64
    let progressHandler: (UploadProgress) -> Void

    init(totalBytes: Int64, progressHandler: @escaping (UploadProgress) -> Void) {
        self.totalBytes = totalBytes
        self.progressHandler = progressHandler
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = UploadProgress(
            bytesUploaded: totalBytesSent,
            totalBytes: totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : totalBytes
        )
        progressHandler(progress)
    }
}
