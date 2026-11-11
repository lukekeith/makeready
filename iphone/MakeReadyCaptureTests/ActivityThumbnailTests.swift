import XCTest
@testable import MakeReady

/// text-activity D26: a canvas-kind rail slide is the document drawn with C-092 in viewer mode.
@MainActor
final class ActivityThumbnailTests: XCTestCase {
    private func summary(_ id: String, kind: String = "text", text: String = "Hello", imageId: String? = nil) -> ActivitySummary {
        let image = imageId.map { ##","image":{"mediaId":"\##($0)"}"## } ?? ""
        let json = ##"{"id":"\##(id)","activityKey":"k","position":0,"kind":"\##(kind)","title":"T","document":{"schemaVersion":1,"kind":"\##(kind)","background":{"color":"#0E4A4D"\##(image)},"content":{"type":"canvas","verticalAnchor":"center","objects":[{"id":"o1","text":"\##(text)","font":"serif","weight":700,"size":26,"color":"#FFFFFF","alignment":"center","transform":{"x":220,"y":478,"width":392,"scale":1,"rotation":0}}]},"actions":[]}}"##
        return try! JSONDecoder.apiDecoder.decode(ActivitySummary.self, from: Data(json.utf8))
    }

    /// A D10-shaped scripture page: numbered from 16, one highlight, and the `reference` the object quotes.
    private static let bibleDoc: ActivityDocument = {
        let json = ##"{"schemaVersion":1,"kind":"bible","background":{"color":"#0E4A4D"},"content":{"type":"canvas","verticalAnchor":"top","objects":[{"id":"s1","role":"scripture","text":"For God so loved the world\nthat he gave his only begotten Son","font":"serif","weight":400,"size":18,"color":"#FFFFFF","alignment":"left","listStyle":"bibleVerse","startNumber":16,"reference":{"start":{"book":43,"chapter":3,"verse":16},"end":{"book":43,"chapter":3,"verse":17},"translation":"ENGKJV"},"highlights":[{"id":"h1","start":4,"end":7}],"transform":{"x":220,"y":200,"width":376,"scale":1,"rotation":0}}]},"actions":[]}"##
        return try! JSONDecoder.apiDecoder.decode(ActivityDocument.self, from: Data(json.utf8))
    }()

    /// F13: the rail slide draws the scripture as the player does — verse numbers from `startNumber`, highlights kept,
    /// and no reference line of C-092's own (D10: the citation object is the only one).
    func testABibleThumbnailKeepsVerseNumbersAndHighlights() {
        let o = ActivityThumbnail.objects(for: Self.bibleDoc)[0]
        XCTAssertEqual(o.listStyle, .bibleVerse); XCTAssertEqual(o.startNumber, 16); XCTAssertEqual(o.highlights.count, 1)
        XCTAssertNil(o.reference)
    }

    func testCanvasKindsGetAKeyAndOtherKindsDoNot() {
        XCTAssertTrue(ActivityThumbnail.key(for: summary("a")).hasPrefix("activity-thumbnail://"))
        XCTAssertFalse(ActivityThumbnail.key(for: summary("a", kind: "bible")).isEmpty)
        let video = try! JSONDecoder.apiDecoder.decode(ActivitySummary.self, from: Data(
            ##"{"id":"v","activityKey":"k","position":0,"kind":"video","title":"V","document":{"schemaVersion":1,"kind":"video","content":{"videoId":"x"}}}"##.utf8))
        XCTAssertEqual(ActivityThumbnail.key(for: video), "")
    }

    func testTheKeyChangesWithTheDocument() {
        XCTAssertEqual(ActivityThumbnail.key(for: summary("a")), ActivityThumbnail.key(for: summary("a")))
        XCTAssertNotEqual(ActivityThumbnail.key(for: summary("a")), ActivityThumbnail.key(for: summary("a", text: "Changed")))
    }

    func testTheMapperPutsTheRenderedKeyInTheRailForCanvasKinds() {
        let activity = summary("a")
        XCTAssertEqual(StudyProgramHomeMapper.slideImage(activity, media: [:]), ActivityThumbnail.key(for: activity))
    }

    func testSeedRendersTheSlideIntoTheCacheOnce() async throws {
        let activity = summary("seeded-\(UUID().uuidString)")
        let url = try XCTUnwrap(URL(string: ActivityThumbnail.key(for: activity)))
        XCTAssertNil(Ui2ImageCache.shared.image(for: url))
        let first = await ActivityThumbnail.seed([activity], media: [:])
        XCTAssertTrue(first)
        let image = try XCTUnwrap(Ui2ImageCache.shared.image(for: url))
        // C-079 ActivityScreenshot: 112 wide at the page's own 440:956 aspect, so nothing is cropped.
        XCTAssertEqual(image.size.width, 112, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 112 * 956 / 440, accuracy: 0.5)
        let second = await ActivityThumbnail.seed([activity], media: [:])
        XCTAssertFalse(second)
    }

    private struct Offline: Error {}

    private static var pixel: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    func testAFailedOrCancelledBackgroundFetchCachesNothing() async throws {
        let activity = summary("fail-\(UUID().uuidString)", imageId: "m1")
        let url = try XCTUnwrap(URL(string: ActivityThumbnail.key(for: activity)))
        let media = ["m1": MediaMapEntry(url: "https://cdn/m1.jpg", width: nil, height: nil, kind: "image", playbackUrl: nil,
                                         posterUrl: nil, durationSeconds: nil, uploaderName: nil)]
        let failed = await ActivityThumbnail.seed([activity], media: media, fetch: { _, _ in throw Offline() })
        XCTAssertFalse(failed)
        XCTAssertNil(Ui2ImageCache.shared.image(for: url))
        let cancelled = await ActivityThumbnail.seed([activity], media: media, fetch: { _, _ in throw CancellationError() })
        XCTAssertFalse(cancelled)
        XCTAssertNil(Ui2ImageCache.shared.image(for: url))
        // A later seed with a working fetch renders it.
        let pixel = Self.pixel
        let ok = await ActivityThumbnail.seed([activity], media: media, fetch: { _, _ in pixel })
        XCTAssertTrue(ok)
        XCTAssertNotNil(Ui2ImageCache.shared.image(for: url))
    }

    /// text-activity-v2 D1/D14: the thumbnail draws a visible gradient, never a hidden one.
    func testTheThumbnailDrawsAVisibleGradient() {
        var rng = SeededRandom(seed: 12)
        let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
        XCTAssertTrue(ActivityThumbnail.drawsGradient(for: doc.background))
        XCTAssertFalse(ActivityThumbnail.drawsGradient(for: ActivitiesEditorMapper.choosingColour("#123456", in: doc).background))
        XCTAssertEqual(ActivityThumbnail.canvasGradient(doc.background.gradient)?.blobs.map(\.x),
                       doc.background.gradient?.blobs.map(\.x))
    }

    /// The slide is the whole page at the page's aspect (C-079 §2), never a crop of it.
    func testTheSlideHasThePagesAspect() {
        XCTAssertEqual(ActivityThumbnail.size.width, 112, accuracy: 0.01)
        XCTAssertEqual(ActivityThumbnail.size.height / ActivityThumbnail.size.width, 956.0 / 440.0, accuracy: 0.0001)
    }

    /// Slides cached by an earlier render (the old cropped 33×44) get a new key, so they draw again.
    func testTheKeyCarriesTheRenderVersion() {
        XCTAssertTrue(ActivityThumbnail.key(for: summary("a")).contains("r=\(ActivityThumbnail.renderVersion)"))
        XCTAssertGreaterThanOrEqual(ActivityThumbnail.renderVersion, 2)
    }
}
