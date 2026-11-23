//
//  VideoModels.swift
//  MakeReady
//
//  Video models, API responses, errors, and upload progress.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

// MARK: - Video Models

/// Video status from Cloudflare Stream
enum VideoStatus: String, Codable {
    case pending
    case ready
    case error

    var displayName: String {
        switch self {
        case .pending: return "Processing"
        case .ready: return "Ready"
        case .error: return "Error"
        }
    }
}

/// Video model matching server's Video Prisma model
struct Video: Codable, Identifiable {
    let id: String
    var title: String?
    var description: String?
    let cloudflareUid: String
    let playbackUrl: String
    var thumbnailUrl: String?
    var duration: Int?  // Duration in seconds
    var status: String
    let userId: String
    var isActive: Bool?
    let createdAt: Date
    var updatedAt: Date

    // video-recorder D27: every property below is Optional, so a cache written before them still decodes.
    var transcript: String?
    var transcriptSegments: [VideoTranscriptSegment]?
    var transcriptStatus: VideoTranscriptStatus?
    /// `on_device` or `server`; nil until a transcript exists.
    var transcriptSource: String?
    /// Set when the leader removed the video from the Library; the video itself stays (D17).
    var libraryRemovedAt: Date?
    /// Distinct lesson activities using the video, from `GET /api/videos/:id` only.
    var lessonUseCount: Int?

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Video status as enum
    var videoStatus: VideoStatus {
        VideoStatus(rawValue: status) ?? .pending
    }

    /// Display title (falls back to "Untitled Video")
    var displayTitle: String {
        title ?? "Untitled Video"
    }
}

/// Where a video's transcript stands. `none` is a video with no audio to transcribe.
enum VideoTranscriptStatus: String, Codable {
    case none
    case pending
    case ready
    case failed
}

/// One timed line of a transcript, in ms from the start of the exported file (D10).
struct VideoTranscriptSegment: Codable, Equatable {
    let text: String
    let startMs: Int
    let endMs: Int
}

/// A Library row: `GET /api/videos/library` (D20). The full `Video` lives in `videos` (D27).
struct VideoSummary: Codable, Identifiable, Equatable {
    let id: String
    var title: String?
    var thumbnailUrl: String?
    var playbackUrl: String
    var duration: Int?
    var status: String
    var transcriptStatus: VideoTranscriptStatus
    var transcriptPreview: String?
    let createdAt: Date

    /// Video status as enum
    var videoStatus: VideoStatus {
        VideoStatus(rawValue: status) ?? .pending
    }
}

/// The ordered ids of the Library's video list and where the next page starts (D20, R-28).
/// Page 1 replaces the ids, so videos removed or deleted elsewhere drop out; later pages append.
struct VideoLibraryWindow: Codable, Equatable {
    /// One `GET /api/videos/library` response, without its rows.
    struct Page: Equatable {
        var ids: [String]
        var nextCursor: String?
        var hasMore: Bool
    }

    var ids: [String] = []
    var nextCursor: String?
    var hasMore: Bool = false
    /// The search text the ids answer, nil for the whole Library.
    var query: String?

    func replacing(with page: Page) -> VideoLibraryWindow {
        VideoLibraryWindow(ids: page.ids, nextCursor: page.nextCursor, hasMore: page.hasMore, query: query)
    }

    func appending(page: Page) -> VideoLibraryWindow {
        let known = Set(ids)
        return VideoLibraryWindow(
            ids: ids + page.ids.filter { !known.contains($0) },
            nextCursor: page.nextCursor, hasMore: page.hasMore, query: query
        )
    }

    /// The window as disk keeps it: the first `limit` ids. A trimmed window has no cursor for what
    /// follows, so it keeps `hasMore` and drops `nextCursor`; the next launch's page 1 replaces it.
    func capped(to limit: Int) -> VideoLibraryWindow {
        guard ids.count > limit else { return self }
        return VideoLibraryWindow(ids: Array(ids.prefix(limit)), nextCursor: nil, hasMore: true, query: query)
    }
}

// MARK: - Video API Response Models

struct UploadUrlResponse: Codable {
    let success: Bool
    let data: UploadUrlData?
    let error: String?
}

struct UploadUrlData: Codable {
    let uploadUrl: String
    let uid: String
}

struct VideoResponse: Codable {
    let success: Bool
    let data: Video?
    let error: String?
}

struct VideoListResponse: Codable {
    let success: Bool
    let data: [Video]?
    let count: Int?
    let error: String?
}

struct DeleteVideoResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Video Errors

enum VideoError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case invalidResponse
    case uploadFailed(String)
    case videoNotReady

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage videos."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .videoNotReady:
            return "Video is still processing. Please try again later."
        }
    }
}

// MARK: - Upload Progress

struct UploadProgress {
    let bytesUploaded: Int64
    let totalBytes: Int64

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }

    var percentage: Int {
        Int(progress * 100)
    }
}
