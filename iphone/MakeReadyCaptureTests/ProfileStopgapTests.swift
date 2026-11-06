import XCTest
@testable import MakeReady

final class ProfileStopgapTests: XCTestCase {
    func testSwitcherOnlyInDevMode() {
        XCTAssertTrue(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: true))
        XCTAssertFalse(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: false))
    }

    /// ui2-fixtures D13: the "Local identity" group shows only in a dev build pointed at Local.
    func testIdentityPickerOnlyForDevModeOnLocal() {
        XCTAssertTrue(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .local))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .staging))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: true, env: .production))
        XCTAssertFalse(ProfileStopgapContainer.showsIdentityPicker(devMode: false, env: .local))
    }
}

final class StagingBuildConfigTests: XCTestCase {
    private func text(_ path: String) throws -> String {
        let iphone = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: iphone.appendingPathComponent(path), encoding: .utf8)
    }

    func testStagingXcconfigHoldsTheStagingSettings() throws {
        let config = try text("Staging.xcconfig")
        XCTAssertTrue(config.contains("DEV_MODE = YES"))
        XCTAssertTrue(config.contains("PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging"))
        XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady-Staging"))
        XCTAssertTrue(config.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING"))
        XCTAssertTrue(config.contains("#include? \"Staging.local.xcconfig\""))
    }

    func testDebugAndReleaseCarryNoKey() throws {
        for name in ["Debug.xcconfig", "Release.xcconfig"] {
            let config = try text(name)
            let line = config.split(separator: "\n").first { $0.hasPrefix("FIXTURE_ACCESS_KEY") }
            XCTAssertEqual(line.map { $0.trimmingCharacters(in: .whitespaces) }, "FIXTURE_ACCESS_KEY =")
            XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady"))
            XCTAssertFalse(config.contains("Staging.local"))
        }
    }

    func testOldStagingXcconfigIsGone() {
        XCTAssertThrowsError(try text("MakeReady/Configuration/Staging.xcconfig"))
    }

    func testProjectHasAStagingConfigurationOnEveryList() throws {
        let project = try text("MakeReady.xcodeproj/project.pbxproj")
        XCTAssertEqual(project.components(separatedBy: "name = Staging;").count - 1, 6)
        XCTAssertEqual(project.components(separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging;").count - 1, 1)
        XCTAssertEqual(project.components(separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app;").count - 1, 2)
    }

    func testStagingSchemeArchivesWithStaging() throws {
        let scheme = try text("MakeReady.xcodeproj/xcshareddata/xcschemes/MakeReady Staging.xcscheme")
        let archive = try XCTUnwrap(scheme.range(of: "<ArchiveAction"))
        XCTAssertTrue(scheme[archive.upperBound...].contains("buildConfiguration = \"Staging\""))
        let test = try XCTUnwrap(scheme.range(of: "<TestAction"))
        XCTAssertTrue(String(scheme[test.upperBound...].prefix(60)).contains("buildConfiguration = \"Debug\""))
    }

    func testInfoPlistCarriesTheNewKeys() throws {
        let plist = try text("MakeReady/Info.plist")
        XCTAssertTrue(plist.contains("<key>FIXTURE_ACCESS_KEY</key>\n\t<string>$(FIXTURE_ACCESS_KEY)</string>"))
        XCTAssertTrue(plist.contains("<key>CFBundleDisplayName</key>\n\t<string>$(APP_DISPLAY_NAME)</string>"))
    }
}
