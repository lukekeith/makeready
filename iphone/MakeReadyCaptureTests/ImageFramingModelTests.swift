import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D5/D6/D7/D13/D20–D26: the Edit cover page's state, without the view.
@MainActor
final class ImageFramingModelTests: XCTestCase {
    private let frame = CGSize(width: 320, height: 180)
    private func image(_ size: CGSize = CGSize(width: 2400, height: 1600)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    private let ok = "https://img/new.jpeg"

    private func model(isNewPick: Bool = true, hasStoredOriginal: Bool = true, framing: CoverFraming = .identity,
                       save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> String) -> ImageFramingModel {
        ImageFramingModel(image: image(), framing: framing, isNewPick: isNewPick,
                          hasStoredOriginal: hasStoredOriginal, frameSize: frame,
                          outputSize: EditGroupCoverContainer.renderSize,
                          saveFailedMessage: EditGroupCoverContainer.saveFailedMessage,
                          save: save)
    }

    /// Every frame corner lies inside the framed (turned, rotated, scaled, offset) image.
    private func covers(_ f: CoverFraming, image: CGSize = CGSize(width: 2400, height: 1600)) -> Bool {
        let turned = f.quarterTurns % 2 == 0 ? image : CGSize(width: image.height, height: image.width)
        let s = ImageFramingMath.absoluteScale(f, image: image, frame: frame)
        let c = ImageFramingMath.imageCenter(f, frame: frame)
        let t = f.rotation * .pi / 180
        return [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].allSatisfy { corner in
            let dx = corner.0 * frame.width / 2 - c.x, dy = corner.1 * frame.height / 2 - c.y
            let u = dx * cos(t) + dy * sin(t), v = -dx * sin(t) + dy * cos(t)
            return abs(u) <= s * turned.width / 2 + 0.01 && abs(v) <= s * turned.height / 2 + 0.01
        }
    }

    /// D6: a new pick opens centred at the floor, unrotated.
    func testNewPickOpensAtIdentity() {
        XCTAssertEqual(model(save: { _, _, _ in self.ok }).framing, .identity)
    }

    func testPinchRotatePanTogetherThenSnapOnRelease() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 2, rotationDegrees: 2, translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(m.framing.scale, 2, accuracy: 1e-9)
        XCTAssertEqual(m.framing.rotation, 2, accuracy: 1e-9)
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 0)                    // D5 +-3 deg snap on release
        m.updateGesture(magnification: 1, rotationDegrees: 20, translation: .zero)
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 20, accuracy: 1e-9)   // cumulative from the committed base
        XCTAssertEqual(m.framing.scale, 2, accuracy: 1e-9)
    }

    /// D25: a pinch below the floor rubber-bands (× 0.3 past it) and settles back on release; the ceiling is hard.
    func testZoomRubberBandsBelowTheFloorAndSettles() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 0.2, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 1 - 0.8 * 0.3, accuracy: 1e-9)
        m.endGesture()
        XCTAssertEqual(m.framing.scale, 1)
        m.updateGesture(magnification: 50, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 8)
    }

    /// D25: a pan past the coverage limit moves at 0.3 and springs back to a covering framing.
    func testPanRubberBandsAndSettlesCovered() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 0, translation: CGSize(width: 100, height: 0))
        XCTAssertEqual(m.framing.offsetX, 100.0 / 320.0 * 0.3, accuracy: 1e-9)   // no slack at the floor → all excess
        XCTAssertFalse(covers(m.framing))
        m.endGesture()
        XCTAssertEqual(m.framing.offsetX, 0, accuracy: 1e-6)
        XCTAssertTrue(covers(m.framing))
    }

    /// D21: a twist stops at the ±45° fine-rotation range — and stays there past 180° (no wrap to the other stop).
    func testTwistStopsAtFortyFive() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 70, translation: .zero)
        XCTAssertEqual(m.framing.rotation, 45)
        m.updateGesture(magnification: 1, rotationDegrees: 200, translation: .zero)
        XCTAssertEqual(m.framing.rotation, 45)
        m.updateGesture(magnification: 1, rotationDegrees: -200, translation: .zero)
        XCTAssertEqual(m.framing.rotation, -45)
        m.updateGesture(magnification: 1, rotationDegrees: 40, translation: .zero)
        m.endGesture()
        m.updateGesture(magnification: 1, rotationDegrees: 145, translation: .zero)   // base 40 + 145 = 185
        XCTAssertEqual(m.framing.rotation, 45)
    }

    /// D22/D25: Flip mirrors the x offset and keeps the frame covered.
    func testFlipMirrorsTheXOffsetAndKeepsCoverage() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 2, rotationDegrees: 10, translation: CGSize(width: 40, height: 0))
        m.endGesture()
        let before = m.framing
        XCTAssertNotEqual(before.offsetX, 0)
        m.flip()
        XCTAssertTrue(m.framing.flipped)
        XCTAssertEqual(m.framing.offsetX, -before.offsetX, accuracy: 1e-9)
        XCTAssertEqual(m.framing.rotation, -before.rotation, accuracy: 1e-9)
        XCTAssertTrue(covers(m.framing))
        m.flip()
        XCTAssertEqual(m.framing, before)
    }

    /// D21/D22: Rotate 90° is counter-clockwise (q + 1), re-applies the floor, and four return to identity.
    func testRotate90FourTimesReturnsToIdentity() {
        let m = model(save: { _, _, _ in self.ok })
        var turns: [Int] = []
        for _ in 0..<4 {
            m.rotate90()
            turns.append(m.framing.quarterTurns)
            XCTAssertTrue(covers(m.framing))
        }
        XCTAssertEqual(turns, [1, 2, 3, 0])
        XCTAssertEqual(m.framing, .identity)
    }

    /// D22: Rotate 90° turns the whole framed view counter-clockwise — the pan turns with it — so four
    /// turns from a panned, tilted framing return to it.
    func testRotate90TurnsThePanAndFourTurnsReturnToIt() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 4, rotationDegrees: 10, translation: CGSize(width: 32, height: -9))
        m.endGesture()
        let start = m.framing
        XCTAssertEqual(start.offsetX, 0.1, accuracy: 1e-9)
        XCTAssertEqual(start.offsetY, -0.05, accuracy: 1e-9)
        m.rotate90()
        // (x, y) points → (y, −x): a pan up becomes a pan left, a pan right becomes a pan up.
        XCTAssertEqual(m.framing.offsetX, -0.05 * 180 / 320, accuracy: 1e-9)
        XCTAssertEqual(m.framing.offsetY, -0.1 * 320 / 180, accuracy: 1e-9)
        XCTAssertEqual(m.framing.rotation, 10, accuracy: 1e-9)
        for _ in 0..<3 { m.rotate90() }
        XCTAssertEqual(m.framing.quarterTurns, 0)
        XCTAssertEqual(m.framing.offsetX, start.offsetX, accuracy: 1e-9)
        XCTAssertEqual(m.framing.offsetY, start.offsetY, accuracy: 1e-9)
        XCTAssertEqual(m.framing.rotation, start.rotation, accuracy: 1e-9)
        XCTAssertEqual(m.framing.scale, start.scale, accuracy: 1e-9)
    }

    func testRotate90PullsAPanBackIntoCoverage() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 0, translation: CGSize(width: 0, height: 30))
        m.endGesture()
        XCTAssertGreaterThan(m.framing.offsetY, 0)            // vertical slack upright
        m.rotate90()
        XCTAssertTrue(covers(m.framing))
    }

    /// D30: the dial sets the fine rotation absolutely; the framing still covers once released.
    func testStraightenSetsRotationAbsolutelyAndStaysCovered() {
        let m = model(save: { _, _, _ in self.ok })
        m.straighten(to: 12)
        XCTAssertEqual(m.framing.rotation, 12, accuracy: 1e-9)
        XCTAssertTrue(m.isGestureActive)
        XCTAssertTrue(m.isTwisting)
        m.straighten(to: 20)
        m.straighten(to: 12)                                     // absolute, not cumulative
        XCTAssertEqual(m.framing.rotation, 12, accuracy: 1e-9)
        m.endStraighten()
        XCTAssertEqual(m.framing.rotation, 12, accuracy: 1e-9)
        XCTAssertTrue(covers(m.framing))
        XCTAssertFalse(m.isGestureActive)
        XCTAssertFalse(m.isTwisting)
    }

    /// D30: scale and offsets stay from the committed base while the dial turns.
    func testStraightenKeepsScaleAndOffsets() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 4, rotationDegrees: 0, translation: CGSize(width: 32, height: -9))
        m.endGesture()
        let before = m.framing
        m.straighten(to: 6)
        XCTAssertEqual(m.framing.scale, before.scale, accuracy: 1e-9)
        XCTAssertEqual(m.framing.offsetX, before.offsetX, accuracy: 1e-9)
        XCTAssertEqual(m.framing.offsetY, before.offsetY, accuracy: 1e-9)
    }

    /// D30: the dial is bounded to ±45° like the twist.
    func testStraightenClampsToTheMaximumRotation() {
        let m = model(save: { _, _, _ in self.ok })
        m.straighten(to: 60)
        XCTAssertEqual(m.framing.rotation, 45, accuracy: 1e-9)
        m.straighten(to: -60)
        XCTAssertEqual(m.framing.rotation, -45, accuracy: 1e-9)
        m.endStraighten()
        XCTAssertTrue(covers(m.framing))
    }

    /// D5/D30: releasing the dial within ±3° snaps to level.
    func testEndStraightenSnapsWithinThreeDegrees() {
        let m = model(save: { _, _, _ in self.ok })
        m.straighten(to: 2)
        XCTAssertEqual(m.framing.rotation, 2, accuracy: 1e-9)
        m.endStraighten()
        XCTAssertEqual(m.framing.rotation, 0)
    }

    /// D30: a twist after a straighten continues from the straightened value.
    func testTwistContinuesFromAStraightenedValue() {
        let m = model(save: { _, _, _ in self.ok })
        m.straighten(to: 12)
        m.endStraighten()
        m.updateGesture(magnification: 1, rotationDegrees: 8, translation: .zero)
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 20, accuracy: 1e-9)
    }

    /// D13: the dial is off while saving, like the gestures.
    func testStraightenIsIgnoredWhileSaving() async {
        var release: CheckedContinuation<Void, Never>?
        let m = model(save: { _, _, _ in
            await withCheckedContinuation { release = $0 }
            return self.ok
        })
        async let first = m.save()
        while release == nil { await Task.yield() }
        m.straighten(to: 20)
        m.endStraighten()
        XCTAssertEqual(m.framing, .identity)
        XCTAssertFalse(m.isGestureActive)
        release?.resume()
        _ = await first
    }

    /// D30: Flip negates the rotation, so a straightened +10 reads -10 (dial and readout change sign).
    func testFlipNegatesAStraightenedRotation() {
        let m = model(save: { _, _, _ in self.ok })
        m.straighten(to: 10)
        m.endStraighten()
        m.flip()
        XCTAssertEqual(m.framing.rotation, -10, accuracy: 1e-9)
        XCTAssertEqual(m.readoutDegrees, -10)
    }

    /// D22: Done is enabled on a re-edit only after a change; a new pick is always savable.
    func testHasChanges() {
        let stored = model(isNewPick: false, framing: CoverFraming(scale: 2, rotation: 0, offsetX: 0, offsetY: 0),
                           save: { _, _, _ in self.ok })
        XCTAssertFalse(stored.hasChanges)
        stored.updateGesture(magnification: 1.2, rotationDegrees: 0, translation: .zero)
        stored.endGesture()
        XCTAssertTrue(stored.hasChanges)

        let changes: [@MainActor (ImageFramingModel) -> Void] = [{ $0.flip() }, { $0.rotate90() }]
        for change in changes {
            let m = model(isNewPick: false, save: { _, _, _ in self.ok })
            change(m)
            XCTAssertTrue(m.hasChanges)
        }
        XCTAssertTrue(model(isNewPick: true, save: { _, _, _ in self.ok }).hasChanges)
    }

    /// D24: the readout shows while twisting; the grid while any gesture is active.
    func testTwistReadoutAndGestureGrid() {
        let m = model(save: { _, _, _ in self.ok })
        XCTAssertFalse(m.isGestureActive)
        XCTAssertFalse(m.isTwisting)
        m.updateGesture(magnification: 1.1, rotationDegrees: 0, translation: .zero)
        XCTAssertTrue(m.isGestureActive)
        XCTAssertFalse(m.isTwisting)
        m.updateGesture(magnification: 1.2, rotationDegrees: 0.6, translation: .zero)   // pinch jitter, not a twist
        XCTAssertFalse(m.isTwisting)
        m.updateGesture(magnification: 1.1, rotationDegrees: -12.4, translation: .zero)
        XCTAssertTrue(m.isTwisting)
        XCTAssertEqual(m.readoutDegrees, -12)
        m.endGesture()
        XCTAssertFalse(m.isGestureActive)
        XCTAssertFalse(m.isTwisting)
    }

    /// D13: the controls are off while saving, like the gestures.
    func testFlipAndRotateAreIgnoredWhileSaving() async {
        var release: CheckedContinuation<Void, Never>?
        let m = model(save: { _, _, _ in
            await withCheckedContinuation { release = $0 }
            return self.ok
        })
        async let first = m.save()
        while release == nil { await Task.yield() }
        m.flip(); m.rotate90()
        XCTAssertEqual(m.framing, .identity)
        release?.resume()
        _ = await first
    }

    /// D5/D25: Done mid-gesture saves what release would settle to — covered, and the ±3° snap applied.
    func testSaveSendsASettledFraming() async {
        var sent: CoverFraming?
        let m = model(save: { _, f, _ in sent = f; return self.ok })
        m.updateGesture(magnification: 0.5, rotationDegrees: 2, translation: CGSize(width: 200, height: 0))
        _ = await m.save()
        XCTAssertEqual(sent?.scale, 1)
        XCTAssertEqual(sent?.offsetX ?? 1, 0, accuracy: 1e-6)
        XCTAssertEqual(sent?.rotation, 0)
    }

    /// D13: a new pick sends the original; a re-edit of a stored original does not.
    func testSaveSendsTheOriginalOnlyForANewPick() async {
        var originals: [Bool] = []
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> String = { _, _, o in originals.append(o != nil); return self.ok }
        _ = await model(isNewPick: true, save: save).save()
        _ = await model(isNewPick: false, save: save).save()
        XCTAssertEqual(originals, [true, false])
    }

    /// D7: the first edit of a no-original cover uses the cover as the original, so Save must store it as one.
    func testSaveSendsTheOriginalWhenTheGroupHasNoStoredOne() async {
        var originals: [Bool] = []
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> String = { _, _, o in originals.append(o != nil); return self.ok }
        _ = await model(isNewPick: false, hasStoredOriginal: false, save: save).save()
        XCTAssertEqual(originals, [true])
    }

    func testSaveRendersAt1200x675() async {
        var size: CGSize?
        _ = await model(save: { r, _, _ in size = CGSize(width: r.cgImage!.width, height: r.cgImage!.height); return self.ok }).save()
        XCTAssertEqual(size, CGSize(width: 1200, height: 675))
    }

    /// D13: a second Save while saving is ignored.
    func testSecondSaveWhileSavingIsIgnored() async {
        var calls = 0
        var release: CheckedContinuation<Void, Never>?
        let m = model(save: { _, _, _ in
            calls += 1
            await withCheckedContinuation { release = $0 }
            return self.ok
        })
        async let first = m.save()
        while release == nil { await Task.yield() }              // the first save is suspended inside send
        XCTAssertTrue(m.isSaving)
        let second = await m.save()
        XCTAssertEqual(second, .ignored)
        release?.resume()
        let firstOutcome = await first
        XCTAssertEqual(firstOutcome, .saved)
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(m.isSaving)
    }

    /// D13: gestures are off while saving, release included, so the saved framing stays what was rendered.
    func testReleaseWhileSavingDoesNotChangeTheFraming() async {
        var release: CheckedContinuation<Void, Never>?
        let m = model(save: { _, _, _ in
            await withCheckedContinuation { release = $0 }
            return self.ok
        })
        m.updateGesture(magnification: 2, rotationDegrees: 10, translation: CGSize(width: 30, height: 0))
        async let first = m.save()
        while release == nil { await Task.yield() }
        let saving = m.framing
        m.updateGesture(magnification: 3, rotationDegrees: 20, translation: CGSize(width: 90, height: 0))
        m.endGesture()
        XCTAssertEqual(m.framing, saving)
        release?.resume()
        _ = await first
    }

    /// D13: success seeds the cache under the new URL so the cover does not flash the placeholder.
    func testSuccessSeedsTheImageCache() async {
        let url = "https://img/seed-\(UUID().uuidString).jpeg"
        let m = model(save: { _, _, _ in url })
        let outcome = await m.save()
        XCTAssertEqual(outcome, .saved)
        XCTAssertNotNil(Ui2ImageCache.shared.image(for: URL(string: url)!))
    }

    func testOutcomes() async {
        let timedOut = APIError.networkError(URLError(.timedOut))
        let unauthorized = await model(save: { _, _, _ in throw APIError.unauthorized }).save()
        let gone = await model(save: { _, _, _ in throw APIHTTPError(status: 404, message: nil) }).save()
        let server = await model(save: { _, _, _ in throw APIHTTPError(status: 500, message: "x") }).save()
        let network = await model(save: { _, _, _ in throw timedOut }).save()
        XCTAssertEqual(unauthorized, .unauthorized)
        XCTAssertEqual(gone, .gone)
        XCTAssertEqual(server, .failed("x"))
        XCTAssertEqual(network, .failed(timedOut.localizedDescription))
    }

    /// image-framing-editor D12: a 403 is its own outcome (the avatar pops to its profile on it).
    func testForbiddenOutcome() async {
        let outcome = await model(save: { _, _, _ in throw APIHTTPError(status: 403, message: "Forbidden") }).save()
        XCTAssertEqual(outcome, .forbidden)
    }

    /// image-framing-editor D1/D7: the render follows the model's output size — 512×512 for the avatar.
    func testSaveRendersAtTheOutputSize() async {
        var size: CGSize?
        let m = ImageFramingModel(image: image(), framing: .identity, isNewPick: true, hasStoredOriginal: true,
                                  frameSize: CGSize(width: 300, height: 300), outputSize: CGSize(width: 512, height: 512),
                                  saveFailedMessage: "Couldn't save the photo",
                                  save: { r, _, _ in size = CGSize(width: r.cgImage!.width, height: r.cgImage!.height); return self.ok })
        _ = await m.save()
        XCTAssertEqual(size, CGSize(width: 512, height: 512))
        XCTAssertEqual(m.saveFailedMessage, "Couldn't save the photo")
    }
}
