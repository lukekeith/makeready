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
    let highlightRanges: [NSRange]
    /// Plain text of the whole block, which the ranges index into.
    let highlightText: String

    @Binding var selectedRange: NSRange?
    @Binding var noteDrafts: [String: String]
    @Binding var attributedNoteDrafts: [String: AttributedString]
    @Binding var savedNoteMarkdownByHighlight: [String: String]

    /// Tells the page which highlight is showing so it can scroll it into view
    /// behind the editor.
    let onNavigate: (NSRange) -> Void
    /// Stages ONE note's text. Save calls this for every note the session
    /// changed, then calls `onPersist` to write them.
    let onCommitNote: (NSRange, String) -> Void
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

    /// Page index, driven by and driving `selectedRange`.
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
            if !highlightRanges.isEmpty {
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
            if let selectedRange,
               let index = highlightRanges.firstIndex(where: { NSEqualRanges($0, selectedRange) }) {
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
            guard highlightRanges.indices.contains(newIndex) else { return }
            let range = highlightRanges[newIndex]
            snapshotOriginal(for: range)
            // `onNavigate` already assigns the page's selected range; assigning
            // `selectedRange` here too wrote the same parent state twice in one
            // update cycle. Drafts are seeded before presentation, so there is
            // nothing to prepare here either.
            onNavigate(range)
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

    private var currentRange: NSRange? {
        guard highlightRanges.indices.contains(pageIndex) else { return highlightRanges.first }
        return highlightRanges[pageIndex]
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
                ForEach(Array(highlightRanges.enumerated()), id: \.offset) { index, range in
                    highlightPage(for: range)
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
    private func highlightPage(for range: NSRange) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                referenceBlock(for: range)

                MarkdownEditor(
                    placeholder: "Add a note...",
                    attributedText: draftBinding(for: range),
                    minHeight: noteFieldMinHeight,
                    autoGrow: true
                )
                .id(rangeKey(for: range))
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
            ForEach(highlightRanges.indices, id: \.self) { index in
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
    private func referenceBlock(for range: NSRange) -> some View {
        // Hugs its content: `ExegesisVerseView` sets `isScrollEnabled = false`
        // and self-sizes via `sizeThatFits`, so given no height constraint it
        // renders the WHOLE highlight and the page's single ScrollView carries
        // it. A fixed frame here only ever clipped it (Luke, 2026-08-02).
        ExegesisVerseView(
            plainText: excerpt(for: range),
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

    private func rangeKey(for range: NSRange) -> String {
        "\(range.location):\(range.length)"
    }

    private func excerpt(for range: NSRange) -> String {
        let text = highlightText as NSString
        guard range.location >= 0,
              range.location + range.length <= text.length else { return "" }
        return text.substring(with: range)
    }

    private func draftBinding(for range: NSRange) -> Binding<AttributedString> {
        let key = rangeKey(for: range)
        return Binding(
            // A PURE STORED READ. It must never compute a value here: TabView
            // builds several pages at once, so each MarkdownEditor would receive
            // a freshly-built AttributedString, write it back during the same
            // update pass, and invalidate the getter that produced it — an
            // AttributeGraph cycle ending in "setting value during update"
            // (crash, 2026-08-02; /animation-debug class 5). The page's drafts
            // are seeded by `seedNoteDrafts()` BEFORE this view is presented, so
            // the fallback below is only ever hit for a genuinely empty note.
            get: { attributedNoteDrafts[key] ?? AttributedString() },
            set: { newValue in
                attributedNoteDrafts[key] = newValue
                noteDrafts[key] = MarkdownEditor.attributedToMarkdown(newValue)
            }
        )
    }

    private func prepareDraft(for range: NSRange) {
        let key = rangeKey(for: range)
        guard attributedNoteDrafts[key] == nil else { return }
        let markdown = noteDrafts[key] ?? savedNoteMarkdownByHighlight[key] ?? ""
        attributedNoteDrafts[key] = MarkdownEditor.markdownToAttributed(markdown)
        noteDrafts[key] = markdown
    }

    /// Snapshots the starting text of EVERY highlight, not just the tapped one.
    /// The pager builds all pages, any of them can be edited before Save, and
    /// "is there anything to save?" is answered by comparing against these.
    private func captureOriginalsIfNeeded() {
        guard !didCaptureOriginals else { return }
        didCaptureOriginals = true
        for range in highlightRanges {
            prepareDraft(for: range)
            snapshotOriginal(for: range)
        }
    }

    private func snapshotOriginal(for range: NSRange) {
        let key = rangeKey(for: range)
        guard originalDrafts[key] == nil,
              !originallyMissingDrafts.contains(key) else { return }
        if let current = noteDrafts[key] {
            originalDrafts[key] = current
        } else {
            originallyMissingDrafts.insert(key)
        }
    }

    // MARK: - Save / cancel (session-wide)

    /// Every highlight whose draft differs from what is saved on the server.
    /// Highlights whose note differs from what it was when the editor opened.
    ///
    /// Compared against `originalDrafts` — the snapshot taken on appear — NOT
    /// against `savedNoteMarkdownByHighlight`. That dictionary is keyed by exact
    /// span string and can miss (the same miss that mislabelled "Add note"), and
    /// a miss there reads as `""`, which made every seeded note look changed and
    /// lit Save up before anything had been typed (Luke, 2026-08-02).
    private var changedRanges: [NSRange] {
        highlightRanges.filter { range in
            let key = rangeKey(for: range)
            let current = (noteDrafts[key] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let original = (originalDrafts[key] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return current != original
        }
    }

    private var hasUnsavedChanges: Bool { !changedRanges.isEmpty }

    private func saveAllChangedNotes() {
        let ranges = changedRanges
        guard !ranges.isEmpty else {
            dismissWithFade()
            return
        }

        isSaving = true
        for range in ranges {
            let key = rangeKey(for: range)
            let markdown = noteDrafts[key] ?? ""
            onCommitNote(range, markdown)
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                savedNoteMarkdownByHighlight.removeValue(forKey: key)
            } else {
                savedNoteMarkdownByHighlight[key] = markdown
            }
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
        for (key, markdown) in originalDrafts {
            noteDrafts[key] = markdown
            attributedNoteDrafts.removeValue(forKey: key)
        }
        for key in originallyMissingDrafts {
            noteDrafts.removeValue(forKey: key)
            attributedNoteDrafts.removeValue(forKey: key)
        }
        originalDrafts.removeAll()
        originallyMissingDrafts.removeAll()
    }
}
