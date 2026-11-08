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

    /// §2 items 4 + 6 (agent walk round 2, item 10): with the keyboard up, a sheet stands on the
    /// keyboard's top edge — lifted once, by the overlap — and its cap shrinks by that overlap, so
    /// its header and Done stay on screen (top ≥ the 16pt gap below the safe top).
    func testSheetRidesTheKeyboardOnceAndKeepsItsHeaderOnScreen() {
        let available: CGFloat = 956 - 62           // overlay height below the safe top, 440×956
        for overlap: CGFloat in [0, 336, 900] {
            let layout = ActivitiesEditorScreen.sheetLayout(available: available, keyboardOverlap: overlap)
            XCTAssertEqual(layout.lift, min(overlap, available - 16), "lifted once, by the keyboard's overlap")
            let top = available - layout.lift - layout.maxHeight
            XCTAssertGreaterThanOrEqual(top, 16, "the sheet's header stays below the top gap at overlap \(overlap)")
            XCTAssertGreaterThanOrEqual(layout.maxHeight, 0)
        }
        let resting = ActivitiesEditorScreen.sheetLayout(available: available, keyboardOverlap: 0)
        XCTAssertEqual(resting.maxHeight, available - 16, "no keyboard: the cap is the screen minus the safe top and 16pt")
    }
}
