import SwiftUI

/// SPEC D3/D13: the app root. Signed out → Login; signed in → the shell
/// (an empty page until Phase 4's UI2Shell).
struct UI2Root: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                Token.layoutBackground.ignoresSafeArea()
            } else {
                LoginContainer()
            }
        }
    }
}
