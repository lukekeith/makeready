import Foundation

/// SPEC D8/D25: Overview + Activity from the snapshot; Sessions, Engagement,
/// Following keep `.empty`'s values.
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
        st.chartScheduled = Array(repeating: 0, count: keys.count)
        st.chartToday = todayKey
        st.chartWindowStart = keys[max(0, todayIndex - 14)]
        st.chartWindowEnd = keys[min(keys.count - 1, todayIndex + 14)]
        st.dayDates = keys
        st.dayMonths = window.map { months[$0.month - 1] }
        st.dayWeekdays = window.map { $0.key == todayKey ? "" : weekdays[$0.weekday - 1] }
        st.dayNumbers = window.map { "\($0.day)" }
        st.dayDateStates = keys.map { $0 == todayKey ? "today" : "default" }
        st.daySeries = keys.map { _ in Array(repeating: 0, count: 12) }
        st.dayLine1s = keys.map { _ in "0 mins" }
        st.dayLine2s = keys.map { "\(s.activityDays[$0] ?? 0) lessons" }
        st.dayDetailsStates = keys.map { (s.activityDays[$0] ?? 0) > 0 ? "default" : "nothing" }
        return st
    }

    // MARK: - Helpers

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
