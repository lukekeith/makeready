//
//  EditEnrollmentFlowModal.swift
//  MakeReady
//
//  Edit-enrollment flow (monday#12270302158). Unlike the create wizard, the
//  Confirm screen ("Edit enrollment") is the ROOT panel — the group / study /
//  schedule pickers are drilldowns to its RIGHT, so they slide in from the
//  right and back out to the left (the reverse of create). Nothing persists
//  until Save; Cancel just dismisses. All the change logic lives in the
//  view-free EnrollmentEditModel; this view renders it and wires navigation.
//

import SwiftUI

struct EditEnrollmentFlowModal: View {
    let enrollment: EnrollmentWithProgram
    let onDismiss: () -> Void
    let onSaved: () -> Void

    // Panels laid side-by-side; Confirm is the root at index 0.
    private enum Panel: Int { case confirm = 0, dates = 1, group = 2, study = 3 }

    @State private var model: EnrollmentEditModel
    @State private var panel: Panel = .confirm
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
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                HStack(spacing: 0) {
                    confirmPanel.frame(width: geometry.size.width)
                    datesPanel.frame(width: geometry.size.width)
                    groupPanel.frame(width: geometry.size.width)
                    studyPanel.frame(width: geometry.size.width)
                }
                .offset(x: -CGFloat(panel.rawValue) * geometry.size.width)

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
        }
        .task {
            if resolvedGroup == nil { try? await GroupActions().loadGroups() }
            if resolvedProgram == nil { try? await ProgramActions().loadPrograms() }
        }
    }

    // MARK: - Panels

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
                onEditGroup: { navigate(.group) },
                onEditStudy: { navigate(.study) },
                onEditSchedule: { prepareAndOpenDates() },
                seedRequireResponse: model.requireResponse,
                seedSmsTime: Self.parseSmsTime(model.smsTime)
            )
        } else {
            loadingPanel
        }
    }

    private var datesPanel: some View {
        SelectEnrollDatePage(
            state: dateState,
            config: .editEnrollmentFlow,
            existingLessonDates: [],
            onDismiss: { navigate(.confirm) },
            onSelect: { start, _, enabledDays in
                model.startDate = start
                model.enabledDays = enabledDays
                refreshPreview()
                navigate(.confirm)
            }
        )
        .id(dateStateVersion)
    }

    private var groupPanel: some View {
        SelectGroupPage(
            enrolledGroupIds: [],
            onClose: { navigate(.confirm) },
            onNext: { group in
                model.groupId = group.id
                refreshPreview()
                navigate(.confirm)
            }
        )
    }

    private var studyPanel: some View {
        SelectStudyProgramPage(
            existingEnrollments: nil,
            onClose: { navigate(.confirm) },
            onNext: { program in
                model.studyProgramId = program.id
                refreshPreview()
                navigate(.confirm)
            }
        )
    }

    private var loadingPanel: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ProgressView().tint(.white)
        }
    }

    // MARK: - Navigation

    private func navigate(_ target: Panel) {
        withAnimation(Motion.standard) { panel = target }
    }

    /// Seed the calendar from the current pending values (and the possibly-
    /// swapped program's lesson count) before sliding to it.
    private func prepareAndOpenDates() {
        let count = max(resolvedProgram?.days ?? enrollment.studyProgram?.days ?? 1, 1)
        let ds = EnrollmentDateState(lessonCount: count)
        ds.startDate = model.startDate
        ds.enabledDays = model.enabledDays
        dateState = ds
        dateStateVersion += 1
        navigate(.dates)
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
