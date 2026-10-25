import SwiftUI

/// SPEC D3/D13: the app root. Signed out → Login; signed in → the shell
/// (UI2Shell: TabBar + TopNav, SPEC D11).
struct UI2Root: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                UI2Shell()
            } else {
                LoginContainer()
            }
        }
    }
}
