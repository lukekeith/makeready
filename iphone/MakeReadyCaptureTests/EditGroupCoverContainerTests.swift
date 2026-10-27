import XCTest
import SwiftUI
import UIKit
@testable import MakeReady

/// group-cover-image D13/D26/D28/D30: the Edit cover page's routing and screen state, without the view.
@MainActor
final class EditGroupCoverContainerTests: XCTestCase {
    private let ok = CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: nil, coverFraming: .identity)

    private func model(isNewPick: Bool) -> EditGroupCoverModel {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: 1600, height: 1200)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return EditGroupCoverModel(groupId: "g1", image: image, framing: .identity, isNewPick: isNewPick,
                                   hasStoredOriginal: true, frameSize: CGSize(width: 320, height: 180),
                                   save: { _, _, _ in self.ok })
    }

    /// D13: each save outcome's route.
    func testOutcomeRoutes() {
        XCTAssertEqual(EditGroupCoverContainer.route(.saved), .pop)
        XCTAssertEqual(EditGroupCoverContainer.route(.gone), .popToRoot)
        XCTAssertEqual(EditGroupCoverContainer.route(.unauthorized), .signOut)
        XCTAssertEqual(EditGroupCoverContainer.route(.failed("x")), .banner)
        XCTAssertEqual(EditGroupCoverContainer.route(.ignored), .stay)
    }

    func testDestinationIsHashableWithAPick() {
        let img = UIImage()
        let a = UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img))
        XCTAssertEqual(a, UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img)))
        XCTAssertNotEqual(a, UI2Destination.editGroupCover(groupId: "g1", source: .stored))
    }

    /// D26: Cancel with a change asks to discard; with none it pops.
    func testCancelAction() {
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: true), .confirmDiscard)
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: false), .pop)
    }

    /// D30: no grid and no readout at rest; Done mirrors `hasChanges` (a new pick is always savable).
    func testScreenStateAtRest() {
        let pick: EditCoverScreen<EmptyView>.State = EditGroupCoverContainer.screenState(model(isNewPick: true))
        XCTAssertFalse(pick.showsGrid)
        XCTAssertNil(pick.readoutDegrees)
        XCTAssertEqual(pick.rotationDegrees, 0)
        XCTAssertFalse(pick.saving)
        XCTAssertTrue(pick.doneEnabled)

        let reEdit: EditCoverScreen<EmptyView>.State = EditGroupCoverContainer.screenState(model(isNewPick: false))
        XCTAssertFalse(reEdit.doneEnabled)
    }

    /// D30: a pan shows the grid but no readout; a twist shows both, the readout the rounded rotation.
    func testScreenStateWhileGesturing() {
        let m = model(isNewPick: false)
        m.updateGesture(magnification: 1.5, rotationDegrees: 0, translation: .zero)
        var s: EditCoverScreen<EmptyView>.State = EditGroupCoverContainer.screenState(m)
        XCTAssertTrue(s.showsGrid)
        XCTAssertNil(s.readoutDegrees)
        XCTAssertTrue(s.doneEnabled)

        m.updateGesture(magnification: 1.5, rotationDegrees: -12.4, translation: .zero)
        s = EditGroupCoverContainer.screenState(m)
        XCTAssertTrue(s.showsGrid)
        XCTAssertEqual(s.readoutDegrees, -12)
        XCTAssertEqual(s.rotationDegrees, -12.4, accuracy: 1e-9)
    }

    /// D30: the dial drives the same state as a twist.
    func testScreenStateWhileStraightening() {
        let m = model(isNewPick: false)
        m.straighten(to: 20)
        let s: EditCoverScreen<EmptyView>.State = EditGroupCoverContainer.screenState(m)
        XCTAssertTrue(s.showsGrid)
        XCTAssertEqual(s.readoutDegrees, 20)
        XCTAssertEqual(s.rotationDegrees, 20, accuracy: 1e-9)
    }

    /// Before the image and frame are ready: nothing to save, nothing to show.
    func testScreenStateWhileLoading() {
        let s: EditCoverScreen<EmptyView>.State = EditGroupCoverContainer.screenState(nil)
        XCTAssertFalse(s.showsGrid)
        XCTAssertNil(s.readoutDegrees)
        XCTAssertFalse(s.saving)
        XCTAssertFalse(s.doneEnabled)
    }
}
