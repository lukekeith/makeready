import XCTest
@testable import MakeReady

/// media-page D10, D13, D17, D18, R4: the container's decisions, pure.
@MainActor
final class MediaHomeContainerTests: XCTestCase {
    private func tile(_ id: String, medium: String? = "https://img/\("x")-md.jpeg") -> MediaHomeMapper.Tile {
        MediaHomeMapper.Tile(id: id, mediumURL: medium.map { URL(string: $0.replacingOccurrences(of: "x", with: id))! },
                             thumbURL: URL(string: "https://img/\(id)-thumb.jpeg"), fullURL: "https://img/\(id).jpeg",
                             date: Date(timeIntervalSince1970: 0), title: id)
    }
    private func output(_ tiles: [MediaHomeMapper.Tile], empty: Bool = false, noResults: Bool = false) -> MediaHomeMapper.Output {
        .init(tiles: tiles, tagOptions: [], leaderOptions: [], dateRange: nil, isEmptyLibrary: empty, isNoResults: noResults)
    }

    func testLoadsOncePerSessionPerOrg() {
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: "o1"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o1"))
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o2"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: nil))
    }

    func testPhase() {
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], empty: true), isLoading: true, failed: false), .loading)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], empty: true), isLoading: false, failed: false), .empty)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], noResults: true), isLoading: false, failed: false), .noResults)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([tile("a")]), isLoading: true, failed: false), .loaded)   // R4: a partial set shows
        XCTAssertEqual(MediaHomeContainer.phase(output: output([tile("a")]), isLoading: false, failed: true), .failed)
    }

    func testFiveColumnsUsesMediumThenThumbOnFailureDenserUsesThumb() {
        let t = tile("a")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: true, failed: { _ in false })?.absoluteString, "https://img/a-md.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: true, failed: { $0.absoluteString.hasSuffix("-md.jpeg") })?.absoluteString,
                       "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: false, failed: { _ in false })?.absoluteString, "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(tile("b", medium: nil), fiveColumns: true, failed: { _ in false })?.absoluteString,
                       "https://img/b-thumb.jpeg")
    }

    func testRequestsOnlyTheReportedRangeAtTilePixelSize() {
        let tiles = (0..<10).map { tile("t\($0)") }
        let requests = MediaHomeContainer.imageRequests(tiles: tiles, range: 3..<6, fiveColumns: false, tileSide: 44, scale: 3,
                                                        failed: { _ in false })
        XCTAssertEqual(requests.map(\.url.absoluteString), ["https://img/t3-thumb.jpeg", "https://img/t4-thumb.jpeg", "https://img/t5-thumb.jpeg"])
        XCTAssertEqual(requests.first?.maxPixelSize, 132)
        XCTAssertTrue(MediaHomeContainer.imageRequests(tiles: tiles, range: 8..<20, fiveColumns: false, tileSide: 44, scale: 3,
                                                       failed: { _ in false }).count == 2)
    }
    /// D10: at 5 columns a tile whose `-md` fails is followed, in the same request, by its thumb.
    func testAFailedMediumIsFollowedByTheThumb() async {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        let images = MediaTileImages(byteLimit: 64 * 1024 * 1024, maxConcurrent: 2, fetch: { url, _ in
            if url.absoluteString.hasSuffix("-md.jpeg") { throw URLError(.fileDoesNotExist) }
            return image
        })
        let tiles = [tile("a")]
        await MediaHomeContainer.loadImages(into: images) {
            MediaHomeContainer.imageRequests(tiles: tiles, range: 0..<1, fiveColumns: true, tileSide: 88, scale: 3,
                                             failed: images.hasFailed)
        }
        XCTAssertTrue(images.hasFailed(URL(string: "https://img/a-md.jpeg")!))
        XCTAssertNotNil(images.image(for: URL(string: "https://img/a-thumb.jpeg")!))
    }
}
