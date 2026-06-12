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
