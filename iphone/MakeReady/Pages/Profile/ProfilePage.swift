//
//  ProfilePage.swift
//  MakeReady
//
//  User profile page
//

import SwiftUI

struct ProfilePage: View {
    let overlayManager: OverlayManager
    @Environment(AuthManager.self) var authManager
    @State private var selectedEnvironment = Configuration.selectedEnvironment
    @State private var environmentStatus: [Configuration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var localIP: String = Configuration.localServerIP ?? "192.168.1.65"
    @State private var apiPort: String = Configuration.localAPIPort
    @State private var clientPort: String = Configuration.localClientPort

    /// Result of the manual "Test connection" probe against the entered Local
    /// IP/port — lets a leader validate Local before switching to it.
    @State private var localTestStatus: LocalConnectionTest = .untested

    enum EnvironmentHealth {
        case checking  // yellow
        case alive     // green
        case dead      // red
    }

    /// Outcome of the Profile screen's "Test connection" button.
    enum LocalConnectionTest: Equatable {
        case untested
        case testing
        case reachable            // a MakeReady server answered /health
        case notMakeReady         // something answered, but not MakeReady
        case unreachable          // nothing answered

        var label: String {
            switch self {
            case .untested: return "Not tested"
            case .testing: return "Testing…"
            case .reachable: return "Connected"
            case .notMakeReady: return "Reachable, but not a MakeReady server"
            case .unreachable: return "Couldn't connect"
            }
        }

        var color: Color {
            switch self {
            case .untested: return .white.opacity(0.3)
            case .testing: return .yellow
            case .reachable: return .green
            case .notMakeReady: return .orange
            case .unreachable: return .red
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page title
                PageTitle.iconTitle(
                    title: "My Profile",
                    icon: "xmark",
                    onIconTap: {
                        overlayManager.dismiss(.profilePage)
                    }
                )

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        if let user = authManager.currentUser {
                            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Text(user.name.prefix(1))
                                            .font(Typography.s48Bold)
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .padding(.top, 40)

                            // User info
                            VStack(spacing: 12) {
                                Text(user.name)
                                    .font(Typography.s28Bold)
                                    .foregroundColor(.white)

                                Text(user.email)
                                    .font(Typography.s17)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, 16)

                            // Profile sections
                            VStack(spacing: 16) {
                                ProfileSection(title: "Account Details", items: [
                                    ProfileItem(icon: "person.fill", label: "Name", value: user.name),
                                    ProfileItem(icon: "envelope.fill", label: "Email", value: user.email)
                                ])

                                ProfileSection(title: "Settings", items: [
                                    ProfileItem(icon: "bell.fill", label: "Notifications", value: "Enabled"),
                                    ProfileItem(icon: "lock.fill", label: "Privacy", value: "Default")
                                ])

                                if Configuration.devMode {
                                    environmentSection
                                }
                            }
                            .padding(.top, 32)
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .onAppear {
            // Load persisted IP into state, or save the hardcoded default
            if let saved = Configuration.localServerIP, !saved.isEmpty {
                localIP = saved
            } else if !localIP.isEmpty {
                Configuration.localServerIP = localIP
            }

            // Auto-check health of the currently selected environment.
            // For Local, heal the API port first (it may have moved) so the
            // health check and displayed URL reflect the right port.
            if Configuration.devMode {
                if selectedEnvironment == .local {
                    healLocalPortThenCheck()
                } else {
                    checkEnvironmentHealth(selectedEnvironment)
                }
            }
        }
    }
}

// MARK: - Environment Selector

extension ProfilePage {
    var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(Configuration.SelectedEnvironment.allCases.enumerated()), id: \.element) { index, env in
                    Button {
                        let previous = Configuration.selectedEnvironment
                        selectedEnvironment = env
                        if previous != env {
                            // Flush the outgoing environment's data to ITS
                            // snapshot file before the switch (persistence
                            // paths are environment-scoped).
                            AppState.shared.persistImmediately()
                        }
                        Configuration.selectedEnvironment = env
                        if previous != env {
                            // Swap caches: each environment renders only its
                            // own data (entities created on local 404 when
                            // mutated against production, and vice versa).
                            AppState.shared.reloadForEnvironmentSwitch()
                        }
                        if env == .local {
                            // Heal the dev port + refresh the health dot, and on
                            // a real switch sign in silently: Local uses
                            // passwordless dev-login, so land in the app instead
                            // of the login screen. If Local is unreachable we
                            // roll back to `previous` and surface an error rather
                            // than stranding the user (see healLocalPortThenCheck).
                            healLocalPortThenCheck(authenticate: previous != env, previous: previous)
                        } else {
                            checkEnvironmentHealth(env)
                            if previous != env {
                                // Sessions are per-environment: re-evaluate auth
                                // so the user lands on the login screen instead
                                // of silent 401s; with a valid session, refresh
                                // the new environment's data.
                                Task {
                                    await authManager.checkAuthStatus()
                                    if authManager.isAuthenticated {
                                        await AppState.shared.loadInitialData()
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedEnvironment == env ? "circle.inset.filled" : "circle")
                                .font(Typography.s18)
                                .foregroundColor(selectedEnvironment == env ? Color.brandPrimary : .white.opacity(0.3))
                                .frame(width: 24)

                            Text(env.rawValue)
                                .font(Typography.s17)
                                .foregroundColor(.white)

                            Spacer()

                            if let status = environmentStatus[env] {
                                Circle()
                                    .fill(healthColor(status))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < Configuration.SelectedEnvironment.allCases.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Local server config — always editable in dev mode (not gated on
            // Local being the active selection). Selecting Local can roll back
            // to the previous environment when the server is unreachable, so
            // these fields must stay reachable to fix a wrong IP/port and retry.
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text("Server IP Address")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    HStack(spacing: 0) {
                        TextField("e.g. 192.168.1.100", text: $localIP)
                            .font(Typography.s17)
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: localIP) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                Configuration.localServerIP = trimmed.isEmpty ? nil : trimmed
                                // Entered target changed — previous test result is stale.
                                localTestStatus = .untested
                                Log.api.info("Local Server IP field changed → '\(trimmed, privacy: .public)' (saved=\(Configuration.localServerIP ?? "nil", privacy: .public))")
                            }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)

                    Text("Ports")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        portField(label: "API", text: $apiPort, placeholder: Configuration.defaultAPIPort) { newValue in
                            Configuration.localAPIPort = newValue
                            // Entered target changed — previous test result is stale.
                            localTestStatus = .untested
                        }
                        portField(label: "Client", text: $clientPort, placeholder: Configuration.defaultClientPort) { newValue in
                            Configuration.localClientPort = newValue
                        }
                    }

                    // Live preview of what the app will target for Local —
                    // reflects the entered IP/port regardless of which
                    // environment is currently active.
                    Text("API: \(Configuration.localAPIBaseURL)")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)

                    Text("Client: \(Configuration.localClientBaseURL)")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)

                    // Test the entered Local connection WITHOUT switching to it,
                    // so a wrong IP/port surfaces here instead of on switch.
                    ActionButton(
                        label: localTestStatus == .testing ? "Testing…" : "Test connection",
                        icon: "antenna.radiowaves.left.and.right",
                        variant: .white
                    ) {
                        testLocalConnection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(localTestStatus.color)
                            .frame(width: 10, height: 10)
                        Text(localTestStatus.label)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func portField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        onSave: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.s11)
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 16)

            TextField(placeholder, text: text)
                .font(Typography.s17)
                .foregroundColor(.white)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .onChange(of: text.wrappedValue) { _, newValue in
                    onSave(newValue)
                }
        }
    }

    /// Heal the Local API port (probe the configured range for a MakeReady
    /// server), reflect any change back into the field, then run the health check.
    /// Heal the local dev API port and refresh the Local health dot. When
    /// `authenticate` is true (a real switch *to* Local, not just opening
    /// Profile), also sign in silently: Local uses passwordless dev-login, so a
    /// reachable server lands the user in the app instead of the login screen.
    ///
    /// If Local is unreachable (or dev-login is refused), it does **not** strand
    /// the user on the login screen or silently switch them to Production.
    /// Instead it rolls the selection back to `previous`, keeps them signed in
    /// there, and surfaces an error naming the host — so they can correct the
    /// Server IP (always editable below) and try Local again.
    private func healLocalPortThenCheck(
        authenticate: Bool = false,
        previous: Configuration.SelectedEnvironment? = nil
    ) {
        environmentStatus[.local] = .checking
        Task {
            let outcome = await LocalPortHealer.heal()
            await MainActor.run {
                apiPort = Configuration.localAPIPort
                checkEnvironmentHealth(.local)
            }
            guard authenticate else { return }

            // Reachable = the server actually answered (already-healthy port or
            // one we healed to); anything else means Local is down.
            let reachable: Bool
            switch outcome {
            case .healthy, .healed: reachable = true
            case .notFound, .skipped: reachable = false
            }

            if reachable, await authManager.signInToReachableLocal() {
                if authManager.isAuthenticated {
                    await AppState.shared.loadInitialData()
                }
                return
            }

            // Couldn't reach / sign in to Local — recover without a bounce.
            await revertLocalSwitch(to: previous ?? .production)
            let host = Configuration.localServerIP ?? Configuration.defaultLocalIP
            AppState.shared.recordError(
                AuthError.localServerUnreachable(host: host, port: Configuration.localAPIPort),
                context: "ProfilePage.switchToLocal",
                surface: true,
                friendlyMessage: "Can't reach the local server at \(host):\(Configuration.localAPIPort). Update the Server IP below and switch to Local again."
            )
        }
    }

    /// Undo an in-progress switch to Local after it failed to connect: return
    /// the active environment to `previous`, swap its cache back in, and
    /// re-validate auth there (the user was signed in on `previous` when they
    /// tried to switch, so this keeps them in the app rather than at login).
    @MainActor
    private func revertLocalSwitch(to previous: Configuration.SelectedEnvironment) async {
        AppState.shared.persistImmediately()
        selectedEnvironment = previous
        Configuration.selectedEnvironment = previous
        AppState.shared.reloadForEnvironmentSwitch()
        checkEnvironmentHealth(previous)
        await authManager.checkAuthStatus()
        if authManager.isAuthenticated {
            await AppState.shared.loadInitialData()
        }
    }

    private func healthColor(_ status: EnvironmentHealth) -> Color {
        switch status {
        case .checking: return .yellow
        case .alive: return .green
        case .dead: return .red
        }
    }

    /// Probe the entered Local server (`Configuration.localAPIBaseURL`) WITHOUT
    /// switching environments, so a wrong IP/port surfaces here instead of on
    /// switch. Confirms it's actually a MakeReady server via /health's `service`
    /// (a plain 200 from some other server counts as "reachable, not MakeReady").
    private func testLocalConnection() {
        let base = Configuration.localAPIBaseURL
        guard let url = URL(string: "\(base)/health") else {
            Log.api.error("Test connection ❌ invalid Local URL: \(base, privacy: .public)/health")
            localTestStatus = .unreachable
            return
        }
        Log.api.info("Test connection → \(url.absoluteString, privacy: .public) [field IP='\(localIP, privacy: .public)', saved IP=\(Configuration.localServerIP ?? "nil", privacy: .public), API port=\(Configuration.localAPIPort, privacy: .public)]")
        localTestStatus = .testing
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Task {
            var result: LocalConnectionTest = .unreachable
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "<non-text body, \(data.count) bytes>"
                if code == 200,
                   let obj = try? JSONSerialization.jsonObject(with: data),
                   let json = obj as? [String: Any],
                   (json["service"] as? String) == "makeready" {
                    result = .reachable
                    Log.api.info("Test connection ✅ MakeReady at \(base, privacy: .public) — HTTP 200 \(body, privacy: .public)")
                } else {
                    // A response came back (host reachable) but it isn't a
                    // MakeReady 200 — wrong port/service, or an error page.
                    result = .notMakeReady
                    Log.api.error("Test connection ⚠️ reachable but not MakeReady at \(base, privacy: .public) — HTTP \(code, privacy: .public) \(body, privacy: .public)")
                }
            } catch {
                result = .unreachable
                Log.api.error("Test connection ❌ couldn't connect to \(base, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            }
            await MainActor.run { localTestStatus = result }
        }
    }

    private func checkEnvironmentHealth(_ env: Configuration.SelectedEnvironment) {
        environmentStatus[env] = .checking

        let urlString: String
        switch env {
        case .local:
            // Use the same resolution as Configuration.baseURL
            urlString = "\(Configuration.baseURL)/health"
            if Configuration.baseURL.contains("api.makeready.org") && Configuration.selectedEnvironment == .local {
                // No local URL resolved — can't health check
                environmentStatus[env] = .dead
                return
            }
        case .staging:
            urlString = "https://staging.api.makeready.org/health"
        case .production:
            urlString = "https://api.makeready.org/health"
        }

        guard let url = URL(string: urlString) else {
            environmentStatus[env] = .dead
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let httpResponse = response as? HTTPURLResponse
                await MainActor.run {
                    environmentStatus[env] = (httpResponse?.statusCode == 200) ? .alive : .dead
                }
            } catch {
                await MainActor.run {
                    environmentStatus[env] = .dead
                }
            }
        }
    }
}

// Profile section component
struct ProfileSection: View {
    let title: String
    let items: [ProfileItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(Typography.s16)
                            .foregroundColor(Color.brandPrimary)
                            .frame(width: 24)

                        Text(item.label)
                            .font(Typography.s17)
                            .foregroundColor(.white)

                        Spacer()

                        Text(item.value)
                            .font(Typography.s17)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < items.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

// Profile item model
struct ProfileItem {
    let icon: String
    let label: String
    let value: String
}

#Preview {
    ProfilePage(overlayManager: OverlayManager())
        .environment(AuthManager())
}
