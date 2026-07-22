//
//  EditEnrollmentFlowModal.swift
//  MakeReady
//
//  Edit-enrollment flow (monday#12270302158). "Edit enrollment" is the ROOT
//  screen; tapping the group / study / schedule rows pushes a drilldown that
//  slides in from the RIGHT and back out — a classic primary→detail push, so
//  it uses SlideStack (which mounts ONLY the root + the one active detail).
//  A hand-rolled multi-panel offset would slide *through* the intermediate
//  panels when jumping from the root to a non-adjacent one; SlideStack never
//  does. Nothing persists until Save; Cancel just dismisses. All change logic
//  lives in the view-free EnrollmentEditModel.
//

import SwiftUI

struct EditEnrollmentFlowModal: View {
    let enrollment: EnrollmentWithProgram
    let onDismiss: () -> Void
    let onSaved: () -> Void

    /// Which drilldown is currently pushed over the root (nil = on the root).
    private enum Drilldown: Equatable, Hashable { case dates, group, study }

    @State private var model: EnrollmentEditModel
    @State private var drilldown: Drilldown?
    @State private var preview: EnrollmentEditPreview?
    @State private var isSaving = false
    @State private var showConfirm = false
    @State private var dateState: EnrollmentDateState
    @State private var dateStateVersion = 0

    private var state: AppState { AppState.shared }

    init(enrollment: EnrollmentWithProgram, onDismiss: @escaping () -> Void, onSaved: @escaping () -> Void) {
        self.enrollment = enrollment
        self.onDismiss = onDismiss
        self.onSaved = onSaved
        let m = EnrollmentEditModel(enrollment: enrollment)
        _model = State(initialValue: m)
        let ds = EnrollmentDateState(lessonCount: max(enrollment.studyProgram?.days ?? 1, 1))
        ds.startDate = m.startDate
        ds.enabledDays = m.enabledDays
        _dateState = State(initialValue: ds)
    }

    // MARK: - Resolved entities (needed to render the Confirm card)

    private var resolvedGroup: UserGroup? { state.groups[model.groupId] }
    private var resolvedProgram: StudyProgram? { state.programs[model.studyProgramId] }

    private var enrollmentData: EnrollmentData? {
        guard let group = resolvedGroup, let program = resolvedProgram else { return nil }
        let end = Self.computeEndDate(
            start: model.startDate,
            enabledDays: model.enabledDays,
            count: max(program.days, 1)
        )
        return EnrollmentData(
            group: group,
            studyProgram: program,
            startDate: model.startDate,
            endDate: end,
            enabledDays: model.enabledDays
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            SlideStack(item: $drilldown, edgeSwipeBack: true) {
                confirmPanel
            } detail: { target in
                detail(for: target)
            }

            if showConfirm {
                DialogOverlay(
                    isPresented: $showConfirm,
                    title: preview?.destructive == true ? "Confirm changes" : "Save changes",
                    message: preview?.confirmationMessage
                        ?? "This will update the existing enrollment to match your changes.",
                    buttons: [
                        DialogButtonConfig("Save", style: .primary) { performSave() },
                        DialogButtonConfig("Cancel", style: .secondary) {}
                    ]
                )
            }
        }
        .task {
            if resolvedGroup == nil { try? await GroupActions().loadGroups() }
            if resolvedProgram == nil { try? await ProgramActions().loadPrograms() }
        }
    }

    // MARK: - Root

    @ViewBuilder
    private var confirmPanel: some View {
        if let data = enrollmentData {
            ConfirmEnrollmentPage(
                enrollmentData: data,
                mode: .edit,
                warningSummary: preview?.summary ?? [],
                saveEnabled: !isSaving,
                onCancel: onDismiss,
                onSave: { _, smsTime, requireResponse in
                    handleSave(smsTime: smsTime, requireResponse: requireResponse)
                },
                onEditGroup: { drilldown = .group },
                onEditStudy: { drilldown = .study },
                onEditSchedule: { openDates() },
                seedRequireResponse: model.requireResponse,
                seedSmsTime: Self.parseSmsTime(model.smsTime)
            )
        } else {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
    }

    // MARK: - Drilldowns (each slides in from the right, returns to the root)

    @ViewBuilder
    private func detail(for target: Drilldown) -> some View {
        switch target {
        case .dates:
            SelectEnrollDatePage(
                state: dateState,
                config: .editEnrollmentFlow,
                existingLessonDates: [],
                onDismiss: { drilldown = nil },
                onSelect: { start, _, enabledDays in
                    model.startDate = start
                    model.enabledDays = enabledDays
                    refreshPreview()
                    drilldown = nil
                }
            )
            .id(dateStateVersion)

        case .group:
            SelectGroupPage(
                enrolledGroupIds: [],
                leftIcon: "chevron.left",
                initialSelectedGroupId: model.groupId,
                onClose: { drilldown = nil },
                onNext: { group in
                    model.groupId = group.id
                    refreshPreview()
                    drilldown = nil
                }
            )

        case .study:
            SelectStudyProgramPage(
                existingEnrollments: nil,
                leftIcon: "chevron.left",
                initialSelectedProgramId: model.studyProgramId,
                onClose: { drilldown = nil },
                onNext: { program in
                    model.studyProgramId = program.id
                    refreshPreview()
                    drilldown = nil
                }
            )
        }
    }

    /// Seed the calendar from the current pending values (and the possibly-
    /// swapped program's lesson count) before pushing it.
    private func openDates() {
        let count = max(resolvedProgram?.days ?? enrollment.studyProgram?.days ?? 1, 1)
        let ds = EnrollmentDateState(lessonCount: count)
        ds.startDate = model.startDate
        ds.enabledDays = model.enabledDays
        dateState = ds
        dateStateVersion += 1
        drilldown = .dates
    }

    // MARK: - Preview + Save

    private func refreshPreview() {
        let body = model.previewBody()
        guard !body.isEmpty else {
            preview = nil
            return
        }
        Task {
            do {
                let result = try await EnrollmentActions().previewEnrollmentEdit(
                    enrollmentId: model.enrollmentId,
                    body: body
                )
                await MainActor.run { preview = result }
            } catch {
                await MainActor.run {
                    // Console-only: the banner just won't populate; Save still works.
                    AppState.shared.recordError(error, context: "EditEnrollmentFlowModal.preview")
                }
            }
        }
    }

    private func handleSave(smsTime: String, requireResponse: Bool) {
        // Merge the scalar edits made on the Confirm screen back into the model
        // so patchBody() reflects them.
        model.smsTime = smsTime
        model.requireResponse = requireResponse
        showConfirm = true
    }

    private func performSave() {
        guard !isSaving else { return }
        isSaving = true
        let body = model.patchBody()
        let originalGroupId = model.originalGroupId
        let newGroupId = model.groupId
        let groupChanged = model.groupChanged
        Task {
            do {
                try await EnrollmentActions().updateEnrollment(enrollmentId: model.enrollmentId, body: body)
                // Structural edits move/rebuild the enrollment — reload the
                // affected group(s) rather than trust a local patch.
                _ = try? await EnrollmentActions().loadEnrollments(groupId: originalGroupId)
                if groupChanged {
                    _ = try? await EnrollmentActions().loadEnrollments(groupId: newGroupId)
                }
                await MainActor.run {
                    isSaving = false
                    onSaved()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    AppState.shared.recordError(
                        error,
                        context: "EditEnrollmentFlowModal.save",
                        surface: true,
                        friendlyMessage: "Couldn't save the enrollment changes"
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Walk forward from `start` collecting one date per lesson on the enabled
    /// weekdays; the last is the end date. Mirrors the server's schedule walk
    /// (Calendar weekday 1=Sun…7=Sat maps to our 0=Sun…6=Sat).
    private static func computeEndDate(start: Date, enabledDays: Set<Int>, count: Int) -> Date {
        guard !enabledDays.isEmpty, count > 0 else { return start }
        let calendar = Calendar.current
        var cursor = start
        var found = 0
        var last = start
        while found < count {
            if enabledDays.contains(calendar.component(.weekday, from: cursor) - 1) {
                last = cursor
                found += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return last
    }

    private static func parseSmsTime(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return DateFormatters.time24Hour.date(from: raw)
    }
}
