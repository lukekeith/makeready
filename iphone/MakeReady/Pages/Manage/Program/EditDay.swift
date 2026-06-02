//
//  EditDay.swift
//  MakeReady
//
//  Edit activities for a specific day in a study program
//

import SwiftUI
import WebKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct EditDay: View {
    @Binding var isPresented: Bool
    let programId: String  // Explicit program ID since lesson might not have it
    let lesson: Lesson
    let onLessonUpdated: (Lesson) -> Void
    let onShowAddActivityMenu: (([String], @escaping (String) -> Void) -> Void)?

    @EnvironmentObject var authManager: AuthManager

    /// True when the signed-in user is the creator of the parent program.
    /// Drives gating for save, plus, swipe, drag, and input fields so non-
    /// creators can view but never mutate this lesson.
    private var canEdit: Bool {
        AppState.shared.programs[programId]?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    // Navigation state — track by id so we always read live data from AppState.
    @State private var editingActivity: StudyActivity? = nil
    @State private var editingActivityId: String? = nil
    @State private var showEditActivity = false

    /// Live activity list, read directly from AppState. ProgramActions writes
    /// to the same store on every mutation, so this view re-renders the moment
    /// any activity/block/verse changes anywhere in the app.
    private var activities: [StudyActivity] {
        AppState.shared.programActivitiesFor(lessonId: lesson.id)
    }

    /// The activity currently being edited inline (looked up live from AppState).
    private var editingActivityInline: StudyActivity? {
        guard let id = editingActivityId else { return nil }
        return AppState.shared.activities[id]
    }

    /// Writable binding for Dragula reorder. Reads live from AppState; writes
    /// optimistically apply the new orderNumber to each entity in the store so
    /// the drag visual works. The drop callback persists to the server.
    private var activitiesBinding: Binding<[StudyActivity]> {
        Binding(
            get: { self.activities },
            set: { newValue in
                for (i, activity) in newValue.enumerated() {
                    if var a = AppState.shared.activities[activity.id] {
                        a.orderNumber = i + 1
                        AppState.shared.activities.upsert(a)
                    }
                }
            }
        )
    }

    // Reset confirmation state
    @State private var activityToReset: StudyActivity? = nil
    @State private var showResetConfirmation = false

    // Delete confirmation state
    @State private var activityToDelete: StudyActivity? = nil
    @State private var showDeleteConfirmation = false

    // Video selection state
    @State private var selectingVideoForActivity: StudyActivity? = nil

    // Video preview state (native player)
    @State private var previewingVideoActivity: StudyActivity? = nil

    // Video web preview state (LessonPreviewModal)
    @State private var previewingVideoActivityWeb: StudyActivity? = nil
    @State private var isGeneratingVideoPreview = false

    // Loading states for inline spinners
    @State private var savingActivityId: String? = nil
    @State private var resettingActivityId: String? = nil
    @State private var deletingActivityId: String? = nil
    @State private var addingActivity = false

    // Clear confirmation state
    @State private var activityToClear: StudyActivity? = nil
    @State private var showClearConfirmation = false
    @State private var clearingActivityId: String? = nil

    // Preview state — uses item: binding to avoid nil-URL race.
    // Holds the full-lesson preview URL so the member lesson view (with
    // activity navigation) renders, mirroring ProgramHomePage's study preview.
    @State private var previewLessonURL: IdentifiableURL? = nil

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Lesson title state
    @State private var lessonTitle: String = ""
    @State private var originalLessonTitle: String = ""
    @State private var isSavingTitle = false


    // Check if all activities have passages (Done button enabled)
    private var canComplete: Bool {
        activities.allSatisfy { $0.status == .complete }
    }

    // Whether the lesson title has been edited
    private var hasTitleChanges: Bool {
        lessonTitle != originalLessonTitle
    }

    /// All passages used anywhere in this lesson, read live from AppState.
    /// Used for the Bible reader's "already used" highlights.
    private var lessonUsedPassages: [PassageData] {
        AppState.shared.passagesUsedIn(lessonId: lesson.id, context: .program)
    }

    // Total passage count for display
    private var totalPassageCount: Int {
        lessonUsedPassages.count
    }

    // Passage counts per book for display in book list
    private var passageCountsByBook: [String: Int] {
        var counts: [String: Int] = [:]
        for passage in lessonUsedPassages {
            counts[passage.bookName, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Screen 1: Day content
                dayContent
                    .frame(width: geometry.size.width)

                // Screen 2: Inline edit pages
                ZStack {
                    if let activity = editingActivityInline {
                        switch activity.type {
                        case .read:
                            EditReadActivityPage(
                                activity: activity,
                                lessonId: lesson.id,
                                programId: programId,
                                passageCount: totalPassageCount,
                                passageCountsByBook: passageCountsByBook,
                                currentLessonTitle: lessonTitle,
                                lessonActivityCount: activities.count,
                                onCancel: dismissEditActivity,
                                onSave: { title in
                                    saveReadContent(title: title)
                                },
                                onLessonTitleUpdate: { reference in
                                    updateLessonTitle(reference)
                                },
                                onBlocksChanged: { _ in
                                    // No-op: ProgramActions writes blocks directly to AppState,
                                    // so this view auto-rerenders.
                                }
                            )
                            .id(activity.id)
                        case .exegesis:
                            EditExegesisActivityPage(
                                activity: activity,
                                programId: programId,
                                onCancel: dismissEditActivity,
                                onSave: {
                                    dismissEditActivity()

                                    var updatedLesson = lesson
                                    updatedLesson.activities = activities
                                    onLessonUpdated(updatedLesson)
                                }
                            )
                            .id(activity.id)
                        case .userInput:
                            EditUserInputActivityPage(
                                activity: activity,
                                programId: programId,
                                onCancel: dismissEditActivity,
                                onSave: { title, isHelpEnabled, helpTitle, helpDescription, placeholder in
                                    saveUserInputContent(title: title, isHelpEnabled: isHelpEnabled, helpTitle: helpTitle, helpDescription: helpDescription, placeholder: placeholder)
                                }
                            )
                            .id(activity.id)
                        case .youtube:
                            EditYouTubeActivityPage(
                                activity: activity,
                                programId: programId,
                                onCancel: dismissEditActivity,
                                onSave: { _, _, _, _ in
                                    dismissEditActivity()

                                    var updatedLesson = lesson
                                    updatedLesson.activities = activities
                                    onLessonUpdated(updatedLesson)
                                }
                            )
                            .id(activity.id)
                        default:
                            EmptyView()
                        }
                    }
                }
                .frame(width: geometry.size.width)
            }
            .offset(x: showEditActivity ? -geometry.size.width : 0)
            .animation(.easeInOut(duration: 0.3), value: showEditActivity)
        }
        .onAppear {
            let title = lesson.title ?? ""
            lessonTitle = title
            originalLessonTitle = title
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectingVideoForActivity != nil },
            set: { if !$0 { selectingVideoForActivity = nil } }
        )) {
            if let activity = selectingVideoForActivity {
                VideoActivityPicker(
                    onDismiss: {
                        selectingVideoForActivity = nil
                    },
                    onVideoSelected: { result in
                        handleVideoSelected(result, for: activity)
                    }
                )
            }
        }
        .onChange(of: editingActivity?.id) { _, newId in
            guard newId != nil, let activity = editingActivity else { return }
            presentBibleReaderForActivity(activity)
        }
        .fullScreenCover(item: $previewingVideoActivity) { activity in
            VideoActivityManager(
                videoUrl: activity.videoUrl ?? activity.video?.playbackUrl ?? "",
                videoThumbnailUrl: activity.video?.thumbnailUrl,
                onDismiss: {
                    previewingVideoActivity = nil
                },
                onVideoSelected: { result in
                    previewingVideoActivity = nil
                    handleVideoSelected(result, for: activity)
                },
                onVideoRemoved: {
                    previewingVideoActivity = nil
                    Task {
                        do {
                            _ = try await ProgramActions().removeActivityVideo(activityId: activity.id)
                            await MainActor.run {
                                var updatedLesson = lesson
                                updatedLesson.activities = activities
                                onLessonUpdated(updatedLesson)
                            }
                        } catch {
                            NSLog("❌ Failed to remove video: \(error)")
                        }
                    }
                }
            )
        }
        .fullScreenCover(item: $previewLessonURL) { item in
            LessonPreviewModal(url: item.url, isPresented: Binding(
                get: { previewLessonURL != nil },
                set: { if !$0 { previewLessonURL = nil } }
            ))
        }
        .fullScreenCover(isPresented: Binding(
            get: { previewingVideoActivityWeb != nil },
            set: { if !$0 { previewingVideoActivityWeb = nil } }
        )) {
            if let activity = previewingVideoActivityWeb {
                ReadActivityPreviewModal(activityId: activity.id, isPresented: Binding(
                    get: { previewingVideoActivityWeb != nil },
                    set: { if !$0 { previewingVideoActivityWeb = nil } }
                ))
            }
        }
        .alert("Reset activity?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {
                activityToReset = nil
            }
            Button("Reset", role: .destructive) {
                if let activity = activityToReset {
                    resetActivity(activity)
                }
                activityToReset = nil
            }
        } message: {
            Text("Resetting this activity is not reversible and will remove all data associated with this activity. Once members have participated in this activity, it can no longer be reset.")
        }
        .alert("Delete activity?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    deleteActivity(activity)
                }
                activityToDelete = nil
            }
        } message: {
            Text("This will permanently remove this activity from the day. This action cannot be undone.")
        }
        .alert("Clear activity?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {
                activityToClear = nil
            }
            Button("Clear", role: .destructive) {
                if let activity = activityToClear {
                    clearActivity(activity)
                }
                activityToClear = nil
                showClearConfirmation = false
            }
        } message: {
            Text("This will reset the activity to its default state, clearing any content that has been configured.")
        }
        .keyboardManaged()
    }

    // MARK: - Day Content (Screen 1)

    private var dayContent: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: switches between back/Done and Cancel/Save based on title edits.
                // For non-creators we always render a plain back-only header — no save
                // affordance regardless of any input state.
                if !canEdit {
                    PageTitle.iconTitle(
                        title: "Day \(lesson.dayNumber)",
                        icon: "chevron.left",
                        onIconTap: { isPresented = false }
                    )
                } else if hasTitleChanges {
                    PageTitle.linkTitleLink(
                        title: "Day \(lesson.dayNumber)",
                        leftLink: "Cancel",
                        rightLink: isSavingTitle ? "Saving..." : "Save",
                        rightLinkColor: isSavingTitle ? .white.opacity(0.3) : nil,
                        onLeftLinkTap: {
                            // Revert title to original
                            lessonTitle = originalLessonTitle
                        },
                        onRightLinkTap: {
                            guard !isSavingTitle else { return }
                            saveLessonTitle()
                        }
                    )
                } else {
                    PageTitle.iconTitleLink(
                        title: "Day \(lesson.dayNumber)",
                        leftIcon: "chevron.left",
                        rightLink: "Done",
                        rightLinkDisabled: false,
                        onLeftIconTap: {
                            isPresented = false
                        },
                        onRightLinkTap: {
                            var updatedLesson = lesson
                            updatedLesson.activities = activities
                            onLessonUpdated(updatedLesson)
                            isPresented = false
                        }
                    )
                }

                // Lesson title
                FieldGroup {
                    TextInput(
                        floatingLabel: "Lesson title",
                        text: $lessonTitle
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .disabled(!canEdit)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 4) {
                        // Drag-to-reorder only for the creator. Non-creators
                        // get a bare ForEach so cards inherit the same parent
                        // VStack(spacing: 4) gap that DragulaView produces.
                        if canEdit {
                            DragulaView(items: activitiesBinding) { activity in
                                activityCard(for: activity)
                            } dropView: { _ in
                                ReorderDropIndicator()
                            } dropCompleted: {
                                persistActivityOrder()
                            }
                        } else {
                            ForEach(activities, id: \.id) { activity in
                                activityCard(for: activity)
                            }
                        }

                        // Show skeleton card while adding new activity
                        if addingActivity {
                            SkeletonCardLessonActivity()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Plus button: only visible to the creator. Non-creators
                        // can't add activities to a lesson they don't own.
                        if canEdit {
                            // Full width large secondary add button (for future activities)
                            Spacer().frame(height: 12)
                            BoxButton(
                                action: {
                                    guard !addingActivity else { return }
                                    let existingTypes = activities.map { $0.type.rawValue }
                                    onShowAddActivityMenu?(existingTypes) { selectedType in
                                        Task {
                                            await addActivity(type: selectedType)
                                        }
                                    }
                                },
                                label: nil,
                                icon: "plus",
                                iconPosition: .right,
                                variant: .secondary,
                                style: .solid,
                                size: .lg,
                                fullWidth: true,
                                iconOpacity: 0.5
                            )
                            .opacity(addingActivity ? 0.5 : 1.0)
                        }

                        // Preview button
                        BoxButton(
                            action: { openPreview() },
                            label: "Preview",
                            icon: "eye",
                            iconPosition: .right,
                            variant: .secondary,
                            style: .solid,
                            size: .lg,
                            fullWidth: true,
                            iconOpacity: 0.5
                        )
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .environment(\.swipeState, swipeState)
                .scrollDisabled(swipeState.isSwiping)
            }
        }
    }

    // MARK: - Activity Card

    @ViewBuilder
    private func activityCard(for activity: StudyActivity) -> some View {
        if activity.type == .video {
            videoActivityCard(for: activity)
        } else {
            studyActivityCard(for: activity)
        }
    }

    // MARK: - Activity Helpers

    /// Build a summary description for READ activities from the first read block.
    private func readBlockSummary(for activity: StudyActivity) -> String? {
        guard let block = activity.readBlocks?.sorted(by: { $0.orderNumber < $1.orderNumber }).first,
              let content = block.content, !content.isEmpty else { return nil }
        if let title = block.title, !title.isEmpty {
            return "\(title)\n\(content)"
        }
        return content
    }

    // MARK: - Study Activity Card (SOAP, OIA, etc.)

    @ViewBuilder
    private func studyActivityCard(for activity: StudyActivity) -> some View {
        let isReady = activity.isConfigured
        let pendingLabel: String = {
            switch activity.type {
            case .read: return "Provide text to read"
            case .userInput: return "Describe what you want members to input"
            case .exegesis: return "Select passage and add highlights"
            default: return "Select passage"
            }
        }()
        let description: String = {
            guard isReady else { return pendingLabel }
            if activity.type == .read, let summary = readBlockSummary(for: activity) { return summary }
            if activity.type == .exegesis,
               let block = activity.readBlocks?.first(where: { $0.isLocked }),
               let title = block.title, !title.isEmpty {
                return title
            }
            return activity.passageReference ?? activity.type.displayName
        }()
        let isComplete = activity.status == .complete
        let isSaving = savingActivityId == activity.id
        let isResetting = resettingActivityId == activity.id
        let isDeleting = deletingActivityId == activity.id
        let isClearing = clearingActivityId == activity.id
        let isLoading = isSaving || isResetting || isDeleting || isClearing
        let canDelete = true

        ZStack {
            SwipeableCard(
                slideButtons: canEdit ? buildSlideButtons(for: activity, isComplete: isComplete, canDelete: canDelete) : [],
                isSwipeEnabled: canEdit,
                onTap: {
                    guard !isLoading else { return }
                    NSLog("📋 Activity tapped - id: \(activity.id), type: \(activity.type.rawValue), title: \(activity.title ?? "nil"), helpTitle: \(activity.helpTitle ?? "nil")")
                    switch activity.type {
                    case .read, .userInput, .youtube, .exegesis:
                        editingActivityId = activity.id
                        DispatchQueue.main.async {
                            showEditActivity = true
                        }
                    default:
                        editingActivity = activity
                    }
                }
            ) {
                CardLessonActivity(
                    data: CardLessonActivityData(
                        id: activity.id,
                        title: activity.passageReference ?? activity.title.flatMap { $0.isEmpty ? nil : $0 } ?? (activity.type == .userInput ? "Write" : activity.type.displayName),
                        description: description,
                        type: activity.type == .userInput ? "Write" : (activity.title ?? activity.type.displayName),
                        rawActivityType: activity.type.rawValue,
                        imageStyle: .icon(
                            systemName: ActivityStyle.icon(for: activity.type),
                            backgroundColor: ActivityStyle.color(for: activity.type),
                            foregroundColor: ActivityStyle.iconColor(for: activity.type)
                        ),
                        status: isReady ? .confirmed : .new,
                        estimatedMinutes: activity.estimatedSeconds.map { max(1, Int(round(Double($0) / 60.0))) }
                    ),
                    size: .small,
                    showAnimatedBorder: !isReady
                )
            }

            if isLoading {
                CardSpinnerOverlay()
            }
        }
        .allowsHitTesting(!isLoading)
    }

    // MARK: - Video Activity Card

    @ViewBuilder
    private func videoActivityCard(for activity: StudyActivity) -> some View {
        let isReady = activity.isConfigured
        let isDeleting = deletingActivityId == activity.id
        let isUploading = savingActivityId == activity.id
        let isClearing = clearingActivityId == activity.id
        let isLoading = isDeleting || isUploading || isClearing
        let canDelete = true

        // Determine image style - use thumbnail if available, otherwise icon
        let imageStyle: CardImageStyle = {
            if let thumbnailUrl = activity.video?.thumbnailUrl {
                return .photo(imageURL: thumbnailUrl)
            } else {
                return .icon(
                    systemName: "play.fill",
                    backgroundColor: Color(hex: "#ef4444"),
                    foregroundColor: Color.white
                )
            }
        }()

        // Get video title or default
        let videoTitle = activity.video?.title ?? activity.title ?? activity.type.displayName
        let videoDescription: String? = isReady ? activity.video?.formattedDuration : "Select video"

        ZStack {
            SwipeableCard(
                slideButtons: canEdit ? {
                    var buttons: [SlideButton] = []
                    if activity.type == .video && activity.isConfigured {
                        buttons.append(SlideButton(icon: "eye", style: .reschedule) {
                            openVideoPreview(for: activity)
                        })
                        buttons.append(SlideButton(icon: "xmark.circle", style: .reschedule) {
                            activityToClear = activity
                            showClearConfirmation = true
                        })
                    }
                    if canDelete {
                        buttons.append(SlideButton(icon: "trash", style: .delete) {
                            activityToDelete = activity
                            showDeleteConfirmation = true
                        })
                    }
                    return buttons
                }() : [],
                isSwipeEnabled: canEdit,
                onTap: {
                    guard !isLoading else { return }
                    if activity.type == .video && activity.isConfigured {
                        previewingVideoActivity = activity
                    } else if canEdit {
                        // Non-creators can preview video but not pick a new one.
                        selectingVideoForActivity = activity
                    }
                }
            ) {
                CardLessonActivity(
                    data: CardLessonActivityData(
                        id: activity.id,
                        title: videoTitle,
                        description: videoDescription,
                        rawActivityType: activity.type.rawValue,
                        imageStyle: imageStyle,
                        status: isReady ? .confirmed : .new,
                        isVideo: true,
                        estimatedMinutes: activity.estimatedSeconds.map { max(1, Int(round(Double($0) / 60.0))) }
                    ),
                    size: .small,
                    showAnimatedBorder: !isReady
                )
            }

            if isLoading {
                CardSpinnerOverlay()
            }
        }
        .allowsHitTesting(!isLoading)
    }

    // MARK: - Slide Buttons Helper

    private func buildSlideButtons(for activity: StudyActivity, isComplete: Bool, canDelete: Bool) -> [SlideButton] {
        var buttons: [SlideButton] = []

        // Reset button for complete activities
        if isComplete {
            buttons.append(SlideButton(icon: "arrow.counterclockwise", style: .delete) {
                activityToReset = activity
                showResetConfirmation = true
            })
        }

        // Clear button for configured activities (resets to lesson template state)
        if activity.type != .userInput && activity.isConfigured {
            buttons.append(SlideButton(icon: "xmark.circle", style: .reschedule) {
                activityToClear = activity
                showClearConfirmation = true
            })
        }

        // Delete button for non-default activity types
        if canDelete {
            buttons.append(SlideButton(icon: "trash", style: .delete) {
                activityToDelete = activity
                showDeleteConfirmation = true
            })
        }

        return buttons
    }

    // MARK: - Inline Edit Helpers

    private func dismissEditActivity() {
        showEditActivity = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            editingActivityId = nil
        }
    }

    private func saveReadContent(title: String?) {
        // Blocks were already saved directly by EditReadActivityPage via ProgramActions,
        // which writes to AppState. The view auto-rerenders.
        dismissEditActivity()

        var updatedLesson = lesson
        updatedLesson.activities = activities
        onLessonUpdated(updatedLesson)
    }

    private func saveUserInputContent(title: String?, isHelpEnabled: Bool, helpTitle: String?, helpDescription: String?, placeholder: String?) {
        // The page saves directly via ProgramActions now (matches the read
        // activity flow). This handler is invoked only by the page's "Done"
        // tap, so here we just dismiss and notify the parent lesson view.
        dismissEditActivity()

        var updatedLesson = lesson
        updatedLesson.activities = activities
        onLessonUpdated(updatedLesson)
    }

    // MARK: - Lesson Title Update

    private func updateLessonTitle(_ newTitle: String) {
        lessonTitle = newTitle
        // Save immediately since this comes from the passage selection prompt
        saveLessonTitle()
    }

    private func saveLessonTitle() {
        guard !isSavingTitle else { return }
        // Dismiss keyboard immediately
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        isSavingTitle = true
        let newTitle = lessonTitle
        Task {
            do {
                try await ProgramActions().updateLessonTitle(
                    programId: programId,
                    lessonId: lesson.id,
                    title: newTitle
                )
                // Update AppState
                if var lessonCopy = AppState.shared.lessons[lesson.id] {
                    lessonCopy.title = newTitle.isEmpty ? nil : newTitle
                    AppState.shared.lessons.upsert(lessonCopy)
                }
                await MainActor.run {
                    originalLessonTitle = newTitle
                    isSavingTitle = false
                }
            } catch {
                NSLog("Failed to save lesson title: \(error)")
                await MainActor.run {
                    isSavingTitle = false
                }
            }
        }
    }

    // MARK: - Bible Reader Presentation

    private func presentBibleReaderForActivity(_ activity: StudyActivity) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Build used passages from other activities (for highlighting already-used passages)
        let usedPassages = lessonUsedPassages

        let overlay = BibleReaderOverlayView(
            overlayManager: OverlayManager(),
            onDismiss: {
                editingActivity = nil
            },
            onPassageConfirmed: { book, chapter, verseStart, verseEnd, selectedText in
                editingActivity = nil

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
                updateActivity(activity, with: passageData, highlightRange: highlightRange)
            },
            usedPassages: usedPassages
        )
        overlay.frame = window.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        overlay.presentFromBottom()
    }

    // MARK: - Update Activity

    private func updateActivity(_ activity: StudyActivity, with passageData: PassageData, highlightRange: HighlightRange) {
        savingActivityId = activity.id
        Task {
            do {
                _ = try await ProgramActions().updateActivity(
                    activityId: activity.id,
                    passageReference: passageData.reference,
                    passageData: passageData,
                    highlightRange: highlightRange
                )

                await MainActor.run {
                    savingActivityId = nil
                    editingActivity = nil
                }
            } catch {
                NSLog("Failed to update activity: \(error)")
                await MainActor.run {
                    savingActivityId = nil
                    editingActivity = nil
                }
            }
        }
    }

    // MARK: - Reset Activity

    private func resetActivity(_ activity: StudyActivity) {
        resettingActivityId = activity.id
        Task {
            do {
                _ = try await ProgramActions().resetActivity(activityId: activity.id)

                await MainActor.run {
                    resettingActivityId = nil

                    var updatedLesson = lesson
                    updatedLesson.activities = activities
                    onLessonUpdated(updatedLesson)
                }
            } catch {
                NSLog("Failed to reset activity: \(error)")
                await MainActor.run {
                    resettingActivityId = nil
                }
            }
        }
    }

    // MARK: - Clear Activity

    private func clearActivity(_ activity: StudyActivity) {
        // Set loading state immediately (visible app-wide via AppState)
        clearingActivityId = activity.id
        AppState.shared.loadingStates.setState(.loading, for: activity.id)

        Task {
            do {
                // Reset endpoint clears type-specific content (video, readContent, source references)
                _ = try await ProgramActions().resetActivity(activityId: activity.id)

                await MainActor.run {
                    clearingActivityId = nil
                    AppState.shared.loadingStates.clearState(for: activity.id)

                    var updatedLesson = lesson
                    updatedLesson.activities = activities
                    onLessonUpdated(updatedLesson)
                }
            } catch {
                NSLog("Failed to clear activity: \(error)")
                await MainActor.run {
                    clearingActivityId = nil
                    AppState.shared.loadingStates.clearState(for: activity.id)
                }
            }
        }
    }

    // MARK: - Add Activity

    private func addActivity(type: String) async {
        NSLog("🎬 EditDay.addActivity called with type: \(type)")

        guard let activityType = ActivityType(rawValue: type) else {
            NSLog("❌ Unknown activity type: \(type)")
            return
        }

        NSLog("🎬 Activity type parsed: \(activityType.rawValue)")

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                addingActivity = true
            }
        }

        NSLog("🎬 Calling API to add activity...")
        NSLog("🎬 programId: \(programId), lessonId: \(lesson.id)")

        do {
            let newActivity = try await ProgramActions().addActivity(
                programId: programId,
                lessonId: lesson.id,
                type: activityType
            )

            NSLog("✅ Activity added successfully: \(newActivity.id)")

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    addingActivity = false
                }

                // For EXEGESIS, jump straight into the dedicated editor (instead of the generic Bible picker).
                if activityType == .exegesis {
                    editingActivityId = newActivity.id
                    showEditActivity = true
                }

                // Notify parent of the change
                var updatedLesson = lesson
                updatedLesson.activities = activities
                onLessonUpdated(updatedLesson)
            }
        } catch {
            NSLog("❌ Failed to add activity: \(error)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    addingActivity = false
                }
            }
        }
    }

    // MARK: - Handle Video Selected

    private func handleVideoSelected(_ result: SelectedVideoResult, for activity: StudyActivity) {
        savingActivityId = activity.id
        selectingVideoForActivity = nil
        AppState.shared.loadingStates.setState(.loading, for: activity.id)

        Task {
            do {
                // Media library item — already uploaded, just link it
                if let mediaItem = result.mediaLibraryItem {
                    let videoId = mediaItem.video?.id ?? mediaItem.id
                    let videoUrl = mediaItem.video?.playbackUrl ?? mediaItem.url
                    NSLog("📹 Linking media library video \(videoId)...")
                    _ = try await ProgramActions().updateActivityVideo(
                        activityId: activity.id,
                        videoId: videoId,
                        videoUrl: videoUrl
                    )
                    NSLog("📹 Activity updated with media library video")

                    await MainActor.run {
                        savingActivityId = nil
                        selectingVideoForActivity = nil
                        AppState.shared.loadingStates.clearState(for: activity.id)
                        var updatedLesson = lesson
                        updatedLesson.activities = activities
                        onLessonUpdated(updatedLesson)
                    }
                    return
                }

                // Step 1: Get uploadable URL with correct orientation
                let videoURL: URL
                let needsCleanup: Bool
                if let recordedURL = result.recordedURL {
                    // Recorded video - export with orientation correction
                    NSLog("📹 Exporting recorded video with orientation fix...")
                    videoURL = try await VideoActions().exportVideoWithOrientation(from: recordedURL)
                    needsCleanup = true  // We created a new temp file
                    NSLog("📹 Exported to: \(videoURL)")
                } else if let asset = result.asset {
                    // Library video - export PHAsset to temp URL (includes orientation fix)
                    NSLog("📹 Exporting PHAsset to URL...")
                    videoURL = try await VideoActions().exportAssetToURL(asset)
                    needsCleanup = true
                    NSLog("📹 Exported to: \(videoURL)")
                } else {
                    throw VideoError.invalidResponse
                }

                // Step 2: Upload to Cloudflare and create video record
                NSLog("📹 Uploading video to Cloudflare...")
                let video = try await VideoActions().uploadAndCreateVideo(
                    from: videoURL,
                    title: "Day \(lesson.dayNumber) Video",
                    description: nil
                ) { progress in
                    NSLog("📹 Upload progress: \(progress.percentage)%")
                }
                NSLog("📹 Video uploaded successfully, ID: \(video.id)")

                // Step 3: Update activity with videoId and videoUrl via API
                NSLog("📹 Updating activity with videoId and videoUrl...")
                _ = try await ProgramActions().updateActivityVideo(
                    activityId: activity.id,
                    videoId: video.id,
                    videoUrl: video.playbackUrl
                )
                NSLog("📹 Activity updated successfully")

                await MainActor.run {
                    savingActivityId = nil
                    selectingVideoForActivity = nil
                    AppState.shared.loadingStates.clearState(for: activity.id)

                    // Notify parent of the change
                    var updatedLesson = lesson
                    updatedLesson.activities = activities
                    onLessonUpdated(updatedLesson)
                }

                // Step 4: Cleanup temp file
                if needsCleanup {
                    try? FileManager.default.removeItem(at: videoURL)
                    NSLog("📹 Cleaned up temp file")
                }

            } catch {
                NSLog("❌ Failed to upload video: \(error)")
                await MainActor.run {
                    savingActivityId = nil
                    selectingVideoForActivity = nil
                    AppState.shared.loadingStates.clearState(for: activity.id)
                }
            }
        }
    }

    // MARK: - Delete Activity

    private func deleteActivity(_ activity: StudyActivity) {
        deletingActivityId = activity.id
        Task {
            do {
                try await ProgramActions().deleteActivity(activityId: activity.id)

                await MainActor.run {
                    deletingActivityId = nil

                    // Notify parent of the change
                    var updatedLesson = lesson
                    updatedLesson.activities = activities
                    onLessonUpdated(updatedLesson)
                }
            } catch {
                NSLog("Failed to delete activity: \(error)")
                await MainActor.run {
                    deletingActivityId = nil
                }
            }
        }
    }

    // MARK: - Persist Reorder

    /// Persist reordered activities to server after Dragula drop
    private func persistActivityOrder() {
        // Notify parent of the change
        var updatedLesson = lesson
        updatedLesson.activities = activities
        onLessonUpdated(updatedLesson)

        // Persist to server
        let activityIds = activities.map { $0.id }
        Task {
            do {
                _ = try await ProgramActions().reorderActivities(
                    programId: programId,
                    lessonId: lesson.id,
                    activityIds: activityIds
                )
            } catch {
                NSLog("Failed to reorder activities: \(error)")
                // AppState retains the optimistic local order; a refresh will reconcile.
            }
        }
    }

    // MARK: - Preview Lesson

    /// Open the full member-lesson preview for this day, starting at the first
    /// step. Uses the authenticated `/preview/lesson/{id}` route — the same
    /// renderer the study overview drills into — so member lesson navigation
    /// (prev/next between activities) is present. Mirrors how
    /// ProgramHomePage.openStudyPreview opens the study overview.
    private func openPreview() {
        let urlString = "\(Configuration.clientBaseURL)/preview/lesson/\(lesson.id)"
        guard let url = URL(string: urlString) else { return }
        NSLog("👁️ LessonPreview: opening \(urlString)")
        previewLessonURL = IdentifiableURL(url: url)
    }

    private func openVideoPreview(for activity: StudyActivity) {
        previewingVideoActivityWeb = activity
    }
}

// MARK: - Lesson Preview Modal

struct LessonPreviewModal: View {
    let url: URL?
    @Binding var isPresented: Bool

    /// Incrementing this forces SwiftUI to replace the PreviewWebView entirely,
    /// which triggers a fresh page load — the simplest way to restart animations.
    @State private var reloadToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header bar: close (left) + replay (right)
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    reloadToken += 1
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Web view — id(reloadToken) forces full reconstruction on replay
            if let url = url {
                let _ = NSLog("👁️ LessonPreviewModal: rendering WebView for \(url.absoluteString)")
                LessonPreviewWebView(url: url)
                    .id(reloadToken)
            } else {
                let _ = NSLog("⚠️ LessonPreviewModal: url is nil, WebView not rendered")
                Text("No preview URL")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Lesson Preview Web View

struct LessonPreviewWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "appBackground")
        webView.scrollView.backgroundColor = UIColor(named: "appBackground")
        loadWithPreviewToken(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Request a preview token from the API, append it to the URL, and load.
    private func loadWithPreviewToken(into webView: WKWebView) {
        _ = Task {
            do {
                let token = try await PreviewWebView.fetchPreviewToken()
                let separator = url.absoluteString.contains("?") ? "&" : "?"
                let tokenURL = URL(string: "\(url.absoluteString)\(separator)preview_token=\(token)")!
                NSLog("👁️ LessonPreviewWebView: loading \(tokenURL.absoluteString)")
                _ = await MainActor.run {
                    webView.load(URLRequest(url: tokenURL))
                }
            } catch {
                NSLog("❌ LessonPreviewWebView: failed to get preview token — \(error.localizedDescription)")
                _ = await MainActor.run {
                    webView.load(URLRequest(url: url))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleLesson = Lesson(
        id: "preview-lesson",
        studyProgramId: "preview-program",
        dayNumber: 1,
        activities: [
            // Pending study activity (needs passage selection)
            StudyActivity(
                id: "activity-1",
                lessonId: "preview-lesson",
                type: .soap,
                status: .pending,
                orderNumber: 1,
                createdAt: Date(),
                updatedAt: Date(),
                videoId: nil,
                videoUrl: nil,
                video: nil,
                passageReference: nil,
                bookNumber: nil,
                bookName: nil,
                chapterStart: nil,
                chapterEnd: nil,
                verseStart: nil,
                verseEnd: nil,
                startElementId: nil,
                startOffset: nil,
                endElementId: nil,
                endOffset: nil
            ),
            // Complete study activity (has passage)
            StudyActivity(
                id: "activity-2",
                lessonId: "preview-lesson",
                type: .soap,
                status: .complete,
                orderNumber: 2,
                createdAt: Date(),
                updatedAt: Date(),
                videoId: nil,
                videoUrl: nil,
                video: nil,
                passageReference: "Romans 1:1-5",
                bookNumber: 45,
                bookName: "Romans",
                chapterStart: 1,
                chapterEnd: nil,
                verseStart: 1,
                verseEnd: 5,
                startElementId: "45-1-1",
                startOffset: 0,
                endElementId: "45-1-5",
                endOffset: 100
            ),
            // Pending video activity (needs video selection)
            StudyActivity(
                id: "activity-3",
                lessonId: "preview-lesson",
                type: .video,
                status: .pending,
                orderNumber: 3,
                createdAt: Date(),
                updatedAt: Date(),
                videoId: nil,
                videoUrl: nil,
                video: nil,
                passageReference: nil,
                bookNumber: nil,
                bookName: nil,
                chapterStart: nil,
                chapterEnd: nil,
                verseStart: nil,
                verseEnd: nil,
                startElementId: nil,
                startOffset: nil,
                endElementId: nil,
                endOffset: nil
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )

    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        EditDay(
            isPresented: .constant(true),
            programId: "preview-program-id",
            lesson: sampleLesson,
            onLessonUpdated: { _ in },
            onShowAddActivityMenu: nil
        )
    }
}
