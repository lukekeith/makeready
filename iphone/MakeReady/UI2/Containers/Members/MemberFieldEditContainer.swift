import SwiftUI

/// ui2-members-edit §iphone Edit container: the `.editMemberField` destination (D2). Reads only
/// `AppState.memberDetails[memberId]` (D27), builds the field's built screen (D3, D10, D14),
/// runs the D16 checks before any request, owns `saving` and the inline error (D13), saves
/// through `MemberActions.updateMember` (D15, D21) and pops only if this page is still on top.
/// Back at any time discards silently (P11): the draft lives only in the screen's own state.
/// F5: the post-save `loadMember` overlaps the member page's `.task` reload on reappear — the
/// APIClient GET coalescer dedupes them.
struct MemberFieldEditContainer: View {
    let memberId: String
    let field: MemberField

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D13 `saving` — set synchronously on Save, so a second tap is a no-op.
    @State private var saving = false
    /// D13 `save-failed` / D16: the inline line above Save; "" draws none.
    @State private var errorText = ""

    var body: some View {
        Group {
            if let detail = AppState.shared.memberDetails[memberId] {
                screen(MemberFieldEditModel.page(
                    field, detail: detail, saving: saving, errorMessage: errorText,
                    today: Date(), calendar: .current
                ))
            } else {
                // D27: rows open this page only once the member is loaded; a sign-out mid-page
                // clears the store and UI2Root swaps to Login.
                Token.layoutBackground
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
    }

    @ViewBuilder private func screen(_ page: MemberFieldPage) -> some View {
        switch page {
        case let .textSingle(state, canSave):
            EditTextSingleFieldScreen(state: state, onBack: { navigator.pop() },
                                      onSave: { save(.text($0)) }, canSave: canSave)
        case let .textMulti(state):
            EditTextMultiFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.text($0)) })
        case let .option(state):
            EditOptionFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.option($0)) })
        case let .date(state):
            EditDateFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.date($0)) })
        }
    }

    /// D16 first (the server's message inline, no request); then D13: `saving` set synchronously,
    /// the save in an unstructured Task, the pop only if this page is still the last entry.
    private func save(_ input: MemberFieldInput) {
        guard !saving else { return }
        if let message = MemberFieldEditModel.validate(field, input, today: Date(), calendar: .current) {
            errorText = message
            return
        }
        saving = true
        errorText = ""
        let patch = MemberFieldEditModel.patch(field, input)
        let destination = UI2Destination.editMemberField(memberId: memberId, field: field)
        let actions = MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MemberFieldEditContainer.signOut", surface: false)
            }
        })
        Task { @MainActor in
            let result = await actions.updateMember(memberId, patch)
            saving = false
            switch result {
            case .success:
                navigator.popIfTop(destination)
            case .failure(let error):
                errorText = MemberFieldEditModel.message(for: error)   // value kept, Save re-enabled
            }
        }
    }
}
