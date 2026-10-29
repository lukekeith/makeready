import SwiftUI

/// ui2-enrollment-create D2/D10: every "New enrollment" entry — the group page's Enrollments `add`
/// (group preloaded), the program page's (program preloaded) and the TopNav Enrollments `add`
/// (nothing). A preload counts only when it passes D5's eligibility; otherwise the row arrives to do.
enum EnrollEntry {
    @MainActor
    static func open(groupId: String?, studyProgramId: String?, push: (UI2Destination) -> Void,
                     state appState: AppState? = nil) {
        let state = appState ?? .shared
        let flowId = state.startEnrollmentDraft(
            groupId: EnrollChecklistMapper.preloadedGroupId(groupId, groups: state.groups.all),
            studyProgramId: EnrollChecklistMapper.preloadedProgramId(studyProgramId, programs: state.programs.all))
        push(.enrollChecklist(flowId: flowId))
    }
}
