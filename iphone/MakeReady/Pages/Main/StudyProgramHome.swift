//
//  StudyProgramHome.swift
//  MakeReady
//
//  Study programs main page - accessed from hamburger menu
//

import SwiftUI
import UniformTypeIdentifiers
import Compression

// MARK: - Program Home Modal Content

/// Separate view to ensure proper re-evaluation when programs binding changes
struct ProgramHomeModalContent: View {
    let overlayManager: OverlayManager
    @Binding var selectedProgramId: String?
    var onDismiss: (() -> Void)?

    var body: some View {
        if let programId = selectedProgramId {
            ProgramHomePage(
                overlayManager: overlayManager,
                programId: programId,
                onShowAddActivityMenu: { existingTypes, callback in
                    overlayManager.present(id: OverlayID.addActivityMenu, priority: .topLevel) {
                        AddActivityMenu(
                            overlayManager: overlayManager,
                            existingActivityTypes: existingTypes,
                            onActivitySelected: { activityType in
                                callback(activityType)
                            }
                        )
                    }
                },
                onDismiss: onDismiss
            )
        } else {
            // ID not set yet - show loading state
            ZStack {
                Color.appBackground
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}

// MARK: - Study Program Home

struct MainPrograms: View {
    let overlayManager: OverlayManager
    let avatarURL: String?
    @Binding var initialTab: Int?

    @Environment(AuthManager.self) var authManager
    @State private var activeTab = 0

    // Program home modal state
    @State private var selectedProgramId: String?

    // Study programs state
    @State private var programToDelete: StudyProgram?
    @State private var showDeleteConfirmation = false
    @State private var deletingProgramId: String? = nil

    // Unenroll state
    @State private var enrollmentToUnenroll: ProgramEnrollment?
    @State private var isProcessingUnenrollment = false
    @State private var unenrolledProgramName = ""

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Refresh state - prevents stacking multiple refresh requests
    @State private var isRefreshing = false

    // Import state
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var showImportPreview = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var importPreviewData: ExportPreviewData?
    @State private var importFileData: Data?
    @State private var isProcessingImport = false

    // Computed properties for state access
    private var programs: [StudyProgram] {
        state.orderedPrograms
    }

    private var isInitialLoading: Bool {
        state.loadingStates.isInitialLoading(.programs)
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Programs", "Enrolled"],
                    activeTab: $activeTab
                ) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Content area
                if activeTab == 0 {
                    programsTabContent
                } else {
                    enrolledTabContent
                }
            }
        }
        .onChange(of: initialTab) { _, newTab in
            if let tab = newTab {
                activeTab = tab
                initialTab = nil
            }
        }
        .onAppear {
            if let tab = initialTab {
                activeTab = tab
                initialTab = nil
            }
        }
        .alert("Delete Program?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                programToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let program = programToDelete {
                    deleteProgram(program)
                }
                programToDelete = nil
            }
        } message: {
            if let program = programToDelete {
                Text("This will permanently delete \"\(program.name)\" and all its lessons.")
            }
        }
        .overlay {
            if showImportPreview {
                ImportConfirmOverlay(
                    isPresented: $showImportPreview,
                    previewData: importPreviewData,
                    isImporting: isImporting,
                    onConfirm: { confirmImport() }
                )
            }
        }
        .alert("Incompatible File", isPresented: $showImportError) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.zip, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }

            guard fileURL.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file."
                showImportError = true
                return
            }

            defer { fileURL.stopAccessingSecurityScopedResource() }

            do {
                let fileData = try Data(contentsOf: fileURL)
                guard let manifest = extractManifestFromZip(fileData) else {
                    importErrorMessage = "This file is not a compatible MakeReady study program. The file must be a .makeready export containing a valid manifest."
                    showImportError = true
                    return
                }

                guard let format = manifest["format"] as? String,
                      format == "makeready-program-v1",
                      let program = manifest["program"] as? [String: Any] else {
                    importErrorMessage = "This file format is not supported. Please use a file exported from MakeReady."
                    showImportError = true
                    return
                }

                // Build preview data from manifest
                let lessons = program["lessons"] as? [[String: Any]] ?? []
                let allActivities = lessons.flatMap { ($0["activities"] as? [[String: Any]]) ?? [] }
                let activityTypes = allActivities.compactMap { $0["type"] as? String }

                importPreviewData = ExportPreviewData(
                    name: program["name"] as? String ?? "Program",
                    days: program["days"] as? Int ?? lessons.count,
                    activities: allActivities.count,
                    reads: activityTypes.filter { $0 == "READ" }.count,
                    videos: activityTypes.filter { $0 == "VIDEO" }.count,
                    userInputs: activityTypes.filter { $0 == "USER_INPUT" }.count,
                    readBlocks: allActivities.reduce(0) { $0 + (($1["readBlocks"] as? [[String: Any]])?.count ?? 0) },
                    scriptureRefs: allActivities.reduce(0) { $0 + (($1["sourceReferences"] as? [[String: Any]])?.count ?? 0) },
                    templateName: (program["template"] as? [String: Any])?["name"] as? String
                )
                importFileData = fileData
                showImportPreview = true

            } catch {
                importErrorMessage = "Failed to read the selected file."
                showImportError = true
            }

        case .failure(let error):
            NSLog("❌ File picker error: \(error)")
        }
    }

    /// Extract manifest.json from a ZIP file using central directory (reliable with data descriptors)
    private func extractManifestFromZip(_ zipData: Data) -> [String: Any]? {
        let count = zipData.count
        guard count > 22 else { return nil }

        // Find End of Central Directory record (scan backwards)
        let eocdSig: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        var eocdOffset = -1
        for i in stride(from: count - 22, through: max(0, count - 65557), by: -1) {
            if [UInt8](zipData[i..<i+4]) == eocdSig {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return nil }

        // Read central directory offset from EOCD
        let cdOffset = Int(zipData.readUInt32(at: eocdOffset + 16))
        let cdEntries = Int(zipData.readUInt16(at: eocdOffset + 10))

        // Scan central directory entries for manifest.json
        let cdSig: [UInt8] = [0x50, 0x4B, 0x01, 0x02]
        var offset = cdOffset

        for _ in 0..<cdEntries {
            guard offset + 46 <= count else { break }
            guard [UInt8](zipData[offset..<offset+4]) == cdSig else { break }

            let compressionMethod = zipData.readUInt16(at: offset + 10)
            let compressedSize = Int(zipData.readUInt32(at: offset + 20))
            let uncompressedSize = Int(zipData.readUInt32(at: offset + 24))
            let filenameLen = Int(zipData.readUInt16(at: offset + 28))
            let extraLen = Int(zipData.readUInt16(at: offset + 30))
            let commentLen = Int(zipData.readUInt16(at: offset + 32))
            let localHeaderOffset = Int(zipData.readUInt32(at: offset + 42))

            let fnStart = offset + 46
            guard fnStart + filenameLen <= count else { break }
            let filename = String(data: zipData[fnStart..<fnStart + filenameLen], encoding: .utf8) ?? ""

            if filename == "manifest.json" {
                // Read local file header to find actual data offset
                guard localHeaderOffset + 30 <= count else { return nil }
                let localFnLen = Int(zipData.readUInt16(at: localHeaderOffset + 26))
                let localExtraLen = Int(zipData.readUInt16(at: localHeaderOffset + 28))
                let dataStart = localHeaderOffset + 30 + localFnLen + localExtraLen

                guard dataStart + compressedSize <= count else { return nil }
                let fileBytes = zipData[dataStart..<dataStart + compressedSize]

                var jsonData: Data
                if compressionMethod == 0 {
                    jsonData = Data(fileBytes)
                } else if compressionMethod == 8 {
                    // Deflate — decompress with zlib
                    guard uncompressedSize > 0 else { return nil }
                    var decompressed = Data(count: uncompressedSize)
                    let result = decompressed.withUnsafeMutableBytes { destBuf in
                        Data(fileBytes).withUnsafeBytes { srcBuf in
                            compression_decode_buffer(
                                destBuf.bindMemory(to: UInt8.self).baseAddress!,
                                uncompressedSize,
                                srcBuf.bindMemory(to: UInt8.self).baseAddress!,
                                compressedSize,
                                nil,
                                COMPRESSION_ZLIB
                            )
                        }
                    }
                    guard result > 0 else { return nil }
                    jsonData = decompressed.prefix(result)
                } else {
                    return nil
                }

                return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            }

            // Next central directory entry
            offset = fnStart + filenameLen + extraLen + commentLen
        }

        return nil
    }

    private func confirmImport() {
        guard let fileData = importFileData, !isImporting else { return }
        isImporting = true
        isProcessingImport = true

        // Show confirmation overlay immediately
        let programName = importPreviewData?.name ?? "Study Program"
        let message = AttributedString.safeMarkdown("**\(programName)** has been successfully imported and is ready to use.")

        showImportPreview = false

        overlayManager.present(id: OverlayID.confirmationOverlay, priority: .topLevel) {
            ConfirmationOverlay(
                style: .success,
                message: message,
                buttonLabel: "Done",
                isProcessing: $isProcessingImport,
                processingMessage: "Importing study program",
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                }
            )
        }

        Task {
            defer {
                isImporting = false
                importFileData = nil
            }
            do {
                try await ProgramActions().importProgram(fileData: fileData)
                NSLog("✅ Program imported successfully")
                try? await ProgramActions().loadPrograms(forceRefresh: true)
                await MainActor.run { isProcessingImport = false }
            } catch {
                NSLog("❌ Failed to import program: \(error)")
                await MainActor.run {
                    isProcessingImport = false
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                }
            }
        }
    }

    // MARK: - Programs Tab

    private var programsTabContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                if isInitialLoading && !state.hasCachedPrograms {
                    VStack(spacing: 4) {
                        SkeletonCardStudy()
                        SkeletonCardStudy()
                    }
                } else if programs.isEmpty {
                    emptyStateView
                } else {
                    programsList
                        .environment(\.swipeState, swipeState)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollDisabled(swipeState.isSwiping)
        .refreshable {
            guard !isRefreshing else { return }
            isRefreshing = true
            Task.detached { @MainActor in
                defer { isRefreshing = false }
                await loadPrograms(forceRefresh: true)
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Enrolled Tab

    private var allEnrollments: [ProgramEnrollment] {
        // Collect all program enrollments across all programs
        var result: [ProgramEnrollment] = []
        for program in programs {
            result.append(contentsOf: state.programEnrollmentsFor(programId: program.id))
        }
        return result.sorted { $0.startDate > $1.startDate }
    }

    private var enrolledTabContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                if allEnrollments.isEmpty {
                    enrolledEmptyState
                } else {
                    ForEach(allEnrollments) { enrollment in
                        let program = state.programs[enrollment.studyProgramId]
                        let totalLessons = program?.lessons?.count ?? program?.days ?? 0
                        let daysSinceStart = max(0, Calendar.current.dateComponents([.day], from: enrollment.startDate, to: Date()).day ?? 0)
                        let lessonsLeft = max(0, totalLessons - daysSinceStart)
                        SwipeableCard(
                            slideButtons: [
                                SlideButton(icon: "trash", style: .delete) {
                                    presentUnenrollModal(enrollment: enrollment)
                                }
                            ],
                            onTap: {
                                openEnrollmentLessons(enrollment, program: program)
                            }
                        ) {
                            CardEnrolled(
                                data: CardEnrolledData(
                                    id: enrollment.id,
                                    studyTitle: program?.name ?? "Study",
                                    groupName: enrollment.group?.name ?? "Group",
                                    startDate: enrollment.startDate,
                                    endDate: enrollment.endDate,
                                    lessonsLeft: lessonsLeft,
                                    studyImageURL: program?.coverImageUrl,
                                    groupImageURL: enrollment.group?.coverImageUrl,
                                    onTap: nil
                                )
                            )
                        }
                    }
                    .environment(\.swipeState, swipeState)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollDisabled(swipeState.isSwiping)
        .task {
            await loadAllEnrollments()
        }
        .refreshable {
            await loadAllEnrollments(forceRefresh: true)
        }
    }

    private var enrolledEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Enrollments")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Enroll a group in a study program to get started")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Study Programs")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Create your first study program to get started")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Programs List

    private var programsList: some View {
        ForEach(programs, id: \.id) { program in
            let isDeleting = deletingProgramId == program.id

            SwipeableCard(
                slideButtons: [
                    SlideButton(icon: "trash", style: .delete) {
                        programToDelete = program
                        showDeleteConfirmation = true
                    }
                ],
                isSwipeEnabled: !isDeleting,
                onTap: {
                    NSLog("👆 Program card tapped: id=\(program.id)")
                    selectedProgramId = program.id
                    presentProgramHome()
                }
            ) {
                CardStudy(
                    data: cardStudyData(from: program)
                )
            }
            .opacity(isDeleting ? 0 : 1)
            .scaleEffect(y: isDeleting ? 0.01 : 1, anchor: .top)
            .frame(maxHeight: isDeleting ? 0 : .infinity)
            .clipped()
            .allowsHitTesting(!isDeleting)
        }
    }

    private func presentProgramHome() {
        // Prevent double-taps while modal is already presented
        guard !overlayManager.isPresented(id: OverlayID.programHome) else { return }

        overlayManager.presentModal(id: OverlayID.programHome) {
            ProgramHomeModalContent(
                overlayManager: overlayManager,
                selectedProgramId: $selectedProgramId,
                onDismiss: {
                    // No reload needed - cache is already updated by ProgramHomePage
                    overlayManager.dismiss(id: OverlayID.programHome)
                }
            )
        }
    }

    // MARK: - Helpers

    private func cardStudyData(from program: StudyProgram) -> CardStudyData {
        let lessonCount = program.lessons?.count ?? program.days
        let enrollmentCount = program._count?.enrollments

        let isPublished = program.isPublished ?? false
        var metadata: [DataItem] = [
            DataItem(icon: "calendar", value: "\(lessonCount) days")
        ]

        // Add enrollment count or loading skeleton
        // Show skeleton only if we're refreshing and don't have cached count yet
        let isLoadingEnrollments = state.loadingStates.isLoading(.programs) && enrollmentCount == nil

        if isLoadingEnrollments {
            // Show loading skeleton while fetching enrollment data
            metadata.append(DataItem(loading: 80))
        } else if let count = enrollmentCount, count > 0 {
            // Show actual count
            metadata.append(DataItem(number: "\(count)", label: count == 1 ? "enrollment" : "enrollments", isPurple: false))
        }

        // Badge always last
        metadata.append(DataItem(
            badge: isPublished ? "Published" : "Draft",
            color: isPublished ? Color(hex: "#57DB5D") : Color(hex: "#6E7079"),
            textColor: isPublished ? Color(hex: "#234D2E") : Color(hex: "#D3D4D7")
        ))

        let imageStyle: CardImageStyle
        if let coverUrl = program.coverImageUrl, !coverUrl.isEmpty {
            imageStyle = .photo(imageURL: coverUrl)
        } else {
            imageStyle = .icon(systemName: "book.fill")
        }

        return CardStudyData(
            id: program.id,
            title: program.name,
            description: program.description,
            type: program.defaultActivity?.rawValue ?? "",
            imageStyle: imageStyle,
            metadata: metadata,
            status: .confirmed,
            onTap: nil
        )
    }

    // MARK: - Actions

    private func loadPrograms(forceRefresh: Bool) async {
        NSLog("📚 MainPrograms: Loading programs (forceRefresh: \(forceRefresh))...")
        do {
            try await ProgramActions().loadPrograms(forceRefresh: forceRefresh)
            NSLog("📚 MainPrograms: Programs loaded - \(programs.count) items")
        } catch {
            NSLog("❌ MainPrograms: Failed to load programs: \(error)")
        }
    }

    private func openEnrollmentLessons(_ enrollment: ProgramEnrollment, program: StudyProgram?) {
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
                overlayManager: overlayManager,
                titleOverride: "Lessons"
            )
        }
    }

    private func loadAllEnrollments(forceRefresh: Bool = false) async {
        let actions = ProgramActions()
        for program in programs {
            let hasEnrollments = (program._count?.enrollments ?? 0) > 0
            let hasCached = state.hasCachedProgramEnrollments(programId: program.id)
            if hasEnrollments && (!hasCached || forceRefresh) {
                do {
                    _ = try await actions.getProgramEnrollments(programId: program.id, forceRefresh: forceRefresh)
                } catch {
                    NSLog("⚠️ Failed to load enrollments for program \(program.id): \(error)")
                }
            }
        }
    }

    private func presentUnenrollModal(enrollment: ProgramEnrollment) {
        overlayManager.presentModal(id: OverlayID.unenrollOptions) {
            UnenrollOptionsModal(
                enrollmentId: enrollment.id,
                programName: state.programs[enrollment.studyProgramId]?.name ?? "Study Program",
                programImageUrl: state.programs[enrollment.studyProgramId]?.coverImageUrl,
                onConfirm: { option in
                    handleEnrollmentUnenrollConfirmed(enrollment: enrollment, option: option)
                },
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.unenrollOptions)
                }
            )
        }
    }

    private func handleEnrollmentUnenrollConfirmed(enrollment: ProgramEnrollment, option: UnenrollOption) {
        overlayManager.dismiss(id: OverlayID.unenrollOptions)

        unenrolledProgramName = state.programs[enrollment.studyProgramId]?.name ?? "the program"
        isProcessingUnenrollment = true

        UnenrollConfirmation.present(
            overlayManager: overlayManager,
            option: option,
            programName: unenrolledProgramName,
            isProcessing: $isProcessingUnenrollment,
            onDismiss: {
                overlayManager.dismiss(id: OverlayID.confirmationOverlay)
            }
        )

        Task {
            do {
                switch option {
                case .fullRemoval:
                    try await EnrollmentActions().deleteEnrollment(id: enrollment.id)
                case .cancelFuture:
                    try await EnrollmentActions().cancelFutureLessons(id: enrollment.id)
                }
                // Reload enrollments for the affected program
                _ = try? await ProgramActions().getProgramEnrollments(programId: enrollment.studyProgramId, forceRefresh: true)
                await MainActor.run {
                    isProcessingUnenrollment = false
                }
            } catch {
                await MainActor.run {
                    isProcessingUnenrollment = false
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                    NSLog("❌ Failed to unenroll: \(error)")
                }
            }
        }
    }

    private func deleteProgram(_ program: StudyProgram) {
        Task {
            do {
                try await ProgramActions().deleteProgram(id: program.id)
                NSLog("🗑️ Deleted program: \(program.name)")

                // Animate the card out
                withAnimation(.easeInOut(duration: 0.3)) {
                    deletingProgramId = program.id
                }

                // Wait for animation to finish, then clear
                try? await Task.sleep(nanoseconds: 350_000_000)
                deletingProgramId = nil
            } catch {
                NSLog("❌ Failed to delete program: \(error)")
            }
        }
    }
}

// MARK: - ZIP Data Helpers

extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        self.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self) }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        self.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
    }
}

// MARK: - Import Confirm Overlay

private struct ImportConfirmOverlay: View {
    @Binding var isPresented: Bool
    let previewData: ExportPreviewData?
    let isImporting: Bool
    let onConfirm: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                Color.black.opacity(0.5)
            }
            .opacity(visible ? 1 : 0)
            .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text("Import Program")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                if let data = previewData {
                    Text(data.name)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))

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

                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("Confirm Import")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#6c47ff"))
                            )
                    }
                    .disabled(isImporting)

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

#Preview {
    MainPrograms(
        overlayManager: OverlayManager(),
        avatarURL: nil,
        initialTab: .constant(nil)
    )
    .environment(AuthManager())
}
