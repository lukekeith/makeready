import XCTest
@testable import MakeReady

/// video-recorder D2, D3, D7: the settings survive on the device.
final class RecorderSettingsTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "RecorderSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testDefaults() {
        let s = RecorderSettings(defaults: freshDefaults())
        XCTAssertEqual(s.length, 60)
        XCTAssertEqual(s.preRoll, .off)
        XCTAssertEqual(s.script, "")
        XCTAssertEqual(s.speedStep, 3)
        XCTAssertEqual(s.sizeStep, 2)
    }

    func testValuesPersistAcrossInstancesAndSnapToTheirRanges() {
        let defaults = freshDefaults()
        let s = RecorderSettings(defaults: defaults)
        s.length = 94; s.preRoll = .ten; s.script = "In the beginning"; s.speedStep = 9; s.sizeStep = 0
        let reread = RecorderSettings(defaults: defaults)
        XCTAssertEqual(reread.length, 90)
        XCTAssertEqual(reread.preRoll, .ten)
        XCTAssertEqual(reread.script, "In the beginning")
        XCTAssertEqual(reread.speedStep, 5)
        XCTAssertEqual(reread.sizeStep, 1)
    }
}
