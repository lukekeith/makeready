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
    @ObservationIgnored private var inFlight: Set<URL> = []
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

    func clear() {
        images = [:]
        order = []
        failed = []
        generation += 1
    }

    func load(_ requests: [Request]) async {
        var seen = Set<URL>()
        let wanted = requests.filter { seen.insert($0.url).inserted }
        let protected = Set(wanted.map(\.url))
        let todo = wanted.filter { images[$0.url] == nil && !inFlight.contains($0.url) && !failed.contains($0.url) }
        guard !todo.isEmpty else { return }
        todo.forEach { inFlight.insert($0.url) }
        defer { todo.forEach { inFlight.remove($0.url) } }
        let fetch = self.fetch
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < todo.count else { return }
                let request = todo[next]
                next += 1
                group.addTask {
                    do { return (request.url, try await fetch(request.url, request.maxPixelSize)) } catch { return (request.url, nil) }
                }
            }
            for _ in 0..<min(maxConcurrent, todo.count) { addNext() }
            while let (url, image) = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                if let image { store(image, for: url, protecting: protected) } else { failed.insert(url) }
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
