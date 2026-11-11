import SwiftUI

/// bible-verse-picker D2/D4/D7/D12/D16/D20/D24: the `.bibleReader` destination — a chapter's verses, a word-snapped
/// selection and Select. Opens at the verse tapped (with a named passage's range, or the passage being changed,
/// preselected from the flow's `initial`); a horizontal swipe steps a chapter and clears the selection; a new
/// translation reloads at the verse at the top and clears the selection. Select delivers the pick for the flow and
/// pops the whole picker in one write, never waiting on the network (D25).
struct BibleReaderContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var model: BibleReaderModel
    @State private var translationMenuOpen = false

    init(book: Int, chapter: Int, verse: Int, flowId: UUID) {
        self.flowId = flowId
        _model = State(initialValue: BibleReaderModel(book: book, chapter: chapter, entryVerse: verse))
    }

    var body: some View {
        let app = AppState.shared
        let translation = app.selectedBibleTranslation
        let translations = app.sortedBibleTranslations
        BibleReaderScreen(
            state: screenState(app: app, translation: translation, translations: translations),
            onBack: { navigator.pop() },
            onSelect: { select() },
            onSelectionChange: { model.selection = $0 },
            onSwipeChapter: { swipe($0) },
            onTranslation: { chooseTranslation($0) },
            onTopVerseChange: { model.top = $0 },
            onTranslationMenu: { translationMenuOpen = true }
        )
        // D7: the chip's C-036, hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: translationMenuOpen, onDismiss: { translationMenuOpen = false }) {
            FilterMenuOverlay(
                options: translations.map { FilterMenuOverlay.Option(id: $0.code, label: $0.name) },
                selectionMode: .single,
                selectedIDs: [translation],
                onSelect: { option in
                    translationMenuOpen = false
                    chooseTranslation(option.id)
                },
                onClose: { translationMenuOpen = false }
            )
        }
        .onAppear { model.start(flowId: flowId) }
    }

    private func screenState(app: AppState, translation: String, translations: [BibleVersion]) -> BibleReaderScreen.State {
        guard let chapter = model.loaded else {
            return BibleReaderMapper.placeholder(
                book: model.book, chapter: model.chapter, translation: translation,
                translations: translations, failed: model.failed)
        }
        var state = BibleReaderMapper.state(
            chapter: chapter, selection: model.selection, used: app.biblePickFlows[flowId]?.used ?? [],
            top: model.scrollTo ?? 1, translations: translations)
        state.scrollToVerse = model.scrollTo
        return state
    }

    // MARK: - Effects

    /// D2/D25: deliver the pick, then pop to the caller's depth in one write.
    private func select() {
        guard let chapter = model.loaded, let selection = model.selection,
              let flow = AppState.shared.biblePickFlows[flowId] else { return }
        let passage = BibleReaderMapper.passage(
            from: selection, book: chapter.book, chapter: chapter.chapter, verses: chapter.verses,
            translation: chapter.translation)
        let bookName = BibleBookCatalog.book(chapter.book)?.name ?? ""
        BiblePassagePick.shared.deliver(BibleReaderMapper.pick(passage: passage, chapter: chapter, bookName: bookName), for: flowId)
        navigator.popToAndPush(flow.returnDepth, nil)
    }

    /// D4: ±1 by the bundled counts; past Genesis 1 / Revelation 22 nothing changes.
    private func swipe(_ delta: Int) {
        guard let next = BibleBookCatalog.step(book: model.book, chapter: model.chapter, by: delta) else { return }
        model.open(book: next.book, chapter: next.chapter, scrollTo: nil)
    }

    /// D7: app-wide; reloads at the verse now at the top and clears the selection.
    private func chooseTranslation(_ code: String) {
        guard code != AppState.shared.selectedBibleTranslation else { return }
        AppState.shared.selectedBibleTranslation = code
        model.open(book: model.book, chapter: model.chapter, scrollTo: model.top)
    }
}

/// The Reader's view state: which chapter it is on, its load, the selection and the verse at the top.
@Observable
@MainActor
final class BibleReaderModel {
    private(set) var book: Int
    private(set) var chapter: Int
    private(set) var loaded: BibleChapter?
    private(set) var failed = false
    /// The verse the reader scrolls to; nil = the chapter's top.
    private(set) var scrollTo: Int?
    var selection: BibleVerseReader.Selection?
    /// The verse last reported at the top of the reader; read when the translation changes.
    @ObservationIgnored var top: Int

    @ObservationIgnored private let entryVerse: Int
    @ObservationIgnored private var started = false
    @ObservationIgnored private var flowId: UUID?
    @ObservationIgnored private var preselectPending = true
    @ObservationIgnored private var generation = 0

    init(book: Int, chapter: Int, entryVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.entryVerse = entryVerse
        self.top = entryVerse
    }

    /// The first appearance: load the entry chapter at the entry verse (D1).
    func start(flowId: UUID) {
        guard !started else { return }
        started = true
        self.flowId = flowId
        open(book: book, chapter: chapter, scrollTo: entryVerse)
    }

    /// Loads a chapter, dropping the selection and any answer still in flight for the one before.
    func open(book: Int, chapter: Int, scrollTo verse: Int?) {
        self.book = book
        self.chapter = chapter
        selection = nil
        loaded = nil
        failed = false
        scrollTo = verse
        top = verse ?? 1
        generation += 1
        let mine = generation
        let translation = AppState.shared.selectedBibleTranslation
        Task { @MainActor in
            do {
                let result = try await BibleActions().loadChapter(book: book, chapter: chapter, translation: translation)
                guard mine == generation else { return }
                loaded = result
                preselect(result)
            } catch {
                guard mine == generation else { return }
                failed = true
                AppState.shared.recordError(
                    error, context: "BibleReaderContainer.load", surface: true,
                    friendlyMessage: "Couldn't load this chapter",
                    retry: { [weak self] in self?.open(book: book, chapter: chapter, scrollTo: verse) })
            }
        }
    }

    /// D12: the first chapter shown selects the flow's `initial` passage when it lies in it. Offsets from another
    /// translation index a different text, so that passage selects whole verses.
    private func preselect(_ chapter: BibleChapter) {
        guard preselectPending else { return }
        preselectPending = false
        guard let flowId, var passage = AppState.shared.biblePickFlows[flowId]?.initial,
              passage.bookNumber == chapter.book, passage.chapterStart == chapter.chapter,
              passage.chapterEnd == chapter.chapter else { return }
        if let code = passage.translation, code != chapter.translation {
            passage.startOffset = nil
            passage.endOffset = nil
        }
        selection = BibleReaderMapper.selection(from: passage, verses: chapter.verses)
    }
}
