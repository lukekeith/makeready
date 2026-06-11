//
//  ImageCache.swift
//  MakeReady
//
//  Persistent image cache with memory (NSCache) and disk layers.
//  Image URLs contain timestamps, so new uploads = new URLs = automatic cache miss.
//
//  Phase 4.3 additions:
//  - Identical in-flight fetches share one download/decode (cells +
//    prefetching would otherwise race the same URL repeatedly)
//  - fetch(url:maxPixelSize:) decodes a downsampled bitmap via ImageIO
//    for callers whose sources are larger than their display size.
//    NOTE: the media grid deliberately keeps full fetch(url:) — its -md
//    sources are already 400px (≈ cell size), and MediaDetailOverlay's
//    instant zoom transition relies on a warm cache hit of that same key.
//

import UIKit
import ImageIO

actor ImageCache {
    static let shared = ImageCache()

    // NSCache is thread-safe, so nonisolated access is safe for synchronous lookups
    nonisolated(unsafe) private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    /// In-flight fetches keyed by memory-cache key, so identical concurrent
    /// requests share one download + decode.
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.totalCostLimit = 50 * 1024 * 1024 // ~50 MB
        memoryCache.countLimit = 200
    }

    // MARK: - Public API

    /// Fetch image: memory -> disk -> network. Caches at each level on miss.
    /// Identical concurrent fetches share one underlying task.
    func fetch(url: URL) async throws -> UIImage {
        try await fetch(url: url, maxPixelSize: nil)
    }

    /// Fetch an image decoded to at most `maxPixelSize` on its longest edge
    /// (in pixels). The downsampled bitmap is what lands in the memory
    /// cache; the disk layer always stores the original bytes so other
    /// sizes stay derivable without re-downloading.
    func fetch(url: URL, maxPixelSize: CGFloat?) async throws -> UIImage {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize)

        // 1. Memory
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // 2. Shared in-flight fetch
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            try await self.loadAndCache(url: url, maxPixelSize: maxPixelSize, key: key)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    /// Synchronous memory-cache lookup. Safe to call from any context because NSCache is thread-safe.
    /// Use this to pre-populate @State in views so images are present from the first render
    /// and don't appear mid-animation.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        return memoryCache.object(forKey: key)
    }

    /// Synchronous lookup of a downsampled variant.
    nonisolated func cachedImage(for url: URL, maxPixelSize: CGFloat?) -> UIImage? {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize) as NSString
        return memoryCache.object(forKey: key)
    }

    // MARK: - Loading

    private func loadAndCache(url: URL, maxPixelSize: CGFloat?, key: String) async throws -> UIImage {
        // 1. Disk (original bytes, decoded to the requested size)
        let diskPath = diskFilePath(for: url)
        if fileManager.fileExists(atPath: diskPath.path),
           let data = try? Data(contentsOf: diskPath),
           let image = decode(data: data, maxPixelSize: maxPixelSize) {
            // LRU touch (M0.3): trimDiskCache evicts by modification date,
            // so a disk hit marks the file as recently used. Only runs on
            // memory-cache misses, so the syscall is infrequent.
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: diskPath.path)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost(of: image, data: data, maxPixelSize: maxPixelSize))
            return image
        }

        // 2. Network
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = decode(data: data, maxPixelSize: maxPixelSize) else {
            throw URLError(.badServerResponse)
        }

        memoryCache.setObject(image, forKey: key as NSString, cost: cost(of: image, data: data, maxPixelSize: maxPixelSize))

        // Cache original bytes to disk (fire-and-forget, non-blocking)
        try? data.write(to: diskPath, options: .atomic)

        return image
    }

    /// Full-size entries keep the original compressed-bytes cost basis so
    /// NSCache retention behaves exactly as before this change; downsampled
    /// variants (new) are costed by their actual bitmap size.
    private func cost(of image: UIImage, data: Data, maxPixelSize: CGFloat?) -> Int {
        maxPixelSize == nil ? data.count : bitmapCost(of: image)
    }

    /// Decode image data, optionally downsampled via ImageIO so the bitmap
    /// never exceeds `maxPixelSize` on its longest edge. Decoded immediately
    /// (off the render path) rather than lazily on first draw.
    private func decode(data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        guard let maxPixelSize else {
            return UIImage(data: data)
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }

    private func bitmapCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }

    // MARK: - Disk Budget (M0.3)

    /// Disk cache budget in bytes. Worst case of trimming is a re-download.
    static let diskBudgetBytes = 512 * 1024 * 1024

    /// Trim the disk cache to the budget, deleting least-recently-used files
    /// first (modification date is touched on every disk hit). Called on
    /// launch and when the app backgrounds — iOS exposes no public low-disk
    /// notification, so backgrounding is the periodic trigger. Trims to 90%
    /// of budget so consecutive trims don't thrash around the threshold.
    func trimDiskCache(budget: Int = ImageCache.diskBudgetBytes) {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return }

        var files: [(url: URL, size: Int, modified: Date)] = []
        var total = 0
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let size = values.totalFileAllocatedSize ?? 0
            files.append((url, size, values.contentModificationDate ?? .distantPast))
            total += size
        }

        guard total > budget else { return }

        let target = budget * 9 / 10
        var freed = 0
        for file in files.sorted(by: { $0.modified < $1.modified }) {
            guard total - freed > target else { break }
            try? fileManager.removeItem(at: file.url)
            freed += file.size
        }
        NSLog(
            "🖼️ ImageCache: trimmed %d MB (disk was %d MB, budget %d MB, %d files)",
            freed / 1_048_576, total / 1_048_576, budget / 1_048_576, files.count
        )
    }

    // MARK: - Helpers

    private nonisolated func cacheKey(for url: URL, maxPixelSize: CGFloat?) -> String {
        guard let maxPixelSize else { return url.absoluteString }
        return "\(url.absoluteString)#\(Int(maxPixelSize))px"
    }

    /// Disk files are keyed by URL only — originals, never sized variants.
    private func diskFilePath(for url: URL) -> URL {
        let key = url.absoluteString
        let safeFilename = key
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheURL.appendingPathComponent(safeFilename)
    }
}
