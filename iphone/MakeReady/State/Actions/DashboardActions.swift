import Foundation

/// SPEC D8, D20–D22, D24–D27: Home's Overview + Activity data.
struct DashboardActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let now: () -> Date
    private let timeZone: TimeZone
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

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
        do {
            var next = state.dashboard
            next.kpiNames = try await kpiNames()
            let today = day(now())
            let from24 = day(offset: -23), from28 = day(offset: -28)

            let series = try await query(["lesson_completions"], dimension: "day", from: from24, to: today, compare: true)
            next.completedSeries = byDay(series.rows, metric: "lesson_completions")
            next.completedTotal = next.completedSeries.values.reduce(0, +)
            next.completedPrevious = series.previousRows?.compactMap { $0["lesson_completions"]?.int }.reduce(0, +)

            let activity = try await query(["lesson_completions"], dimension: "day", from: from28, to: today, compare: false)
            next.activityDays = byDay(activity.rows, metric: "lesson_completions")

            if next.kpiNames.contains("watch_seconds") {
                let watch = try await query(["watch_seconds"], dimension: nil, from: nil, to: nil, compare: false)
                next.watchSeconds = watch.rows.first?["watch_seconds"]?.int
            }
            next.refreshedAt = now()
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
