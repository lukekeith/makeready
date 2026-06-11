//
//  EditEnrollmentDay.swift
//  MakeReady
//
//  Edit scheduled activities for a specific day in an enrollment.
//  Modeled on EditDay.swift but operates on ScheduledActivity objects.
//

import SwiftUI

struct EditEnrollmentDay: View {
    @Binding var isPresented: Bool
    let schedule: LessonSchedule
    let enrollmentId: String
    let onShowAddActivityMenu: (([String], @escaping (String) -> Void) -> Void)?
    var onTitleChanged: ((String) -> Void)? = nil

    // Navigation state — track the activity being edited by id so we read live
    // data from AppState instead of holding a stale snapshot.
    @State private var editingActivityId: String? = nil

    /// Live activity list, read directly from AppState. Mutations go through
    /// EnrollmentActions which upsert into the same store, so this view re-renders
    /// the moment any verse/block/order changes anywhere in the app.
    private var activities: [ScheduledActivity] {
        AppState.shared.scheduledActivitiesFor(lessonId: schedule.lesson.id)
    }

    /// Writable binding for Dragula reorder. Reads live from the lesson
    /// aggregate; writes apply the new orderNumber to each activity inside
    /// the lesson and upsert the whole lesson — one observable change.
    private var activitiesBinding: Binding<[ScheduledActivity]> {
        Binding(
            get: { self.activities },
            set: { newValue in
                let lessonId = schedule.lesson.id
                guard var lesson = AppState.shared.scheduledLessons[lessonId] else { return }
                var byId = Dictionary(uniqueKeysWithValues: lesson.activities.map { ($0.id, $0) })
                var reordered: [ScheduledActivity] = []
                for (i, activity) in newValue.enumerated() {
                    if var a = byId[activity.id] {
                        a.orderNumber = i + 1
                        byId[activity.id] = a
                        reordered.append(a)
                    }
                }
                lesson.activities = reordered
                AppState.shared.scheduledLessons.upsert(lesson)
            }
        )
    }

    // Delete confirmation state
    @State private var activityToDelete: ScheduledActivity? = nil
    @State private var showDeleteConfirmation = false

    // Clear confirmation state
    @State private var activityToClear: ScheduledActivity? = nil
    @State private var showClearConfirmation = false

    // Video selection state
    @State private var selectingVideoForActivity: ScheduledActivity? = nil
    @State private var previewingVideoActivity: ScheduledActivity? = nil

    // Preview state (shared across all activity types)
    @State private var showPreviewModal = false
    @State private var previewActivityId: String? = nil

    /// The study program ID this enrollment is based on — used for preview token generation.
    private var programId: String? {
        schedule.lesson.studyProgramId.isEmpty ? nil : schedule.lesson.studyProgramId
    }

    // Loading states for inline spinners
    @State private var savingActivityId: String? = nil
    @State private var deletingActivityId: String? = nil
    @State private var addingActivity = false
    @State private var clearingActivityId: String? = nil

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Lesson title state
    @State private var lessonTitle: String = ""
    @State private var originalLessonTitle: String = ""
    @State private var isSavingTitle = false


    private var hasTitleChanges: Bool {
        lessonTitle != originalLessonTitle
    }

    /// All passages used anywhere in this enrollment lesson, read live from
    /// AppState. Used for the Bible reader's "already used" highlights.
    private var lessonUsedPassages: [PassageData] {
        AppState.shared.passagesUsedIn(lessonId: schedule.lesson.id, context: .enrollment)
    }

    private var totalPassageCount: Int { lessonUsedPassages.count }

    private var passageCountsByBook: [String: Int] {
        var counts: [String: Int] = [:]
        for passage in lessonUsedPassages {
            counts[passage.bookName, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        // Canonical slider (Phase 3.4): SlideStack owns the two-step insertion,
        // the single animation driver, and the completion-tied unmount this page
        // previously hand-rolled with showEditActivity + an asyncAfter(0.35) wait.
        SlideStack(item: $editingActivityId) {
            dayContent
        } detail: { activityId in
            inlineEditPane(activityId: activityId)
        }
        .onAppear {
            let title = schedule.lesson.title ?? ""
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
        .fullScreenCover(item: $previewingVideoActivity) { activity in
            VideoActivityManager(
                videoUrl: activity.videoUrl ?? activity.video?.playbackUrl ?? AppState.shared.videos[activity.videoId ?? ""]?.playbackUrl ?? "",
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
                    let activityId = activity.id
                    Task {
                        do {
                            _ = try await EnrollmentActions().removeScheduledActivityVideo(activityId: activityId)
                        } catch {
                            NSLog("❌ Failed to remove video: \(error)")
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showPreviewModal) {
            if let activityId = previewActivityId {
                ReadActivityPreviewModal(activityId: activityId, isPresented: $showPreviewModal)
            }
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
    }

    // MARK: - Day Content (Screen 1)

    private var dayContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: switches between back and Cancel/Save based on title edits
                if hasTitleChanges {
                    PageTitle.linkTitleLink(
                        title: "Day \(schedule.lesson.dayNumber)",
                        leftLink: "Cancel",
                        rightLink: isSavingTitle ? "Saving..." : "Save",
                        rightLinkColor: isSavingTitle ? .white.opacity(0.3) : nil,
                        onLeftLinkTap: {
                            lessonTitle = originalLessonTitle
                        },
                        onRightLinkTap: {
                            guard !isSavingTitle else { return }
                            saveLessonTitle()
                        }
                    )
                } else {
                    PageTitle.iconTitleLink(
                        title: "Day \(schedule.lesson.dayNumber)",
                        leftIcon: "xmark",
                        rightLink: "Done",
                        onLeftIconTap: {
                            isPresented = false
                        },
                        onRightLinkTap: {
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

                // Scrollable content
                ScrollView {
                    VStack(spacing: 4) {
                        DragulaView(items: activitiesBinding) { activity in
                            activityCard(for: activity)
                        } dropView: { _ in
                            ReorderDropIndicator()
                        } dropCompleted: {
                            persistActivityOrder()
                        }

                        // Show skeleton card while adding new activity
                        if addingActivity {
                            SkeletonCardStudy()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Add activity button
                        Spacer().frame(height: 12)
                        BoxButton(
                            action: {
                                guard !addingActivity else { return }
                                let existingTypes = activities.map { $0.type }
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
    private func activityCard(for activity: ScheduledActivity) -> some View {
        if activity.type == "VIDEO" {
            videoActivityCard(for: activity)
        } else {
            studyActivityCard(for: activity)
        }
    }

    // MARK: - Study Activity Card

    @ViewBuilder
    private func studyActivityCard(for activity: ScheduledActivity) -> some View {
        let isReady = activity.isConfigured
        let pendingLabel = activity.type == "READ" ? "Provide text to read" : "Configure activity"
        let description: String = {
            guard isReady else { return pendingLabel }
            if activity.type == "READ", let summary = readBlockSummary(for: activity) {
                return summary
            }
            return activity.passageReference ?? activity.title ?? activityDisplayName(for: activity.type)
        }()
        let isSaving = savingActivityId == activity.id
        let isDeleting = deletingActivityId == activity.id
        let isClearing = clearingActivityId == activity.id
        let isLoading = isSaving || isDeleting || isClearing

        ZStack {
            SwipeableCard(
                slideButtons: buildSlideButtons(for: activity),
                onTap: {
                    guard !isLoading else { return }
                    switch activity.type {
                    case "READ", "USER_INPUT":
                        editingActivityId = activity.id
                    default:
                        break
                    }
                }
            ) {
                CardLessonActivity(
                    data: CardLessonActivityData(
                        id: activity.id,
                        title: activity.passageReference ?? activity.title ?? activityDisplayName(for: activity.type),
                        description: description,
                        type: activity.title ?? activityDisplayName(for: activity.type),
                        rawActivityType: activity.type,
                        imageStyle: .icon(
                            systemName: ActivityStyle.icon(forRawType: activity.type),
                            backgroundColor: ActivityStyle.color(forRawType: activity.type),
                            foregroundColor: ActivityStyle.iconColor(forRawType: activity.type)
                        ),
                        status: isReady ? .confirmed : .new
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
    private func videoActivityCard(for activity: ScheduledActivity) -> some View {
        let isReady = activity.isConfigured
        let isDeleting = deletingActivityId == activity.id
        let isClearing = clearingActivityId == activity.id
        let isLoading = isDeleting || isClearing

        ZStack {
            SwipeableCard(
                slideButtons: buildSlideButtons(for: activity),
                onTap: {
                    guard !isLoading else { return }
                    if activity.isConfigured {
                        previewingVideoActivity = activity
                    } else {
                        selectingVideoForActivity = activity
                    }
                }
            ) {
                CardLessonActivity(
                    data: CardLessonActivityData(
                        id: activity.id,
                        title: activity.title ?? "Video",
                        description: isReady ? "Video selected" : "Select video",
                        type: "Video",
                        rawActivityType: activity.type,
                        imageStyle: .icon(
                            systemName: ActivityStyle.icon(forRawType: activity.type),
                            backgroundColor: ActivityStyle.color(forRawType: activity.type),
                            foregroundColor: ActivityStyle.iconColor(forRawType: activity.type)
                        ),
                        status: isReady ? .confirmed : .new,
                        isVideo: true
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

    // MARK: - Slide Buttons

    private func buildSlideButtons(for activity: ScheduledActivity) -> [SlideButton] {
        var buttons: [SlideButton] = []

        // Preview button for configured video activities
        if activity.type == "VIDEO" && activity.isConfigured {
            buttons.append(SlideButton(icon: "eye", style: .reschedule) {
                openPreview(for: activity)
            })
        }

        // Clear button for configured activities
        if activity.isConfigured {
            buttons.append(SlideButton(icon: "xmark.circle", style: .reschedule) {
                activityToClear = activity
                showClearConfirmation = true
            })
        }

        // Delete button
        buttons.append(SlideButton(icon: "trash", style: .delete) {
            activityToDelete = activity
            showDeleteConfirmation = true
        })

        return buttons
    }

    // MARK: - Inline Edit View (Screen 2)

    /// Inline edit pane for the activity being edited. Built from the
    /// SlideStack-mounted id — NOT from editingActivityId, which clears at
    /// dismissal while the pane is still sliding out.
    @ViewBuilder
    private func inlineEditPane(activityId: String) -> some View {
        if let activity = activities.first(where: { $0.id == activityId }) {
            editActivityView(activity: activity)
        }
    }

    @ViewBuilder
    private func editActivityView(activity: ScheduledActivity) -> some View {
        switch activity.type {
        case "READ":
            EditReadActivityPage(
                activity: activity.toStudyActivity(),
                lessonId: schedule.lesson.id,
                programId: programId,
                passageCount: totalPassageCount,
                passageCountsByBook: passageCountsByBook,
                currentLessonTitle: lessonTitle,
                lessonActivityCount: activities.count,
                onCancel: dismissEditActivity,
                onSave: { _ in
                    // EnrollmentActions has already updated AppState; nothing to mirror.
                    dismissEditActivity()
                },
                onBlocksChanged: { _ in
                    // EnrollmentActions has already updated AppState.
                },
                actions: .enrollment
            )
        case "USER_INPUT":
            EditScheduledUserInputView(
                activity: activity,
                programId: programId,
                onCancel: dismissEditActivity,
                onSave: { title, isHelpEnabled, helpTitle, helpDescription in
                    saveUserInputContent(
                        activity: activity,
                        title: title,
                        isHelpEnabled: isHelpEnabled,
                        helpTitle: helpTitle,
                        helpDescription: helpDescription
                    )
                }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Lesson Title Save

    private func saveLessonTitle() {
        guard !isSavingTitle else { return }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        isSavingTitle = true
        let newTitle = lessonTitle
        Task {
            do {
                try await EnrollmentActions().updateScheduleTitle(
                    enrollmentId: enrollmentId,
                    scheduleId: schedule.id,
                    title: newTitle
                )
                await MainActor.run {
                    originalLessonTitle = newTitle
                    onTitleChanged?(newTitle)
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

    // MARK: - Inline Edit Helpers

    private func dismissEditActivity() {
        editingActivityId = nil
    }

    private func saveUserInputContent(activity: ScheduledActivity, title: String?, isHelpEnabled: Bool, helpTitle: String?, helpDescription: String?) {
        savingActivityId = activity.id

        Task {
            do {
                // First toggle help if changed
                let updatedActivity = try await EnrollmentActions().toggleScheduledActivityHelp(
                    activityId: activity.id,
                    isHelpEnabled: isHelpEnabled
                )

                // Then update content (stub - will fail until endpoint exists)
                _ = try? await EnrollmentActions().updateScheduledActivity(
                    activityId: activity.id,
                    title: title,
                    helpTitle: helpTitle,
                    helpDescription: helpDescription
                )

                _ = updatedActivity  // already upserted to AppState by EnrollmentActions
                await MainActor.run {
                    savingActivityId = nil
                    dismissEditActivity()
                }
            } catch {
                NSLog("Failed to update scheduled activity: \(error)")
                await MainActor.run {
                    savingActivityId = nil
                    dismissEditActivity()
                }
            }
        }
    }

    // MARK: - Delete Activity

    private func deleteActivity(_ activity: ScheduledActivity) {
        deletingActivityId = activity.id
        Task {
            do {
                try await EnrollmentActions().deleteScheduledActivity(
                    enrollmentId: enrollmentId,
                    scheduleId: schedule.id,
                    activityId: activity.id
                )

                await MainActor.run {
                    // EnrollmentActions has already removed the activity from AppState.
                    deletingActivityId = nil
                }
            } catch {
                NSLog("Failed to delete scheduled activity: \(error)")
                await MainActor.run {
                    deletingActivityId = nil
                }
            }
        }
    }

    // MARK: - Clear Activity

    private func clearActivity(_ activity: ScheduledActivity) {
        clearingActivityId = activity.id
        Task {
            do {
                _ = try await EnrollmentActions().clearScheduledActivity(
                    activityId: activity.id
                )

                await MainActor.run {
                    // EnrollmentActions has already updated AppState.
                    clearingActivityId = nil
                }
            } catch {
                NSLog("Failed to clear scheduled activity: \(error)")
                await MainActor.run {
                    clearingActivityId = nil
                }
            }
        }
    }

    // MARK: - Add Activity

    private func addActivity(type: String) async {
        await MainActor.run {
            withAnimation(Motion.micro) {
                addingActivity = true
            }
        }

        do {
            _ = try await EnrollmentActions().addScheduledActivity(
                enrollmentId: enrollmentId,
                scheduleId: schedule.id,
                type: type
            )

            await MainActor.run {
                withAnimation(Motion.standardBrisk) {
                    // EnrollmentActions has already appended to AppState.
                    addingActivity = false
                }
            }
        } catch {
            NSLog("Failed to add scheduled activity: \(error)")
            await MainActor.run {
                withAnimation(Motion.micro) {
                    addingActivity = false
                }
            }
        }
    }

    // MARK: - Handle Video Selected

    private func handleVideoSelected(_ result: SelectedVideoResult, for activity: ScheduledActivity) {
        savingActivityId = activity.id
        selectingVideoForActivity = nil

        Task {
            do {
                // Media library item — already uploaded, just link it
                if let mediaItem = result.mediaLibraryItem {
                    let videoId = mediaItem.video?.id ?? mediaItem.id
                    let videoUrl = mediaItem.video?.playbackUrl ?? mediaItem.url
                    NSLog("📹 Linking media library video \(videoId) to scheduled activity...")
                    _ = try await EnrollmentActions().updateScheduledActivityVideo(
                        activityId: activity.id,
                        videoId: videoId,
                        videoUrl: videoUrl
                    )
                    NSLog("📹 Scheduled activity updated with media library video")
                    await MainActor.run { savingActivityId = nil }
                    return
                }

                // Get uploadable URL with correct orientation
                let videoURL: URL
                let needsCleanup: Bool
                if let recordedURL = result.recordedURL {
                    NSLog("📹 Exporting recorded video with orientation fix...")
                    videoURL = try await VideoActions().exportVideoWithOrientation(from: recordedURL)
                    needsCleanup = true
                } else if let asset = result.asset {
                    NSLog("📹 Exporting PHAsset to URL...")
                    videoURL = try await VideoActions().exportAssetToURL(asset)
                    needsCleanup = true
                } else {
                    throw VideoError.invalidResponse
                }

                // Upload to Cloudflare and create video record
                NSLog("📹 Uploading video to Cloudflare...")
                let video = try await VideoActions().uploadAndCreateVideo(
                    from: videoURL,
                    title: "Day \(schedule.lesson.dayNumber) Video",
                    description: nil
                ) { progress in
                    NSLog("📹 Upload progress: \(progress.percentage)%")
                }
                NSLog("📹 Video uploaded successfully, ID: \(video.id)")

                // Update scheduled activity with videoId and videoUrl
                _ = try await EnrollmentActions().updateScheduledActivityVideo(
                    activityId: activity.id,
                    videoId: video.id,
                    videoUrl: video.playbackUrl
                )
                NSLog("📹 Scheduled activity updated successfully")

                await MainActor.run { savingActivityId = nil }

                if needsCleanup {
                    try? FileManager.default.removeItem(at: videoURL)
                }

            } catch {
                NSLog("❌ Failed to upload video for scheduled activity: \(error)")
                await MainActor.run { savingActivityId = nil }
            }
        }
    }

    // MARK: - Preview

    private func openPreview(for activity: ScheduledActivity) {
        previewActivityId = activity.id
        showPreviewModal = true
    }

    // MARK: - Persist Reorder

    private func persistActivityOrder() {
        let activityIds = activities.map { $0.id }
        Task {
            do {
                try await EnrollmentActions().reorderScheduledActivities(
                    enrollmentId: enrollmentId,
                    scheduleId: schedule.id,
                    activityIds: activityIds
                )
            } catch {
                NSLog("Failed to reorder scheduled activities: \(error)")
                // Refetch enrollment details to restore the canonical order in AppState.
                _ = try? await EnrollmentActions().getEnrollmentDetails(id: enrollmentId)
            }
        }
    }

    // MARK: - Read Block Summary

    private func readBlockSummary(for activity: ScheduledActivity) -> String? {
        guard let block = activity.readBlocks?.sorted(by: { $0.orderNumber < $1.orderNumber }).first,
              let content = block.content, !content.isEmpty else { return nil }
        if let title = block.title, !title.isEmpty {
            return "\(title)\n\(content)"
        }
        return content
    }

    // MARK: - Display Name Helper

    private func activityDisplayName(for type: String) -> String {
        switch type {
        case "READ": return "Read"
        case "USER_INPUT": return "Response"
        case "VIDEO": return "Video"
        default: return type
        }
    }
}

// MARK: - Inline Edit: READ Activity

private struct EditScheduledReadView: View {
    let activity: ScheduledActivity
    let onCancel: () -> Void
    let onSave: (String?) -> Void

    @State private var title: String = ""

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitleLink(
                    title: "Edit Activity",
                    leftIcon: "chevron.left",
                    rightLink: "Done",
                    onLeftIconTap: onCancel,
                    onRightLinkTap: { onSave(title.isEmpty ? nil : title) }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        // Title field
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Activity title",
                                text: $title
                            )
                        }
                        .padding(.horizontal, 16)

                        // Read content (read-only display)
                        if let readContent = activity.readContent, !readContent.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Content")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)

                                Text(readContent)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Passage reference (if any)
                        if let passage = activity.passageReference, !passage.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Passage")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)

                                Text(passage)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            title = activity.title ?? ""
        }
    }
}

// MARK: - Inline Edit: USER_INPUT Activity

private struct EditScheduledUserInputView: View {
    let activity: ScheduledActivity
    let programId: String?
    let onCancel: () -> Void
    let onSave: (String?, Bool, String?, String?) -> Void

    @State private var title: String = ""
    @State private var isHelpEnabled: Bool = false
    @State private var helpTitle: String = ""
    @State private var helpDescription: String = ""

    // Preview state
    @State private var showPreviewModal = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitleLink(
                    title: "Edit Activity",
                    leftIcon: "chevron.left",
                    rightLink: "Save",
                    onLeftIconTap: onCancel,
                    onRightLinkTap: {
                        onSave(
                            title.isEmpty ? nil : title,
                            isHelpEnabled,
                            helpTitle.isEmpty ? nil : helpTitle,
                            helpDescription.isEmpty ? nil : helpDescription
                        )
                    }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        // Title field
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Activity title",
                                text: $title
                            )
                        }
                        .padding(.horizontal, 16)

                        // Help toggle
                        ToggleGroup {
                            ToggleControl(
                                title: "Show help",
                                description: "Display a help section for this activity",
                                isOn: $isHelpEnabled
                            )
                        }
                        .padding(.horizontal, 16)

                        // Help fields (shown when help is enabled)
                        if isHelpEnabled {
                            FieldGroup {
                                TextInput(
                                    floatingLabel: "Help title",
                                    autocorrect: true,
                                    text: $helpTitle
                                )
                            }
                            .padding(.horizontal, 16)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Help description")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)

                                MultilineTextInput(
                                    placeholder: "Help description",
                                    text: $helpDescription
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        // Preview button
                        if programId != nil {
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
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 16)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .fullScreenCover(isPresented: $showPreviewModal) {
            ReadActivityPreviewModal(activityId: activity.id, isPresented: $showPreviewModal)
        }
        .onAppear {
            title = activity.title ?? ""
            isHelpEnabled = activity.helpTitle != nil || activity.helpDescription != nil
            helpTitle = activity.helpTitle ?? ""
            helpDescription = activity.helpDescription ?? ""
        }
    }

    private func openPreview() {
        showPreviewModal = true
    }
}

// MARK: - Preview

#Preview {
    EditEnrollmentDay(
        isPresented: .constant(true),
        schedule: LessonSchedule(
            id: "ls1",
            enrollmentId: "e1",
            lessonId: "l1",
            scheduledDate: Date(),
            isCompleted: nil,
            completedAt: nil,
            lesson: LessonWithActivities(
                id: "l1",
                studyProgramId: "p1",
                dayNumber: 3,
                createdAt: Date(),
                updatedAt: Date(),
                activities: [
                    ScheduledActivity(
                        id: "a1",
                        lessonId: "l1",
                        type: "READ",
                        title: "Daily Reading",
                        readContent: "Today we explore the meaning of grace in everyday life.",
                        passageReference: "Ephesians 2:8-9",
                        orderNumber: 1
                    ),
                    ScheduledActivity(
                        id: "a2",
                        lessonId: "l1",
                        type: "USER_INPUT",
                        title: "Reflection",
                        helpTitle: "How to reflect",
                        helpDescription: "Take a moment to consider how this applies to your life.",
                        orderNumber: 2
                    ),
                    ScheduledActivity(
                        id: "a3",
                        lessonId: "l1",
                        type: "VIDEO",
                        title: "Teaching Video",
                        orderNumber: 3
                    )
                ]
            )
        ),
        enrollmentId: "e1",
        onShowAddActivityMenu: nil
    )
}
