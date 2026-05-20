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
//   - One or more highlights (ExegesisHighlight rows) attached to that block
//   - Verse text is never edited — only selected/highlighted
//

import SwiftUI

struct EditExegesisActivityPage: View {
    let activity: StudyActivity
    let programId: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    @EnvironmentObject var authManager: AuthManager
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
    @State private var noteDrafts: [String: String] = [:]
    @State private var attributedNoteDrafts: [String: AttributedString] = [:]
    @State private var savedNoteMarkdownByHighlight: [String: String] = [:]
    @State private var exegesisHighlights: [ExegesisHighlight] = []

    // MARK: - Derived

    private var lockedBlock: ActivityReadBlock? {
        AppState.shared.activities[activity.id]?.readBlocks?.first(where: { $0.isLocked })
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
            ReadActivityPreviewModal(
                activityId: activity.id,
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
                                        text: $title
                                    )
                                }
                                .padding(.horizontal, 16)
                                .disabled(!canEdit)

                                // Passage chip
                                passageRow
                                    .padding(.horizontal, 16)

                                // Image, color, and font size controls
                                if hasPassage, let blockId = lockedBlock?.id {
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                guard canEdit else { return }
                selectPassageTapped()
            } label: {
                Text(lockedBlock?.title ?? "select passage")
                    .font(.system(size: 14, weight: .semibold))
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
                                    .stroke(Color(hex: "#6c47ff"), lineWidth: 1.5)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)
        }
        .padding(16)
        .background(Color(hex: "#252936"))
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
                        overlayManager.dismiss(id: OverlayID.exegesisHighlightActionMenu)
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
            overlayManager.dismiss(id: OverlayID.exegesisHighlightActionMenu)
            return
        }

        overlayManager.presentMenu(id: OverlayID.exegesisHighlightActionMenu, priority: .menu) {
            HighlightActionMenuContent(
                selectedRange: $selectedHighlightRange,
                highlightRanges: sortedHighlightRanges,
                highlightText: BibleVerseContentNormalizer.normalizedPlainText(from: lockedBlock?.content ?? ""),
                noteDrafts: $noteDrafts,
                attributedNoteDrafts: $attributedNoteDrafts,
                savedNoteMarkdownByHighlight: savedNoteMarkdownByHighlight,
                onNavigate: { range in
                    navigateToHighlight(range)
                },
                onDelete: {
                    guard let range = selectedHighlightRange,
                          let blockId = lockedBlock?.id else { return }
                    let key = highlightNoteKey(for: range)
                    noteDrafts.removeValue(forKey: key)
                    attributedNoteDrafts.removeValue(forKey: key)
                    savedNoteMarkdownByHighlight.removeValue(forKey: key)
                    applyStyle(nil, range: range, blockId: blockId, activityId: activity.id)
                },
                onCommitNote: { range, markdown in
                    commitNoteDraft(markdown, for: range)
                },
                onDismiss: {
                    selectedHighlightRange = nil
                    scrollSelectedHighlightIntoView = false
                }
            )
        }
    }

    private func navigateToHighlight(_ range: NSRange) {
        NSLog("🟨 ExegesisSelectionTrace highlightNavigation selected range=\(debugRange(range))")
        scrollSelectedHighlightIntoView = true
        selectedHighlightRange = range
    }

    private func highlightNoteKey(for range: NSRange) -> String {
        "\(range.location):\(range.length)"
    }

    private func rangeFromHighlightNoteKey(_ key: String) -> NSRange? {
        let parts = key.split(separator: ":")
        guard parts.count == 2,
              let location = Int(parts[0]),
              let length = Int(parts[1]) else { return nil }
        return NSRange(location: location, length: length)
    }

    private func matchingExegesisHighlight(for range: NSRange) -> ExegesisHighlight? {
        exegesisHighlights.first { highlight in
            highlight.start == range.location && highlight.end == range.location + range.length
        }
    }

    @MainActor
    private func loadExegesisHighlights() async {
        do {
            let result = try await ProgramActions().fetchExegesisHighlights(activityId: activity.id)
            exegesisHighlights = result.highlights.sorted { lhs, rhs in
                if lhs.start == rhs.start { return lhs.end < rhs.end }
                return lhs.start < rhs.start
            }

            var savedNotes: [String: String] = [:]
            for highlight in exegesisHighlights {
                let range = NSRange(location: highlight.start, length: highlight.end - highlight.start)
                let key = highlightNoteKey(for: range)
                savedNotes[key] = highlight.noteMarkdown
                if noteDrafts[key] == nil {
                    noteDrafts[key] = highlight.noteMarkdown
                }
            }
            savedNoteMarkdownByHighlight = savedNotes
            NSLog("🟨 ExegesisSelectionTrace loaded exegesis highlights count=\(exegesisHighlights.count) activityId=\(activity.id)")
        } catch {
            NSLog("❌ ExegesisSelectionTrace failed to load exegesis highlights activityId=\(activity.id) error=\(error.localizedDescription)")
        }
    }

    @MainActor
    private func commitNoteDraft(_ markdown: String, for range: NSRange) {
        let key = highlightNoteKey(for: range)
        noteDrafts[key] = markdown
        hasSaved = false
        NSLog("🟨 ExegesisSelectionTrace commitNoteDraft activityId=\(activity.id) range=\(debugRange(range)) noteLength=\(markdown.count)")
    }

    @MainActor
    private func savePendingNotes() async throws {
        guard lockedBlock?.id != nil else { return }

        let pendingDrafts = noteDrafts
        for (key, markdown) in pendingDrafts {
            guard savedNoteMarkdownByHighlight[key] != markdown,
                  let range = rangeFromHighlightNoteKey(key) else { continue }

            let saved: ExegesisHighlight
            if let existing = matchingExegesisHighlight(for: range) {
                saved = try await ProgramActions().updateExegesisHighlight(
                    activityId: activity.id,
                    highlightId: existing.id,
                    noteMarkdown: markdown
                )
            } else if let blockId = lockedBlock?.id {
                saved = try await ProgramActions().createExegesisHighlight(
                    activityId: activity.id,
                    readBlockId: blockId,
                    start: range.location,
                    end: range.location + range.length,
                    noteMarkdown: markdown
                )
            } else {
                continue
            }

            upsertExegesisHighlight(saved)
            let savedKey = highlightNoteKey(for: NSRange(location: saved.start, length: saved.end - saved.start))
            savedNoteMarkdownByHighlight[savedKey] = saved.noteMarkdown
            noteDrafts[savedKey] = saved.noteMarkdown
            NSLog("🟨 ExegesisSelectionTrace savePendingNotes success activityId=\(activity.id) highlightId=\(saved.id) range={\(saved.start)-\(saved.end)} noteLength=\(saved.noteMarkdown.count)")
        }
    }

    @MainActor
    private func upsertExegesisHighlight(_ highlight: ExegesisHighlight) {
        if let index = exegesisHighlights.firstIndex(where: { $0.id == highlight.id }) {
            exegesisHighlights[index] = highlight
        } else {
            exegesisHighlights.append(highlight)
        }
        exegesisHighlights.sort { lhs, rhs in
            if lhs.start == rhs.start { return lhs.end < rhs.end }
            return lhs.start < rhs.start
        }
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
                        _ = try await ProgramActions().addSourceReference(activityId: activity.id, passageData: passageData, content: content)

                        // Re-apply styling to the new block
                        if let newBlockId = lockedBlock?.id {
                            let actions = ProgramActions()
                            if savedImageUrl != nil || savedColor != nil || savedOpacity != nil {
                                try await actions.setReadBlockBackground(
                                    activityId: activity.id,
                                    blockId: newBlockId,
                                    imageUrl: savedImageUrl,
                                    color: savedColor,
                                    overlayOpacity: savedOpacity
                                )
                            }
                            if let fs = savedFontSize {
                                try await actions.setReadBlockFontSize(
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
                        NSLog("❌ Failed to set exegesis passage: \(error)")
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
                let actions = ProgramActions()
                do {
                    // Revert background styling
                    try await actions.setReadBlockBackground(
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
                    try await actions.setReadBlockFontSize(
                        activityId: activity.id,
                        blockId: blockId,
                        fontSize: snapshotFontSize
                    )
                } catch {
                    NSLog("❌ Failed to revert styling: \(error)")
                }

                // Revert title if it was saved during this session
                if activity.title != originalTitle {
                    do {
                        _ = try await actions.updateActivityContent(activityId: activity.id, title: originalTitle)
                    } catch {
                        NSLog("❌ Failed to revert title: \(error)")
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

        if var activity = AppState.shared.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            NSLog("🟨 ExegesisSelectionTrace applyStyle appState update begin blockIndex=\(index)")
            blocks[index].selections = merged
            activity.readBlocks = blocks
            AppState.shared.activities.upsert(activity)
            AppState.shared.persist()
            NSLog("🟨 ExegesisSelectionTrace applyStyle appState update end")
        } else {
            NSLog("🟨 ExegesisSelectionTrace applyStyle appState update skipped activityFound=\(AppState.shared.activities[activityId] != nil)")
        }

        hasSaved = false
        NSLog("🟨 ExegesisSelectionTrace applyStyle hasSaved=false; starting API save")
        let existingHighlightForDelete = style == nil ? matchingExegesisHighlight(for: range) : nil

        Task {
            do {
                if style == .highlight {
                    let created = try await ProgramActions().createExegesisHighlight(
                        activityId: activityId,
                        readBlockId: blockId,
                        start: range.location,
                        end: range.location + range.length,
                        noteMarkdown: ""
                    )
                    await MainActor.run {
                        upsertExegesisHighlight(created)
                        let key = highlightNoteKey(for: NSRange(location: created.start, length: created.end - created.start))
                        savedNoteMarkdownByHighlight[key] = created.noteMarkdown
                    }
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API createHighlight success activityId=\(activityId) blockId=\(blockId) highlightId=\(created.id) range={\(created.start)-\(created.end)}")
                } else if style == nil, let existingHighlight = existingHighlightForDelete {
                    try await ProgramActions().deleteExegesisHighlight(activityId: activityId, highlightId: existingHighlight.id)
                    await MainActor.run {
                        exegesisHighlights.removeAll { $0.id == existingHighlight.id }
                    }
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API deleteHighlight success activityId=\(activityId) blockId=\(blockId) highlightId=\(existingHighlight.id)")
                } else {
                    try await ProgramActions().updateReadBlockSelections(activityId: activityId, blockId: blockId, selections: merged)
                    NSLog("🟨 ExegesisSelectionTrace applyStyle API save selections success activityId=\(activityId) blockId=\(blockId) mergedCount=\(merged.count)")
                }
            } catch {
                NSLog("❌ ExegesisSelectionTrace applyStyle API save failed activityId=\(activityId) blockId=\(blockId) error=\(error.localizedDescription)")
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
        let result = kept + [ReadBlockSelection(start: start, end: end, style: style)]
        NSLog("🟨 ExegesisSelectionTrace mergeSelection resultCount=\(result.count)")
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
                    _ = try await ProgramActions().updateActivityContent(activityId: activity.id, title: title)
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
                NSLog("❌ Failed to save exegesis activity changes: \(error)")
                await MainActor.run { isSavingTitle = false }
            }
        }
    }

}

// MARK: - Highlight Action Menu

private struct HighlightActionMenuContent: View {
    @Environment(\.dismissOverlay) private var dismissOverlay

    private enum Mode {
        case actions
        case noteEditor
    }

    private enum SaveState {
        case idle
        case saving
        case saved
    }

    @Binding var selectedRange: NSRange?
    let highlightRanges: [NSRange]
    let highlightText: String
    @Binding var noteDrafts: [String: String]
    @Binding var attributedNoteDrafts: [String: AttributedString]
    let onNavigate: (NSRange) -> Void
    let onDelete: () -> Void
    let onCommitNote: (NSRange, String) -> Void
    let onDismiss: () -> Void

    @State private var mode: Mode = .actions
    @State private var saveState: SaveState = .idle
    @State private var savedNoteMarkdownByHighlight: [String: String]
    @State private var noteEditorOriginalDrafts: [String: String] = [:]
    @State private var noteEditorOriginallyMissingDrafts: Set<String> = []

    init(
        selectedRange: Binding<NSRange?>,
        highlightRanges: [NSRange],
        highlightText: String,
        noteDrafts: Binding<[String: String]>,
        attributedNoteDrafts: Binding<[String: AttributedString]>,
        savedNoteMarkdownByHighlight: [String: String],
        onNavigate: @escaping (NSRange) -> Void,
        onDelete: @escaping () -> Void,
        onCommitNote: @escaping (NSRange, String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._selectedRange = selectedRange
        self.highlightRanges = highlightRanges
        self.highlightText = highlightText
        self._noteDrafts = noteDrafts
        self._attributedNoteDrafts = attributedNoteDrafts
        self._savedNoteMarkdownByHighlight = State(initialValue: savedNoteMarkdownByHighlight)
        self.onNavigate = onNavigate
        self.onDelete = onDelete
        self.onCommitNote = onCommitNote
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 16) {
            navigationRow

            ZStack(alignment: .top) {
                if mode == .actions {
                    actionButtonGroup
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                }

                if mode == .noteEditor {
                    noteEditorContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: mode == .noteEditor ? editorContentHeight : actionContentHeight, alignment: .top)
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16 + bottomSafeAreaInset)
        .frame(height: sheetContentHeight, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: mode)
        .animation(.easeInOut(duration: 0.18), value: saveState)
        .onChange(of: selectedRange?.location ?? NSNotFound) { _, _ in
            saveState = .idle
        }
        .onChange(of: selectedRange?.length ?? 0) { _, _ in
            saveState = .idle
        }
        .onDisappear(perform: onDismiss)
    }

    private var navigationRow: some View {
        HStack {
            // PREV button
            Button {
                if let previousRange {
                    prepareDraftForEditorNavigation(to: previousRange)
                    onNavigate(previousRange)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("PREV")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(Color(hex: "#6c47ff").opacity(previousRange == nil ? 0.35 : 1.0))
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "#6c47ff").opacity(previousRange == nil ? 0.1 : 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(previousRange == nil)

            Spacer()

            // Count: current / total
            if let index = currentIndex {
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                    Text("/")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(highlightRanges.count)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color(hex: "#6c47ff"))
                }
            }

            Spacer()

            // NEXT button
            Button {
                if let nextRange {
                    prepareDraftForEditorNavigation(to: nextRange)
                    onNavigate(nextRange)
                }
            } label: {
                HStack(spacing: 10) {
                    Text("NEXT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Color(hex: "#6c47ff").opacity(nextRange == nil ? 0.35 : 1.0))
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(Color(hex: "#6c47ff").opacity(nextRange == nil ? 0.1 : 0.2))
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
                    if let selectedRange {
                        beginNoteEditorSession(for: selectedRange)
                    }
                    saveState = .idle
                    mode = .noteEditor
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

    private var noteEditorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedHighlightExcerpt)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 64, alignment: .topLeading)

            MarkdownEditor(
                placeholder: "Add a note...",
                attributedText: currentAttributedDraftBinding,
                minHeight: max(120, noteEditorHeight - 45),
                autoGrow: false
            )
            .frame(maxWidth: .infinity)
            .frame(height: noteEditorHeight)

            HStack(spacing: 12) {
                Button {
                    dismissOverlay?()
                    DispatchQueue.main.async {
                        cancelNoteEditorSession()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(saveState == .saving)

                Button {
                    saveTapped()
                } label: {
                    ZStack {
                        if saveState == .saving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "#6c47ff"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(saveState == .saving)
            }
            .opacity(mode == .noteEditor ? 1 : 0)
        }
    }

    private var currentAttributedDraftBinding: Binding<AttributedString> {
        Binding(
            get: {
                attributedNoteDrafts[selectedRangeKey] ?? AttributedString()
            },
            set: { newValue in
                attributedNoteDrafts[selectedRangeKey] = newValue
                noteDrafts[selectedRangeKey] = MarkdownEditor.attributedToMarkdown(newValue)
                if saveState == .saved { saveState = .idle }
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

    private func snapshotDraftIfNeeded(for range: NSRange) {
        let key = rangeKey(for: range)
        guard noteEditorOriginalDrafts[key] == nil,
              !noteEditorOriginallyMissingDrafts.contains(key) else { return }

        if let currentDraft = noteDrafts[key] {
            noteEditorOriginalDrafts[key] = currentDraft
        } else {
            noteEditorOriginallyMissingDrafts.insert(key)
        }
    }

    private func beginNoteEditorSession(for range: NSRange) {
        noteEditorOriginalDrafts.removeAll()
        noteEditorOriginallyMissingDrafts.removeAll()
        snapshotDraftIfNeeded(for: range)
        prepareDraft(for: range)
    }

    private func prepareDraftForEditorNavigation(to range: NSRange) {
        if mode == .noteEditor {
            snapshotDraftIfNeeded(for: range)
        }
        prepareDraft(for: range)
        saveState = .idle
    }

    private func cancelNoteEditorSession() {
        for (key, markdown) in noteEditorOriginalDrafts {
            noteDrafts[key] = markdown
            attributedNoteDrafts.removeValue(forKey: key)
        }
        for key in noteEditorOriginallyMissingDrafts {
            noteDrafts.removeValue(forKey: key)
            attributedNoteDrafts.removeValue(forKey: key)
        }
        noteEditorOriginalDrafts.removeAll()
        noteEditorOriginallyMissingDrafts.removeAll()
        saveState = .idle
    }

    private func saveTapped() {
        switch saveState {
        case .idle, .saved:
            guard let selectedRange else { return }
            let key = selectedRangeKey
            let markdown = noteDrafts[key] ?? savedNoteMarkdownByHighlight[key] ?? ""
            onCommitNote(selectedRange, markdown)
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                savedNoteMarkdownByHighlight.removeValue(forKey: key)
            } else {
                savedNoteMarkdownByHighlight[key] = markdown
            }
            noteEditorOriginalDrafts.removeAll()
            noteEditorOriginallyMissingDrafts.removeAll()
            saveState = .idle
            dismissOverlay?()
        case .saving:
            break
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

    private var currentNoteHasContent: Bool {
        !(savedNoteMarkdownByHighlight[selectedRangeKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var noteButtonLabel: String {
        currentNoteHasContent ? "Edit note" : "Add note"
    }

    private var noteButtonIcon: String {
        currentNoteHasContent ? "square.and.pencil" : "plus"
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
        switch mode {
        case .actions:
            return 196 + bottomSafeAreaInset
        case .noteEditor:
            return expandedSheetHeight
        }
    }

    private var actionContentHeight: CGFloat { 120 }

    private var editorContentHeight: CGFloat {
        expandedSheetHeight - bottomSafeAreaInset - 76
    }

    private var noteEditorHeight: CGFloat {
        max(220, editorContentHeight - 152)
    }

    private var expandedSheetHeight: CGFloat {
        max(560, Screen.bounds.height - topSafeAreaInset - 40)
    }

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
        .environmentObject(AuthManager())
        .environment(OverlayManager())
    }
}
