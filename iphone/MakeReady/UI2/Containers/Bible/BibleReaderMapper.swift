import Foundation

/// bible-verse-picker D4/D8/D16/D20: what the Reader shows and what Select returns, decided from the loaded
/// chapter, the selection and the lesson's used passages alone, so it is tested without a view.
enum BibleReaderMapper {

    // MARK: - Selection <-> passage (D8)

    /// The passage a selection stands for. D8: an offset is absent when it is the verse's own edge, so a
    /// selection starting at a verse's start writes no `startOffset` and one ending at its end writes no `endOffset`.
    static func passage(
        from selection: BibleVerseReader.Selection, book: Int, chapter: Int, verses: [BibleVerse], translation: String
    ) -> BiblePassage {
        BiblePassage(
            bookNumber: book,
            chapterStart: chapter, verseStart: selection.startVerse,
            chapterEnd: chapter, verseEnd: selection.endVerse,
            startOffset: selection.startOffset > 0 ? selection.startOffset : nil,
            endOffset: selection.endOffset < length(of: selection.endVerse, in: verses) ? selection.endOffset : nil,
            translation: translation)
    }

    /// The selection a passage covers: an absent offset is the verse's start (0) or its UTF-16 length.
    static func selection(from passage: BiblePassage, verses: [BibleVerse]) -> BibleVerseReader.Selection {
        .init(
            startVerse: passage.verseStart, startOffset: passage.startOffset ?? 0,
            endVerse: passage.verseEnd, endOffset: passage.endOffset ?? length(of: passage.verseEnd, in: verses))
    }

    private static func length(of verse: Int, in verses: [BibleVerse]) -> Int {
        verses.first { $0.verse == verse }?.text.utf16.count ?? 0
    }

    // MARK: - Screen state

    /// The Reader for a loaded chapter. `top` is the verse to scroll to; `used` are the lesson's passages, drawn
    /// as underlay where they fall in this chapter (D16); the copyright is the chapter's (D20).
    static func state(
        chapter: BibleChapter,
        selection: BibleVerseReader.Selection?,
        used: [BiblePassage],
        top: Int,
        translations: [BibleVersion] = []
    ) -> BibleReaderScreen.State {
        let title = title(book: chapter.book, chapter: chapter.chapter)
        return BibleReaderScreen.State(
            title: title,
            translationCode: chapter.translation,
            translationCodes: translations.isEmpty ? [chapter.translation] : translations.map(\.code),
            translationNames: translations.isEmpty ? [chapter.translation] : translations.map(\.name),
            chapterHeading: title,
            verses: chapter.verses.map { .init(number: $0.verse, text: $0.text) },
            selection: selection,
            usedRanges: used.compactMap { usedRange($0, in: chapter) },
            copyright: chapter.copyright,
            scrollToVerse: top,
            hasPreviousChapter: BibleBookCatalog.step(book: chapter.book, chapter: chapter.chapter, by: -1) != nil,
            hasNextChapter: BibleBookCatalog.step(book: chapter.book, chapter: chapter.chapter, by: 1) != nil,
            loading: false,
            failed: false,
            canSelect: selection != nil)
    }

    /// The Reader while a chapter is on its way (spinner) or has failed (empty body; the banner carries Retry, D24).
    static func placeholder(
        book: Int, chapter: Int, translation: String, translations: [BibleVersion] = [], failed: Bool
    ) -> BibleReaderScreen.State {
        let title = title(book: book, chapter: chapter)
        return BibleReaderScreen.State(
            title: title,
            translationCode: translation,
            translationCodes: translations.isEmpty ? [translation] : translations.map(\.code),
            translationNames: translations.isEmpty ? [translation] : translations.map(\.name),
            chapterHeading: title,
            verses: [],
            selection: nil,
            usedRanges: [],
            copyright: "",
            scrollToVerse: nil,
            hasPreviousChapter: BibleBookCatalog.step(book: book, chapter: chapter, by: -1) != nil,
            hasNextChapter: BibleBookCatalog.step(book: book, chapter: chapter, by: 1) != nil,
            loading: !failed,
            failed: failed,
            canSelect: false)
    }

    private static func title(book: Int, chapter: Int) -> String {
        "\(BibleBookCatalog.book(book)?.name ?? "") \(chapter)"
    }

    /// The part of `passage` inside `chapter`: whole verses where it crosses the chapter's edge, and no partial
    /// offsets from another translation (they index a different text).
    private static func usedRange(_ passage: BiblePassage, in chapter: BibleChapter) -> BibleVerseReader.Selection? {
        guard passage.bookNumber == chapter.book,
              passage.chapterStart <= chapter.chapter, chapter.chapter <= passage.chapterEnd,
              let first = chapter.verses.first?.verse, let last = chapter.verses.last?.verse else { return nil }
        let sameText = passage.translation == nil || passage.translation == chapter.translation
        let startVerse = chapter.chapter == passage.chapterStart ? passage.verseStart : first
        let endVerse = chapter.chapter == passage.chapterEnd ? passage.verseEnd : last
        let startOffset = sameText && chapter.chapter == passage.chapterStart ? passage.startOffset ?? 0 : 0
        let endOffset = sameText && chapter.chapter == passage.chapterEnd
            ? passage.endOffset ?? length(of: endVerse, in: chapter.verses) : length(of: endVerse, in: chapter.verses)
        return .init(startVerse: startVerse, startOffset: startOffset, endVerse: endVerse, endOffset: endOffset)
    }

    // MARK: - Select

    /// What Select returns: the passage and the chapter's whole verses for it; the offsets trim them later (D8, D10).
    static func pick(passage: BiblePassage, chapter: BibleChapter, bookName: String) -> BiblePick {
        BiblePick(
            passage: passage,
            verses: chapter.verses.filter { passage.verseStart...passage.verseEnd ~= $0.verse },
            bookName: bookName)
    }
}
