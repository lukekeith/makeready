import SwiftUI

/// ui2-enrollment-create T8/D10/D11: hosts the d2m-built `EnrollmentSelectScheduleScreen`. Seeds it
/// from the draft (start/weekdays/overrides survive a program change, design rule 2), gives it the
/// draft group's existing lesson dates (the calendar's dots), and on Select writes the calendar's
/// exact dates (A4: a short list is refused, the draft stays as it was). Owner 2026-10-30: any
/// schedule may be picked; one that overlaps the group's lessons raises the amber top note.
struct EnrollSelectScheduleContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var existing: [EnrollPickerWarnings.ExistingLesson] = []
    /// The screen's live draft, as it last reported it.
    @State private var live: (start: Date?, days: Set<Int>, overrides: Set<Date>)?
    /// The overlap note last raised, so a change that leaves it the same doesn't raise it again.
    @State private var raisedNote = ""

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        let lessonCount = draft.studyProgramId.flatMap { app.programs[$0]?.days } ?? 0   // A2: days, as the server expects
        EnrollmentSelectScheduleScreen(
            state: EnrollSelectScheduleMapper.state(draft: draft, lessonCount: lessonCount,
                                                    existingLessonDates: existing.map(\.date), today: Date()),
            onBack: { navigator.pop() },
            onSelect: { start, end, days, overrides in
                var applied = false
                AppState.shared.updateEnrollmentDraft(flowId) {
                    applied = EnrollSelectScheduleMapper.apply(start: start, end: end, days: days, overrides: overrides,
                                                               lessonCount: lessonCount, to: &$0)
                }
                if applied {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectSchedule(flowId: flowId))
                }
            },
            onScheduleChange: { start, days, overrides in
                live = (start, days, overrides)
                noteOverlap(lessonCount: lessonCount)
            }
        )
        .ui2PushedPageFill()
        .task {
            // No program → the screen shows its needs-program body and never reads the dates.
            guard let groupId = draft.groupId, draft.studyProgramId != nil else { return }
            existing = await Self.existingLessons(groupId: groupId)
            noteOverlap(lessonCount: lessonCount)
        }
    }

    /// Owner 2026-10-30: the live schedule against the group's lessons — a new overlap raises the
    /// amber note; clearing the overlap takes a still-showing note down.
    private func noteOverlap(lessonCount: Int) {
        let dates = live.flatMap { live in
            live.start.flatMap { EnrollScheduleMath.dates(start: $0, days: live.days, overrides: live.overrides,
                                                          lessonCount: lessonCount) }
        } ?? []
        let note = EnrollPickerWarnings.scheduleOverlapNote(dates, existing: existing)
        guard note != raisedNote else { return }
        let state = AppState.shared
        if note.isEmpty {
            if state.activeSurfacedError?.context == Self.noteContext { state.activeSurfacedError = nil }
        } else {
            state.showWarning(note, context: Self.noteContext)
        }
        raisedNote = note
    }

    static let noteContext = "EnrollSelectScheduleContainer.overlap"

    /// D11: the group's lesson dates across its active enrollments (as 1.0 — A6 accepted).
    @MainActor
    static func existingLessonDates(groupId: String, state: AppState? = nil, api: APIClientProtocol? = nil) async -> [Date] {
        await existingLessons(groupId: groupId, state: state, api: api).map(\.date)
    }

    /// enroll-picker-hide-enrolled D5 (owner 2026-10-29): each existing lesson with its enrollment's
    /// program name, so the checklist's clash note can say what it clashes with.
    @MainActor
    static func existingLessons(groupId: String, state: AppState? = nil,
                                api: APIClientProtocol? = nil) async -> [EnrollPickerWarnings.ExistingLesson] {
        let state = state ?? AppState.shared
        let actions = EnrollmentActions(api: api ?? APIClient.shared, state: state)
        let enrollments: [EnrollmentWithProgram]
        do { enrollments = try await actions.loadEnrollments(groupId: groupId) } catch {
            state.recordError(error, context: "EnrollSelectScheduleContainer.loadEnrollments")
            enrollments = state.enrollmentsFor(groupId: groupId)
        }
        var lessons: [EnrollPickerWarnings.ExistingLesson] = []
        for enrollment in enrollments where enrollment.isActive {
            let name = enrollment.studyProgram?.name ?? state.programs[enrollment.studyProgramId]?.name ?? ""
            do {
                lessons += try await actions.getEnrollmentDetails(id: enrollment.id).lessonSchedules
                    .map { .init(date: $0.scheduledDate, programName: name) }
            } catch {
                state.recordError(error, context: "EnrollSelectScheduleContainer.getEnrollmentDetails")
            }
        }
        return lessons
    }
}
