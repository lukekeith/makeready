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
        XCTAssertFalse(s.countdownSound, "countdown-sound S3: silent until the leader turns it on")
        XCTAssertEqual(s.lengthMode, .any, "video-polish D4: a new leader starts on Any length")
        XCTAssertEqual(s.endCountdownSeconds, 0, "video-polish D6: the end countdown is off by default")
    }

    func testSavedLengthOpensAsSpecify() {
        let defaults = freshDefaults()
        defaults.set(90, forKey: "videoRecorder.lengthSeconds")
        let s = RecorderSettings(defaults: defaults)
        XCTAssertEqual(s.lengthMode, .specify)
        XCTAssertEqual(s.length, 90)
        s.lengthMode = .any
        XCTAssertEqual(RecorderSettings(defaults: defaults).lengthMode, .any)
    }

    func testEndCountdownPersistsAndRejectsOtherValues() {
        let defaults = freshDefaults()
        RecorderSettings(defaults: defaults).endCountdownSeconds = 3
        XCTAssertEqual(RecorderSettings(defaults: defaults).endCountdownSeconds, 3)
        RecorderSettings(defaults: defaults).endCountdownSeconds = 7
        XCTAssertEqual(RecorderSettings(defaults: defaults).endCountdownSeconds, 0)
    }

    func testValuesPersistAcrossInstancesAndSnapToTheirRanges() {
        let defaults = freshDefaults()
        let s = RecorderSettings(defaults: defaults)
        s.length = 94; s.preRoll = .ten; s.script = "In the beginning"; s.speedStep = 9; s.sizeStep = 0
        let reread = RecorderSettings(defaults: defaults)
        XCTAssertEqual(reread.length, 94, "video-polish D13: no snapping")
        XCTAssertEqual(reread.preRoll, .ten)
        XCTAssertEqual(reread.script, "In the beginning")
        XCTAssertEqual(reread.speedStep, 5)
        XCTAssertEqual(reread.sizeStep, 1)
    }

    func testCountdownSoundPersists() {
        let defaults = freshDefaults()
        RecorderSettings(defaults: defaults).countdownSound = true
        XCTAssertTrue(RecorderSettings(defaults: defaults).countdownSound)
        RecorderSettings(defaults: defaults).countdownSound = false
        XCTAssertFalse(RecorderSettings(defaults: defaults).countdownSound)
    }

    @MainActor
    func testBeeperIsSilentUnlessSoundIsOn() {
        var soundOn = false
        var played: [Double] = []
        let beeper = CountdownBeeper(isSoundOn: { soundOn }, play: { played.append($0) })
        beeper.beep(hz: 1100)
        XCTAssertEqual(played, [], "Sound off: no beep")
        soundOn = true
        beeper.beep(hz: 1100)
        beeper.beep(hz: 1660)
        XCTAssertEqual(played, [1100, 1660], "Sound on: every beep plays, read fresh each time")
    }
}
