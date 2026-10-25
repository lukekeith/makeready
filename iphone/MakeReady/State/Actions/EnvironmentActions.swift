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
struct EnvironmentActions {
    static func healthURL(for env: AppConfiguration.SelectedEnvironment) -> URL? {
        switch env {
        case .local:
            if AppConfiguration.baseURL.contains("api.makeready.org") { return nil }   // no local URL resolved
            return URL(string: "\(AppConfiguration.baseURL)/health")
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
            switch await LocalPortHealer.heal() {
            case .healthy, .healed: reachable = true
            case .notFound, .skipped: reachable = false
            }
            if reachable, await auth.signInToReachableLocal() {
                if auth.isAuthenticated { await AppState.shared.loadInitialData() }
                return
            }
            AppState.shared.persistImmediately()
            AppConfiguration.selectedEnvironment = previous
            AppState.shared.reloadForEnvironmentSwitch()
            await auth.checkAuthStatus()
            if auth.isAuthenticated { await AppState.shared.loadInitialData() }
            let host = AppConfiguration.localServerIP ?? AppConfiguration.defaultLocalIP
            throw AuthError.localServerUnreachable(host: host, port: AppConfiguration.localAPIPort)
        }
        await auth.checkAuthStatus()
        if auth.isAuthenticated { await AppState.shared.loadInitialData() }
    }
}
