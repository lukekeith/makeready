//
//  HighlightDraftStore.swift
//  MakeReady
//
//  Note drafts, keyed by the highlight's IDENTITY — and the one place where a
//  merge's succession is handled.
//
//  This is the fix for monday#12708759849 sub-issue A ("exegesis notes erased on
//  merge"), replacing the narrow re-key shipped in phase 1 (09 §C-b).
//
//  The bug's shape: the editor kept three parallel dictionaries keyed by a
//  string derived from the highlight's SPAN (`"location:length"`). A span is
//  mutable data — the moment the server merged two highlights, every key derived
//  from the old spans pointed at nothing, and a note that was still safely in
//  the database read back as "no note".
//
//  Re-keying by id is necessary but NOT sufficient, and that is the whole point
//  of this type. A merge does not move an entity, it DESTROYS entities and
//  creates a new one — so id-keyed state is orphaned by a merge exactly as
//  range-keyed state was. The server already reports what happened (the created
//  row plus `absorbedIds`, 03 §2.2); succession has to be handled somewhere, and
//  `applyMerge` is that somewhere. One call site, so it cannot be half-done.
//
//  See docs/features/highlighting/06-iphone.md §Note keying and 13 §4.8b.
//

import Foundation

/// One highlight's in-progress note.
struct HighlightDraft: Equatable {

    /// The canonical text. Markdown is what the server stores.
    var markdown: String

    /// The rich-text editor's working copy. `nil` means "no working copy yet —
    /// render it from `markdown`", which is also how `applyMerge` signals that
    /// the text changed underneath the editor.
    var attributed: AttributedString?

    /// True when `markdown` differs from what the server has. Only dirty drafts
    /// need saving, and only dirty drafts are worth carrying through a merge.
    var isDirty: Bool

    init(markdown: String, attributed: AttributedString? = nil, isDirty: Bool = false) {
        self.markdown = markdown
        self.attributed = attributed
        self.isDirty = isDirty
    }
}

/// The editor's note drafts for one activity, keyed by `ContentHighlight.id`.
///
/// Replaces three parallel dictionaries. The third of those,
/// `savedNoteMarkdownByHighlight`, is **deleted rather than re-keyed**: it was a
/// mirror of server state that existed only because the view did not treat the
/// entity as the source of truth. Now that highlights live in
/// `AppState.contentHighlights` (phase 4.8), the saved note *is*
/// `state.contentHighlights[id]?.noteMarkdown`, and a second copy could only
/// disagree with it.
struct HighlightDraftStore: Equatable {

    private(set) var drafts: [String: HighlightDraft] = [:]

    init() {}

    // MARK: Reading

    subscript(id: String) -> HighlightDraft? { drafts[id] }

    /// The text to show for a highlight: its draft if one exists, otherwise the
    /// saved note.
    func markdown(for highlight: ContentHighlight) -> String {
        drafts[highlight.id]?.markdown ?? highlight.noteMarkdown
    }

    /// Ids whose text differs from the server's, in no particular order.
    var dirtyIds: [String] {
        drafts.filter(\.value.isDirty).map(\.key)
    }

    var isEmpty: Bool { drafts.isEmpty }

    // MARK: Writing

    /// Give every highlight a draft, seeded from its saved note. Existing
    /// drafts are left alone — seeding must never clobber unsaved typing.
    mutating func seed(from highlights: [ContentHighlight]) {
        for highlight in highlights where drafts[highlight.id] == nil {
            drafts[highlight.id] = HighlightDraft(markdown: highlight.noteMarkdown)
        }
    }

    /// Record what the user typed.
    mutating func setMarkdown(_ markdown: String, attributed: AttributedString? = nil, for highlight: ContentHighlight) {
        drafts[highlight.id] = HighlightDraft(
            markdown: markdown,
            attributed: attributed,
            isDirty: markdown != highlight.noteMarkdown
        )
    }

    /// The rich-text working copy, if the editor has one.
    func attributed(for id: String) -> AttributedString? {
        drafts[id]?.attributed
    }

    /// Ensure a working copy exists, rendering it from the draft's markdown.
    ///
    /// Called BEFORE the editor is presented. Its bindings must do a pure
    /// stored read — computing a value inside the getter makes each page of the
    /// pager write back during the same update pass, which is an AttributeGraph
    /// cycle ending in "setting value during update" (crash, 2026-08-02).
    mutating func prepare(for highlight: ContentHighlight, render: (String) -> AttributedString) {
        var draft = drafts[highlight.id] ?? HighlightDraft(markdown: highlight.noteMarkdown)
        guard draft.attributed == nil else { return }
        draft.attributed = render(draft.markdown)
        drafts[highlight.id] = draft
    }

    /// The editor typed something: both representations move together.
    mutating func setAttributed(
        _ attributed: AttributedString,
        markdown: String,
        for highlight: ContentHighlight
    ) {
        drafts[highlight.id] = HighlightDraft(
            markdown: markdown,
            attributed: attributed,
            isDirty: markdown != highlight.noteMarkdown
        )
    }

    /// Throw away the working copy, keeping the text — the next `prepare` will
    /// re-render it. Used by Cancel.
    mutating func discardAttributed(for id: String) {
        drafts[id]?.attributed = nil
    }

    /// Put a draft back to a known text (Cancel restoring its snapshot).
    mutating func restore(markdown: String?, for id: String, savedMarkdown: String) {
        guard let markdown else {
            drafts.removeValue(forKey: id)
            return
        }
        drafts[id] = HighlightDraft(markdown: markdown, isDirty: markdown != savedMarkdown)
    }

    /// The server accepted this note; the draft is no longer ahead of it.
    mutating func markSaved(_ highlight: ContentHighlight) {
        drafts[highlight.id] = HighlightDraft(markdown: highlight.noteMarkdown)
    }

    /// Forget a highlight that no longer exists.
    mutating func forget(id: String) {
        drafts.removeValue(forKey: id)
    }

    /// Drop every draft whose highlight is gone.
    mutating func prune(keeping ids: some Sequence<String>) {
        let live = Set(ids)
        drafts = drafts.filter { live.contains($0.key) }
    }

    // MARK: The succession seam

    /// A merge happened: `created` absorbed and deleted `absorbedIds`.
    ///
    /// The server concatenates the absorbed rows' **saved** notes into the
    /// created row (03 §2.2), so `created.noteMarkdown` already carries
    /// everything that had been saved. What it cannot carry is text the user had
    /// typed but not yet saved — so any *dirty* absorbed draft is folded in
    /// after it, and the survivor stays dirty so that text still gets saved.
    ///
    /// Clean absorbed drafts are simply dropped: their content is, by
    /// definition, already inside `created.noteMarkdown`.
    ///
    /// `attributed` is cleared on the survivor because the markdown underneath
    /// the editor just changed; a stale rich-text copy would overwrite the merged
    /// note the next time it was saved.
    mutating func applyMerge(created: ContentHighlight, absorbedIds: [String]) {
        let unsaved = absorbedIds
            .compactMap { drafts[$0] }
            .filter(\.isDirty)
            .map(\.markdown)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for id in absorbedIds {
            drafts.removeValue(forKey: id)
        }

        var markdown = created.noteMarkdown
        var carriedSomething = false

        for text in unsaved where !markdown.contains(text) {
            markdown = markdown.isEmpty ? text : markdown + "\n\n" + text
            carriedSomething = true
        }

        // A pre-existing draft on the survivor itself also survives, if it was
        // ahead of the server.
        if let existing = drafts[created.id], existing.isDirty,
           !existing.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !markdown.contains(existing.markdown) {
            markdown = markdown.isEmpty ? existing.markdown : markdown + "\n\n" + existing.markdown
            carriedSomething = true
        }

        drafts[created.id] = HighlightDraft(
            markdown: markdown,
            attributed: nil,
            isDirty: carriedSomething
        )
    }
}
