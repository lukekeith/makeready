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

    /// The independent home-dashboard-data sections, fetched concurrently. A nil is a failed (or
    /// cancelled) fetch whose cached section stays.
    private struct ExtraSections {
        var scheduled: AnalyticsQueryResponse?
        var days: HomeDaysResponse?
        var engagement: HomeEngagementResponse?
        var following: HomeFollowingResponse?
        var sessions: [String: HomeSessionsResponse] = [:]
    }

    @MainActor
    func refresh() async {
        let generation = state.initialLoad.generation
        do {
            let today = day(now())
            let from24 = day(offset: -23), fromHistory = day(offset: -Self.historyDays), ahead7 = day(offset: 7)

            // The extra sections start now and run alongside the core fetches below, so neither
            // waits on the other — Overview/Activity never wait on the heavy Sessions ranges.
            async let extras = fetchExtras(from: fromHistory, to: ahead7, dayRanges: dayRanges(fromOffset: -Self.historyDays, toOffset: 7))

            var next = state.dashboard
            next.kpiNames = try await kpiNames()

            let series = try await query(["lesson_completions"], dimension: "day", from: from24, to: today, compare: true)
            next.completedSeries = byDay(series.rows, metric: "lesson_completions")
            next.completedTotal = next.completedSeries.values.reduce(0, +)
            next.completedPrevious = series.previousRows?.compactMap { $0["lesson_completions"]?.int }.reduce(0, +)

            let activity = try await query(["lesson_completions"], dimension: "day", from: fromHistory, to: today, compare: false)
            next.activityDays = byDay(activity.rows, metric: "lesson_completions")

            if next.kpiNames.contains("watch_seconds") {
                let watch = try await nonFatal("watchSeconds", {
                    try await query(["watch_seconds"], dimension: nil, from: nil, to: nil, compare: false)
                })
                if let watch { next.watchSeconds = watch.rows.first?["watch_seconds"]?.int }
            }

            // First write: the core sections land as soon as they are fetched.
            next.refreshedAt = now()
            // A sign-out during the awaits re-armed the load: this is the old session's data.
            guard state.initialLoad.isCurrent(generation) else { return }
            state.dashboard = next
            state.persist()

            // Second write: the extra sections, merged onto what is now in state.
            let sections = try await extras
            guard state.initialLoad.isCurrent(generation) else { return }
            var merged = state.dashboard
            if let scheduled = sections.scheduled { merged.scheduledDays = byDay(scheduled.rows, metric: "scheduled_lessons") }   // D10
            if let days = sections.days {                                                                                        // D6
                merged.dayMinutes = Dictionary(days.days.map { ($0.day, Int((Double($0.sessionSeconds) / 60).rounded())) },
                                               uniquingKeysWith: { $1 })
                merged.dayBlocks = Dictionary(days.days.map { ($0.day, $0.blocks) }, uniquingKeysWith: { $1 })
            }
            if let engagement = sections.engagement { merged.engagement = engagement }                                          // D3
            if let following = sections.following { merged.following = following }                                              // D4, D11
            for (range, sessions) in sections.sessions { merged.sessions[range] = sessions }                                    // D8, D13
            state.dashboard = merged
            state.persist()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { await onUnauthorized(); return }
            if Self.isCancellation(error) { return }   // leaving Home mid-refresh is not an error
            state.recordError(error, context: "DashboardActions.refresh", surface: false)   // D28: logged, cache kept
        }
    }

    /// Owner ruling 2026-10-25: Activity (chart + day cards) carries ~6 months of history.
    static let historyDays = 182
    /// `/api/home/days` serves at most 62 days per call (frozen contract), so the history is
    /// fetched as consecutive ≤ 62-day ranges, in parallel.
    static let daysPerCall = 62

    private func dayRanges(fromOffset: Int, toOffset: Int) -> [(from: String, to: String)] {
        stride(from: fromOffset, through: toOffset, by: Self.daysPerCall).map { start in
            (day(offset: start), day(offset: min(start + Self.daysPerCall - 1, toOffset)))
        }
    }

    /// home-dashboard-data: every call is non-fatal (a failure keeps that cached section) and all of
    /// them run at once. A 401 from any of them rethrows, so the caller signs out.
    @MainActor
    private func fetchExtras(from: String, to: String, dayRanges: [(from: String, to: String)]) async throws -> ExtraSections {
        async let scheduled = nonFatal("scheduledLessons", {
            try await query(["scheduled_lessons"], dimension: "day", from: from, to: to, compare: false)
        })
        async let days = nonFatal("days", {
            try await withThrowingTaskGroup(of: [HomeDay].self) { group in
                for range in dayRanges {
                    group.addTask {
                        try await self.api.get(
                            self.homePath("/api/home/days", [("from", range.from), ("to", range.to)]),
                            responseType: HomeDaysResponse.self
                        ).days
                    }
                }
                var all: [HomeDay] = []
                for try await chunk in group { all += chunk }
                return HomeDaysResponse(days: all.sorted { $0.day < $1.day })
            }
        })
        async let engagement = nonFatal("engagement", {
            try await api.get(homePath("/api/home/engagement", []), responseType: HomeEngagementResponse.self)
        })
        async let following = nonFatal("following", {
            try await api.get(homePath("/api/home/following", [], timezone: false), responseType: HomeFollowingResponse.self)
        })
        async let sessions = fetchSessions()

        var sections = ExtraSections()
        // Await every child before throwing, so a 401 does not leave siblings running un-awaited.
        var failure: Error?
        do { sections.scheduled = try await scheduled } catch { failure = failure ?? error }
        do { sections.days = try await days } catch { failure = failure ?? error }
        do { sections.engagement = try await engagement } catch { failure = failure ?? error }
        do { sections.following = try await following } catch { failure = failure ?? error }
        do { sections.sessions = try await sessions } catch { failure = failure ?? error }
        if let failure { throw failure }
        return sections
    }

    /// D8/D13: all four ranges at once; a failed range is simply absent (its cache stays).
    @MainActor
    private func fetchSessions() async throws -> [String: HomeSessionsResponse] {
        try await withThrowingTaskGroup(of: (String, HomeSessionsResponse?).self) { group in
            for range in Self.sessionRangeKeys {
                group.addTask { @MainActor in
                    (range, try await nonFatal("sessions.\(range)", {
                        try await api.get(homePath("/api/home/sessions", [("range", range)]), responseType: HomeSessionsResponse.self)
                    }))
                }
            }
            var result: [String: HomeSessionsResponse] = [:]
            for try await (range, sessions) in group { if let sessions { result[range] = sessions } }
            return result
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
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
            if Self.isCancellation(error) { return nil }   // Home was left mid-refresh: not an error
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
