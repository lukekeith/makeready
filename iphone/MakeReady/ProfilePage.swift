//
//  ProfilePage.swift
//  MakeReady
//
//  User profile page
//

import SwiftUI

struct ProfilePage: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page title
                PageTitle.iconTitle(
                    title: "My Profile",
                    icon: "chevron.left",
                    onIconTap: {
                        dismiss()
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
                            }
                            .padding(.top, 32)
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 80)
                    }
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
    ProfilePage()
        .environmentObject(AuthManager())
}
