import Foundation

/// SPEC D8, D20–D22, D24–D27: Home's Overview + Activity data; home-dashboard-data adds Activity's scheduled side, day minutes, Sessions, Engagement and Following.
struct DashboardActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let now: () -> Date
    private let timeZone: TimeZone
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// home-dashboard-data D8/D13: every Sessions range is fetched, so switching is a pure re-map.
    static let sessionRangeKeys = ["all", "year", "month", "week"]

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.now = now
        self.timeZone = timeZone
        self.onUnauthorized = onUnauthorized
    }

    @MainActor
    func refresh() async {
        let generation = state.initialLoad.generation
        do {
            var next = state.dashboard
            next.kpiNames = try await kpiNames()
            let today = day(now())
            let from24 = day(offset: -23), from28 = day(offset: -28), ahead7 = day(offset: 7)

            let series = try await query(["lesson_completions"], dimension: "day", from: from24, to: today, compare: true)
            next.completedSeries = byDay(series.rows, metric: "lesson_completions")
            next.completedTotal = next.completedSeries.values.reduce(0, +)
            next.completedPrevious = series.previousRows?.compactMap { $0["lesson_completions"]?.int }.reduce(0, +)

            let activity = try await query(["lesson_completions"], dimension: "day", from: from28, to: today, compare: false)
            next.activityDays = byDay(activity.rows, metric: "lesson_completions")

            if next.kpiNames.contains("watch_seconds") {
                do {
                    let watch = try await query(["watch_seconds"], dimension: nil, from: nil, to: nil, compare: false)
                    next.watchSeconds = watch.rows.first?["watch_seconds"]?.int
                } catch {
                    // A 401 still signs out; any other failure leaves watchSeconds as cached.
                    if AuthStatusPolicy.shouldSignOut(after: error) { throw error }
                    state.recordError(error, context: "DashboardActions.refresh.watchSeconds", surface: false)
                }
            }

            // home-dashboard-data: each call below is non-fatal — a failure keeps that cached section.
            let scheduled = try await nonFatal("scheduledLessons", {
                try await query(["scheduled_lessons"], dimension: "day", from: from28, to: ahead7, compare: false)
            })
            if let scheduled { next.scheduledDays = byDay(scheduled.rows, metric: "scheduled_lessons") }   // D10

            let days = try await nonFatal("days", {
                try await api.get(homePath("/api/home/days", [("from", from28), ("to", ahead7)]),
                                  responseType: HomeDaysResponse.self)
            })
            if let days {                                                                              // D6
                next.dayMinutes = Dictionary(days.days.map { ($0.day, Int((Double($0.sessionSeconds) / 60).rounded())) },
                                             uniquingKeysWith: { $1 })
                next.dayBlocks = Dictionary(days.days.map { ($0.day, $0.blocks) }, uniquingKeysWith: { $1 })
            }

            let engagement = try await nonFatal("engagement", {
                try await api.get(homePath("/api/home/engagement", []), responseType: HomeEngagementResponse.self)
            })
            if let engagement { next.engagement = engagement }                                         // D3

            let following = try await nonFatal("following", {
                try await api.get(homePath("/api/home/following", [], timezone: false), responseType: HomeFollowingResponse.self)
            })
            if let following { next.following = following }                                           // D4, D11

            for range in Self.sessionRangeKeys {                                                      // D8, D13
                let sessions = try await nonFatal("sessions.\(range)", {
                    try await api.get(homePath("/api/home/sessions", [("range", range)]), responseType: HomeSessionsResponse.self)
                })
                if let sessions { next.sessions[range] = sessions }
            }

            next.refreshedAt = now()
            // A sign-out during the awaits re-armed the load: this is the old session's data.
            guard state.initialLoad.isCurrent(generation) else { return }
            state.dashboard = next
            state.persist()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { await onUnauthorized(); return }
            state.recordError(error, context: "DashboardActions.refresh", surface: false)   // D28: logged, cache kept
        }
    }

    // MARK: - Helpers

    @MainActor
    private func kpiNames() async throws -> [String] {
        let defaults = ["lesson_completions", "watch_seconds"]   // D25 default
        let pref = try await api.get("/api/preferences/dashboard.kpis", responseType: DashboardPreferenceResponse.self)
        guard pref.isDefault != true,
              let data = pref.value.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else { return defaults }
        let known = names.filter { defaults.contains($0) }
        return known.isEmpty ? defaults : known
    }

    /// A background section fetch: a 401 rethrows (the outer catch signs out, D27); anything else
    /// is recorded console-only (a background refresh never surfaces) and returns nil so the
    /// caller keeps the cached section.
    @MainActor
    private func nonFatal<T>(_ context: String, _ work: () async throws -> T) async throws -> T? {
        do {
            return try await work()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { throw error }
            state.recordError(error, context: "DashboardActions.refresh.\(context)", surface: false)
            return nil
        }
    }

    /// `/api/home/*` path with its query: the given params, then `tz` (unless `timezone: false`),
    /// then `organizationId` when known (D9: it can only narrow the scope).
    @MainActor
    private func homePath(_ path: String, _ params: [(String, String)], timezone: Bool = true) -> String {
        var items = params
        if timezone { items.append(("tz", timeZone.identifier)) }
        if let org = state.organizationId { items.append(("organizationId", org)) }
        guard !items.isEmpty else { return path }
        return path + "?" + items.map { "\($0.0)=\(Self.queryValue($0.1))" }.joined(separator: "&")
    }

    /// `APIClient.get` takes the raw path (APIClient.swift:218), so each value is encoded here.
    /// `urlQueryAllowed` keeps `+`, which a server reads as a space (`Etc/GMT+5`), so it is removed
    /// along with the separators `&`, `=` and `#`.
    static func queryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    @MainActor
    private func query(_ metrics: [String], dimension: String?, from: String?, to: String?, compare: Bool) async throws -> AnalyticsQueryResponse {
        var filters: [String: Any] = [:]
        if let org = state.organizationId { filters["organizationId"] = org }   // D26
        if let from { filters["from"] = from }
        if let to { filters["to"] = to }
        var body: [String: Any] = ["metrics": metrics, "timezone": timeZone.identifier, "filters": filters]
        if let dimension { body["dimensions"] = [dimension] }
        if compare { body["compareToPrevious"] = true }
        return try await api.post("/api/analytics/query", body: body, responseType: AnalyticsQueryResponse.self)
    }

    private func byDay(_ rows: [[String: AnalyticsValue]], metric: String) -> [String: Int] {
        Dictionary(rows.compactMap { row in row["day"]?.string.flatMap { key in row[metric]?.int.map { (key, $0) } } },
                   uniquingKeysWith: { $1 })
    }

    private func day(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let parts = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    private func day(offset: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return day(cal.date(byAdding: .day, value: offset, to: now()) ?? now())
    }
}
