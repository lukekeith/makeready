//
//  MediaModels.swift
//  MakeReady
//
//  Media library models, organization lookup, and tag-count models.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

// MARK: - Media Library Models

/// Media type for filtering
enum MediaType: String, Codable {
    case video
    case photo
    case document
    case audio

    var displayName: String {
        switch self {
        case .video: return "Video"
        case .photo: return "Photo"
        case .document: return "Document"
        case .audio: return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .video: return "play.fill"
        case .photo: return "photo"
        case .document: return "doc.fill"
        case .audio: return "waveform"
        }
    }
}

/// A media item from the organization media library
struct MediaLibraryItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var url: String
    var type: String              // "photo", "video", "document", "audio"
    var mimeType: String?
    var fileSize: Int?
    var thumbnailUrl: String?
    var uploadStatus: String      // "pending", "processing", "ready", "error"
    var duration: Int?            // seconds (videos/audio)
    var tags: [String]
    var usageCount: Int
    var uploader: MediaUploader?
    var video: MediaVideo?
    let createdAt: Date
    var updatedAt: Date

    /// Parsed media type
    var mediaType: MediaType {
        MediaType(rawValue: type) ?? .document
    }

    /// Whether the media is ready
    var isReady: Bool {
        uploadStatus == "ready"
    }

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Display title
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    static func == (lhs: MediaLibraryItem, rhs: MediaLibraryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Media uploader info
struct MediaUploader: Codable, Hashable {
    let id: String
    let name: String
}

/// Video details attached to a media item
struct MediaVideo: Codable, Hashable {
    let id: String
    var playbackUrl: String?
    var duration: Int?
    var status: String?
}

/// API response for media library listing
struct MediaLibraryResponse: Codable {
    let success: Bool?
    let data: [MediaLibraryItem]?
    let total: Int?
    let page: Int?
    let limit: Int?
    let totalPages: Int?
    /// Keyset paging (media plan M1.5). Optional so old servers decode fine.
    let nextCursor: String?
    let hasMore: Bool?
    let error: String?
}

/// API response for media detail
struct MediaDetailResponse: Codable {
    let success: Bool?
    let data: MediaDetailItem?
    let error: String?
}

/// Full media detail with tags, video info, and usage summary
struct MediaDetailItem: Codable {
    let id: String
    let title: String?
    let description: String?
    let url: String?
    let type: String?
    let mimeType: String?
    let fileSize: Int?
    let thumbnailUrl: String?
    let uploadStatus: String?
    let duration: Int?
    let tags: [String]?
    let usageCount: Int?       // from library list endpoint
    let usages: [MediaUsage]?  // from detail endpoint
    let uploader: MediaUploader?
    let video: MediaVideo?
    let organization: MediaOrganization?
    let width: Int?
    let height: Int?
    let aspectRatio: String?
    let dominantColor: String?
    let altText: String?
    let source: String?
    let createdAt: Date?
    let updatedAt: Date?

    /// Parsed media type
    var mediaType: MediaType {
        MediaType(rawValue: type ?? "photo") ?? .document
    }

    /// Formatted duration string
    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted file size
    var formattedFileSize: String? {
        guard let size = fileSize, size > 0 else { return nil }
        return ModelFormatters.fileSize.string(fromByteCount: Int64(size))
    }

    /// Display title
    var displayTitle: String {
        let t = title ?? ""
        return t.isEmpty ? "Untitled" : t
    }

    /// Resolved usage count (from either usageCount or usages array length)
    var resolvedUsageCount: Int {
        usageCount ?? usages?.count ?? 0
    }

    /// Dimensions string
    var formattedDimensions: String? {
        guard let w = width, let h = height, w > 0, h > 0 else { return nil }
        return "\(w) × \(h)"
    }
}

/// Organization info on a media detail
struct MediaOrganization: Codable {
    let id: String
    let name: String
}

/// API response for media usages
struct MediaUsagesResponse: Codable {
    let success: Bool?
    let data: [MediaUsage]?
    let error: String?
}

/// A single usage record — where media is referenced
struct MediaUsage: Codable, Identifiable {
    let id: String
    let mediaId: String?
    let usageType: String      // "LESSON_ACTIVITY", "PROGRAM_COVER", "GROUP_COVER", "POST"
    let resourceId: String?
    let resourceName: String?
    let createdAt: Date?

    /// Human-readable resource type
    var displayResourceType: String {
        switch usageType {
        case "LESSON_ACTIVITY": return "Lesson Activity"
        case "PROGRAM_COVER": return "Study Program Cover"
        case "GROUP_COVER": return "Group Cover"
        case "POST": return "Post"
        case "EVENT": return "Event"
        default: return usageType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Icon for the resource type
    var resourceIcon: String {
        switch usageType {
        case "LESSON_ACTIVITY": return "list.bullet"
        case "PROGRAM_COVER": return "book.fill"
        case "GROUP_COVER": return "person.3.fill"
        case "POST": return "text.bubble.fill"
        case "EVENT": return "calendar"
        default: return "link"
        }
    }
}

/// API response for organization lookup
struct OrganizationResponse: Codable {
    let success: Bool?
    let data: OrganizationData?
    let error: String?
}

struct OrganizationData: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var ownerId: String?
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - Tag-Count Models

/// Single tag with its usage count, returned by /api/programs/tags and
/// /api/media/tags. Drives the chip rows inside the tags filter dropdown.
struct TagCount: Codable, Identifiable, Hashable {
    let tag: String
    let count: Int
    var id: String { tag }
}

struct TagsResponse: Codable {
    let success: Bool
    let tags: [TagCount]?
    let error: String?
}
