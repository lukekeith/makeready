//
//  EnrollmentFlowModal.swift
//  MakeReady
//
//  Bidirectional container for the 3-step enrollment flow:
//  - From group: [Select Program → Select Dates → Confirm]
//  - From program: [Select Group → Select Dates → Confirm]
//

import SwiftUI

// MARK: - Flow Step

enum EnrollmentFlowStep: Int {
    case selectGroup = 0
    case selectProgram = 1
    case selectDates = 2
    case confirm = 3
}

// MARK: - Flow Modal

struct EnrollmentFlowModal: View {
    // Entry point: provide ONE of these (the other is selected in the flow)
    let preselectedGroup: UserGroup?
    let preselectedProgram: StudyProgram?
    let enrolledGroupIds: Set<String>
    let onDismiss: () -> Void
    let onComplete: (EnrollmentData, String, Bool) -> Void

    // Flow navigation state
    @State private var currentStep: EnrollmentFlowStep

    // Shared data across steps
    @State private var selectedGroup: UserGroup?
    @State private var selectedProgram: StudyProgram?
    @State private var dateState: EnrollmentDateState?
    @State private var dateStateId = UUID()

    // Cached enrollment data for confirm screen (set BEFORE navigation to ensure view is ready)
    @State private var confirmedEnrollmentData: EnrollmentData?

    // Existing enrollments for overlap protection (group→program flow only)
    @State private var existingEnrollments: [EnrollmentWithProgram]?
    @State private var existingLessonDates: Set<Date>?

    /// Maps the current logical step to the physical panel index in the HStack.
    /// Both flows always have exactly 3 panels: [selection, dates, confirm].
    private var panelIndex: Int {
        switch currentStep {
        case .selectGroup:
            return 0   // Only in from-program flow (panel 0)
        case .selectProgram:
            return 0   // Only in from-group flow (panel 0)
        case .selectDates:
            return 1
        case .confirm:
            return 2
        }
    }

    init(
        preselectedGroup: UserGroup?,
        preselectedProgram: StudyProgram?,
        enrolledGroupIds: Set<String> = [],
        existingEnrollments: [EnrollmentWithProgram]? = nil,
        existingLessonDates: Set<Date>? = nil,
        onDismiss: @escaping () -> Void,
        onComplete: @escaping (EnrollmentData, String, Bool) -> Void
    ) {
        self.preselectedGroup = preselectedGroup
        self.preselectedProgram = preselectedProgram
        self.enrolledGroupIds = enrolledGroupIds
        self.onDismiss = onDismiss
        self.onComplete = onComplete

        // Initialize selected values from preselected
        _selectedGroup = State(initialValue: preselectedGroup)
        _selectedProgram = State(initialValue: preselectedProgram)

        // Start on the appropriate first step
        if preselectedGroup != nil {
            _currentStep = State(initialValue: .selectProgram)
        } else {
            _currentStep = State(initialValue: .selectGroup)
        }

        // Initialize state from pre-loaded data (may be nil)
        _existingEnrollments = State(initialValue: existingEnrollments)
        _existingLessonDates = State(initialValue: existingLessonDates)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Step 0: Select Group (only when entering from program)
                    if preselectedGroup == nil {
                        SelectGroupPage(
                            enrolledGroupIds: enrolledGroupIds,
                            onClose: { onDismiss() },
                            onNext: { group in
                                selectGroup(group)
                            }
                        )
                        .frame(width: geometry.size.width)
                    }

                    // Step 1: Select Program (only when entering from group)
                    if preselectedProgram == nil {
                        SelectStudyProgramPage(
                            existingEnrollments: existingEnrollments,
                            onClose: {
                                if preselectedGroup == nil {
                                    // Go back to group selection
                                    navigateTo(.selectGroup)
                                } else {
                                    onDismiss()
                                }
                            },
                            onNext: { program in
                                selectProgram(program)
                            }
                        )
                        .frame(width: geometry.size.width)
                    }

                    // Step 2: Select Dates
                    if let state = dateState, selectedProgram != nil {
                        SelectEnrollDatePage(
                            state: state,
                            config: .enrollmentFlow,
                            existingLessonDates: existingLessonDates ?? [],
                            onDismiss: {
                                // Go back to the selection step
                                if preselectedProgram == nil {
                                    navigateTo(.selectProgram)
                                } else {
                                    navigateTo(.selectGroup)
                                }
                            },
                            onSelect: { startDate, endDate, enabledDays in
                                cacheEnrollmentDataAndNavigate(
                                    startDate: startDate,
                                    endDate: endDate,
                                    enabledDays: enabledDays
                                )
                            }
                        )
                        .id(dateStateId)
                        .frame(width: geometry.size.width)
                    } else {
                        Color.appBackground
                            .frame(width: geometry.size.width)
                    }

                    // Step 3: Confirm
                    if let enrollmentData = confirmedEnrollmentData {
                        ConfirmEnrollmentPage(
                            enrollmentData: enrollmentData,
                            onBack: {
                                navigateTo(.selectDates)
                            },
                            onConfirm: { data, smsTime, requireResponse in
                                onComplete(data, smsTime, requireResponse)
                            }
                        )
                        .frame(width: geometry.size.width)
                    } else {
                        Color.appBackground
                            .frame(width: geometry.size.width)
                    }
                }
                .offset(x: -CGFloat(panelIndex) * geometry.size.width)
            }
        }
        .task {
            await loadEnrollmentsIfNeeded()
        }
    }

    // MARK: - Load Enrollments

    private func loadEnrollmentsIfNeeded() async {
        // Only relevant for group→program flow where we have a preselected group
        guard let group = preselectedGroup else { return }
        guard existingEnrollments == nil else { return }

        do {
            let enrollments = try await EnrollmentActions().loadEnrollments(groupId: group.id)
            await MainActor.run {
                existingEnrollments = enrollments
            }

            var lessonDates: Set<Date> = []
            let calendar = Calendar.current

            for enrollment in enrollments where enrollment.isActive {
                do {
                    let details = try await EnrollmentActions().getEnrollmentDetails(id: enrollment.id)
                    for schedule in details.lessonSchedules {
                        let dayStart = calendar.startOfDay(for: schedule.scheduledDate)
                        lessonDates.insert(dayStart)
                    }
                } catch {
                    NSLog("Failed to load enrollment details: \(error)")
                }
            }

            await MainActor.run {
                existingLessonDates = lessonDates
            }

            NSLog("EnrollmentFlowModal: Loaded \(enrollments.count) enrollments, \(lessonDates.count) lesson dates")
        } catch {
            NSLog("EnrollmentFlowModal: Failed to load enrollments: \(error)")
            await MainActor.run {
                existingEnrollments = []
                existingLessonDates = []
            }
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ step: EnrollmentFlowStep) {
        withAnimation(Motion.standard) {
            currentStep = step
        }
    }

    // MARK: - Group Selection (program→group flow)

    private func selectGroup(_ group: UserGroup) {
        selectedGroup = group
        if let program = preselectedProgram {
            // Program already known — go straight to dates
            dateState = EnrollmentDateState(lessonCount: program.days)
            dateStateId = UUID()
            navigateTo(.selectDates)
        } else {
            navigateTo(.selectProgram)
        }
    }

    // MARK: - Program Selection (group→program flow)

    private func selectProgram(_ program: StudyProgram) {
        selectedProgram = program
        dateState = EnrollmentDateState(lessonCount: program.days)
        dateStateId = UUID()
        navigateTo(.selectDates)
    }

    // MARK: - Date Selection -> Confirm Navigation

    private func cacheEnrollmentDataAndNavigate(
        startDate: Date,
        endDate: Date,
        enabledDays: Set<Int>
    ) {
        guard let group = selectedGroup, let program = selectedProgram else { return }

        confirmedEnrollmentData = EnrollmentData(
            group: group,
            studyProgram: program,
            startDate: startDate,
            endDate: endDate,
            enabledDays: enabledDays
        )

        navigateTo(.confirm)
    }
}

// MARK: - Preview

#Preview {
    EnrollmentFlowModal(
        preselectedGroup: UserGroup(
            id: "preview",
            code: "ABC123",
            name: "Young Professionals",
            description: "A group for young professionals",
            coverImageUrl: nil,
            isPrivate: false,
            allowInvites: true,
            memberDirectory: true,
            welcomeMessage: nil,
            ageRange: nil,
            maxMembers: nil,
            memberCount: 25,
            creatorId: "1",
            createdAt: Date(),
            updatedAt: Date()
        ),
        preselectedProgram: nil,
        onDismiss: { print("Dismissed") },
        onComplete: { data, smsTime, requireResponse in print("Complete: \(data.studyProgram.name) at \(smsTime), requireResponse: \(requireResponse)") }
    )
}
