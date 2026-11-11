import XCTest
@testable import MakeReady

/// bible-verse-picker Task 11: the Reader's selection <-> passage mapping (D8: absent offset = whole verse),
/// the screen state it draws and the pick Select returns.
@MainActor
final class BibleReaderMapperTests: XCTestCase {
    static let v16 = "For God so loved the world, that he gave his only begotten Son."
    static let v17 = "For God sent not his Son into the world to condemn the world."
    static let v18 = "He that believeth on him is not condemned: but he that believeth not is condemned already."
    static let verses = [BibleVerse(verse: 16, text: v16), BibleVerse(verse: 17, text: v17), BibleVerse(verse: 18, text: v18)]
    static let chapter = BibleChapter(book: 43, chapter: 3, translation: "ENGKJV", verses: verses, copyright: "Public domain")

    func testAPartialSelectionKeepsItsOffsets() {
        let p = BibleReaderMapper.passage(from: .init(startVerse: 16, startOffset: 9, endVerse: 18, endOffset: Self.v18.utf16.count),
            book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
        XCTAssertEqual(p, BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18,
            startOffset: 9, endOffset: nil, translation: "ENGKJV"))
    }

    func testAWholeVerseSelectionHasNoOffsets() {
        let p = BibleReaderMapper.passage(from: .init(startVerse: 16, startOffset: 0, endVerse: 16, endOffset: Self.v16.utf16.count),
            book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
        XCTAssertNil(p.startOffset); XCTAssertNil(p.endOffset)
    }

    func testAnEndInsideTheLastVerseKeepsItsEndOffset() {
        let p = BibleReaderMapper.passage(from: .init(startVerse: 16, startOffset: 0, endVerse: 17, endOffset: 12),
            book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
        XCTAssertNil(p.startOffset); XCTAssertEqual(p.endOffset, 12)
    }

    func testSelectionRoundTripsThroughAPassage() {
        let sel = BibleVerseReader.Selection(startVerse: 16, startOffset: 9, endVerse: 17, endOffset: 12)
        let p = BibleReaderMapper.passage(from: sel, book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
        XCTAssertEqual(BibleReaderMapper.selection(from: p, verses: Self.verses), sel)
    }

    func testAbsentOffsetsSelectWholeVerses() {
        let p = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 17,
                             startOffset: nil, endOffset: nil, translation: "ENGKJV")
        XCTAssertEqual(BibleReaderMapper.selection(from: p, verses: Self.verses),
                       .init(startVerse: 16, startOffset: 0, endVerse: 17, endOffset: Self.v17.utf16.count))
    }

    func testSelectIsDisabledWithoutASelection() {
        XCTAssertFalse(BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [], top: 1).canSelect)
    }

    func testSelectIsEnabledWithASelection() {
        let sel = BibleVerseReader.Selection(startVerse: 16, startOffset: 0, endVerse: 16, endOffset: 5)
        XCTAssertTrue(BibleReaderMapper.state(chapter: Self.chapter, selection: sel, used: [], top: 1).canSelect)
    }

    func testTheStateCarriesTheChapterItsCopyrightAndTheTopVerse() {
        let s = BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [], top: 17)
        XCTAssertEqual(s.title, "John 3"); XCTAssertEqual(s.translationCode, "ENGKJV")
        XCTAssertEqual(s.verses.map(\.number), [16, 17, 18]); XCTAssertEqual(s.copyright, "Public domain")
        XCTAssertEqual(s.scrollToVerse, 17); XCTAssertFalse(s.loading); XCTAssertFalse(s.failed)
    }

    func testTheEndsOfTheCanonHaveNoNeighbour() {
        let first = BibleChapter(book: 1, chapter: 1, translation: "KJV", verses: [], copyright: "")
        let last = BibleChapter(book: 66, chapter: 22, translation: "KJV", verses: [], copyright: "")
        XCTAssertFalse(BibleReaderMapper.state(chapter: first, selection: nil, used: [], top: 1).hasPreviousChapter)
        XCTAssertTrue(BibleReaderMapper.state(chapter: first, selection: nil, used: [], top: 1).hasNextChapter)
        XCTAssertFalse(BibleReaderMapper.state(chapter: last, selection: nil, used: [], top: 1).hasNextChapter)
        XCTAssertTrue(BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [], top: 1).hasPreviousChapter)
    }

    func testUsedPassagesInThisChapterBecomeUnderlayRanges() {
        let here = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 17,
                                startOffset: 9, endOffset: 12, translation: "ENGKJV")
        let elsewhere = BiblePassage(bookNumber: 43, chapterStart: 4, verseStart: 1, chapterEnd: 4, verseEnd: 2,
                                     startOffset: nil, endOffset: nil, translation: "ENGKJV")
        let s = BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [here, elsewhere], top: 1)
        XCTAssertEqual(s.usedRanges, [.init(startVerse: 16, startOffset: 9, endVerse: 17, endOffset: 12)])
    }

    func testAPassageAcrossChaptersFillsTheChaptersItCrosses() {
        let across = BiblePassage(bookNumber: 43, chapterStart: 2, verseStart: 20, chapterEnd: 4, verseEnd: 1,
                                  startOffset: 4, endOffset: 3, translation: "ENGKJV")
        let s = BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [across], top: 1)
        XCTAssertEqual(s.usedRanges, [.init(startVerse: 16, startOffset: 0, endVerse: 18, endOffset: Self.v18.utf16.count)])
    }

    func testAnotherTranslationsOffsetsDoNotCarryOver() {
        let web = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16,
                               startOffset: 9, endOffset: 12, translation: "WEBBE")
        let s = BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [web], top: 1)
        XCTAssertEqual(s.usedRanges, [.init(startVerse: 16, startOffset: 0, endVerse: 16, endOffset: Self.v16.utf16.count)])
    }

    func testTheLoadingAndFailedStatesDrawNoVerses() {
        let loading = BibleReaderMapper.placeholder(book: 43, chapter: 3, translation: "ENGKJV", failed: false)
        XCTAssertTrue(loading.loading); XCTAssertFalse(loading.failed); XCTAssertEqual(loading.title, "John 3")
        let failed = BibleReaderMapper.placeholder(book: 43, chapter: 3, translation: "ENGKJV", failed: true)
        XCTAssertFalse(failed.loading); XCTAssertTrue(failed.failed); XCTAssertTrue(failed.verses.isEmpty)
        XCTAssertFalse(failed.canSelect)
    }

    func testThePickCarriesTheWholeVersesOfThePassage() {
        let passage = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 17, chapterEnd: 3, verseEnd: 18,
                                   startOffset: 4, endOffset: nil, translation: "ENGKJV")
        let pick = BibleReaderMapper.pick(passage: passage, chapter: Self.chapter, bookName: "John")
        XCTAssertEqual(pick, BiblePick(passage: passage, verses: [Self.verses[1], Self.verses[2]], bookName: "John"))
    }

    func testTheTranslationMenuListsTheServedCodes() {
        let served = [BibleVersion(id: "a", code: "WEBBE", name: "World English Bible", language: nil, description: nil, copyright: nil, popularity: 9)]
        let s = BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [], top: 1, translations: served)
        XCTAssertEqual(s.translationCodes, ["WEBBE"]); XCTAssertEqual(s.translationNames, ["World English Bible"])
    }
}
