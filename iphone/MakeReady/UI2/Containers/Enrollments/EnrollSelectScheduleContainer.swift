import SwiftUI

/// ui2-enrollment-create T8/D10/D11: hosts the d2m-built `EnrollmentSelectScheduleScreen`. Seeds it
/// from the draft (start/weekdays/overrides survive a program change, design rule 2), gives it the
/// draft group's existing lesson dates for its overlap prompt, and on Select writes the calendar's
/// exact dates (A4: a short list is refused, the draft stays as it was).
struct EnrollSelectScheduleContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var existing: [Date] = []

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        let lessonCount = draft.studyProgramId.flatMap { app.programs[$0]?.days } ?? 0   // A2: days, as the server expects
        EnrollmentSelectScheduleScreen(
            state: EnrollSelectScheduleMapper.state(draft: draft, lessonCount: lessonCount,
                                                    existingLessonDates: existing, today: Date()),
            onBack: { navigator.pop() },
            onSelect: { start, end, days, overrides in
                var applied = false
                AppState.shared.updateEnrollmentDraft(flowId) {
                    applied = EnrollSelectScheduleMapper.apply(start: start, end: end, days: days, overrides: overrides,
                                                               lessonCount: lessonCount, to: &$0)
                }
                if applied { navigator.popIfTop(.enrollSelectSchedule(flowId: flowId)) }
            }
        )
        .id(existing)
        .ui2PushedPageFill()
        .task {
            guard let groupId = draft.groupId else { return }
            existing = await Self.existingLessonDates(groupId: groupId)
        }
    }

    /// D11: the group's lesson dates across its active enrollments (as 1.0 — A6 accepted).
    @MainActor
    static func existingLessonDates(groupId: String, state: AppState? = nil, api: APIClientProtocol? = nil) async -> [Date] {
        let state = state ?? AppState.shared
        let actions = EnrollmentActions(api: api ?? APIClient.shared, state: state)
        let enrollments: [EnrollmentWithProgram]
        do { enrollments = try await actions.loadEnrollments(groupId: groupId) } catch {
            state.recordError(error, context: "EnrollSelectScheduleContainer.loadEnrollments")
            enrollments = state.enrollmentsFor(groupId: groupId)
        }
        var dates: [Date] = []
        for enrollment in enrollments where enrollment.isActive {
            do { dates += try await actions.getEnrollmentDetails(id: enrollment.id).lessonSchedules.map(\.scheduledDate) } catch {
                state.recordError(error, context: "EnrollSelectScheduleContainer.getEnrollmentDetails")
            }
        }
        return dates
    }
}
