import SwiftUI

/// bible-verse-picker D1/D18/D24: the `.bibleVerses` destination — a chapter's verse numbers. The count comes
/// from the chapter itself (cache, else network): a spinner until THIS chapter's arrives, and on failure the
/// top banner with Retry.
struct BibleVersesContainer: View {
    let book: Int
    let chapter: Int
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var verseCount: Int?
    @State private var failed = false

    var body: some View {
        Group {
        BibleVersesScreen(
            state: BiblePickerMapper.verses(
                book: book, chapter: chapter, verseCount: verseCount,
                used: AppState.shared.biblePickFlows[flowId]?.used ?? [], failed: failed),
            onBack: { navigator.pop() },
            onSelect: { navigator.push(.bibleReader(book: book, chapter: chapter, verse: $0, flowId: flowId)) }
        )
    }
        // D53: the screen owns its scroll under a fixed header; the page fills the screen.
        .ui2PushedPageFill()
        .task { await load() }
    }

    private func load() async {
        failed = false
        verseCount = nil
        do {
            let loaded = try await BibleActions().loadChapter(
                book: book, chapter: chapter, translation: AppState.shared.selectedBibleTranslation)
            verseCount = loaded.verses.count
        } catch {
            failed = true
            AppState.shared.recordError(
                error, context: "BibleVersesContainer.load", surface: true,
                friendlyMessage: "Couldn't load this chapter",
                retry: { Task { await load() } })
        }
    }
}
