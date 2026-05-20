//
//  ImageCache.swift
//  MakeReady
//
//  Persistent image cache with memory (NSCache) and disk layers.
//  Image URLs contain timestamps, so new uploads = new URLs = automatic cache miss.
//

import UIKit

actor ImageCache {
    static let shared = ImageCache()

    // NSCache is thread-safe, so nonisolated access is safe for synchronous lookups
    nonisolated(unsafe) private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.totalCostLimit = 50 * 1024 * 1024 // ~50 MB
        memoryCache.countLimit = 200
    }

    // MARK: - Public API

    /// Fetch image: memory -> disk -> network. Caches at each level on miss.
    func fetch(url: URL) async throws -> UIImage {
        let key = cacheKey(for: url)

        // 1. Memory
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // 2. Disk
        let diskPath = diskFilePath(for: key)
        if fileManager.fileExists(atPath: diskPath.path),
           let data = try? Data(contentsOf: diskPath),
           let image = UIImage(data: data) {
            let cost = data.count
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }

        // 3. Network
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }

        // Cache in memory
        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)

        // Cache to disk (fire-and-forget, non-blocking)
        try? data.write(to: diskPath, options: .atomic)

        return image
    }

    /// Synchronous memory-cache lookup. Safe to call from any context because NSCache is thread-safe.
    /// Use this to pre-populate @State in views so images are present from the first render
    /// and don't appear mid-animation.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        return memoryCache.object(forKey: key)
    }

    // MARK: - Helpers

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
    }

    private func diskFilePath(for key: String) -> URL {
        let safeFilename = key
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheURL.appendingPathComponent(safeFilename)
    }
}
