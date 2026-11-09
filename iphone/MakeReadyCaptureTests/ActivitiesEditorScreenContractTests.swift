//
//  ActivitiesEditorScreenContractTests.swift
//  MakeReadyCaptureTests
//
//  The editor screen's contract with its container (SPEC D33): it reports object edits, carries
//  colours as hex, gates the Idle header's Done on `canSave` and has a load-failed state.
//

import XCTest
import SwiftUI
@testable import MakeReadyUI

@MainActor
final class ActivitiesEditorScreenContractTests: XCTestCase {
    func testEditorExposesObjectEdit() {
        var edits: [ActivitiesEditorScreen.ObjectEdit] = []
        let screen = ActivitiesEditorScreen(
            state: .idlePopulated,
            onEditObject: { edits.append($0) }
        )
        screen.onEditObject(.init(index: 0, color: "#509CEF"))
        XCTAssertEqual(edits.count, 1)
        XCTAssertEqual(edits.first?.index, 0)
        XCTAssertEqual(edits.first?.color, "#509CEF")
    }

    /// §9.3 (owner ruling 2026-11-08): `canSave` defaults to false; the Idle samples show both.
    func testCanSaveDefaultsOffAndIdleSamplesShowBoth() {
        XCTAssertFalse(ActivitiesEditorScreen.State.idleEmpty.canSave)
        XCTAssertTrue(ActivitiesEditorScreen.State.idlePopulated.canSave)
    }

    func testColorsAreHex() {
        let colors = ActivitiesEditorScreen.State.idlePopulated.objectColors.filter { !$0.isEmpty }
        XCTAssertFalse(colors.isEmpty)
        XCTAssertTrue(colors.allSatisfy { $0.hasPrefix("#") })
    }

    func testLoadFailedReportsThroughItsClosure() {
        var message: String?
        let screen = ActivitiesEditorScreen(state: .idlePopulated, onLoadFailed: { message = $0 })
        screen.onLoadFailed("Couldn't load this activity.")
        XCTAssertEqual(message, "Couldn't load this activity.")
    }
}
