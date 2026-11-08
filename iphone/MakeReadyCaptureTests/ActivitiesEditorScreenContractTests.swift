//
//  ActivitiesEditorScreenContractTests.swift
//  MakeReadyCaptureTests
//
//  The editor screen's contract with its container (SPEC D33): it reports object edits, carries
//  colours as hex, exposes the Idle-header play glyph's callback and a load-failed state.
//

import XCTest
import SwiftUI
@testable import MakeReadyUI

@MainActor
final class ActivitiesEditorScreenContractTests: XCTestCase {
    func testEditorExposesObjectEditAndPlay() {
        var edits: [ActivitiesEditorScreen.ObjectEdit] = []
        var plays = 0
        let screen = ActivitiesEditorScreen(
            state: .idlePopulated,
            onEditObject: { edits.append($0) },
            onPlay: { plays += 1 }
        )
        screen.onEditObject(.init(index: 0, color: "#509CEF"))
        screen.onPlay()
        XCTAssertEqual(edits.count, 1)
        XCTAssertEqual(edits.first?.index, 0)
        XCTAssertEqual(edits.first?.color, "#509CEF")
        XCTAssertEqual(plays, 1)
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
