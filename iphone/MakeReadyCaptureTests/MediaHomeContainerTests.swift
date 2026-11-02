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
        .init(tiles: tiles, tagSections: [], leaderOptions: [], dateRange: nil, isEmptyLibrary: empty, isNoResults: noResults)
    }

    func testLoadsOncePerSessionPerOrg() {
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: "o1"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o1"))
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o2"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: nil))
    }

    func testATappedItemIDMapsToItsTileByID() {
        let tiles = [tile("a"), tile("b"), tile("c")]
        XCTAssertEqual(MediaHomeContainer.index(ofTileID: "b", in: tiles), 1)
        XCTAssertNil(MediaHomeContainer.index(ofTileID: "photo-1", in: tiles))
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
        XCTAssertEqual(MediaHomeContainer.tileURL(t, medium: true, failed: { _ in false })?.absoluteString, "https://img/a-md.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, medium: true, failed: { $0.absoluteString.hasSuffix("-md.jpeg") })?.absoluteString,
                       "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, medium: false, failed: { _ in false })?.absoluteString, "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(tile("b", medium: nil), medium: true, failed: { _ in false })?.absoluteString,
                       "https://img/b-thumb.jpeg")
    }

    /// Search's 3-column tiles are bigger than the 5-column ones, so they load `-md` too.
    func testThreeAndFiveColumnsUseMediumDenserLevelsDoNot() {
        XCTAssertTrue(MediaHomeContainer.usesMedium(.three))
        XCTAssertTrue(MediaHomeContainer.usesMedium(.five))
        XCTAssertFalse(MediaHomeContainer.usesMedium(.eight))
        XCTAssertFalse(MediaHomeContainer.usesMedium(.thirty))
    }

    func testRequestsOnlyTheReportedRangeAtTilePixelSize() {
        let tiles = (0..<10).map { tile("t\($0)") }
        let requests = MediaHomeContainer.imageRequests(tiles: tiles, range: 3..<6, medium: false, tileSide: 44, scale: 3,
                                                        failed: { _ in false })
        XCTAssertEqual(requests.map(\.url.absoluteString), ["https://img/t3-thumb.jpeg", "https://img/t4-thumb.jpeg", "https://img/t5-thumb.jpeg"])
        XCTAssertEqual(requests.first?.maxPixelSize, 132)
        XCTAssertTrue(MediaHomeContainer.imageRequests(tiles: tiles, range: 8..<20, medium: false, tileSide: 44, scale: 3,
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
            MediaHomeContainer.imageRequests(tiles: tiles, range: 0..<1, medium: true, tileSide: 88, scale: 3,
                                             failed: images.hasFailed)
        }
        XCTAssertTrue(images.hasFailed(URL(string: "https://img/a-md.jpeg")!))
        XCTAssertNotNil(images.image(for: URL(string: "https://img/a-thumb.jpeg")!))
    }

    // MARK: media-library D7/D8

    private let sources = [MediaSource(id: "mr", name: "MakeReady", isMakeReady: true, canUpload: false),
                           MediaSource(id: "o1", name: "Alpha", isMakeReady: false, canUpload: true),
                           MediaSource(id: "o2", name: "Beta", isMakeReady: false, canUpload: true),
                           MediaSource(id: "o3", name: "Gamma", isMakeReady: false, canUpload: false)]

    func testSourceLabelFollowsTheChipRule() {
        XCTAssertNil(MediaHomeContainer.sourceLabel([], sources: sources))
        XCTAssertEqual(MediaHomeContainer.sourceLabel(["o2"], sources: sources), "Beta")
        XCTAssertEqual(MediaHomeContainer.sourceLabel(["o2", "mr"], sources: sources), "MakeReady +1")
    }

    func testUploadTargets() {
        typealias C = MediaHomeContainer
        // Several orgs accept uploads → the menu, MakeReady and read-only orgs left out.
        let many = C.uploadTargets(sources: sources, selection: .init(), primaryOrgId: "o1")
        XCTAssertEqual(many.options.map(\.id), ["o1", "o2"])
        XCTAssertNil(many.direct)
        XCTAssertNil(many.preselected)
        // Narrowed to one uploadable org → preselected.
        XCTAssertEqual(C.uploadTargets(sources: sources, selection: .init(sourceIds: ["o2"]), primaryOrgId: nil).preselected, "o2")
        // One org → straight in.
        let one = C.uploadTargets(sources: Array(sources.prefix(2)), selection: .init(), primaryOrgId: nil)
        XCTAssertEqual(one.direct, "o1")
        // Sources not loaded → the primary org.
        XCTAssertEqual(C.uploadTargets(sources: [], selection: .init(), primaryOrgId: "o9").direct, "o9")
        // Nowhere to upload → no options, no direct target.
        let none = C.uploadTargets(sources: [sources[0], sources[3]], selection: .init(), primaryOrgId: "o1")
        XCTAssertTrue(none.options.isEmpty)
        XCTAssertNil(none.direct)
    }

    /// media-viewer-paging: a paged-to item flies back into its own tile — the opened tile moved by
    /// whole columns and rows of the frozen grid — or off the bottom when that tile isn't on screen.
    func testTileFrameMovesTheOpenedFrameByColumnsAndRowsAndIsNilOffScreen() {
        // 440 wide at five: side (440 − 4 × 2) ÷ 5 = 86.4, pitch 88.4. Index 21 is row 4, column 1.
        let opened = CGRect(x: 88.4, y: 400, width: 86.4, height: 86.4)
        let band = MediaHomeContainer.gridBand(screen: CGRect(x: 0, y: 0, width: 440, height: 956))
        func frame(_ i: Int) -> CGRect? {
            MediaHomeContainer.tileFrame(index: i, openedIndex: 21, openedFrame: opened, level: .five, gridWidth: 440, visible: band)
        }
        XCTAssertEqual(frame(21), opened)
        XCTAssertEqual(frame(22)?.minX ?? 0, 176.8, accuracy: 0.001)              // next column
        XCTAssertEqual(frame(22)?.minY ?? 0, 400, accuracy: 0.001)
        XCTAssertEqual(frame(26)?.minX ?? 0, 88.4, accuracy: 0.001)               // next row
        XCTAssertEqual(frame(26)?.minY ?? 0, 488.4, accuracy: 0.001)
        XCTAssertEqual(frame(15)?.minX ?? 0, 0, accuracy: 0.001)                  // row 3, column 0
        XCTAssertNil(frame(1), "four rows up (y 46.4) is under the 108pt top bar")
        XCTAssertNil(frame(51), "six rows down runs past the screen bottom")
    }

    /// media-viewer-paging: the grid's band is the screen below the top bar.
    func testGridBandStartsBelowTheTopBar() {
        let band = MediaHomeContainer.gridBand(screen: CGRect(x: 0, y: 100, width: 440, height: 800))
        XCTAssertEqual(band, CGRect(x: 0, y: 208, width: 440, height: 692))
    }
}
