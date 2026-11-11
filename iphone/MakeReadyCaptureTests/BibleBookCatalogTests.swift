import XCTest
@testable import MakeReady

final class BibleBookCatalogTests: XCTestCase {
    func testEveryBookHasACategoryAndUniqueAbbreviation() {
        let books = (1...66).compactMap { BibleBookCatalog.book($0) }
        XCTAssertEqual(books.count, 66)
        XCTAssertEqual(Set(books.map(\.abbreviation)).count, 66)
        XCTAssertEqual(BibleBookCatalog.book(50)?.abbreviation, "Phil"); XCTAssertEqual(BibleBookCatalog.book(57)?.abbreviation, "Phlm")
    }
    func testMinorProphetsShareOneColour() {
        XCTAssertEqual(Set((28...39).map { BibleBookCatalog.category(of: $0).colorToken }), ["bibleBrown"])
        XCTAssertEqual(BibleBookCatalog.category(of: 1).colorToken, BibleBookCatalog.category(of: 45).colorToken)
    }
    func testChapterSteppingCrossesBooksAndStopsAtTheEnds() {
        XCTAssertEqual(BibleBookCatalog.step(book: 1, chapter: 50, by: 1)?.book, 2)
        XCTAssertEqual(BibleBookCatalog.step(book: 2, chapter: 1, by: -1).map { [$0.book, $0.chapter] }, [1, 50])
        XCTAssertNil(BibleBookCatalog.step(book: 1, chapter: 1, by: -1))
        XCTAssertNil(BibleBookCatalog.step(book: 66, chapter: 22, by: 1))
    }
    func testCategoryBoundariesTestamentAndTokens() {
        XCTAssertEqual(BibleBookCatalog.category(of: 5), .law)
        XCTAssertEqual(BibleBookCatalog.category(of: 6), .history)
        XCTAssertEqual(BibleBookCatalog.category(of: 18), .wisdom)
        XCTAssertEqual(BibleBookCatalog.category(of: 23), .majorProphets)
        XCTAssertEqual(BibleBookCatalog.category(of: 40), .gospelsActs)
        XCTAssertEqual(BibleBookCatalog.category(of: 58), .general)
        XCTAssertEqual(BibleBookCatalog.category(of: 66), .apocalyptic)
        XCTAssertTrue(BibleBookCatalog.isOldTestament(39)); XCTAssertFalse(BibleBookCatalog.isOldTestament(40))
        XCTAssertEqual(BibleBookCatalog.chapterCount(of: 19), 150)
        XCTAssertEqual(BibleCategory.history.colorToken, "bibleTeal")
        XCTAssertEqual(BibleCategory.wisdom.colorToken, "bibleGreen")
        XCTAssertEqual(BibleCategory.apocalyptic.colorToken, "bibleMaroon")
    }
}
