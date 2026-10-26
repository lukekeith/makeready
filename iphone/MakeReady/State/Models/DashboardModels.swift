import Foundation

/// Home dashboard data cached in `AppState.dashboard` (SPEC D20, D25; home-dashboard-data §iphone).
struct DashboardSnapshot: Codable, Equatable {
    var completedSeries: [String: Int] = [:]      // yyyy-MM-dd → lesson_completions, last 24 days
    var completedTotal: Int = 0
    var completedPrevious: Int?                   // compareToPrevious total
    var watchSeconds: Int?                        // snapshot, lifetime
    var activityDays: [String: Int] = [:]         // yyyy-MM-dd → completions, 28 back + today
    var kpiNames: [String] = ["lesson_completions", "watch_seconds"]
    var refreshedAt: Date?
    // home-dashboard-data (SPEC §iphone)
    var scheduledDays: [String: Int] = [:]        // yyyy-MM-dd → scheduled_lessons, 28 back … 7 ahead (D10)
    var dayMinutes: [String: Int] = [:]           // yyyy-MM-dd → Σ session minutes, rounded (D6)
    var dayBlocks: [String: [Int]] = [:]          // yyyy-MM-dd → 12 two-hour blocks, in SECONDS (D6)
    var sessions: [String: HomeSessionsResponse] = [:]   // "all" | "year" | "month" | "week" (D8, D13)
    var engagement: HomeEngagementResponse?       // nil = never fetched (D3)
    var following: HomeFollowingResponse?         // nil = never fetched (D4, D11)
}

extension DashboardSnapshot {
    /// Tolerant: a key missing from an older snapshot keeps its default, so adding a field
    /// never wipes the cached dashboard (SPEC F11 — every new key below MUST stay defaulted).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let empty = DashboardSnapshot()
        completedSeries = try container.decodeIfPresent([String: Int].self, forKey: .completedSeries) ?? empty.completedSeries
        completedTotal = try container.decodeIfPresent(Int.self, forKey: .completedTotal) ?? empty.completedTotal
        completedPrevious = try container.decodeIfPresent(Int.self, forKey: .completedPrevious)
        watchSeconds = try container.decodeIfPresent(Int.self, forKey: .watchSeconds)
        activityDays = try container.decodeIfPresent([String: Int].self, forKey: .activityDays) ?? empty.activityDays
        kpiNames = try container.decodeIfPresent([String].self, forKey: .kpiNames) ?? empty.kpiNames
        refreshedAt = try container.decodeIfPresent(Date.self, forKey: .refreshedAt)
        scheduledDays = try container.decodeIfPresent([String: Int].self, forKey: .scheduledDays) ?? empty.scheduledDays
        dayMinutes = try container.decodeIfPresent([String: Int].self, forKey: .dayMinutes) ?? empty.dayMinutes
        dayBlocks = try container.decodeIfPresent([String: [Int]].self, forKey: .dayBlocks) ?? empty.dayBlocks
        sessions = try container.decodeIfPresent([String: HomeSessionsResponse].self, forKey: .sessions) ?? empty.sessions
        engagement = try container.decodeIfPresent(HomeEngagementResponse.self, forKey: .engagement)
        following = try container.decodeIfPresent(HomeFollowingResponse.self, forKey: .following)
    }
}

struct AnalyticsQueryResponse: Decodable {
    let rows: [[String: AnalyticsValue]]
    let previousRows: [[String: AnalyticsValue]]?
}

enum AnalyticsValue: Decodable, Equatable {
    case int(Int), double(Double), string(String), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    /// Integer value; a fractional metric (e.g. `SUM(value)::float8`) is rounded.
    var int: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return value.isFinite ? Int(value.rounded()) : nil
        default: return nil
        }
    }
    var string: String? { if case .string(let value) = self { return value }; return nil }
}

/// `FilterState.swift` already has a file-private `PreferenceResponse`; this one is named apart to avoid shadowing.
struct DashboardPreferenceResponse: Decodable {
    let key: String
    let value: String
    let isDefault: Bool?
}

// MARK: - /api/home/* (home-dashboard-data SPEC §Contract — FROZEN shapes)
// Each type doubles as a cached snapshot section, so every key decodes with a default (F11).

/// `GET /api/home/sessions?range=` — one D8 range.
struct HomeSessionsResponse: Codable, Equatable {
    var averageSeconds: Int = 0
    var sessionCount: Int = 0          // unread by the mapper today (§Contract)
    var hourly: [Double] = []          // 24, index 0 = 12 AM, caller tz — sessions active during each hour (D23)
    var bins: [Double] = []            // 88 session-length bands over 0 … axisMinutes, normalised 0–1 (D18)
    var ticks: [Int] = []              // ≤ 4 axis labels in minutes, 0 first, axisMinutes last (D18)
    var axisMinutes: Int = 0
}

extension HomeSessionsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        averageSeconds = try c.decodeIfPresent(Int.self, forKey: .averageSeconds) ?? 0
        sessionCount = try c.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
        hourly = try c.decodeIfPresent([Double].self, forKey: .hourly) ?? []
        bins = try c.decodeIfPresent([Double].self, forKey: .bins) ?? []
        // A cache written before D18 holds date strings here: it decodes as no ticks, not a failure.
        ticks = (try? c.decodeIfPresent([Int].self, forKey: .ticks)) ?? []
        axisMinutes = try c.decodeIfPresent(Int.self, forKey: .axisMinutes) ?? 0
    }
}

/// One day of `GET /api/home/days` — Σ blocks = sessionSeconds (D6).
struct HomeDay: Codable, Equatable {
    var day: String = ""               // yyyy-MM-dd
    var sessionSeconds: Int = 0
    var blocks: [Int] = []             // 12 two-hour blocks, seconds, index 0 = 12–2 AM
}

extension HomeDay {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
        sessionSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionSeconds) ?? 0
        blocks = try c.decodeIfPresent([Int].self, forKey: .blocks) ?? []
    }
}

/// `GET /api/home/days?from=&to=` — every day in range, zero-filled.
struct HomeDaysResponse: Codable, Equatable {
    var days: [HomeDay] = []
}

extension HomeDaysResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([HomeDay].self, forKey: .days) ?? []
    }
}

/// `GET /api/home/engagement` (D3, D15).
struct HomeEngagementResponse: Codable, Equatable {
    var currentCount: Int = 0
    var enrolledCount: Int = 0
    var groupCount: Int = 0
    var percent: Int = 0
    var activeCount: Int = 0
}

extension HomeEngagementResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentCount = try c.decodeIfPresent(Int.self, forKey: .currentCount) ?? 0
        enrolledCount = try c.decodeIfPresent(Int.self, forKey: .enrolledCount) ?? 0
        groupCount = try c.decodeIfPresent(Int.self, forKey: .groupCount) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        activeCount = try c.decodeIfPresent(Int.self, forKey: .activeCount) ?? 0
    }
}

/// One followed enrollment's group card (D11). `enrollmentId` is unread today (no-op callbacks).
struct HomeFollowedGroup: Codable, Equatable {
    var enrollmentId: String = ""
    var groupName: String = ""
    var photoUrl: String?              // nil → C-038 initials
    var memberCount: Int = 0
    var percent: Int = 0
    var synced: Bool = false
}

extension HomeFollowedGroup {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enrollmentId = try c.decodeIfPresent(String.self, forKey: .enrollmentId) ?? ""
        groupName = try c.decodeIfPresent(String.self, forKey: .groupName) ?? ""
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        synced = try c.decodeIfPresent(Bool.self, forKey: .synced) ?? false
    }
}

/// One followed program (D11). `createdAt` stays an ISO 8601 STRING (SPEC F5).
struct HomeFollowedProgram: Codable, Equatable {
    var id: String = ""
    var title: String = ""
    var author: String = ""
    var createdAt: String = ""
    var groups: [HomeFollowedGroup] = []
}

extension HomeFollowedProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        groups = try c.decodeIfPresent([HomeFollowedGroup].self, forKey: .groups) ?? []
    }
}

/// `GET /api/home/following` — programs by title, groups by name (server-ordered, D11).
struct HomeFollowingResponse: Codable, Equatable {
    var programs: [HomeFollowedProgram] = []
}

extension HomeFollowingResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        programs = try c.decodeIfPresent([HomeFollowedProgram].self, forKey: .programs) ?? []
    }
}
