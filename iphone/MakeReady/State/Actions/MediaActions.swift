//
//  MediaActions.swift
//  MakeReady
//
//  Actions for media library operations.
//  Handles loading, filtering, and deleting media items.
//

import Foundation
import UIKit
import ImageIO
import MobileCoreServices

/// Actions for media library CRUD operations.
struct MediaActions {

    @MainActor private var state: AppState { AppState.shared }
    private let api = APIClient.shared

    // MARK: - Load Media Library

    /// Load media library items, using cache if available
    /// - Parameters:
    ///   - type: Optional media type filter ("video", "photo", "audio")
    ///   - forceRefresh: If true, always fetch from API
    ///   - tags: Tags to filter by (multi-select OR semantics on the server)
    ///   - leaders: Group-leader user IDs to filter by (multi-select OR)
    @MainActor
    func loadLibrary(
        type: String? = nil,
        tags: [String]? = nil,
        leaders: [String]? = nil,
        forceRefresh: Bool = false
    ) async throws {
        let hasFilters = type != nil || (tags?.isEmpty == false) || (leaders?.isEmpty == false)

        // If we have cached data, no filters, and not forcing refresh, show
        // cached and refresh in the background.
        if state.hasCachedMedia && !forceRefresh && !hasFilters {
            state.loadingStates.startLoading(.media, hasCachedData: true)
            Task {
                do {
                    try await fetchLibrary(type: type, tags: tags, leaders: leaders)
                } catch {
                    NSLog("❌ MediaActions: Background refresh failed: \(error.localizedDescription)")
                }
            }
            return
        }

        state.loadingStates.startLoading(.media, hasCachedData: state.hasCachedMedia)
        try await fetchLibrary(type: type, tags: tags, leaders: leaders)
    }

    /// Fetch media library from API and update state
    @MainActor
    private func fetchLibrary(
        type: String? = nil,
        tags: [String]? = nil,
        leaders: [String]? = nil
    ) async throws {
        defer {
            state.loadingStates.finishLoading(.media)
        }

        guard let orgId = state.organizationId else {
            NSLog("⚠️ MediaActions: No organization ID available")
            return
        }

        var endpoint = "/api/organizations/\(orgId)/media/library?limit=100"
        if let type = type {
            endpoint += "&type=\(type)"
        }
        if let tags, !tags.isEmpty {
            let joined = tags.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            endpoint += "&tags=\(encoded)"
        }
        if let leaders, !leaders.isEmpty {
            let joined = leaders.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            endpoint += "&leaders=\(encoded)"
        }

        let response: MediaLibraryResponse = try await api.get(endpoint, responseType: MediaLibraryResponse.self)

        guard let items = response.data else {
            throw APIError.serverError(response.error ?? "Failed to load media library")
        }

        state.mediaLibrary.replaceAll(items)
        state.mediaLibraryTotal = response.total ?? items.count
        state.persist()
        NSLog("📸 MediaActions: Loaded \(items.count) media items (total: \(state.mediaLibraryTotal))")
    }

    // MARK: - Delete Media

    /// Delete a media item
    @MainActor
    func deleteMedia(id: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/media/\(id)",
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete media")
        }

        state.mediaLibrary.remove(id)
        state.persist()
        NSLog("📸 MediaActions: Deleted media \(id)")
    }

    // MARK: - Media Detail

    /// Fetch full media detail (tags, video info, usage summary)
    func loadDetail(id: String) async throws -> MediaDetailItem {
        let response: MediaDetailResponse = try await api.get(
            "/api/media/\(id)/detail",
            responseType: MediaDetailResponse.self
        )

        guard let item = response.data else {
            throw APIError.serverError(response.error ?? "Failed to load media detail")
        }

        return item
    }

    // MARK: - Media Usages

    /// Fetch where a media item is used
    func loadUsages(id: String) async throws -> [MediaUsage] {
        let response: MediaUsagesResponse = try await api.get(
            "/api/media/\(id)/usages",
            responseType: MediaUsagesResponse.self
        )

        return response.data ?? []
    }

    // MARK: - Update Media

    /// Update media metadata (title, description)
    @MainActor
    func updateMedia(id: String, title: String? = nil, description: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let description = description { body["description"] = description }

        struct UpdateResponse: Decodable {
            let success: Bool
            let data: MediaLibraryItem?
            let error: String?
        }

        let response: UpdateResponse = try await api.patch(
            "/api/media/\(id)",
            body: body,
            responseType: UpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update media")
        }

        // Refresh the item in state if returned
        if let updated = response.data {
            state.mediaLibrary.upsert(updated)
            state.persist()
        }

        NSLog("📸 MediaActions: Updated media \(id)")
    }

    /// Add tags to a media item
    @MainActor
    func addTags(mediaId: String, tags: [String]) async throws {
        let body: [String: Any] = ["tags": tags]
        let response: APISuccessResponse = try await api.post(
            "/api/media/\(mediaId)/tags",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to add tags")
        }
    }

    /// Remove tags from a media item
    @MainActor
    func removeTags(mediaId: String, tags: [String]) async throws {
        let body: [String: Any] = ["tags": tags]
        let response: APISuccessResponse = try await api.request(
            endpoint: "/api/media/\(mediaId)/tags",
            method: "DELETE",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to remove tags")
        }
    }

    /// Sync tags (diff old vs new, add/remove as needed)
    @MainActor
    func syncTags(mediaId: String, oldTags: [String], newTags: [String]) async throws {
        let toAdd = newTags.filter { !oldTags.contains($0) }
        let toRemove = oldTags.filter { !newTags.contains($0) }

        if !toAdd.isEmpty {
            try await addTags(mediaId: mediaId, tags: toAdd)
        }
        if !toRemove.isEmpty {
            try await removeTags(mediaId: mediaId, tags: toRemove)
        }
    }

    // MARK: - Upload Photo

    /// Lightweight shape of the `/media/upload` response — the server returns
    /// a raw Prisma Media row (no `tags[]`/`usageCount`), so we avoid forcing
    /// the full `MediaLibraryItem` decode here.
    struct UploadedPhoto: Decodable {
        let id: String
        let url: String
        let thumbnailUrl: String?
    }

    /// Upload a UIImage to the user's organization media library. The server
    /// stores it on R2 + automatically tags it via Claude Vision (fire-and-forget).
    /// Returns an UploadedPhoto; use `.url` as the background image URL.
    @MainActor
    func uploadPhoto(image: UIImage, title: String = "Photo") async throws -> UploadedPhoto {
        guard let orgId = state.organizationId else {
            throw APIError.serverError("No organization context — cannot upload photo")
        }

        // Encode JPEG without EXIF metadata via ImageIO.
        let resized = Self.resizeIfNeeded(image, maxDimension: 2000)
        guard let cgImage = resized.cgImage else {
            throw APIError.serverError("Failed to read image data")
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            throw APIError.serverError("Failed to create JPEG destination")
        }
        CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw APIError.serverError("Failed to encode JPEG")
        }
        let base64 = (data as Data).base64EncodedString()

        let body: [String: Any] = [
            "type":      "photo",
            "title":     title,
            "imageData": base64,
        ]

        struct UploadResponse: Decodable {
            let success: Bool
            let data: UploadedPhoto?
            let error: String?
        }

        let response: UploadResponse = try await api.post(
            "/api/organizations/\(orgId)/media/upload",
            body: body,
            responseType: UploadResponse.self
        )

        guard response.success, let item = response.data else {
            throw APIError.serverError(response.error ?? "Failed to upload photo")
        }

        NSLog("📸 MediaActions: Uploaded photo \(item.id) → \(item.url)")
        return item
    }

    /// Downscale to keep upload sizes sane.
    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        if max(w, h) <= maxDimension { return image }
        let scale = maxDimension / max(w, h)
        let target = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    // MARK: - Search Media

    /// Search media library by text query (server searches title, description, and tags)
    @MainActor
    func searchLibrary(
        query: String,
        type: String? = nil,
        tags: [String]? = nil,
        leaders: [String]? = nil
    ) async throws {
        guard let orgId = state.organizationId else { return }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var endpoint = "/api/organizations/\(orgId)/media/library?limit=100&q=\(encodedQuery)"
        if let type = type {
            endpoint += "&type=\(type)"
        }
        if let tags, !tags.isEmpty {
            let joined = tags.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            endpoint += "&tags=\(encoded)"
        }
        if let leaders, !leaders.isEmpty {
            let joined = leaders.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            endpoint += "&leaders=\(encoded)"
        }

        let response: MediaLibraryResponse = try await api.get(endpoint, responseType: MediaLibraryResponse.self)

        guard let items = response.data else {
            throw APIError.serverError(response.error ?? "Failed to search media library")
        }

        state.mediaLibrary.replaceAll(items)
        state.mediaLibraryTotal = response.total ?? items.count
    }

    // MARK: - Tags

    /// List all distinct media tags in the user's org with usage counts.
    /// Drives the Library Media tab tags filter dropdown.
    @MainActor
    func loadAllMediaTags() async throws -> [String] {
        let response: TagsResponse = try await api.get(
            "/api/media/tags",
            responseType: TagsResponse.self
        )
        guard response.success, let tags = response.tags else {
            throw APIError.serverError(response.error ?? "Failed to load media tags")
        }
        return tags.map { $0.tag }
    }
}
