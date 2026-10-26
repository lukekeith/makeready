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
}
