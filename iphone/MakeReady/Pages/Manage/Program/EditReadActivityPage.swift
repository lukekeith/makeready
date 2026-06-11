//
//  EditReadActivityPage.swift
//  MakeReady
//
//  Multi-block editor for READ activity content.
//  Supports locked verse blocks (from Bible selection) and editable content blocks.
//  Uses RichTextInput for editable blocks and stripped HTML for locked blocks.
//

import SwiftUI

/// Action closures for read activity operations, allowing reuse across program and enrollment contexts.
/// All mutations route through Actions, which write to AppState; views observe via @Observable.
struct ReadActivityActionProvider {
    let context: LessonContext
    let addSourceReference: (String, PassageData, String?) async throws -> [ActivityReadBlock]?
    let createCustomBlock: (String) async throws -> [ActivityReadBlock]?
    let deleteReadBlock: (String, String) async throws -> [ActivityReadBlock]?
    let updateReadBlock: (String, String, String?) async throws -> Void
    let updateReadBlockSelections: (String, String, [ReadBlockSelection]) async throws -> Void
    let reorderReadBlocks: (String, [String]) async throws -> Void
    let updateTitle: (String, String?) async throws -> Void

    /// Default: uses ProgramActions and AppState
    static var program: ReadActivityActionProvider {
        ReadActivityActionProvider(
            context: .program,
            addSourceReference: { activityId, passageData, content in
                let updated = try await ProgramActions().addSourceReference(activityId: activityId, passageData: passageData, content: content)
                return updated?.readBlocks
            },
            createCustomBlock: { activityId in
                let updated = try await ProgramActions().createReadBlock(activityId: activityId, content: "", isLocked: false)
                return updated?.readBlocks
            },
            deleteReadBlock: { activityId, blockId in
                let updated = try await ProgramActions().deleteReadBlock(activityId: activityId, blockId: blockId)
                return updated?.readBlocks
            },
            updateReadBlock: { activityId, blockId, content in
                try await ProgramActions().updateReadBlock(activityId: activityId, blockId: blockId, content: content)
            },
            updateReadBlockSelections: { activityId, blockId, selections in
                try await ProgramActions().updateReadBlockSelections(activityId: activityId, blockId: blockId, selections: selections)
            },
            reorderReadBlocks: { activityId, blockIds in
                _ = try await ProgramActions().reorderReadBlocks(activityId: activityId, blockIds: blockIds)
            },
            updateTitle: { activityId, title in
                _ = try await ProgramActions().updateActivityContent(activityId: activityId, title: title)
            }
        )
    }

    /// Enrollment: uses EnrollmentActions
    static var enrollment: ReadActivityActionProvider {
        ReadActivityActionProvider(
            context: .enrollment,
            addSourceReference: { activityId, passageData, content in
                let updated = try await EnrollmentActions().addSourceReference(activityId: activityId, passageData: passageData, content: content)
                return updated?.readBlocks
            },
            createCustomBlock: { activityId in
                let updated = try await EnrollmentActions().createReadBlock(activityId: activityId, content: "", isLocked: false)
                return updated?.readBlocks
            },
            deleteReadBlock: { activityId, blockId in
                let updated = try await EnrollmentActions().deleteReadBlock(activityId: activityId, blockId: blockId)
                return updated?.readBlocks
            },
            updateReadBlock: { activityId, blockId, content in
                try await EnrollmentActions().updateReadBlock(activityId: activityId, blockId: blockId, content: content)
            },
            updateReadBlockSelections: { activityId, blockId, selections in
                try await EnrollmentActions().updateReadBlockSelections(activityId: activityId, blockId: blockId, selections: selections)
            },
            reorderReadBlocks: { activityId, blockIds in
                _ = try await EnrollmentActions().reorderReadBlocks(activityId: activityId, blockIds: blockIds)
            },
            updateTitle: { activityId, title in
                _ = try await EnrollmentActions().updateScheduledActivity(activityId: activityId, title: title, helpTitle: nil, helpDescription: nil)
            }
        )
    }
}

struct EditReadActivityPage: View {
    let activity: StudyActivity
    /// Lesson id this activity belongs to. Required so the page can read live
    /// from the lesson aggregate in AppState (used-passage highlights, blocks).
    let lessonId: String
    let programId: String?
    let passageCount: Int
    let passageCountsByBook: [String: Int]
    let currentLessonTitle: String?
    let lessonActivityCount: Int
    let onCancel: () -> Void
    let onSave: (String?) -> Void
    var onLessonTitleUpdate: ((String) -> Void)? = nil
    var onBlocksChanged: (([ActivityReadBlock]) -> Void)? = nil
    var actions: ReadActivityActionProvider = .program

    @Environment(OverlayManager.self) private var overlayManager
    @Environment(AuthManager.self) var authManager

    /// True when the signed-in user is the creator of the program containing
    /// this activity. Drives gating: hides save/done/plus, disables swipe,
    /// drag, and inputs. Defaults to false in the enrollment context (the
    /// passed-in actions handle their own auth) and when programId is nil.
    private var canEdit: Bool {
        guard let programId else { return false }
        return AppState.shared.programs[programId]?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    @State private var title: String = ""
    @State private var isSaving = false
    /// True when the on-screen form matches what's been saved. Opens as
    /// `true` so the right-link shows "Done" on first appear — flips to
    /// `false` on any edit, flips back on successful `save()`.
    @State private var hasSaved = true
    /// Guards `.onChange` handlers so the initial seeding in onAppear
    /// doesn't flip `hasSaved` to false before the user has touched anything.
    @State private var didInitialize = false
    /// Bumped when a background picker writes to AppState, forcing the swatch
    /// to re-read the latest backgroundImageUrl/backgroundColor.

    /// Which block is currently showing the theme picker sheet (nil = hidden).
    /// Owned here (not inside MarkdownEditor) so that DragulaView's two copies of
    /// each card — the hidden one that drives layout and the visible one inside a
    /// UIHostingController — read from the same AttributedString and therefore
    /// report the same intrinsic height. Previously each copy had its own @State
    /// AttributedString that re-derived from markdown via an HTML round-trip, and
    /// the two versions diverged whenever the round-trip altered whitespace or
    /// paragraph structure — which caused the visible editor to clip.
    @State private var editableBlockAttributed: [String: AttributedString] = [:]
    @State private var deletingBlockId: String?
    @State private var blockToDelete: ActivityReadBlock?
    @State private var collapsedBlockIds: Set<String> = []
    /// Set when a tap-and-hold selection inside a locked block stabilizes;
    /// `.onChange` opens the style picker. Cleared after the picker dismisses.
    @State private var pendingSelectionRange: NSRange?
    @State private var pendingSelectionBlockId: String?
    /// Block currently in highlight-mode (text-selection enabled). Tap the
    /// highlighter icon next to the chevron to toggle. While set, the rest of
    /// the activity dims and drag-to-sort is suppressed for that block.
    @State private var highlightingBlockId: String?
    @State private var showSourceMenu = false
    @State private var sourceMenuOffset: CGFloat = Screen.bounds.height
    @State private var sourceMenuOverlayOpacity: Double = 0
    @State private var showPassageSelection = false
    @State private var pendingTitleReference: String? = nil

    // Set-titles modal state
    @State private var showSetTitlesModal = false
    @State private var setTitlesModalOffset: CGFloat = Screen.bounds.height
    @State private var setTitlesModalOverlayOpacity: Double = 0
    @State private var setActivityTitleEnabled = true
    @State private var setLessonTitleEnabled = false

    // Mutable local array for drag-to-reorder via Dragula.
    // Initialized in init() to avoid NSAttributedString/WebKit crash on @State + RichTextInput.
    @State private var orderedBlocks: [ActivityReadBlock] = []

    // Preview state
    @State private var showSlidePreview = false

    // Theme editor state
    @State private var showThemeEditor = false
    /// Themes are loaded once at app startup into AppState — read them
    /// synchronously here so the picker + swatches on screens 2 & 3 render
    /// immediately, with no flash on first open of this editor.
    private var availableThemes: [TextTheme] { AppState.shared.textThemes }

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    init(
        activity: StudyActivity,
        lessonId: String,
        programId: String? = nil,
        passageCount: Int = 0,
        passageCountsByBook: [String: Int] = [:],
        currentLessonTitle: String? = nil,
        lessonActivityCount: Int = 1,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String?) -> Void,
        onLessonTitleUpdate: ((String) -> Void)? = nil,
        onBlocksChanged: (([ActivityReadBlock]) -> Void)? = nil,
        actions: ReadActivityActionProvider = .program
    ) {
        self.activity = activity
        self.lessonId = lessonId
        self.programId = programId
        self.passageCount = passageCount
        self.passageCountsByBook = passageCountsByBook
        self.currentLessonTitle = currentLessonTitle
        self.lessonActivityCount = lessonActivityCount
        self.onCancel = onCancel
        self.onSave = onSave
        self.onLessonTitleUpdate = onLessonTitleUpdate
        self.onBlocksChanged = onBlocksChanged
        self.actions = actions
        let blocks = (activity.readBlocks ?? []).sorted { $0.orderNumber < $1.orderNumber }
        _orderedBlocks = State(initialValue: blocks)
    }

    private var setTitlesActionLabel: String {
        switch (setActivityTitleEnabled, setLessonTitleEnabled) {
        case (true, true):  return "Set titles"
        case (true, false): return "Set title"
        case (false, true): return "Set title"
        case (false, false): return "Set title"
        }
    }

    /// Read fresh block data straight from AppState. Returns the live entity
    /// for either context, falling back to the original prop only if the
    /// activity hasn't been loaded into the store yet.
    private var blocksFromAppState: [ActivityReadBlock] {
        let source: [ActivityReadBlock]
        switch actions.context {
        case .program:
            source = AppState.shared.activities[activity.id]?.readBlocks ?? activity.readBlocks ?? []
        case .enrollment:
            // Read live from the lesson aggregate.
            let live = AppState.shared.scheduledLessons[lessonId]?
                .activities.first { $0.id == activity.id }?.readBlocks
            source = live ?? activity.readBlocks ?? []
        }
        return source.sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Fresh used-passages list for the current lesson, read directly from
    /// AppState. Updates the moment any verse is added or removed anywhere.
    private var currentUsedPassages: [PassageData] {
        AppState.shared.passagesUsedIn(lessonId: lessonId, context: actions.context)
    }

    /// Dump every verse the lesson and the current activity hold, straight from
    /// AppState — used to verify the read path during editing. Logs once per
    /// editor open and any time we want to manually inspect state.
    private func logVerseAudit() {
        let state = AppState.shared
        NSLog("🔎 VerseAudit — context=\(actions.context), lessonId=\(lessonId), activityId=\(activity.id)")

        // 1. All verses the lesson knows about (across every activity).
        let lessonPassages = state.passagesUsedIn(lessonId: lessonId, context: actions.context)
        NSLog("🔎 Lesson verses (\(lessonPassages.count)):")
        if lessonPassages.isEmpty {
            NSLog("🔎   (none)")
        } else {
            for (i, p) in lessonPassages.enumerated() {
                NSLog("🔎   [\(i)] \(p.reference) — book=\(p.bookNumber)/\(p.bookName) ch=\(p.chapterStart)\(p.chapterEnd.map { "-\($0)" } ?? "") v=\(p.verseStart)-\(p.verseEnd)")
            }
        }

        // 2. All verses on the current activity, read live from the lesson aggregate.
        let liveActivity: StudyActivity? = {
            switch actions.context {
            case .program:
                return state.activities[activity.id]
            case .enrollment:
                return state.scheduledLessons[lessonId]?
                    .activities.first { $0.id == activity.id }?.toStudyActivity()
            }
        }()

        let activityRefs = liveActivity?.sourceReferences ?? activity.sourceReferences ?? []
        NSLog("🔎 Activity sourceReferences (\(activityRefs.count)):")
        if activityRefs.isEmpty {
            NSLog("🔎   (none)")
        } else {
            for (i, ref) in activityRefs.enumerated() {
                NSLog("🔎   [\(i)] id=\(ref.id) book=\(ref.bookNumber.map(String.init) ?? "nil")/\(ref.bookName ?? "nil") ch=\(ref.chapterStart.map(String.init) ?? "nil") v=\(ref.verseStart.map(String.init) ?? "nil")-\(ref.verseEnd.map(String.init) ?? "nil")")
            }
        }

        // 3. ReadBlocks on the current activity (with sourceReferenceId linkage).
        let liveBlocks = liveActivity?.readBlocks ?? activity.readBlocks ?? []
        NSLog("🔎 Activity readBlocks (\(liveBlocks.count)):")
        for (i, block) in liveBlocks.sorted(by: { $0.orderNumber < $1.orderNumber }).enumerated() {
            NSLog("🔎   [\(i)] id=\(block.id) order=\(block.orderNumber) locked=\(block.isLocked) title=\(block.title ?? "nil") sourceRefId=\(block.sourceReferenceId ?? "nil")")
        }
    }

    var body: some View {
        // Canonical slider (Phase 3.4): SlideStack owns the slide choreography
        // this page previously hand-rolled with an always-mounted second pane +
        // offset/.animation. The theme editor now mounts one runloop before the
        // slide and unmounts when the slide-out completes.
        SlideStack(isPresented: $showThemeEditor) {
            editActivityContent
        } detail: {
            themeEditorContent
        }
        .fullScreenCover(isPresented: $showSlidePreview) {
            LessonPreviewModal(
                url: LessonPreviewModal.lessonURL(forActivityId: activity.id, lessonId: lessonId),
                isPresented: $showSlidePreview
            )
        }
        .onChange(of: title) { _, _ in
            if didInitialize { hasSaved = false }
        }
        .onChange(of: editableBlockAttributed) { _, _ in
            if didInitialize { hasSaved = false }
        }
        .alert("Delete Block", isPresented: Binding(
            get: { blockToDelete != nil },
            set: { if !$0 { blockToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let block = blockToDelete {
                    deleteBlock(block)
                }
                blockToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                blockToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this block? This cannot be undone.")
        }
        .onChange(of: showPassageSelection) { _, show in
            if show {
                presentBibleReaderOverlay()
            }
        }
        .onChange(of: pendingSelectionRange) { _, newRange in
            if newRange != nil {
                presentStylePickerForPendingSelection()
            }
        }
        .onAppear {
            title = activity.title ?? activity.type.displayName
            // Pre-populate editor state from each block's saved markdown. Done
            // once here so both DragulaView copies of the card bind to the same
            // AttributedString from the first frame.
            var attributed: [String: AttributedString] = [:]
            for block in orderedBlocks where !block.isLocked {
                attributed[block.id] = MarkdownEditor.markdownToAttributed(block.content ?? "")
            }
            editableBlockAttributed = attributed

            // Collapse locked blocks by default
            collapsedBlockIds = Set(orderedBlocks.filter { $0.isLocked }.map { $0.id })

            NSLog("📖 EditReadActivityPage - readBlocks count: \(activity.readBlocks?.count ?? 0)")
            for (i, block) in orderedBlocks.enumerated() {
                NSLog("📖 Block[\(i)]: id=\(block.id), order=\(block.orderNumber), isLocked=\(block.isLocked), title=\(block.title ?? "nil"), contentLength=\(block.content?.count ?? 0)")
            }

            // Verse audit: dump every verse the lesson knows about and every
            // verse this activity knows about, sourced live from AppState.
            logVerseAudit()

            // Flip the .onChange guard AFTER the initial assignments above
            // have dispatched their change events. Async ensures the onChange
            // observers see didInitialize=false for the seed writes.
            DispatchQueue.main.async {
                didInitialize = true
            }
        }
    }

    // MARK: - Edit Activity Content (Screen 1)

    private var editActivityContent: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if canEdit {
                    PageTitle.linkTitleLink(
                        title: "Edit Activity",
                        leftLink: "Cancel",
                        rightLink: isSaving ? "Saving..." : (hasSaved ? "Done" : "Save"),
                        rightLinkColor: isSaving ? .white.opacity(0.3) : nil,
                        onLeftLinkTap: { onCancel() },
                        onRightLinkTap: {
                            guard !isSaving else { return }
                            if hasSaved {
                                onSave(title)
                            } else {
                                save()
                            }
                        }
                    )
                    .opacity(highlightingBlockId == nil ? 1 : 0.3)
                    .allowsHitTesting(highlightingBlockId == nil)
                } else {
                    // Read-only header for non-creators: back chevron only,
                    // no save affordance regardless of input state.
                    PageTitle.iconTitle(
                        title: "Activity",
                        icon: "chevron.left",
                        onIconTap: { onCancel() }
                    )
                }

                ScrollView {
                    VStack(spacing: 16) {
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Activity title",
                                autocorrect: true,
                                text: $title
                            )
                        }
                        .padding(.horizontal, 16)
                        .opacity(highlightingBlockId == nil ? 1 : 0.3)
                        .allowsHitTesting(highlightingBlockId == nil)
                        .disabled(!canEdit)

                        // Drag-to-reorder only for the creator. Non-creators
                        // get a bare ForEach so blocks inherit the same parent
                        // VStack(spacing: 16) gap that DragulaView produces.
                        if canEdit {
                            DragulaView(
                                items: Binding<[DraggableReadBlock]>(
                                    get: {
                                        let canDrag = highlightingBlockId == nil
                                        return orderedBlocks.map { DraggableReadBlock(block: $0, isDraggable: canDrag) }
                                    },
                                    set: { newValue in
                                        orderedBlocks = newValue.map { $0.block }
                                    }
                                )
                            ) { wrapper in
                                blockView(wrapper.block)
                            } dropView: { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 48)
                                    .padding(.horizontal, 16)
                            } dropCompleted: {
                                persistBlockOrder()
                            }
                        } else {
                            ForEach(orderedBlocks, id: \.id) { block in
                                blockView(block)
                            }
                        }

                        // Add-block + Edit Themes + Preview buttons
                        VStack(spacing: 4) {
                            if canEdit {
                                BoxButton(
                                    action: { openSourceMenu() },
                                    icon: "plus",
                                    variant: .secondary,
                                    style: .solid,
                                    size: .lg,
                                    fullWidth: true,
                                    iconOpacity: 0.5
                                )

                                BoxButton(
                                    action: { openThemeEditor() },
                                    label: "Edit Themes",
                                    icon: "paintbrush",
                                    iconPosition: .right,
                                    variant: .secondary,
                                    style: .solid,
                                    size: .lg,
                                    fullWidth: true,
                                    iconOpacity: 0.5
                                )
                            }

                            // Preview is read-only; available to everyone.
                            BoxButton(
                                action: { openSlidePreview() },
                                label: "Preview",
                                icon: "eye",
                                iconPosition: .right,
                                variant: .secondary,
                                style: .solid,
                                size: .lg,
                                fullWidth: true,
                                iconOpacity: 0.5
                            )
                        }
                        .padding(.horizontal, 16)
                        .opacity(highlightingBlockId == nil ? 1 : 0.3)
                        .allowsHitTesting(highlightingBlockId == nil)
                    }
                    .padding(.top, 16)
                    .keyboardBottomPadding()
                }
                .environment(\.swipeState, swipeState)
                .scrollDisabled(swipeState.isSwiping)
            }

            // Source menu overlay
            if showSourceMenu {
                Color.black.opacity(sourceMenuOverlayOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { dismissSourceMenu() }

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 24)
                        .overlay {
                            Capsule()
                                .fill(Color(UIColor.tertiaryLabel))
                                .frame(width: 34, height: 5)
                        }

                    VStack(spacing: 8) {
                        CardActivityType(
                            title: "Bible verse",
                            description: "Add a passage from the Bible.",
                            image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                            mode: .list,
                            onTap: {
                                dismissSourceMenu {
                                    showPassageSelection = true
                                }
                            }
                        )
                        CardActivityType(
                            title: "Custom text",
                            description: "Add a rich text block you can write in.",
                            image: .icon(systemName: "text.alignleft", backgroundColor: Color(hex: "#6c47ff")),
                            mode: .list,
                            onTap: {
                                dismissSourceMenu {
                                    addCustomTextBlock()
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Button {
                        dismissSourceMenu()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#252936"))
                .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
                .offset(y: sourceMenuOffset)
            }

            // Set-titles modal
            if showSetTitlesModal {
                Color.black.opacity(setTitlesModalOverlayOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { dismissSetTitlesModal(apply: false) }

                setTitlesModalContent
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#252936"))
                    .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
                    .offset(y: setTitlesModalOffset)
            }
        }
    }

    // MARK: - Theme Editor Content (Screen 2)

    private var themeEditorContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitle(
                    title: "Edit Themes",
                    icon: "chevron.left",
                    onIconTap: { showThemeEditor = false }
                )

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(orderedBlocks) { block in
                            BlockStyleEditor(
                                activityId: activity.id,
                                blockId: block.id,
                                blockTitle: customBlockTitle(block),
                                availableThemes: availableThemes
                            )
                            .environment(overlayManager)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Theme Editor Actions

    private func openThemeEditor() {
        showThemeEditor = true
    }

    /// Display title for a block: uses explicit title, then content preview, then fallback.
    private func customBlockTitle(_ block: ActivityReadBlock?) -> String {
        guard let block else { return "Custom Text" }
        if let t = block.title, !t.isEmpty { return t }
        if block.isLocked { return "Bible Verse" }
        if let content = block.content,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let plain = content
                .replacingOccurrences(of: "^#{1,3}\\s+", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*+", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^>\\s+", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^-\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
            if !plain.isEmpty { return plain }
        }
        return "Custom Text"
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: ActivityReadBlock) -> some View {
        if block.isLocked {
            lockedBlockView(block)
        } else {
            editableBlockView(block)
        }
    }

    private func lockedBlockView(_ block: ActivityReadBlock) -> some View {
        let isDeleting = deletingBlockId == block.id
        let isCollapsed = collapsedBlockIds.contains(block.id)
        let isHighlighting = highlightingBlockId == block.id
        let dimForOtherHighlight = highlightingBlockId != nil && !isHighlighting

        // `rasterizesContent: false` is required because the expanded state
        // contains a UIViewRepresentable (SelectableLockedBlockView) which
        // SwipeableCard's default `.drawingGroup()` cannot flatten into a
        // Metal texture (it produces a yellow placeholder).
        return SwipeableCard(
            slideButtons: canEdit ? [
                SlideButton(icon: "trash", style: .delete) {
                    blockToDelete = block
                }
            ] : [],
            isSwipeEnabled: canEdit && !isDeleting && highlightingBlockId == nil,
            rasterizesContent: false,
            // The active highlighting block must let touches pass through to
            // its inner UITextView for tap-and-hold selection. Other blocks
            // keep their tap so tapping them exits highlight mode.
            isTapEnabled: !isHighlighting,
            onTap: {
                // While any block is in highlight mode, tapping anywhere
                // outside the active block exits highlight mode rather than
                // toggling collapse.
                if highlightingBlockId != nil && !isHighlighting {
                    withAnimation(Motion.micro) {
                        highlightingBlockId = nil
                    }
                    return
                }
                if isHighlighting { return }
                withAnimation(Motion.micro) {
                    if collapsedBlockIds.contains(block.id) {
                        collapsedBlockIds.remove(block.id)
                    } else {
                        collapsedBlockIds.insert(block.id)
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: isCollapsed ? 0 : 8) {
                if let blockTitle = block.title, !blockTitle.isEmpty {
                    HStack(spacing: 16) {
                        Text(blockTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        // Reserve space where the externally-overlaid highlighter
                        // button sits so the chevron lands in the same spot it
                        // would have if the button were inline.
                        if !isCollapsed {
                            Color.clear.frame(width: 24, height: 24)
                        }
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    if !isCollapsed {
                        Spacer().frame(height: 2)
                    }
                }

                if !isCollapsed, let content = block.content, !content.isEmpty {
                    SelectableLockedBlockView(
                        plainText: BibleVerseContentNormalizer.normalizedPlainText(from: content),
                        selections: block.selections ?? [],
                        isSelectionEnabled: isHighlighting,
                        editingRange: pendingSelectionBlockId == block.id ? pendingSelectionRange : nil,
                        pendingRange: Binding(
                            get: { pendingSelectionBlockId == block.id ? pendingSelectionRange : nil },
                            set: { newValue in
                                pendingSelectionRange = newValue
                                pendingSelectionBlockId = newValue == nil ? nil : block.id
                            }
                        ),
                        isScripture: block.sourceReferenceId != nil
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#252936"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isHighlighting ? Color(hex: "#6c47ff").opacity(0.8) : Color.white.opacity(0.08),
                        lineWidth: isHighlighting ? 2 : 1
                    )
            )
            .opacity(isDeleting ? 0.5 : (dimForOtherHighlight ? 0.3 : 1))
        }
        // Highlighter button overlays the SwipeableCard externally so it's
        // above the card's UIKit gesture coordinator in z-order — otherwise
        // taps would be eaten by the coordinator's tap recognizer (which
        // toggles collapse). Positioned to land where the inline placeholder
        // sits inside the title row.
        .overlay(alignment: .topTrailing) {
            if !isCollapsed {
                Button {
                    withAnimation(Motion.micro) {
                        highlightingBlockId = isHighlighting ? nil : block.id
                        pendingSelectionRange = nil
                        pendingSelectionBlockId = nil
                    }
                } label: {
                    Image(systemName: "highlighter")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isHighlighting ? Color(hex: "#6c47ff") : .white.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 13)
                .padding(.trailing, 44)
                .opacity(isDeleting ? 0.5 : (dimForOtherHighlight ? 0.3 : 1))
            }
        }
        .padding(.horizontal, 16)
    }

    private func editableBlockView(_ block: ActivityReadBlock) -> some View {
        let binding = Binding<AttributedString>(
            get: { editableBlockAttributed[block.id] ?? AttributedString() },
            set: { editableBlockAttributed[block.id] = $0 }
        )
        let isDeleting = deletingBlockId == block.id

        return MarkdownEditor(
            placeholder: "Write content...",
            attributedText: binding,
            minHeight: 100,
            autoGrow: true
        )
        .overlay(alignment: .topTrailing) {
            Button {
                blockToDelete = block
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .padding(8)
        }
        .opacity(isDeleting ? 0.5 : (highlightingBlockId != nil ? 0.3 : 1))
        .allowsHitTesting(highlightingBlockId == nil)
        .padding(.horizontal, 16)
    }

    // MARK: - Delete Block

    private func deleteBlock(_ block: ActivityReadBlock) {
        deletingBlockId = block.id
        Task {
            do {
                let updatedBlocks = try await actions.deleteReadBlock(activity.id, block.id)
                NSLog("📖 Deleted read block: \(block.id)")
                if let blocks = updatedBlocks {
                    orderedBlocks = blocks.sorted { $0.orderNumber < $1.orderNumber }
                } else {
                    orderedBlocks = blocksFromAppState
                }
                onBlocksChanged?(orderedBlocks)
            } catch {
                NSLog("Failed to delete read block: \(error)")
            }
            deletingBlockId = nil
        }
    }

    // MARK: - Source Menu

    private func openSourceMenu() {
        // Dismiss keyboard so menu isn't hidden behind it
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        showSourceMenu = true
        ModalAnimations.animateAppear(
            offset: $sourceMenuOffset,
            overlayOpacity: $sourceMenuOverlayOpacity
        )
    }

    /// Optional completion runs when the exit animation finishes
    /// (Phase 3.2 — replaces wall-clock asyncAfter waits).
    private func dismissSourceMenu(then completion: (() -> Void)? = nil) {
        ModalAnimations.animateDismiss(
            offset: $sourceMenuOffset,
            overlayOpacity: $sourceMenuOverlayOpacity,
            screenHeight: Screen.bounds.height
        ) {
            showSourceMenu = false
            completion?()
        }
    }

    // MARK: - Preview Lesson (local slide preview)

    private func openSlidePreview() {
        // Themes were loaded at app startup into AppState — no network
        // round-trip needed here. See AppState.loadTextThemes().
        showSlidePreview = true
    }

    // MARK: - Set Titles Modal

    @ViewBuilder
    private var setTitlesModalContent: some View {
        let activityCurrent = title.isEmpty ? (activity.title ?? activity.type.displayName) : title
        let lessonCurrent = (currentLessonTitle?.isEmpty == false ? currentLessonTitle : nil) ?? "Untitled lesson"

        VStack(spacing: 0) {
            // Drag indicator
            Rectangle()
                .fill(Color.clear)
                .frame(height: 24)
                .overlay {
                    Capsule()
                        .fill(Color(UIColor.tertiaryLabel))
                        .frame(width: 34, height: 5)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Set titles?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("Select which of the titles below you would like to change or proceed without updating the title. You can update the activity and lesson title at any time.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                setTitleRow(
                    label: activityCurrent,
                    currentTitle: activityCurrent,
                    description: "Set the title of this activity.",
                    isOn: $setActivityTitleEnabled
                )
                setTitleRow(
                    label: "Lesson",
                    currentTitle: lessonCurrent,
                    description: "Set the title of the entire lesson, which has \(lessonActivityCount) \(lessonActivityCount == 1 ? "activity" : "activities").",
                    isOn: $setLessonTitleEnabled
                )
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                BoxButton(
                    action: { dismissSetTitlesModal(apply: false) },
                    label: "Do nothing",
                    variant: .secondary,
                    style: .solid,
                    size: .lg,
                    fullWidth: true
                )
                BoxButton(
                    action: { dismissSetTitlesModal(apply: true) },
                    label: setTitlesActionLabel,
                    variant: .primary,
                    style: .solid,
                    size: .lg,
                    fullWidth: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    private func setTitleRow(label: String, currentTitle: String, description: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                CustomToggle(isOn: isOn)
            }
            Text(currentTitle)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openSetTitlesModal() {
        // If the activity already has a locked (Bible verse) read block,
        // default both toggles off so we don't overwrite a title the user
        // has likely already set from an earlier passage.
        let hasLockedBlock = orderedBlocks.contains { $0.isLocked }
        setActivityTitleEnabled = !hasLockedBlock
        setLessonTitleEnabled = false
        // Dismiss keyboard
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        showSetTitlesModal = true
        ModalAnimations.animateAppear(
            offset: $setTitlesModalOffset,
            overlayOpacity: $setTitlesModalOverlayOpacity
        )
    }

    private func dismissSetTitlesModal(apply: Bool) {
        let reference = pendingTitleReference
        let applyActivity = apply && setActivityTitleEnabled
        let applyLesson = apply && setLessonTitleEnabled

        ModalAnimations.animateDismiss(
            offset: $setTitlesModalOffset,
            overlayOpacity: $setTitlesModalOverlayOpacity,
            screenHeight: Screen.bounds.height
        ) {
            showSetTitlesModal = false
            if let reference = reference {
                if applyActivity {
                    title = reference
                }
                if applyLesson {
                    onLessonTitleUpdate?(reference)
                }
            }
            pendingTitleReference = nil
        }
    }

    // MARK: - Add from Source

    private func addCustomTextBlock() {
        let previousIds = orderedBlocks.map { $0.id }
        Task {
            do {
                let updatedBlocks = try await actions.createCustomBlock(activity.id)
                let source = updatedBlocks ?? blocksFromAppState
                orderedBlocks = appendNewBlocksToEnd(updated: source, previousIds: previousIds)
                // Seed editor state for any new non-locked blocks
                for block in orderedBlocks where !block.isLocked && editableBlockAttributed[block.id] == nil {
                    editableBlockAttributed[block.id] = MarkdownEditor.markdownToAttributed(block.content ?? "")
                }
                onBlocksChanged?(orderedBlocks)
            } catch {
                NSLog("📖 Failed to create custom text block: \(error)")
            }
        }
    }

    /// Place any newly-added blocks at the end of the list, preserving the prior
    /// order for existing blocks. Persists the new order to the server if it
    /// differs from what the server returned.
    private func appendNewBlocksToEnd(updated: [ActivityReadBlock], previousIds: [String]) -> [ActivityReadBlock] {
        let previousIdSet = Set(previousIds)
        let byId = Dictionary(uniqueKeysWithValues: updated.map { ($0.id, $0) })

        // Existing blocks in their prior display order (drop any that were removed server-side).
        var result: [ActivityReadBlock] = previousIds.compactMap { byId[$0] }

        // New blocks (not in prior list) appended in server order.
        let newBlocks = updated
            .sorted { $0.orderNumber < $1.orderNumber }
            .filter { !previousIdSet.contains($0.id) }
        result.append(contentsOf: newBlocks)

        // Normalize order numbers 1..N locally.
        for i in 0..<result.count {
            result[i].orderNumber = i + 1
        }

        // Persist to AppState so state matches UI.
        if var updatedActivity = AppState.shared.activities[activity.id] {
            updatedActivity.readBlocks = result
            AppState.shared.activities.upsert(updatedActivity)
        }

        // If the server order differs from our desired order, persist the reorder.
        let serverOrder = updated.sorted { $0.orderNumber < $1.orderNumber }.map { $0.id }
        let desiredOrder = result.map { $0.id }
        if serverOrder != desiredOrder {
            Task {
                try? await actions.reorderReadBlocks(activity.id, desiredOrder)
            }
        }

        return result
    }

    private func presentBibleReaderOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let overlay = BibleReaderOverlayView(
            overlayManager: OverlayManager(),
            onDismiss: { [self] in
                showPassageSelection = false
            },
            onPassageConfirmed: { [self] book, chapter, verseStart, verseEnd, selectedText in
                showPassageSelection = false

                let passageData = PassageData(
                    bookNumber: book.id,
                    bookName: book.name,
                    chapterStart: chapter,
                    chapterEnd: nil,
                    verseStart: verseStart,
                    verseEnd: verseEnd
                )
                let highlightRange = HighlightRange(
                    startElementId: "\(book.id)-\(chapter)-\(verseStart)",
                    startOffset: 0,
                    endElementId: "\(book.id)-\(chapter)-\(verseEnd)",
                    endOffset: 0
                )
                handlePassageSelected(passageData, highlightRange: highlightRange, selectedText: selectedText)
            },
            usedPassages: currentUsedPassages
        )
        overlay.frame = window.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)

        // Animate up from bottom
        overlay.presentFromBottom()
    }

    private func handlePassageSelected(_ passageData: PassageData, highlightRange: HighlightRange, selectedText: String? = nil) {
        let previousIds = orderedBlocks.map { $0.id }
        Task {
            let content: String

            if let selectedText, !selectedText.isEmpty {
                // Use the text selected by the user in the reader (plain text)
                content = BibleVerseContentNormalizer.normalizedMarkdown(from: selectedText)
            } else {
                // Fallback: fetch verses from local Bible cache
                guard let verses = await BibleCacheManager.shared.getChapterVerses(
                    bookNumber: passageData.bookNumber,
                    chapter: passageData.chapterStart
                ) else { return }

                let selected = verses.filter { $0.v >= passageData.verseStart && $0.v <= passageData.verseEnd }

                let plainText = selected.map { verse -> String in
                    let fullText = verse.t
                    let isFirst = verse.v == passageData.verseStart
                    let isLast = verse.v == passageData.verseEnd

                    let startChar = isFirst ? min(highlightRange.startOffset, fullText.count) : 0
                    let endChar = isLast ? min(highlightRange.endOffset, fullText.count) : fullText.count

                    let startIdx = fullText.index(fullText.startIndex, offsetBy: startChar)
                    let endIdx = fullText.index(fullText.startIndex, offsetBy: endChar)
                    let text = String(fullText[startIdx..<endIdx])

                    return "\(verse.v). \(text)"
                }.joined(separator: "\n")
                content = BibleVerseContentNormalizer.normalizedMarkdown(from: plainText)
            }

            // addSourceReference creates a locked read block server-side and returns updated activity
            NSLog("📖 handlePassageSelected: calling addSourceReference with content length=\(content.count)")
            let updatedBlocks = try? await actions.addSourceReference(activity.id, passageData, content)
            NSLog("📖 handlePassageSelected: updatedBlocks=\(updatedBlocks != nil ? "\(updatedBlocks!.count) blocks" : "nil"), onLessonTitleUpdate=\(onLessonTitleUpdate != nil)")

            let source = updatedBlocks ?? blocksFromAppState
            orderedBlocks = appendNewBlocksToEnd(updated: source, previousIds: previousIds)
            onBlocksChanged?(orderedBlocks)

            // Ask user if they want to set the activity and/or lesson title to the verse reference
            pendingTitleReference = passageData.reference
            openSetTitlesModal()
            NSLog("📖 handlePassageSelected: showing set-titles modal for '\(passageData.reference)'")
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        Task {
            do {
                try await actions.updateTitle(activity.id, title)

                // Convert each editable block's AttributedString to markdown
                // only at save time — no per-keystroke round trip.
                var markdownByBlockId: [String: String] = [:]
                for block in orderedBlocks where !block.isLocked {
                    let attr = editableBlockAttributed[block.id] ?? AttributedString()
                    markdownByBlockId[block.id] = MarkdownEditor.attributedToMarkdown(attr)
                }

                for block in orderedBlocks where !block.isLocked {
                    let currentContent = markdownByBlockId[block.id] ?? ""
                    let originalContent = block.content ?? ""
                    if currentContent != originalContent {
                        try await actions.updateReadBlock(activity.id, block.id, currentContent)
                    }
                }

                // Notify parent of updated blocks (with saved content applied)
                var finalBlocks = orderedBlocks
                for i in 0..<finalBlocks.count where !finalBlocks[i].isLocked {
                    finalBlocks[i].content = markdownByBlockId[finalBlocks[i].id] ?? finalBlocks[i].content
                }
                onBlocksChanged?(finalBlocks)

                isSaving = false
                hasSaved = true
            } catch {
                NSLog("📖 Failed to save read activity: \(error)")
                isSaving = false
            }
        }
    }

    // MARK: - Persist Block Order

    private func persistBlockOrder() {
        // Only persist if order numbers need updating
        let needsUpdate = orderedBlocks.enumerated().contains { $0.element.orderNumber != $0.offset + 1 }
        guard needsUpdate else { return }

        var reordered = orderedBlocks
        for i in 0..<reordered.count {
            reordered[i].orderNumber = i + 1
        }

        // Update AppState if available (program context)
        if var updatedActivity = AppState.shared.activities[activity.id] {
            updatedActivity.readBlocks = reordered
            AppState.shared.activities.upsert(updatedActivity)
        }

        orderedBlocks = reordered
        onBlocksChanged?(reordered)

        let blockIds = reordered.map { $0.id }
        Task {
            try? await actions.reorderReadBlocks(activity.id, blockIds)
        }
    }

    // MARK: - Styled Selections

    private func presentStylePickerForPendingSelection() {
        guard let range = pendingSelectionRange,
              let blockId = pendingSelectionBlockId,
              let block = orderedBlocks.first(where: { $0.id == blockId }),
              let content = block.content else { return }

        let plain = BibleVerseContentNormalizer.normalizedPlainText(from: content)
        let nsPlain = plain as NSString
        guard range.location >= 0,
              range.location + range.length <= nsPlain.length else { return }
        let snippet = nsPlain.substring(with: range)

        // Look up the existing selection that exactly matches this range so
        // the picker can show the active style preselected. If the user
        // long-pressed a fresh range, no match → currentStyle = nil.
        let existing = block.selections ?? []
        let exactMatch = existing.first { $0.start == range.location && $0.end == range.location + range.length }
        let currentStyle = exactMatch.flatMap { ReadBlockSelectionStyle(rawValue: $0.style) }

        overlayManager.presentMenu(id: OverlayID.stylePicker(blockId: blockId)) {
            StylePickerMenu(
                snippet: snippet,
                currentStyle: currentStyle,
                onSelect: { [activityId = activity.id] chosen in
                    applyStyle(chosen, range: range, blockId: blockId, activityId: activityId)
                },
                onDismiss: {
                    // Clear the editing highlight on the span when the menu
                    // disappears (covers cancel + scrim-tap dismissals;
                    // applyStyle already clears these explicitly).
                    pendingSelectionRange = nil
                    pendingSelectionBlockId = nil
                }
            )
        }
    }

    private func applyStyle(
        _ style: ReadBlockSelectionStyle?,
        range: NSRange,
        blockId: String,
        activityId: String
    ) {
        guard let blockIndex = orderedBlocks.firstIndex(where: { $0.id == blockId }) else { return }
        let existing = orderedBlocks[blockIndex].selections ?? []
        let merged = mergeSelection(into: existing, range: range, style: style?.rawValue)

        // Optimistic local update so the UI re-renders immediately.
        orderedBlocks[blockIndex].selections = merged
        if var activity = AppState.shared.activities[activityId],
           var blocks = activity.readBlocks,
           let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].selections = merged
            activity.readBlocks = blocks
            AppState.shared.activities.upsert(activity)
        }

        pendingSelectionRange = nil
        pendingSelectionBlockId = nil

        Task {
            do {
                try await actions.updateReadBlockSelections(activityId, blockId, merged)
            } catch {
                NSLog("❌ Failed to save selections: \(error.localizedDescription)")
            }
        }
    }

    /// Merge `range` (with optional `style`) into `existing`. A nil style removes
    /// any selections fully covered by `range`. Otherwise, drop any overlapping
    /// existing selections and append the new one.
    private func mergeSelection(
        into existing: [ReadBlockSelection],
        range: NSRange,
        style: String?
    ) -> [ReadBlockSelection] {
        let start = range.location
        let end = range.location + range.length
        let overlaps: (ReadBlockSelection) -> Bool = { sel in
            sel.start < end && sel.end > start
        }

        let kept = existing.filter { !overlaps($0) }
        guard let style else { return kept }
        return kept + [ReadBlockSelection(start: start, end: end, style: style)]
    }

}

// MARK: - DragulaItem Conformance

extension ActivityReadBlock: DragulaItem {}

/// Wrapper around `ActivityReadBlock` that lets the page toggle `isDraggable`
/// at runtime (e.g. to suppress drag-to-sort while a block is in highlight mode).
struct DraggableReadBlock: DragulaItem, Identifiable {
    let block: ActivityReadBlock
    let isDraggable: Bool
    var id: String { block.id }
}

// MARK: - Previews

#Preview("Single Read") {
    EditReadActivityPage(
        activity: StudyActivity(
            id: "preview-single",
            type: .read,
            status: .complete,
            orderNumber: 1,
            title: "Scripture",
            readBlocks: [
                ActivityReadBlock(
                    id: "block-1",
                    orderNumber: 1,
                    content: "",
                    isLocked: false
                )
            ]
        ),
        lessonId: "preview-lesson",
        onCancel: { print("Cancel") },
        onSave: { title in print("Save: \(title ?? "nil")") }
    )
}

#Preview("Multi-Read") {
    EditReadActivityPage(
        activity: StudyActivity(
            id: "preview-multi",
            type: .read,
            status: .complete,
            orderNumber: 1,
            title: "Who is God",
            readBlocks: [
                ActivityReadBlock(
                    id: "block-1",
                    orderNumber: 1,
                    title: "Genesis 1:1-2",
                    content: "In the beginning God created the heavens and the earth. The earth was formless and void, and darkness was over the surface of the deep, and the Spirit of God was moving over the surface of the waters.",
                    isLocked: true,
                    sourceReferenceId: "ref-1"
                ),
                ActivityReadBlock(
                    id: "block-2",
                    orderNumber: 2,
                    content: "# God was not created\n\nGod wasn't created — He was **before all things**.\n\n- He created the space\n- He created gravity\n- He created light\n\n> In the beginning was the Word, and the Word was with God, and the Word was God.\n\nGod has a capital \"S\" *Spirit*.",
                    isLocked: false
                ),
                ActivityReadBlock(
                    id: "block-3",
                    orderNumber: 3,
                    title: "Genesis 1:3-5",
                    content: "Then God said, \"Let there be light\"; and there was light. God saw that the light was good; and God separated the light from the darkness. God called the light day, and the darkness He called night. And there was evening and there was morning, one day.",
                    isLocked: true,
                    sourceReferenceId: "ref-2"
                )
            ]
        ),
        lessonId: "preview-lesson",
        programId: "preview-program",
        onCancel: { print("Cancel") },
        onSave: { title in print("Save: \(title ?? "nil")") }
    )
}
