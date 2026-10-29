import SwiftUI

// ui2-enrollment-create Task 11: placeholders for the seven flow pages so the shell's page switch
// compiles. Tasks 12-14 replace them one by one and delete this file when it is empty.

struct EnrollSelectScheduleContainer: View {
    let flowId: UUID
    var body: some View { EmptyView() }
}

// Task 13: temporary home of the group picker's lesson-overlap lookup; Task 14 moves it into
// EnrollSelectScheduleContainer.swift (its body is Task 14's Step 3, verbatim).
extension EnrollSelectScheduleContainer {
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

struct EnrollSelectInviteTimeContainer: View {
    let flowId: UUID
    var body: some View { EmptyView() }
}

struct EnrollSelectSyncContainer: View {
    let flowId: UUID
    var body: some View { EmptyView() }
}

struct EnrollSelectAccessContainer: View {
    let flowId: UUID
    var body: some View { EmptyView() }
}
