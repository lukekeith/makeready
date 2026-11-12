import SwiftUI

/// bible-verse-picker D1/D5: the `.bibleChapters` destination — a book's chapters, always shown, even for a
/// one-chapter book. Works offline from the bundled counts (D24); chapters this lesson uses are outlined.
struct BibleChaptersContainer: View {
    let book: Int
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        Group {
        BibleChaptersScreen(
            state: BiblePickerMapper.chapters(book: book, used: AppState.shared.biblePickFlows[flowId]?.used ?? []),
            onBack: { navigator.pop() },
            onSelect: { navigator.push(.bibleVerses(book: book, chapter: $0, flowId: flowId)) }
        )
    }
        // D53: the screen owns its scroll under a fixed header; the page fills the screen.
        .ui2PushedPageFill()
    }
}
