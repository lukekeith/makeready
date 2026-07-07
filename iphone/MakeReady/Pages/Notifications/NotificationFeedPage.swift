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
                        .font(Typography.s40)
                        .foregroundColor(.white.opacity(0.3))
                    Text("No notifications yet")
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.orderedNotifications) { notification in
                            NotificationRow(
                                notification: notification,
                                onAction: { action in
                                    handleAction(notification, action: action)
                                }
                            )
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
            // Background feed load — console-only.
            state.recordError(error, context: "NotificationFeedPage.loadNotifications")
        }
    }

    private func handleTap(_ notification: AppNotification) {
        // Mark as read
        if !notification.isRead {
            // Silent: best-effort read receipt — the unread state self-corrects
            // on the next feed load, and the user is mid-navigation.
            Task { try? await NotificationActions().markAsRead(ids: [notification.id]) }
        }

        // Study-sync rows route to the enrollment's Study Sync settings
        // (their data carries enrollmentId, not groupId).
        if let enrollmentId = notification.data?.enrollmentId,
           notification.type.hasPrefix("STUDY_SYNC") {
            overlayManager.dismiss(.notificationFeed)
            PushNotificationManager.shared.pendingDeepLink = .enrollmentSync(enrollmentId: enrollmentId)
            return
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

    /// A tapped action button. `view` names a client surface — only
    /// "enrollment-sync" is wired; unknown views mark read and stay put.
    private func handleAction(_ notification: AppNotification, action: NotificationAction) {
        if !notification.isRead {
            // Silent: best-effort read receipt — same contract as handleTap.
            Task { try? await NotificationActions().markAsRead(ids: [notification.id]) }
        }

        if action.view == "enrollment-sync",
           let enrollmentId = action.params?["enrollmentId"] {
            overlayManager.dismiss(.notificationFeed)
            PushNotificationManager.shared.pendingDeepLink = .enrollmentSync(enrollmentId: enrollmentId)
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification
    var onAction: ((NotificationAction) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(Typography.s16)
                    .foregroundColor(Color.brandPrimary)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(notification.body)
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)

                // Action buttons (study-sync rows: "Review updates" etc.)
                if let actions = notification.actions, !actions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.label) { action in
                            BoxButton(
                                action: { onAction?(action) },
                                label: action.label,
                                variant: .secondary,
                                size: .sm
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Spacer()

            // Time + unread dot
            VStack(alignment: .trailing, spacing: 4) {
                Text(notification.relativeTime)
                    .font(Typography.s11)
                    .foregroundColor(.white.opacity(0.4))

                if !notification.isRead {
                    Circle()
                        .fill(Color.brandPrimary)
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
