import Foundation

enum EnvironmentHealth: Equatable {
    case checking, reachable, unreachable

    var label: String {
        switch self {
        case .checking: "Checking…"
        case .reachable: "Reachable"
        case .unreachable: "Unreachable"
        }
    }
}

/// SPEC D16: legacy ProfilePage's environment switch, moved out of the view.
/// ui2-fixtures D13: also the Local dev-login identity switch.
struct EnvironmentActions {
    /// Probes (and heals) the Local API port; injectable for tests.
    private let heal: () async -> LocalPortHealer.Outcome

    init(heal: @escaping () async -> LocalPortHealer.Outcome = { await LocalPortHealer.heal() }) {
        self.heal = heal
    }

    static func healthURL(for env: AppConfiguration.SelectedEnvironment) -> URL? {
        switch env {
        case .local:
            // The rows probe all three environments, so Local's URL must not follow the selection.
            return URL(string: "\(AppConfiguration.localAPIBaseURL)/health")
        case .staging: return URL(string: "https://staging.api.makeready.org/health")
        case .production: return URL(string: "https://api.makeready.org/health")
        }
    }

    /// The health probe is a sanctioned direct URLSession call, as in legacy.
    func health(of env: AppConfiguration.SelectedEnvironment) async -> EnvironmentHealth {
        guard let url = Self.healthURL(for: env) else { return .unreachable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let status = (try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse
        return status?.statusCode == 200 ? .reachable : .unreachable
    }

    /// Switches the active environment. On a failed switch to Local the previous
    /// environment is restored and `AuthError.localServerUnreachable` is thrown for the
    /// caller to surface per `/ios-error-surface`.
    @MainActor
    func switchTo(_ env: AppConfiguration.SelectedEnvironment, auth: AuthManager) async throws {
        let previous = AppConfiguration.selectedEnvironment
        guard previous != env else { return }
        AppState.shared.persistImmediately()
        AppConfiguration.selectedEnvironment = env
        AppState.shared.reloadForEnvironmentSwitch()
        if env == .local {
            let reachable: Bool
            switch await heal() {
            case .healthy, .healed: reachable = true
            case .notFound, .skipped: reachable = false
            }
            // D14: an unseeded Fixtures identity is surfaced as such, not as "unreachable".
            var seedingError: AuthError?
            var signedIn = false
            if reachable {
                do { signedIn = try await auth.signInToReachableLocal() } catch AuthError.fixturesNotSeeded { seedingError = .fixturesNotSeeded }
            }
            if signedIn {
                if auth.isAuthenticated { await AppState.shared.loadInitialData() }
                return
            }
            AppState.shared.persistImmediately()
            AppConfiguration.selectedEnvironment = previous
            AppState.shared.reloadForEnvironmentSwitch()
            await auth.checkAuthStatus()
            if auth.isAuthenticated { await AppState.shared.loadInitialData() }
            if let seedingError {
                DevLoginIdentity.current = .you   // D14: the identity reverts to You
                throw seedingError
            }
            let host = AppConfiguration.localServerIP ?? AppConfiguration.defaultLocalIP
            throw AuthError.localServerUnreachable(host: host, port: AppConfiguration.localAPIPort)
        }
        await auth.checkAuthStatus()
        if auth.isAuthenticated { await AppState.shared.loadInitialData() }
    }

    /// ui2-fixtures D13: switches the Local dev-login identity. Persists it, signs out
    /// (`clearAllData()` drops `AppState` and this environment's snapshot, so one identity's
    /// cached Home never shows under the other), then signs in again; `signIn()` dev-logs
    /// in with the new identity's email. On failure the identity reverts to You, the message
    /// is handed to Login (`AuthManager.loginNotice`, D14; Profile is unmounted by the
    /// sign-out) and the error is rethrown for the caller to record.
    @MainActor
    func switchIdentity(_ identity: DevLoginIdentity, auth: AuthManager) async throws {
        guard DevLoginIdentity.current != identity else { return }
        DevLoginIdentity.current = identity
        do {
            try await auth.signOut()
            try await auth.signIn()
        } catch {
            DevLoginIdentity.current = .you
            auth.loginNotice = LoginOutcome.message(for: error)
            throw error
        }
    }
}
