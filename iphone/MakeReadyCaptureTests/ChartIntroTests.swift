import XCTest
import SwiftUI
@testable import MakeReady

/// dashboard-chart-intros: the shared intro vocabulary (SPEC D3, D7, D10, D13, D14, D16).
final class ChartIntroTests: XCTestCase {

    // MARK: - D14 count-up

    func testCountUpParsesTheLeadingNumberAndKeepsItsAffixes() {
        let percent = CountUpFormat.parse("84%")
        XCTAssertEqual(percent?.number, 84)
        XCTAssertEqual(percent?.suffix, "%")
        XCTAssertEqual(percent?.decimals, 0)
        let grouped = CountUpFormat.parse("1,204")
        XCTAssertEqual(grouped?.number, 1204)
        XCTAssertEqual(grouped?.grouped, true)
        XCTAssertEqual(CountUpFormat.parse("32")?.number, 32)
        let decimal = CountUpFormat.parse("4.5")
        XCTAssertEqual(decimal?.number, 4.5)
        XCTAssertEqual(decimal?.decimals, 1)
        XCTAssertEqual(CountUpFormat.parse("12 min")?.suffix, " min")
        XCTAssertNil(CountUpFormat.parse("—"))
        XCTAssertNil(CountUpFormat.parse(""))
    }

    func testCountUpRendersTheSourceAtItsValueAndFormatsOnTheWay() {
        let grouped = CountUpFormat.parse("1,204")!
        XCTAssertEqual(grouped.render(1204), "1,204")
        XCTAssertEqual(grouped.render(602), "602")
        XCTAssertEqual(grouped.render(1100), "1,100")
        XCTAssertEqual(CountUpFormat.parse("84%")!.render(0), "0%")
        XCTAssertEqual(CountUpFormat.parse("4.5")!.render(2), "2.0")
        XCTAssertEqual(CountUpFormat.parse("12 min")!.render(6), "6 min")
    }

    func testCountUpShownValueFollowsTheIntro() {
        let format = CountUpFormat.parse("84%")
        XCTAssertEqual(CountUpText.shown(format, intro: nil), 84)
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: false)), 0)
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: true)), 84)
        // D10: no count-up under Reduce Motion — the value is final from the first frame.
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: false, reduceMotion: true)), 84)
        XCTAssertEqual(CountUpText.shown(nil, intro: ChartIntro(played: false)), 0)
    }

    // MARK: - D3 stagger

    func testStaggerIsFifteenMillisecondsAndAWaveFitsTheBudget() {
        XCTAssertEqual(ChartIntroMotion.stagger(0, of: 24), 0)
        XCTAssertEqual(ChartIntroMotion.stagger(1, of: 24), 0.015, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(23, of: 24), 0.345, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(87, of: 88), ChartIntroMotion.waveBudget, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(200, of: 88), ChartIntroMotion.waveBudget, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(3, of: 1), 0)
        XCTAssertEqual(ChartIntroMotion.sweepDelay(hour: 0), 0)
        XCTAssertEqual(ChartIntroMotion.sweepDelay(hour: 12), 0.3, accuracy: 1e-9)
    }

    // MARK: - D7 / D10 / D16 poses

    func testIntroPoses() {
        XCTAssertEqual(ChartIntro(played: false).progress(fadeOnly: false), 0)
        XCTAssertEqual(ChartIntro(played: true).progress(fadeOnly: false), 1)
        XCTAssertEqual(ChartIntro(played: false).opacity(fadeOnly: false), 1)
        // D16: an empty chart crossfades only — final geometry, opacity 0 → 1.
        XCTAssertEqual(ChartIntro(played: false).progress(fadeOnly: true), 1)
        XCTAssertEqual(ChartIntro(played: false).opacity(fadeOnly: true), 0)
        XCTAssertEqual(ChartIntro(played: true).opacity(fadeOnly: true), 1)
        // D10: Reduce Motion is the same crossfade, and nothing animates geometry.
        XCTAssertEqual(ChartIntro(played: false, reduceMotion: true).progress(fadeOnly: false), 1)
        XCTAssertEqual(ChartIntro(played: false, reduceMotion: true).opacity(fadeOnly: false), 0)
        XCTAssertNil(ChartIntro(played: true, reduceMotion: true).animation(ChartIntroMotion.rise))
        XCTAssertNil(ChartIntro(played: true, reduceMotion: true).morph)
        XCTAssertNotNil(ChartIntro(played: true).morph)
        XCTAssertEqual(ChartIntro(played: true, delay: 0.1).delayed(by: 0.2).delay, 0.3, accuracy: 1e-9)
    }

    func testScaledLengthIsTheStillLengthAtFullProgress() {
        XCTAssertEqual(ChartIntro.scaled(98, by: 0), 0)
        XCTAssertEqual(ChartIntro.scaled(98, by: 0.5), 49)
        XCTAssertEqual(ChartIntro.scaled(98, by: 1), 98)
    }

    // MARK: - D5 / D6 / D15 the played ledger

    func testASectionPlaysOnceAndNotAgainOnScrollBack() {
        var ledger = ChartIntroLedger()
        XCTAssertFalse(ledger.hasPlayed(.sessions))
        ledger.setVisible(.sessions, true)
        XCTAssertTrue(ledger.hasPlayed(.sessions))
        ledger.setVisible(.sessions, false)
        ledger.setVisible(.sessions, true)
        XCTAssertTrue(ledger.hasPlayed(.sessions))
        XCTAssertFalse(ledger.hasPlayed(.engagement))
    }

    /// F4 + D15: Home sits hidden under another tab with its geometry unchanged, so leaving
    /// clears every flag and returning replays only what is still on screen.
    func testLeavingHomeClearsAndReturningReplaysTheVisibleSections() {
        var ledger = ChartIntroLedger()
        ledger.setVisible(.overview, true)
        ledger.setVisible(.overview, false)
        ledger.setVisible(.activity, true)
        ledger.setActive(false)
        XCTAssertFalse(ledger.hasPlayed(.overview))
        XCTAssertFalse(ledger.hasPlayed(.activity))
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.activity))
        XCTAssertFalse(ledger.hasPlayed(.overview))
    }

    /// D6: a pushed page or a menu over Home never reports Home inactive — a repeated `true`
    /// changes nothing.
    func testARepeatedActiveSignalChangesNothing() {
        var ledger = ChartIntroLedger()
        ledger.setVisible(.overview, true)
        ledger.setVisible(.overview, false)
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.overview))
    }

    func testNothingPlaysWhileHomeIsHidden() {
        var ledger = ChartIntroLedger()
        ledger.setActive(false)
        ledger.setVisible(.engagement, true)
        XCTAssertFalse(ledger.hasPlayed(.engagement))
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.engagement))
    }

    func testHomeActiveFollowsTheSelectedTab() {
        var model = UI2ShellModel()
        XCTAssertTrue(model.homeActive)
        model.apply(.tab(.profile))
        XCTAssertFalse(model.homeActive)
        model.apply(.tab(.home))
        XCTAssertTrue(model.homeActive)
        model.apply(.section(.members))
        model.apply(.tab(.home))                // a re-tap of Home
        XCTAssertTrue(model.homeActive)
    }

    // MARK: - Task 3: C-024 / C-023

    func testSparkBarChartTreatsAnAllZeroSeriesAsEmpty() {
        XCTAssertTrue(SparkBarChart.isEmptySeries([]))
        XCTAssertTrue(SparkBarChart.isEmptySeries([0, 0, 0]))
        XCTAssertFalse(SparkBarChart.isEmptySeries([0, 2, 0]))
    }

    func testRailCardRisesEightPointsIntoPlace() {
        XCTAssertEqual(RailCard.introOffset(progress: 0), 8)
        XCTAssertEqual(RailCard.introOffset(progress: 0.5), 4)
        XCTAssertEqual(RailCard.introOffset(progress: 1), 0)
    }

    // MARK: - Task 4: C-026

    func testDualSeriesColumnsRiseToTheirStillHeight() {
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 0), 0)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 0.5), 49)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 1), 98)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(5, max: 0, progress: 1), 0)
    }

    /// D3: the today rule and badge wait for the sweep, but never past 0.4 s, so the badge's
    /// rise still lands inside 1.2 s however long the window is.
    func testDualSeriesTodayWaitsForTheSweepWithinTheBudget() {
        XCTAssertEqual(DualSeriesBarChart.introSettle(windowLength: 7), 0.09, accuracy: 1e-9)
        XCTAssertEqual(DualSeriesBarChart.introSettle(windowLength: 60), 0.4, accuracy: 1e-9)
    }
}
