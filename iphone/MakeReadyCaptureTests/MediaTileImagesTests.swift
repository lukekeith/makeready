import XCTest
import UIKit
@testable import MakeReady

/// media-page D18: only the requested range loads, concurrently (bounded), into a bounded cache.
@MainActor
final class MediaTileImagesTests: XCTestCase {
    private actor Counter {
        var current = 0, peak = 0, calls: [URL] = []
        func enter(_ url: URL) { current += 1; peak = max(peak, current); calls.append(url) }
        func leave() { current -= 1 }
    }

    private func pixel() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
    }
    private func url(_ n: Int) -> URL { URL(string: "https://img/\(n).jpeg")! }
    private func requests(_ range: Range<Int>) -> [MediaTileImages.Request] { range.map { .init(url: url($0), maxPixelSize: 132) } }

    func testLoadsEachRequestOnceWithBoundedConcurrency() async {
        let counter = Counter()
        let image = pixel()
        let tiles = MediaTileImages(byteLimit: 64 * 1024 * 1024, maxConcurrent: 3, fetch: { url, _ in
            await counter.enter(url)
            try await Task.sleep(nanoseconds: 5_000_000)
            await counter.leave()
            return image
        })
        await tiles.load(requests(0..<10) + requests(0..<10))
        let calls = await counter.calls
        let peak = await counter.peak
        XCTAssertEqual(Set(calls).count, 10)
        XCTAssertEqual(calls.count, 10)
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertNotNil(tiles.image(for: url(9)))
        XCTAssertGreaterThan(tiles.generation, 0)
    }

    /// A square bitmap of `side` pixels at scale 1, and its decoded size.
    private func bitmap(_ side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in }
    }
    private func bytes(_ image: UIImage) -> Int { image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0 }

    func testEvictsTheOldestBeyondTheByteBudgetButNotTheLatestRequest() async {
        let image = bitmap(64)
        let tiles = MediaTileImages(byteLimit: 5 * bytes(image), maxConcurrent: 2, fetch: { _, _ in image })
        await tiles.load(requests(0..<5))
        await tiles.load(requests(5..<8))
        XCTAssertNil(tiles.image(for: url(0)))
        XCTAssertNil(tiles.image(for: url(2)))
        XCTAssertNotNil(tiles.image(for: url(3)))
        XCTAssertNotNil(tiles.image(for: url(7)))
        XCTAssertNotNil(tiles.image(for: url(5)))
    }

    /// Final review I2: the bound is decoded bytes, not a count — larger tiles keep fewer images.
    func testALargerImageEvictsMoreThanOneSmallOne() async {
        let small = bitmap(64), large = bitmap(128)   // the large one decodes to 4× the bytes
        let tiles = MediaTileImages(byteLimit: 6 * bytes(small), maxConcurrent: 1, fetch: { url, _ in
            url.absoluteString.hasSuffix("/99.jpeg") ? large : small
        })
        await tiles.load(requests(0..<6))
        await tiles.load([.init(url: url(99), maxPixelSize: 128)])
        XCTAssertNotNil(tiles.image(for: url(99)))
        for n in 0..<4 { XCTAssertNil(tiles.image(for: url(n)), "tile \(n)") }
        for n in 4..<6 { XCTAssertNotNil(tiles.image(for: url(n)), "tile \(n)") }
    }

    /// Final review I2: the default budget is in line with the app's ImageCache (~50–100 MB of decoded
    /// bitmaps), whatever the tile count. One 4 MiB bitmap is shared by every URL, so the test holds 4 MiB.
    func testTheDefaultBudgetHoldsAboutFiftyToAHundredMegabytes() async {
        let image = bitmap(1024)
        let each = bytes(image)
        let tiles = MediaTileImages(maxConcurrent: 6, fetch: { _, _ in image })
        await tiles.load(requests(0..<40))
        await tiles.load(requests(40..<41))
        let held = (0..<41).filter { tiles.image(for: url($0)) != nil }.count
        XCTAssertNil(tiles.image(for: url(0)))
        XCTAssertNotNil(tiles.image(for: url(40)))
        XCTAssertLessThanOrEqual(held * each, 100 * 1024 * 1024)
        XCTAssertGreaterThanOrEqual(held * each, 48 * 1024 * 1024)
    }

    /// A URL stored twice — a cancelled load's late image and its replacement's — is one entry,
    /// counted once: a budget of exactly four images keeps all four.
    func testAURLStoredTwiceIsCountedOnce() async throws {
        let counter = Counter()
        let image = bitmap(64)
        let tiles = MediaTileImages(byteLimit: 4 * bytes(image), maxConcurrent: 6, fetch: { url, _ in
            await counter.enter(url)
            return try await Task { try await Task.sleep(nanoseconds: 30_000_000); return image }.value
        })
        let first = Task { await tiles.load(requests(0..<3)) }
        while await counter.calls.count < 3 { try await Task.sleep(nanoseconds: 1_000_000) }
        first.cancel()
        await tiles.load(requests(0..<3))
        await first.value
        await tiles.load(requests(3..<4))
        for n in 0..<4 { XCTAssertNotNil(tiles.image(for: url(n)), "tile \(n)") }
    }

    /// ImageCache.fetch runs the download in its own Task, so cancelling the caller never stops it —
    /// the stub does the same. A load cancelled mid-flight and replaced by a request for the same range
    /// must still end with every image (fix round 1: no in-flight skip, late images kept).
    func testARangeReRequestedWhileItsFirstLoadIsCancelledMidFlightIsLoaded() async throws {
        let counter = Counter()
        let image = pixel()
        let tiles = MediaTileImages(byteLimit: 64 * 1024 * 1024, maxConcurrent: 6, fetch: { url, _ in
            await counter.enter(url)
            return try await Task { try await Task.sleep(nanoseconds: 30_000_000); return image }.value
        })
        let first = Task { await tiles.load(requests(0..<3)) }
        while await counter.calls.count < 3 { try await Task.sleep(nanoseconds: 1_000_000) }
        first.cancel()
        await tiles.load(requests(0..<3))
        await first.value
        for n in 0..<3 { XCTAssertNotNil(tiles.image(for: url(n)), "tile \(n)") }
        for n in 0..<3 { XCTAssertFalse(tiles.hasFailed(url(n)), "tile \(n)") }
    }

    /// A pull-to-refresh that succeeds forgets earlier failures, so a transient outage doesn't blank a
    /// URL for the session.
    /// A burst of landed images redraws the grid a few times, not once per image (every redraw re-renders
    /// the whole Media screen).
    func testABurstOfLandedImagesBumpsGenerationLessThanOncePerImage() async {
        let image = pixel()
        let tiles = MediaTileImages(byteLimit: 64 * 1024 * 1024, maxConcurrent: 6, fetch: { _, _ in image })
        await tiles.load(requests(0..<30))
        XCTAssertNotNil(tiles.image(for: url(29)))
        XCTAssertGreaterThan(tiles.generation, 0)
        XCTAssertLessThan(tiles.generation, 30)
    }

    func testClearFailuresForgetsFailedURLs() async {
        let tiles = MediaTileImages(byteLimit: 64 * 1024 * 1024, maxConcurrent: 1, fetch: { _, _ in throw URLError(.notConnectedToInternet) })
        await tiles.load(requests(0..<1))
        XCTAssertTrue(tiles.hasFailed(url(0)))
        tiles.clearFailures()
        XCTAssertFalse(tiles.hasFailed(url(0)))
    }
}
