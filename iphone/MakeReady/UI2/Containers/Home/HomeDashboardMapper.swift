import Foundation

/// SPEC D8/D25 + home-dashboard-data D6–D16: every Home section from the snapshot; a section the
/// snapshot has never held keeps `.empty`'s values.
enum HomeDashboardMapper {
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
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

        // Sessions (D8/D13/D16): the container's selected range, re-mapped from the snapshot.
        // A range the snapshot has never held keeps `.empty`'s zeroed section.
        if let r = s.sessions[sessionKey(for: sessionRange)] {
            st.hourValues = fixed(r.hourly, count: 24)
            st.centerValue = "\(Int((Double(r.averageSeconds) / 60).rounded()))"
            st.centerUnit = "min"
            st.bins = fixed(r.bins, count: 88)
            st.sessionTickValues = r.ticks.map(tickLabel)
            st.sessionTickUnits = r.ticks.map { _ in "" }
        }

        // Engagement (D3/D7). Never fetched → `.empty`'s zeroed section.
        if let e = s.engagement {
            st.activeCount = "\(e.activeCount)"
            st.engagementPercent = e.percent
            st.engagementLabel = "Members current"
            st.engagementCount = e.currentCount
            st.engagementProgress = Double(e.percent) / 100
            st.engagementSubtitle = "\(e.enrolledCount) total members enrolled across \(e.groupCount) groups"
            st.engagementColor = bandColor(percent: e.percent)
        }

        // Following (D4/D11): program blocks in server order; group cards flattened, each pointing
        // back at its program by index.
        if let f = s.following {
            let cards: [(program: Int, group: HomeFollowedGroup)] = f.programs.enumerated().flatMap { index, program in
                program.groups.map { (program: index, group: $0) }
            }
            st.followedCount = "\(cards.count)"
            st.programTitles = f.programs.map { $0.title }
            st.programAuthors = f.programs.map { $0.author }
            st.programCreatedLabels = f.programs.map { createdLabel($0.createdAt, tz: timeZone) }
            st.groupProgramIndices = cards.map { $0.program }
            st.groupTitles = cards.map { $0.group.groupName }
            st.groupPhotoURLs = cards.map { $0.group.photoUrl ?? "" }
            st.groupMembers = cards.map { "\($0.group.memberCount)" }          // the card adds "members"
            st.groupPercents = cards.map { "\($0.group.percent)%" }
            st.groupColors = cards.map { bandColor(percent: $0.group.percent) }
            st.groupShowLinks = cards.map { $0.group.synced }
        }
        return st
    }

    // MARK: - Helpers

    /// D7: C-031 / C-033 colour bands — green ≥ 50, yellow 20–49, red < 20.
    static func bandColor(percent: Int) -> String {
        if percent >= 50 { return "green" }
        if percent >= 20 { return "yellow" }
        return "red"
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// D11: "Created MMM d, yyyy" in the caller's tz from the server's ISO 8601 string (Prisma
    /// writes fractional seconds); "" when it doesn't parse.
    static func createdLabel(_ iso: String, tz: TimeZone) -> String {
        guard let date = isoFractional.date(from: iso) ?? isoPlain.date(from: iso) else { return "" }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return "Created \(shortMonths[m - 1]) \(d), \(y)"
    }

    /// D13: the C-028 label → the snapshot's `sessions` key (`DashboardActions.sessionRangeKeys`).
    static func sessionKey(for label: String) -> String {
        switch label {
        case "Year": return "year"
        case "Month": return "month"
        case "Week": return "week"
        default: return "all"
        }
    }

    /// Pads with zeros or truncates to the length the component's prop contract states.
    static func fixed(_ values: [Double], count: Int) -> [Double] {
        let head = Array(values.prefix(count))
        return head + Array(repeating: 0, count: count - head.count)
    }

    /// D16: a server tick (yyyy-MM-dd, a calendar date — no tz shift) as "MMM d".
    static func tickLabel(_ day: String) -> String {
        let parts = day.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let date = Int(parts[2]), (1...12).contains(month)
        else { return day }
        return "\(shortMonths[month - 1]) \(date)"
    }

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
