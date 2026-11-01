import Observation
import UIKit

/// media-page D18: the Media grid's tile images. Only what MediaBrowser reports as visible + prefetch is
/// requested; each is fetched off the main thread through the app's ImageCache, downsampled to the tile's
/// pixel size, at most `maxConcurrent` at once, into a cache of at most `byteLimit` decoded bytes (the
/// oldest leave first, never one from the latest request). `generation` bumps as images land, so the grid redraws.
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
    /// Each cached URL once, oldest first.
    @ObservationIgnored private var order: [URL] = []
    @ObservationIgnored private var bytes: [URL: Int] = [:]
    @ObservationIgnored private var totalBytes = 0
    @ObservationIgnored private var failed: Set<URL> = []
    @ObservationIgnored private let byteLimit: Int
    @ObservationIgnored private let maxConcurrent: Int
    @ObservationIgnored private let fetch: UI2ImageLoader.Fetch
    /// Images landed since the last `generation` bump. Each bump re-renders the whole Media screen, so a
    /// burst of landings is one bump per `redrawInterval`, not one per image.
    @ObservationIgnored private var redrawPending = false
    @ObservationIgnored private var redrawScheduled = false
    nonisolated static let redrawInterval: Duration = .milliseconds(50)

    /// Final review I2: 64 MB of decoded bitmaps, in line with ImageCache's 50 MB memory layer — about 300
    /// tiles at 5 columns (231 px, ~213 KB each), more at the denser levels' smaller thumbs.
    nonisolated static let defaultByteLimit = 64 * 1024 * 1024

    init(byteLimit: Int = MediaTileImages.defaultByteLimit, maxConcurrent: Int = 6,
         fetch: @escaping UI2ImageLoader.Fetch = UI2ImageLoader.live) {
        self.byteLimit = byteLimit
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
        bytes = [:]
        totalBytes = 0
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
        flushRedraw()
    }

    /// Bumps `generation` for the images landed since the last bump.
    private func flushRedraw() {
        guard redrawPending else { return }
        redrawPending = false
        generation += 1
    }

    private func scheduleRedraw() {
        redrawPending = true
        guard !redrawScheduled else { return }
        redrawScheduled = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.redrawInterval)
            self?.redrawScheduled = false
            self?.flushRedraw()
        }
    }

    private func store(_ image: UIImage, for url: URL, protecting protected: Set<URL>) {
        if images[url] != nil { remove(url) }   // a re-stored URL is one entry, counted once
        let cost = Self.decodedBytes(of: image)
        images[url] = image
        order.append(url)
        bytes[url] = cost
        totalBytes += cost
        var index = 0
        while totalBytes > byteLimit, index < order.count {
            let candidate = order[index]
            if protected.contains(candidate) { index += 1; continue }
            remove(candidate)
        }
        scheduleRedraw()
    }

    private func remove(_ url: URL) {
        images[url] = nil
        totalBytes -= bytes.removeValue(forKey: url) ?? 0
        order.removeAll { $0 == url }
    }

    /// The bitmap's decoded size; an image without a CGImage is estimated at 4 bytes a pixel.
    static func decodedBytes(of image: UIImage) -> Int {
        if let cgImage = image.cgImage { return cgImage.bytesPerRow * cgImage.height }
        // `imageRendererFormat.scale`: an asset named "scale" generates a static UIImage.scale that shadows `image.scale`.
        let scale = image.imageRendererFormat.scale
        return Int(image.size.width * scale) * Int(image.size.height * scale) * 4
    }
}
