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

    // MARK: - D25: grabbing a text layer (owner walk round 3)

    private typealias Area = ActivitiesEditorScreen.GrabArea

    /// The grab area is the box padded 24 pt each side, so a touch just outside the text still grabs it.
    func testATouchJustOutsideTheTextGrabsIt() {
        let text = Area(center: CGPoint(x: 200, y: 400), size: CGSize(width: 200, height: 60))
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200 + 100 + 20, y: 400), objects: [text], editedIndex: nil), 0)
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200, y: 400 + 30 + 20), objects: [text], editedIndex: nil), 0)
        XCTAssertNil(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200 + 100 + 30, y: 400), objects: [text], editedIndex: nil))
    }

    /// A tiny object still offers at least 88 × 88 pt.
    func testASmallObjectHasAnEightyEightPointMinimum() {
        let tiny = Area(center: CGPoint(x: 100, y: 100), size: CGSize(width: 10, height: 10))
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 100 + 43, y: 100 - 43), objects: [tiny], editedIndex: nil), 0)
        XCTAssertNil(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 100 + 46, y: 100), objects: [tiny], editedIndex: nil))
    }

    /// The area turns with the object: a point along a 90°-rotated box's long axis grabs it, one off it doesn't.
    func testTheAreaFollowsRotationAndScale() {
        let rotated = Area(center: CGPoint(x: 200, y: 400), size: CGSize(width: 300, height: 40), rotation: .degrees(90))
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200, y: 400 + 160), objects: [rotated], editedIndex: nil), 0)
        XCTAssertNil(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200 + 160, y: 400), objects: [rotated], editedIndex: nil))
        let scaled = Area(center: CGPoint(x: 200, y: 400), size: CGSize(width: 100, height: 40), scale: 2)
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: CGPoint(x: 200 + 110, y: 400), objects: [scaled], editedIndex: nil), 0)
    }

    /// The edited object wins; otherwise the topmost (last drawn) one does.
    func testTheEditedObjectWinsThenTheTopmost() {
        let a = Area(center: CGPoint(x: 200, y: 400), size: CGSize(width: 200, height: 60))
        let b = Area(center: CGPoint(x: 210, y: 410), size: CGSize(width: 200, height: 60))
        let point = CGPoint(x: 205, y: 405)
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: point, objects: [a, b], editedIndex: nil), 1)
        XCTAssertEqual(ActivitiesEditorScreen.grabTarget(at: point, objects: [a, b], editedIndex: 0), 0)
    }

    // MARK: - D32: snapping (owner 2026-11-09)

    /// Rotation snaps to every 45° within 4° and lets go past the release window.
    func testRotationSnapsToEveryFortyFiveDegrees() {
        XCTAssertEqual(ActivitiesEditorScreen.snapRotation(43, engaged: nil).angle, 45)
        XCTAssertEqual(ActivitiesEditorScreen.snapRotation(-88, engaged: nil).angle, -90)
        XCTAssertEqual(ActivitiesEditorScreen.snapRotation(2.5, engaged: nil).angle, 0)
        XCTAssertEqual(ActivitiesEditorScreen.snapRotation(20, engaged: nil).angle, 20)          // outside every window
        XCTAssertNil(ActivitiesEditorScreen.snapRotation(20, engaged: nil).engaged)
        XCTAssertEqual(ActivitiesEditorScreen.snapRotation(49, engaged: 45).angle, 45)           // held inside release
    }

    /// A layer dragged near the page centre snaps onto it and shows a guide; far off, nothing snaps.
    func testAMoveNearThePageCentreSnapsAndShowsAGuide() {
        let size = CGSize(width: 200, height: 60)
        let near = ActivitiesEditorScreen.snapPosition(CGPoint(x: 223, y: 500), size: size, rotation: .zero, others: [],
                                                       viewport: 956, pinnedAction: false, unit: 1, engaged: .init())
        XCTAssertEqual(near.position.x, 220, accuracy: 0.01)
        XCTAssertFalse(near.guides.isEmpty)
        let far = ActivitiesEditorScreen.snapPosition(CGPoint(x: 260, y: 500), size: CGSize(width: 100, height: 60),
                                                      rotation: .zero, others: [], viewport: 956, pinnedAction: false,
                                                      unit: 1, engaged: .init())
        XCTAssertEqual(far.position.x, 260, accuracy: 0.01)
    }

    /// The standard 24 wu gap: a layer dragged to just under another snaps to sit 24 wu below it.
    func testTheStandardGapSnaps() {
        let above = CGRect(x: 120, y: 300, width: 200, height: 60)               // bottom edge at 360
        let size = CGSize(width: 200, height: 60)
        // Centre y for a 24 wu gap = 360 + 24 + 30 = 414; start 3 wu off.
        let result = ActivitiesEditorScreen.snapPosition(CGPoint(x: 260, y: 417), size: size, rotation: .zero,
                                                         others: [above], viewport: 956, pinnedAction: false,
                                                         unit: 1, engaged: .init())
        XCTAssertEqual(result.position.y, 414, accuracy: 0.01)
    }
}
