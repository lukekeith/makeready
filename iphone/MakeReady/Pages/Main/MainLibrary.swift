//
//  MainLibrary.swift
//  MakeReady
//
//  Library tab page content - Programs, Media
//

import SwiftUI
import UniformTypeIdentifiers
import Compression

// MARK: - Sort Options

enum LibrarySortOption: String, CaseIterable {
    case newestFirst = "Newest first"
    case mostPopular = "Most popular"
    case alphabetical = "A - Z"
}

// MARK: - Filter Dropdown Identity

/// Which filter dropdown panel is currently expanded above the page content.
enum LibraryDropdown {
    case programsTags
    case programsLeaders
    case mediaTags
    case mediaLeaders
    case mediaType
    case mediaTime
}

// MARK: - Media Filter Enums

enum MediaTypeFilter: String, CaseIterable {
    case all = "All"
    case video = "Video"
    case images = "Images"
    case audio = "Audio"

    /// Maps to the API ?type= query parameter
    var apiValue: String? {
        switch self {
        case .all: return nil
        case .video: return "video"
        case .images: return "photo"
        case .audio: return "audio"
        }
    }
}

enum MediaTimeFilter: String, CaseIterable {
    case allTime = "All time"
    case lastWeek = "Last 7 days"
    case lastMonth = "Last 30 days"
    case last3Months = "Last 90 days"

    /// Cutoff date for filtering
    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .allTime: return nil
        case .lastWeek: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .lastMonth: return calendar.date(byAdding: .day, value: -30, to: Date())
        case .last3Months: return calendar.date(byAdding: .day, value: -90, to: Date())
        }
    }
}

enum MediaSortOption: String, CaseIterable {
    case newestFirst = "Newest first"
    case mostUsed = "Most used"
    case alphabetical = "A - Z"
}

struct MainLibrary: View {
    let overlayManager: OverlayManager
    @State private var activeTab = 0

    @Environment(AuthManager.self) var authManager

    // Use centralized state
    private var state: AppState { AppState.shared }

    // Program state
    @State private var selectedProgramId: String?
    @State private var programToDelete: StudyProgram?
    @State private var showDeleteConfirmation = false
    @State private var deletingProgramId: String? = nil
    @StateObject private var swipeState = SwipeState()
    @State private var isRefreshing = false

    // Search & filter state
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTags: Set<String> = []
    @State private var selectedLeaders: Set<String> = []
    @State private var sortOption: LibrarySortOption = .newestFirst

    // Persisted filter state — synced to server via UserPreference
    private var programsFilter: FilterState { FilterStateManager.shared.state(for: "library.programs") }
    private var mediaFilter: FilterState { FilterStateManager.shared.state(for: "library.media") }

    // Tags state (loaded from API)
    @State private var allTags: [String] = []
    /// Group leaders in the org with program/media counts. Loaded once on
    /// first appear, shared between Programs + Media tabs.
    @State private var allLeaders: [GroupLeader] = []

    // Library filter dropdown expansion state. Both tabs share one enum so
    // only a single panel can be open at a time.
    @State private var expandedDropdown: LibraryDropdown? = nil

    // Media tab state
    @State private var selectedMediaType: MediaTypeFilter = .all
    @State private var selectedTimeFilter: MediaTimeFilter = .allTime
    @State private var selectedMediaTags: Set<String> = []
    @State private var selectedMediaLeaders: Set<String> = []
    @State private var allMediaTags: [String] = []
    @State private var mediaSortOption: MediaSortOption = .newestFirst
    @State private var mediaToDelete: MediaLibraryItem?
    @State private var showMediaDeleteConfirmation = false
    @State private var deletingMediaId: String? = nil
    @State private var isMediaRefreshing = false
    @State private var mediaSearchText = ""
    @State private var isMediaSearchActive = false
    @FocusState private var isMediaSearchFocused: Bool
    @State private var mediaSearchDebounceTask: Task<Void, Never>?

    // Media grid coordinator reference (for restoring hidden cells)
    @State private var mediaGridCoordinator: AnyObject?

    // Import state
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var showImportPreview = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var importPreviewData: ExportPreviewData?
    @State private var importFileData: Data?
    @State private var isProcessingImport = false

    // Computed
    private var programs: [StudyProgram] {
        state.orderedPrograms
    }

    private var isInitialLoading: Bool {
        state.loadingStates.isInitialLoading(.programs)
    }

    /// Programs with active enrollments
    private var enrolledPrograms: [StudyProgram] {
        let activeProgramIds = Set(
            programs.flatMap { program in
                state.programEnrollmentsFor(programId: program.id)
                    .filter { $0.isActive }
                    .map { _ in program.id }
            }
        )
        return programs.filter { activeProgramIds.contains($0.id) }
    }

    /// Filtered + sorted programs for "Browse all"
    private var browsePrograms: [StudyProgram] {
        var result = programs

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                ($0.description?.lowercased().contains(query) ?? false) ||
                ($0.tags?.contains { $0.lowercased().contains(query) } ?? false)
            }
        }

        // Tag filter is handled server-side via ?tag= query param

        // Sort
        switch sortOption {
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .mostPopular:
            result.sort { ($0._count?.enrollments ?? 0) > ($1._count?.enrollments ?? 0) }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }

    // Media computed properties
    private var isMediaLoading: Bool {
        state.loadingStates.isInitialLoading(.media)
    }

    /// Media items filtered by time and sorted.
    /// One sort per evaluation (Phase 4.5) — this used to take orderedMedia
    /// (already sorted newest-first) and then sort the whole array again,
    /// every render.
    private var filteredMedia: [MediaLibraryItem] {
        var result: [MediaLibraryItem]

        switch mediaSortOption {
        case .newestFirst:
            result = state.orderedMedia  // already newest-first
        case .mostUsed:
            result = state.mediaLibrary.all.sorted { $0.usageCount > $1.usageCount }
        case .alphabetical:
            result = state.mediaLibrary.all.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        // Time filter (client-side)
        if let cutoff = selectedTimeFilter.cutoffDate {
            result = result.filter { $0.createdAt >= cutoff }
        }

        return result
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Programs", "Media"],
                    activeTab: $activeTab
                ) {
                    HStack(spacing: 8) {
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            overlayManager.presentMenu(id: OverlayID.libraryAddMenu) {
                                ActionCardMenu(
                                    title: "Create New",
                                    items: [
                                        ActionCardMenuItem(icon: "book.fill", title: "Study Program", description: "Create a new study program") {
                                            overlayManager.dismiss(id: OverlayID.libraryAddMenu) {
                                                overlayManager.presentModal(id: OverlayID.createProgram) {
                                                    CreateProgramPage(overlayManager: overlayManager)
                                                }
                                            }
                                        },
                                        ActionCardMenuItem(icon: "photo.on.rectangle", title: "Media", description: "Upload photos or videos") {
                                            // TODO: Media upload flow
                                        },
                                    ]
                                )
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if activeTab == 0 {
                    programsTabContent
                } else {
                    mediaTabContent
                }
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
        .alert("Delete Media?", isPresented: $showMediaDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                mediaToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let media = mediaToDelete {
                    deleteMedia(media)
                }
                mediaToDelete = nil
            }
        } message: {
            if let media = mediaToDelete {
                Text("This will permanently delete \"\(media.displayTitle)\".")
            }
        }
        .onChange(of: selectedTags) { _, _ in
            syncProgramFiltersToState()
            Task { await loadPrograms(forceRefresh: true) }
        }
        .onChange(of: selectedLeaders) { _, _ in
            syncProgramFiltersToState()
            Task { await loadPrograms(forceRefresh: true) }
        }
        .onChange(of: sortOption) { _, _ in
            syncProgramFiltersToState()
        }
        .onChange(of: selectedMediaTags) { _, _ in
            syncMediaFiltersToState()
            Task {
                if mediaSearchText.isEmpty {
                    await loadMedia(forceRefresh: true)
                } else {
                    await searchMedia(query: mediaSearchText)
                }
            }
        }
        .onChange(of: selectedMediaLeaders) { _, _ in
            syncMediaFiltersToState()
            Task {
                if mediaSearchText.isEmpty {
                    await loadMedia(forceRefresh: true)
                } else {
                    await searchMedia(query: mediaSearchText)
                }
            }
        }
        .onChange(of: selectedMediaType) { _, _ in
            syncMediaFiltersToState()
            Task {
                if mediaSearchText.isEmpty {
                    await loadMedia(forceRefresh: true)
                } else {
                    await searchMedia(query: mediaSearchText)
                }
            }
        }
        .onChange(of: selectedTimeFilter) { _, _ in
            syncMediaFiltersToState()
        }
        .onChange(of: mediaSortOption) { _, _ in
            syncMediaFiltersToState()
        }
        .task {
            await loadFiltersFromServer()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.zip, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        // Watch for `.makeready` file open requests routed through the deep-link
        // pipeline (system file association from Files/Mail/Messages/etc.).
        .onAppear {
            handlePendingImportDeepLink()
        }
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, _ in
            handlePendingImportDeepLink()
        }
    }

    // MARK: - Programs Tab

    private var programsTabContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer for search + filter-row overlay (always shown).
                    Color.clear.frame(height: 100)

                    if isInitialLoading && !state.hasCachedPrograms {
                        VStack(spacing: 12) {
                            SkeletonCardProgramFull()
                            SkeletonCardProgramFull()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    } else if programs.isEmpty {
                        programsEmptyState
                    } else {
                        if !isSearchActive && searchText.isEmpty && selectedTags.isEmpty && selectedLeaders.isEmpty && !enrolledPrograms.isEmpty {
                            currentlyEnrolledSection
                                .padding(.top, 20)
                        }

                        browseAllSection
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 100)
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)

                    Color.black
                }
            )
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

            // Fixed search + tags overlay with blur
            VStack(spacing: 0) {
                SearchField(
                    isActive: $isSearchActive,
                    searchText: $searchText,
                    isFocused: $isSearchFocused,
                    placeholder: "Search studies, tags, authors...",
                    onClose: { searchText = "" },
                    onClear: { searchText = "" }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                programsFilterRow
                    .padding(.top, 12)
            }
            .padding(.bottom, 8)
        }
        .task {
            // Tags + leaders are reloaded on selection change too via
            // loadPrograms; this initial load is for the very first appear.
            if allTags.isEmpty {
                do {
                    allTags = try await ProgramActions().loadAllTags()
                } catch {
                    NSLog("⚠️ Failed to load tags: \(error)")
                }
            }
            if allLeaders.isEmpty {
                do {
                    allLeaders = try await ProgramActions().loadGroupLeaders()
                } catch {
                    NSLog("⚠️ Failed to load group leaders: \(error)")
                }
            }
        }
        // Tap-outside-the-row scrim + dropdown panel. Rendered as an overlay
        // anchored to the top of programsTabContent so it doesn't push the
        // program list down. Padding is sized to clear the search + trigger
        // row above.
        .overlay(alignment: .top) {
            programsDropdownOverlay
        }
    }

    /// Horizontal row of dropdown triggers for the Programs tab.
    private var programsFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipDropdownTrigger(
                    label: programsTagsLabel,
                    isActive: !selectedTags.isEmpty
                ) {
                    expandedDropdown = (expandedDropdown == .programsTags) ? nil : .programsTags
                }
                FilterChipDropdownTrigger(
                    label: programsLeadersLabel,
                    isActive: !selectedLeaders.isEmpty
                ) {
                    expandedDropdown = (expandedDropdown == .programsLeaders) ? nil : .programsLeaders
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var programsDropdownOverlay: some View {
        if expandedDropdown == .programsTags || expandedDropdown == .programsLeaders {
            VStack(spacing: 0) {
                // Spacer matches the search + trigger-row stack at the top of
                // programsTabContent (search ~48 + filter row ~40 + paddings ~12).
                // The overlay anchors to programsTabContent.top, so no need to
                // account for PageHeader height.
                Color.clear.frame(height: 108)

                if expandedDropdown == .programsTags {
                    FilterChipDropdownPanel(
                        items: allTags.map { FilterChipDropdownItem(id: $0, label: $0) },
                        selectedIds: selectedTags,
                        emptyMessage: "No tags have been added to your programs yet.",
                        onToggle: { id in
                            if selectedTags.contains(id) {
                                selectedTags.remove(id)
                            } else {
                                selectedTags.insert(id)
                            }
                        },
                        onClearAll: { selectedTags.removeAll() }
                    )
                    .padding(.horizontal, 16)
                } else if expandedDropdown == .programsLeaders {
                    FilterChipDropdownPanel(
                        items: allLeaders.map {
                            FilterChipDropdownItem(id: $0.id, label: "\($0.displayName) (\($0.programCount))")
                        },
                        selectedIds: selectedLeaders,
                        emptyMessage: "You are the only group leader in this org.",
                        onToggle: { id in
                            if selectedLeaders.contains(id) {
                                selectedLeaders.remove(id)
                            } else {
                                selectedLeaders.insert(id)
                            }
                        },
                        onClearAll: { selectedLeaders.removeAll() }
                    )
                    .padding(.horizontal, 16)
                }
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(.keyboard)
            .background(dropdownDimLayer)
        }
    }

    private var programsTagsLabel: String {
        if selectedTags.isEmpty { return "All tags" }
        if selectedTags.count == 1 { return selectedTags.first! }
        return "\(selectedTags.count) tags"
    }

    private var programsLeadersLabel: String {
        if selectedLeaders.isEmpty { return "All leaders" }
        if selectedLeaders.count == 1 {
            let id = selectedLeaders.first!
            if id == authManager.currentUser?.id { return "My content" }
            if let leader = allLeaders.first(where: { $0.id == id }) { return leader.displayName }
            return "1 group leader"
        }
        return "\(selectedLeaders.count) group leaders"
    }

    private var programsEmptyState: some View {
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

    // MARK: - Currently Enrolled Section

    private var currentlyEnrolledSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Currently enrolled")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(enrolledPrograms.count) active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.brandPrimary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(enrolledPrograms, id: \.id) { program in
                        CardStudyMini(
                            data: CardStudyData(
                                id: program.id,
                                title: program.name,
                                description: nil,
                                type: nil,
                                imageStyle: program.coverImageUrl.flatMap { url in
                                    !url.isEmpty ? .photo(imageURL: url) : nil
                                } ?? .icon(systemName: "book.fill"),
                                metadata: [DataItem(icon: "clock", value: "\(program.days)")],
                                status: .confirmed,
                                onTap: {
                                    selectedProgramId = program.id
                                    presentProgramHome()
                                }
                            )
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Browse All Section

    private var browseAllSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Browse all")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Menu {
                    ForEach(LibrarySortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if option == sortOption {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOption.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)

            if browsePrograms.isEmpty {
                VStack(spacing: 12) {
                    Text("No programs found")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(browsePrograms, id: \.id) { program in
                        let isDeleting = deletingProgramId == program.id
                        let isOwn = program.isEditable(by: authManager.currentUser?.id)

                        SwipeableCard(
                            slideButtons: isOwn ? [
                                SlideButton(icon: "trash", style: .delete) {
                                    programToDelete = program
                                    showDeleteConfirmation = true
                                }
                            ] : [],
                            isSwipeEnabled: isOwn && !isDeleting,
                            onTap: {
                                selectedProgramId = program.id
                                presentProgramHome()
                            }
                        ) {
                            CardProgramFull(data: cardProgramFullData(from: program))
                        }
                        .opacity(isDeleting ? 0 : 1)
                        .scaleEffect(y: isDeleting ? 0.01 : 1, anchor: .top)
                        .frame(maxHeight: isDeleting ? 0 : .infinity)
                        .clipped()
                        .allowsHitTesting(!isDeleting)
                    }
                }
                .padding(.horizontal, 16)
                .environment(\.swipeState, swipeState)
            }
        }
    }

    // MARK: - Helpers

    private func presentProgramHome() {
        guard !overlayManager.isPresented(id: OverlayID.programHome) else { return }

        overlayManager.presentModal(id: OverlayID.programHome) {
            ProgramHomeModalContent(
                overlayManager: overlayManager,
                selectedProgramId: $selectedProgramId,
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.programHome)
                }
            )
        }
    }

    private func cardProgramFullData(from program: StudyProgram) -> CardProgramFullData {
        CardProgramFullData(
            id: program.id,
            title: program.name,
            description: program.description,
            coverImageUrl: program.coverImageUrl,
            tags: program.tags ?? [],
            days: program.days,
            enrollmentCount: program._count?.enrollments,
            authorName: authorName(for: program),
            createdAt: program.createdAt,
            isPublished: program.isPublished ?? false,
            onTap: nil
        )
    }

    /// Resolve the creator's display name for a program card. Prefers a
    /// matching entry in `allLeaders` (loaded with the org's group leaders),
    /// falls back to the current user's name when the creator IS the current
    /// user, and otherwise returns nil so the card simply omits the byline
    /// rather than misattributing authorship.
    private func authorName(for program: StudyProgram) -> String? {
        guard let creatorId = program.creatorId else { return nil }
        if let leader = allLeaders.first(where: { $0.id == creatorId }) {
            return leader.displayName
        }
        if creatorId == authManager.currentUser?.id {
            return authManager.currentUser?.name
        }
        return nil
    }

    // MARK: - Media Tab

    private var mediaTabContent: some View {
        ZStack(alignment: .top) {
            if isMediaLoading && !state.hasCachedMedia {
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 116)
                        LazyVGrid(columns: mediaGridColumns, spacing: 2) {
                            ForEach(0..<9, id: \.self) { _ in
                                SkeletonCardMediaFull()
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 116)

                        Color.black
                    }
                )
            } else if state.orderedMedia.isEmpty {
                mediaEmptyState
            } else {
                MediaLibraryGrid(
                    items: filteredMedia,
                    topInset: 116,
                    onItemSelected: { item, sourceFrame, restore in
                        presentMediaDetail(item: item, sourceFrame: sourceFrame, restoreGridCell: restore)
                    },
                    onNearEnd: {
                        Task { await loadMoreMedia() }
                    }
                )
            }

            // Fixed search + filter overlay
            VStack(spacing: 0) {
                SearchField(
                    isActive: $isMediaSearchActive,
                    searchText: $mediaSearchText,
                    isFocused: $isMediaSearchFocused,
                    placeholder: "Search media library",
                    onClose: {
                        mediaSearchText = ""
                        Task { await loadMedia(forceRefresh: true) }
                    },
                    onClear: {
                        mediaSearchText = ""
                        Task { await loadMedia(forceRefresh: true) }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                mediaFilterRow
                    .padding(.top, 12)
            }
            .padding(.bottom, 8)
        }
        .task {
            await loadMedia(forceRefresh: false)
            if allMediaTags.isEmpty {
                do {
                    allMediaTags = try await MediaActions().loadAllMediaTags()
                } catch {
                    NSLog("⚠️ Failed to load media tags: \(error)")
                }
            }
            if allLeaders.isEmpty {
                do {
                    allLeaders = try await ProgramActions().loadGroupLeaders()
                } catch {
                    NSLog("⚠️ Failed to load group leaders: \(error)")
                }
            }
        }
        .overlay(alignment: .top) {
            mediaDropdownOverlay
        }
        .onChange(of: mediaSearchText) { _, newValue in
            mediaSearchDebounceTask?.cancel()
            mediaSearchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if newValue.isEmpty {
                    await loadMedia(forceRefresh: true)
                } else {
                    await searchMedia(query: newValue)
                }
            }
        }
    }

    /// Horizontal row of dropdown triggers for the Media tab.
    private var mediaFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipDropdownTrigger(
                    label: mediaTagsLabel,
                    isActive: !selectedMediaTags.isEmpty
                ) {
                    expandedDropdown = (expandedDropdown == .mediaTags) ? nil : .mediaTags
                }
                FilterChipDropdownTrigger(
                    label: mediaLeadersLabel,
                    isActive: !selectedMediaLeaders.isEmpty
                ) {
                    expandedDropdown = (expandedDropdown == .mediaLeaders) ? nil : .mediaLeaders
                }
                FilterChipDropdownTrigger(
                    label: selectedMediaType.rawValue,
                    isActive: selectedMediaType != .all
                ) {
                    expandedDropdown = (expandedDropdown == .mediaType) ? nil : .mediaType
                }
                FilterChipDropdownTrigger(
                    label: selectedTimeFilter.rawValue,
                    isActive: selectedTimeFilter != .allTime
                ) {
                    expandedDropdown = (expandedDropdown == .mediaTime) ? nil : .mediaTime
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var mediaDropdownOverlay: some View {
        let isMediaDropdownOpen = expandedDropdown == .mediaTags
            || expandedDropdown == .mediaLeaders
            || expandedDropdown == .mediaType
            || expandedDropdown == .mediaTime

        if isMediaDropdownOpen {
            VStack(spacing: 0) {
                // Same offset as programsDropdownOverlay — search + filter row
                // stack at the top of mediaTabContent.
                Color.clear.frame(height: 108)

                Group {
                    switch expandedDropdown {
                    case .mediaTags:
                        FilterChipDropdownPanel(
                            items: allMediaTags.map { FilterChipDropdownItem(id: $0, label: $0) },
                            selectedIds: selectedMediaTags,
                            emptyMessage: "No tags have been added to your media yet.",
                            onToggle: { id in
                                if selectedMediaTags.contains(id) {
                                    selectedMediaTags.remove(id)
                                } else {
                                    selectedMediaTags.insert(id)
                                }
                            },
                            onClearAll: { selectedMediaTags.removeAll() }
                        )
                    case .mediaLeaders:
                        FilterChipDropdownPanel(
                            items: allLeaders.map {
                                FilterChipDropdownItem(id: $0.id, label: "\($0.displayName) (\($0.mediaCount))")
                            },
                            selectedIds: selectedMediaLeaders,
                            emptyMessage: "You are the only group leader in this org.",
                            onToggle: { id in
                                if selectedMediaLeaders.contains(id) {
                                    selectedMediaLeaders.remove(id)
                                } else {
                                    selectedMediaLeaders.insert(id)
                                }
                            },
                            onClearAll: { selectedMediaLeaders.removeAll() }
                        )
                    case .mediaType:
                        FilterChipDropdownPanel(
                            items: MediaTypeFilter.allCases.map {
                                FilterChipDropdownItem(id: $0.rawValue, label: $0.rawValue)
                            },
                            selectedIds: [selectedMediaType.rawValue],
                            // Single-select: this dropdown's "Show all" maps
                            // to .all (cleared state). The MediaTypeFilter.all
                            // option is always shown like a chip too.
                            showClearAll: false,
                            onToggle: { id in
                                if let next = MediaTypeFilter(rawValue: id) {
                                    selectedMediaType = next
                                    expandedDropdown = nil
                                }
                            },
                            onClearAll: { selectedMediaType = .all }
                        )
                    case .mediaTime:
                        FilterChipDropdownPanel(
                            items: MediaTimeFilter.allCases.map {
                                FilterChipDropdownItem(id: $0.rawValue, label: $0.rawValue)
                            },
                            selectedIds: [selectedTimeFilter.rawValue],
                            showClearAll: false,
                            onToggle: { id in
                                if let next = MediaTimeFilter(rawValue: id) {
                                    selectedTimeFilter = next
                                    expandedDropdown = nil
                                }
                            },
                            onClearAll: { selectedTimeFilter = .allTime }
                        )
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(.keyboard)
            .background(dropdownDimLayer)
        }
    }

    /// Dim/scrim shown behind an open filter dropdown. Mirrors the 0.5 opacity
    /// used by `ManagedMenuView` (UserMenu, AddMenu) so the dimming feel is
    /// consistent across menus and filter dropdowns. Tap anywhere to dismiss.
    private var dropdownDimLayer: some View {
        Color.black.opacity(0.5)
            .contentShape(Rectangle())
            .onTapGesture { expandedDropdown = nil }
    }

    private var mediaTagsLabel: String {
        if selectedMediaTags.isEmpty { return "All tags" }
        if selectedMediaTags.count == 1 { return selectedMediaTags.first! }
        return "\(selectedMediaTags.count) tags"
    }

    private var mediaLeadersLabel: String {
        if selectedMediaLeaders.isEmpty { return "All leaders" }
        if selectedMediaLeaders.count == 1 {
            let id = selectedMediaLeaders.first!
            if id == authManager.currentUser?.id { return "My content" }
            if let leader = allLeaders.first(where: { $0.id == id }) { return leader.displayName }
            return "1 group leader"
        }
        return "\(selectedMediaLeaders.count) group leaders"
    }

    private var mediaEmptyState: some View {
        VStack(spacing: 16) {
            // Clear the search + filter overlay (116px)
            Color.clear.frame(height: 116)

            Spacer()

            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))

            Text("No Media")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.2))

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private let mediaGridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    // MARK: - Media Detail Presentation

    private func presentMediaDetail(item: MediaLibraryItem, sourceFrame: CGRect, restoreGridCell: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        var overlayRef: MediaDetailOverlayView?

        let overlay = MediaDetailOverlayView(
            item: item,
            sourceFrame: sourceFrame,
            onDismiss: {
                restoreGridCell()
            },
            onUsageTap: { usage in
                // Dismiss the detail overlay first, then open the linked resource
                overlayRef?.dismissAnimated {
                    restoreGridCell()
                    self.handleUsageTap(usage)
                }
            }
        )
        overlayRef = overlay
        overlay.present(in: window)
    }

    private func handleUsageTap(_ usage: MediaUsage) {
        switch usage.usageType {
        case "PROGRAM_COVER":
            if let resourceId = usage.resourceId {
                selectedProgramId = resourceId
                presentProgramHome()
            }
        case "LESSON_ACTIVITY":
            // Resource name often contains the program/lesson context
            NSLog("📎 MainLibrary: Lesson activity usage tapped (resourceId: \(usage.resourceId ?? "nil"), name: \(usage.resourceName ?? "nil"))")
        case "GROUP_COVER":
            NSLog("📎 MainLibrary: Group cover usage tapped (resourceId: \(usage.resourceId ?? "nil"))")
        default:
            NSLog("⚠️ MainLibrary: Unhandled usage type: \(usage.usageType)")
        }
    }


    // MARK: - Filter Persistence

    /// Load saved filters from the server and apply to @State variables.
    private func loadFiltersFromServer() async {
        // Load programs filters
        await programsFilter.load()
        if programsFilter.isLoaded {
            selectedTags = programsFilter.tags
            if programsFilter.hasExplicitPreference {
                selectedLeaders = programsFilter.leaders
            } else if let userId = authManager.currentUser?.id {
                // Default to showing the leader's own content
                selectedLeaders = [userId]
            }
            if let sort = LibrarySortOption(rawValue: programsFilter.sort) {
                sortOption = sort
            }
        }

        // Load media filters
        await mediaFilter.load()
        if mediaFilter.isLoaded {
            selectedMediaTags = mediaFilter.tags
            if mediaFilter.hasExplicitPreference {
                selectedMediaLeaders = mediaFilter.leaders
            } else if let userId = authManager.currentUser?.id {
                // Default to showing the leader's own content
                selectedMediaLeaders = [userId]
            }
            if let type = MediaTypeFilter(rawValue: mediaFilter.mediaType) {
                selectedMediaType = type
            }
            if let time = MediaTimeFilter(rawValue: mediaFilter.timeFilter) {
                selectedTimeFilter = time
            }
            if let sort = MediaSortOption(rawValue: mediaFilter.sort) {
                mediaSortOption = sort
            }
        }
    }

    /// Sync current program filter @State values to FilterState and schedule a debounced save.
    private func syncProgramFiltersToState() {
        programsFilter.tags = selectedTags
        programsFilter.leaders = selectedLeaders
        programsFilter.sort = sortOption.rawValue
        programsFilter.scheduleSave()
    }

    /// Sync current media filter @State values to FilterState and schedule a debounced save.
    private func syncMediaFiltersToState() {
        mediaFilter.tags = selectedMediaTags
        mediaFilter.leaders = selectedMediaLeaders
        mediaFilter.mediaType = selectedMediaType.rawValue
        mediaFilter.timeFilter = selectedTimeFilter.rawValue
        mediaFilter.sort = mediaSortOption.rawValue
        mediaFilter.scheduleSave()
    }

    // MARK: - Program Actions

    private func loadPrograms(forceRefresh: Bool) async {
        let tagsArray: [String]? = selectedTags.isEmpty ? nil : Array(selectedTags)
        let leadersArray: [String]? = selectedLeaders.isEmpty ? nil : Array(selectedLeaders)

        async let programsTask: () = {
            do {
                try await ProgramActions().loadPrograms(
                    forceRefresh: forceRefresh,
                    tags: tagsArray,
                    leaders: leadersArray
                )
            } catch {
                NSLog("❌ Failed to load programs: \(error)")
            }
        }()
        async let tagsTask: () = {
            do {
                let tags = try await ProgramActions().loadAllTags()
                await MainActor.run { allTags = tags }
            } catch {
                NSLog("⚠️ Failed to load tags: \(error)")
            }
        }()
        async let leadersTask: () = {
            do {
                let leaders = try await ProgramActions().loadGroupLeaders()
                await MainActor.run { allLeaders = leaders }
            } catch {
                NSLog("⚠️ Failed to load group leaders: \(error)")
            }
        }()
        _ = await (programsTask, tagsTask, leadersTask)
    }

    private func deleteProgram(_ program: StudyProgram) {
        Task {
            do {
                try await ProgramActions().deleteProgram(id: program.id)

                withAnimation(Motion.standard) {
                    deletingProgramId = program.id
                }

                try? await Task.sleep(nanoseconds: 350_000_000)
                deletingProgramId = nil
            } catch {
                NSLog("❌ Failed to delete program: \(error)")
            }
        }
    }

    // MARK: - Media Actions

    private func loadMedia(forceRefresh: Bool) async {
        let tagsArray: [String]? = selectedMediaTags.isEmpty ? nil : Array(selectedMediaTags)
        let leadersArray: [String]? = selectedMediaLeaders.isEmpty ? nil : Array(selectedMediaLeaders)
        do {
            try await MediaActions().loadLibrary(
                type: selectedMediaType.apiValue,
                tags: tagsArray,
                leaders: leadersArray,
                forceRefresh: forceRefresh
            )
        } catch {
            NSLog("❌ Failed to load media: \(error)")
        }
    }

    /// Append the next library page using the current filters (Phase 4.1).
    private func loadMoreMedia() async {
        let tagsArray: [String]? = selectedMediaTags.isEmpty ? nil : Array(selectedMediaTags)
        let leadersArray: [String]? = selectedMediaLeaders.isEmpty ? nil : Array(selectedMediaLeaders)
        do {
            try await MediaActions().loadMoreLibrary(
                type: selectedMediaType.apiValue,
                tags: tagsArray,
                leaders: leadersArray
            )
        } catch {
            state.recordError(error, context: "MainLibrary.loadMoreMedia")
        }
    }

    private func deleteMedia(_ item: MediaLibraryItem) {
        Task {
            do {
                try await MediaActions().deleteMedia(id: item.id)

                withAnimation(Motion.standard) {
                    deletingMediaId = item.id
                }

                try? await Task.sleep(nanoseconds: 350_000_000)
                deletingMediaId = nil
            } catch {
                NSLog("❌ Failed to delete media: \(error)")
            }
        }
    }

    private func searchMedia(query: String) async {
        let tagsArray: [String]? = selectedMediaTags.isEmpty ? nil : Array(selectedMediaTags)
        let leadersArray: [String]? = selectedMediaLeaders.isEmpty ? nil : Array(selectedMediaLeaders)
        do {
            try await MediaActions().searchLibrary(
                query: query,
                type: selectedMediaType.apiValue,
                tags: tagsArray,
                leaders: leadersArray
            )
        } catch {
            NSLog("❌ Failed to search media: \(error)")
        }
    }

    // MARK: - Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            processImportURL(fileURL, requireSecurityScope: true)

        case .failure(let error):
            NSLog("❌ File picker error: \(error)")
        }
    }

    /// Process a `.makeready` file URL, validate it, and present the import preview.
    /// - Parameters:
    ///   - fileURL: The file URL to import. May be from the file picker (security-scoped)
    ///     or from the system file-association handler (already copied to our temp dir).
    ///   - requireSecurityScope: Pass `true` for picker URLs, `false` for files we own.
    private func processImportURL(_ fileURL: URL, requireSecurityScope: Bool) {
        var didStartAccess = false
        if requireSecurityScope {
            guard fileURL.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file."
                showImportError = true
                return
            }
            didStartAccess = true
        }

        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

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
            // Make sure the user lands on the Programs tab so the import preview
            // appears in the correct context.
            activeTab = 0
            showImportPreview = true

        } catch {
            importErrorMessage = "Failed to read the selected file."
            showImportError = true
        }
    }

    /// Consume any pending `.importFile` deep link from the system file-association handler.
    /// Called from `.onChange` and `.onAppear` so the import preview triggers whether the
    /// app was launched cold or already running when the user tapped a `.makeready` file.
    private func handlePendingImportDeepLink() {
        guard case .importFile(let fileURL) = PushNotificationManager.shared.pendingDeepLink else {
            return
        }
        NSLog("📥 MainLibrary: Consuming .importFile deep link: %@", fileURL.lastPathComponent)
        PushNotificationManager.shared.clearPendingDeepLink()
        processImportURL(fileURL, requireSecurityScope: false)

        // Clean up the temp copy after the import preview consumes the data.
        // The fileData is already loaded into importFileData at this point.
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func extractManifestFromZip(_ zipData: Data) -> [String: Any]? {
        let count = zipData.count
        guard count > 22 else { return nil }

        let eocdSig: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        var eocdOffset = -1
        for i in stride(from: count - 22, through: max(0, count - 65557), by: -1) {
            if [UInt8](zipData[i..<i+4]) == eocdSig {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return nil }

        let cdOffset = Int(zipData.readUInt32(at: eocdOffset + 16))
        let cdEntries = Int(zipData.readUInt16(at: eocdOffset + 10))

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

            offset = fnStart + filenameLen + extraLen + commentLen
        }

        return nil
    }

    private func confirmImport() {
        guard let fileData = importFileData, !isImporting else { return }
        isImporting = true
        isProcessingImport = true

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

#Preview {
    MainLibraryPreview()
}

private struct MainLibraryPreview: View {
    @State private var activeTab = 0
    @FocusState private var isSearchFocused: Bool

    private let mockTags = ["Faith & Leadership", "Youth", "Marriage", "Parenting", "Bible Study"]

    private let mockPrograms: [(title: String, desc: String, days: Int, tags: [String], enrollments: Int, hasImage: Bool)] = [
        ("Romans in 30 Days", "A 12 week journey through the core beliefs and practices of the book of Romans.", 27, ["Faith & Scripture", "Bible"], 28, true),
        ("Faith & Leadership", "Developing leadership skills through biblical principles and practical exercises.", 14, ["Faith & Leadership", "Youth"], 12, false),
        ("Marriage Enrichment", "Strengthening relationships through scripture and guided reflection.", 42, ["Marriage"], 5, true),
        ("Youth Bible Study", "An engaging study designed for young adults exploring their faith.", 21, ["Youth", "Bible Study"], 0, false),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Programs", "Media"],
                    activeTab: $activeTab
                )

                ScrollView {
                    VStack(spacing: 0) {
                        // Search
                        SearchField(
                            isActive: .constant(false),
                            searchText: .constant(""),
                            isFocused: $isSearchFocused,
                            placeholder: "Search studies, tags, authors..."
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // Filter triggers (preview only — buttons are no-ops)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChipDropdownTrigger(label: "All tags", isActive: false, action: {})
                                FilterChipDropdownTrigger(label: "All leaders", isActive: false, action: {})
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)

                        // Currently enrolled
                        VStack(spacing: 12) {
                            HStack {
                                Text("Currently enrolled")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("2 active")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.brandPrimary)
                            }
                            .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<3, id: \.self) { i in
                                        CardStudyMini(
                                            data: CardStudyData(
                                                id: "mini-\(i)",
                                                title: mockPrograms[i].title,
                                                description: nil,
                                                type: nil,
                                                imageStyle: .icon(systemName: "book.fill"),
                                                metadata: [DataItem(icon: "clock", value: "\(mockPrograms[i].days)")],
                                                status: .confirmed,
                                                onTap: nil
                                            )
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 20)

                        // Browse all
                        VStack(spacing: 12) {
                            HStack {
                                Text("Browse all")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("Newest first")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                ForEach(Array(mockPrograms.enumerated()), id: \.offset) { i, program in
                                    CardProgramFull(data: CardProgramFullData(
                                        id: "program-\(i)",
                                        title: program.title,
                                        description: program.desc,
                                        coverImageUrl: nil,
                                        tags: program.tags,
                                        days: program.days,
                                        enrollmentCount: program.enrollments,
                                        authorName: "Tony Stark",
                                        createdAt: Date().addingTimeInterval(Double(-i) * 86400 * 3),
                                        isPublished: true,
                                        onTap: nil
                                    ))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }
}
