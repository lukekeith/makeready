//
//  EnrollmentSchedulePage.swift
//  MakeReady
//
//  Page showing all scheduled lessons for an enrollment.
//  Displays lessons with MM/DD dates and activities.
//

import SwiftUI
import UIKit

struct EnrollmentSchedulePage: View {
    let enrollment: EnrollmentWithProgram
    let onDismiss: () -> Void
    var leftIcon: String = "chevron.left"  // "xmark" when presented as modal
    var overlayManager: OverlayManager? = nil  // For menu presentation
    var titleOverride: String? = nil  // Custom title (defaults to study program name)
    var previewDetails: EnrollmentDetails? = nil  // For previews only

    @State private var enrollmentDetails: EnrollmentDetails?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedLessonForInvite: LessonSchedule?
    @State private var selectedLessonForMenu: LessonSchedule?
    @State private var lessonToDelete: LessonSchedule?
    @State private var showDeleteConfirmation = false
    @State private var showAddLessonDialog = false
    @State private var isAddingLesson = false
    @State private var deletingScheduleId: String? = nil

    // Edit activities state — track by schedule id so the SlideStack detail
    // pane reads live data from enrollmentDetails.
    @State private var editingScheduleId: String? = nil

    // Study Sync settings pane (study-sync phase 6) — outer SlideStack detail.
    @State private var showSyncSettings = false

    /// True once the modal's open animation has finished. Gates swapping loaded
    /// content in: the network/local-server response can land mid-slide, and
    /// inserting the content branch then is a structural change that doesn't
    /// ride the slide-up — it appears at its final position and is clipped by
    /// the still-opening modal. The skeleton is rendered from frame 1 and rides
    /// the slide; real content swaps in cleanly once the modal is fully open.
    /// Only deferred when presented as a modal; pushed navigation shows
    /// immediately.
    @Environment(\.isModalRoot) private var isModalRoot
    @State private var readyToShowContent = false

    /// Group-completion analytics for this enrollment. Drives the per-activity
    /// fill opacity (fraction = completedCount / memberCount). Loaded in parallel
    /// with details; nil until loaded → cards fall back to empty outlined blocks.
    @State private var completionStats: EnrollmentCompletionStats?

    // Initialize from cache so the slide-in/modal-open animates with content
    // already laid out — async content arriving mid-flight is inserted outside
    // the animation transaction and lands at its final position (see
    // SWIFTUI_TRANSITIONS.md § Pre-loading Content). A warm cache also skips
    // the readyToShowContent skeleton gate: content that exists from frame 1
    // rides the animation, so there is no mid-flight swap to defer.
    init(
        enrollment: EnrollmentWithProgram,
        onDismiss: @escaping () -> Void,
        leftIcon: String = "chevron.left",
        overlayManager: OverlayManager? = nil,
        titleOverride: String? = nil,
        previewDetails: EnrollmentDetails? = nil
    ) {
        self.enrollment = enrollment
        self.onDismiss = onDismiss
        self.leftIcon = leftIcon
        self.overlayManager = overlayManager
        self.titleOverride = titleOverride
        self.previewDetails = previewDetails

        let cached = previewDetails ?? AppState.shared.enrollmentDetailsById[enrollment.id]
        _enrollmentDetails = State(initialValue: cached)
        _isLoading = State(initialValue: cached == nil)
        _readyToShowContent = State(initialValue: cached != nil)
    }

    var body: some View {
        // Canonical slider (Phase 3.4): SlideStack owns the two-step insertion,
        // the single animation driver, and the completion-tied unmount this page
        // previously hand-rolled with showEditActivities + a deferred flag flip.
        // Outer Bool-driven SlideStack pushes the Study Sync settings pane;
        // the inner item-driven one keeps the existing edit-day flow.
        SlideStack(isPresented: $showSyncSettings) {
            SlideStack(item: $editingScheduleId) {
                scheduleContent
            } detail: { scheduleId in
                editEnrollmentDayPane(scheduleId: scheduleId)
            }
        } detail: {
            EnrollmentSyncPage(
                enrollmentId: enrollment.id,
                onDismiss: { showSyncSettings = false },
                programName: enrollment.studyProgram?.name
            )
            .environment(\.isModalRoot, false)
        }
        .onAppear {
            // Hold the structure stable until the modal finishes opening so
            // loaded content rides the slide instead of popping in clipped.
            // (Appear spring is response 0.4; 0.5s covers the settle.)
            if isModalRoot {
                if !readyToShowContent {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        readyToShowContent = true
                    }
                }
            } else {
                readyToShowContent = true
            }
        }
        .background(Color.appBackground)
        .fullScreenCover(item: $selectedLessonForInvite) { schedule in
            StudyInvitePage(
                scheduleId: schedule.id,
                dayNumber: schedule.lesson.dayNumber,
                studyName: enrollment.studyProgram?.name ?? "Study",
                onDismiss: {
                    selectedLessonForInvite = nil
                },
                // Pass preview data when in preview mode
                previewData: previewDetails != nil ? LessonInviteData(
                    lessonScheduleId: schedule.id,
                    code: "PREVIEW",
                    inviteUrl: "\(Configuration.clientBaseURL)/join/study/\(schedule.id)",
                    qrCode: "",
                    dayNumber: schedule.lesson.dayNumber,
                    scheduledDate: ISO8601DateFormatter().string(from: schedule.scheduledDate),
                    passageReference: schedule.lesson.activities.first?.passageReference,
                    studyProgram: LessonInviteProgram(
                        id: enrollment.studyProgramId,
                        name: enrollment.studyProgram?.name ?? "Study",
                        days: enrollment.studyProgram?.days ?? 30,
                        coverImageUrl: enrollment.studyProgram?.coverImageUrl
                    ),
                    group: LessonInviteGroup(
                        id: enrollment.groupId,
                        name: "Preview Group",
                        code: "PREVIEW",
                        coverImageUrl: nil
                    )
                ) : nil
            )
        }
        .task {
            // Skip API call if preview data provided
            if let preview = previewDetails {
                enrollmentDetails = preview
                isLoading = false
                return
            }
            // Load schedule and completion analytics concurrently so fills are
            // ready when content appears.
            async let details: Void = loadEnrollmentDetails()
            async let stats: Void = loadCompletionStats()
            _ = await (details, stats)
        }
        .alert("Delete Lesson?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                lessonToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let schedule = lessonToDelete {
                    Task {
                        await performDeleteLesson(schedule)
                    }
                }
                lessonToDelete = nil
            }
        } message: {
            if let schedule = lessonToDelete {
                let studyName = enrollment.studyProgram?.name ?? "Study"
                Text("Are you sure you want to permanently delete Day \(schedule.lesson.dayNumber) of \(studyName) from the enrollment schedule?")
            }
        }
        .overlay {
            DialogOverlay(
                isPresented: $showAddLessonDialog,
                title: "Add a new lesson?",
                message: "This will add a new scheduled lesson to the end of the enrollment.",
                buttons: [
                    DialogButtonConfig(
                        isAddingLesson ? "Adding..." : "Add lesson",
                        style: .primary
                    ) {
                        addScheduledLesson()
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ]
            )
        }
    }

    // MARK: - Edit Enrollment Day (Screen 2)

    /// Inline edit pane for the schedule being edited. Built from the
    /// SlideStack-mounted id — NOT from editingScheduleId, which clears at
    /// dismissal while the pane is still sliding out. The schedule is looked
    /// up live so title edits in enrollmentDetails re-render the pane.
    @ViewBuilder
    private func editEnrollmentDayPane(scheduleId: String) -> some View {
        if let schedule = enrollmentDetails?.lessonSchedules.first(where: { $0.id == scheduleId }) {
            EditEnrollmentDay(
                isPresented: Binding(
                    get: { editingScheduleId != nil },
                    set: { if !$0 { editingScheduleId = nil } }
                ),
                schedule: schedule,
                enrollmentId: enrollment.id,
                onShowAddActivityMenu: { existingTypes, onSelect in
                    onShowAddActivityMenu(existingTypes: existingTypes, onSelect: onSelect)
                },
                onTitleChanged: { newTitle in
                    updateScheduleTitle(scheduleId: schedule.id, title: newTitle)
                }
            )
            .environment(\.isModalRoot, false)
        }
    }

    // MARK: - Schedule Content (Screen 1)

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            // Header — the trailing sync icon opens the Study Sync settings pane.
            PageTitle.iconTitleIcon(
                title: titleOverride ?? enrollment.studyProgram?.name ?? "Schedule",
                leftIcon: leftIcon,
                rightIcon: "arrow.triangle.2.circlepath",
                onLeftIconTap: { onDismiss() },
                onRightIconTap: { showSyncSettings = true }
            )

            if isLoading || !readyToShowContent {
                // Loading state (also shown until the modal finishes opening so
                // content doesn't swap in mid-slide and get clipped).
                SwipeableScrollView {
                    VStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { _ in
                            SkeletonCardLesson()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else if let error = error {
                // Error state
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(Typography.s40)
                        .foregroundColor(.white.opacity(0.3))

                    Text(error)
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task { await loadEnrollmentDetails() }
                    }
                    .foregroundColor(Color.brandPrimary)
                }
                .padding(32)
                Spacer()
            } else if let details = enrollmentDetails {
                // Content
                SwipeableScrollView {
                    VStack(spacing: 4) {
                        ForEach(details.lessonSchedules) { schedule in
                            let isDeleting = deletingScheduleId == schedule.id

                            SwipeableCard(
                                slideButtons: [
                                    SlideButton(icon: "square.and.arrow.up", style: .reschedule) {
                                        handleInviteTap(schedule)
                                    },
                                    SlideButton(icon: "calendar", style: .reschedule) {
                                        handleReschedule(schedule)
                                    },
                                    SlideButton(icon: "trash", style: .delete) {
                                        handleDeleteLesson(schedule)
                                    }
                                ],
                                onTap: {
                                    handleLessonTap(schedule)
                                }
                            ) {
                                CardLesson(data: cardLessonData(for: schedule))
                            }
                            .opacity(isDeleting ? 0 : 1)
                            .scaleEffect(y: isDeleting ? 0.01 : 1, anchor: .top)
                            .frame(maxHeight: isDeleting ? 0 : .infinity)
                            .clipped()
                            .allowsHitTesting(!isDeleting)
                        }

                        // Ghost card while adding
                        if isAddingLesson {
                            SkeletonCardLesson()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        BoxButton(
                            action: { showAddLessonDialog = true },
                            label: nil,
                            icon: "plus",
                            iconPosition: .right,
                            variant: .secondary,
                            style: .solid,
                            size: .lg,
                            fullWidth: true,
                            iconOpacity: 0.5
                        )
                        .opacity(isAddingLesson ? 0.5 : 1.0)
                        .disabled(isAddingLesson)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .animation(Motion.micro, value: isAddingLesson)
                }
            } else {
                // Empty state
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(Typography.s40)
                        .foregroundColor(.white.opacity(0.3))

                    Text("No lessons scheduled")
                        .font(Typography.s17Semibold)
                        .foregroundColor(.white)

                    Text("This enrollment doesn't have any lessons yet")
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                Spacer()
            }
        }
    }

    // MARK: - Data Loading

    private func loadEnrollmentDetails(showLoading: Bool = true) async {
        // Only show the skeleton when there's nothing cached to display —
        // flipping to the loading branch mid-slide swaps the content
        // subtree outside the animation transaction.
        if showLoading && enrollmentDetails == nil {
            isLoading = true
        }
        error = nil

        do {
            let details = try await EnrollmentActions().getEnrollmentDetails(id: enrollment.id)
            await MainActor.run {
                enrollmentDetails = details
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Keep showing cached content on a background refresh
                // failure; only surface the error screen when empty.
                // Console-only: load failure, never banner-surfaced.
                AppState.shared.recordError(error, context: "EnrollmentSchedulePage.loadEnrollmentDetails")
                if enrollmentDetails == nil {
                    self.error = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    /// Load group-completion analytics. Failures are non-fatal — the cards just
    /// fall back to empty outlined blocks until/unless stats are available.
    private func loadCompletionStats() async {
        do {
            let stats = try await EnrollmentActions().getEnrollmentCompletionStats(id: enrollment.id)
            await MainActor.run { completionStats = stats }
        } catch {
            // Console-only: background analytics load, cards fall back to empty.
            await MainActor.run {
                AppState.shared.recordError(error, context: "EnrollmentSchedulePage.loadCompletionStats")
            }
        }
    }

    // MARK: - Actions

    private func handleLessonTap(_ schedule: LessonSchedule) {
        NSLog("Tapped lesson: Day \(schedule.lesson.dayNumber) on \(schedule.scheduledDate)")
        selectedLessonForMenu = schedule

        overlayManager?.present(.lessonActionMenu) {
            LessonActionMenu(
                schedule: schedule,
                studyName: enrollment.studyProgram?.name ?? "Study",
                enrollmentId: enrollment.id,
                onEditActivities: {
                    editingScheduleId = schedule.id
                },
                onOpenLesson: {
                    handleOpenLesson(schedule)
                },
                onShareLesson: {
                    handleInviteTap(schedule)
                },
                onAddLesson: {
                    showAddLessonDialog = true
                },
                onDelete: {
                    handleDeleteLesson(schedule)
                }
            )
        }
    }

    private func onShowAddActivityMenu(existingTypes: [String], onSelect: @escaping (String) -> Void) {
        overlayManager?.present(.addActivityMenu) {
            AddActivityMenu(overlayManager: overlayManager!, existingActivityTypes: existingTypes, onActivitySelected: onSelect)
        }
    }

    private func handleInviteTap(_ schedule: LessonSchedule) {
        NSLog("Invite tapped for lesson: Day \(schedule.lesson.dayNumber)")
        selectedLessonForInvite = schedule
    }

    private func handleOpenLesson(_ schedule: LessonSchedule) {
        // Fetch the invite URL from the API and open it
        Task {
            do {
                let invite = try await EnrollmentActions().loadLessonInvite(scheduleId: schedule.id)
                if let url = URL(string: invite.inviteUrl) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                // User tapped "Open Lesson" in the action menu — retry
                // re-runs with the captured schedule.
                await MainActor.run {
                    AppState.shared.recordError(
                        error,
                        context: "EnrollmentSchedulePage.handleOpenLesson",
                        surface: true,
                        friendlyMessage: "Couldn't open the lesson",
                        retry: { handleOpenLesson(schedule) }
                    )
                }
            }
        }
    }

    private func handleShareLesson(_ schedule: LessonSchedule) {
        // Build the invite URL
        let studyName = enrollment.studyProgram?.name ?? "Study"
        let inviteURL = "\(Configuration.clientBaseURL)/join/study/\(schedule.id)"
        let shareText = "Join Day \(schedule.lesson.dayNumber) of \(studyName) on MakeReady: \(inviteURL)"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func handleReschedule(_ schedule: LessonSchedule) {
        NSLog("Reschedule tapped for lesson: Day \(schedule.lesson.dayNumber)")
        // TODO: Implement reschedule functionality
    }

    private func handleDeleteLesson(_ schedule: LessonSchedule) {
        lessonToDelete = schedule
        showDeleteConfirmation = true
    }

    private func performDeleteLesson(_ schedule: LessonSchedule) async {
        NSLog("Deleting lesson schedule: \(schedule.id)")

        do {
            try await EnrollmentActions().deleteLessonSchedule(
                enrollmentId: enrollment.id,
                scheduleId: schedule.id
            )

            // Animate the card out
            withAnimation(Motion.standard) {
                deletingScheduleId = schedule.id
            }

            // Wait for animation to finish, then refresh data
            try? await Task.sleep(nanoseconds: 350_000_000)
            deletingScheduleId = nil
            await loadEnrollmentDetails(showLoading: false)
        } catch {
            // User confirmed the delete dialog — retry re-runs with the
            // captured schedule.
            await MainActor.run {
                AppState.shared.recordError(
                    error,
                    context: "EnrollmentSchedulePage.performDeleteLesson",
                    surface: true,
                    friendlyMessage: "Couldn't delete the lesson",
                    retry: { Task { await performDeleteLesson(schedule) } }
                )
            }
        }
    }

    private func addScheduledLesson() {
        guard !isAddingLesson else { return }
        isAddingLesson = true

        Task {
            do {
                try await EnrollmentActions().addScheduledLesson(enrollmentId: enrollment.id)
                await loadEnrollmentDetails(showLoading: false)
            } catch {
                // User tapped "Add lesson" — retry re-runs the add (the
                // isAddingLesson guard has been cleared by then).
                await MainActor.run {
                    isAddingLesson = false
                    AppState.shared.recordError(
                        error,
                        context: "EnrollmentSchedulePage.addScheduledLesson",
                        surface: true,
                        friendlyMessage: "Couldn't add the lesson",
                        retry: { addScheduledLesson() }
                    )
                }
            }
            isAddingLesson = false
        }
    }

    // MARK: - Title Updates

    private func updateScheduleTitle(scheduleId: String, title: String) {
        guard let index = enrollmentDetails?.lessonSchedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        enrollmentDetails?.lessonSchedules[index].lesson.title = title
        // Keep the cache-first snapshot in sync so the next visit's first
        // frame doesn't flash the pre-edit title while the refresh lands.
        if let details = enrollmentDetails {
            AppState.shared.enrollmentDetailsById[enrollment.id] = details
        }
    }

    // MARK: - Card Data Mapping

    private func cardLessonData(for schedule: LessonSchedule) -> CardLessonData {
        // Per-activity completion counts for this lesson, keyed by scheduled
        // activity id. The fraction (completed / members) drives the fill opacity.
        let memberCount = completionStats?.memberCount ?? 0
        let lessonStat = completionStats?.lessons.first { $0.lessonScheduleId == schedule.id }
        let completedByActivity: [String: Int] = (lessonStat?.activities ?? [])
            .reduce(into: [:]) { $0[$1.scheduledActivityId] = $1.completedCount }

        // A lesson is "released" once its scheduled date is today or in the past,
        // which gives the card its brand (purple) background.
        let calendar = Calendar.current
        let isReleased = calendar.startOfDay(for: schedule.scheduledDate) <= calendar.startOfDay(for: Date())

        let activities = schedule.lesson.activities.sorted(by: { $0.orderNumber < $1.orderNumber }).map { activity -> LessonActivityData in
            let status: LessonActivityStatus
            if completionStats != nil, memberCount > 0 {
                let completed = completedByActivity[activity.id] ?? 0
                status = .percentComplete(Double(completed) / Double(memberCount))
            } else {
                // Stats not loaded yet (or no members) → empty outlined block.
                status = .incomplete
            }
            return LessonActivityData(
                icon: ActivityStyle.icon(forRawType: activity.type),
                type: activity.type,
                title: activity.title ?? activityTypeLabel(for: activity.type),
                status: status
            )
        }

        return CardLessonData(
            id: schedule.id,
            day: schedule.lesson.dayNumber,
            mode: .lesson,
            activities: activities,
            title: schedule.lesson.title,
            date: schedule.scheduledDate,
            estimatedMinutes: schedule.lesson.totalEstimatedMinutes,
            isReleased: isReleased
        )
    }

    private func activityTypeLabel(for type: String) -> String {
        switch type {
        case "READ": return "Read"
        case "VIDEO": return "Video"
        case "USER_INPUT": return "Response"
        default: return type.capitalized
        }
    }
}

#Preview {
    EnrollmentSchedulePagePreview()
}

/// Preview wrapper that provides OverlayManager for menu functionality
private struct EnrollmentSchedulePagePreview: View {
    @State private var overlayManager = OverlayManager()

    // Mock lesson schedules for preview
    // Days 1-2 are in the past (completed), day 3 is today, days 4-5 are future
    private var mockSchedules: [LessonSchedule] {
        (1...5).map { day in
            // Offset: day 1 = -2 days, day 2 = -1 day, day 3 = today, day 4 = +1, day 5 = +2
            let dayOffset = Double(day - 3)
            let scheduledDate = Date().addingTimeInterval(dayOffset * 24 * 60 * 60)
            let isInPast = dayOffset < 0

            return LessonSchedule(
                id: "ls\(day)",
                enrollmentId: "1",
                lessonId: "l\(day)",
                scheduledDate: scheduledDate,
                isCompleted: isInPast,
                completedAt: isInPast ? scheduledDate : nil,
                lesson: LessonWithActivities(
                    id: "l\(day)",
                    studyProgramId: "p1",
                    dayNumber: day,
                    title: "SOAP",
                    createdAt: Date(),
                    updatedAt: Date(),
                    activities: [
                        ScheduledActivity(id: "a\(day)a", lessonId: "l\(day)", type: "READ", title: "Read", orderNumber: 1),
                        ScheduledActivity(id: "a\(day)b", lessonId: "l\(day)", type: "USER_INPUT", title: "Observe", orderNumber: 2),
                        ScheduledActivity(id: "a\(day)c", lessonId: "l\(day)", type: "USER_INPUT", title: "Application", orderNumber: 3),
                        ScheduledActivity(id: "a\(day)d", lessonId: "l\(day)", type: "USER_INPUT", title: "Prayer", orderNumber: 4)
                    ]
                )
            )
        }
    }

    private var mockEnrollment: EnrollmentWithProgram {
        EnrollmentWithProgram(
            id: "1",
            groupId: "g1",
            studyProgramId: "p1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            enabledDays: "[\"Mon\",\"Tue\",\"Wed\",\"Thu\",\"Fri\"]",
            smsTime: "09:00",
            timezone: "America/Chicago",
            requireResponse: false,
            createdAt: Date(),
            updatedAt: Date(),
            studyProgram: StudyProgramSummary(
                id: "p1",
                name: "Foundation",
                description: "30-day foundation study",
                days: 30,
                coverImageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=600"
            )
        )
    }

    private var mockEnrollmentDetails: EnrollmentDetails {
        EnrollmentDetails(
            id: "1",
            groupId: "g1",
            studyProgramId: "p1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            enabledDays: "[\"Mon\",\"Tue\",\"Wed\",\"Thu\",\"Fri\"]",
            smsTime: "09:00",
            timezone: "America/Chicago",
            requireResponse: false,
            createdAt: Date(),
            updatedAt: Date(),
            studyProgram: StudyProgramSummary(
                id: "p1",
                name: "Foundation",
                description: "30-day foundation study",
                days: 30,
                coverImageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=600"
            ),
            lessonSchedules: mockSchedules
        )
    }

    var body: some View {
        ZStack {
            EnrollmentSchedulePage(
                enrollment: mockEnrollment,
                onDismiss: { print("Dismissed") },
                overlayManager: overlayManager,
                previewDetails: mockEnrollmentDetails
            )

            // Render overlays on top
            ForEach(overlayManager.sortedOverlays) { item in
                item.content
            }
        }
        .environment(overlayManager)
    }
}
