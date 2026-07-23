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
    @State private var loadFailed = false

    private var state: AppState { AppState.shared }

    /// This enrollment's CURRENT scheduled lesson dates, ghosted on the date
    /// picker. **Computed from AppState so it's reactive**: it reads the real
    /// per-lesson dates from the local store (the enrollment list payload omits
    /// `enabledDays`/schedules, so these arrive asynchronously via
    /// `getEnrollmentDetails`) and re-renders the moment they land; until then
    /// it falls back to a schedule computed from the enrollment's own start
    /// date + enabled weekdays. Past dates render distinctly (they won't move).
    private var currentScheduleDates: Set<Date> {
        let calendar = Calendar.current
        if let details = state.enrollmentDetailsById[model.enrollmentId], !details.lessonSchedules.isEmpty {
            return Set(details.lessonSchedules.map { calendar.startOfDay(for: $0.scheduledDate) })
        }
        return computeCurrentScheduleDates()
    }

    init(enrollment: EnrollmentWithProgram, onDismiss: @escaping () -> Void, onSaved: @escaping () -> Void) {
        self.enrollment = enrollment
        self.onDismiss = onDismiss
        self.onSaved = onSaved
        let m = EnrollmentEditModel(enrollment: enrollment)
        _model = State(initialValue: m)
        let ds = EnrollmentDateState(lessonCount: max(enrollment.studyProgram?.days ?? 1, 1))
        // Intentionally NOT seeding ds.startDate: the current schedule is shown
        // as a faint ghost, so the bold purple selection stays empty until the
        // user actually picks a new start (see openDates()).
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
        .task { await ensureLoaded() }
    }

    /// Resolve the enrollment's group + study so the Confirm card can render.
    /// Fetches each by id (bypassing the /api/groups list, which one bad group
    /// can poison) and, if either is still unresolved, surfaces an error rather
    /// than spinning forever (monday#12270302158).
    private func ensureLoaded() async {
        if resolvedGroup == nil { _ = try? await GroupActions().getGroup(id: model.groupId) }
        if resolvedProgram == nil { _ = try? await ProgramActions().getProgram(id: model.studyProgramId) }
        if resolvedGroup == nil || resolvedProgram == nil {
            await MainActor.run { loadFailed = true }
        }
        // Pull the full schedule into the local store so the date-picker ghost
        // shows the real per-lesson dates. `currentScheduleDates` reads this
        // reactively, so the ghost appears the moment it lands — no reopen.
        // Console-only on failure — the ghost falls back to the computed schedule.
        if state.enrollmentDetailsById[model.enrollmentId] == nil {
            do {
                _ = try await EnrollmentActions().getEnrollmentDetails(id: model.enrollmentId)
            } catch {
                AppState.shared.recordError(error, context: "EditEnrollmentFlowModal.loadDetails")
            }
        }
    }

    /// Walk the enrollment's own start date forward over its enabled weekdays,
    /// one date per lesson, mirroring the server's schedule walk. Approximate:
    /// it doesn't reflect manual per-day overrides, but it's a reliable ghost
    /// when the authoritative lesson schedule can't be fetched.
    private func computeCurrentScheduleDates() -> Set<Date> {
        // Use the ORIGINAL schedule (not the mutable current values) so the ghost
        // always represents what's scheduled today, even after the user edits.
        let enabled = model.originalEnabledDays
        let count = max(resolvedProgram?.days ?? enrollment.studyProgram?.days ?? 1, 1)
        guard !enabled.isEmpty, count > 0 else { return [] }
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: model.originalStartDate)
        var dates: Set<Date> = []
        var iterations = 0
        while dates.count < count, iterations < count * 10 {
            if enabled.contains(calendar.component(.weekday, from: cursor) - 1) {
                dates.insert(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            iterations += 1
        }
        return dates
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
        } else if loadFailed {
            errorPanel
        } else {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
    }

    private var errorPanel: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                PageTitle(
                    title: "Edit enrollment",
                    leftLink: "Cancel",
                    onLeftLinkTap: onDismiss
                )
                Spacer()
                Text("Couldn't load this enrollment. Check your connection and try again.")
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
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
                currentScheduleDates: currentScheduleDates,
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
                rightLabel: "Save",
                initialSelectedGroupId: model.groupId,
                onClose: { drilldown = nil },
                onNext: { group in
                    model.groupId = group.id
                    refreshPreview()
                    drilldown = nil
                }
            )

        case .study:
            // `[]` (not nil) = "enrollment data loaded, nothing blocking" — so
            // programs are selectable. nil means "not loaded yet" and disables
            // every card, which muted the whole list here.
            SelectStudyProgramPage(
                existingEnrollments: [],
                leftIcon: "chevron.left",
                rightLabel: "Save",
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
        // Only pre-select (bold purple) once the user has actually changed the
        // schedule — on first open, leave it empty so the faint current-schedule
        // ghost is visible instead of being buried under the purple selection.
        if model.scheduleChanged {
            ds.startDate = model.startDate
        }
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
