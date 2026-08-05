//
//  EditExegesisActivityPage.swift
//  MakeReady
//
//  Editor for EXEGESIS activities.
//
//  Layout: title → passage chip → image/color row → font size → inline passage preview → highlights list
//  The inline preview container supports direct highlight editing while the Preview
//  button opens the same full-screen member preview used by the other activity editors.
//
//  Invariants:
//   - Exactly one locked scripture read block (managed via /source-references)
//   - One or more highlights (ContentHighlight rows) attached to that block
//   - Verse text is never edited — only selected/highlighted
//

import SwiftUI

/// Action closures for EXEGESIS activity operations, allowing reuse across the
/// program and enrollment contexts (same pattern as ReadActivityActionProvider).
/// All mutations route through Actions, which write to AppState; views observe.
struct ExegesisActivityActionProvider {
    let context: LessonContext
    /// Live activity lookup so blocks/selections re-read fresh from AppState.
    /// @MainActor: synchronous closures that touch AppState (main-actor
    /// isolated) — the async closures below hop via await instead.
    let liveActivity: @MainActor (String) -> StudyActivity?
    /// Optimistic local write of merged selections: (activityId, blockId, merged).
    let applyLocalSelections: @MainActor (String, String, [ReadBlockSelection]) -> Void
    /// Loads the activity's highlights INTO AppState. Void by design — the
    /// view reads `AppState.contentHighlights`, it does not own a copy.
    let loadHighlights: (String) async throws -> Void
    /// (activityId, readBlockId, span, noteMarkdown) -> the created row PLUS the
    /// rows the server's merge absorbed (03 §2.2).
    let createHighlight: (String, String, HighlightSpan, String) async throws -> HighlightCreateResult
    /// (activityId, highlightId, noteMarkdown)
    let updateHighlightNote: (String, String, String) async throws -> ContentHighlight
    /// (activityId, highlightId)
    let deleteHighlight: (String, String) async throws -> Void
    /// (activityId, blockId, selections)
    let updateSelections: (String, String, [ReadBlockSelection]) async throws -> Void
    /// (activityId, passageData, content)
    let addSourceReference: (String, PassageData, String?) async throws -> Void
    /// (activityId, title)
    let updateTitle: (String, String) async throws -> Void
    /// Block styling (image/color/font via BlockStyleEditor + snapshot revert)
    /// is program-only for now — BlockStyleEditor talks to ProgramActions.
    let supportsBlockStyling: Bool
    /// Member-preview URL for the given activity id. @MainActor: the
    /// enrollment builder calls PreviewWebView.buildPreviewURL,
    /// whose View-conforming type is main-actor isolated.
    let previewURL: @MainActor (String) -> URL?

    /// Default: program activities via ProgramActions + the program entity store.
    static var program: ExegesisActivityActionProvider {
        ExegesisActivityActionProvider(
            context: .program,
            liveActivity: { AppState.shared.activities[$0] },
            applyLocalSelections: { activityId, blockId, merged in
                if var activity = AppState.shared.activities[activityId],
                   var blocks = activity.readBlocks,
                   let index = blocks.firstIndex(where: { $0.id == blockId }) {
                    blocks[index].selections = merged
                    activity.readBlocks = blocks
                    AppState.shared.activities.upsert(activity)
                    AppState.shared.persist()
                }
            },
            loadHighlights: { try await ProgramActions().loadHighlights(activityId: $0) },
            createHighlight: { activityId, readBlockId, span, note in
                try await ProgramActions().createHighlight(
                    activityId: activityId, readBlockId: readBlockId, span: span, noteMarkdown: note
                )
            },
            updateHighlightNote: { activityId, highlightId, note in
                try await ProgramActions().updateHighlight(
                    activityId: activityId, highlightId: highlightId, noteMarkdown: note
                )
            },
            deleteHighlight: { activityId, highlightId in
                try await ProgramActions().deleteHighlight(activityId: activityId, highlightId: highlightId)
            },
            updateSelections: { activityId, blockId, selections in
                try await ProgramActions().updateReadBlockSelections(activityId: activityId, blockId: blockId, selections: selections)
            },
            addSourceReference: { activityId, passageData, content in
                _ = try await ProgramActions().addSourceReference(activityId: activityId, passageData: passageData, content: content)
            },
            updateTitle: { activityId, title in
                _ = try await ProgramActions().updateActivityContent(activityId: activityId, title: title)
            },
            supportsBlockStyling: true,
            previewURL: { LessonPreviewModal.lessonURL(forActivityId: $0) }
        )
    }

    /// Enrollment: scheduled activities via EnrollmentActions + the scheduled
    /// lesson aggregate. `lessonId` is the scheduled lesson containing the activity.
    static func enrollment(lessonId: String) -> ExegesisActivityActionProvider {
        ExegesisActivityActionProvider(
            context: .enrollment,
            liveActivity: { activityId in
                AppState.shared.scheduledLessons[lessonId]?
                    .activities.first { $0.id == activityId }?.toStudyActivity()
            },
            applyLocalSelections: { activityId, blockId, merged in
                _ = AppState.shared.mutateScheduledActivity(activityId: activityId) { activity in
                    if var blocks = activity.readBlocks,
                       let index = blocks.firstIndex(where: { $0.id == blockId }) {
                        blocks[index].selections = merged
                        activity.readBlocks = blocks
                    }
                }
                AppState.shared.persist()
            },
            loadHighlights: { try await EnrollmentActions().loadHighlights(activityId: $0) },
            createHighlight: { activityId, readBlockId, span, note in
                try await EnrollmentActions().createHighlight(
                    activityId: activityId, readBlockId: readBlockId, span: span, noteMarkdown: note
                )
            },
            updateHighlightNote: { activityId, highlightId, note in
                try await EnrollmentActions().updateHighlight(
                    activityId: activityId, highlightId: highlightId, noteMarkdown: note
                )
            },
            deleteHighlight: { activityId, highlightId in
                try await EnrollmentActions().deleteHighlight(activityId: activityId, highlightId: highlightId)
            },
            updateSelections: { activityId, blockId, selections in
                try await EnrollmentActions().updateReadBlockSelections(activityId: activityId, blockId: blockId, selections: selections)
            },
            addSourceReference: { activityId, passageData, content in
                _ = try await EnrollmentActions().addSourceReference(activityId: activityId, passageData: passageData, content: content)
            },
            updateTitle: { activityId, title in
                _ = try await EnrollmentActions().updateScheduledActivity(
                    activityId: activityId, title: title, helpTitle: nil, helpDescription: nil
                )
            },
            supportsBlockStyling: false,
            previewURL: { PreviewWebView.buildPreviewURL(activityId: $0) }
        )
    }
}

struct EditExegesisActivityPage: View {
    let activity: StudyActivity
    let programId: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    var actions: ExegesisActivityActionProvider = .program

    @Environment(AuthManager.self) var authManager
    @Environment(OverlayManager.self) private var overlayManager

    private var canEdit: Bool {
        guard let programId else { return false }
        return AppState.shared.programs[programId]?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    // MARK: - Title state

    @State private var title: String = ""
    @State private var originalTitle: String = ""
    @State private var isSavingTitle = false
    /// True when the on-screen form matches what's been saved. Opens as
    /// `true` so the right-link shows "Done" on first appear — flips to
    /// `false` on any edit, flips back on successful `save()`.
    @State private var hasSaved = true
    @State private var savedStyleFingerprint: String = ""

    // MARK: - Snapshot for Cancel revert

    @State private var snapshotBlockId: String? = nil
    @State private var snapshotImageUrl: String? = nil
    @State private var snapshotColor: String? = nil
    @State private var snapshotOpacity: Double? = nil
    @State private var snapshotFontSize: String? = nil
    @State private var snapshotPassageTitle: String? = nil

    @State private var showChangePassageDialog = false
    @State private var showSlidePreview = false
    @State private var selectedHighlightRange: NSRange?
    @State private var scrollSelectedHighlightIntoView = false
    /// Note drafts keyed by highlight ID (highlighting phase 4.8b). Replaces
    /// three dictionaries keyed by `"location:length"` — a key derived from
    /// mutable data, which every merge invalidated (monday#12708759849 sub-issue
    /// A). `savedNoteMarkdownByHighlight` is gone entirely: the saved note is
    /// the entity's own `noteMarkdown` now that highlights live in `AppState`.
    @State private var draftStore = HighlightDraftStore()
    /// Derived from `AppState`, not held here (highlighting phase 4.8).
    /// Highlights are server data with identity that three screens read, so a
    /// view-local copy is exactly the forked state the state-management rule
    /// exists to prevent — and SwiftLint's `server_collection_in_view_state`
    /// enforces it.
    private var exegesisHighlights: [ContentHighlight] {
        let blockIds = Set((activity.readBlocks ?? []).filter(\.isLocked).map(\.id))
        return AppState.shared.contentHighlights.all
            .filter { blockIds.contains($0.readBlockId) }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start { return lhs.end < rhs.end }
                return lhs.start < rhs.start
            }
    }

    // MARK: - Derived

    private var lockedBlock: ActivityReadBlock? {
        actions.liveActivity(activity.id)?.readBlocks?.first(where: { $0.isLocked })
    }

    private var hasPassage: Bool { lockedBlock != nil }
    private var storedImageUrl: String? { lockedBlock?.backgroundImageUrl }
    private var selectedColor: String? { lockedBlock?.backgroundColor }
    private var storedOpacity: Double? { lockedBlock?.backgroundOverlayOpacity }
    private var effectiveFontSize: String { lockedBlock?.fontSize ?? "m" }
    private var effectiveOpacity: Double { storedOpacity ?? 0.8 }
    private var sortedHighlightRanges: [NSRange] {
        (lockedBlock?.selections ?? [])
            .filter { selection in
                ReadBlockSelectionStyle(rawValue: selection.style) == .highlight && selection.end > selection.start
            }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start { return lhs.end < rhs.end }
                return lhs.start < rhs.start
            }
            .map { NSRange(location: $0.start, length: $0.end - $0.start) }
    }

    /// Fingerprint of the block's styling — changes when image, color, opacity, or font size change.
    private var blockStyleFingerprint: String {
        "\(storedImageUrl ?? "")||\(selectedColor ?? "")||\(storedOpacity ?? 0)||\(effectiveFontSize)"
    }

    // MARK: - Body

    var body: some View {
        mainContent
        .onAppear {
            title = activity.title ?? activity.type.displayName
            originalTitle = title
            savedStyleFingerprint = blockStyleFingerprint

            // Snapshot for cancel revert
            let block = lockedBlock
            snapshotBlockId = block?.id
            snapshotImageUrl = block?.backgroundImageUrl
            snapshotColor = block?.backgroundColor
            snapshotOpacity = block?.backgroundOverlayOpacity
            snapshotFontSize = block?.fontSize
            snapshotPassageTitle = block?.title

            Task { await loadExegesisHighlights() }
        }
        .fullScreenCover(isPresented: $showSlidePreview) {
            LessonPreviewModal(
                url: actions.previewURL(activity.id),
                isPresented: $showSlidePreview
            )
        }
        .onChange(of: title) { _, newTitle in
            if newTitle != originalTitle { hasSaved = false }
        }
        .onChange(of: blockStyleFingerprint) { _, newFingerprint in
            if newFingerprint != savedStyleFingerprint { hasSaved = false }
        }
    }

    // MARK: - Screen 1: Main Content

    private var mainContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header

                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Title
                                FieldGroup {
                                    TextInput(
                                        floatingLabel: "Activity title",
                                        autocorrect: true,
                                        // Server caps activity titles at 200 chars; enforce at
                                        // entry so a long title can't fail the save (monday#12297338039).
                                        maxLength: 200,
                                        text: $title
                                    )
                                }
                                .padding(.horizontal, 16)
                                .disabled(!canEdit)

                                // Passage chip
                                passageRow
                                    .padding(.horizontal, 16)

                                // Image, color, and font size controls.
                                // Program-only: BlockStyleEditor is wired to
                                // ProgramActions and the program entity store.
                                if hasPassage, actions.supportsBlockStyling, let blockId = lockedBlock?.id {
                                    BlockStyleEditor(
                                        activityId: activity.id,
                                        blockId: blockId,
                                        onColorPickerOpened: {
                                            withAnimation {
                                                scrollProxy.scrollTo("blockStyleEditor", anchor: .top)
                                            }
                                        }
                                    )
                                    .id("blockStyleEditor")
                                    .padding(.horizontal, 16)
                                    .disabled(!canEdit)
                                    .environment(overlayManager)
                                }

                                // Preview container — natural height, no scroll wrapper
                                previewContainer
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 16)
                                    .id("previewContainer")

                                // Full-screen member preview button, matching the other edit pages.
                                BoxButton(
                                    action: { showSlidePreview = true },
                                    label: "Preview",
                                    icon: "eye",
                                    iconPosition: .right,
                                    variant: .secondary,
                                    style: .solid,
                                    size: .lg,
                                    fullWidth: true,
                                    iconOpacity: 0.5
                                )
                                .padding(.horizontal, 16)

                                Spacer().frame(height: 32)
                            }
                            .padding(.top, 16)
                        }
                    }
                }
            }

            DialogOverlay(
                isPresented: $showChangePassageDialog,
                title: "Change passage?",
                message: "Changing the passage will remove all highlights for this activity.",
                buttons: [
                    DialogButtonConfig("Cancel", style: .secondary) {},
                    DialogButtonConfig("Change", style: .primary) {
                        presentBibleReaderOverlay()
                    }
                ]
            )
        }
    }


    // MARK: - Header

    private var header: some View {
        Group {
            if canEdit {
                PageTitle.linkTitleLink(
                    title: "Edit Activity",
                    leftLink: "Cancel",
                    rightLink: isSavingTitle ? "Saving..." : (hasSaved ? "Done" : "Save"),
                    rightLinkColor: isSavingTitle ? .white.opacity(0.3) : nil,
                    onLeftLinkTap: { cancelAndRevert() },
                    onRightLinkTap: {
                        guard !isSavingTitle else { return }
                        if hasSaved {
                            onSave()
                        } else {
                            saveTitle()
                        }
                    }
                )
            } else {
                PageTitle.iconTitle(
                    title: "Activity",
                    icon: "chevron.left",
                    onIconTap: { onCancel() }
                )
            }
        }
    }

    // MARK: - Passage Row (chip style)

    private var passageRow: some View {
        HStack {
            Text("Passage")
                .font(Typography.s16Bold)
                .foregroundColor(.white)

            Spacer()

            Button {
                guard canEdit else { return }
                selectPassageTapped()
            } label: {
                Text(lockedBlock?.title ?? "select passage")
                    .font(Typography.s14Semibold)
                    .foregroundColor(hasPassage ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if hasPassage {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.brandPrimary, lineWidth: 1.5)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 764px Preview Container

    @ViewBuilder
    private var previewContainer: some View {
        ZStack {
            // Background layers
            ZStack {
                Color(hex: "#1A1D28")

                if let url = storedImageUrl, let parsed = URL(string: url) {
                    GeometryReader { geo in
                        AsyncImage(url: parsed) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        }
                    }
                }

                if let hex = selectedColor {
                    Color(hex: hex)
                        .opacity(storedImageUrl != nil ? effectiveOpacity : 1.0)
                }
            }

            // Verse content. Editable users get native UITextView selection:
            // long-press/drag selects arbitrary character ranges, then the
            // selected span is persisted directly as a read-block highlight.
            if let block = lockedBlock, let content = block.content, !content.isEmpty {
                ExegesisVerseView(
                    plainText: BibleVerseContentNormalizer.normalizedPlainText(from: content),
                    highlights: block.selections ?? [],
                    isSelectionEnabled: canEdit,
                    fontSize: InlineFontSizePicker.previewPointSize(effectiveFontSize),
                    usePreviewHighlightStyle: false,
                    selectedHighlightRange: selectedHighlightRange,
                    scrollSelectedHighlightIntoView: scrollSelectedHighlightIntoView,
                    usesNativeTextSelection: true,
                    onRangeSelected: { range in
                        selectedHighlightRange = nil
                        scrollSelectedHighlightIntoView = false
                        overlayManager.dismiss(.exegesisHighlightActionMenu)
                        applyStyle(.highlight, range: range, blockId: block.id, activityId: activity.id)
                    },
                    onHighlightTapped: { range in
                        selectedHighlightRange = range
                        scrollSelectedHighlightIntoView = false
                        presentHighlightActionMenu()
                    },
                    pendingRange: .constant(nil)
                )
                .padding(16)
            }
        }
    }

    // MARK: - Passage Actions

    private func presentHighlightActionMenu() {
        guard lockedBlock?.id != nil, selectedHighlightRange != nil else {
            overlayManager.dismiss(.exegesisHighlightActionMenu)
            return
        }

        // The TEMPORARY DIAGNOSTIC that lived here existed to decide whether the
        // note survived in the database. It did — proven at the API level on
        // 2026-08-04 (docs/features/highlighting/10-phase-1-*.md task 1.2), so
        // it has served its purpose and is removed.

        overlayManager.present(.exegesisHighlightActionMenu) {
            HighlightActionMenuContent(
                selectedRange: $selectedHighlightRange,
                highlightRanges: sortedHighlightRanges,
                highlightText: BibleVerseContentNormalizer.normalizedPlainText(from: lockedBlock?.content ?? ""),
                onNavigate: { range in
                    navigateToHighlight(range)
                },
                onDelete: {
                    guard let range = selectedHighlightRange,
                          let blockId = lockedBlock?.id else { return }
                    if let highlight = matchingExegesisHighlight(for: range) ?? overlappingExegesisHighlight(for: range) {
                        draftStore.forget(id: highlight.id)
                    }
                    applyStyle(nil, range: range, blockId: blockId, activityId: activity.id)
                },
                onEditNote: {
                    presentNoteEditor()
                },
                hasNote: selectedHighlightHasNote,
                onDismiss: {
                    selectedHighlightRange = nil
                    scrollSelectedHighlightIntoView = false
                }
            )
        }
    }

    /// Swaps the action sheet for the full-screen note editor. Sequenced
    /// dismiss-then-present via the overlay manager's completion — never
    /// `asyncAfter` (MODAL_GUIDE D3/E1).
    private func presentNoteEditor() {
        // Seed a draft for EVERY highlight before the editor exists. The editor's
        // pages read these dictionaries and must never fabricate a value mid-render
        // — that produced an AttributeGraph cycle and a "setting value during
        // update" crash (2026-08-02). Same cache-first discipline the slide-in
        // pages use: content is complete from frame 1.
        seedNoteDrafts()
        overlayManager.dismiss(.exegesisHighlightActionMenu) {
            overlayManager.present(.exegesisNoteEditor) {
                ExegesisNoteEditorPage(
                    highlights: exegesisHighlights,
                    highlightText: BibleVerseContentNormalizer.normalizedPlainText(
                        from: lockedBlock?.content ?? ""
                    ),
                    selectedId: selectedHighlightIdBinding,
                    drafts: $draftStore,
                    onNavigate: { highlight in
                        navigateToHighlight(range(of: highlight))
                    },
                    onCommitNote: { highlight, markdown in
                        commitNoteDraft(markdown, for: highlight)
                    },
                    onPersist: {
                        // The page's own server path — it writes each note and
                        // calls `upsertExegesisHighlight`, which is what keeps
                        // the highlight list (and so the "Edit note" label) in
                        // step with what was just saved.
                        try await savePendingNotes()
                    },
                    onCancelAll: {
                        selectedHighlightRange = nil
                        scrollSelectedHighlightIntoView = false
                        overlayManager.dismiss(.exegesisHighlightActionMenu)
                    },
                    onDismiss: {
                        selectedHighlightRange = nil
                        scrollSelectedHighlightIntoView = false
                    }
                )
            }
        }
    }

    /// The note attached to `range`, resolved against the AUTHORITATIVE server
    /// highlights first.
    ///
    /// The dictionary is keyed by `"location:length"` built from the block's
    /// `selections`, while the notes arrive on `exegesis_highlights` rows. Those
    /// are two separate server collections reaching the app by two paths — and
    /// `selections` comes off the disk cache — so requiring exact key equality
    /// meant a one-character drift silently reported "no note", which is what
    /// showed "Add note" on a highlight that had one (monday#12668543338).
    /// `overlappingExegesisHighlight` is the same overlap test the server itself
    /// enforces, so it cannot miss for a highlight that genuinely exists.
    /// The highlights the note editor pages through, and therefore how many dots
    /// it shows.
    ///
    /// Derived from the FETCHED `exegesisHighlights` rather than the block's
    /// `selections`, because `selections` arrives via the disk cache and can lag
    /// the server — and when it lags, the dot count silently drops (a stale cache
    /// holding one selection made the dots disappear entirely, since they only
    /// render for more than one page). Falls back to the selections when the
    /// fetch has not landed yet.
    private var noteEditorRanges: [NSRange] {
        guard !exegesisHighlights.isEmpty else { return sortedHighlightRanges }
        return exegesisHighlights
            .map { NSRange(location: $0.start, length: $0.end - $0.start) }
            .sorted { lhs, rhs in
                if lhs.location == rhs.location { return lhs.length < rhs.length }
                return lhs.location < rhs.location
            }
    }

    private func nonEmpty(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    private func noteMarkdown(for range: NSRange) -> String {
        overlappingExegesisHighlight(for: range)?.noteMarkdown ?? ""
    }

    private func range(of highlight: ContentHighlight) -> NSRange {
        NSRange(location: highlight.start, length: highlight.end - highlight.start)
    }

    /// Bridges the page's range-based selection to the note editor's
    /// identity-based one. The editor pages through entities; this page still
    /// renders by span, so the translation happens here rather than in either.
    private var selectedHighlightIdBinding: Binding<String?> {
        Binding(
            get: {
                guard let range = selectedHighlightRange else { return nil }
                return (matchingExegesisHighlight(for: range)
                        ?? overlappingExegesisHighlight(for: range))?.id
            },
            set: { id in
                selectedHighlightRange = id
                    .flatMap { wanted in exegesisHighlights.first { $0.id == wanted } }
                    .map { range(of: $0) }
            }
        )
    }

    /// Whether the selected highlight already carries a note — drives the
    /// "Edit note" vs "Add note" label.
    private var selectedHighlightHasNote: Bool {
        guard let range = selectedHighlightRange else { return false }
        return !noteMarkdown(for: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    /// Gives every highlight a draft and a rendered working copy BEFORE the
    /// note editor is presented, so its bindings are pure stored reads.
    private func seedNoteDrafts() {
        draftStore.seed(from: exegesisHighlights)
        for highlight in exegesisHighlights {
            draftStore.prepare(for: highlight) { MarkdownEditor.markdownToAttributed($0) }
        }
    }

    private func navigateToHighlight(_ range: NSRange) {
        NSLog("🟨 ExegesisSelectionTrace highlightNavigation selected range=\(debugRange(range))")
        scrollSelectedHighlightIntoView = true
        selectedHighlightRange = range
    }

    private func matchingExegesisHighlight(for range: NSRange) -> ContentHighlight? {
        exegesisHighlights.first { highlight in
            highlight.start == range.location && highlight.end == range.location + range.length
        }
    }

    /// An existing highlight whose span overlaps `range` (same overlap test the
    /// server enforces). Used to merge an overlapping note into the existing
    /// highlight instead of creating a new one — the server rejects overlapping
    /// creates, which otherwise fails the whole save ("Couldn't save changes").
    private func overlappingExegesisHighlight(for range: NSRange) -> ContentHighlight? {
        let start = range.location
        let end = range.location + range.length
        return exegesisHighlights.first { !(end <= $0.start || start >= $0.end) }
    }

    @MainActor
    private func loadExegesisHighlights() async {
        do {
            // The Action writes AppState; this view reads it (phase 4.9).
            try await actions.loadHighlights(activity.id)

            let live = exegesisHighlights
            draftStore.prune(keeping: live.map(\.id))
            draftStore.seed(from: live)
            NSLog("🟨 ExegesisSelectionTrace loaded exegesis highlights count=\(exegesisHighlights.count) activityId=\(activity.id)")
        } catch {
            // Background load on appear — console-only.
            AppState.shared.recordError(error, context: "EditExegesisActivityPage.loadExegesisHighlights")
        }
    }

    @MainActor
    private func commitNoteDraft(_ markdown: String, for highlight: ContentHighlight) {
        draftStore.setMarkdown(markdown, for: highlight)
        hasSaved = false
        Log.ui.debug("exegesis note draft staged, length \(markdown.count, privacy: .public)")
    }

    @MainActor
    private func savePendingNotes() async throws {
        guard lockedBlock?.id != nil else { return }

        // Every draft belongs to a highlight that exists, because drafts are
        // keyed by that highlight's id. The predecessor also had a CREATE branch
        // here, for drafts whose span matched no highlight — but that could only
        // happen when the span-derived lookup MISSED, which is the bug this
        // keying removes. Creating a highlight while saving a note was papering
        // over it, so the branch is gone (2026-08-04, phase 4.8b).
        for id in draftStore.dirtyIds {
            guard let highlight = exegesisHighlights.first(where: { $0.id == id }),
                  let markdown = draftStore[id]?.markdown else { continue }

            let saved = try await actions.updateHighlightNote(activity.id, highlight.id, markdown)
            upsertExegesisHighlight(saved)
            draftStore.markSaved(saved)
            Log.ui.debug("exegesis note saved, length \(saved.noteMarkdown.count, privacy: .public)")
        }
    }

    @MainActor
    private func upsertExegesisHighlight(_ highlight: ContentHighlight) {
        AppState.shared.contentHighlights.upsert(highlight)
    }

    private func selectPassageTapped() {
        presentBibleReaderOverlay()
    }

    private func presentBibleReaderOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let overlay = BibleReaderOverlayView(
            overlayManager: OverlayManager(),
            onDismiss: {},
            onPassageConfirmed: { book, chapter, verseStart, verseEnd, selectedText in
                let passageData = PassageData(
                    bookNumber: book.id,
                    bookName: book.name,
                    chapterStart: chapter,
                    chapterEnd: nil,
                    verseStart: verseStart,
                    verseEnd: verseEnd
                )

                // Capture current block styling before the passage change replaces the block
                let previousBlock = lockedBlock
                let savedImageUrl = previousBlock?.backgroundImageUrl
                let savedColor = previousBlock?.backgroundColor
                let savedOpacity = previousBlock?.backgroundOverlayOpacity
                let savedFontSize = previousBlock?.fontSize

                Task {
                    do {
                        let content = selectedText.isEmpty
                            ? nil
                            : BibleVerseContentNormalizer.normalizedMarkdown(from: selectedText)
                        try await actions.addSourceReference(activity.id, passageData, content)

                        // Re-apply styling to the new block (program-only —
                        // block styling isn't editable in the enrollment context)
                        if actions.supportsBlockStyling, let newBlockId = lockedBlock?.id {
                            let programActions = ProgramActions()
                            if savedImageUrl != nil || savedColor != nil || savedOpacity != nil {
                                try await programActions.setReadBlockBackground(
                                    activityId: activity.id,
                                    blockId: newBlockId,
                                    imageUrl: savedImageUrl,
                                    color: savedColor,
                                    overlayOpacity: savedOpacity
                                )
                            }
                            if let fs = savedFontSize {
                                try await programActions.setReadBlockFontSize(
                                    activityId: activity.id,
                                    blockId: newBlockId,
                                    fontSize: fs
                                )
                            }
                        }

                        await MainActor.run {
                            hasSaved = false
                        }
                    } catch {
                        await MainActor.run {
                            AppState.shared.recordError(
                                error,
                                context: "EditExegesisActivityPage.setExegesisPassage",
                                surface: true,
                                friendlyMessage: "Couldn't set the passage"
                            )
                        }
                    }
                }
            },
            usedPassages: []
        )

        overlay.frame = window.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        overlay.presentFromBottom()
    }

    // MARK: - Cancel & Revert

    private func cancelAndRevert() {
        guard !hasSaved else {
            onCancel()
            return
        }

        // Revert styling on the current block (may be new if passage changed)
        if let blockId = lockedBlock?.id {
            Task {
                if actions.supportsBlockStyling {
                    let programActions = ProgramActions()
                    do {
                        // Revert background styling
                        try await programActions.setReadBlockBackground(
                            activityId: activity.id,
                            blockId: blockId,
                            imageUrl: snapshotImageUrl,
                            color: snapshotColor,
                            overlayOpacity: snapshotOpacity,
                            clearImage: snapshotImageUrl == nil && lockedBlock?.backgroundImageUrl != nil,
                            clearColor: snapshotColor == nil && lockedBlock?.backgroundColor != nil,
                            clearOverlayOpacity: snapshotOpacity == nil && lockedBlock?.backgroundOverlayOpacity != nil
                        )
                        // Revert font size
                        try await programActions.setReadBlockFontSize(
                            activityId: activity.id,
                            blockId: blockId,
                            fontSize: snapshotFontSize
                        )
                    } catch {
                        await MainActor.run {
                            AppState.shared.recordError(
                                error,
                                context: "EditExegesisActivityPage.cancelAndRevert (styling)",
                                surface: true,
                                friendlyMessage: "Couldn't revert your changes"
                            )
                        }
                    }
                }

                // Revert title if it was saved during this session
                if activity.title != originalTitle {
                    do {
                        try await actions.updateTitle(activity.id, originalTitle)
                    } catch {
                        await MainActor.run {
                            AppState.shared.recordError(
                                error,
                                context: "EditExegesisActivityPage.cancelAndRevert (title)",
                                surface: true,
                                friendlyMessage: "Couldn't revert the title"
                            )
                        }
                    }
                }

                await MainActor.run { onCancel() }
            }
        } else {
            onCancel()
        }
    }

    // MARK: - Styled Selections

    private func applyStyle(
        _ style: ReadBlockSelectionStyle?,
        range: NSRange,
        blockId: String,
        activityId: String
    ) {
        guard let block = lockedBlock else {
            NSLog("🟨 ExegesisSelectionTrace applyStyle skipped missing lockedBlock activityId=\(activityId) blockId=\(blockId) range=\(debugRange(range))")
            return
        }
        let plainText = BibleVerseContentNormalizer.normalizedPlainText(from: block.content ?? "") as NSString
        NSLog("🟨 ExegesisSelectionTrace applyStyle begin activityId=\(activityId) blockId=\(blockId) style=\(style?.rawValue ?? "nil") range=\(debugRange(range)) snippet=\"\(debugSnippet(for: range, in: plainText))\" existingCount=\(block.selections?.count ?? 0)")
        let existing = block.selections ?? []
        let merged = mergeSelection(into: existing, range: range, style: style?.rawValue)
        NSLog("🟨 ExegesisSelectionTrace applyStyle merged activityId=\(activityId) blockId=\(blockId) previousCount=\(existing.count) mergedCount=\(merged.count)")

        // Optimistic local write so the preview re-renders immediately; the
        // provider routes it to the program store or the scheduled aggregate.
        actions.applyLocalSelections(activityId, blockId, merged)

        hasSaved = false
        NSLog("🟨 ExegesisSelectionTrace applyStyle hasSaved=false; starting API save")
        let existingHighlightForDelete = style == nil ? matchingExegesisHighlight(for: range) : nil

        Task {
            do {
                if style == .highlight {
                    guard let span = HighlightSpan(range) else { return }
                    let result = try await actions.createHighlight(activityId, blockId, span, "")
                    let created = result.highlight
                    await MainActor.run {
                        // `absorbedIds` comes from the SERVER (03 §2.2). The
                        // predecessor re-derived it locally with an overlap
                        // test — a second copy of the server's merge rule, which
                        // 03 §5 forbids consumers from keeping ("consumers never
                        // merge locally"). The Action has already applied both
                        // the removal and the upsert to AppState.

                        // A merge DESTROYS entities and creates a new one, so
                        // any state keyed by the absorbed highlights is orphaned
                        // — which is monday#12708759849 sub-issue A. This is the
                        // only place the client learns a merge happened, so it
                        // is the only place succession is handled, and it is one
                        // call (highlighting phase 4.8b; the phase-1 stop-gap
                        // that re-keyed three dictionaries by hand is gone).
                        draftStore.applyMerge(created: created, absorbedIds: result.absorbedIds)
                    }
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API createHighlight success activityId=\(activityId) blockId=\(blockId) highlightId=\(created.id) range={\(created.start)-\(created.end)}")
                } else if style == nil, let existingHighlight = existingHighlightForDelete {
                    try await actions.deleteHighlight(activityId, existingHighlight.id)
                    await MainActor.run {
                        _ = AppState.shared.contentHighlights.remove(existingHighlight.id)
                    }
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API deleteHighlight success activityId=\(activityId) blockId=\(blockId) highlightId=\(existingHighlight.id)")
                } else {
                    try await actions.updateSelections(activityId, blockId, merged)
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API save selections success activityId=\(activityId) blockId=\(blockId) mergedCount=\(merged.count)")
                }
            } catch {
                await MainActor.run {
                    AppState.shared.recordError(
                        error,
                        context: "EditExegesisActivityPage.applyStyle",
                        surface: true,
                        friendlyMessage: "Couldn't save the highlight",
                        retry: { applyStyle(style, range: range, blockId: blockId, activityId: activityId) }
                    )
                }
            }
        }
    }

    private func debugRange(_ range: NSRange) -> String {
        "{loc:\(range.location), len:\(range.length), end:\(range.location == NSNotFound ? NSNotFound : range.location + range.length)}"
    }

    private func debugSnippet(for range: NSRange, in text: NSString) -> String {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length > 0,
              range.location + range.length <= text.length else { return "" }
        let raw = text.substring(with: range)
        let singleLine = raw
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        if singleLine.count <= 120 { return singleLine }
        return String(singleLine.prefix(120)) + "…"
    }

    private func mergeSelection(
        into existing: [ReadBlockSelection],
        range: NSRange,
        style: String?
    ) -> [ReadBlockSelection] {
        let start = range.location
        let end = range.location + range.length
        let overlaps: (ReadBlockSelection) -> Bool = { selection in
            selection.start < end && selection.end > start
        }

        let overlapping = existing.filter { overlaps($0) }
        NSLog("🟨 ExegesisSelectionTrace mergeSelection start=\(start) end=\(end) style=\(style ?? "nil") existing=\(existing.count) overlapping=\(overlapping.map { "{\($0.start)-\($0.end):\($0.style)}" }.joined(separator: ","))")
        let kept = existing.filter { !overlaps($0) }
        guard let style else {
            NSLog("🟨 ExegesisSelectionTrace mergeSelection removeStyle kept=\(kept.count)")
            return kept
        }
        // Same-style overlaps merge into one union span (matching the server,
        // which absorbs overlapping highlights on create); other styles are
        // still replaced by the new selection.
        let sameStyle = overlapping.filter { $0.style == style }
        let unionStart = min(start, sameStyle.map(\.start).min() ?? start)
        let unionEnd = max(end, sameStyle.map(\.end).max() ?? end)
        let result = kept + [ReadBlockSelection(start: unionStart, end: unionEnd, style: style)]
        Log.ui.info("🟨 ExegesisSelectionTrace mergeSelection resultCount=\(result.count, privacy: .public) union={\(unionStart, privacy: .public)-\(unionEnd, privacy: .public)}")
        return result
    }

    // MARK: - Save

    private func saveTitle() {
        guard canEdit else { return }
        let titleChanged = title != originalTitle
        guard !titleChanged || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSavingTitle = true
        Task {
            do {
                if titleChanged {
                    try await actions.updateTitle(activity.id, title)
                }
                try await savePendingNotes()
                await MainActor.run {
                    if titleChanged {
                        originalTitle = title
                    }
                    savedStyleFingerprint = blockStyleFingerprint
                    hasSaved = true
                    isSavingTitle = false
                }
            } catch {
                await MainActor.run {
                    isSavingTitle = false
                    AppState.shared.recordError(
                        error,
                        context: "EditExegesisActivityPage.saveTitle",
                        surface: true,
                        friendlyMessage: "Couldn't save changes"
                    )
                }
            }
        }
    }

}

// MARK: - Highlight Action Menu

private struct HighlightActionMenuContent: View {
    @Environment(\.dismissOverlay) private var dismissOverlay

    @Binding var selectedRange: NSRange?
    let highlightRanges: [NSRange]
    let highlightText: String
    let onNavigate: (NSRange) -> Void
    let onDelete: () -> Void
    /// Asks the page to swap this sheet for the full-screen note editor.
    let onEditNote: () -> Void
    /// Resolved by the page against the authoritative server highlights — the
    /// sheet must NOT re-derive this from the span-keyed dictionary, which is
    /// what mislabelled noted highlights as "Add note" (monday#12668543338).
    let hasNote: Bool
    let onDismiss: () -> Void
    init(
        selectedRange: Binding<NSRange?>,
        highlightRanges: [NSRange],
        highlightText: String,
        onNavigate: @escaping (NSRange) -> Void,
        onDelete: @escaping () -> Void,
        onEditNote: @escaping () -> Void,
        hasNote: Bool,
        onDismiss: @escaping () -> Void
    ) {
        self._selectedRange = selectedRange
        self.highlightRanges = highlightRanges
        self.highlightText = highlightText
        self.onNavigate = onNavigate
        self.onDelete = onDelete
        self.onEditNote = onEditNote
        self.hasNote = hasNote
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 16) {
            navigationRow

            actionButtonGroup
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16 + bottomSafeAreaInset)
        .frame(height: sheetContentHeight, alignment: .top)
        .onDisappear(perform: onDismiss)
    }

    private var navigationRow: some View {
        HStack {
            // PREV button
            Button {
                if let previousRange {
                    onNavigate(previousRange)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                        .font(Typography.s9Bold)
                    Text("PREV")
                        .font(Typography.s10Bold)
                        .tracking(1)
                }
                .foregroundColor(Color.brandPrimary.opacity(previousRange == nil ? 0.35 : 1.0))
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
                .background(Color.brandPrimary.opacity(previousRange == nil ? 0.1 : 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(previousRange == nil)

            Spacer()

            // Count: current / total
            if let index = currentIndex {
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(Typography.s10Bold)
                        .tracking(1)
                        .foregroundColor(.white)
                    Text("/")
                        .font(Typography.s10)
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(highlightRanges.count)")
                        .font(Typography.s10Bold)
                        .tracking(1)
                        .foregroundColor(Color.brandPrimary)
                }
            }

            Spacer()

            // NEXT button
            Button {
                if let nextRange {
                    onNavigate(nextRange)
                }
            } label: {
                HStack(spacing: 10) {
                    Text("NEXT")
                        .font(Typography.s10Bold)
                        .tracking(1)
                    Image(systemName: "chevron.right")
                        .font(Typography.s9Bold)
                }
                .foregroundColor(Color.brandPrimary.opacity(nextRange == nil ? 0.35 : 1.0))
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(Color.brandPrimary.opacity(nextRange == nil ? 0.1 : 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(nextRange == nil)
        }
        .padding(.horizontal, 4)
    }

    private var actionButtonGroup: some View {
        VStack(spacing: 8) {
            BoxButton(
                action: {
                    // Hands off to the full-screen editor instead of morphing
                    // this sheet into one. Sequenced dismiss-then-present, never
                    // asyncAfter (MODAL_GUIDE D3/E1).
                    onEditNote()
                },
                label: noteButtonLabel,
                icon: noteButtonIcon,
                iconPosition: .left,
                variant: .secondary,
                style: .solid,
                size: .lg,
                fullWidth: true,
                iconOpacity: 0.75
            )

            BoxButton(
                action: {
                    onDelete()
                    dismissOverlay?()
                },
                label: "Delete",
                icon: "trash",
                iconPosition: .left,
                variant: .destructive,
                style: .solid,
                size: .lg,
                fullWidth: true,
                iconOpacity: 0.8
            )
        }
    }

    private var selectedHighlightExcerpt: String {
        guard let selectedRange else { return "" }
        let text = highlightText as NSString
        guard selectedRange.location != NSNotFound,
              selectedRange.location >= 0,
              selectedRange.length > 0,
              selectedRange.location + selectedRange.length <= text.length else { return "" }
        return text.substring(with: selectedRange)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    private var selectedRangeKey: String {
        guard let selectedRange else { return "none" }
        return rangeKey(for: selectedRange)
    }

    private func rangeKey(for range: NSRange) -> String {
        "\(range.location):\(range.length)"
    }

    private var noteButtonLabel: String {
        hasNote ? "Edit note" : "Add note"
    }

    private var noteButtonIcon: String {
        hasNote ? "square.and.pencil" : "plus"
    }

    private var previousRange: NSRange? {
        guard let currentIndex, currentIndex > 0 else { return nil }
        return highlightRanges[currentIndex - 1]
    }

    private var nextRange: NSRange? {
        guard let currentIndex, currentIndex < highlightRanges.count - 1 else { return nil }
        return highlightRanges[currentIndex + 1]
    }

    private var currentIndex: Int? {
        guard let selectedRange else { return nil }
        return highlightRanges.firstIndex { range in
            range.location == selectedRange.location && range.length == selectedRange.length
        }
    }

    private var sheetContentHeight: CGFloat {
        196 + bottomSafeAreaInset
    }

    private var actionContentHeight: CGFloat { 120 }


    private var topSafeAreaInset: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return 0 }
        return (scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first)?.safeAreaInsets.top ?? 0
    }

    private var bottomSafeAreaInset: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return 0 }
        return (scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first)?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Preview

#Preview("No Data") {
    ExegesisPreviewWrapper(variant: .empty)
}

#Preview("Verse") {
    ExegesisPreviewWrapper(variant: .verse)
}

#Preview("Image + Color") {
    ExegesisPreviewWrapper(variant: .imageAndColor)
}

#Preview("Highlights") {
    ExegesisPreviewWrapper(variant: .highlights)
}

private enum ExegesisPreviewVariant {
    case empty, verse, imageAndColor, highlights
}

private struct ExegesisPreviewWrapper: View {
    let variant: ExegesisPreviewVariant

    private let verseContent = """
    1. In the beginning God created the heaven and the earth.
    2. And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters.
    3. And God said, Let there be light: and there was light.
    4. And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day.
    5. And God said, Let there be a firmament in the midst of the waters, and let it divide the waters from the waters.
    6. And God made the firmament, and divided the waters which were under the firmament from the waters which were above the firmament: and it was so.
    7. And God called the firmament Heaven. And the evening and the morning were the second day.
    8. And God said, Let the waters under the heaven be gathered together unto one place, and let the dry land appear: and it was so.
    9. And God called the dry land Earth; and the gathering together of the waters called he Seas: and God saw that it was good.
    10. And God said, Let the earth bring forth grass, the herb yielding seed, and the fruit tree yielding fruit after his kind, whose seed is in itself, upon the earth: and it was so.
    """

    var body: some View {
        let activity: StudyActivity = {
            switch variant {
            case .empty:
                return StudyActivity(
                    id: "preview-empty",
                    type: .exegesis,
                    orderNumber: 1,
                    title: "Exegesis"
                )
            case .verse:
                return StudyActivity(
                    id: "preview-verse",
                    type: .exegesis,
                    orderNumber: 1,
                    title: "Genesis 1:1",
                    readBlocks: [
                        ActivityReadBlock(
                            id: "block-1",
                            title: "Genesis 1:1-10",
                            content: verseContent,
                            isLocked: true
                        )
                    ]
                )
            case .imageAndColor:
                return StudyActivity(
                    id: "preview-styled",
                    type: .exegesis,
                    orderNumber: 1,
                    title: "Genesis 1:1",
                    readBlocks: [
                        ActivityReadBlock(
                            id: "block-2",
                            title: "Genesis 1:1-10",
                            content: verseContent,
                            isLocked: true,
                            backgroundImageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=800",
                            backgroundColor: "#1f0098",
                            backgroundOverlayOpacity: 0.6,
                            fontSize: "lg"
                        )
                    ]
                )
            case .highlights:
                return StudyActivity(
                    id: "preview-highlights",
                    type: .exegesis,
                    orderNumber: 1,
                    title: "Genesis 1:1",
                    readBlocks: [
                        ActivityReadBlock(
                            id: "block-3",
                            title: "Genesis 1:1-10",
                            content: verseContent,
                            isLocked: true,
                            selections: [
                                ReadBlockSelection(start: 3, end: 58, style: "highlight"),
                                ReadBlockSelection(start: 175, end: 230, style: "highlight")
                            ]
                        )
                    ]
                )
            }
        }()

        EditExegesisActivityPage(
            activity: activity,
            programId: nil,
            onCancel: {},
            onSave: {}
        )
        .environment(AuthManager())
        .environment(OverlayManager())
    }
}
