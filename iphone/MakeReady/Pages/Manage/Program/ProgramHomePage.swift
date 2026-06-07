//
//  ProgramHomePage.swift
//  MakeReady
//
//  Program management home page with cover image, tabs, and lessons
//
//  Architecture: Uses centralized AppState for all program/lesson data.
//  UI triggers actions via ProgramActions, view re-renders automatically.
//

import SwiftUI
import UIKit

/// Wraps a URL so it can be used with `fullScreenCover(item:)`.
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct ProgramHomePage: View {
    let overlayManager: OverlayManager
    let programId: String
    let onShowAddActivityMenu: (([String], @escaping (String) -> Void) -> Void)?
    var onDismiss: (() -> Void)?
    var leftIcon: String

    @EnvironmentObject var authManager: AuthManager

    init(
        overlayManager: OverlayManager,
        programId: String,
        onShowAddActivityMenu: (([String], @escaping (String) -> Void) -> Void)?,
        onDismiss: (() -> Void)? = nil,
        leftIcon: String = "xmark",
        initialCoverImage: UIImage? = nil
    ) {
        self.overlayManager = overlayManager
        self.programId = programId
        self.onShowAddActivityMenu = onShowAddActivityMenu
        self.onDismiss = onDismiss
        self.leftIcon = leftIcon
        _coverImage = State(initialValue: initialCoverImage)
    }

    // MARK: - Centralized State Access

    private var state: AppState { AppState.shared }

    /// Program from centralized state
    private var program: StudyProgram? {
        state.programs[programId]
    }

    /// True when the signed-in user created this program. Drives the
    /// edit-gating across this page: hides save/done/plus buttons, disables
    /// swipe-to-delete and reorder, etc. Group leaders can VIEW any program
    /// in their org but only edit ones they created themselves.
    private var canEdit: Bool {
        program?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    /// Lessons reconstructed from centralized state with activities
    private var lessons: [Lesson] {
        let cachedLessons = state.lessonsFor(programId: programId)
        return cachedLessons.map { lesson -> Lesson in
            var lessonCopy = lesson
            let activityIds = state.lessonActivityIndex.get(lesson.id)
            lessonCopy.activities = state.activities.getMany(activityIds).sorted { $0.orderNumber < $1.orderNumber }
            return lessonCopy
        }
    }

    /// Lessons that have no activities. A study cannot be published until
    /// every lesson has at least one activity.
    private var lessonsWithoutActivities: [Lesson] {
        lessons.filter { $0.activities.isEmpty }
    }

    /// Message shown when a publish attempt is blocked by lessons missing activities.
    private var publishBlockedMessage: String {
        let count = lessonsWithoutActivities.count
        let lessonNoun = count == 1 ? "lesson" : "lessons"
        let verb = count == 1 ? "is" : "are"
        return "There \(verb) \(count) \(lessonNoun) without an activity. Every lesson must have at least one activity before this study can be published."
    }

    /// Whether we're loading program data (initial load only)
    private var isLoadingProgram: Bool {
        state.loadingStates.isInitialLoading(programId)
    }

    /// Program enrollments from centralized state
    private var enrollments: [ProgramEnrollment] {
        state.programEnrollmentsFor(programId: programId)
    }

    // MARK: - Local UI State (legitimate - not app data)

    @State private var selectedTab = 0
    @State private var coverImage: UIImage?
    @State private var editingLesson: Lesson? = nil
    @State private var showEditDay = false
    @State private var showEditProgram = false
    @State private var isUploadingImage = false

    // Delete confirmation
    @State private var lessonToDelete: Lesson? = nil
    @State private var showDeleteConfirmation = false

    // Refresh state - prevents stacking multiple refresh requests
    @State private var isRefreshing = false

    // Drag-to-reorder (Dragula)
    @State private var orderedLessons: [Lesson] = []

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Add day
    @State private var showAddDayDialog = false
    @State private var isAddingDay = false

    // Publish status
    @State private var showPublishDialog = false
    @State private var showDraftAlert = false
    @State private var showPublishBlockedAlert = false

    // Preview modal — uses IdentifiableURL so fullScreenCover(item:) triggers
    // only after the URL is set, avoiding the nil-URL race with isPresented.
    @State private var previewItem: IdentifiableURL? = nil

    // Export
    @State private var showExportConfirm = false
    @State private var isExporting = false
    @State private var isLoadingExportPreview = false
    @State private var exportPreviewData: ExportPreviewData?
    @State private var isProcessingExport = false
    @State private var exportedFileURL: URL?

    // Edit form state (local copies for editing)
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var editIsPublished: Bool = false
    @State private var editTags: [String] = []
    @State private var originalEditTags: [String] = []

    private var showSecondScreen: Bool {
        showEditProgram || showEditDay
    }

    var body: some View {
        GeometryReader { geometry in
            if let program = program {
                HStack(spacing: 0) {
                    // Screen 1: Main program view
                    mainContent(program: program)
                        .frame(width: geometry.size.width)

                    // Screen 2: Container for edit screens
                    ZStack {
                        // Edit program settings
                        editProgramContent(program: program)
                            .opacity(showEditProgram ? 1 : 0)

                        // Edit day
                        if let lesson = editingLesson {
                            EditDay(
                                isPresented: $showEditDay,
                                programId: programId,
                                lesson: lesson,
                                onLessonUpdated: { _ in
                                    // No-op: AppState updates automatically via Actions
                                },
                                onShowAddActivityMenu: onShowAddActivityMenu
                            )
                            .id(lesson.id)
                            .opacity(showEditDay ? 1 : 0)
                        }
                    }
                    .frame(width: geometry.size.width)
                }
                .offset(x: showSecondScreen ? -geometry.size.width : 0)
                .animation(.easeInOut(duration: 0.3), value: showSecondScreen)
            } else if isLoadingProgram {
                loadingContent
            } else {
                // Program not found
                errorContent
            }
        }
        .task {
            // Trigger data load via Actions - AppState updates, view re-renders
            await loadProgramData()
        }
    }

    // MARK: - Data Loading (via Actions)

    /// Load program with lessons via ProgramActions
    private func loadProgramData() async {
        do {
            _ = try await ProgramActions().getProgram(id: programId)
            NSLog("📚 ProgramHomePage: Loaded program \(programId)")
        } catch {
            NSLog("❌ ProgramHomePage: Failed to load program: \(error)")
        }
    }

    /// Load enrollments for this program
    private func loadEnrollments() async {
        do {
            _ = try await ProgramActions().getProgramEnrollments(programId: programId)
            NSLog("📚 ProgramHomePage: Loaded enrollments for \(programId)")
        } catch {
            NSLog("❌ ProgramHomePage: Failed to load enrollments: \(error)")
        }
    }

    /// Open bidirectional enrollment flow with this program preselected
    private func openEnrollmentFlow() {
        guard let program = program else { return }
        guard program.isPublished == true else {
            showDraftAlert = true
            return
        }
        let enrolledIds = Set(enrollments.filter { $0.isActive }.map { $0.groupId })
        overlayManager.presentModal(id: OverlayID.programEnrollmentFlow, dismissOnTapOutside: false) {
            EnrollmentFlowModal(
                preselectedGroup: nil,
                preselectedProgram: program,
                enrolledGroupIds: enrolledIds,
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.programEnrollmentFlow)
                },
                onComplete: { enrollmentData, smsTime, requireResponse in
                    overlayManager.dismiss(id: OverlayID.programEnrollmentFlow)
                    createEnrollmentFromProgram(enrollmentData: enrollmentData, smsTime: smsTime, requireResponse: requireResponse)
                }
            )
        }
    }

    /// Create enrollment after completing the flow from program side
    private func createEnrollmentFromProgram(enrollmentData: EnrollmentData, smsTime: String, requireResponse: Bool) {
        let dayMap = [0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat"]
        let enabledDayStrings = enrollmentData.enabledDays.sorted().compactMap { dayMap[$0] }

        Task {
            do {
                let enrollment = try await EnrollmentActions().createEnrollment(
                    groupId: enrollmentData.group.id,
                    studyProgramId: enrollmentData.studyProgram.id,
                    startDate: enrollmentData.startDate,
                    enabledDays: enabledDayStrings,
                    smsTime: smsTime,
                    timezone: TimeZone.current.identifier,
                    requireResponse: requireResponse
                )
                NSLog("Created enrollment: \(enrollment.id)")

                // Refresh enrollments list
                await loadEnrollments()
            } catch {
                NSLog("Enrollment error: \(error)")
            }
        }
    }

    /// Open enrollment schedule for a program enrollment
    private func openEnrollmentSchedule(_ enrollment: ProgramEnrollment) {
        // Convert ProgramEnrollment → EnrollmentWithProgram for EnrollmentSchedulePage
        let programSummary: StudyProgramSummary? = program.map {
            StudyProgramSummary(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                days: $0.days,
                coverImageUrl: $0.coverImageUrl
            )
        }

        let enrollmentWithProgram = EnrollmentWithProgram(
            id: enrollment.id,
            groupId: enrollment.groupId,
            studyProgramId: enrollment.studyProgramId,
            startDate: enrollment.startDate,
            endDate: enrollment.endDate,
            enabledDays: enrollment.enabledDays,
            smsTime: enrollment.smsTime,
            timezone: enrollment.timezone,
            requireResponse: enrollment.requireResponse,
            currentLessonId: enrollment.currentLessonId,
            createdAt: enrollment.createdAt,
            updatedAt: enrollment.updatedAt,
            studyProgram: programSummary,
            isActive: enrollment.isActive
        )

        overlayManager.presentModal(id: OverlayID.enrollmentSchedule, dismissOnTapOutside: false) {
            EnrollmentSchedulePage(
                enrollment: enrollmentWithProgram,
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.enrollmentSchedule)
                },
                leftIcon: "xmark",
                overlayManager: overlayManager
            )
        }
    }

    /// Refresh data for the currently selected tab
    private func refreshCurrentTab() async {
        do {
            switch selectedTab {
            case 0: // Studies
                _ = try await ProgramActions().getProgram(id: programId)
                NSLog("🔄 ProgramHomePage: Refreshed studies for \(programId)")
            case 1: // Enrollments
                _ = try await ProgramActions().getProgramEnrollments(programId: programId, forceRefresh: true)
                NSLog("🔄 ProgramHomePage: Refreshed enrollments for \(programId)")
            case 2: // Analytics
                NSLog("🔄 ProgramHomePage: Analytics refresh not yet implemented")
            default:
                break
            }
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            // Ignore cancellation - happens when view updates during refresh
            NSLog("🔄 ProgramHomePage: Refresh cancelled (view updated)")
        } catch {
            NSLog("❌ ProgramHomePage: Failed to refresh: \(error)")
        }
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconIcon(
                    leftIcon: leftIcon,
                    rightIcon: "gearshape",
                    onLeftIconTap: {
                        overlayManager.dismiss(id: OverlayID.programHome)
                        onDismiss?()
                    },
                    onRightIconTap: {}
                )

                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            }
        }
    }

    private var errorContent: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitle(
                    title: "Error",
                    icon: leftIcon,
                    onIconTap: {
                        overlayManager.dismiss(id: OverlayID.programHome)
                        onDismiss?()
                    }
                )

                Spacer()
                Text("Program not found")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
        }
    }

    // MARK: - Main Content

    private func mainContent(program: StudyProgram) -> some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitleIcons(
                    title: "",
                    leftIcon: leftIcon,
                    rightIcons: [
                        IconAction(icon: "square.and.arrow.up") {
                            loadExportPreview()
                        },
                        IconAction(icon: "eye") {
                            openStudyPreview()
                        },
                        IconAction(icon: "gearshape") {
                            // Initialize edit form with current values from AppState (not stale parameter)
                            let current = state.programs[programId]
                            editName = current?.name ?? program.name
                            editDescription = current?.description ?? program.description ?? ""
                            editIsPublished = current?.isPublished ?? false
                            editTags = current?.tags ?? []
                            originalEditTags = editTags
                            showEditProgram = true
                            // Load tags from API in background
                            Task {
                                if let tags = try? await ProgramActions().getTags(programId: programId) {
                                    editTags = tags
                                    originalEditTags = tags
                                }
                            }
                        }
                    ],
                    onLeftIconTap: {
                        overlayManager.dismiss(id: OverlayID.programHome)
                        onDismiss?()
                    }
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Cover image picker
                            ZStack {
                                CoverImagePicker(
                                    selectedImage: $coverImage,
                                    programName: program.name,
                                    programDescription: program.description ?? "",
                                    mode: .display
                                )

                                if isUploadingImage {
                                    CardSpinnerOverlay()
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                Button {
                                    // Block publishing a draft that still has lessons without activities.
                                    if !(program.isPublished ?? false) && !lessonsWithoutActivities.isEmpty {
                                        showPublishBlockedAlert = true
                                    } else {
                                        showPublishDialog = true
                                    }
                                } label: {
                                    PublishBadge(isPublished: program.isPublished ?? false)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 12)
                                .padding(.leading, 12)
                            }

                            // Tab slider
                            TabSlider(
                                tabs: ["Studies", "Enrollments", "Analytics"],
                                selectedIndex: $selectedTab
                            )
                            .padding(.horizontal, 16)

                            // Tab content
                            Group {
                                switch selectedTab {
                                case 0:
                                    studiesContent(program: program)
                                        .environment(\.swipeState, swipeState)
                                case 1:
                                    enrollmentsContent
                                case 2:
                                    analyticsContent
                                default:
                                    EmptyView()
                                }
                            }

                            Spacer()
                                .frame(height: 40)
                        }
                    }
                    .refreshable {
                        guard !isRefreshing else { return }
                        isRefreshing = true

                        Task.detached { @MainActor in
                            defer { isRefreshing = false }
                            await refreshCurrentTab()
                        }

                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scrollDisabled(swipeState.isSwiping)
            }
        }
        .task {
            await loadExistingCoverImage(program: program)
        }
        .onChange(of: coverImage) { oldValue, newValue in
            if oldValue != nil || (oldValue == nil && newValue != nil && program.coverImageUrl == nil) {
                if let image = newValue, !isUploadingImage {
                    uploadCoverImage(image, programId: program.id)
                }
            }
        }
        .overlay {
            DialogOverlay(
                isPresented: $showPublishDialog,
                title: program.isPublished == true ? "Unpublish this study?" : "Publish this study?",
                message: program.isPublished == true
                    ? "This will unpublish the study. It will no longer be available for group enrollment."
                    : "Publishing the study will make it available for group enrollment.",
                buttons: [
                    DialogButtonConfig(
                        program.isPublished == true ? "Switch to Draft" : "Publish",
                        style: .primary
                    ) {
                        togglePublishStatus(programId: program.id, publish: !(program.isPublished == true))
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ]
            )
        }
        .fullScreenCover(item: $previewItem) { item in
            LessonPreviewModal(url: item.url, isPresented: Binding(
                get: { previewItem != nil },
                set: { if !$0 { previewItem = nil } }
            ))
        }
        .overlay {
            DialogOverlay(
                isPresented: $showAddDayDialog,
                title: "Add a new day?",
                message: "This will add a new day to the end of your study program.",
                buttons: [
                    DialogButtonConfig(
                        isAddingDay ? "Adding..." : "Add day",
                        style: .primary
                    ) {
                        addDay(programId: program.id)
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ]
            )
        }
        .alert("Draft Program", isPresented: $showDraftAlert) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("This study program must be published before it can be used for enrollment. Open the program and publish it first.")
        }
        .alert("Cannot Publish", isPresented: $showPublishBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(publishBlockedMessage)
        }
        .overlay {
            if showExportConfirm {
                ExportConfirmOverlay(
                    isPresented: $showExportConfirm,
                    previewData: exportPreviewData,
                    isExporting: isExporting,
                    onExport: { exportProgram() }
                )
            }
        }
    }

    // MARK: - Export

    private func loadExportPreview() {
        guard !isLoadingExportPreview else { return }
        isLoadingExportPreview = true

        Task {
            defer { isLoadingExportPreview = false }
            do {
                let data = try await APIClient.shared.request(
                    endpoint: "/api/programs/\(programId)/export-preview"
                )
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let preview = json["preview"] as? [String: Any],
                   let counts = preview["counts"] as? [String: Any] {

                    let activityTypes = counts["activityTypes"] as? [String: Int] ?? [:]

                    exportPreviewData = ExportPreviewData(
                        name: preview["name"] as? String ?? "Program",
                        days: counts["lessons"] as? Int ?? 0,
                        activities: counts["activities"] as? Int ?? 0,
                        reads: activityTypes["READ"] ?? 0,
                        videos: activityTypes["VIDEO"] ?? 0,
                        userInputs: activityTypes["USER_INPUT"] ?? 0,
                        readBlocks: counts["readBlocks"] as? Int ?? 0,
                        scriptureRefs: counts["scriptureReferences"] as? Int ?? 0,
                        templateName: (preview["template"] as? [String: Any])?["name"] as? String
                    )
                    showExportConfirm = true
                }
            } catch {
                NSLog("❌ Failed to load export preview: \(error)")
            }
        }
    }

    private func exportProgram() {
        guard !isExporting else { return }
        isExporting = true
        isProcessingExport = true
        exportedFileURL = nil

        let programName = program?.name ?? "Study Program"
        let message = try! AttributedString(markdown: "**\(programName)** has been exported successfully.")

        showExportConfirm = false

        overlayManager.present(id: OverlayID.confirmationOverlay, priority: .topLevel) {
            ConfirmationOverlay(
                style: .success,
                message: message,
                buttonLabel: "Save",
                secondaryButtonLabel: "Discard",
                isProcessing: $isProcessingExport,
                processingMessage: "Exporting study program",
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                    presentShareSheet()
                },
                onSecondaryDismiss: {
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                    exportedFileURL = nil
                }
            )
        }

        Task {
            defer { isExporting = false }
            do {
                let data = try await APIClient.shared.request(
                    endpoint: "/api/programs/\(programId)/export",
                    method: "POST"
                )

                let fileName = "\(programName).makeready"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)

                await MainActor.run {
                    exportedFileURL = tempURL
                    isProcessingExport = false
                }
            } catch {
                NSLog("❌ Failed to export program: \(error)")
                await MainActor.run {
                    isProcessingExport = false
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                }
            }
        }
    }

    private func presentShareSheet() {
        guard let fileURL = exportedFileURL else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(activityVC, animated: true)
            }
        }
    }

    // MARK: - Image Loading & Upload

    private func loadExistingCoverImage(program: StudyProgram) async {
        guard let urlString = program.coverImageUrl else { return }

        let mediumUrl = urlString.mediumImageUrl
        guard let url = URL(string: mediumUrl) else { return }

        NSLog("📸 Loading existing cover image from: \(mediumUrl)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    isUploadingImage = true
                    coverImage = image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isUploadingImage = false
                    }
                }
                NSLog("📸 Cover image loaded successfully")
            }
        } catch {
            NSLog("⚠️ Failed to load cover image: \(error)")
        }
    }

    private func togglePublishStatus(programId: String, publish: Bool) {
        // Guard: never publish a study that still has lessons without activities.
        if publish && !lessonsWithoutActivities.isEmpty {
            showPublishBlockedAlert = true
            return
        }

        // Optimistic update: immediately reflect in UI
        if var current = state.programs[programId] {
            current.isPublished = publish
            state.programs.upsert(current)
        }

        Task {
            do {
                _ = try await ProgramActions().updateProgram(id: programId, isPublished: publish)
                // Re-apply after API response upsert in case server response overwrote the value
                if var current = state.programs[programId], current.isPublished != publish {
                    current.isPublished = publish
                    state.programs.upsert(current)
                }
                NSLog("📚 Program \(publish ? "published" : "unpublished")")
            } catch {
                // Revert on failure
                if var current = state.programs[programId] {
                    current.isPublished = !publish
                    state.programs.upsert(current)
                }
                NSLog("⚠️ Failed to update publish status: \(error)")
            }
        }
    }

    /// Open the full-study preview in the in-app `LessonPreviewModal`
    /// (WKWebView). Uses the authenticated `/preview/study/{id}` route so
    /// the session cookie planted by LessonPreviewWebView authenticates
    /// the creator without needing the Safari admin-login flow.
    /// Mirrors how the lesson and activity preview buttons open.
    private func openStudyPreview() {
        let urlString = "\(Configuration.clientBaseURL)/preview/study/\(programId)"
        guard let url = URL(string: urlString) else { return }
        NSLog("👁️ StudyPreview: opening \(urlString)")
        previewItem = IdentifiableURL(url: url)
    }

    private func uploadCoverImage(_ image: UIImage, programId: String) {
        guard !isUploadingImage else { return }
        isUploadingImage = true

        NSLog("📸 Auto-saving cover image for program \(programId)")

        Task {
            do {
                _ = try await ProgramActions().uploadCoverImage(
                    programId: programId,
                    image: image
                )
                await MainActor.run {
                    isUploadingImage = false
                }
                NSLog("📸 Cover image auto-saved")
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                }
                NSLog("⚠️ Failed to auto-save cover image: \(error)")
            }
        }
    }

    // MARK: - Studies Tab

    @ViewBuilder
    private func studiesContent(program: StudyProgram) -> some View {
        VStack(spacing: 4) {
            if isLoadingProgram && lessons.isEmpty {
                SkeletonCardLesson()
                SkeletonCardLesson()
            } else if lessons.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                        .frame(height: 40)

                    Image(systemName: "book.closed")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No lessons yet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Add lessons to build your study program")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)

                    if canEdit {
                        BoxButton(
                            action: { showAddDayDialog = true },
                            label: nil,
                            icon: "plus",
                            iconPosition: .right,
                            variant: .secondary,
                            style: .solid,
                            size: .lg,
                            fullWidth: true,
                            iconOpacity: 0.5
                        )
                        .opacity(isAddingDay ? 0.5 : 1.0)
                        .disabled(isAddingDay)
                        .padding(.top, 8)
                    }

                    // Ghost card while adding
                    if isAddingDay {
                        SkeletonCardLesson()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.2), value: isAddingDay)
            } else {
                // Reorder via DragulaView only for the creator. Non-creators
                // get a bare ForEach so the lesson cards inherit the same
                // spacing as the parent VStack(spacing: 4) — DragulaView is
                // also a ForEach internally, so the gap between cards stays
                // visually identical regardless of edit permission.
                if canEdit {
                    DragulaView(items: $orderedLessons) { lesson in
                        lessonCard(lesson: lesson, program: program)
                    } dropView: { _ in
                        ReorderDropIndicator()
                    } dropCompleted: {
                        persistLessonOrder(programId: program.id)
                    }
                } else {
                    ForEach(orderedLessons, id: \.id) { lesson in
                        lessonCard(lesson: lesson, program: program)
                    }
                }

                // Ghost card while adding
                if isAddingDay {
                    SkeletonCardLesson()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if canEdit {
                    BoxButton(
                        action: { showAddDayDialog = true },
                        label: nil,
                        icon: "plus",
                        iconPosition: .right,
                        variant: .secondary,
                        style: .solid,
                        size: .lg,
                        fullWidth: true,
                        iconOpacity: 0.5
                    )
                    .opacity(isAddingDay ? 0.5 : 1.0)
                    .disabled(isAddingDay)
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isAddingDay)
        .onChange(of: lessons) { _, newLessons in
            orderedLessons = newLessons
        }
        .onAppear {
            orderedLessons = lessons
        }
        .alert("Permanently delete day \(lessonToDelete?.dayNumber ?? 0)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                lessonToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let lesson = lessonToDelete {
                    deleteLesson(lesson, programId: program.id)
                }
                lessonToDelete = nil
            }
        } message: {
            Text("This will permanently delete this day and all associated data from the program.")
        }
    }

    @ViewBuilder
    private func lessonCard(lesson: Lesson, program: StudyProgram) -> some View {
        SwipeableCard(
            slideButtons: canEdit ? [
                SlideButton(icon: "trash", style: .delete) {
                    lessonToDelete = lesson
                    showDeleteConfirmation = true
                }
            ] : [],
            isSwipeEnabled: canEdit,
            onTap: {
                editingLesson = lesson
                DispatchQueue.main.async {
                    showEditDay = true
                }
            }
        ) {
            CardLesson(data: cardLessonData(from: lesson), showAnimatedBorder: true)
        }
    }

    /// Persist reordered lessons to AppState and server
    private func persistLessonOrder(programId: String) {
        let lessonIds = orderedLessons.map { $0.id }

        // Optimistic update: immediately reflect new order in AppState
        for (index, lesson) in orderedLessons.enumerated() {
            var updated = lesson
            updated.dayNumber = index + 1
            state.lessons.upsert(updated)
        }

        // Persist via Actions
        Task {
            do {
                _ = try await ProgramActions().reorderLessons(
                    programId: programId,
                    lessonIds: lessonIds
                )
            } catch {
                NSLog("Failed to reorder lessons: \(error)")
                await loadProgramData()
            }
        }
    }

    // MARK: - Helpers

    private func cardLessonData(from lesson: Lesson) -> CardLessonData {
        // `orderedLessons` is a drag/reorder snapshot. Child activity changes
        // such as exegesis highlights update AppState.activities, but they do
        // not necessarily mutate the copied Lesson value or trip Lesson.==
        // because equality only compares activity count. Build card status from
        // live normalized activity state so readiness updates immediately.
        let liveActivities = state.programActivitiesFor(lessonId: lesson.id)
        let activities = liveActivities.isEmpty ? lesson.activities : liveActivities

        let activityDataList = activities.map { activity -> LessonActivityData in
            let icon: String
            let title: String

            icon = ActivityStyle.icon(for: activity.type)
            switch activity.type {
            case .soap, .oia, .dbs, .hear:
                title = activity.title ?? activity.passageReference ?? activity.type.displayName
            default:
                title = activity.title ?? activity.type.displayName
            }

            return LessonActivityData(
                icon: icon,
                type: activity.type.rawValue,
                title: title,
                isConfigured: activity.isConfigured,
                isLoading: state.loadingStates.isLoading(activity.id),
                status: activity.isConfigured ? .complete : .incomplete
            )
        }

        let totalSeconds = activities.compactMap(\.estimatedSeconds).reduce(0, +)
        let estimatedMinutes = totalSeconds > 0
            ? max(1, Int(round(Double(totalSeconds) / 60.0)))
            : lesson.estimatedMinutes

        return CardLessonData(
            id: lesson.id,
            day: lesson.dayNumber,
            mode: .lesson,
            activities: activityDataList,
            title: lesson.title ?? program?.templateName,
            estimatedMinutes: estimatedMinutes,
            onTap: nil
        )
    }

    // MARK: - Actions

    private func saveProgram(programId: String) {
        NSLog("📝 Saving program changes for \(programId)")

        let savedName = editName
        let savedDesc = editDescription.isEmpty ? nil : editDescription
        let savedIsPublished = editIsPublished
        let savedTags = editTags
        let oldTags = originalEditTags

        // Optimistic update: immediately reflect in UI
        var oldName: String?
        var oldDescription: String?
        var oldIsPublished: Bool?
        if var current = state.programs[programId] {
            oldName = current.name
            oldDescription = current.description
            oldIsPublished = current.isPublished
            current.name = savedName
            current.description = savedDesc
            current.isPublished = savedIsPublished
            state.programs.upsert(current)
        }

        Task {
            do {
                _ = try await ProgramActions().updateProgram(
                    id: programId,
                    name: savedName,
                    description: savedDesc,
                    isPublished: savedIsPublished
                )
                // Re-apply after API response upsert in case server response overwrote values
                if var current = state.programs[programId] {
                    var changed = false
                    if current.name != savedName { current.name = savedName; changed = true }
                    if current.description != savedDesc { current.description = savedDesc; changed = true }
                    if current.isPublished != savedIsPublished { current.isPublished = savedIsPublished; changed = true }
                    if changed { state.programs.upsert(current) }
                }
                // Sync tags
                if savedTags != oldTags {
                    try await ProgramActions().syncTags(programId: programId, oldTags: oldTags, newTags: savedTags)
                    if var current = state.programs[programId] {
                        current.tags = savedTags
                        state.programs.upsert(current)
                    }
                }
                NSLog("📝 Program saved successfully")
            } catch {
                // Revert on failure
                if var current = state.programs[programId] {
                    current.name = oldName ?? current.name
                    current.description = oldDescription
                    current.isPublished = oldIsPublished
                    state.programs.upsert(current)
                }
                NSLog("⚠️ Failed to save program: \(error)")
            }
        }
    }

    private func deleteLesson(_ lesson: Lesson, programId: String) {
        NSLog("📝 Deleting lesson day \(lesson.dayNumber)")

        // Optimistic update: immediately remove from UI
        let activityIds = state.lessonActivityIndex.get(lesson.id)
        state.lessons.remove(lesson.id)
        state.programLessonIndex.remove(parentId: programId, childId: lesson.id)
        state.activities.removeMany(activityIds)
        state.lessonActivityIndex.removeAll(parentId: lesson.id)

        Task {
            do {
                try await ProgramActions().deleteLesson(programId: programId, lessonId: lesson.id)
                NSLog("📝 Lesson deleted")
            } catch {
                NSLog("⚠️ Failed to delete lesson: \(error)")
                // Reload to restore correct state
                await loadProgramData()
            }
        }
    }

    private func addDay(programId: String) {
        guard !isAddingDay else { return }
        isAddingDay = true

        Task {
            do {
                let lesson = try await ProgramActions().addLesson(programId: programId)
                NSLog("📝 Added day \(lesson.dayNumber)")
                // Refresh to get full program state
                _ = try await ProgramActions().getProgram(id: programId)
            } catch {
                NSLog("⚠️ Failed to add day: \(error)")
            }
            isAddingDay = false
        }
    }

    // MARK: - Edit Program Content

    private func editProgramContent(program: StudyProgram) -> some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if canEdit {
                    PageTitle.iconTitleLink(
                        title: "Edit Program",
                        leftIcon: "chevron.left",
                        rightLink: "Done",
                        onLeftIconTap: {
                            showEditProgram = false
                        },
                        onRightLinkTap: {
                            // Block publishing via settings if any lesson lacks an activity.
                            if editIsPublished && !lessonsWithoutActivities.isEmpty {
                                showPublishBlockedAlert = true
                                return
                            }
                            saveProgram(programId: program.id)
                            showEditProgram = false
                        }
                    )
                } else {
                    // Read-only view for non-creators: keep the back chevron
                    // but drop the "Done" link so there's no save affordance.
                    PageTitle.iconTitle(
                        title: "Program",
                        icon: "chevron.left",
                        onIconTap: {
                            showEditProgram = false
                        }
                    )
                }

                ScrollView {
                    VStack(spacing: 20) {
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: editName,
                            programDescription: editDescription
                        )
                        .disabled(!canEdit)

                        FieldGroup {
                            TextInput(
                                floatingLabel: "Program name",
                                autocorrect: true,
                                text: $editName
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        FieldGroup {
                            MultilineTextInput(
                                placeholder: "Describe the purpose of this program",
                                text: $editDescription,
                                minHeight: 130
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        ToggleGroup {
                            ToggleControl(
                                title: "Publish program",
                                description: "Published programs can be enrolled by groups. Draft programs are only visible to you.",
                                isOn: $editIsPublished
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        // Tags
                        TagInput(
                            tags: $editTags,
                            placeholder: "Add tag...",
                            onRequestSuggestions: {
                                (try? await ProgramActions().suggestTags(programId: programId)) ?? []
                            }
                        )
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        Spacer()
                            .frame(height: KeyboardState.shared.isVisible ? KeyboardState.shared.height + 40 : 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Enrollments Tab

    @ViewBuilder
    private var enrollmentsContent: some View {
        let isLoading = state.loadingStates.isInitialLoading("enrollments-\(programId)")

        VStack(spacing: 8) {
            if isLoading && enrollments.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCardGroup()
                }
            } else if enrollments.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                        .frame(height: 40)

                    Image(systemName: "person.3")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No enrollments yet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Groups enrolled in this program will appear here")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)

                    BoxButton(
                        action: { openEnrollmentFlow() },
                        label: nil,
                        icon: "plus",
                        iconPosition: .right,
                        variant: .secondary,
                        style: .solid,
                        size: .lg,
                        fullWidth: true,
                        iconOpacity: 0.5
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            } else {
                ForEach(enrollments) { enrollment in
                    CardGroup(
                        data: CardGroupData(
                            id: enrollment.id,
                            title: enrollment.group?.name ?? "Unknown Group",
                            subtitle: enrollment.group?.creator?.name,
                            imageStyle: enrollment.group?.coverImageUrl != nil
                                ? .photo(imageURL: enrollment.group!.coverImageUrl!)
                                : .icon(systemName: "person.2.fill", backgroundColor: .purple),
                            metadata: [
                                DataItem(icon: "clock", value: enrollment.dateRangeString)
                            ],
                            isSelected: false,
                            onTap: {
                                openEnrollmentSchedule(enrollment)
                            }
                        )
                    )
                }

                BoxButton(
                    action: { openEnrollmentFlow() },
                    label: nil,
                    icon: "plus",
                    iconPosition: .right,
                    variant: .secondary,
                    style: .solid,
                    size: .lg,
                    fullWidth: true,
                    iconOpacity: 0.5
                )
            }
        }
        .padding(.horizontal, 16)
        .task {
            await loadEnrollments()
        }
    }

    // MARK: - Analytics Tab

    @ViewBuilder
    private var analyticsContent: some View {
        VStack {
            Spacer()
                .frame(height: 80)

            Text("Coming soon")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
    }
}

// MARK: - Export Preview Data

struct ExportPreviewData {
    let name: String
    let days: Int
    let activities: Int
    let reads: Int
    let videos: Int
    let userInputs: Int
    let readBlocks: Int
    let scriptureRefs: Int
    let templateName: String?
}

// MARK: - Export Confirm Overlay

private struct ExportConfirmOverlay: View {
    @Binding var isPresented: Bool
    let previewData: ExportPreviewData?
    let isExporting: Bool
    let onExport: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            // Blurred dark background
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                Color.black.opacity(0.5)
            }
            .opacity(visible ? 1 : 0)
            .onTapGesture { dismiss() }

            // Content
            VStack(spacing: 20) {
                Text("Export Program")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                if let data = previewData {
                    // Program name
                    Text(data.name)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))

                    // KPI grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Kpi(value: Double(data.days), valueType: .number, label: "Days", icon: "calendar", variant: .iconValue)
                        Kpi(value: Double(data.activities), valueType: .number, label: "Activities", icon: "list.bullet", variant: .iconValue)

                        if data.reads > 0 {
                            Kpi(value: Double(data.reads), valueType: .number, label: "Read", icon: "book.fill", variant: .iconValue)
                        }
                        if data.videos > 0 {
                            Kpi(value: Double(data.videos), valueType: .number, label: "Video", icon: "play.fill", variant: .iconValue)
                        }
                        if data.userInputs > 0 {
                            Kpi(value: Double(data.userInputs), valueType: .number, label: "Write", icon: "pencil", variant: .iconValue)
                        }
                        if data.readBlocks > 0 {
                            Kpi(value: Double(data.readBlocks), valueType: .number, label: "Read Blocks", icon: "text.alignleft", variant: .iconValue)
                        }
                        if data.scriptureRefs > 0 {
                            Kpi(value: Double(data.scriptureRefs), valueType: .number, label: "Scriptures", icon: "book.closed.fill", variant: .iconValue)
                        }
                    }

                    if let template = data.templateName {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Template: \(template)")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onExport()
                    } label: {
                        Text(isExporting ? "Exporting..." : "Export")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#6c47ff"))
                            )
                    }
                    .disabled(isExporting)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1A1D28"))
            )
            .padding(.horizontal, 32)
            .scaleEffect(visible ? 1 : 0.9)
            .opacity(visible ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { visible = true }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    PreviewContainer()
}

/// Preview container that sets up mock data in AppState
private struct PreviewContainer: View {
    @State private var overlayManager = OverlayManager()
    @State private var isDataReady = false

    private let mockProgramId = "preview-program-1"

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            if isDataReady {
                ProgramHomePage(
                    overlayManager: overlayManager,
                    programId: mockProgramId,
                    onShowAddActivityMenu: nil,
                    onDismiss: nil
                )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .environment(overlayManager)
        .onAppear {
            setupMockData()
            isDataReady = true
        }
    }

    private func setupMockData() {
        let state = AppState.shared
        let now = Date()

        // Create mock activities
        let activity1 = StudyActivity(
            id: "activity-1",
            lessonId: "lesson-1",
            type: .soap,
            status: .complete,
            orderNumber: 0,
            createdAt: now,
            updatedAt: now,
            videoId: nil,
            videoUrl: nil,
            video: nil,
            passageReference: "Romans 1:1-7",
            bookNumber: 45,
            bookName: "Romans",
            chapterStart: 1,
            chapterEnd: nil,
            verseStart: 1,
            verseEnd: 7,
            startElementId: nil,
            startOffset: nil,
            endElementId: nil,
            endOffset: nil
        )

        let activity2 = StudyActivity(
            id: "activity-2",
            lessonId: "lesson-1",
            type: .video,
            status: .pending,
            orderNumber: 1,
            createdAt: now,
            updatedAt: now,
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

        let activity3 = StudyActivity(
            id: "activity-3",
            lessonId: "lesson-2",
            type: .soap,
            status: .complete,
            orderNumber: 0,
            createdAt: now,
            updatedAt: now,
            videoId: nil,
            videoUrl: nil,
            video: nil,
            passageReference: "Romans 1:8-17",
            bookNumber: 45,
            bookName: "Romans",
            chapterStart: 1,
            chapterEnd: nil,
            verseStart: 8,
            verseEnd: 17,
            startElementId: nil,
            startOffset: nil,
            endElementId: nil,
            endOffset: nil
        )

        // Activity with loading state (simulates video being cleared/uploaded)
        let activity4 = StudyActivity(
            id: "activity-4-loading",
            lessonId: "lesson-2",
            type: .video,
            status: .pending,
            orderNumber: 1,
            createdAt: now,
            updatedAt: now,
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

        // Create mock lessons
        let lesson1 = Lesson(
            id: "lesson-1",
            studyProgramId: mockProgramId,
            dayNumber: 1,
            activities: [activity1, activity2],
            createdAt: now,
            updatedAt: now
        )

        let lesson2 = Lesson(
            id: "lesson-2",
            studyProgramId: mockProgramId,
            dayNumber: 2,
            activities: [activity3, activity4],
            createdAt: now,
            updatedAt: now
        )

        let lesson3 = Lesson(
            id: "lesson-3",
            studyProgramId: mockProgramId,
            dayNumber: 3,
            activities: [],
            createdAt: now,
            updatedAt: now
        )

        // Create mock program
        let program = StudyProgram(
            id: mockProgramId,
            name: "Romans Deep Dive",
            description: "A 30-day journey through the book of Romans, exploring Paul's theology of grace and faith.",
            defaultActivity: .soap,
            days: 30,
            coverImageUrl: nil,
            creatorId: "user-1",
            isActive: true,
            createdAt: now,
            updatedAt: now,
            lessons: [lesson1, lesson2, lesson3],
            _count: ProgramCount(lessons: 3, enrollments: 12)
        )

        // Set loading state for activity4 to simulate processing
        state.loadingStates.setState(.loading, for: "activity-4-loading")

        // Insert into AppState
        state.programs.upsert(program)

        // Insert lessons and activities
        for lesson in [lesson1, lesson2, lesson3] {
            state.lessons.upsert(lesson)
            state.programLessonIndex.add(parentId: mockProgramId, childId: lesson.id)

            for activity in lesson.activities {
                state.activities.upsert(activity)
                state.lessonActivityIndex.add(parentId: lesson.id, childId: activity.id)
            }
        }
    }
}

// MARK: - Publish Badge

private struct PublishBadge: View {
    let isPublished: Bool

    var body: some View {
        Text(isPublished ? "Published" : "Draft")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isPublished ? Color(hex: "#0D101A") : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: isPublished ? "#57DB5D" : "#242A3E"))
            )
    }
}

