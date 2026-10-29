import SwiftUI

/// ui2-enrollment-create D7 + design §3: the three value pickers' writes — only a valid value lands.
enum EnrollValueWrite {
    static func inviteTime(_ smsTime: String, timezone: String, into d: inout EnrollmentDraft) {
        d.smsTime = smsTime
        d.timezone = timezone                         // D16: the picker's zone is the enrollment's
    }

    static func sync(_ mode: String, into d: inout EnrollmentDraft) -> Bool {
        guard mode == "AUTO" || mode == "OFF" else { return false }
        d.syncMode = mode
        return true
    }

    static func access(_ value: String, into d: inout EnrollmentDraft) -> Bool {
        guard value == "one-at-a-time" || value == "all-at-once" else { return false }
        d.lessonAccess = value
        return true
    }
}

/// D7: the invite time (`HH:mm`) and its zone are stored and sent; sending invites is out of scope.
struct EnrollSelectInviteTimeContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectInviteTimeScreen(
            state: .init(smsTime: AppState.shared.enrollmentDrafts[flowId]?.smsTime ?? ""),
            onBack: { navigator.pop() },
            onSelect: { time, zone in
                AppState.shared.updateEnrollmentDraft(flowId) { EnrollValueWrite.inviteTime(time, timezone: zone, into: &$0) }
                EnrollDraftSyncs.changed(flowId)                                // ui2-enrollments-browse D4
                navigator.popIfTop(.enrollSelectInviteTime(flowId: flowId))
            }
        )
        .ui2PushedPageFill()
    }
}

struct EnrollSelectSyncContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectSyncScreen(
            state: .init(syncMode: AppState.shared.enrollmentDrafts[flowId]?.syncMode ?? ""),
            onBack: { navigator.pop() },
            onSave: { mode in
                var saved = false
                AppState.shared.updateEnrollmentDraft(flowId) { saved = EnrollValueWrite.sync(mode, into: &$0) }
                if saved {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectSync(flowId: flowId))
                }
            }
        )
        .ui2PushedPageFill()
    }
}

struct EnrollSelectAccessContainer: View {
    let flowId: UUID
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        EnrollmentSelectAccessScreen(
            state: .init(lessonAccess: AppState.shared.enrollmentDrafts[flowId]?.lessonAccess ?? ""),
            onBack: { navigator.pop() },
            onSave: { value in
                var saved = false
                AppState.shared.updateEnrollmentDraft(flowId) { saved = EnrollValueWrite.access(value, into: &$0) }
                if saved {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectAccess(flowId: flowId))
                }
            }
        )
        .ui2PushedPageFill()
    }
}
