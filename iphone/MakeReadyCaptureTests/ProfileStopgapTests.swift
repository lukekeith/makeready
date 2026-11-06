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

    func testFixturePickerOnlyWithAKeyOnStaging() {
        XCTAssertTrue(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .staging))
        XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "", env: .staging))
        XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .production))
        XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .local))
    }

    func testResetCopy() {
        XCTAssertEqual(FixtureResetCopy.confirmTitle, "Reset this test data?")
        XCTAssertEqual(FixtureResetCopy.confirmMessage(for: .newGroup), "Reset New group for everyone on it?")
        XCTAssertEqual(FixtureResetCopy.action.label, "Reset")
        XCTAssertEqual(FixtureResetCopy.cancelLabel, "Cancel")
        XCTAssertEqual(FixtureResetCopy.startedMessage, "Reset started. This takes a few minutes and affects everyone on this fixture.")
        XCTAssertEqual(FixtureResetCopy.failedMessage, "Couldn't start the reset. Try again.")
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
        XCTAssertTrue(config.contains("PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app\n"))
        XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady-Staging"))
        XCTAssertTrue(config.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING"))
        XCTAssertTrue(config.contains("#include? \"Staging.local.xcconfig\""))
    }

    func testDebugAndReleaseCommitNoKey() throws {
        for name in ["Debug.xcconfig", "Release.xcconfig"] {
            let config = try text(name)
            let line = config.split(separator: "\n").first { $0.hasPrefix("FIXTURE_ACCESS_KEY") }
            XCTAssertEqual(line.map { $0.trimmingCharacters(in: .whitespaces) }, "FIXTURE_ACCESS_KEY =")
            XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady"))
        }
    }

    /// A local Debug build reads the git-ignored key so Staging offers Test data; a store build never does.
    func testOnlyDebugAndStagingReadTheLocalKey() throws {
        XCTAssertTrue(try text("Debug.xcconfig").contains("#include? \"Staging.local.xcconfig\""))
        XCTAssertFalse(try text("Release.xcconfig").contains("Staging.local"))
    }

    func testOldStagingXcconfigIsGone() {
        XCTAssertThrowsError(try text("MakeReady/Configuration/Staging.xcconfig"))
    }

    func testProjectHasAStagingConfigurationOnEveryList() throws {
        let project = try text("MakeReady.xcodeproj/project.pbxproj")
        XCTAssertEqual(project.components(separatedBy: "name = Staging;").count - 1, 6)
        XCTAssertFalse(project.contains("com.makeready.app.staging"))
        XCTAssertEqual(project.components(separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app;").count - 1, 3)
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

final class StagingEnvironmentTests: XCTestCase {
    func testEnvironmentListForEachBuild() {
        XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .staging), [.staging, .production])
        XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .debug), [.local, .staging, .production])
        XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .production), [.local, .staging, .production])
    }

    func testDefaultEnvironmentForEachBuild() {
        XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .staging), .staging)
        XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .debug), .production)
        XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .production), .production)
    }

    func testStagingFixtureTitlesOrderAndDefault() {
        let saved = UserDefaults.standard.string(forKey: "stagingFixture")
        defer { UserDefaults.standard.set(saved, forKey: "stagingFixture") }
        UserDefaults.standard.removeObject(forKey: "stagingFixture")
        XCTAssertEqual(StagingFixture.allCases.map(\.title), ["Fully populated", "New group"])
        XCTAssertEqual(StagingFixture.allCases.map(\.rawValue), ["full", "new-group"])
        XCTAssertEqual(StagingFixture.current, .full)
        StagingFixture.current = .newGroup
        XCTAssertEqual(StagingFixture.current, .newGroup)
    }

    func testLoginRouteForEveryEnvironmentAndKey() {
        XCTAssertEqual(AuthManager.loginRoute(env: .local, devMode: true, fixtureKey: "k"), .devLogin)
        XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: true, fixtureKey: "k"), .fixtureLogin)
        XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: true, fixtureKey: ""), .google)
        XCTAssertEqual(AuthManager.loginRoute(env: .production, devMode: true, fixtureKey: "k"), .google)
        XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: false, fixtureKey: "k"), .google)
    }
}
