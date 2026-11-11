import XCTest
@testable import MakeReady

/// bible-verse-picker Task 10: what the Books, Chapters and Verses pages show, and the search debounce.
/// The d2m screens landed with flat parallel-array states (d2m-api.md), so the assertions read those.
@MainActor
final class BiblePickerMapperTests: XCTestCase {
    private static let john3 = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18,
                                             startOffset: 9, endOffset: nil, translation: "ENGKJV")

    func testBooksAreColouredAndUsedIsMarked() {
        let s = BiblePickerMapper.books(used: [Self.john3], recents: [], result: nil, translation: "ENGKJV", query: "")
        XCTAssertEqual(s.oldTestamentNumbers.count, 39); XCTAssertEqual(s.newTestamentNumbers.count, 27)
        XCTAssertEqual(s.oldTestamentNumbers.first, 1); XCTAssertEqual(s.newTestamentNumbers.first, 40)
        XCTAssertEqual(s.oldTestamentFills[27], "bibleBrown")
        XCTAssertEqual(s.oldTestamentLabels[0], "Gen"); XCTAssertEqual(s.newTestamentLabels[3], "John")
        XCTAssertTrue(s.usedBooks.contains(s.newTestamentNumbers[3])); XCTAssertFalse(s.usedBooks.contains(s.newTestamentNumbers[2]))
        XCTAssertEqual(s.translationCode, "ENGKJV")
    }

    func testTheTranslationChipListsTheServedCodesInOrder() {
        let served = [
            BibleVersion(id: "a", code: "WEBBE", name: "World English Bible", language: nil, description: nil, copyright: nil, popularity: 9),
            BibleVersion(id: "b", code: "NIV11", name: "New International Version", language: nil, description: nil, copyright: nil, popularity: 5),
        ]
        let s = BiblePickerMapper.books(used: [], recents: [], result: nil, translation: "WEBBE", query: "", translations: served)
        XCTAssertEqual(s.translationCodes, ["WEBBE", "NIV11"])
        XCTAssertEqual(s.translationNames, ["World English Bible", "New International Version"])
    }

    func testAOneChapterBookStillListsItsChapter() {
        XCTAssertEqual(BiblePickerMapper.chapters(book: 57, used: []).chapterCount, 1)
        XCTAssertEqual(BiblePickerMapper.chapters(book: 57, used: []).title, "Philemon")
    }

    func testChaptersMarkTheOnesAPassageTouches() {
        let multi = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 30, chapterEnd: 5, verseEnd: 2,
                                 startOffset: nil, endOffset: nil, translation: "ENGKJV")
        let other = BiblePassage(bookNumber: 44, chapterStart: 9, verseStart: 1, chapterEnd: 9, verseEnd: 1,
                                 startOffset: nil, endOffset: nil, translation: nil)
        XCTAssertEqual(BiblePickerMapper.chapters(book: 43, used: [multi, other]).usedChapters, [3, 4, 5])
    }

    func testVersesWaitForTheirOwnChapterCount() {
        let waiting = BiblePickerMapper.verses(book: 43, chapter: 4, verseCount: nil, used: [])
        XCTAssertTrue(waiting.loading); XCTAssertEqual(waiting.verseCount, 0)
        let v = BiblePickerMapper.verses(book: 43, chapter: 3, verseCount: 36, used: [Self.john3])
        XCTAssertFalse(v.loading); XCTAssertEqual(v.verseCount, 36); XCTAssertEqual(v.title, "John 3")
        XCTAssertEqual(v.usedVerses, [16, 17, 18])
    }

    func testAFailedChapterStopsLoadingWithNoVerses() {
        let v = BiblePickerMapper.verses(book: 43, chapter: 3, verseCount: nil, used: [], failed: true)
        XCTAssertFalse(v.loading); XCTAssertEqual(v.verseCount, 0)
    }

    func testIsUsedAcrossAMultiChapterPassage() {
        let multi = BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 30, chapterEnd: 4, verseEnd: 2,
                                 startOffset: nil, endOffset: nil, translation: nil)
        XCTAssertFalse(BiblePickerMapper.isUsed(book: 43, chapter: 3, verse: 29, in: [multi]))
        XCTAssertTrue(BiblePickerMapper.isUsed(book: 43, chapter: 3, verse: 30, in: [multi]))
        XCTAssertTrue(BiblePickerMapper.isUsed(book: 43, chapter: 4, verse: 2, in: [multi]))
        XCTAssertFalse(BiblePickerMapper.isUsed(book: 43, chapter: 4, verse: 3, in: [multi]))
        XCTAssertFalse(BiblePickerMapper.isUsed(book: 42, chapter: 3, verse: 30, in: [multi]))
    }

    func testRecentsAreTheQueryStrings() {
        let s = BiblePickerMapper.books(used: [], recents: [BibleRecent(id: "1", query: "grace"), BibleRecent(id: "2", query: "john 3:16")],
                                        result: nil, translation: "KJV", query: "")
        XCTAssertEqual(s.recents, ["grace", "john 3:16"])
    }

    func testGroupedResultsBecomeBookAndVerseRows() {
        let result = BibleSearchResult.grouped(
            books: [BibleBookHit(bookNumber: 43, bookName: "John", chapters: 21, testament: "NT")],
            verses: [
                BibleVerseHit(bookNumber: 43, chapter: 3, verse: 16, verseEnd: nil, reference: "John 3:16", text: "For God so loved", title: nil, summary: nil),
                BibleVerseHit(bookNumber: 43, chapter: 3, verse: 16, verseEnd: 18, reference: "John 3:16-18", text: "x", title: "God's love", summary: "The gospel in brief"),
            ])
        let s = BiblePickerMapper.books(used: [], recents: [], result: result, translation: "KJV", query: "john")
        XCTAssertEqual(s.bookResultNumbers, [43]); XCTAssertEqual(s.bookResultNames, ["John"])
        XCTAssertEqual(s.bookResultDescriptions, ["21 chapters · New Testament"]); XCTAssertEqual(s.bookResultFills, ["bibleMaroon"])
        XCTAssertEqual(s.verseResultTitles, ["John 3:16", "God's love"])
        XCTAssertEqual(s.verseResultDescriptions, ["For God so loved", "The gospel in brief"])
        XCTAssertFalse(s.searchEmpty)
    }

    func testAVerseResultOpensTheReaderAtItsVerseAndANamedPassageCarriesItsRange() {
        let result = BibleSearchResult.grouped(books: [], verses: [
            BibleVerseHit(bookNumber: 43, chapter: 3, verse: 16, verseEnd: nil, reference: "John 3:16", text: "a", title: nil, summary: nil),
            BibleVerseHit(bookNumber: 43, chapter: 3, verse: 16, verseEnd: 18, reference: "John 3:16-18", text: "x", title: "T", summary: "S"),
        ])
        let targets = BiblePickerMapper.verseTargets(result)
        XCTAssertEqual(targets.map(\.chapter), [3, 3]); XCTAssertEqual(targets.map(\.verse), [16, 16])
        XCTAssertNil(targets[0].range)
        XCTAssertEqual(targets[1].range, 16...18)
    }

    func testADirectReferenceListsItsVerses() {
        let result = BibleSearchResult.direct(book: 43, chapter: 3, verses: [BibleVerse(verse: 16, text: "For God"), BibleVerse(verse: 17, text: "For God sent")])
        let s = BiblePickerMapper.books(used: [], recents: [], result: result, translation: "KJV", query: "john 3:16-17")
        XCTAssertEqual(s.verseResultTitles, ["John 3:16", "John 3:17"])
        XCTAssertEqual(BiblePickerMapper.verseTargets(result).map(\.verse), [16, 17])
        XCTAssertTrue(s.bookResultNames.isEmpty)
    }

    func testNothingFoundIsEmptyOnlyOnceTheSearchHasAnswered() {
        let none = BibleSearchResult.grouped(books: [], verses: [])
        XCTAssertTrue(BiblePickerMapper.books(used: [], recents: [], result: none, translation: "KJV", query: "zzz").searchEmpty)
        XCTAssertFalse(BiblePickerMapper.books(used: [], recents: [], result: none, translation: "KJV", query: "zzz", searching: true).searchEmpty)
        XCTAssertTrue(BiblePickerMapper.books(used: [], recents: [], result: none, translation: "KJV", query: "zzz", searching: true).searching)
        XCTAssertFalse(BiblePickerMapper.books(used: [], recents: [], result: nil, translation: "KJV", query: "zzz").searchEmpty)
    }

    func testAnAbandonedFlowIsPrunedOnlyOnceTheStackIsBackAtTheCaller() {
        XCTAssertTrue(BibleBooksContainer.shouldPruneFlow(depth: 2, returnDepth: 2, pickDelivered: false))
        XCTAssertFalse(BibleBooksContainer.shouldPruneFlow(depth: 3, returnDepth: 2, pickDelivered: false))
        XCTAssertFalse(BibleBooksContainer.shouldPruneFlow(depth: 2, returnDepth: 2, pickDelivered: true))
    }

    /// D17: only the page's first appearance drops an earlier visit's answer; a return from a pushed page keeps it.
    func testOnlyTheFirstAppearanceClearsAnEarlierAnswer() {
        let model = BibleBooksModel()
        XCTAssertTrue(model.isFirstAppearance())
        XCTAssertFalse(model.isFirstAppearance())
        XCTAssertTrue(BibleBooksModel().isFirstAppearance())
    }

    func testTypingSearchesUnrecordedAfter300msAndReturnRecords() async {
        var calls: [(String, Bool)] = []
        let d = BibleSearchDebouncer(delay: .milliseconds(300)) { q, rec in calls.append((q, rec)) }
        d.type("j"); d.type("jo"); try? await Task.sleep(for: .milliseconds(400))
        d.submit("john 3:16")
        XCTAssertEqual(calls.map(\.0), ["jo", "john 3:16"]); XCTAssertEqual(calls.map(\.1), [false, true])
    }

    func testReturnCancelsThePendingTypedSearch() async {
        var calls: [(String, Bool)] = []
        let d = BibleSearchDebouncer(delay: .milliseconds(100)) { q, rec in calls.append((q, rec)) }
        d.type("joh"); d.submit("john"); try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(calls.map(\.0), ["john"]); XCTAssertEqual(calls.map(\.1), [true])
    }
}
