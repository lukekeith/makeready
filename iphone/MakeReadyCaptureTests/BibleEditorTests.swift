import XCTest
@testable import MakeReady

/// bible-verse-picker Task 14 (D11, D12, D13, D21): locked scripture, the passage menu, highlighting and change passage.
@MainActor
final class BibleEditorTests: XCTestCase {

    private static let v16 = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have eternal life."
    private static let v17 = "For God sent not his Son into the world to condemn the world; but that the world through him might be saved."
    private static let v18 = "He that believeth on him is not condemned."
    private static let chapter: [BibleVerse] = [(1, "In the beginning was the Word."), (2, "The same was in the beginning with God."),
                                               (16, v16), (17, v17), (18, v18), (19, "And this is the condemnation."),
                                               (20, "For every one that doeth evil."), (21, "But he that doeth truth.")]
        .map { BibleVerse(verse: $0.0, text: $0.1) }

    private static func pick(_ from: Int, _ to: Int, translation: String = "ENGKJV") -> BiblePick {
        BiblePick(passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: from, chapterEnd: 3, verseEnd: to,
                                        startOffset: nil, endOffset: nil, translation: translation),
                  verses: chapter.filter { $0.verse >= from && $0.verse <= to }, bookName: "John")
    }
    static let pick1to2 = pick(1, 2)
    static let pick16to21 = pick(16, 21)

    /// John 3:16-18 with "eternal life" highlighted in verse 16.
    static var bibleDoc: ActivityDocument {
        let start = (v16 as NSString).range(of: "eternal life")
        return BibleScripture.document(for: pick(16, 18), background: nil).updating { raw in
            raw[path: ["content", "objects", .index(0), "highlights"]] = .array([
                .object(["id": .string("h1"), "start": .number(Double(start.location)),
                         "end": .number(Double(start.location + start.length))])
            ])
        }
    }

    /// A scripture-looking document without `reference` (converter output, D23).
    static var legacyBibleDoc: ActivityDocument {
        bibleDoc.updating { $0[path: ["content", "objects", .index(0), "reference"]] = nil }
    }

    static var textDoc: ActivityDocument { ActivityNewContainer.textDocument(title: "Text") }

    private func state(_ doc: ActivityDocument, kind: String) -> ActivitiesEditorScreen.State {
        ActivitiesEditorMapper.state(document: doc, media: [:], slides: [], activeID: "a1", kind: kind)
    }

    private let stub = BibleSaveTests.Stub()

    private func model(_ doc: ActivityDocument? = nil) -> ActivitiesEditorContainer.Model {
        ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: doc ?? Self.bibleDoc, lessonId: "l1", lessonVersionId: "v",
                                        kind: "bible", actions: ScriptedActivityActions(), newActivityActions: stub.actions)
    }

    func testOnlyBibleShowsTheHighlightTool() {
        XCTAssertTrue(state(Self.bibleDoc, kind: "bible").showsHighlightTool)
        XCTAssertFalse(state(Self.textDoc, kind: "text").showsHighlightTool)
    }

    func testReferencedScriptureIsLockedAndLegacyIsNot() {
        XCTAssertEqual(state(Self.bibleDoc, kind: "bible").objectLocks, [true, true])
        XCTAssertEqual(state(Self.legacyBibleDoc, kind: "bible").objectLocks, [false, false])
        XCTAssertEqual(state(Self.bibleDoc, kind: "bible").objectIDs.count, 2)
    }

    func testTappingLockedScriptureOpensThePassageMenu() async {
        let model = model()
        await model.tapObject(0)
        XCTAssertEqual(model.presentation, .menu(object: 0))
        XCTAssertEqual(BiblePassageMenu.items.map(\.label), ["Change passage", "Highlight"])
        XCTAssertEqual(model.editingIndex, -1)
    }

    func testTappingLegacyScriptureEditsItAsOrdinaryText() async {
        let model = model(Self.legacyBibleDoc)
        await model.tapObject(0)
        XCTAssertNil(model.presentation)
        XCTAssertEqual(model.editingIndex, 0)
    }

    func testHighlightEntersHighlightingWithoutTheKeyboard() async {
        let model = model()
        await model.tapObject(0)
        model.choose(.highlight)
        model.menuHidden()
        let ids = state(model.document, kind: "bible").objectIDs
        XCTAssertEqual(model.highlightingObjectID, ids[0])
        XCTAssertEqual(model.editingIndex, -1)
    }

    /// D12/D28: the Idle tool bar's Highlight enters highlighting on the scripture object, no menu involved.
    func testTheIdleHighlightToolEntersHighlightingOnTheScripture() {
        let model = model()
        model.startHighlighting()
        let ids = state(model.document, kind: "bible").objectIDs
        XCTAssertEqual(model.highlightingObjectID, ids[0])
        XCTAssertEqual(model.editingIndex, -1)
    }

    func testAHighlightRangeTogglesAHighlight() {
        let model = model()
        model.highlightRange(objectIndex: 0, start: 4, end: 8)
        XCTAssertEqual(model.document.textObjects[0].highlights.count, 2)
        model.highlightRange(objectIndex: 0, start: 4, end: 8)
        XCTAssertEqual(model.document.textObjects[0].highlights.count, 1)
    }

    func testAChangeThatDropsAHighlightAsksWithTheCount() async {
        let model = model()
        await model.changePassage(pick: Self.pick1to2)
        XCTAssertEqual(model.presentation, .change(BiblePassageMenu.changeConfirmation(removed: 1)))
        let confirmation = BiblePassageMenu.changeConfirmation(removed: 1)
        XCTAssertEqual(confirmation.title, "Change passage?")
        XCTAssertEqual(confirmation.message, "1 highlight is outside the new passage and will be removed")
        XCTAssertEqual(confirmation.confirm, "Change")
        XCTAssertEqual(confirmation.cancel, "Cancel")
        XCTAssertEqual(BiblePassageMenu.changeConfirmation(removed: 2).message, "2 highlights are outside the new passage and will be removed")
        XCTAssertEqual(stub.log, [], "nothing saves before the leader confirms")
    }

    func testConfirmingAChangeSavesAndRemovesTheHighlight() async {
        let model = model()
        await model.changePassage(pick: Self.pick1to2)
        await model.confirmChange()
        XCTAssertEqual(stub.log, ["PUT a1"])
        XCTAssertNil(model.presentation)
        XCTAssertEqual(model.document.textObjects[0].highlights, [])
        XCTAssertEqual(model.document.passages.first?.verseStart, 1)
    }

    func testCancellingAChangeSavesNothing() async {
        let model = model()
        await model.changePassage(pick: Self.pick1to2)
        model.cancelPresentation()
        XCTAssertEqual(stub.log, [])
        XCTAssertEqual(model.document.passages.first?.verseStart, 16)
    }

    func testAChangeThatKeepsEveryHighlightSavesWithoutAsking() async {
        let model = model()
        await model.changePassage(pick: Self.pick16to21)
        XCTAssertNil(model.presentation)
        XCTAssertEqual(stub.log, ["PUT a1"])
        XCTAssertEqual(model.document.textObjects[0].highlights.count, 1)
        XCTAssertEqual(model.document.passages.first?.verseEnd, 21)
    }

    func testDeletingALockedObjectAsksThenRemovesBothObjects() async {
        let model = model()
        model.requestDelete(objectIndex: 0)
        XCTAssertEqual(model.presentation, .delete(BiblePassageMenu.deleteConfirmation))
        await model.confirmDelete()
        XCTAssertEqual(model.document.textObjects, [])
        XCTAssertEqual(model.document.passages, [])
    }

    func testCancellingTheDeleteKeepsThePassage() {
        let model = model()
        model.requestDelete(objectIndex: 1)
        model.cancelPresentation()
        XCTAssertEqual(model.document.textObjects.count, 2)
    }

    // MARK: Final review

    /// D12: Change passage opens the Reader at the current passage, over Books, in one path write.
    func testChangePassageOpensTheReaderAtTheCurrentPassageOverBooks() async {
        let nav = RecordingEditorNavigator()
        let model = model()
        model.navigator = nav
        await model.tapObject(0)
        model.choose(.changePassage)
        model.menuHidden()
        guard let flowId = model.changeFlowId else { return XCTFail("no change flow") }
        defer { AppState.shared.endBiblePickFlow(flowId) }
        XCTAssertEqual(nav.pushedTogether, [[.bibleBooks(flowId: flowId),
                                             .bibleReader(book: 43, chapter: 3, verse: 16, flowId: flowId)]])
        XCTAssertEqual(AppState.shared.biblePickFlows[flowId]?.initial, Self.bibleDoc.passages.first)
    }

    /// D11/D13: a changed passage keeps the leader's page — moves, restyling, added objects and page actions — and
    /// replaces only the passage's own text, numbering, reference, highlights, citation and title.
    func testChangingThePassageKeepsThePageEdits() async {
        let edited = Self.bibleDoc.updating { raw in
            raw[path: ["content", "objects", .index(0), "transform", "x"]] = .number(123)
            raw[path: ["content", "objects", .index(0), "font"]] = .string("display")
            raw[path: ["content", "objects", .index(1), "color"]] = .string("#FFCC00")
            raw[path: ["content", "objects", .index(1), "transform", "rotation"]] = .number(0.5)
            if case .array(var objects)? = raw[path: ["content", "objects"]] {
                objects.append(.object(["id": .string("extra"), "text": .string("Read slowly"), "font": .string("sans"),
                                        "size": .number(20), "color": .string("#FFFFFF"), "alignment": .string("center"),
                                        "transform": .object(["x": .number(220), "y": .number(800), "width": .number(300),
                                                              "scale": .number(1), "rotation": .number(0)])]))
                raw[path: ["content", "objects"]] = .array(objects)
            }
            raw[path: ["actions"]] = .array([.object(["id": .string("act1"), "label": .string("Pray")])])
        }
        let model = model(edited)
        await model.changePassage(pick: Self.pick16to21)
        XCTAssertEqual(stub.log, ["PUT a1"])
        let raw = model.document.raw
        XCTAssertEqual(raw[path: ["content", "objects", .index(0), "transform", "x"]], .number(123))
        XCTAssertEqual(raw[path: ["content", "objects", .index(0), "font"]], .string("display"))
        XCTAssertEqual(raw[path: ["content", "objects", .index(1), "color"]], .string("#FFCC00"))
        XCTAssertEqual(raw[path: ["content", "objects", .index(1), "transform", "rotation"]], .number(0.5))
        XCTAssertEqual(raw[path: ["content", "objects", .index(2), "id"]], .string("extra"))
        XCTAssertEqual(raw[path: ["actions"]], edited.raw[path: ["actions"]])
        let fresh = BibleScripture.document(for: Self.pick16to21, background: nil)
        let objects = model.document.textObjects
        XCTAssertEqual(objects[0].text, fresh.textObjects[0].text)
        XCTAssertEqual(objects[0].startNumber, 16)
        XCTAssertEqual(raw[path: ["content", "objects", .index(0), "reference"]], fresh.raw[path: ["content", "objects", .index(0), "reference"]])
        XCTAssertEqual(objects[0].highlights.map(\.id), ["h1"])
        XCTAssertEqual(objects[1].text, "John 3:16-21 ENGKJV")
        XCTAssertEqual(raw[path: ["fallback", "title"]], .string("John 3:16-21"))
        XCTAssertEqual(model.document.passages.first?.verseEnd, 21)
        XCTAssertEqual(ActivitiesEditorMapper.rawObjects(model.document).count, 3)
    }

    // MARK: Task 19: page-laid-out scripture (D26–D29, D31)

    /// A chapter-length passage: 36 long verses, John 3:1-36 shaped.
    static var john3AllDoc: ActivityDocument {
        let verses = (1...36).map { BibleVerse(verse: $0, text: String(repeating: "For God so loved the world, that he gave his only begotten Son. ", count: 2)) }
        return BibleScripture.document(for: BiblePick(
            passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 1, chapterEnd: 3, verseEnd: 36,
                                  startOffset: nil, endOffset: nil, translation: "ENGKJV"),
            verses: verses, bookName: "John"), background: nil)
    }

    /// D26: the editor never changes a page-laid-out object's transform — a drag, pinch or width edit is dropped.
    func testPageLaidOutObjectsIgnoreTransforms() async {
        let model = model()
        let before = model.document.textObjects.map(\.transform)
        model.edit(.init(index: 0, width: 100, transform: .init(x: 300, y: 300, scale: 2, rotation: 15)))
        model.edit(.init(index: 1, transform: .init(x: 10, y: 10, scale: 0.5, rotation: 3)))
        XCTAssertEqual(model.document.textObjects.map(\.transform), before)
    }

    /// An ordinary text object on the same page still moves.
    func testAnOrdinaryObjectOnABiblePageStillMoves() {
        let doc = Self.bibleDoc.updating { raw in
            if case .array(var objects)? = raw[path: ["content", "objects"]] {
                objects.append(.object(["id": .string("extra"), "text": .string("Read slowly"), "font": .string("sans"),
                                        "transform": .object(["x": .number(220), "y": .number(800), "width": .number(300),
                                                              "scale": .number(1), "rotation": .number(0)])]))
                raw[path: ["content", "objects"]] = .array(objects)
            }
        }
        let model = model(doc)
        model.edit(.init(index: 2, transform: .init(x: 100, y: 500, scale: 1, rotation: 0)))
        XCTAssertEqual(model.document.textObjects[2].transform.x, 100)
    }

    /// D28: the style panel writes the scripture and the citation together.
    func testTheStylePanelWritesScriptureAndCitationTogether() {
        let model = model()
        model.setBibleStyle(.inset(48)); model.setBibleStyle(.face("sans"))
        XCTAssertEqual(model.document.textObjects[0].inset, 48)
        XCTAssertEqual(model.document.textObjects[1].inset, 48)
        XCTAssertEqual(model.document.textObjects[0].font, "sans")
        XCTAssertEqual(model.document.textObjects[1].font, "sans")
    }

    /// D28: size and line height and weight and verse numbers belong to the scripture; the citation keeps 14/18 of the size.
    func testTheStylePanelSizesTheCitationAtFourteenEighteenths() {
        let model = model()
        model.setBibleStyle(.size(36)); model.setBibleStyle(.lineHeight(1.8)); model.setBibleStyle(.weight(700))
        model.setBibleStyle(.verseNumbers("inline"))
        let objects = model.document.textObjects
        XCTAssertEqual(objects[0].size, 36); XCTAssertEqual(objects[0].lineHeight, 1.8); XCTAssertEqual(objects[0].weight, 700)
        XCTAssertEqual(objects[0].verseNumbers, .inline)
        XCTAssertEqual(objects[1].size, 28, accuracy: 0.001)
        XCTAssertEqual(objects[1].weight, 400, "the weight is the scripture's alone; the citation follows the face")
    }

    /// D28: the citation follows the scripture's colour and alignment when either is edited.
    func testColourAndAlignmentEditsReachBothObjects() {
        let model = model()
        model.edit(.init(index: 1, color: "#FFCC00", alignment: "right"))
        let objects = model.document.textObjects
        XCTAssertEqual(objects.map(\.color), ["#FFCC00", "#FFCC00"])
        XCTAssertEqual(objects.map(\.alignment), ["right", "right"])
    }

    /// D28: no Animation or effects on a bible activity; the five-tool row is on.
    func testBibleHidesAnimation() {
        let s = state(Self.bibleDoc, kind: "bible")
        XCTAssertFalse(s.showsEffectsTool)
        XCTAssertTrue(s.isBible)
        XCTAssertFalse(state(Self.textDoc, kind: "text").isBible)
    }

    /// D26/D29: the state carries the page's layout — both objects page-laid-out, the citation under the scripture,
    /// the style panel seeded from the scripture; a legacy object keeps its place.
    func testTheStateCarriesThePageLayout() {
        let s = state(Self.bibleDoc, kind: "bible")
        XCTAssertEqual(s.objectPageLaidOut, [true, true])
        XCTAssertEqual(s.objectYs[0] - s.objectHeights[0] / 2, 96, accuracy: 0.5)
        XCTAssertEqual(s.objectYs[1] - s.objectHeights[1] / 2, 96 + s.objectHeights[0] + 16, accuracy: 0.5)
        XCTAssertEqual(s.objectXs, [220, 220])
        XCTAssertEqual(s.objectWidths, [376, 376])
        XCTAssertEqual(s.pageHeight, 956)
        XCTAssertEqual([s.bibleFace, "\(s.bibleSize)", "\(s.bibleInset)", s.bibleVerseNumbers], ["serif", "18.0", "32.0", "gutter"])
        let legacy = state(Self.legacyBibleDoc, kind: "bible")
        XCTAssertFalse(legacy.isBible)
        XCTAssertFalse(legacy.objectPageLaidOut.contains(true))
        XCTAssertEqual(legacy.pageHeight, 956)
    }

    /// D29: a whole chapter makes the page taller than the screen, and a bigger size or line height grows it.
    func testAWholeChapterGrowsTheEditorPage() {
        let s = state(Self.john3AllDoc, kind: "bible")
        XCTAssertGreaterThan(s.pageHeight, 956)
        let grown = state(Self.john3AllDoc.updating { $0[path: ["content", "objects", .index(0), "size"]] = .number(40) }, kind: "bible")
        XCTAssertGreaterThan(grown.pageHeight, s.pageHeight)
    }

    /// D28: the tool bar is on in Idle, so its Color and Alignment write the scripture and the citation with no edit
    /// session; dismissing the passage menu without a row enters no edit mode (the workaround is gone).
    func testIdleBibleToolsRestyleTheScriptureWithoutEditing() async {
        let model = model()
        model.setBibleStyle(.color("#FFCC00")); model.setBibleStyle(.alignment("right"))
        XCTAssertEqual(model.document.textObjects.map(\.color), ["#FFCC00", "#FFCC00"])
        XCTAssertEqual(model.document.textObjects.map(\.alignment), ["right", "right"])
        XCTAssertEqual(model.editingIndex, -1)
        await model.tapObject(1)
        model.cancelPresentation()
        XCTAssertNil(model.presentation)
        XCTAssertEqual(model.editingIndex, -1)
        let s = ActivitiesEditorContainer.screenState(model, app: AppState.shared)
        XCTAssertEqual([s.bibleColor, s.bibleAlignment], ["#FFCC00", "right"])
    }
    // MARK: D32 / D33 — vertical alignment and the Align panel

    /// D33: the Align panel's vertical row and verse-number row write the scripture.
    func testTheAlignPanelWritesVerticalAlignmentAndVerseNumbers() {
        let model = model()
        model.setBibleStyle(.verticalAlignment("center")); model.setBibleStyle(.verseNumbers("inline"))
        XCTAssertEqual(model.document.textObjects[0].verticalAlignment, .center)
        XCTAssertEqual(model.document.textObjects[0].verseNumbers, .inline)
        XCTAssertNil(model.document.textObjects[1].verticalAlignment, "the citation follows the scripture's block, not its own field")
    }

    /// D32: a document without the field reads top and is not given the field by a save or an unrelated style change.
    func testALegacyScriptureReadsTopAndNeverGainsTheField() throws {
        XCTAssertEqual(try BibleScriptureTests.decode(BibleScriptureTests.legacyScriptureJSON).verticalAlignment ?? .top, .top)
        let model = model()
        model.setBibleStyle(.size(24))
        let raw = model.document.raw[path: ["content", "objects", .index(0), "verticalAlignment"]]
        XCTAssertNil(raw)
        let object = try BibleScriptureTests.decode(BibleScriptureTests.legacyScriptureJSON)
        let back = try JSONSerialization.jsonObject(with: JSONEncoder().encode(object)) as? [String: Any]
        XCTAssertNil(back?["verticalAlignment"])
    }

    /// D32/D33: the editor screen does the shift itself, so the state carries the choice and the top-at-96 frames.
    func testTheEditorStateCarriesVerticalAlignmentWithoutPreShifting() {
        let centered = Self.bibleDoc.updating { $0[path: ["content", "objects", .index(0), "verticalAlignment"]] = .string("center") }
        let s = state(centered, kind: "bible")
        XCTAssertEqual(s.bibleVerticalAlignment, "center")
        XCTAssertEqual(s.objectYs[0] - s.objectHeights[0] / 2, 96, accuracy: 0.5)
        XCTAssertEqual(state(Self.bibleDoc, kind: "bible").bibleVerticalAlignment, "top")
    }
}
