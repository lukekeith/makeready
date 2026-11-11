import XCTest
@testable import MakeReady

final class BibleScriptureTests: XCTestCase {
    // MARK: Fixtures

    static let v16 = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have eternal life."
    static let v17 = "For God sent not his Son into the world to condemn the world; but that the world through him might be saved."
    static let v18 = "He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God."

    static func passage(_ start: Int, _ end: Int, startOffset: Int? = nil, endOffset: Int? = nil,
                        translation: String? = "ENGKJV") -> BiblePassage {
        BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: start, chapterEnd: 3, verseEnd: end,
                     startOffset: startOffset, endOffset: endOffset, translation: translation)
    }

    static let pick16b18 = BiblePick(
        passage: passage(16, 18, startOffset: 9),
        verses: [BibleVerse(verse: 16, text: v16), BibleVerse(verse: 17, text: v17), BibleVerse(verse: 18, text: v18)],
        bookName: "John")
    static let pick16to17 = BiblePick(
        passage: passage(16, 17),
        verses: [BibleVerse(verse: 16, text: v16), BibleVerse(verse: 17, text: v17)],
        bookName: "John")
    static let pick16b18WEB = BiblePick(
        passage: passage(16, 18, startOffset: 9, translation: "WEBBE"),
        verses: pick16b18.verses, bookName: "John")
    static let john3All = BiblePick(
        passage: passage(1, 36),
        verses: (1...36).map { BibleVerse(verse: $0, text: "Verse \($0) of John three.") },
        bookName: "John")

    /// A highlight over "eternal life" in verse 16, indexed into pick16b18's scripture text.
    static func range(of needle: String, in text: String) -> (Int, Int) {
        let r = (text as NSString).range(of: needle)
        return (r.location, r.location + r.length)
    }
    static let hlEternalLifeIn16: TextObject.Highlight = {
        let (s, e) = range(of: "eternal life", in: String(v16.utf16.dropFirst(9))!)
        return TextObject.Highlight(id: "h1", start: s, end: e, noteMarkdown: nil)
    }()
    /// "condemned" in verse 18 — outside pick16to17.
    static let hlIn18: TextObject.Highlight = {
        let text = [String(v16.utf16.dropFirst(9))!, v17, v18].joined(separator: "\n")
        let (s, e) = range(of: "condemned already", in: text)
        return TextObject.Highlight(id: "h2", start: s, end: e, noteMarkdown: "note")
    }()
    static func offsetOfEternalLifeIn(_ pick: BiblePick) -> Int {
        range(of: "eternal life", in: pick.verses[0].text).0
    }

    static let bibleActivity = ContentActivity(
        id: "b1", lessonVersionId: "v1", activityKey: "k1", position: 0, kind: "bible", title: "John 3:16b-18",
        document: BibleScripture.document(for: pick16b18, background: nil), estimatedSeconds: nil)
    static let textActivity = ContentActivity(
        id: "t1", lessonVersionId: "v1", activityKey: "k2", position: 1, kind: "text", title: "Text",
        document: ActivityDocument(raw: .object([
            "schemaVersion": .number(1), "kind": .string("text"),
            "content": .object(["type": .string("canvas"), "objects": .array([]),
                                "passages": .array([.object(["bookNumber": .number(1), "chapterStart": .number(1),
                                                             "verseStart": .number(1), "chapterEnd": .number(1),
                                                             "verseEnd": .number(1)])])])
        ])), estimatedSeconds: nil)

    // MARK: Tests

    func testCitationMarksPartialEnds() {
        XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: 9, endOffset: nil, translation: "ENGKJV"), bookName: "John"), "John 3:16b-18 ENGKJV")
        XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: nil, endOffset: 20, translation: "ENGKJV"), bookName: "John"), "John 3:16-18a ENGKJV")
        XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16, startOffset: nil, endOffset: nil, translation: nil), bookName: "John"), "John 3:16")
    }

    func testTitleIsTheCitationWithoutTheTranslationCode() {
        XCTAssertEqual(BibleScripture.title(for: Self.pick16b18.passage, bookName: "John"), "John 3:16b-18")
    }

    func testTheDocumentCarriesTrimmedNumberedScriptureAndItsPassage() {
        let doc = BibleScripture.document(for: Self.pick16b18, background: nil)
        let s = doc.textObjects[0]
        XCTAssertEqual(s.role, "scripture"); XCTAssertEqual(s.startNumber, 16); XCTAssertEqual(s.listStyle, "bibleVerse")
        XCTAssertEqual(s.text, [String(Self.v16.utf16.dropFirst(9))!, Self.v17, Self.v18].joined(separator: "\n"))
        XCTAssertEqual(s.reference?.start.offset, 9); XCTAssertNil(doc.textObjects[1].reference)
        XCTAssertEqual(doc.textObjects[1].text, "John 3:16b-18 ENGKJV"); XCTAssertEqual(doc.passages, [Self.pick16b18.passage])
    }

    func testTheDocumentUsesTheD10Layout() {
        let doc = BibleScripture.document(for: Self.pick16b18, background: nil)
        let s = doc.textObjects[0], c = doc.textObjects[1]
        XCTAssertEqual(s.font, "serif"); XCTAssertEqual(s.size, 18); XCTAssertEqual(s.alignment, "left")
        XCTAssertEqual(s.transform.width, 376)
        XCTAssertEqual(c.role, "citation"); XCTAssertEqual(c.font, "serif"); XCTAssertEqual(c.size, 14)
        XCTAssertGreaterThan(c.transform.y, s.transform.y)
        XCTAssertTrue(s.isLockedScripture); XCTAssertTrue(c.isLockedScripture)
    }

    func testTheLastVerseIsCutAtTheEndOffset() {
        let pick = BiblePick(passage: Self.passage(16, 17, endOffset: 10), verses: Self.pick16to17.verses, bookName: "John")
        let doc = BibleScripture.document(for: pick, background: nil)
        XCTAssertEqual(doc.textObjects[0].text, Self.v16 + "\n" + String(Self.v17.utf16.prefix(10))!)
        XCTAssertEqual(doc.textObjects[0].reference?.end.offset, 10)
    }

    func testASingleVerseIsCutAtBothOffsets() {
        let pick = BiblePick(passage: Self.passage(16, 16, startOffset: 9, endOffset: 20),
                             verses: [BibleVerse(verse: 16, text: Self.v16)], bookName: "John")
        XCTAssertEqual(BibleScripture.document(for: pick, background: nil).textObjects[0].text,
                       (Self.v16 as NSString).substring(with: NSRange(location: 9, length: 11)))
    }

    func testReanchorKeepsInsideAndCountsOutside() {
        let r = BibleScripture.reanchor(highlights: [Self.hlEternalLifeIn16, Self.hlIn18], old: Self.pick16b18, new: Self.pick16to17)
        XCTAssertEqual(r.kept.count, 1); XCTAssertEqual(r.removed, 1)
        XCTAssertEqual(r.kept[0].start, Self.offsetOfEternalLifeIn(Self.pick16to17))
    }

    func testReanchoringToTheSamePassageKeepsEveryHighlightUnchanged() {
        let r = BibleScripture.reanchor(highlights: [Self.hlIn18], old: Self.pick16b18, new: Self.pick16b18)
        XCTAssertEqual(r.kept, [Self.hlIn18]); XCTAssertEqual(r.removed, 0)
    }

    func testATranslationChangeRemovesEveryHighlight() {
        XCTAssertEqual(BibleScripture.reanchor(highlights: [Self.hlEternalLifeIn16], old: Self.pick16b18, new: Self.pick16b18WEB).removed, 1)
    }

    func testSplitAtVerseBoundariesKeepsPartialEnds() {
        let parts = BibleScripture.split(Self.john3All, fits: { $0.count <= 12 })
        XCTAssertEqual(parts.map { [$0.passage.verseStart, $0.passage.verseEnd] }, [[1, 12], [13, 24], [25, 36]])
    }

    func testSplitKeepsPartialStartOnFirstAndPartialEndOnLast() {
        let pick = BiblePick(passage: Self.passage(1, 36, startOffset: 4, endOffset: 7),
                             verses: Self.john3All.verses, bookName: "John")
        let parts = BibleScripture.split(pick, fits: { $0.count <= 12 })
        XCTAssertEqual(parts.map(\.passage.startOffset), [4, nil, nil])
        XCTAssertEqual(parts.map(\.passage.endOffset), [nil, nil, 7])
    }

    func testAPickThatFitsIsNotSplit() {
        XCTAssertEqual(BibleScripture.split(Self.pick16b18, fits: { _ in true }), [Self.pick16b18])
    }

    func testFitsMeasuresAtTheD10Style() {
        XCTAssertTrue(BibleScripture.fits(verses: Self.pick16b18.verses, width: 376))
        XCTAssertFalse(BibleScripture.fits(verses: Self.john3All.verses, width: 376))
    }

    func testUsedCollectsEveryBiblePassageInTheDraft() {
        XCTAssertEqual(BibleScripture.used(in: [Self.bibleActivity, Self.textActivity]), [Self.pick16b18.passage])
    }
}
