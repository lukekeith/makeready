import Foundation

/// Home dashboard data cached in `AppState.dashboard` (SPEC D20, D25).
struct DashboardSnapshot: Codable, Equatable {
    var completedSeries: [String: Int] = [:]      // yyyy-MM-dd → lesson_completions, last 24 days
    var completedTotal: Int = 0
    var completedPrevious: Int?                   // compareToPrevious total
    var watchSeconds: Int?                        // snapshot, lifetime
    var activityDays: [String: Int] = [:]         // yyyy-MM-dd → completions, 28 back + today
    var kpiNames: [String] = ["lesson_completions", "watch_seconds"]
    var refreshedAt: Date?
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
