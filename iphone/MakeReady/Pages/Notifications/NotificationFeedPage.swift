//
//  NotificationFeedPage.swift
//  MakeReady
//
//  In-app notification feed presented as a modal.
//

import SwiftUI

struct NotificationFeedPage: View {

    @Environment(OverlayManager.self) private var overlayManager

    private var state: AppState { AppState.shared }

    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PageTitle.iconTitleLink(
                title: "Notifications",
                leftIcon: "xmark",
                rightLink: state.unreadNotificationCount > 0 ? "Mark all read" : "",
                onLeftIconTap: { overlayManager.dismiss(.notificationFeed) },
                onRightLinkTap: {
                    Task { try? await NotificationActions().markAllAsRead() }
                }
            )

            if isLoading && state.notifications.isEmpty {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if state.orderedNotifications.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No notifications yet")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.orderedNotifications) { notification in
                            NotificationRow(notification: notification)
                                .onTapGesture {
                                    handleTap(notification)
                                }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await NotificationActions().loadNotifications()
        } catch {
            NSLog("❌ NotificationFeedPage: Failed to load notifications: \(error)")
        }
    }

    private func handleTap(_ notification: AppNotification) {
        // Mark as read
        if !notification.isRead {
            Task { try? await NotificationActions().markAsRead(ids: [notification.id]) }
        }

        // Navigate to relevant content
        if let groupId = notification.data?.groupId {
            overlayManager.dismiss(.notificationFeed)

            // Navigate based on notification type
            switch notification.type {
            case "JOIN_REQUEST":
                PushNotificationManager.shared.pendingDeepLink = .joinRequests(groupId: groupId)
            case "MEMBER_JOINED":
                PushNotificationManager.shared.pendingDeepLink = .group(groupId: groupId)
            default:
                PushNotificationManager.shared.pendingDeepLink = .group(groupId: groupId)
            }
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#6c47ff").opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#6c47ff"))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(notification.body)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            // Time + unread dot
            VStack(alignment: .trailing, spacing: 4) {
                Text(notification.relativeTime)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))

                if !notification.isRead {
                    Circle()
                        .fill(Color(hex: "#6c47ff"))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notification.isRead ? Color.clear : Color.white.opacity(0.03))
    }

    private var iconName: String {
        switch notification.type {
        case "JOIN_REQUEST":
            return "person.badge.plus"
        case "MEMBER_JOINED":
            return "person.badge.checkmark"
        default:
            return "bell.fill"
        }
    }
}
