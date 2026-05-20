//
//  PhotoLibraryManager.swift
//  MakeReady
//
//  Reactive store for device photo library videos.
//
//  Views read from this store — they never tell it to load.
//  The store manages its own authorization and data lifecycle:
//    - On init: checks auth status, loads immediately if already authorized
//    - On first access from a video view: requests authorization if needed
//    - Album/filter changes swap the PHFetchResult instantly
//    - PHFetchResult provides count immediately; assets accessed on demand
//    - Thumbnails load per-cell via async thumbnail() calls
//

import SwiftUI
import Photos

// MARK: - Video Asset Model

struct VideoAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let duration: TimeInterval

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VideoAsset, rhs: VideoAsset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Album Model

struct PhotoAlbum: Identifiable, Hashable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
    let thumbnailAsset: PHAsset?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoAlbum, rhs: PhotoAlbum) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Photo Library Manager

@MainActor
class PhotoLibraryManager: ObservableObject {
    static let shared = PhotoLibraryManager()

    // MARK: - Published State (views observe these)

    /// Current video fetch result. Count is instant, assets accessed on demand.
    @Published private(set) var videoFetchResult: PHFetchResult<PHAsset>?

    /// Available albums with video content.
    @Published private(set) var albums: [PhotoAlbum] = []

    /// Current authorization status.
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined

    /// Whether the store has completed initial authorization + load.
    @Published private(set) var isReady = false

    /// The currently selected album filter (nil = all videos).
    @Published var selectedAlbum: PhotoAlbum? {
        didSet { applyAlbumFilter() }
    }

    // MARK: - Computed Accessors (views read these)

    /// Number of videos available (instant from PHFetchResult).
    var videoCount: Int {
        videoFetchResult?.count ?? 0
    }

    /// First video asset (for recorder library thumbnail).
    var firstVideoAsset: VideoAsset? {
        guard let result = videoFetchResult, result.count > 0 else { return nil }
        let asset = result.object(at: 0)
        return VideoAsset(id: asset.localIdentifier, asset: asset, duration: asset.duration)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    /// Lazy accessor — creates VideoAsset wrapper on demand without materializing the full array.
    func videoAsset(at index: Int) -> VideoAsset? {
        guard let result = videoFetchResult, index < result.count else { return nil }
        let asset = result.object(at: index)
        return VideoAsset(id: asset.localIdentifier, asset: asset, duration: asset.duration)
    }

    // MARK: - Private

    /// Maximum video duration in seconds (default: 5 minutes)
    var maxVideoDuration: TimeInterval = 300

    private let imageManager = PHCachingImageManager()
    private let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB — auto-evicts under pressure
        return cache
    }()
    private var hasRequestedAuthorization = false

    private init() {
        // Clear caches on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }

        // Check status synchronously — if already authorized, load videos immediately
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            // PHFetchResult creation is instant — no enumeration
            videoFetchResult = PHAsset.fetchAssets(with: videoFetchOptions)
            isReady = true
            // Defer album loading — enumerates all albums, can be slow
            Task { @MainActor in
                self.loadAlbums()
            }
        }
    }

    private func handleMemoryWarning() {
        thumbnailCache.removeAllObjects()
        imageManager.stopCachingImagesForAllAssets()
        NSLog("📸 Memory warning: cleared thumbnail caches")
    }

    // MARK: - Authorization (called once, internally managed)

    /// Ensures authorization is resolved. Safe to call multiple times — only requests once.
    /// Views should call this in .task but NOT await it before rendering.
    func ensureAuthorized() async {
        // Already authorized — nothing to do
        if isAuthorized {
            if !isReady {
                videoFetchResult = PHAsset.fetchAssets(with: videoFetchOptions)
                loadAlbums()
                isReady = true
            }
            return
        }

        // Only request once
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status

        if status == .authorized || status == .limited {
            videoFetchResult = PHAsset.fetchAssets(with: videoFetchOptions)
            loadAlbums()
            isReady = true
        }
    }

    // MARK: - Video Fetch Options

    private var videoFetchOptions: PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND duration <= %f",
            PHAssetMediaType.video.rawValue,
            maxVideoDuration
        )
        return fetchOptions
    }

    // MARK: - Album Filter

    /// Swaps PHFetchResult when album selection changes. Instant operation.
    private func applyAlbumFilter() {
        guard isAuthorized else { return }
        if let album = selectedAlbum {
            videoFetchResult = PHAsset.fetchAssets(in: album.collection, options: videoFetchOptions)
        } else {
            videoFetchResult = PHAsset.fetchAssets(with: videoFetchOptions)
        }
    }

    /// Reload videos (e.g. after recording a new video).
    func refresh() {
        applyAlbumFilter()
    }

    // MARK: - Albums

    private func loadAlbums() {
        var photoAlbums: [PhotoAlbum] = []

        // Fetch smart albums (Camera Roll, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )

        smartAlbums.enumerateObjects { collection, _, _ in
            let album = self.createAlbum(from: collection)
            if let album = album, album.count > 0 {
                photoAlbums.append(album)
            }
        }

        // Fetch user-created albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )

        userAlbums.enumerateObjects { collection, _, _ in
            let album = self.createAlbum(from: collection)
            if let album = album, album.count > 0 {
                photoAlbums.append(album)
            }
        }

        // Sort by count descending
        self.albums = photoAlbums.sorted { $0.count > $1.count }
    }

    private func createAlbum(from collection: PHAssetCollection) -> PhotoAlbum? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND duration <= %f",
            PHAssetMediaType.video.rawValue,
            maxVideoDuration
        )

        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        guard assets.count > 0 else { return nil }

        return PhotoAlbum(
            id: collection.localIdentifier,
            collection: collection,
            title: collection.localizedTitle ?? "Untitled",
            count: assets.count,
            thumbnailAsset: assets.firstObject
        )
    }

    // MARK: - Thumbnail Loading

    func thumbnail(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let key = asset.localIdentifier as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let targetSize = CGSize(
                width: size.width * Screen.scale,
                height: size.height * Screen.scale
            )

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                // Cache the result with cost = decoded byte size
                if let image = image {
                    let cost = Int(image.size.width * image.size.height * 4)
                    self?.thumbnailCache.setObject(image, forKey: key, cost: cost)
                }

                // Only return on final result (not degraded)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // MARK: - Video URL Loading

    func videoURL(for asset: PHAsset) async -> URL? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic

            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func playerItem(for asset: PHAsset) async -> AVPlayerItem? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic

            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { playerItem, _ in
                continuation.resume(returning: playerItem)
            }
        }
    }

    // MARK: - Cache Management

    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }

    func prefetchThumbnails(for assets: [PHAsset], size: CGSize) {
        let targetSize = CGSize(
            width: size.width * Screen.scale,
            height: size.height * Screen.scale
        )

        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopPrefetching(for assets: [PHAsset], size: CGSize) {
        let targetSize = CGSize(
            width: size.width * Screen.scale,
            height: size.height * Screen.scale
        )

        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
}
