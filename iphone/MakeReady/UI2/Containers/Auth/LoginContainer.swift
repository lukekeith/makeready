import SwiftUI

/// SPEC D7 (outcomes completed in Task 8).
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
            do { try await authManager.signIn() } catch { errorMessage = "Authentication failed" }
        }
    }
}
