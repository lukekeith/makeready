import SwiftUI

/// ui2-groups-edit §iphone Container: the `.editGroupField` destination (D2). Reads only
/// `AppState.groups[groupId]`, builds the field's built screen, owns `saving` and the inline
/// error (D5), saves one key through `GroupActions.updateGroup(id:patch:)` and pops only if this
/// page is still on top. Back discards silently: the draft lives only in the screen's own state.
struct GroupFieldEditContainer: View {
    let groupId: String
    let field: GroupField

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D5 `saving` — set synchronously on Save, so a second tap is a no-op.
    @State private var saving = false
    /// D5: the inline line above Save; "" draws none. The age page has no slot (banner instead).
    @State private var errorText = ""

    var body: some View {
        Group {
            if let group = AppState.shared.groups[groupId] {
                screen(GroupFieldEditModel.page(field, group: group, saving: saving, errorMessage: errorText))
            } else {
                // D1: rows open this page only once the group is loaded. A 404 on Save forgets
                // the group and pops to the root itself (`save`), and a sign-out swaps the shell
                // for Login. If the group leaves the store any other way while this page is open,
                // this draws a blank page with no header (it lives inside the screens) — only the
                // edge swipe leaves it. Nothing pops here.
                Token.layoutBackground
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
    }

    @ViewBuilder private func screen(_ page: GroupFieldPage) -> some View {
        switch page {
        case let .textSingle(state, canSave):
            EditTextSingleFieldScreen(state: state, onBack: { navigator.pop() },
                                      onSave: { save(.text($0)) }, canSave: canSave)
        case let .textMulti(state):
            EditTextMultiFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.text($0)) })
        case let .option(state):
            EditOptionFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.option($0)) })
        case let .ageRange(state):
            EditOptionsCustomFieldScreen(state: state, onBack: { navigator.pop() },
                                         onSave: { save(.ageRange(minimum: $0, maximum: $1)) })
        }
    }

    /// D5: `saving` set synchronously, the PATCH in an unstructured Task, the pop only if this
    /// page is still the last entry; a failure keeps the typed value and re-enables Save.
    private func save(_ input: GroupFieldInput) {
        guard !saving, let patch = GroupFieldEditModel.patch(field, input) else { return }
        saving = true
        errorText = ""
        let destination = UI2Destination.editGroupField(groupId: groupId, field: field)
        let actions = GroupActions()
        Task { @MainActor in
            do {
                _ = try await actions.updateGroup(id: groupId, patch: patch)
                saving = false
                navigator.popIfTop(destination)
            } catch {
                saving = false
                switch GroupFieldEditModel.failure(for: error) {
                case .cancelled:
                    return
                case .signOut:
                    // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                    do { try await authManager.signOut() } catch {
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.signOut", surface: false)
                    }
                case .gone:
                    // D5/D10: the group is gone or out of scope — forget it, back to Groups.
                    actions.forgetGroup(id: groupId)
                    navigator.popTo(0)
                case .retry:
                    if field == .ageRange {
                        // EditOptionsCustomFieldScreen has no error slot (D4/D5): the shell banner.
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.save", surface: true,
                                                    friendlyMessage: GroupFieldEditModel.saveFailedMessage)
                    } else {
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.save", surface: false)
                        errorText = GroupFieldEditModel.saveFailedMessage
                    }
                }
            }
        }
    }
}
