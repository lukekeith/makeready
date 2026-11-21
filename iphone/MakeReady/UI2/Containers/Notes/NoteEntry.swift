import SwiftUI

/// notes D17: where the Add menu's "Write a note" row goes — a fresh note on the tab's own stack.
enum NoteEntry {
    static let rowLabel = "Write a note"

    /// Pushes `.newNote` on `tab`'s stack, with a new `flowId` each open so two new notes are never the
    /// same destination.
    @MainActor
    static func open(on tab: TabBar.Tab, model: Binding<UI2ShellModel>) {
        model.wrappedValue.push(.newNote(flowId: UUID()), on: tab)
    }
}
