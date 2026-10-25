import SwiftUI

/// SPEC D7: outcomes are mapped by `LoginOutcome`.
struct LoginContainer: View {
    @Environment(AuthManager.self) private var authManager
    @State private var authenticating = false
    @State private var errorMessage = ""

    var body: some View {
        LoginScreen(
            state: .init(authenticating: authenticating, errorMessage: errorMessage),
            onSignIn: signIn
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private func signIn() {
        guard !authenticating else { return }
        authenticating = true
        errorMessage = ""
        Task { @MainActor in
            defer { authenticating = false }
            do {
                try await authManager.signIn()
            } catch {
                Log.auth.error("Login failed: \(error.localizedDescription, privacy: .private)")
                errorMessage = LoginOutcome.message(for: error) ?? ""
            }
        }
    }
}
