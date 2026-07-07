//
//  NotificationModels.swift
//  MakeReady
//
//  In-app notification models and API responses.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

// MARK: - Notification Models

/// In-app notification from the server
struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String        // "JOIN_REQUEST", "MEMBER_JOINED", "STUDY_SYNC_*"
    let title: String
    let body: String
    var isRead: Bool
    let data: NotificationData?
    let createdAt: Date
    /// Tappable actions (study-sync rows carry these; absent elsewhere).
    let actions: [NotificationAction]?
    /// Server coalescing key (informational — the server dedupes by it).
    let dedupeKey: String?

    /// Relative time string (e.g., "2m ago", "1h ago", "3d ago")
    var relativeTime: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

/// Data payload within a notification
struct NotificationData: Codable {
    let groupId: String?
    let requestId: String?
    let enrollmentId: String?
}

/// One tappable action on a notification: `view` names a client surface
/// ("enrollment-sync" is the only one wired), `params` carries its identity.
struct NotificationAction: Codable, Equatable {
    let label: String
    let view: String
    let params: [String: String]?
}

/// API response for notification list
struct NotificationListResponse: Codable {
    let success: Bool
    let notifications: [AppNotification]?
    let error: String?
}

/// API response for unread count
struct UnreadCountResponse: Codable {
    let success: Bool
    let count: Int?
    let error: String?
}
