import Foundation

/// bible-verse-picker D1/D5/D16/D17/D18: what the Books, Chapters and Verses pages show, decided from the
/// bundled canon, the lesson's used passages and the search answer alone, so it is tested without a view.
/// The states are the d2m screens' own (flat parallel arrays: `d2m-api.md`).
enum BiblePickerMapper {

    /// Where a search verse result opens the Reader (D1); `range` is a named passage's `verse...verseEnd`.
    struct VerseTarget: Equatable {
        let book: Int
        let chapter: Int
        let verse: Int
        let range: ClosedRange<Int>?
    }

    // MARK: - Used (D16)

    /// True when a passage covers the position: its start and end are (chapter, verse) points, inclusive.
    static func isUsed(book: Int, chapter: Int, verse: Int, in used: [BiblePassage]) -> Bool {
        used.contains { passage in
            guard passage.bookNumber == book else { return false }
            let point = (chapter, verse)
            return !lessThan(point, (passage.chapterStart, passage.verseStart))
                && !lessThan((passage.chapterEnd, passage.verseEnd), point)
        }
    }

    private static func lessThan(_ a: (Int, Int), _ b: (Int, Int)) -> Bool {
        a.0 != b.0 ? a.0 < b.0 : a.1 < b.1
    }

    private static func usesChapter(_ chapter: Int, of book: Int, in used: [BiblePassage]) -> Bool {
        used.contains { $0.bookNumber == book && $0.chapterStart <= chapter && chapter <= $0.chapterEnd }
    }

    // MARK: - Books (D5, D7, D17)

    /// The Books page: OT then NT cells in canon order, each filled with its category token (D5); the search
    /// body from `result`; the chip row from `translations` (empty = just the selected code).
    static func books(
        used: [BiblePassage],
        recents: [BibleRecent],
        result: BibleSearchResult?,
        translation: String,
        query: String,
        translations: [BibleVersion] = [],
        searching: Bool = false,
        searchFocused: Bool = false
    ) -> BibleBooksScreen.State {
        let old = Array(1...39), new = Array(40...66)
        var bookNumbers: [Int] = [], bookNames: [String] = [], bookDescriptions: [String] = [], bookFills: [String] = []
        var verseTitles: [String] = [], verseDescriptions: [String] = []

        switch result {
        case .grouped(let books, let verses)?:
            for hit in books {
                bookNumbers.append(hit.bookNumber)
                bookNames.append(hit.bookName)
                let testament = BibleBookCatalog.isOldTestament(hit.bookNumber) ? "Old Testament" : "New Testament"
                bookDescriptions.append("\(hit.chapters) \(hit.chapters == 1 ? "chapter" : "chapters") · \(testament)")
                bookFills.append(BibleBookCatalog.category(of: hit.bookNumber).colorToken)
            }
            for hit in verses {
                // A named passage shows its title and summary; a plain verse its reference and text (D6).
                verseTitles.append(hit.title ?? hit.reference)
                verseDescriptions.append(hit.summary ?? hit.text)
            }
        case .direct(let book, let chapter, let verses)?:
            let name = BibleBookCatalog.book(book)?.name ?? ""
            for verse in verses {
                verseTitles.append("\(name) \(chapter):\(verse.verse)")
                verseDescriptions.append(verse.text)
            }
        case .error?, nil:
            break
        }

        let answered = result != nil && !isError(result)
        let sorted = translations
        return BibleBooksScreen.State(
            translationCode: translation,
            translationCodes: sorted.isEmpty ? [translation] : sorted.map(\.code),
            translationNames: sorted.isEmpty ? [translation] : sorted.map(\.name),
            query: query,
            searchFocused: searchFocused,
            oldTestamentNumbers: old,
            oldTestamentLabels: old.map(label),
            oldTestamentFills: old.map { BibleBookCatalog.category(of: $0).colorToken },
            newTestamentNumbers: new,
            newTestamentLabels: new.map(label),
            newTestamentFills: new.map { BibleBookCatalog.category(of: $0).colorToken },
            usedBooks: Array(Set(used.map(\.bookNumber))).sorted(),
            recents: recents.map(\.query),
            bookResultNumbers: bookNumbers,
            bookResultNames: bookNames,
            bookResultDescriptions: bookDescriptions,
            bookResultFills: bookFills,
            verseResultTitles: verseTitles,
            verseResultDescriptions: verseDescriptions,
            searching: searching,
            searchEmpty: answered && !searching && bookNames.isEmpty && verseTitles.isEmpty)
    }

    private static func isError(_ result: BibleSearchResult?) -> Bool {
        if case .error? = result { return true }
        return false
    }

    private static func label(_ number: Int) -> String {
        BibleBookCatalog.book(number)?.abbreviation ?? ""
    }

    /// The Reader target of each verse row `books` shows, in the same order (D1).
    static func verseTargets(_ result: BibleSearchResult?) -> [VerseTarget] {
        switch result {
        case .grouped(_, let verses)?:
            return verses.map { hit in
                let range = hit.verseEnd.flatMap { $0 > hit.verse ? hit.verse...$0 : nil }
                return VerseTarget(book: hit.bookNumber, chapter: hit.chapter, verse: hit.verse, range: range)
            }
        case .direct(let book, let chapter, let verses)?:
            return verses.map { VerseTarget(book: book, chapter: chapter, verse: $0.verse, range: nil) }
        case .error?, nil:
            return []
        }
    }

    // MARK: - Chapters (D1, D5)

    /// Always lists the book's chapters, even a one-chapter book's (D1).
    static func chapters(book: Int, used: [BiblePassage]) -> BibleChaptersScreen.State {
        let count = BibleBookCatalog.chapterCount(of: book)
        return BibleChaptersScreen.State(
            title: BibleBookCatalog.book(book)?.name ?? "",
            chapterCount: count,
            usedChapters: count > 0 ? (1...count).filter { usesChapter($0, of: book, in: used) } : [])
    }

    // MARK: - Verses (D18)

    /// `verseCount` is nil until THIS chapter's count arrives (never the previous chapter's, D18); `failed`
    /// stops the spinner on an empty grid and leaves the banner to say why.
    static func verses(
        book: Int, chapter: Int, verseCount: Int?, used: [BiblePassage], failed: Bool = false
    ) -> BibleVersesScreen.State {
        let count = verseCount ?? 0
        return BibleVersesScreen.State(
            title: "\(BibleBookCatalog.book(book)?.name ?? "") \(chapter)",
            verseCount: count,
            usedVerses: count > 0 ? (1...count).filter { isUsed(book: book, chapter: chapter, verse: $0, in: used) } : [],
            loading: verseCount == nil && !failed)
    }
}

/// D17: typing searches `delay` after the last keystroke without recording; return searches at once and records.
@MainActor
final class BibleSearchDebouncer {
    private let delay: Duration
    private let perform: @MainActor (String, Bool) -> Void
    private var pending: Task<Void, Never>?

    /// - Parameter perform: called with the query and whether it records a recent.
    init(delay: Duration, perform: @escaping @MainActor (String, Bool) -> Void) {
        self.delay = delay
        self.perform = perform
    }

    func type(_ query: String) {
        pending?.cancel()
        pending = Task { @MainActor [delay, perform] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            perform(query, false)
        }
    }

    func submit(_ query: String) {
        cancel()
        perform(query, true)
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
