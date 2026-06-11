//
//  EnrollmentsListPage.swift
//  MakeReady
//
//  Page showing all enrollments for a group, separated into Active and Completed sections.
//

import SwiftUI

struct EnrollmentsListPage: View {
    let groupId: String
    let onDismiss: () -> Void
    var overlayManager: OverlayManager? = nil
    var onUnenroll: (() -> Void)? = nil  // Callback to notify parent when unenrollment completes

    // Pending enrollment (being created in background)
    var pendingEnrollment: EnrollmentData?
    var isCreatingEnrollment: Bool = false

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }
    @State private var enrollments: [EnrollmentWithProgram] = []
    @State private var isLoading = true
    @State private var error: String?

    // Unenroll confirmation
    @State private var enrollmentToDelete: EnrollmentWithProgram?
    @State private var isDeleting = false

    // Processing state for unenrollment overlay
    @State private var isProcessingUnenrollment = false
    @State private var unenrolledProgramName: String = ""

    // Navigation state — track by enrollment id so the SlideStack detail
    // pane reads live data from the loaded list.
    @State private var selectedEnrollmentId: String? = nil

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Computed properties for sections
    private var activeEnrollments: [EnrollmentWithProgram] {
        enrollments.filter { $0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    private var completedEnrollments: [EnrollmentWithProgram] {
        enrollments.filter { $0.isCompleted }.sorted { $0.endDate > $1.endDate }
    }

    var body: some View {
        ZStack {
            // Background at root level - stays fixed
            Color.appBackground
                .ignoresSafeArea()

            // Canonical slider (Phase 3.4): SlideStack owns the two-step
            // insertion, the single animation driver, and the completion-tied
            // unmount this page previously hand-rolled with currentScreen +
            // an asyncAfter(0.3) selection-clear wait.
            SlideStack(item: $selectedEnrollmentId) {
                enrollmentsListContent
            } detail: { enrollmentId in
                schedulePane(enrollmentId: enrollmentId)
            }
            .clipped()
        }
        .task {
            await loadEnrollments()
        }
        .onChange(of: isCreatingEnrollment) { wasCreating, isNowCreating in
            // When enrollment creation finishes (goes from true to false), refresh the list
            if wasCreating && !isNowCreating {
                Task {
                    await loadEnrollments()
                }
            }
        }
    }

    // MARK: - Schedule Detail (Screen 2)

    /// Schedule pane for the enrollment being viewed. Built from the
    /// SlideStack-mounted id — NOT from selectedEnrollmentId, which clears at
    /// dismissal while the pane is still sliding out.
    @ViewBuilder
    private func schedulePane(enrollmentId: String) -> some View {
        if let enrollment = enrollments.first(where: { $0.id == enrollmentId }) {
            EnrollmentSchedulePage(
                enrollment: enrollment,
                onDismiss: {
                    selectedEnrollmentId = nil
                },
                overlayManager: overlayManager
            )
        }
    }

    // MARK: - Enrollments List Content

    private var enrollmentsListContent: some View {
        VStack(spacing: 0) {
            // Header
            PageTitle.iconTitle(
                title: "Enrollments",
                icon: "chevron.left",
                onIconTap: { onDismiss() }
            )

            if isLoading {
                // Loading state
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
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
                        Task { await loadEnrollments() }
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }
                .padding(32)
                Spacer()
            } else if enrollments.isEmpty && !isCreatingEnrollment {
                // Empty state (only show if not creating an enrollment)
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No enrollments yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Enroll your group in a study program to get started")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                Spacer()
            } else {
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Pending enrollment skeleton at top
                        if isCreatingEnrollment, let pending = pendingEnrollment {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Creating...")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.horizontal, 16)

                                SkeletonEnrollmentCard(
                                    programName: pending.studyProgram.name,
                                    programImageUrl: pending.studyProgram.coverImageUrl,
                                    programDays: pending.studyProgram.days
                                )
                                .padding(.horizontal, 16)
                            }
                        }

                        // Active section (no title header)
                        if !activeEnrollments.isEmpty {
                            enrollmentSection(title: nil, enrollments: activeEnrollments)
                                .environment(\.swipeState, swipeState)
                        }

                        // Completed section
                        if !completedEnrollments.isEmpty {
                            enrollmentSection(title: "Completed", enrollments: completedEnrollments)
                                .environment(\.swipeState, swipeState)
                        }

                        // Bottom padding
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.top, 16)
                }
                .scrollDisabled(swipeState.isSwiping)
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Section View

    private func enrollmentSection(title: String?, enrollments: [EnrollmentWithProgram]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (optional)
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 16)
            }

            // Enrollment cards with swipe-to-delete
            VStack(spacing: 4) {
                ForEach(enrollments) { enrollment in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                presentUnenrollModal(enrollment: enrollment)
                            }
                        ],
                        onTap: {
                            handleEnrollmentTap(enrollment)
                        }
                    ) {
                        EnrollmentCard(enrollment: enrollment) {
                            // Tap handled by SwipeableCard
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadEnrollments() async {
        isLoading = true
        error = nil

        do {
            let loaded = try await EnrollmentActions().loadEnrollments(groupId: groupId)
            await MainActor.run {
                enrollments = loaded
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

    private func handleEnrollmentTap(_ enrollment: EnrollmentWithProgram) {
        NSLog("Tapped enrollment: \(enrollment.id)")
        selectedEnrollmentId = enrollment.id
    }

    private func presentUnenrollModal(enrollment: EnrollmentWithProgram) {
        overlayManager?.presentModal(id: OverlayID.unenrollOptions) {
            UnenrollOptionsModal(
                enrollmentId: enrollment.id,
                programName: enrollment.studyProgram?.name ?? "Study Program",
                programImageUrl: enrollment.studyProgram?.coverImageUrl,
                onConfirm: { option in
                    handleUnenrollConfirmed(enrollment: enrollment, option: option)
                },
                onDismiss: {
                    overlayManager?.dismiss(id: OverlayID.unenrollOptions)
                }
            )
        }
    }

    private func handleUnenrollConfirmed(enrollment: EnrollmentWithProgram, option: UnenrollOption) {
        overlayManager?.dismiss(id: OverlayID.unenrollOptions)

        // Store program name and show processing overlay
        unenrolledProgramName = enrollment.studyProgram?.name ?? "the program"
        isProcessingUnenrollment = true
        showProcessingUnenrollConfirmation(option: option)

        // Perform the action in background
        Task {
            await performUnenroll(enrollment: enrollment, option: option)
        }
    }

    private func performUnenroll(enrollment: EnrollmentWithProgram, option: UnenrollOption) async {
        isDeleting = true

        do {
            switch option {
            case .fullRemoval:
                try await EnrollmentActions().deleteEnrollment(id: enrollment.id)
                await MainActor.run {
                    enrollments.removeAll { $0.id == enrollment.id }
                }
            case .cancelFuture:
                try await EnrollmentActions().cancelFutureLessons(id: enrollment.id)
                // Reload enrollments to get updated state
                let reloaded = try await EnrollmentActions().loadEnrollments(groupId: groupId)
                await MainActor.run {
                    enrollments = reloaded
                }
            }

            await MainActor.run {
                isDeleting = false
                isProcessingUnenrollment = false
                onUnenroll?()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                isProcessingUnenrollment = false
                overlayManager?.dismiss(id: OverlayID.confirmationOverlay)
                self.error = "Failed to unenroll: \(error.localizedDescription)"
            }
        }
    }

    private func showProcessingUnenrollConfirmation(option: UnenrollOption) {
        guard let overlayManager = overlayManager else { return }

        UnenrollConfirmation.present(
            overlayManager: overlayManager,
            option: option,
            programName: unenrolledProgramName,
            isProcessing: $isProcessingUnenrollment,
            onDismiss: {
                overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                if option == .fullRemoval {
                    onDismiss()
                }
            }
        )
    }
}

#Preview {
    EnrollmentsListPage(
        groupId: "preview-group",
        onDismiss: { print("Dismissed") }
    )
}
