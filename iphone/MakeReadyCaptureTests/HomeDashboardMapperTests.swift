import XCTest
@testable import MakeReady

final class HomeDashboardMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    private func snapshot() -> DashboardSnapshot {
        var s = DashboardSnapshot()
        s.completedSeries = ["2026-10-24": 3, "2026-10-25": 2]
        s.completedTotal = 5; s.completedPrevious = 4
        s.watchSeconds = 49_680
        s.activityDays = ["2026-10-24": 3, "2026-10-25": 2]
        return s
    }

    func testTwoKpisInOrder() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "All time")
        XCTAssertEqual(st.kpiTitles, ["Completed lessons", "Total video time"])     // D25
        XCTAssertEqual(st.metricCount, "2")
        XCTAssertEqual(st.kpiValues, ["5", "13.8hrs"])
        XCTAssertEqual(st.kpiSeries[0].count, 24)
        XCTAssertEqual(st.kpiSeries[1], [])
        XCTAssertEqual(st.kpiTrendDirections, ["up", "neutral"])
        XCTAssertEqual(st.kpiTrendLabels[0], "25%")
        XCTAssertEqual(st.kpiTrendLabels[1], "")
    }

    func testActivityWindowAndZeros() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "All time")
        XCTAssertEqual(st.chartDates.count, 36)                                       // 28 + today + 7
        XCTAssertEqual(st.chartToday, "2026-10-25")
        XCTAssertEqual(st.chartScheduled, Array(repeating: 0, count: 36))             // D25
        XCTAssertEqual(st.chartCompleted[st.chartDates.firstIndex(of: "2026-10-24")!], 3)
        XCTAssertTrue(st.dayLine1s.allSatisfy { $0 == "0 mins" })
    }

    func testEmptySectionsStayEmpty() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "Week")
        XCTAssertEqual(st.followedCount, "0"); XCTAssertEqual(st.programTitles, [])
        XCTAssertEqual(st.engagementCount, 0); XCTAssertEqual(st.centerValue, "0")
        XCTAssertEqual(st.sessionRange, "Week")
    }
}
