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

    /// SPEC D31 (owner 2026-10-25): Activity opens on today, at the right — the window is the
    /// 29 days ending today.
    func testActivityWindowEndsOnToday() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "All time")
        XCTAssertEqual(st.chartWindowEnd, "2026-10-25")
        XCTAssertEqual(st.chartWindowStart, "2026-09-27")
    }

    /// SPEC D31: "Jump to today" is live exactly when today's card has left the rail's view.
    func testTodayCardOnScreen() {
        // Card 30 spans 16 + 30×130 = 3916 … 4047.
        func on(_ minX: CGFloat) -> Bool {
            HomeDashboardScreen.cardOnScreen(index: 30, visible: CGRect(x: minX, y: 0, width: 440, height: 192),
                                             leadingInset: 16, width: 131, step: 130)
        }
        XCTAssertTrue(on(3700))     // fully in view
        XCTAssertTrue(on(4000))     // its last 47pt still in view
        XCTAssertFalse(on(4047))    // scrolled past it
        XCTAssertFalse(on(3476))    // still short of it (view ends at 3916)
        XCTAssertTrue(HomeDashboardScreen.cardOnScreen(index: nil, visible: nil, leadingInset: 16, width: 131, step: 130))
    }

    func testEmptySectionsStayEmpty() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "Week")
        XCTAssertEqual(st.followedCount, "0"); XCTAssertEqual(st.programTitles, [])
        XCTAssertEqual(st.engagementCount, 0); XCTAssertEqual(st.centerValue, "0")
        XCTAssertEqual(st.sessionRange, "Week")
    }
}
