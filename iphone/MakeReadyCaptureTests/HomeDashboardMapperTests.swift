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

    // MARK: - Task 8: DashboardSnapshot decoding (SPEC F11)

    private func cacheDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601        // PersistedState's decoder
        return decoder
    }

    /// A snapshot cached by the build before this feature keeps every old field and
    /// defaults every new one — it is never a cache miss.
    func testOldSnapshotWithoutTheNewKeysKeepsItsFields() throws {
        let json = #"{"completedSeries":{"2026-10-24":3},"completedTotal":3,"completedPrevious":2,"watchSeconds":120,"activityDays":{"2026-10-24":3},"kpiNames":["lesson_completions"],"refreshedAt":"2026-10-25T18:00:00Z"}"#
        let s = try cacheDecoder().decode(DashboardSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(s.completedSeries, ["2026-10-24": 3])
        XCTAssertEqual(s.completedTotal, 3)
        XCTAssertEqual(s.completedPrevious, 2)
        XCTAssertEqual(s.watchSeconds, 120)
        XCTAssertEqual(s.activityDays, ["2026-10-24": 3])
        XCTAssertEqual(s.kpiNames, ["lesson_completions"])
        XCTAssertNotNil(s.refreshedAt)
        XCTAssertEqual(s.scheduledDays, [:])
        XCTAssertEqual(s.dayMinutes, [:])
        XCTAssertEqual(s.dayBlocks, [:])
        XCTAssertEqual(s.sessions, [:])
        XCTAssertNil(s.engagement)
        XCTAssertNil(s.following)
    }

    func testNewFieldsRoundTrip() throws {
        var s = DashboardSnapshot()
        s.scheduledDays = ["2026-10-24": 5]
        s.dayMinutes = ["2026-10-24": 26]
        s.dayBlocks = ["2026-10-24": [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0]]
        s.sessions = ["week": HomeSessionsResponse(averageSeconds: 600, sessionCount: 2, hourly: [1, 2],
                                                   bins: [0.5, 1], ticks: ["2026-10-19"])]
        s.engagement = HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9)
        s.following = HomeFollowingResponse(programs: [
            HomeFollowedProgram(id: "p1", title: "Romans in 30 days", author: "", createdAt: "2026-07-08T18:00:00.000Z",
                                groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "The kids", photoUrl: nil,
                                                           memberCount: 2, percent: 13, synced: false)])
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try cacheDecoder().decode(DashboardSnapshot.self, from: try encoder.encode(s))
        XCTAssertEqual(decoded, s)
    }

    /// Every nested type is tolerant too: a missing key inside a cached section defaults
    /// instead of throwing (which would drop the whole dashboard).
    func testNestedTypesDefaultTheirMissingKeys() throws {
        let json = #"{"sessions":{"week":{"averageSeconds":600}},"engagement":{"percent":40},"following":{"programs":[{"title":"Romans","createdAt":"2026-07-08T18:00:00.123Z","groups":[{"groupName":"Kids","photoUrl":null}]}]}}"#
        let s = try cacheDecoder().decode(DashboardSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(s.sessions["week"]?.averageSeconds, 600)
        XCTAssertEqual(s.sessions["week"]?.hourly, [])
        XCTAssertEqual(s.sessions["week"]?.ticks, [])
        XCTAssertEqual(s.engagement?.percent, 40)
        XCTAssertEqual(s.engagement?.currentCount, 0)
        let program = try XCTUnwrap(s.following?.programs.first)
        XCTAssertEqual(program.id, "")
        XCTAssertEqual(program.author, "")
        XCTAssertEqual(program.createdAt, "2026-07-08T18:00:00.123Z")
        XCTAssertEqual(program.groups.first?.groupName, "Kids")
        XCTAssertNil(program.groups.first?.photoUrl)
        XCTAssertEqual(program.groups.first?.memberCount, 0)
        XCTAssertEqual(program.groups.first?.synced, false)
        XCTAssertEqual(s.completedTotal, 0)
    }

    /// The wire shapes of SPEC §Contract decode through the app's API decoder.
    func testHomeResponsesDecodeFromTheContractShapes() throws {
        let following = #"{"programs":[{"id":"p1","title":"Daily inspiration","author":"Scott Stickane","createdAt":"2026-04-13T15:02:11.123Z","groups":[{"enrollmentId":"e1","groupName":"Young professionals","photoUrl":"https://cdn.example/g.jpg","memberCount":9,"percent":55,"synced":true}]}]}"#
        let f = try JSONDecoder.apiDecoder.decode(HomeFollowingResponse.self, from: Data(following.utf8))
        XCTAssertEqual(f.programs.first?.createdAt, "2026-04-13T15:02:11.123Z")
        XCTAssertEqual(f.programs.first?.groups.first?.photoUrl, "https://cdn.example/g.jpg")
        XCTAssertEqual(f.programs.first?.groups.first?.synced, true)

        let days = #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]}]}"#
        let d = try JSONDecoder.apiDecoder.decode(HomeDaysResponse.self, from: Data(days.utf8))
        XCTAssertEqual(d.days, [HomeDay(day: "2026-10-24", sessionSeconds: 1530, blocks: [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0])])

        let engagement = #"{"currentCount":52,"enrolledCount":178,"groupCount":15,"percent":29,"activeCount":15}"#
        let e = try JSONDecoder.apiDecoder.decode(HomeEngagementResponse.self, from: Data(engagement.utf8))
        XCTAssertEqual(e, HomeEngagementResponse(currentCount: 52, enrolledCount: 178, groupCount: 15, percent: 29, activeCount: 15))

        let sessions = #"{"averageSeconds":1920,"sessionCount":40,"hourly":[0,0,0,0,0,0,0,0,0,600.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"bins":[0,0.25,1],"ticks":["2025-10-26","2026-02-23","2026-06-24","2026-10-25"]}"#
        let r = try JSONDecoder.apiDecoder.decode(HomeSessionsResponse.self, from: Data(sessions.utf8))
        XCTAssertEqual(r.averageSeconds, 1920)
        XCTAssertEqual(r.hourly.count, 24)
        XCTAssertEqual(r.hourly[9], 600.5)
        XCTAssertEqual(r.bins, [0, 0.25, 1])
        XCTAssertEqual(r.ticks.count, 4)
    }

    // MARK: - Task 10: Activity + day cards (D6, D10)

    private func map(_ s: DashboardSnapshot, range: String = "All time") -> HomeDashboardScreen.State {
        HomeDashboardMapper.state(from: s, today: today, timeZone: tz, sessionRange: range)
    }

    func testScheduledColumnsComeFromTheSnapshot() {
        var s = snapshot()
        s.scheduledDays = ["2026-10-24": 5, "2026-11-01": 4]
        let st = map(s)
        XCTAssertEqual(st.chartScheduled.count, 36)
        XCTAssertEqual(st.chartScheduled[st.chartDates.firstIndex(of: "2026-10-24")!], 5)
        XCTAssertEqual(st.chartScheduled[st.chartDates.firstIndex(of: "2026-11-01")!], 4)   // today + 7
        XCTAssertEqual(st.chartScheduled.reduce(0, +), 9)
    }

    func testDayCardMinutesBarsAndCompletions() {
        var s = snapshot()
        s.dayMinutes = ["2026-10-24": 26]
        s.dayBlocks = ["2026-10-24": [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0]]
        let st = map(s)
        let i = st.dayDates.firstIndex(of: "2026-10-24")!
        XCTAssertEqual(st.dayLine1s[i], "26 mins")
        XCTAssertEqual(st.dayLine2s[i], "3 complete")
        XCTAssertEqual(st.daySeries[i], [0, 0, 0, 0, 10, 0, 15.5, 0, 0, 0, 0, 0])
        XCTAssertEqual(st.dayDetailsStates[i], "default")
    }

    func testEmptyDayIsNothing() {
        let st = map(snapshot())
        let i = st.dayDates.firstIndex(of: "2026-10-20")!
        XCTAssertEqual(st.dayLine1s[i], "0 mins")
        XCTAssertEqual(st.dayLine2s[i], "0 complete")
        XCTAssertEqual(st.daySeries[i], Array(repeating: 0, count: 12))
        XCTAssertEqual(st.dayDetailsStates[i], "nothing")
    }

    func testSessionOnlyDayIsDefault() {
        var s = snapshot()
        s.dayMinutes = ["2026-10-22": 1]
        s.dayBlocks = ["2026-10-22": [60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]
        let st = map(s)
        let i = st.dayDates.firstIndex(of: "2026-10-22")!
        XCTAssertEqual(st.dayLine2s[i], "0 complete")
        XCTAssertEqual(st.dayDetailsStates[i], "default")
    }

    func testBlockMinutesIsAlwaysTwelve() {
        XCTAssertEqual(HomeDashboardMapper.blockMinutes([120]), [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(HomeDashboardMapper.blockMinutes(nil), Array(repeating: 0, count: 12))
        XCTAssertEqual(HomeDashboardMapper.blockMinutes(Array(repeating: 60, count: 14)).count, 12)
    }

    // MARK: - Task 11: Sessions by range (D8, D13, D16)

    private func sessions(_ average: Int, peakHour: Int) -> HomeSessionsResponse {
        var hourly = Array(repeating: 0.0, count: 24)
        hourly[peakHour] = Double(average)
        var bins = Array(repeating: 0.0, count: 88)
        bins[87] = 1
        return HomeSessionsResponse(averageSeconds: average, sessionCount: 3, hourly: hourly, bins: bins,
                                    ticks: ["2025-10-26", "2026-02-23", "2026-06-24", "2026-10-25"])
    }

    private func sessionsSnapshot() -> DashboardSnapshot {
        var s = snapshot()
        s.sessions = ["all": sessions(1920, peakHour: 9), "year": sessions(1500, peakHour: 12),
                      "month": sessions(900, peakHour: 18), "week": sessions(630, peakHour: 20)]
        return s
    }

    func testSessionsFieldsForTheDefaultRange() {
        let st = map(sessionsSnapshot(), range: "All time")
        XCTAssertEqual(st.hourValues.count, 24)
        XCTAssertEqual(st.hourValues[9], 1920)
        XCTAssertEqual(st.centerValue, "32")                                      // 1920 s = 32 min
        XCTAssertEqual(st.centerUnit, "min")
        XCTAssertEqual(st.centerCaption, "Average session")                       // unchanged (D8)
        XCTAssertEqual(st.bins.count, 88)
        XCTAssertEqual(st.bins[87], 1)
        XCTAssertEqual(st.sessionTickValues, ["Oct 26", "Feb 23", "Jun 24", "Oct 25"])   // D16 "MMM d"
        XCTAssertEqual(st.sessionTickUnits, ["", "", "", ""])
    }

    /// D13: one snapshot holds all four ranges; changing the label is a pure re-map.
    func testFourRangesMapFromOneSnapshot() {
        let s = sessionsSnapshot()
        let expected: [(label: String, center: String, peak: Int)] = [
            ("All time", "32", 9), ("Year", "25", 12), ("Month", "15", 18), ("Week", "11", 20)   // 630 s = 10.5 → 11
        ]
        for row in expected {
            let st = map(s, range: row.label)
            XCTAssertEqual(st.sessionRange, row.label)
            XCTAssertEqual(st.centerValue, row.center, row.label)
            XCTAssertEqual(st.hourValues.firstIndex(where: { $0 > 0 }), row.peak, row.label)
        }
    }

    func testRangeNotYetFetchedKeepsTheEmptySection() {
        var s = snapshot()
        s.sessions = ["all": sessions(1920, peakHour: 9)]
        let st = map(s, range: "Week")
        XCTAssertEqual(st.centerValue, "0")
        XCTAssertEqual(st.hourValues, Array(repeating: 0, count: 24))
        XCTAssertEqual(st.sessionTickValues, HomeDashboardScreen.State.empty.sessionTickValues)
    }

    func testShortSessionArraysAreFixedLength() {
        var s = snapshot()
        s.sessions = ["all": HomeSessionsResponse(averageSeconds: 60, sessionCount: 1, hourly: [1, 2], bins: [0.5], ticks: [])]
        let st = map(s)
        XCTAssertEqual(st.hourValues.count, 24)
        XCTAssertEqual(Array(st.hourValues.prefix(2)), [1, 2])
        XCTAssertEqual(st.bins.count, 88)
        XCTAssertEqual(st.bins[0], 0.5)
        XCTAssertEqual(st.sessionTickValues, [])
        XCTAssertEqual(st.sessionTickUnits, [])
    }

    func testTickLabelFormatsAStoredDate() {
        XCTAssertEqual(HomeDashboardMapper.tickLabel("2026-01-05"), "Jan 5")
        XCTAssertEqual(HomeDashboardMapper.tickLabel("2026-12-31"), "Dec 31")
        XCTAssertEqual(HomeDashboardMapper.tickLabel("garbage"), "garbage")
    }
}
