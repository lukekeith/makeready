import SwiftUI

/// ui2-programs D8: the create call and its error routing, apart from the view so it is testable
/// (the CreateGroupSubmit precedent).
enum CreateProgramSubmit {
    /// D8 / create-study-program §3 `create-failed`: the inline error line.
    static let failedMessage = "Couldn't create the program"
    /// D8: 1–200 characters (the server's limit).
    static let maxLength = 200

    enum Result: Equatable {
        /// The Action stored it in `AppState.programs`.
        case created(StudyProgram)
        /// Show `failedMessage` under the field; the typed title stays.
        case failed
        /// Nothing to show: a blank title, a cancelled request, or a 401 (already signed out).
        case silent
    }

    /// Creates a blank program from the trimmed title (D8: no template).
    @MainActor
    static func run(title: String, actions: ProgramActions = ProgramActions(), state: AppState? = nil,
                    onUnauthorized: @MainActor () async -> Void) async -> Result {
        let state = state ?? .shared
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return .silent }
        do {
            return .created(try await actions.createProgram(name: trimmed))
        } catch {
            if GroupActions.isCancellation(error) { return .silent }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()                                   // ui2-shell D27
                return .silent
            }
            state.recordError(error, context: "CreateStudyProgramContainer.create", surface: false)
            return .failed
        }
    }
}

/// ui2-programs D8: hosts the d2m-built `CreateStudyProgramScreen`. Owns the in-flight flag and
/// the inline error; the typed title is the screen's own state, so a failure keeps it and Create
/// re-enabled is the retry. Success replaces this form with the new program's page in one path
/// write — back then returns to Programs.
struct CreateStudyProgramContainer: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var creating = false
    @State private var errorMessage = ""

    var body: some View {
        CreateStudyProgramScreen(
            state: .init(text: "", creating: creating, errorMessage: errorMessage),
            onBack: { navigator.pop() },
            onCreate: create
        )
        .ui2PushedPageFill()
    }

    private func create(_ title: String) {
        guard !creating else { return }                              // §3 creating: one request
        creating = true
        errorMessage = ""
        Task { @MainActor in
            let result = await CreateProgramSubmit.run(title: title, onUnauthorized: { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "CreateStudyProgramContainer.signOut", surface: false)
                }
            })
            creating = false
            switch result {
            case .created(let program):
                navigator.replaceTop(.createStudyProgram, .studyProgramHome(id: program.id, name: program.name))
            case .failed:
                errorMessage = CreateProgramSubmit.failedMessage
            case .silent:
                break
            }
        }
    }
}
