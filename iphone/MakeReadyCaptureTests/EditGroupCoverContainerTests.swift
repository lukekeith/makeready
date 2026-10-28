import XCTest
import SwiftUI
import UIKit
@testable import MakeReady

/// group-cover-image D13/D26/D28/D30: the Edit cover page's routing and screen state, without the view.
@MainActor
final class EditGroupCoverContainerTests: XCTestCase {
    private let ok = "https://img/new.jpeg"

    private func model(isNewPick: Bool) -> ImageFramingModel {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: 1600, height: 1200)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return ImageFramingModel(image: image, framing: .identity, isNewPick: isNewPick,
                                 hasStoredOriginal: true, frameSize: CGSize(width: 320, height: 180),
                                 outputSize: EditGroupCoverContainer.renderSize,
                                 saveFailedMessage: EditGroupCoverContainer.saveFailedMessage,
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
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: true, isSaving: false), .confirmDiscard)
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: false, isSaving: false), .pop)
    }

    /// I1/D13: while a save is in flight Cancel (and so the blocked swipe) does nothing — no
    /// discard menu, no pop — and the discard row cannot pop.
    func testCancelIsInertWhileSaving() {
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: true, isSaving: true), .ignore)
        XCTAssertEqual(EditGroupCoverContainer.cancelAction(hasChanges: false, isSaving: true), .ignore)
        XCTAssertFalse(EditGroupCoverContainer.discardPops(isSaving: true))
        XCTAssertTrue(EditGroupCoverContainer.discardPops(isSaving: false))
    }

    /// I1/D26: the edge swipe is vetoed while there is a change OR a save is in flight.
    func testBackSwipeIsBlockedWhileSaving() {
        XCTAssertTrue(EditGroupCoverContainer.blocksBackSwipe(hasChanges: false, isSaving: true))
        XCTAssertTrue(EditGroupCoverContainer.blocksBackSwipe(hasChanges: true, isSaving: false))
        XCTAssertFalse(EditGroupCoverContainer.blocksBackSwipe(hasChanges: false, isSaving: false))
    }

    /// D26/D2: the discard row's glyph is a real GlyphName case (an unknown name renders the red stub).
    func testDiscardGlyphExists() {
        XCTAssertNotNil(GlyphName(rawValue: EditGroupCoverContainer.discardAction.glyph))
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

    /// Moved from CoverFramingMathTests (image-framing-editor D1): the 16:9 frame and the 1200×675
    /// render are the group cover's own constants now.
    func testFrameIs16By9() {
        XCTAssertEqual(EditGroupCoverContainer.frameAspect, 16.0 / 9.0, accuracy: 1e-12)
        XCTAssertEqual(EditGroupCoverContainer.renderSize, CGSize(width: 1200, height: 675))
    }

    /// image-framing-editor D12: the model's new 403 outcome keeps the group cover's old behaviour — the banner.
    func testForbiddenKeepsTheGroupBanner() {
        XCTAssertEqual(EditGroupCoverContainer.route(.forbidden), .banner)
    }

    /// Moved from EditGroupCoverModelTests (group-cover-image D7): the original at its framing; no
    /// original -> the cover at identity; no cover -> nil.
    func testOpening() {
        func group(cover: String?, original: String?, framing: CoverFraming?) -> UserGroup {
            UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original, coverFraming: framing,
                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
        }
        let f = CoverFraming(scale: 3, rotation: 10, offsetX: 0, offsetY: 0)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.url, "o")
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.hasOriginal, true)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.framing, f)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: nil))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.url, "c")
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.hasOriginal, false)
        XCTAssertNil(EditGroupCoverContainer.opening(group: group(cover: nil, original: nil, framing: nil)))
    }
}
