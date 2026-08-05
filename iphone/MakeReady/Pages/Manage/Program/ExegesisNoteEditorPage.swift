//
//  ExegesisNoteEditorPage.swift
//  MakeReady
//
//  Full-screen editor for the note attached to an exegesis highlight.
//
//  Replaces the bottom-sheet editor that lived inside HighlightActionMenuContent.
//  The sheet sized itself from the keyboard, so the note field resized underneath
//  the user as they typed, and its Cancel/Done sat at the bottom competing with
//  the keyboard toolbar.
//
//  The shape here follows Apple Books' and Kindle's highlight-note editors:
//  a fixed full-screen surface, Cancel/Save in the header, the quoted passage
//  pinned above the note in a visually distinct non-editable treatment, and the
//  keyboard overlaying rather than reflowing the layout.
//
//  THE LOAD-BEARING LAYOUT RULE: nothing here is sized from the keyboard, and
//  nothing shrinks when it appears. Layout is: header, then FIXED dots, then one
//  ScrollView holding the passage (hugging its full content) and the note field
//  (growing with what you type). The keyboard overlays the bottom and
//  `keyboardBottomPadding()` adds room to scroll past it — padding only, never a
//  resize. That is why nothing moves underneath the typing.
//

import SwiftUI

struct ExegesisNoteEditorPage: View {

    /// Every highlight on the block, in document order — one page each.
    ///
    /// ENTITIES, not ranges (highlighting phase 4.8b). The thing being edited is
    /// a highlight; its span is a property of it, derived here for display. A
    /// merge changes spans, so a page identified by its location is a page that
    /// stops existing the moment the server merges anything.
    let highlights: [ContentHighlight]
    /// Plain text of the whole block, which the spans index into.
    let highlightText: String

    @Binding var selectedId: String?
    @Binding var drafts: HighlightDraftStore

    /// Tells the page which highlight is showing so it can scroll it into view
    /// behind the editor.
    let onNavigate: (ContentHighlight) -> Void
    /// Stages ONE note's text. Save calls this for every note the session
    /// changed, then calls `onPersist` to write them.
    let onCommitNote: (ContentHighlight, String) -> Void
    /// Writes the staged notes to the server AND refreshes the page's highlight
    /// list. Without this the editor's Save only ever staged a draft, so the
    /// note never reached the server and reopening the highlight still offered
    /// "Add note" (Luke, 2026-08-02).
    let onPersist: () async throws -> Void
    /// Tears down the whole note-editing experience — deselects the highlight and
    /// makes sure the highlight action sheet does not reappear behind this.
    let onCancelAll: () -> Void
    let onDismiss: () -> Void

    /// Presented with RAW chrome (this view owns its background and its
    /// transition), so there is no injected dismiss closure to rely on — an
    /// earlier version read `dismissOverlay`, which page chrome never injects,
    /// and Cancel/Save silently did nothing. Going through the manager directly
    /// cannot fail that way.
    @Environment(OverlayManager.self) private var overlayManager
    /// Drives the dissolve. Full-screen surfaces here fade rather than push in
    /// from the right (Luke).
    @State private var appeared = false

    /// Page index, driven by and driving `selectedId`.
    @State private var pageIndex: Int = 0
    /// Drafts as they were when the editor opened, for Cancel. Captured for
    /// EVERY highlight the session touches, not just the first — Save and Cancel
    /// are session-wide (Luke, 2026-08-02).
    @State private var originalDrafts: [String: String] = [:]
    @State private var originallyMissingDrafts: Set<String> = []
    @State private var isSaving = false
    @State private var didCaptureOriginals = false
    /// Which page the horizontal scroll view has settled on. Optional because
    /// that is the shape `.scrollPosition(id:)` binds to.
    @State private var scrolledIndex: Int?

    // MARK: - Layout constants

    private let headerHeight: CGFloat = 56
    private let dotsRowHeight: CGFloat = 28
    /// A comfortable starting target for the note field. It only ever GROWS from
    /// here as you type — nothing shrinks it, and the keyboard never touches it.
    private let noteFieldMinHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            // Dots are FIXED at the top, above the paging content, so they stay
            // put while the pages move under them (Luke).
            if !highlights.isEmpty {
                dots
                    .frame(height: dotsRowHeight)
            }

            highlightPager
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        // Nothing reflows when the keyboard appears — it overlays the bottom of
        // the page, which scrolls.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.micro) { appeared = true }
            captureOriginalsIfNeeded()
            if let selectedId,
               let index = highlights.firstIndex(where: { $0.id == selectedId }) {
                pageIndex = index
            }
            // Open on the highlight that was tapped.
            scrolledIndex = pageIndex
        }
        // The pager is the source of truth for which page is showing; mirror it
        // into `pageIndex` so the dots and the draft bindings follow.
        .onChange(of: scrolledIndex) { _, newIndex in
            guard let newIndex, newIndex != pageIndex else { return }
            pageIndex = newIndex
        }
        .onChange(of: pageIndex) { _, newIndex in
            guard highlights.indices.contains(newIndex) else { return }
            let highlight = highlights[newIndex]
            snapshotOriginal(for: highlight)
            // `onNavigate` already assigns the page's selection; assigning
            // `selectedId` here too wrote the same parent state twice in one
            // update cycle. Drafts are seeded before presentation, so there is
            // nothing to prepare here either.
            onNavigate(highlight)
        }
        .onDisappear(perform: onDismiss)
    }

    /// Fades the surface out, then removes it. Uses the iOS 17 completion
    /// handler rather than an asyncAfter wall-clock wait.
    private func dismissWithFade() {
        withAnimation(Motion.micro) {
            appeared = false
        } completion: {
            overlayManager.dismiss(.exegesisNoteEditor)
        }
    }

    // MARK: - Paging

    private var currentHighlight: ContentHighlight? {
        guard highlights.indices.contains(pageIndex) else { return highlights.first }
        return highlights[pageIndex]
    }

    /// A genuinely interactive pager: the current highlight tracks your finger,
    /// its neighbours are glued either side, and it snaps to whichever you land
    /// on (Luke).
    ///
    /// Built on the SwiftUI paging scroll APIs rather than `TabView(.page)` —
    /// `TabView` is a UIPageViewController whose UIKit scroll view re-insets
    /// itself for the keyboard, which no SwiftUI modifier can suppress, and that
    /// was the layout jump on focus. A plain `ScrollView` honours
    /// `.ignoresSafeArea(.keyboard)`. It is also NOT a hand-rolled HStack+offset
    /// slider, which this codebase forbids for new navigation surfaces.
    ///
    /// The HStack is eager, not lazy: page count is the number of highlights on
    /// one passage (a handful), and lazy containers inside animated surfaces are
    /// a documented failure class here.
    private var highlightPager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                    highlightPage(for: highlight)
                        .frame(width: Screen.bounds.width)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledIndex)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// One highlight: the passage hugging its full content, then the note field.
    /// Scrolls vertically on its own — the pager owns horizontal, this owns
    /// vertical, so neither has to arbitrate against the other.
    private func highlightPage(for highlight: ContentHighlight) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                referenceBlock(for: highlight)

                MarkdownEditor(
                    placeholder: "Add a note...",
                    attributedText: draftBinding(for: highlight),
                    minHeight: noteFieldMinHeight,
                    autoGrow: true
                )
                .id(highlight.id)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .keyboardBottomPadding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private var header: some View {
        PageTitle.linkTitleLink(
            title: "Note",
            leftLink: "Cancel",
            // Always reads "Save" — muted and inert until something has actually
            // changed, rather than swapping to a different word (Luke).
            rightLink: isSaving ? "Saving..." : "Save",
            // `rightLinkDisabled`, NOT `rightLinkColor` — PageTitle only ever
            // rendered the former, so the colour I was passing did nothing and
            // Save always looked live (Luke, 2026-08-02). This both mutes it and
            // makes it untappable.
            rightLinkDisabled: isSaving || !hasUnsavedChanges,
            onLeftLinkTap: {
                guard !isSaving else { return }
                restoreOriginals()
                // Cancel leaves the whole note-editing experience, not just this
                // screen: the editor closes, the highlight is deselected and the
                // action sheet does not come back (Luke).
                onCancelAll()
                dismissWithFade()
            },
            onRightLinkTap: {
                guard !isSaving, hasUnsavedChanges else { return }
                saveAllChangedNotes()
            }
        )
    }

    /// Dot navigation. Fixed above the paging content so it never slides with it.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(highlights.indices, id: \.self) { index in
                // Standard iOS page-control colouring: white for the current
                // page, dimmed white for the rest (Luke) — not the brand purple.
                // UIPageControl's own values are white / white @ 30%.
                Circle()
                    .fill(index == pageIndex
                          ? Color.white
                          : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(Motion.micro, value: pageIndex)
        .frame(maxWidth: .infinity)
    }

    // MARK: - One highlight's page

    /// The quoted passage. It IS scripture, so it renders through the same
    /// `ExegesisVerseView` the editor and the Bible reader use — serif face,
    /// hanging verse badges in the left rail — rather than as flat body text
    /// (Luke). Selection is off: this is reference material, not an input.
    /// The underlying UITextView scrolls, so a long highlight can be read in
    /// full while writing.
    private func referenceBlock(for highlight: ContentHighlight) -> some View {
        // Hugs its content: `ExegesisVerseView` sets `isScrollEnabled = false`
        // and self-sizes via `sizeThatFits`, so given no height constraint it
        // renders the WHOLE highlight and the page's single ScrollView carries
        // it. A fixed frame here only ever clipped it (Luke, 2026-08-02).
        ExegesisVerseView(
            plainText: excerpt(for: highlight),
            highlights: [],
            isSelectionEnabled: false,
            usePreviewHighlightStyle: true,
            pendingRange: .constant(nil)
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.vertical, 8)
        .background(Color.backgroundDark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Draft plumbing

    private func excerpt(for highlight: ContentHighlight) -> String {
        let text = highlightText as NSString
        let range = NSRange(location: highlight.start, length: highlight.end - highlight.start)
        guard range.location >= 0,
              range.location + range.length <= text.length else { return "" }
        return text.substring(with: range)
    }

    private func draftBinding(for highlight: ContentHighlight) -> Binding<AttributedString> {
        Binding(
            // A PURE STORED READ. It must never compute a value here: TabView
            // builds several pages at once, so each MarkdownEditor would receive
            // a freshly-built AttributedString, write it back during the same
            // update pass, and invalidate the getter that produced it — an
            // AttributeGraph cycle ending in "setting value during update"
            // (crash, 2026-08-02; /animation-debug class 5). The page's drafts
            // are seeded by `seedNoteDrafts()` BEFORE this view is presented, so
            // the fallback below is only ever hit for a genuinely empty note.
            get: { drafts.attributed(for: highlight.id) ?? AttributedString() },
            set: { newValue in
                drafts.setAttributed(
                    newValue,
                    markdown: MarkdownEditor.attributedToMarkdown(newValue),
                    for: highlight
                )
            }
        )
    }

    private func prepareDraft(for highlight: ContentHighlight) {
        drafts.prepare(for: highlight) { MarkdownEditor.markdownToAttributed($0) }
    }

    /// Snapshots the starting text of EVERY highlight, not just the tapped one.
    /// The pager builds all pages, any of them can be edited before Save, and
    /// "is there anything to save?" is answered by comparing against these.
    private func captureOriginalsIfNeeded() {
        guard !didCaptureOriginals else { return }
        didCaptureOriginals = true
        for highlight in highlights {
            prepareDraft(for: highlight)
            snapshotOriginal(for: highlight)
        }
    }

    private func snapshotOriginal(for highlight: ContentHighlight) {
        let key = highlight.id
        guard originalDrafts[key] == nil,
              !originallyMissingDrafts.contains(key) else { return }
        if let current = drafts[key]?.markdown {
            originalDrafts[key] = current
        } else {
            originallyMissingDrafts.insert(key)
        }
    }

    // MARK: - Save / cancel (session-wide)

    /// Every highlight whose draft differs from what is saved on the server.
    /// Highlights whose note differs from what it was when the editor opened.
    ///
    /// Compared against `originalDrafts` — the snapshot taken on appear — and
    /// keyed by highlight ID. The predecessor compared against a dictionary
    /// keyed by exact span string, which could miss (the same miss that
    /// mislabelled "Add note"); a miss read as `""`, which made every seeded
    /// note look changed and lit Save up before anything had been typed
    /// (Luke, 2026-08-02). An id cannot miss.
    private var changedHighlights: [ContentHighlight] {
        highlights.filter { highlight in
            let current = (drafts[highlight.id]?.markdown ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let original = (originalDrafts[highlight.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return current != original
        }
    }

    private var hasUnsavedChanges: Bool { !changedHighlights.isEmpty }

    private func saveAllChangedNotes() {
        let changed = changedHighlights
        guard !changed.isEmpty else {
            dismissWithFade()
            return
        }

        isSaving = true
        for highlight in changed {
            onCommitNote(highlight, drafts[highlight.id]?.markdown ?? "")
        }

        // Staging is not saving. Persist, and only dismiss once it lands — the
        // page refreshes its highlights in the same call, so reopening this
        // highlight now correctly reads "Edit note".
        Task {
            do {
                try await onPersist()
                await MainActor.run {
                    isSaving = false
                    dismissWithFade()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    AppState.shared.recordError(
                        error,
                        context: "ExegesisNoteEditorPage.save",
                        surface: true,
                        friendlyMessage: "Couldn't save the note"
                    )
                }
            }
        }
    }

    /// Cancel puts every draft the session touched back the way it was —
    /// including highlights the user swiped through and edited, not just the
    /// visible one.
    private func restoreOriginals() {
        let savedById = Dictionary(uniqueKeysWithValues: highlights.map { ($0.id, $0.noteMarkdown) })
        for (key, markdown) in originalDrafts {
            drafts.restore(markdown: markdown, for: key, savedMarkdown: savedById[key] ?? "")
            drafts.discardAttributed(for: key)
        }
        for key in originallyMissingDrafts {
            drafts.restore(markdown: nil, for: key, savedMarkdown: savedById[key] ?? "")
        }
        originalDrafts.removeAll()
        originallyMissingDrafts.removeAll()
    }
}
