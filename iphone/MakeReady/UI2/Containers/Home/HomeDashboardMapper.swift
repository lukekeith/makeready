import Foundation

/// SPEC D8/D25 + home-dashboard-data D6–D16: every Home section from the snapshot; a section the
/// snapshot has never held keeps `.empty`'s values.
enum HomeDashboardMapper {
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private static let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    static func state(from s: DashboardSnapshot, today: Date, timeZone: TimeZone, sessionRange: String) -> HomeDashboardScreen.State {
        var st = HomeDashboardScreen.State.empty
        st.sessionRange = sessionRange

        // Overview (D21/D25)
        let last24 = days(endingAt: today, back: 23, ahead: 0, tz: timeZone)
        let completedSeries = last24.map { Double(s.completedSeries[$0.key] ?? 0) }
        let completedTrend = trend(current: s.completedTotal, previous: s.completedPrevious)
        var titles = ["Completed lessons"], values = ["\(s.completedTotal)"]
        var series = [completedSeries], averages = [average(completedSeries)]
        var dirs = [completedTrend.direction], pols = [completedTrend.polarity], labels = [completedTrend.label]
        if s.kpiNames.contains("watch_seconds") {
            titles.append("Total video time"); values.append(hours(s.watchSeconds ?? 0))
            series.append([]); averages.append("")
            dirs.append("neutral"); pols.append("neutral"); labels.append("")
        }
        st.kpiTitles = titles; st.kpiValues = values; st.kpiSeries = series; st.kpiAverageLabels = averages
        st.kpiTrendDirections = dirs; st.kpiTrendPolarities = pols; st.kpiTrendLabels = labels
        st.metricCount = "\(titles.count)"

        // Activity (D22/D25)
        let window = days(endingAt: today, back: 28, ahead: 7, tz: timeZone)
        let keys = window.map(\.key)
        let todayKey = key(today, tz: timeZone)
        let todayIndex = keys.firstIndex(of: todayKey) ?? 28
        st.chartDates = keys
        st.chartCompleted = keys.map { s.activityDays[$0] ?? 0 }
        st.chartScheduled = keys.map { s.scheduledDays[$0] ?? 0 }                    // D10
        st.chartToday = todayKey
        // SPEC D31 (owner 2026-10-25): the window opens on the 29 days ending today, so today is
        // the last column and the rail's three cards end on it.
        st.chartWindowStart = keys[max(0, todayIndex - 28)]
        st.chartWindowEnd = todayKey
        st.dayDates = keys
        st.dayMonths = window.map { months[$0.month - 1] }
        st.dayWeekdays = window.map { $0.key == todayKey ? "" : weekdays[$0.weekday - 1] }
        st.dayNumbers = window.map { "\($0.day)" }
        st.dayDateStates = keys.map { $0 == todayKey ? "today" : "default" }
        // D6: minutes and bars are session time; line 2 is lesson completions.
        st.daySeries = keys.map { blockMinutes(s.dayBlocks[$0]) }
        st.dayLine1s = keys.map { "\(s.dayMinutes[$0] ?? 0) mins" }
        st.dayLine2s = keys.map { "\(s.activityDays[$0] ?? 0) complete" }
        st.dayDetailsStates = keys.map { key in
            let sessionSeconds = s.dayBlocks[key]?.reduce(0, +) ?? 0
            let hasActivity = sessionSeconds > 0 || (s.dayMinutes[key] ?? 0) > 0 || (s.activityDays[key] ?? 0) > 0
            return hasActivity ? "default" : "nothing"
        }
        return st
    }

    // MARK: - Helpers

    /// D6: the 12 two-hour blocks (server seconds) as minutes — always 12 long, zero-filled.
    static func blockMinutes(_ seconds: [Int]?) -> [Double] {
        let values = (seconds ?? []).prefix(12).map { Double($0) / 60 }
        return values + Array(repeating: 0, count: 12 - values.count)
    }

    struct Trend { let direction: String; let polarity: String; let label: String }
    struct Day { let key: String; let month: Int; let day: Int; let weekday: Int }

    static func trend(current: Int, previous: Int?) -> Trend {
        guard let previous, previous > 0 else { return Trend(direction: "neutral", polarity: "neutral", label: "") }
        let pct = Int((Double(current - previous) / Double(previous) * 100).rounded())
        if pct > 0 { return Trend(direction: "up", polarity: "positive", label: "\(pct)%") }
        if pct < 0 { return Trend(direction: "down", polarity: "negative", label: "\(-pct)%") }
        return Trend(direction: "neutral", polarity: "neutral", label: "0%")
    }

    static func hours(_ seconds: Int) -> String { String(format: "%.1fhrs", Double(seconds) / 3600) }

    static func average(_ v: [Double]) -> String {
        guard !v.isEmpty, v.contains(where: { $0 > 0 }) else { return "" }
        return "\(Int((v.reduce(0, +) / Double(v.count)).rounded()))"
    }

    static func days(endingAt today: Date, back: Int, ahead: Int, tz: TimeZone) -> [Day] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return (-back...ahead).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
            guard let y = c.year, let m = c.month, let d = c.day, let w = c.weekday else { return nil }
            return Day(key: String(format: "%04d-%02d-%02d", y, m, d), month: m, day: d, weekday: w)
        }
    }

    static func key(_ date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
