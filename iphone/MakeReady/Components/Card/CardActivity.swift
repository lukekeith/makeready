//
//  CardActivity.swift
//  MakeReady
//
//  Activity log card - displays a single activity log entry
//  with category icon, message, timestamp, and status indicator
//

import SwiftUI

// MARK: - Data Model

struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let category: String
    let activityType: String
    let status: String
    let message: String
    let userId: String?
    let memberId: String?
    let groupId: String?
    let eventId: String?
    let enrollmentId: String?
    let organizationId: String?
    let metadata: [String: AnyCodable]?
    let createdAt: String
}

struct ActivityLogResponse: Codable {
    let success: Bool
    let logs: [ActivityLogEntry]
    let pagination: ActivityLogPagination
}

struct ActivityLogPagination: Codable {
    let hasMore: Bool
    let nextCursor: String?
    let count: Int
}

/// Type-erased Codable for metadata
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String { try container.encode(string) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let bool = value as? Bool { try container.encode(bool) }
    }
}

// MARK: - Card Component

struct CardActivity: View {
    let entry: ActivityLogEntry

    private var categoryIcon: String {
        switch entry.category {
        case "AUTH": return "person.badge.key"
        case "JOIN": return "person.badge.plus"
        case "ACCESS": return "eye"
        default: return "circle"
        }
    }

    private var categoryColor: Color {
        switch entry.category {
        case "AUTH": return Color.brandPrimary
        case "JOIN": return Color.success
        case "ACCESS": return Color(hex: "#4a90d9")
        default: return .white.opacity(0.5)
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case "SUCCESS": return Color.success
        case "FAILURE": return Color(hex: "#ff4444")
        case "WARNING": return Color(hex: "#ffaa00")
        default: return .white.opacity(0.3)
        }
    }

    /// Shared per-render formatter (Phase 5.1 formatter pass; main-thread).
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var formattedTime: String {
        guard let date = Self.isoFormatter.date(from: entry.createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: entry.createdAt) else { return "" }
            return relativeTime(from: date)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }

        return DateFormatters.monthDay.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon)
                    .font(Typography.s16)
                    .foregroundColor(categoryColor)
            }

            // Message and metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(Typography.s15)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(entry.category.capitalized)
                        .font(Typography.s12Medium)
                        .foregroundColor(.white.opacity(0.4))

                    Text("·")
                        .foregroundColor(.white.opacity(0.3))

                    Text(formattedTime)
                        .font(Typography.s12)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 4) {
            CardActivity(entry: ActivityLogEntry(
                id: "1", category: "AUTH", activityType: "AUTH_GOOGLE_LOGIN_SUCCESS",
                status: "SUCCESS", message: "User logged in via Google OAuth",
                userId: nil, memberId: nil, groupId: nil, eventId: nil,
                enrollmentId: nil, organizationId: nil, metadata: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120))
            ))

            CardActivity(entry: ActivityLogEntry(
                id: "2", category: "JOIN", activityType: "JOIN_GROUP_REQUEST",
                status: "SUCCESS", message: "John Doe requested to join Young Professionals",
                userId: nil, memberId: nil, groupId: nil, eventId: nil,
                enrollmentId: nil, organizationId: nil, metadata: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
            ))

            CardActivity(entry: ActivityLogEntry(
                id: "3", category: "ACCESS", activityType: "ACCESS_LESSON_VIEW",
                status: "WARNING", message: "Failed to access lesson - enrollment expired",
                userId: nil, memberId: nil, groupId: nil, eventId: nil,
                enrollmentId: nil, organizationId: nil, metadata: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
            ))
        }
        .padding(16)
    }
}
