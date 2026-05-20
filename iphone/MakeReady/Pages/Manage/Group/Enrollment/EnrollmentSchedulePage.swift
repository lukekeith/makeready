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

    // Edit activities state
    @State private var editingSchedule: LessonSchedule? = nil
    @State private var showEditActivities = false

    @State private var cachedWidth: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let width = cachedWidth ?? geometry.size.width
            HStack(spacing: 0) {
                // Screen 1: Lesson list
                scheduleContent
                    .frame(width: width)

                // Screen 2: Edit enrollment day
                ZStack {
                    if let schedule = editingSchedule {
                        EditEnrollmentDay(
                            isPresented: $showEditActivities,
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
                        .id(schedule.id)
                    }
                }
                .frame(width: width)
            }
            .offset(x: showEditActivities ? -width : 0)
            .animation(.easeInOut(duration: 0.3), value: showEditActivities)
            .onAppear {
                if cachedWidth == nil {
                    cachedWidth = geometry.size.width
                }
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
                    inviteUrl: "https://app.makeready.org/join/study/\(schedule.id)",
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
            await loadEnrollmentDetails()
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

    // MARK: - Schedule Content (Screen 1)

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            // Header
            PageTitle.iconTitle(
                title: titleOverride ?? enrollment.studyProgram?.name ?? "Schedule",
                icon: leftIcon,
                onIconTap: { onDismiss() }
            )

            if isLoading {
                // Loading state
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
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task { await loadEnrollmentDetails() }
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
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
                    .animation(.easeInOut(duration: 0.2), value: isAddingLesson)
                }
            } else {
                // Empty state
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No lessons scheduled")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text("This enrollment doesn't have any lessons yet")
                        .font(.system(size: 15))
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
        if showLoading {
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
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Actions

    private func handleLessonTap(_ schedule: LessonSchedule) {
        NSLog("Tapped lesson: Day \(schedule.lesson.dayNumber) on \(schedule.scheduledDate)")
        selectedLessonForMenu = schedule

        overlayManager?.presentMenu(id: OverlayID.lessonActionMenu) {
            LessonActionMenu(
                schedule: schedule,
                studyName: enrollment.studyProgram?.name ?? "Study",
                enrollmentId: enrollment.id,
                onEditActivities: {
                    editingSchedule = schedule
                    DispatchQueue.main.async {
                        showEditActivities = true
                    }
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
        overlayManager?.present(id: OverlayID.addActivityMenu, priority: .topLevel) {
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
                let response = try await APIClient.shared.get(
                    "/api/lesson-schedules/\(schedule.id)/invite",
                    responseType: LessonInviteResponse.self
                )

                if let invite = response.invite, let url = URL(string: invite.inviteUrl) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                } else {
                    NSLog("Failed to get invite URL: \(response.error ?? "Unknown error")")
                }
            } catch {
                NSLog("Failed to fetch lesson invite: \(error)")
            }
        }
    }

    private func handleShareLesson(_ schedule: LessonSchedule) {
        // Build the invite URL
        let studyName = enrollment.studyProgram?.name ?? "Study"
        let inviteURL = "https://app.makeready.org/join/study/\(schedule.id)"
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
            withAnimation(.easeInOut(duration: 0.3)) {
                deletingScheduleId = schedule.id
            }

            // Wait for animation to finish, then refresh data
            try? await Task.sleep(nanoseconds: 350_000_000)
            deletingScheduleId = nil
            await loadEnrollmentDetails(showLoading: false)
        } catch {
            NSLog("Failed to delete lesson schedule: \(error)")
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
                NSLog("Failed to add scheduled lesson: \(error)")
            }
            isAddingLesson = false
        }
    }

    // MARK: - Title Updates

    private func updateScheduleTitle(scheduleId: String, title: String) {
        guard let index = enrollmentDetails?.lessonSchedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        enrollmentDetails?.lessonSchedules[index].lesson.title = title
    }

    // MARK: - Card Data Mapping

    private func cardLessonData(for schedule: LessonSchedule) -> CardLessonData {
        let isCompleted = schedule.isCompleted == true || schedule.scheduledDate < Date()

        let activities = schedule.lesson.activities.sorted(by: { $0.orderNumber < $1.orderNumber }).map { activity in
            LessonActivityData(
                icon: ActivityStyle.icon(forRawType: activity.type),
                type: activity.type,
                title: activity.title ?? activityTypeLabel(for: activity.type),
                status: isCompleted ? .complete : .default
            )
        }

        return CardLessonData(
            id: schedule.id,
            day: schedule.lesson.dayNumber,
            mode: .lesson,
            activities: activities,
            title: schedule.lesson.title,
            date: schedule.scheduledDate,
            estimatedMinutes: schedule.lesson.totalEstimatedMinutes
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
