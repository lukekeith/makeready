//
//  NotificationActions.swift
//  MakeReady
//
//  Actions for loading and managing in-app notifications.
//

import Foundation

/// Actions for managing in-app notifications.
struct NotificationActions {

    private let api = APIClient.shared
    private var state: AppState { AppState.shared }

    // MARK: - Load Notifications

    /// Fetch notifications from the server and populate the EntityStore.
    @MainActor
    func loadNotifications() async throws {
        let response: NotificationListResponse = try await api.get(
            "/api/notifications?limit=50",
            responseType: NotificationListResponse.self
        )

        guard response.success, let notifications = response.notifications else {
            throw APIError.serverError(response.error ?? "Failed to load notifications")
        }

        state.notifications.replaceAll(notifications)
    }

    // MARK: - Unread Count

    /// Fetch just the unread count (lightweight badge update).
    @MainActor
    func loadUnreadCount() async throws {
        let response: UnreadCountResponse = try await api.get(
            "/api/notifications/unread-count",
            responseType: UnreadCountResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to load unread count")
        }

        // If we haven't loaded full notifications yet, sync the count via a minimal load
        // so that unreadNotificationCount computed property works
        if state.notifications.isEmpty && (response.count ?? 0) > 0 {
            try await loadNotifications()
        }
    }

    // MARK: - Mark as Read

    /// Mark specific notifications as read.
    @MainActor
    func markAsRead(ids: [String]) async throws {
        let body: [String: Any] = ["ids": ids]

        let response: APISuccessResponse = try await api.post(
            "/api/notifications/mark-read",
            body: body,
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to mark notifications as read")
        }

        // Update local state
        for id in ids {
            if var notification = state.notifications[id] {
                notification.isRead = true
                state.notifications.upsert(notification)
            }
        }
    }

    /// Mark all notifications as read.
    @MainActor
    func markAllAsRead() async throws {
        let body: [String: Any] = ["all": true]

        let response: APISuccessResponse = try await api.post(
            "/api/notifications/mark-read",
            body: body,
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to mark all as read")
        }

        // Update local state
        for notification in state.notifications.all {
            if !notification.isRead {
                var updated = notification
                updated.isRead = true
                state.notifications.upsert(updated)
            }
        }
    }
}
