import SwiftUI

/// ui2-groups-browse D8: the create call and its error routing, apart from the view so it is
/// testable (the InviteMemberSend precedent).
enum CreateGroupSubmit {
    static let failedMessage = "Couldn't create the group"
    /// D8 / create-group §3: 1–200 characters (the server's limit).
    static let maxLength = 200

    /// Creates the group with `GroupActions.createGroup`'s default flags (`isPrivate:false,
    /// allowInvites:true, memberDirectory:true` → D11 `ALLOWED`); the Action upserts it into
    /// `AppState.groups`. A 401 signs out first and surfaces nothing; a cancelled request is
    /// silent; any other failure surfaces `failedMessage`. nil on any failure or a blank name.
    @MainActor
    static func run(name: String, actions: GroupActions = GroupActions(), state: AppState? = nil,
                    onUnauthorized: @MainActor () async -> Void) async -> UserGroup? {
        let state = state ?? .shared
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return nil }
        do {
            return try await actions.createGroup(name: trimmed)
        } catch {
            if GroupActions.isCancellation(error) { return nil }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()                                   // ui2-shell D27
                return nil
            }
            state.recordError(error, context: "CreateGroupContainer.create", surface: true,
                              friendlyMessage: failedMessage)
            return nil
        }
    }
}

/// ui2-groups-browse D8: hosts the d2m-built `CreateGroupScreen`. Owns only the in-flight flag:
/// creating = Create disabled + the field read-only (§3 `creating`); a failure keeps the typed
/// name (the screen's own state) and re-enables Create as the retry. Success replaces this form
/// with the new group's page in one path write — back then returns to Groups.
struct CreateGroupContainer: View {
    /// This form's own route — what `replaceTop` expects on top (UI2Shell passes `.createGroup`).
    let route: UI2Destination
    /// The page that replaces the form (UI2Shell passes the new group's `.groupDetail`).
    let destination: (UserGroup) -> UI2Destination

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var creating = false

    var body: some View {
        CreateGroupScreen(
            state: .init(text: "", focused: !creating, creating: creating),
            onBack: { navigator.pop() },
            onCreate: create
        )
        .ui2PushedPageFill()
    }

    private func create(_ name: String) {
        guard !creating else { return }                              // §3 creating: one request
        creating = true
        Task { @MainActor in
            let group = await CreateGroupSubmit.run(name: name, onUnauthorized: { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "CreateGroupContainer.signOut", surface: false)
                }
            })
            creating = false
            if let group { navigator.replaceTop(route, destination(group)) }
        }
    }
}
