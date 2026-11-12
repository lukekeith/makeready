import XCTest
@testable import MakeReady

/// `BiblePassageEditing.currentPick` recovers the old pick's book name from the document's fallback title (D34), which
/// `citationAfterChange` then compares against: a name lost here means an unedited reference stops following Change passage.
final class BiblePassageEditingTests: XCTestCase {
    private func pick(book: Int, name: String) -> BiblePick {
        let passage = BiblePassage(bookNumber: book, chapterStart: 2, verseStart: 1, chapterEnd: 2, verseEnd: 3,
                                   startOffset: nil, endOffset: nil, translation: "ENGKJV")
        return BiblePick(passage: passage, verses: (1...3).map { BibleVerse(verse: $0, text: "Verse \($0) text.") }, bookName: name)
    }

    private func assertRecovered(book: Int, name: String, file: StaticString = #filePath, line: UInt = #line) {
        let original = pick(book: book, name: name)
        let document = BibleScripture.document(for: original, background: nil)
        let recovered = BiblePassageEditing.currentPick(of: document)
        XCTAssertEqual(recovered?.bookName, name, file: file, line: line)
        guard let recovered else { return }
        XCTAssertEqual(
            BibleScripture.citationAfterChange(current: BibleScripture.title(for: original.passage, bookName: name),
                                               old: recovered, new: pick(book: book, name: name)),
            BibleScripture.title(for: original.passage, bookName: name), file: file, line: line)
    }

    func testAMultiWordBookNameIsRecovered() { assertRecovered(book: 22, name: "Song of Solomon") }

    func testANumberedBookNameIsRecovered() { assertRecovered(book: 62, name: "1 John") }

    func testAnUneditedReferenceFollowsAChangeInAMultiWordBook() {
        let old = pick(book: 22, name: "Song of Solomon")
        let new = BiblePick(passage: BiblePassage(bookNumber: 22, chapterStart: 2, verseStart: 1, chapterEnd: 2, verseEnd: 5,
                                                  startOffset: nil, endOffset: nil, translation: "ENGKJV"),
                            verses: (1...5).map { BibleVerse(verse: $0, text: "Verse \($0) text.") }, bookName: "Song of Solomon")
        let recovered = BiblePassageEditing.currentPick(of: BibleScripture.document(for: old, background: nil))!
        XCTAssertEqual(BibleScripture.citationAfterChange(current: "Song of Solomon 2:1-3", old: recovered, new: new), "Song of Solomon 2:1-5")
    }
}
