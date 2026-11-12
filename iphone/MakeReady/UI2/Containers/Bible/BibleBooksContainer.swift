import SwiftUI

/// bible-verse-picker D1/D7/D17: the `.bibleBooks` destination — the picker's first page. Browses OT and NT
/// by book; the C-131 field searches the Bible (typing after 300 ms unrecorded, return at once and recorded);
/// the chip picks the app-wide translation and re-runs an active search. Recents and the answer live in
/// `AppState`, written by `BibleActions`; the query and the in-flight flag are local. Back delivers nothing (D15).
struct BibleBooksContainer: View {
    /// D17: the query runs this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)

    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var model = BibleBooksModel()

    var body: some View {
        let app = AppState.shared
        let state = BiblePickerMapper.books(
            used: app.biblePickFlows[flowId]?.used ?? [], recents: app.bibleRecents, result: app.bibleSearchResult,
            translation: app.selectedBibleTranslation, query: model.fillQuery, translations: app.sortedBibleTranslations,
            searching: model.searching, searchFocused: !model.fillQuery.isEmpty)
        Group {
        BibleBooksScreen(
            state: state,
            onBack: { navigator.pop() },
            onBook: { navigator.push(.bibleChapters(book: $0, flowId: flowId)) },
            onQuery: { queryChanged($0) },
            onSubmit: { submit() },
            onRecent: { fill($0) },
            onRemoveRecent: { removeRecent($0) },
            onBookResult: { navigator.push(.bibleChapters(book: $0, flowId: flowId)) },
            onVerseResult: { openVerseResult(at: $0) },
            onTranslation: { chooseTranslation($0) }
        )
        // A recent fills the field: the screen seeds its field once, so a new generation re-seeds it.
        .id(model.fillGeneration)
    }
        // D53: the screen owns its scroll under a fixed header; the page fills the screen.
        .ui2PushedPageFill()
        .task {
            // An earlier visit's answer is not this visit's — but a return from a pushed page is the same visit, and
            // keeps its results (D17). The task restarts on every reappearance, so only the first one clears.
            if model.isFirstAppearance() { await BibleActions().search("", record: false) }
            await BibleActions().loadRecents()
        }
        .onDisappear {
            // Back (button or edge swipe) abandons the flow (D15); a push over this page, or Select, does not.
            let app = AppState.shared
            guard let flow = app.biblePickFlows[flowId],
                  Self.shouldPruneFlow(depth: navigator.depth(), returnDepth: flow.returnDepth,
                                       pickDelivered: BiblePassagePick.shared.pending[flowId] != nil)
            else { return }
            app.endBiblePickFlow(flowId)
        }
    }

    // MARK: - Decisions (pure, tested)

    /// The stack is back at the caller's depth and no pick is waiting: Books was popped, not covered.
    static func shouldPruneFlow(depth: Int, returnDepth: Int, pickDelivered: Bool) -> Bool {
        depth <= returnDepth && !pickDelivered
    }

    // MARK: - Effects

    private func queryChanged(_ text: String) {
        model.query = text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.clearSearch()
        } else {
            model.debouncer.type(text)
        }
    }

    /// Return searches at once, records a recent and dismisses the keyboard (D17).
    private func submit() {
        let text = model.query
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.debouncer.submit(text)
    }

    private func fill(_ recent: String) {
        model.query = recent
        model.fillQuery = recent
        model.fillGeneration += 1
        model.debouncer.submit(recent)
    }

    private func removeRecent(_ query: String) {
        guard let id = AppState.shared.bibleRecents.first(where: { $0.query == query })?.id else { return }
        Task { await BibleActions().deleteRecent(id: id) }
    }

    /// D7: the choice is app-wide; an active search runs again in it, unrecorded.
    private func chooseTranslation(_ code: String) {
        AppState.shared.selectedBibleTranslation = code
        guard !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.debouncer.cancel()
        model.run(model.query, record: false)
    }

    /// D1: the Reader opens at the verse; a named passage's `verseStart...verseEnd` arrives preselected
    /// through the flow's `initial`, the passage the Reader shows selected (D12).
    private func openVerseResult(at index: Int) {
        let app = AppState.shared
        let targets = BiblePickerMapper.verseTargets(app.bibleSearchResult)
        guard targets.indices.contains(index) else { return }
        let target = targets[index]
        if var flow = app.biblePickFlows[flowId] {
            if let range = target.range {
                flow.initial = BiblePassage(
                    bookNumber: target.book, chapterStart: target.chapter, verseStart: range.lowerBound,
                    chapterEnd: target.chapter, verseEnd: range.upperBound, startOffset: nil, endOffset: nil,
                    translation: app.selectedBibleTranslation)
            } else if case .newActivity = flow.caller {
                flow.initial = nil
            }
            app.biblePickFlows[flowId] = flow
        }
        navigator.push(.bibleReader(book: target.book, chapter: target.chapter, verse: target.verse, flowId: flowId))
    }
}

/// The Books page's search state: the typed query, the field-fill generation and how many searches are in flight.
@Observable
@MainActor
final class BibleBooksModel {
    var searching = false
    var fillQuery = ""
    var fillGeneration = 0
    @ObservationIgnored var query = ""
    @ObservationIgnored private var inFlight = 0
    @ObservationIgnored private(set) var debouncer: BibleSearchDebouncer!

    init() {
        debouncer = BibleSearchDebouncer(delay: BibleBooksContainer.searchDebounce) { [weak self] query, record in
            self?.run(query, record: record)
        }
    }

    @ObservationIgnored private var appeared = false

    /// True once, on the page's first appearance; false on every return from a page pushed over it.
    func isFirstAppearance() -> Bool {
        defer { appeared = true }
        return !appeared
    }

    func run(_ query: String, record: Bool) {
        inFlight += 1
        searching = true
        Task { @MainActor in
            let actions = BibleActions()
            await actions.search(query, record: record)
            inFlight -= 1
            searching = inFlight > 0
            if record { await actions.loadRecents() }
        }
    }

    /// An emptied field shows recents again: drop the answer and any query still waiting.
    func clearSearch() {
        debouncer.cancel()
        Task { await BibleActions().search("", record: false) }
    }
}
