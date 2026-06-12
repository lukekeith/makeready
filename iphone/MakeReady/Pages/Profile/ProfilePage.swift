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

    enum EnvironmentHealth {
        case checking  // yellow
        case alive     // green
        case dead      // red
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
                        if env == .local {
                            healLocalPortThenCheck()
                        } else {
                            checkEnvironmentHealth(env)
                        }
                        if previous != env {
                            // Swap caches: each environment renders only its
                            // own data (entities created on local 404 when
                            // mutated against production, and vice versa).
                            AppState.shared.reloadForEnvironmentSwitch()
                            // Sessions are per-environment too: re-evaluate
                            // auth so the user lands on the login screen
                            // instead of silent 401s; with a valid session,
                            // refresh the new environment's data.
                            Task {
                                await authManager.checkAuthStatus()
                                if authManager.isAuthenticated {
                                    await AppState.shared.loadInitialData()
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

            // Local server IP field — shown when Local is selected
            if selectedEnvironment == .local {
                VStack(alignment: .leading, spacing: 8) {
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
                        }
                        portField(label: "Client", text: $clientPort, placeholder: Configuration.defaultClientPort) { newValue in
                            Configuration.localClientPort = newValue
                        }
                    }

                    Text("API: \(Configuration.baseURL)")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)

                    Text("Client: \(Configuration.clientBaseURL)")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.3))
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
    private func healLocalPortThenCheck() {
        environmentStatus[.local] = .checking
        Task {
            await LocalPortHealer.heal()
            await MainActor.run {
                apiPort = Configuration.localAPIPort
                checkEnvironmentHealth(.local)
            }
        }
    }

    private func healthColor(_ status: EnvironmentHealth) -> Color {
        switch status {
        case .checking: return .yellow
        case .alive: return .green
        case .dead: return .red
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
