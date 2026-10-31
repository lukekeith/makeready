import Observation
import UIKit

/// media-page D18: the Media grid's tile images. Only what MediaBrowser reports as visible + prefetch is
/// requested; each is fetched off the main thread through the app's ImageCache, downsampled to the tile's
/// pixel size, at most `maxConcurrent` at once, into a cache of at most `countLimit` images (the oldest
/// leave first, never one from the latest request). `generation` bumps as images land, so the grid redraws.
/// Not `Ui2ImageCache`, which is unbounded (F11).
@MainActor
@Observable
final class MediaTileImages {
    struct Request: Hashable {
        let url: URL
        let maxPixelSize: CGFloat
    }

    private(set) var generation = 0
    @ObservationIgnored private var images: [URL: UIImage] = [:]
    @ObservationIgnored private var order: [URL] = []
    @ObservationIgnored private var failed: Set<URL> = []
    @ObservationIgnored private let countLimit: Int
    @ObservationIgnored private let maxConcurrent: Int
    @ObservationIgnored private let fetch: UI2ImageLoader.Fetch

    init(countLimit: Int = 3000, maxConcurrent: Int = 6, fetch: @escaping UI2ImageLoader.Fetch = UI2ImageLoader.live) {
        self.countLimit = countLimit
        self.maxConcurrent = maxConcurrent
        self.fetch = fetch
    }

    func image(for url: URL) -> UIImage? { images[url] }

    func hasFailed(_ url: URL) -> Bool { failed.contains(url) }

    /// A successful pull-to-refresh forgets failures, so those URLs are requested again.
    func clearFailures() { failed = [] }

    func clear() {
        images = [:]
        order = []
        failed = []
        generation += 1
    }

    /// Loads what isn't cached or failed. A URL another load is still fetching is asked again: ImageCache
    /// shares the one download, so a replacement load never skips a tile its cancelled predecessor held.
    /// Cancelled, it starts nothing new but keeps every image that still lands (the bytes are fetched).
    func load(_ requests: [Request]) async {
        var seen = Set<URL>()
        let wanted = requests.filter { seen.insert($0.url).inserted }
        let protected = Set(wanted.map(\.url))
        let todo = wanted.filter { images[$0.url] == nil && !failed.contains($0.url) }
        guard !todo.isEmpty else { return }
        let fetch = self.fetch
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < todo.count, !Task.isCancelled else { return }
                let request = todo[next]
                next += 1
                group.addTask {
                    do { return (request.url, try await fetch(request.url, request.maxPixelSize)) } catch { return (request.url, nil) }
                }
            }
            for _ in 0..<min(maxConcurrent, todo.count) { addNext() }
            while let (url, image) = await group.next() {
                if let image {
                    store(image, for: url, protecting: protected)
                } else if !Task.isCancelled {
                    failed.insert(url)   // a fetch that ended because the load was cancelled isn't a failure
                }
                addNext()
            }
        }
    }

    private func store(_ image: UIImage, for url: URL, protecting protected: Set<URL>) {
        images[url] = image
        order.append(url)
        var index = 0
        while images.count > countLimit, index < order.count {
            let candidate = order[index]
            if protected.contains(candidate) { index += 1; continue }
            images[candidate] = nil
            order.remove(at: index)
        }
        generation += 1
    }
}
