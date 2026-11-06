import SwiftUI

/// staging-fixtures D11/D14: the exact copy of Reset's confirm and its inline messages.
enum FixtureResetCopy {
    static let confirmTitle = "Reset this test data?"
    static func confirmMessage(for fixture: StagingFixture) -> String { "Reset \(fixture.title) for everyone on it?" }
    static let action = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Reset", tone: .destructive)
    static let cancelLabel = "Cancel"
    static let startedMessage = "Reset started. This takes a few minutes and affects everyone on this fixture."
    static let failedMessage = "Couldn't start the reset. Try again."
}

/// SPEC D15/D16: a stopgap until profile-home is designed.
/// ui2-fixtures D13: in a dev build on Local it also picks the dev-login identity.
struct ProfileStopgapContainer: View {
    static func showsEnvironmentSwitcher(devMode: Bool) -> Bool { devMode }

    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    static func showsIdentityPicker(devMode: Bool, env: AppConfiguration.SelectedEnvironment) -> Bool {
        devMode && env == .local
    }

    /// staging-fixtures D4: the "Test data" group shows only with a fixture key on Staging.
    static func showsFixturePicker(fixtureKey: String, env: AppConfiguration.SelectedEnvironment) -> Bool {
        !fixtureKey.isEmpty && env == .staging
    }

    private static var environments: [AppConfiguration.SelectedEnvironment] {
        AppConfiguration.switcherEnvironments(for: AppConfiguration.current)
    }

    @Environment(AuthManager.self) private var authManager
    @State private var current = AppConfiguration.selectedEnvironment
    @State private var identity = DevLoginIdentity.current
    @State private var health: [AppConfiguration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var fixture = StagingFixture.current
    @State private var switchError = ""
    @State private var resetNotice = ""
    @State private var resetMenuOpen = false
    @State private var isSwitching = false

    var body: some View {
        VStack(spacing: Token.Space.sectionGap) {
            Spacer()
            PageActionButton(label: "Sign out", role: .secondary, onTap: signOut)
            if Self.showsEnvironmentSwitcher(devMode: AppConfiguration.devMode) {
                VStack(spacing: 0) {
                    ForEach(Self.environments, id: \.self) { env in
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
                if Self.showsFixturePicker(fixtureKey: AppConfiguration.fixtureAccessKey, env: current) {
                    fixturePicker
                }
                if !switchError.isEmpty {
                    Text(switchError)
                        .designTextStyle(Token.TypeStyle.body)
                        .foregroundStyle(Token.negative)
                }
                if !resetNotice.isEmpty {
                    Text(resetNotice)
                        .designTextStyle(Token.TypeStyle.body)
                        .foregroundStyle(Token.textSecondary)
                }
            }
            Spacer()
        }
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.layoutBackground)
        .task { await refreshHealth() }
        .actionMenuPresentation(isPresented: resetMenuOpen, onDismiss: { resetMenuOpen = false }) {
            ActionMenuOverlay(
                title: FixtureResetCopy.confirmTitle,
                message: FixtureResetCopy.confirmMessage(for: fixture),
                actions: [FixtureResetCopy.action],
                doneLabel: FixtureResetCopy.cancelLabel,
                onSelect: { _ in
                    resetMenuOpen = false
                    resetFixture()
                },
                onDone: { resetMenuOpen = false }
            )
        }
    }

    /// staging-fixtures D4: Fully populated · New group, then Reset for the selected one.
    private var fixturePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Test data")
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
            ForEach(StagingFixture.allCases, id: \.self) { option in
                RadioOptionRow(
                    title: option.title,
                    selected: option == fixture,
                    onSelect: { selectFixture(option) }
                )
            }
            PageActionButton(label: "Reset", role: .secondary, onTap: {
                guard !isSwitching else { return }
                resetMenuOpen = true
            })
        }
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
        resetNotice = ""
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

    /// staging-fixtures D12: sign out, then back in as `option`. Profile unmounts on the sign-out,
    /// so a failure is shown on Login (`AuthManager.loginNotice`) and only logged here. The
    /// fixture is kept on failure.
    private func selectFixture(_ option: StagingFixture) {
        guard !isSwitching, option != fixture else { return }
        isSwitching = true
        switchError = ""
        resetNotice = ""
        fixture = option
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().switchFixture(option, auth: authManager)
            } catch {
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.selectFixture", surface: false)
            }
            fixture = StagingFixture.current
        }
    }

    /// staging-fixtures D11/D14: C2 for the current fixture; the result shows inline, with no
    /// sign-out and no progress tracking (D15).
    private func resetFixture() {
        guard !isSwitching else { return }
        isSwitching = true
        switchError = ""
        resetNotice = ""
        Task { @MainActor in
            defer { isSwitching = false }
            do {
                try await EnvironmentActions().resetFixture(StagingFixture.current, auth: authManager)
                resetNotice = FixtureResetCopy.startedMessage
            } catch {
                switchError = FixtureResetCopy.failedMessage
                AppState.shared.recordError(error, context: "ProfileStopgapContainer.reset", surface: false)
            }
        }
    }

    /// Probes the environments the build lists concurrently (each times out at 5 s).
    private func refreshHealth() async {
        for env in Self.environments { health[env] = .checking }
        await withTaskGroup(of: (AppConfiguration.SelectedEnvironment, EnvironmentHealth).self) { group in
            for env in Self.environments {
                group.addTask { (env, await EnvironmentActions().health(of: env)) }
            }
            for await (env, result) in group { health[env] = result }
        }
    }
}
