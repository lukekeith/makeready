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

    @Environment(AuthManager.self) var authManager

    init(
        overlayManager: OverlayManager,
        programId: String,
        onShowAddActivityMenu: (([String], @escaping (String) -> Void) -> Void)?,
        onDismiss: (() -> Void)? = nil,
        leftIcon: String = "xmark",
        initialCoverImage: UIImage? = nil,
        initialTab: Int = 0
    ) {
        self.overlayManager = overlayManager
        self.programId = programId
        self.onShowAddActivityMenu = onShowAddActivityMenu
        self.onDismiss = onDismiss
        self.leftIcon = leftIcon
        _coverImage = State(initialValue: initialCoverImage)
        // Seedable so the capture harness (and deep links, if ever needed) can
        // open a specific tab; production call sites default to Lessons.
        _selectedTab = State(initialValue: initialTab)
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

    // Analytics tab: Week/Month/Year toggle (pure client state — all three
    // series ship in one payload) + fetch-failure flag for the no-cache case.
    @State private var analyticsTimeScale = 0
    @State private var analyticsLoadFailed = false
    @State private var coverImage: UIImage?
    @State private var isUploadingImage = false

    /// Which detail pane the slider shows. One enum item replaces the old
    /// showEditProgram/showEditDay flags + always-mounted opacity swap: only
    /// the active detail is built, and SlideStack keys content identity off
    /// the item so switching lessons recreates the EditDay pane.
    private enum DetailScreen: Equatable, Hashable {
        case editProgram
        case editDay(lessonId: String)
    }
    @State private var detailScreen: DetailScreen? = nil

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
    // Switching a published study to draft while groups are enrolled: confirm
    // first, explaining that enrolled groups keep their lessons (monday#12268464531).
    @State private var showSwitchToDraftConfirm = false

    // Publish updates (study sync). Tapping the Published badge kicks off a
    // read-only preview fetch; the "Published study" dialog opens immediately
    // with "Checking for changes…" and the summary (last published + what
    // changed since) fills in IN PLACE when the preview lands. Publishing
    // hands off to a processing ConfirmationOverlay (spinner circle → green
    // checkmark); a raced no-op publish alerts.
    @State private var isPublishingUpdates = false
    @State private var publishPreview: ProgramActions.PublishPreview?
    @State private var publishPreviewFailed = false
    @State private var showAlreadyUpToDateAlert = false

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

    var body: some View {
        Group {
            if let program = program {
                // Canonical slider (Phase 3.4): SlideStack with an enum item
                // replaces the hand-rolled offset slider whose second pane
                // opacity-swapped between the two edit screens.
                SlideStack(item: $detailScreen) {
                    mainContent(program: program)
                } detail: { screen in
                    detailPane(screen: screen, program: program)
                }
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
            // Enrollments back the switch-to-draft confirm's count, so load them
            // on open (cache-first) rather than only when the Enrollments tab is
            // visited (monday#12268464531).
            await loadEnrollments()
        }
    }

    // MARK: - Detail Pane (Screen 2)

    /// Detail pane for the slider. Built from the SlideStack-mounted item —
    /// NOT from detailScreen, which clears at dismissal while the pane is
    /// still sliding out. The lesson is looked up live from AppState.
    @ViewBuilder
    private func detailPane(screen: DetailScreen, program: StudyProgram) -> some View {
        switch screen {
        case .editProgram:
            editProgramContent(program: program)
        case .editDay(let lessonId):
            if let lesson = state.lessonsFor(programId: programId).first(where: { $0.id == lessonId }) {
                EditDay(
                    isPresented: Binding(
                        get: { detailScreen != nil },
                        set: { if !$0 { detailScreen = nil } }
                    ),
                    programId: programId,
                    lesson: lesson,
                    onLessonUpdated: { _ in
                        // No-op: AppState updates automatically via Actions
                    },
                    onShowAddActivityMenu: onShowAddActivityMenu
                )
            }
        }
    }

    // MARK: - Data Loading (via Actions)

    /// Load program with lessons via ProgramActions
    private func loadProgramData() async {
        do {
            _ = try await ProgramActions().getProgram(id: programId)
        } catch {
            // Background load — console-only; cached content stays on screen.
            state.recordError(error, context: "ProgramHomePage.loadProgramData")
        }
    }

    /// Load enrollments for this program
    private func loadEnrollments() async {
        do {
            _ = try await ProgramActions().getProgramEnrollments(programId: programId)
        } catch {
            // Background load — console-only.
            state.recordError(error, context: "ProgramHomePage.loadEnrollments")
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
        overlayManager.present(.programEnrollmentFlow) {
            EnrollmentFlowModal(
                preselectedGroup: nil,
                preselectedProgram: program,
                enrolledGroupIds: enrolledIds,
                onDismiss: {
                    overlayManager.dismiss(.programEnrollmentFlow)
                },
                onComplete: { enrollmentData, smsTime, requireResponse in
                    overlayManager.dismiss(.programEnrollmentFlow)
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
                    requireResponse: requireResponse,
                    syncMode: enrollmentData.syncMode
                )
                Log.state.info("Created enrollment: \(enrollment.id, privacy: .private)")

                // Refresh enrollments list
                await loadEnrollments()
            } catch {
                // User just completed the enrollment flow — surface it.
                // Retry re-runs the create with the captured flow values.
                state.recordError(
                    error,
                    context: "ProgramHomePage.createEnrollmentFromProgram",
                    surface: true,
                    friendlyMessage: "Couldn't create the enrollment",
                    retry: {
                        createEnrollmentFromProgram(
                            enrollmentData: enrollmentData,
                            smsTime: smsTime,
                            requireResponse: requireResponse
                        )
                    }
                )
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

        // Tapping an enrollment offers Edit lessons / Edit enrollment
        // (monday#12270302158) rather than jumping straight to the schedule.
        let studyName = program?.name ?? "Study"
        let canManage = enrollment.canManage ?? (AppState.shared.groups[enrollment.groupId] != nil)
        overlayManager.present(.enrollmentActionMenu) {
            EnrollmentActionMenu(
                studyName: studyName,
                canManage: canManage,
                creatorName: enrollment.studyProgramCreatorName,
                onEditLessons: {
                    overlayManager.present(.enrollmentSchedule) {
                        EnrollmentSchedulePage(
                            enrollment: enrollmentWithProgram,
                            onDismiss: {
                                overlayManager.dismiss(.enrollmentSchedule)
                            },
                            leftIcon: "xmark",
                            overlayManager: overlayManager
                        )
                    }
                },
                onEditEnrollment: {
                    overlayManager.present(.editEnrollmentFlow) {
                        EditEnrollmentFlowModal(
                            enrollment: enrollmentWithProgram,
                            onDismiss: { overlayManager.dismiss(.editEnrollmentFlow) },
                            onSaved: {
                                overlayManager.dismiss(.editEnrollmentFlow)
                                Task { await refreshCurrentTab() }
                            }
                        )
                    }
                },
                // All enrollments here are for THIS program, so the existing
                // program-scoped study preview is the right target.
                onPreviewStudy: { openStudyPreview() }
            )
        }
    }

    /// Refresh data for the currently selected tab
    private func refreshCurrentTab() async {
        do {
            switch selectedTab {
            case 0: // Lessons
                _ = try await ProgramActions().getProgram(id: programId)
                NSLog("🔄 ProgramHomePage: Refreshed studies for \(programId)")
            case 1: // Enrollments
                _ = try await ProgramActions().getProgramEnrollments(programId: programId, forceRefresh: true)
                NSLog("🔄 ProgramHomePage: Refreshed enrollments for \(programId)")
            case 2: // Analytics
                _ = try await ProgramActions().getProgramAnalytics(programId: programId)
                Log.ui.info("🔄 ProgramHomePage: refreshed analytics for \(programId, privacy: .public)")
            default:
                break
            }
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            // Silent: refresh cancelled because the view updated mid-flight — expected, not a failure.
        } catch {
            // Background refresh — console-only; cached content stays on screen.
            state.recordError(error, context: "ProgramHomePage.refreshCurrentTab")
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
                        overlayManager.dismiss(.programHome)
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
                        overlayManager.dismiss(.programHome)
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
                            detailScreen = .editProgram
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
                        overlayManager.dismiss(.programHome)
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
                                    handlePublishTap(program: program)
                                } label: {
                                    PublishBadge(isPublished: program.isPublished ?? false)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 12)
                                .padding(.leading, 12)
                            }

                            // Tab slider
                            TabSlider(
                                tabs: ["Lessons", "Enrollments", "Analytics"],
                                selectedIndex: $selectedTab
                            )
                            .padding(.horizontal, 16)

                            // Tab content
                            Group {
                                switch selectedTab {
                                case 0: // Lessons
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
            // Published: the badge is the home of the explicit "Publish
            // updates" action (study sync — the publish, not the edit, is the
            // unit of enrollment sync), alongside switching back to draft.
            // Draft: the original publish confirm.
            DialogOverlay(
                isPresented: $showPublishDialog,
                title: program.isPublished == true ? "Published study" : "Publish this study?",
                message: program.isPublished == true
                    ? publishedDialogMessage
                    : "Publishing the study will make it available for group enrollment.",
                buttons: program.isPublished == true
                    ? [
                        DialogButtonConfig("Publish updates", style: .primary) {
                            publishUpdates(programId: program.id)
                        },
                        DialogButtonConfig("Switch to Draft", style: .secondary) {
                            // If any group is currently enrolled, confirm first and
                            // explain the effect; otherwise switch to draft directly.
                            if enrollments.contains(where: { $0.isActive }) {
                                showSwitchToDraftConfirm = true
                            } else {
                                togglePublishStatus(programId: program.id, publish: false)
                            }
                        },
                        DialogButtonConfig("Cancel", style: .secondary) {}
                    ]
                    : [
                        DialogButtonConfig("Publish", style: .primary) {
                            togglePublishStatus(programId: program.id, publish: true)
                        },
                        DialogButtonConfig("Cancel", style: .secondary) {}
                    ]
            )
        }
        .overlay {
            // Explain-only confirm before switching a study with enrolled groups
            // back to draft — no cascade, no kick-out (monday#12268464531).
            DialogOverlay(
                isPresented: $showSwitchToDraftConfirm,
                title: "Switch to draft?",
                message: switchToDraftMessage,
                buttons: [
                    DialogButtonConfig("Switch to Draft", style: .primary) {
                        togglePublishStatus(programId: program.id, publish: false)
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
        .alert("Already up to date", isPresented: $showAlreadyUpToDateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enrolled groups already have the latest version of this study.")
        }
        .overlay {
            if showExportConfirm {
                ExportConfirmOverlay(
                    isPresented: $showExportConfirm,
                    previewData: exportPreviewData,
                    isExporting: isExporting,
                    onExport: { exportProgram() },
                    onPublish: {
                        // Instant dismiss, then present the publish dialog
                        // (MODAL_GUIDE: never dismiss + present simultaneously).
                        showExportConfirm = false
                        handlePublishTap(program: program)
                    }
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
                let data = try await ProgramActions().loadExportPreviewData(programId: programId)
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
                // User just tapped Export — without the preview nothing happens,
                // so surface the failure. Safe to re-run as-is.
                state.recordError(
                    error,
                    context: "ProgramHomePage.loadExportPreview",
                    surface: true,
                    friendlyMessage: "Couldn't load the export preview",
                    retry: { loadExportPreview() }
                )
            }
        }
    }

    private func exportProgram() {
        guard !isExporting else { return }
        isExporting = true
        isProcessingExport = true
        exportedFileURL = nil

        let programName = program?.name ?? "Study Program"
        let message = AttributedString.safeMarkdown("**\(programName)** has been exported successfully.")

        showExportConfirm = false

        overlayManager.present(.confirmationOverlay) {
            ConfirmationOverlay(
                style: .success,
                message: message,
                buttonLabel: "Save",
                secondaryButtonLabel: "Discard",
                isProcessing: $isProcessingExport,
                processingMessage: "Exporting study program",
                onDismiss: {
                    overlayManager.dismiss(.confirmationOverlay)
                    presentShareSheet()
                },
                onSecondaryDismiss: {
                    overlayManager.dismiss(.confirmationOverlay)
                    exportedFileURL = nil
                }
            )
        }

        Task {
            defer { isExporting = false }
            do {
                let data = try await ProgramActions().exportProgramData(programId: programId)

                let fileName = "\(programName).makeready"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)

                await MainActor.run {
                    exportedFileURL = tempURL
                    isProcessingExport = false
                }
            } catch {
                await MainActor.run {
                    // Cleanup first, then record — the banner must not sit
                    // over a stuck processing overlay.
                    isProcessingExport = false
                    overlayManager.dismiss(.confirmationOverlay)
                    state.recordError(
                        error,
                        context: "ProgramHomePage.exportProgram",
                        surface: true,
                        friendlyMessage: "Couldn't export the study program",
                        retry: { exportProgram() }
                    )
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
            // Background CDN image load — console-only; page renders fine without the cover.
            state.recordError(error, context: "ProgramHomePage.loadExistingCoverImage")
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
                // Revert the optimistic update first, then surface — the user
                // just tapped publish/unpublish.
                if var current = state.programs[programId] {
                    current.isPublished = !publish
                    state.programs.upsert(current)
                }
                state.recordError(
                    error,
                    context: "ProgramHomePage.togglePublishStatus",
                    surface: true,
                    friendlyMessage: publish ? "Couldn't publish the study" : "Couldn't unpublish the study",
                    retry: { togglePublishStatus(programId: programId, publish: publish) }
                )
            }
        }
    }

    /// Open the publish dialog — shared by the Published/Draft badge and the
    /// Export & Publish overlay's Publish button. Drafts are gated on every
    /// lesson having at least one activity; published programs start the
    /// pending-changes preview load as the dialog opens.
    private func handlePublishTap(program: StudyProgram) {
        if !(program.isPublished ?? false) && !lessonsWithoutActivities.isEmpty {
            showPublishBlockedAlert = true
            return
        }
        if program.isPublished == true {
            fetchPublishPreview(programId: program.id)
        }
        showPublishDialog = true
    }

    /// The "Published study" dialog message — "Checking…" until the preview
    /// lands, then the composed summary (the DialogOverlay re-renders live
    /// from this state). Falls back to the generic text if the preview fails.
    private var publishedDialogMessage: String {
        if let preview = publishPreview {
            return publishPreviewMessage(preview)
        }
        if publishPreviewFailed {
            return "Publish your latest edits to enrolled groups as a new version, or switch this study back to draft."
        }
        return "Checking for changes since the last publish…"
    }

    /// Explain-only copy for the switch-to-draft confirm: enrolled groups keep
    /// their scheduled lessons; only new enrollments are affected. Pluralized on
    /// the active-enrollment count (monday#12268464531).
    private var switchToDraftMessage: String {
        let count = enrollments.filter { $0.isActive }.count
        let groups = count == 1 ? "1 group is" : "\(count) groups are"
        return "\(groups) currently enrolled. Switching to draft removes this study from new enrollments. Groups already enrolled keep their scheduled lessons — they are not removed."
    }

    /// Kicked off as the badge dialog opens — loads the read-only diff that
    /// fills the dialog's message in place.
    private func fetchPublishPreview(programId: String) {
        publishPreview = nil
        publishPreviewFailed = false

        Task {
            do {
                let preview = try await ProgramActions().getPublishPreview(programId: programId)
                await MainActor.run { publishPreview = preview }
            } catch {
                await MainActor.run {
                    // Console-only: the preview is advisory — the dialog falls
                    // back to its generic message and publish stays no-op-guarded.
                    publishPreviewFailed = true
                    state.recordError(error, context: "ProgramHomePage.fetchPublishPreview")
                }
            }
        }
    }

    /// Condensed preview: last-published line, a count matrix
    /// ("2 changed · 1 added"), then capped per-day lines.
    private func publishPreviewMessage(_ preview: ProgramActions.PublishPreview) -> String {
        var paragraphs: [String] = []

        if let last = preview.lastPublished {
            let date = ModelFormatters.monthDay.string(from: last.publishedAt)
            paragraphs.append("Last published \(date) (version \(last.versionNumber))")
        } else {
            paragraphs.append("Changes aren't tracked for this study yet — publishing creates version 1, the baseline enrolled groups sync to.")
        }

        if preview.upToDate {
            paragraphs.append("No changes since — enrolled groups have the latest version.")
            return paragraphs.joined(separator: "\n\n")
        }

        if let changes = preview.changes {
            var matrix: [String] = []
            if !changes.changed.isEmpty { matrix.append("\(changes.changed.count) changed") }
            if !changes.added.isEmpty { matrix.append("\(changes.added.count) added") }
            if !changes.removed.isEmpty { matrix.append("\(changes.removed.count) removed") }
            if !changes.moved.isEmpty { matrix.append("\(changes.moved.count) moved") }
            if !matrix.isEmpty {
                paragraphs.append(matrix.joined(separator: " · "))
            }

            func shortTitle(_ title: String?) -> String {
                guard let title, !title.isEmpty else { return "" }
                return title.count > 24 ? " — \(title.prefix(24))…" : " — \(title)"
            }
            var detail: [String] = []
            detail += changes.changed.map { "Day \($0.dayNumber) changed\(shortTitle($0.title))" }
            detail += changes.added.map { "Day \($0.dayNumber) added\(shortTitle($0.title))" }
            detail += changes.removed.map { "Day \($0.dayNumber) removed\(shortTitle($0.title))" }
            detail += changes.moved.map { "Day \($0.fromDay) → \($0.toDay) moved\(shortTitle($0.title))" }
            let cap = 5
            if detail.count > cap {
                let extra = detail.count - cap
                detail = Array(detail.prefix(cap)) + ["+ \(extra) more"]
            }
            paragraphs.append(detail.joined(separator: "\n"))
        }

        paragraphs.append("Syncing groups receive these on publish.")
        return paragraphs.joined(separator: "\n\n")
    }

    /// Publish curriculum updates as a new program version (study sync).
    /// The badge dialog hands off to a ConfirmationOverlay presented in
    /// processing mode — the circle spins while the version is cut (the
    /// Claude summary takes a few seconds), then fills green with the
    /// checkmark and the success message (export-flow pattern). The success
    /// message is composed upfront from the already-loaded preview
    /// (ConfirmationOverlay captures `message` at present time).
    private func publishUpdates(programId: String) {
        guard !isPublishingUpdates else { return }
        isPublishingUpdates = true

        overlayManager.present(.confirmationOverlay) {
            ConfirmationOverlay(
                style: .success,
                message: publishSuccessMessage(),
                buttonLabel: "Done",
                isProcessing: $isPublishingUpdates,
                processingMessage: "Publishing updates",
                onDismiss: {
                    overlayManager.dismiss(.confirmationOverlay)
                }
            )
        }

        Task {
            do {
                let result = try await ProgramActions().publishUpdates(programId: programId)
                await MainActor.run {
                    if result.alreadyUpToDate {
                        // Raced with another publish — nothing was cut.
                        overlayManager.dismiss(.confirmationOverlay)
                        isPublishingUpdates = false
                        showAlreadyUpToDateAlert = true
                    } else {
                        // Circle fills green + checkmark; message swaps in.
                        isPublishingUpdates = false
                    }
                }
            } catch {
                await MainActor.run {
                    // Cleanup first, then record — the user just tapped
                    // "Publish updates". Safe to re-run as-is (idempotent).
                    isPublishingUpdates = false
                    overlayManager.dismiss(.confirmationOverlay)
                    state.recordError(
                        error,
                        context: "ProgramHomePage.publishUpdates",
                        surface: true,
                        friendlyMessage: "Couldn't publish updates",
                        retry: { publishUpdates(programId: programId) }
                    )
                }
            }
        }
    }

    /// Success message for the publish confirmation — version + count matrix
    /// from the preview loaded when the badge dialog opened.
    private func publishSuccessMessage() -> AttributedString {
        let programName = program?.name ?? "Study"
        let nextVersion = (publishPreview?.lastPublished?.versionNumber ?? 0) + 1
        var lines = ["**\(programName)** version \(nextVersion) published."]
        if let changes = publishPreview?.changes {
            var matrix: [String] = []
            if !changes.changed.isEmpty { matrix.append("\(changes.changed.count) changed") }
            if !changes.added.isEmpty { matrix.append("\(changes.added.count) added") }
            if !changes.removed.isEmpty { matrix.append("\(changes.removed.count) removed") }
            if !changes.moved.isEmpty { matrix.append("\(changes.moved.count) moved") }
            if !matrix.isEmpty { lines.append(matrix.joined(separator: " · ")) }
        }
        lines.append("Syncing groups are receiving these updates.")
        return AttributedString.safeMarkdown(lines.joined(separator: "\n"))
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
                    // Cleanup first, then record — user just picked a cover image.
                    isUploadingImage = false
                    state.recordError(
                        error,
                        context: "ProgramHomePage.uploadCoverImage",
                        surface: true,
                        friendlyMessage: "Couldn't save the cover image",
                        retry: { uploadCoverImage(image, programId: programId) }
                    )
                }
            }
        }
    }

    // MARK: - Lessons Tab

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
                        .font(Typography.s32)
                        .foregroundColor(.white.opacity(0.3))

                    Text("No lessons yet")
                        .font(Typography.s17Medium)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Add lessons to build your study program")
                        .font(Typography.s14)
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
                .animation(Motion.micro, value: isAddingDay)
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
        .animation(Motion.micro, value: isAddingDay)
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
                detailScreen = .editDay(lessonId: lesson.id)
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
                // User just dragged lessons into a new order — surface it.
                // No retry: the reload below resets the orderedLessons snapshot
                // this function reads from, so a re-run would persist stale order.
                state.recordError(
                    error,
                    context: "ProgramHomePage.persistLessonOrder",
                    surface: true,
                    friendlyMessage: "Couldn't save the new lesson order"
                )
                // Reload to restore the server's order
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
                Log.state.info("Program saved successfully")
            } catch {
                // Revert the optimistic update first, then surface — the user
                // just tapped Done. No retry: a re-run would re-read the edit
                // form @State, which the Done navigation has already left behind.
                if var current = state.programs[programId] {
                    current.name = oldName ?? current.name
                    current.description = oldDescription
                    current.isPublished = oldIsPublished
                    state.programs.upsert(current)
                }
                state.recordError(
                    error,
                    context: "ProgramHomePage.saveProgram",
                    surface: true,
                    friendlyMessage: "Couldn't save program changes"
                )
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
            } catch {
                // User just confirmed the delete — surface it. Retry captures
                // the lesson value, so it re-runs safely after the reload below.
                state.recordError(
                    error,
                    context: "ProgramHomePage.deleteLesson",
                    surface: true,
                    friendlyMessage: "Couldn't delete the lesson",
                    retry: { deleteLesson(lesson, programId: programId) }
                )
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
                _ = try await ProgramActions().addLesson(programId: programId)
                // Refresh to get full program state. Separate catch so a
                // refresh failure after a successful add can't trigger an
                // "add day" retry that would create a duplicate day.
                do {
                    _ = try await ProgramActions().getProgram(id: programId)
                } catch {
                    // Background refresh after the add — console-only.
                    state.recordError(error, context: "ProgramHomePage.addDay (refresh)")
                }
            } catch {
                // User just tapped the add-day button — cleanup, then surface.
                isAddingDay = false
                state.recordError(
                    error,
                    context: "ProgramHomePage.addDay",
                    surface: true,
                    friendlyMessage: "Couldn't add a day",
                    retry: { addDay(programId: programId) }
                )
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
                            detailScreen = nil
                        },
                        onRightLinkTap: {
                            // Block publishing via settings if any lesson lacks an activity.
                            if editIsPublished && !lessonsWithoutActivities.isEmpty {
                                showPublishBlockedAlert = true
                                return
                            }
                            saveProgram(programId: program.id)
                            detailScreen = nil
                        }
                    )
                } else {
                    // Read-only view for non-creators: keep the back chevron
                    // but drop the "Done" link so there's no save affordance.
                    PageTitle.iconTitle(
                        title: "Program",
                        icon: "chevron.left",
                        onIconTap: {
                            detailScreen = nil
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
                        .font(Typography.s32)
                        .foregroundColor(.white.opacity(0.3))

                    Text("No enrollments yet")
                        .font(Typography.s17Medium)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Groups enrolled in this program will appear here")
                        .font(Typography.s14)
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

    /// Sections 1/3/4 of the analytics tab spec (KPI grid, Recent Activity
    /// line, heatmap) — docs/features/analytics/program-analytics-tab.md.
    /// Video row, funnel, content mix, and leaderboards land in Phase C2.
    @ViewBuilder
    private var analyticsContent: some View {
        let analytics = state.programAnalyticsById[programId]

        VStack(alignment: .leading, spacing: 24) {
            if let analytics {
                // Owner rule (2026-07-30): a section with zero data is HIDDEN,
                // not shown as an empty shell. No enrollments — or enrollments
                // with zero engagement anywhere — collapses to the whole-tab
                // empty state.
                if analytics.kpis.totalEnrollments == 0 || !Self.analyticsHasAnyActivity(analytics) {
                    analyticsEmptyState
                } else {
                    analyticsKpiGrid(analytics.kpis)
                    if analytics.topGroups.contains(where: { $0.lessonCompletions > 0 }) {
                        analyticsTopGroupsSection(analytics.topGroups)
                    }
                    if Self.hasRecentActivity(analytics.recent) {
                        analyticsRecentSection(analytics.recent)
                    }
                    if analytics.heatmap.contains(where: { $0.count > 0 }) {
                        analyticsHeatmapSection(analytics.heatmap)
                    }
                    analyticsFreshnessFooter(analytics)
                }
            } else if analyticsLoadFailed {
                analyticsErrorState
            } else {
                analyticsLoadingState
            }
        }
        .padding(.horizontal, 16)
        .task {
            // Cache-first: any cached payload above renders immediately; this
            // refreshes it in the background on every tab select.
            do {
                _ = try await ProgramActions().getProgramAnalytics(programId: programId)
                analyticsLoadFailed = false
            } catch let error as NSError where error.code == NSURLErrorCancelled {
                // Tab switched away mid-fetch — not a failure.
            } catch {
                Log.ui.error("⚠️ ProgramHomePage: analytics load failed: \(error, privacy: .public)")
                analyticsLoadFailed = true
            }
        }
    }

    /// Any engagement signal at all — KPIs, any recent series point, any
    /// heatmap bucket, or any group completion. All-zero payloads render the
    /// whole-tab empty state instead of a wall of zeroed sections.
    private static func analyticsHasAnyActivity(_ analytics: ProgramAnalytics) -> Bool {
        let kpis = analytics.kpis
        return kpis.membersReached > 0
            || kpis.lessonCompletions > 0
            || kpis.videoCompletions > 0
            || kpis.watchSeconds > 0
            || hasRecentActivity(analytics.recent)
            || analytics.heatmap.contains { $0.count > 0 }
            || analytics.topGroups.contains { $0.lessonCompletions > 0 }
    }

    /// Any non-zero point across the week/month/year series. The section is
    /// hidden only when ALL THREE are flat — a single empty period keeps the
    /// section (the toggle's other periods have data) with its per-period
    /// overlay.
    private static func hasRecentActivity(_ recent: ProgramAnalyticsRecent) -> Bool {
        recent.week.contains { $0.count > 0 }
            || recent.month.contains { $0.count > 0 }
            || recent.year.contains { $0.count > 0 }
    }

    // Section 1 — KPI grid (2×2). The spec's "of {total} total" description
    // needs the standard Kpi layout (compact drops description). Explicit
    // rows with expanded, fixed-height cells so every card fills its slot
    // uniformly — LazyVGrid let each card hug its content, leaving ragged
    // widths/heights.
    private let analyticsKpiCardHeight: CGFloat = 116

    private func analyticsKpiGrid(_ kpis: ProgramAnalyticsKpis) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Kpi(
                    value: Double(kpis.membersReached),
                    valueType: .number,
                    label: "Members reached",
                    icon: "person.2",
                    iconColor: .brandPrimary,
                    expand: true
                )
                Kpi(
                    value: Double(kpis.activeEnrollments),
                    valueType: .number,
                    label: "Active enrollments",
                    description: "of \(kpis.totalEnrollments) total",
                    expand: true
                )
            }
            .frame(height: analyticsKpiCardHeight)

            HStack(spacing: 12) {
                Kpi(
                    value: Double(kpis.lessonCompletions),
                    valueType: .number,
                    label: "Lessons completed",
                    expand: true
                )
                Kpi(
                    value: kpis.completionRate * 100,
                    valueType: .percent,
                    label: "Completion rate",
                    expand: true
                )
            }
            .frame(height: analyticsKpiCardHeight)
        }
    }

    // Section 3 — Recent activity: Week · Month · Year toggle + column chart
    // (columns over a line by owner direction 2026-07-30 — discrete daily
    // counts read exactly; a smoothed curve implied values between days).
    // All three series arrive pre-zero-filled in one payload, so the toggle
    // is pure client state (no refetch).
    private func analyticsRecentSection(_ recent: ProgramAnalyticsRecent) -> some View {
        let series: [DayActivityCount] = {
            switch analyticsTimeScale {
            case 1: return recent.month
            case 2: return recent.year
            default: return recent.week
            }
        }()

        // Category labels must be UNIQUE per bar (Swift Charts merges same-
        // label bars): weekday names for the 7-day window, "Jul 1" for the
        // 30-day window, month names for the 12-month window.
        let bars = series.compactMap { day -> BarChartDataPoint? in
            guard let date = DateFormatters.dateKey.date(from: day.date) else { return nil }
            let label: String
            switch analyticsTimeScale {
            case 1: label = DateFormatters.monthDay.string(from: date)
            case 2: label = DateFormatters.monthAbbrev.string(from: date)
            default: label = DateFormatters.weekdayAbbrev.string(from: date)
            }
            return BarChartDataPoint(label: label, value: Double(day.count), color: Color.brandPrimary)
        }
        // The 30-bar month view can't label every bar — mark roughly weekly.
        // Skip the very first bar's mark: hard against the y-axis it truncates
        // to "…".
        let axisValues: [String]? = analyticsTimeScale == 1
            ? bars.enumerated().filter { $0.offset > 0 && $0.offset % 7 == 0 }.map { $0.element.label }
            : nil
        let hasActivity = series.contains { $0.count > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            TabSlider(
                tabs: ["Week", "Month", "Year"],
                selectedIndex: $analyticsTimeScale
            )

            ZStack {
                VerticalBarChart(
                    dataPoints: bars,
                    showValues: analyticsTimeScale == 0 && hasActivity,
                    chartHeight: 200,
                    xAxisValues: axisValues
                )

                if !hasActivity {
                    Text("No activity in this period")
                        .font(Typography.s15Semibold)
                        .foregroundColor(.white.opacity(0.2))
                }
            }
        }
    }

    // Section 4 — heatmap, mirroring MainHome's mapping (HeatMapChart's field
    // names are transposed: bucket.day → week, bucket.hour → day). The server
    // sends only non-zero buckets and the chart's domain is data-driven, so
    // the full 7×24 grid is zero-filled here — sparse data must never drop
    // empty leading/trailing day columns.
    private func analyticsHeatmapSection(_ heatmap: [HeatmapBucket]) -> some View {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var counts: [Int: Int] = [:]
        for bucket in heatmap {
            counts[bucket.day * 24 + bucket.hour] = bucket.count
        }
        var points: [HeatMapDataPoint] = []
        for day in 0..<7 {
            for hour in 0..<24 {
                points.append(HeatMapDataPoint(
                    week: day,
                    day: hour,
                    value: Double(counts[day * 24 + hour] ?? 0),
                    dayLabel: dayLabels[day]
                ))
            }
        }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Activity Heatmap")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            HeatMapChart(
                dataPoints: points,
                showDayLabels: false,
                xLabels: dayLabels,
                yLabels: ["12a", "1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12p", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p"],
                chartHeight: 576
            )

            Text("Last 30 days")
                .font(Typography.s13)
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // Top groups (owner-requested 2026-07-30) — one table card, a row per
    // enrolled group (top 10 by completion): name + member count, trailing
    // completion % over a thin capsule progress fill.
    private func analyticsTopGroupsSection(_ groups: [ProgramTopGroup]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Groups")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.groupId) { index, group in
                    analyticsTopGroupRow(group)
                    if index < groups.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private func analyticsTopGroupRow(_ group: ProgramTopGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.groupName)
                        .font(Typography.s15Semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int((group.completionPct * 100).rounded()))%")
                        .font(Typography.s15Semibold)
                        .foregroundColor(.white)
                    Text("Completion")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: max(0, min(1, group.completionPct)) * geo.size.width)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
    }

    // "As of …" — surfaces the analytics matview refresh honestly, including
    // for cached/offline payloads.
    @ViewBuilder
    private func analyticsFreshnessFooter(_ analytics: ProgramAnalytics) -> some View {
        if let date = analytics.freshAsOfDate {
            Text("As of \(Self.analyticsRelativeFormatter.localizedString(for: date, relativeTo: Date()))")
                .font(Typography.s13)
                .foregroundColor(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private static let analyticsRelativeFormatter = RelativeDateTimeFormatter()

    private var analyticsLoadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 120)
            }
        }
    }

    private var analyticsEmptyState: some View {
        VStack(spacing: 8) {
            Spacer()
                .frame(height: 80)

            Text("No activity yet")
                .font(Typography.s17Bold)
                .foregroundColor(.white.opacity(0.7))

            Text("Analytics appear once groups enroll and members engage.")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var analyticsErrorState: some View {
        VStack(spacing: 8) {
            Spacer()
                .frame(height: 80)

            Text("Couldn't load analytics")
                .font(Typography.s17Bold)
                .foregroundColor(.white.opacity(0.7))

            Text("Pull to refresh to try again.")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.4))

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
    let onPublish: () -> Void

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
                Text("Export & Publish")
                    .font(Typography.s17Bold)
                    .foregroundColor(.white)

                if let data = previewData {
                    // Program name
                    Text(data.name)
                        .font(Typography.s14)
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
                                .font(Typography.s12)
                                .foregroundColor(.white.opacity(0.4))
                            Text("Template: \(template)")
                                .font(Typography.s13)
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
                            .font(Typography.s17Semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandPrimary)
                            )
                    }
                    .disabled(isExporting)

                    Button {
                        onPublish()
                    } label: {
                        Text("Publish")
                            .font(Typography.s17Semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandPrimary)
                            )
                    }
                    .disabled(isExporting)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(Typography.s17Medium)
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
            withAnimation(Motion.pagePushBrisk) { visible = true }
        }
    }

    private func dismiss() {
        withAnimation(Motion.exit) { visible = false }
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
            .font(Typography.s12Semibold)
            .foregroundColor(isPublished ? Color.appBackground : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: isPublished ? "#57DB5D" : "#242A3E"))
            )
    }
}

