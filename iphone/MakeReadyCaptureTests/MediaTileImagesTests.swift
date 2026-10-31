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
        let tiles = MediaTileImages(countLimit: 100, maxConcurrent: 3, fetch: { url, _ in
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

    func testEvictsTheOldestBeyondTheLimitButNotTheLatestRequest() async {
        let image = pixel()
        let tiles = MediaTileImages(countLimit: 5, maxConcurrent: 2, fetch: { _, _ in image })
        await tiles.load(requests(0..<5))
        await tiles.load(requests(5..<8))
        XCTAssertNil(tiles.image(for: url(0)))
        XCTAssertNotNil(tiles.image(for: url(7)))
        XCTAssertNotNil(tiles.image(for: url(5)))
    }

    func testAFailureIsRememberedAndNotRetriedInTheSameLoad() async {
        let tiles = MediaTileImages(countLimit: 10, maxConcurrent: 2, fetch: { _, _ in throw URLError(.badServerResponse) })
        await tiles.load(requests(0..<1))
        XCTAssertTrue(tiles.hasFailed(url(0)))
        XCTAssertNil(tiles.image(for: url(0)))
    }
    /// ImageCache.fetch runs the download in its own Task, so cancelling the caller never stops it —
    /// the stub does the same. A load cancelled mid-flight and replaced by a request for the same range
    /// must still end with every image (fix round 1: no in-flight skip, late images kept).
    func testARangeReRequestedWhileItsFirstLoadIsCancelledMidFlightIsLoaded() async throws {
        let counter = Counter()
        let image = pixel()
        let tiles = MediaTileImages(countLimit: 100, maxConcurrent: 6, fetch: { url, _ in
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
    func testClearFailuresForgetsFailedURLs() async {
        let tiles = MediaTileImages(countLimit: 10, maxConcurrent: 1, fetch: { _, _ in throw URLError(.notConnectedToInternet) })
        await tiles.load(requests(0..<1))
        XCTAssertTrue(tiles.hasFailed(url(0)))
        tiles.clearFailures()
        XCTAssertFalse(tiles.hasFailed(url(0)))
    }
}
