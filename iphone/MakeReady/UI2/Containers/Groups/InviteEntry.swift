import Foundation

/// invite-member D2/D12/D13: where the Add menu's "Invite a member" row goes.
enum InviteEntry {
    static let rowLabel = "Invite a member"
    static let noGroupsMessage = "Create a group before inviting members"
    static let loadFailedMessage = "Couldn't load your groups"

    static func destination(groups: [UserGroup], returnDepth: Int) -> UI2Destination? {
        switch groups.count {
        case 0: return nil
        case 1: return .inviteMember(groupId: groups[0].id, returnDepth: returnDepth)
        default: return .inviteSelectGroup(returnDepth: returnDepth)
        }
    }

    /// D13: cache-first load, then decide. D12: no groups → the banner, nothing pushed.
    @MainActor
    static func open(state appState: AppState? = nil, push: (UI2Destination) -> Void, returnDepth: Int) async {
        let state = appState ?? .shared
        do {
            try await GroupActions().loadGroups()
        } catch {
            if state.groups.all.isEmpty {
                state.recordError(error, context: "InviteEntry.open", surface: true, friendlyMessage: loadFailedMessage)
                return
            }
            state.recordError(error, context: "InviteEntry.open")       // stale cache still usable
        }
        guard let destination = destination(groups: state.groups.all, returnDepth: returnDepth) else {
            state.recordError(APIError.serverError(noGroupsMessage), context: "InviteEntry.open",
                              surface: true, friendlyMessage: noGroupsMessage)
            return
        }
        push(destination)
    }
}
