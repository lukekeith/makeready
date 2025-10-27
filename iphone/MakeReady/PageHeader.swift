//
//  PageHeader.swift
//  MakeReady
//
//  Page header with tabs, notification icon, and avatar
//

import SwiftUI

struct PageHeader: View {
    let tabs: [String]
    @Binding var activeTab: Int
    let avatarURL: String?
    let onNotificationTap: () -> Void
    let onAvatarTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Tabs on the left - hug content
            HStack(spacing: 16) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    TabButton(
                        title: tab,
                        isActive: index == activeTab,
                        onTap: {
                            activeTab = index
                        }
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer()

            // Right side: notification icon and avatar
            HStack(spacing: 16) {
                // Notification icon
                Button(action: onNotificationTap) {
                    Image("IconNotification")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                }

                // Avatar
                Button(action: onAvatarTap) {
                    if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    } else {
                        // Default avatar placeholder
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .padding(16)
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(0.7))

                // Active tab underline - matches text width
                Rectangle()
                    .fill(Color(hex: "#6c47ff"))
                    .frame(height: 2)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            PageHeader(
                tabs: ["Home"],
                activeTab: .constant(0),
                avatarURL: nil,
                onNotificationTap: {
                    print("Notification tapped")
                },
                onAvatarTap: {
                    print("Avatar tapped")
                }
            )
            Spacer()
        }
    }
}
