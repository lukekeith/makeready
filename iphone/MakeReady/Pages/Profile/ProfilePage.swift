//
//  ProfilePage.swift
//  MakeReady
//
//  User profile page
//

import SwiftUI

struct ProfilePage: View {
    let overlayManager: OverlayManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedEnvironment = Configuration.selectedEnvironment
    @State private var environmentStatus: [Configuration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var localIP: String = Configuration.localServerIP ?? "192.168.1.65"

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
                        overlayManager.dismiss(id: OverlayID.profilePage)
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
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .padding(.top, 40)

                            // User info
                            VStack(spacing: 12) {
                                Text(user.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)

                                Text(user.email)
                                    .font(.system(size: 17, weight: .regular))
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

            // Auto-check health of the currently selected environment
            if Configuration.devMode {
                checkEnvironmentHealth(selectedEnvironment)
            }
        }
    }
}

// MARK: - Environment Selector

extension ProfilePage {
    var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(Configuration.SelectedEnvironment.allCases.enumerated()), id: \.element) { index, env in
                    Button {
                        selectedEnvironment = env
                        Configuration.selectedEnvironment = env
                        checkEnvironmentHealth(env)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedEnvironment == env ? "circle.inset.filled" : "circle")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(selectedEnvironment == env ? Color(hex: "#6c47ff") : .white.opacity(0.3))
                                .frame(width: 24)

                            Text(env.rawValue)
                                .font(.system(size: 17, weight: .regular))
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    HStack(spacing: 0) {
                        TextField("e.g. 192.168.1.100", text: $localIP)
                            .font(.system(size: 17, weight: .regular))
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

                    Text("API: \(Configuration.baseURL)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)

                    Text("Client: \(Configuration.clientBaseURL)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)
                }
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hex: "#6c47ff"))
                            .frame(width: 24)

                        Text(item.label)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.white)

                        Spacer()

                        Text(item.value)
                            .font(.system(size: 17, weight: .regular))
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
        .environmentObject(AuthManager())
}
