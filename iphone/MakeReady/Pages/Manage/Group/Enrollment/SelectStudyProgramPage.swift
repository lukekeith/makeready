//
//  SelectStudyProgramPage.swift
//  MakeReady
//
//  Step 1 of enrollment flow: Select a study program
//

import SwiftUI

struct SelectStudyProgramPage: View {
    // nil = enrollment data not loaded yet, [] = loaded with no enrollments
    let existingEnrollments: [EnrollmentWithProgram]?
    let onClose: () -> Void
    let onNext: (StudyProgram) -> Void

    // Initialize from cache synchronously so content is ready BEFORE modal animation starts
    // This ensures cards animate with the modal slide-up transition
    @State private var programs: [StudyProgram]
    @State private var selectedProgramId: String?
    @State private var searchText = ""
    @State private var isLoading: Bool
    @State private var error: String?
    @State private var showDraftAlert = false
    @FocusState private var isSearchFocused: Bool

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }

    /// Whether enrollment status data has been loaded
    private var isEnrollmentDataLoaded: Bool {
        existingEnrollments != nil
    }

    /// Map of program ID to active enrollment (for showing "enrolled until" status)
    private var activeEnrollmentsByProgram: [String: EnrollmentWithProgram] {
        guard let enrollments = existingEnrollments else { return [:] }
        var map: [String: EnrollmentWithProgram] = [:]
        for enrollment in enrollments where enrollment.isActive {
            map[enrollment.studyProgramId] = enrollment
        }
        return map
    }

    /// Left nav icon — "xmark" (close) in the create wizard, "chevron.left"
    /// (back) when it's a drilldown of the edit flow (monday#12270302158).
    let leftIcon: String

    init(
        existingEnrollments: [EnrollmentWithProgram]? = nil,
        leftIcon: String = "xmark",
        initialSelectedProgramId: String? = nil,
        onClose: @escaping () -> Void,
        onNext: @escaping (StudyProgram) -> Void
    ) {
        self.existingEnrollments = existingEnrollments
        self.leftIcon = leftIcon
        self.onClose = onClose
        self.onNext = onNext

        // Pre-load from cache for smooth modal animation
        let cachedPrograms = AppState.shared.orderedPrograms
        _programs = State(initialValue: cachedPrograms)
        _isLoading = State(initialValue: cachedPrograms.isEmpty)
        // Pre-select the enrollment's current study when editing.
        _selectedProgramId = State(initialValue: initialSelectedProgramId)
    }

    private var filteredPrograms: [StudyProgram] {
        if searchText.isEmpty {
            return programs
        }
        return programs.filter { program in
            program.name.localizedCaseInsensitiveContains(searchText) ||
            (program.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var selectedProgram: StudyProgram? {
        guard let id = selectedProgramId else { return nil }
        return programs.first { $0.id == id }
    }

    private var shouldShowSearch: Bool {
        !searchText.isEmpty || programs.count > 10
    }

    var body: some View {
        // Simple VStack structure - no ZStack layering issues
        // Header is rendered LAST but with .zIndex(1) to be on top for taps
        VStack(spacing: 0) {
            // Content area - show loading if programs empty OR isLoading flag
            if programs.isEmpty || isLoading {
                loadingContent
            } else if let error = error {
                errorContent(error)
            } else if filteredPrograms.isEmpty {
                emptyContent
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .overlay(alignment: .top) {
            // Header overlay - always on top for tap priority
            VStack(spacing: 0) {
                PageTitle.iconTitleLink(
                    title: "Select Program",
                    leftIcon: leftIcon,
                    rightLink: "Next",
                    rightLinkDisabled: selectedProgramId == nil,
                    onLeftIconTap: onClose,
                    onRightLinkTap: {
                        if let program = selectedProgram {
                            onNext(program)
                        }
                    }
                )

                // Search field - only show if > 10 programs
                if shouldShowSearch {
                    SearchField(
                        isActive: .constant(true),
                        searchText: $searchText,
                        isFocused: $isSearchFocused,
                        placeholder: "Search programs"
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.appBackground)
        }
        .alert("Draft Program", isPresented: $showDraftAlert) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("This study program must be published before it can be used for enrollment. Open the program and publish it first.")
        }
        .task {
            // Only fetch from API if cache was empty
            if programs.isEmpty {
                await loadPrograms()
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Top padding to account for header + search
                Color.clear
                    .frame(height: shouldShowSearch ? 140 : 70)

                ForEach(filteredPrograms, id: \.id) { program in
                    let activeEnrollment = activeEnrollmentsByProgram[program.id]
                    let isCurrentlyEnrolled = activeEnrollment != nil
                    let isPublished = program.isPublished ?? false

                    // When enrollment data not loaded: all cards dimmed and disabled
                    // When loaded: enrolled cards stay dimmed, draft cards are tappable (show alert)
                    let isDisabled = !isEnrollmentDataLoaded || isCurrentlyEnrolled

                    CardStudySelectable(
                        data: CardStudySelectableData(
                            id: program.id,
                            title: program.name,
                            description: program.description,
                            lessonCount: program.days,
                            imageURL: program.coverImageUrl,
                            isSelected: selectedProgramId == program.id,
                            isPublished: isPublished,
                            enrolledUntilDate: activeEnrollment?.endDate,
                            isDisabled: isDisabled,
                            onTap: {
                                if !isPublished {
                                    showDraftAlert = true
                                } else {
                                    withAnimation(Motion.micro) {
                                        if selectedProgramId == program.id {
                                            selectedProgramId = nil
                                        } else {
                                            selectedProgramId = program.id
                                        }
                                    }
                                }
                            }
                        )
                    )
                    .animation(Motion.standard, value: isEnrollmentDataLoaded)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Loading Content (Skeleton Cards)

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Top padding to account for header + search
                Color.clear
                    .frame(height: shouldShowSearch ? 140 : 70)

                // Show 4 skeleton cards for loading state
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCardStudy()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Error Content

    private func errorContent(_ errorMessage: String) -> some View {
        VStack {
            Spacer()
                .frame(height: 100)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(Typography.s40)
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadPrograms() }
                }
                .foregroundColor(.brandPrimary)
            }
            .padding()
            Spacer()
        }
    }

    // MARK: - Empty Content

    private var emptyContent: some View {
        VStack {
            Spacer()
                .frame(height: 100)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.s40)
                    .foregroundColor(.white.opacity(0.3))
                Text(searchText.isEmpty ? "No study programs found" : "No programs match your search")
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadPrograms() async {
        isLoading = true
        error = nil

        do {
            try await ProgramActions().loadPrograms()
            await MainActor.run {
                programs = state.orderedPrograms
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SelectStudyProgramPage(
            existingEnrollments: nil,
            onClose: { print("Close") },
            onNext: { program in print("Selected: \(program.name)") }
        )
    }
}
