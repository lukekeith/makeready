import SwiftUI
import XCTest
@testable import MakeReady

/// text-activity Task 27 (D9, D11, D23, D25, §iphone "Viewer", §Contract): the viewer's pure mapping
/// from a loaded lesson version and the engine to `ActivitiesPlayerScreen.State`.
@MainActor
final class ActivityViewerMapperTests: XCTestCase {

    /// D23: the page list is the activities, in lesson order, plus the completion page; an unknown
    /// kind takes a page and shows `fallback` (D11).
    func testPagesAreActivitiesPlusTheEndPage() {
        let s = ActivityViewerMapper.state(payload: .fixture(kinds: ["text", "video", "quiz"]), engine: .fixture(pages: 4), viewport: 440, playback: .idle)
        XCTAssertEqual(s.pageKinds, ["canvas", "video", "fallback", "end"])
    }

    /// §iphone "Viewer": the active page and one neighbour each side are mounted.
    func testOnlyActiveAndNeighboursMount() {
        XCTAssertEqual(ActivityViewerMapper.mountedPages(active: 3, count: 8), [2, 3, 4])
        XCTAssertEqual(ActivityViewerMapper.mountedPages(active: 0, count: 8), [0, 1])
        XCTAssertEqual(ActivityViewerMapper.mountedPages(active: 7, count: 8), [6, 7])
    }

    /// §Contract: with no `presenter` in the document, the presenter row is the video's uploader.
    func testPresenterFallsBackToUploader() {
        let s = ActivityViewerMapper.state(payload: .fixtureVideo(presenter: nil, uploaderName: "Ana Ruiz"), engine: .fixture(pages: 2), viewport: 440, playback: .idle)
        XCTAssertEqual(s.pagePresenterNames.first, "Ana Ruiz")
    }

    /// D9, D25: a `write` page is the screen's preview-only write page — its prompt as the page's
    /// object and the document's placeholder in the disabled field, which the screen labels "Preview"
    /// itself (`ActivitiesPlayerScreen.writeField`); no sheet is open.
    func testWriteAndActionSheetArePreviewOnly() {
        let s = ActivityViewerMapper.state(payload: .fixture(kinds: ["write"]), engine: .fixture(pages: 2), viewport: 440, playback: .idle)
        XCTAssertEqual(s.pageKinds.first, "write")
        XCTAssertEqual(s.pagePlaceholders.first, "Write your thoughts")
        XCTAssertEqual(s.objectPages, [0])
        XCTAssertEqual(s.objectTexts, ["What stood out?"])
        XCTAssertEqual(s.sheetKind, "")
    }

    /// Agent walk round 1 (Close under the status bar): the viewer ignores the safe area, so its proxy reads 0;
    /// the window's insets win, edge by edge, and with no window the proxy's stand.
    func testViewerInsetsTakeTheWindowsWhenTheProxyReadsZero() {
        let insets = ActivityViewerContainer.viewerInsets(proxy: EdgeInsets(),
                                                          window: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0))
        XCTAssertEqual(insets.top, 62)
        XCTAssertEqual(insets.bottom, 34)
        let proxyOnly = ActivityViewerContainer.viewerInsets(proxy: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
                                                             window: nil)
        XCTAssertEqual(proxyOnly.top, 59)
    }

    /// A D10-shaped scripture page: numbered from 16, one highlight, and the `reference` the object quotes.
    private static let bibleDoc: ActivityDocument = {
        let json = ##"{"schemaVersion":1,"kind":"bible","background":{"color":"#0E4A4D"},"content":{"type":"canvas","verticalAnchor":"top","objects":[{"id":"s1","role":"scripture","text":"For God so loved the world\nthat he gave his only begotten Son","font":"serif","weight":400,"size":18,"color":"#FFFFFF","alignment":"left","listStyle":"bibleVerse","startNumber":16,"reference":{"start":{"book":43,"chapter":3,"verse":16},"end":{"book":43,"chapter":3,"verse":17},"translation":"ENGKJV"},"highlights":[{"id":"h1","start":4,"end":7}],"transform":{"x":220,"y":200,"width":376,"scale":1,"rotation":0}}]},"actions":[]}"##
        return try! JSONDecoder.apiDecoder.decode(ActivityDocument.self, from: Data(json.utf8))
    }()

    /// D10: the player maps a scripture object with its verse numbers and highlights but WITHOUT a `reference`
    /// channel — the state has no per-object reference, so C-092 draws no second citation line.
    func testThePlayerNeverDrawsTheScriptureReference() {
        let a = ContentActivity(id: "a0", lessonVersionId: "v1", activityKey: "k0", position: 0, kind: "bible",
                                title: "T", document: Self.bibleDoc, estimatedSeconds: nil)
        let s = ActivityViewerMapper.state(payload: .payload([a], media: [:]), engine: .fixture(pages: 2),
                                           viewport: 440, playback: .idle)
        XCTAssertEqual(s.objectListStyles, ["bibleVerse"])
        XCTAssertEqual(s.objectStartNumbers, [16])
        XCTAssertEqual(s.highlightObjects, [0])
        XCTAssertTrue(s.pageReferences.allSatisfy { $0.isEmpty }, "the scripture's reference must not reach the page's reference line")
    }

    /// D29: a whole chapter's page is taller than the screen.
    func testAWholeChapterPageIsTallerThanTheScreen() {
        XCTAssertGreaterThan(ActivityViewerMapper.page(for: BibleEditorTests.john3AllDoc)?.height ?? 0, 956)
        XCTAssertEqual(ActivityViewerMapper.page(for: BibleEditorTests.bibleDoc)?.height, 956)
        XCTAssertNil(ActivityViewerMapper.page(for: ActivityNewContainer.textDocument(title: "T")))
    }

    /// D26/D29/D30: the player gets a `bible` page with its height, laid-out flags and the page's own placement.
    func testThePlayerMapsATallBiblePage() {
        let a = ContentActivity(id: "a0", lessonVersionId: "v1", activityKey: "k0", position: 0, kind: "bible",
                                title: "T", document: BibleEditorTests.john3AllDoc, estimatedSeconds: nil)
        let s = ActivityViewerMapper.state(payload: .payload([a], media: [:]), engine: .fixture(pages: 2),
                                           viewport: 440, playback: .idle)
        XCTAssertEqual(s.pageKinds, ["bible", "end"])
        XCTAssertGreaterThan(s.pageHeights[0], 956)
        XCTAssertEqual(s.pageHeights[1], 956)
        XCTAssertEqual(s.objectPageLaidOut, [true, true])
        XCTAssertEqual(s.objectXs, [220, 220])
        XCTAssertGreaterThan(s.objectYs[1], s.objectYs[0])
        let placed = ActivityViewerMapper.page(for: BibleEditorTests.john3AllDoc)
        XCTAssertEqual(s.pageHeights[0], placed?.height)
    }

    /// D30: the engine scrolls inside a tall page — its height in points is the layout's, scaled to the viewport.
    func testTheEngineSeesATallPageAsTall() {
        let a = ContentActivity(id: "a0", lessonVersionId: "v1", activityKey: "k0", position: 0, kind: "bible",
                                title: "T", document: BibleEditorTests.john3AllDoc, estimatedSeconds: nil)
        let heights = ActivityViewerMapper.pageHeights(.payload([a], media: [:]), size: CGSize(width: 440, height: 956))
        XCTAssertEqual(heights[0], ActivityViewerMapper.page(for: BibleEditorTests.john3AllDoc)?.height ?? 0, accuracy: 0.5)
        XCTAssertEqual(heights[1], 956)
    }

    /// text-activity-v2 D1/D14: a visible gradient reaches the page's background; a hidden one doesn't.
    func testAVisibleGradientReachesThePage() {
        var rng = SeededRandom(seed: 11)
        let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
        func gradients(_ document: ActivityDocument) -> [ActivityCanvasGradient?] {
            let a = ContentActivity(id: "a0", lessonVersionId: "v1", activityKey: "k0", position: 0, kind: "text",
                                    title: "T", document: document, estimatedSeconds: nil)
            return ActivityViewerMapper.state(payload: .payload([a], media: [:]), engine: .fixture(pages: 2),
                                              viewport: 440, playback: .idle).pageGradients
        }
        XCTAssertEqual(gradients(doc).first??.blobs.count, 4)
        XCTAssertNil(gradients(ActivitiesEditorMapper.choosingColour("#123456", in: doc)).first ?? nil)
    }
}

// MARK: - Fixtures

private extension LessonVersionPayload {
    /// One activity per kind, in order, on a draft titled "Day 1".
    static func fixture(kinds: [String]) -> LessonVersionPayload {
        payload(kinds.enumerated().map { index, kind in activity(index, kind: kind, content: content(for: kind)) }, media: [:])
    }

    /// One video page whose document names no presenter; the video's media row names its uploader.
    static func fixtureVideo(presenter: String?, uploaderName: String) -> LessonVersionPayload {
        var content: [String: JSONValue] = ["type": .string("video"), "videoId": .string("vid1")]
        if let presenter { content["presenter"] = .object(["name": .string(presenter)]) }
        let entry = MediaMapEntry(url: "https://stream.example/vid1.m3u8", width: nil, height: nil, kind: "video",
                                  playbackUrl: "https://stream.example/vid1.m3u8", posterUrl: nil,
                                  durationSeconds: 120, uploaderName: uploaderName)
        return payload([activity(0, kind: "video", content: .object(content))], media: ["vid1": entry])
    }

    static func payload(_ activities: [ContentActivity], media: [String: MediaMapEntry]) -> LessonVersionPayload {
        LessonVersionPayload(
            version: LessonVersion(id: "v1", lessonId: "l1", enrollmentId: nil, number: 1, status: .draft,
                                   title: "Day 1", estimatedSeconds: nil, publishedAt: nil),
            activities: activities,
            media: media
        )
    }

    static func activity(_ index: Int, kind: String, content: JSONValue) -> ContentActivity {
        let document = ActivityDocument(raw: .object([
            "schemaVersion": .number(1),
            "kind": .string(kind),
            "background": .object(["color": .string("#0E4A4D")]),
            "content": content,
            "actions": .array([])
        ]))
        return ContentActivity(id: "a\(index)", lessonVersionId: "v1", activityKey: "k\(index)", position: index,
                               kind: kind, title: kind, document: document, estimatedSeconds: nil)
    }

    static func textObject(_ text: String) -> JSONValue {
        .object([
            "id": .string("o1"), "text": .string(text), "font": .string("sans"), "weight": .number(700),
            "size": .number(28), "color": .string("#FFFFFF"), "alignment": .string("center"),
            "transform": .object(["x": .number(220), "y": .number(400), "width": .number(392),
                                  "scale": .number(1), "rotation": .number(0)])
        ])
    }

    static func content(for kind: String) -> JSONValue {
        switch kind {
        case "text":
            return .object(["type": .string("canvas"), "verticalAnchor": .string("center"),
                            "objects": .array([textObject("Hello")])])
        case "video":
            return .object(["type": .string("video"), "videoId": .string("vid1")])
        case "write":
            return .object(["type": .string("write"), "prompt": textObject("What stood out?"),
                            "placeholder": .string("Write your thoughts")])
        default:
            return .object(["type": .string(kind)])
        }
    }
}

private extension ViewerEngine {
    /// `pages` viewport-tall pages on the 956 pt reference viewport, resting on the first.
    static func fixture(pages: Int) -> ViewerEngine {
        ViewerEngine(viewportHeight: 956, pageHeights: Array(repeating: 956, count: pages))
    }
}
