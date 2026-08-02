//
//  AnalyticsModels.swift
//  MakeReady
//
//  Chart/analytics API response models.
//
//  HeatmapBucket/DayActivityCount (+ their response wrappers) moved here from
//  MemberHomePage.swift — they were always shared state (AppState +
//  PersistedState reference them), and the Program Analytics tab now reuses
//  them too.
//
//  ProgramAnalytics* mirrors GET /api/programs/:id/analytics
//  (docs/features/analytics/program-analytics-tab.md § Data contract). The
//  wrapper's keys are additive-only, so decoding stays stable across server
//  releases; the Phase-C sections (funnel, content mix, tops) are modeled now
//  and arrive as empty arrays until the server fills them.
//

import Foundation

// MARK: - Engagement Chart Models (shared by MainHome + Program Analytics)

struct HeatmapBucket: Codable {
    let day: Int      // 0 (Sun) - 6 (Sat)
    let hour: Int     // 0-23
    let count: Int
}

struct HeatmapResponse: Codable {
    let success: Bool
    let data: [HeatmapBucket]?
    let error: String?
}

struct DayActivityCount: Codable {
    let date: String  // "yyyy-MM-dd" (monthly series use the month's first day)
    let count: Int
}

struct WeeklyStatsResponse: Codable {
    let success: Bool
    let data: [DayActivityCount]?
    let error: String?
}

// MARK: - Program Analytics (GET /api/programs/:id/analytics)

struct ProgramAnalyticsKpis: Codable {
    let membersReached: Int
    let activeEnrollments: Int
    let totalEnrollments: Int
    let lessonCompletions: Int
    /// 0–1 (server-computed registry ratio; never divide metrics client-side)
    let completionRate: Double
    let videoCompletions: Int
    let watchSeconds: Int
    /// 0–1
    let avgWatchPercent: Double
}

struct ProgramAnalyticsRecent: Codable {
    let week: [DayActivityCount]   // 7 daily points, pre-zero-filled
    let month: [DayActivityCount]  // 30 daily points
    let year: [DayActivityCount]   // 12 monthly points
}

struct ProgramFunnelRow: Codable {
    let dayNumber: Int
    let membersCompleted: Int
}

struct ProgramContentMixRow: Codable {
    let activityType: String
    let completions: Int
}

struct ProgramTopMember: Codable {
    let memberId: String
    let name: String
    let avatarUrl: String?
    let groupName: String?
    let completions: Int
}

struct ProgramTopEnrollment: Codable {
    let enrollmentId: String
    let groupName: String?
    let memberCount: Int
    let lessonCompletions: Int
    let completionPct: Double
}

/// Top-groups table row (owner-requested 2026-07-30): every enrolled group
/// ranked by completion percentage (top 10).
struct ProgramTopGroup: Codable {
    let groupId: String
    let groupName: String
    let memberCount: Int
    let lessonCompletions: Int
    /// 0–1, server-computed (completions ÷ Σ members × active schedules)
    let completionPct: Double
}

struct ProgramAnalytics: Codable {
    /// Last analytics_events matview refresh (ISO8601) — surfaced as the
    /// tab's "As of …" caption so stale/offline views are honestly labeled.
    let freshAsOf: String?
    let kpis: ProgramAnalyticsKpis
    let recent: ProgramAnalyticsRecent
    let heatmap: [HeatmapBucket]
    let topGroups: [ProgramTopGroup]
    let funnel: [ProgramFunnelRow]
    let contentMix: [ProgramContentMixRow]
    let topMembers: [ProgramTopMember]
    let topEnrollments: [ProgramTopEnrollment]

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = ISO8601DateFormatter()

    var freshAsOfDate: Date? {
        guard let freshAsOf else { return nil }
        return Self.isoFractional.date(from: freshAsOf) ?? Self.iso.date(from: freshAsOf)
    }
}

struct ProgramAnalyticsResponse: Codable {
    let success: Bool
    let error: String?
    let freshAsOf: String?
    let kpis: ProgramAnalyticsKpis?
    let recent: ProgramAnalyticsRecent?
    let heatmap: [HeatmapBucket]?
    let topGroups: [ProgramTopGroup]?
    let funnel: [ProgramFunnelRow]?
    let contentMix: [ProgramContentMixRow]?
    let topMembers: [ProgramTopMember]?
    let topEnrollments: [ProgramTopEnrollment]?

    var analytics: ProgramAnalytics? {
        guard success, let kpis, let recent else { return nil }
        return ProgramAnalytics(
            freshAsOf: freshAsOf,
            kpis: kpis,
            recent: recent,
            heatmap: heatmap ?? [],
            topGroups: topGroups ?? [],
            funnel: funnel ?? [],
            contentMix: contentMix ?? [],
            topMembers: topMembers ?? [],
            topEnrollments: topEnrollments ?? []
        )
    }
}
