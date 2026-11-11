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
}
