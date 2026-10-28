import SwiftUI

/// ui2-programs D10: the `.editProgramField` destination — GroupFieldEditContainer over a program.
/// Reads only `AppState.programs[programId]`, owns `saving` and the inline error, saves one key
/// through `ProgramActions.updateProgram(id:patch:)` and pops only if this page is still on top.
/// Back discards silently: the draft lives only in the screen's own state.
struct ProgramFieldEditContainer: View {
    let programId: String
    let field: ProgramField

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Set synchronously on Save, so a second tap is a no-op.
    @State private var saving = false
    /// The inline line above Save; "" draws none. The age page has no slot (banner instead).
    @State private var errorText = ""

    var body: some View {
        Group {
            if let program = AppState.shared.programs[programId] {
                screen(ProgramFieldEditModel.page(field, program: program, saving: saving, errorMessage: errorText))
            } else {
                // Rows open this page only once the program is loaded; a 404 on Save forgets it
                // and pops to the root itself (`save`). Nothing pops here.
                Token.layoutBackground
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
    }

    @ViewBuilder private func screen(_ page: FieldEditPage) -> some View {
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

    private func save(_ input: FieldEditInput) {
        guard !saving, let patch = ProgramFieldEditModel.patch(field, input) else { return }
        saving = true
        errorText = ""
        let destination = UI2Destination.editProgramField(programId: programId, field: field)
        let actions = ProgramActions()
        Task { @MainActor in
            do {
                _ = try await actions.updateProgram(id: programId, patch: patch)
                saving = false
                navigator.popIfTop(destination)
            } catch {
                saving = false
                switch FieldEditRules.failure(for: error) {
                case .cancelled:
                    return
                case .signOut:
                    // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                    do { try await authManager.signOut() } catch {
                        AppState.shared.recordError(error, context: "ProgramFieldEditContainer.signOut", surface: false)
                    }
                case .gone:
                    // D5/D10: the program is gone or out of scope — forget it, back to the list.
                    actions.forgetProgram(id: programId)
                    navigator.popTo(0)
                case .retry:
                    if field == .ageRange {
                        // EditOptionsCustomFieldScreen has no error slot: the shell banner.
                        AppState.shared.recordError(error, context: "ProgramFieldEditContainer.save", surface: true,
                                                    friendlyMessage: FieldEditRules.saveFailedMessage)
                    } else {
                        AppState.shared.recordError(error, context: "ProgramFieldEditContainer.save", surface: false)
                        errorText = FieldEditRules.saveFailedMessage
                    }
                }
            }
        }
    }
}
