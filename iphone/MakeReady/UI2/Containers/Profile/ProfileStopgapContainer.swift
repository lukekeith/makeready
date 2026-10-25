import SwiftUI

/// SPEC D15/D16: a stopgap until profile-home is designed.
/// ui2-fixtures D13: in a dev build on Local it also picks the dev-login identity.
struct ProfileStopgapContainer: View {
    static func showsEnvironmentSwitcher(devMode: Bool) -> Bool { devMode }

    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    static func showsIdentityPicker(devMode: Bool, env: AppConfiguration.SelectedEnvironment) -> Bool {
        devMode && env == .local
    }

    @Environment(AuthManager.self) private var authManager
    @State private var current = AppConfiguration.selectedEnvironment
    @State private var identity = DevLoginIdentity.current
    @State private var health: [AppConfiguration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var switchError = ""
    @State private var isSwitching = false

    var body: some View {
        VStack(spacing: Token.Space.sectionGap) {
            Spacer()
            PageActionButton(label: "Sign out", role: .secondary, onTap: signOut)
            if Self.showsEnvironmentSwitcher(devMode: AppConfiguration.devMode) {
                VStack(spacing: 0) {
                    ForEach(AppConfiguration.SelectedEnvironment.allCases, id: \.self) { env in
                        RadioOptionRow(
                            title: env.rawValue,
                            description: (health[env] ?? .checking).label,
                            selected: env == current,
                            onSelect: { select(env) }
                        )
                    }
                }
                if Self.showsIdentityPicker(devMode: AppConfiguration.devMode, env: current) {
                    identityPicker
                }
                if !switchError.isEmpty {
                    Text(switchError)
                        .designTextStyle(Token.TypeStyle.body)
                        .foregroundStyle(Token.negative)
                }
            }
            Spacer()
        }
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.layoutBackground)
        .task { await refreshHealth() }
    }

    /// ui2-fixtures D13: You · Fixtures, each row described by the email it dev-logs in with.
    private var identityPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Local identity")
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
            ForEach(DevLoginIdentity.allCases, id: \.self) { option in
                RadioOptionRow(
                    title: option.title,
                    description: option.email,
                    selected: option == identity,
                    onSelect: { selectIdentity(option) }
                )
            }
        }
    }

    private func signOut() {
        Task { @MainActor in
            do {
                try await authManager.signOut()
            } catch {
                // SPEC D28: no banner host in 2.0 — logged through the one error channel.
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.signOut", surface: false)
            }
        }
    }

    private func select(_ env: AppConfiguration.SelectedEnvironment) {
        guard !isSwitching else { return }   // a second tap mid-switch is ignored
        isSwitching = true
        switchError = ""
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().switchTo(env, auth: authManager)
            } catch {
                // SPEC D28: shown inline (no banner host) and logged.
                switchError = error.localizedDescription
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.select", surface: false)
            }
            current = AppConfiguration.selectedEnvironment
            identity = DevLoginIdentity.current
            await refreshHealth()
        }
    }

    /// ui2-fixtures D13: sign out, then back in as `option`. Profile unmounts on the sign-out,
    /// so a failure is shown on Login (`AuthManager.loginNotice`) and only logged here.
    private func selectIdentity(_ option: DevLoginIdentity) {
        guard !isSwitching, option != identity else { return }
        isSwitching = true
        switchError = ""
        identity = option
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().switchIdentity(option, auth: authManager)
            } catch {
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.selectIdentity", surface: false)
            }
            identity = DevLoginIdentity.current
        }
    }

    /// Probes the three environments concurrently (each times out at 5 s).
    private func refreshHealth() async {
        for env in AppConfiguration.SelectedEnvironment.allCases { health[env] = .checking }
        await withTaskGroup(of: (AppConfiguration.SelectedEnvironment, EnvironmentHealth).self) { group in
            for env in AppConfiguration.SelectedEnvironment.allCases {
                group.addTask { (env, await EnvironmentActions().health(of: env)) }
            }
            for await (env, result) in group { health[env] = result }
        }
    }
}
