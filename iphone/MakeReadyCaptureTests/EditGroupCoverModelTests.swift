import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D5/D6/D7/D13/D20–D26: the Edit cover page's state, without the view.
@MainActor
final class EditGroupCoverModelTests: XCTestCase {
    private let frame = CGSize(width: 320, height: 180)
    private func image(_ size: CGSize = CGSize(width: 2400, height: 1600)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    private let ok = CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: "https://img/o.jpeg", coverFraming: .identity)

    private func model(isNewPick: Bool = true, hasStoredOriginal: Bool = true, framing: CoverFraming = .identity,
                       horizon: Double? = nil,
                       save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult) -> EditGroupCoverModel {
        EditGroupCoverModel(groupId: "g1", image: image(), framing: framing, isNewPick: isNewPick,
                            hasStoredOriginal: hasStoredOriginal, frameSize: frame,
                            detectHorizon: { _ in horizon }, save: save)
    }

    /// Every frame corner lies inside the framed (turned, rotated, scaled, offset) image.
    private func covers(_ f: CoverFraming, image: CGSize = CGSize(width: 2400, height: 1600)) -> Bool {
        let turned = f.quarterTurns % 2 == 0 ? image : CGSize(width: image.height, height: image.width)
        let s = CoverFramingMath.absoluteScale(f, image: image, frame: frame)
        let c = CoverFramingMath.imageCenter(f, frame: frame)
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

    /// D21: a twist stops at the ±45° fine-rotation range.
    func testTwistStopsAtFortyFive() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 70, translation: .zero)
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

    func testRotate90PullsAPanBackIntoCoverage() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 0, translation: CGSize(width: 0, height: 30))
        m.endGesture()
        XCTAssertGreaterThan(m.framing.offsetY, 0)            // vertical slack upright
        m.rotate90()
        XCTAssertTrue(covers(m.framing))
    }

    /// D23: Auto is disabled until a horizon is found, then levels it (clamped to ±45°) at the floor.
    func testAutoLevelsTheDetectedHorizon() async {
        let none = model(horizon: nil, save: { _, _, _ in self.ok })
        await none.detectHorizon()
        XCTAssertNil(none.horizonAngle)
        XCTAssertFalse(none.canAuto)
        none.auto()
        XCTAssertEqual(none.framing, .identity)

        let m = model(horizon: 8, save: { _, _, _ in self.ok })
        XCTAssertFalse(m.canAuto)                               // not run yet
        await m.detectHorizon()
        XCTAssertEqual(m.horizonAngle, 8)
        XCTAssertTrue(m.canAuto)
        m.auto()
        XCTAssertEqual(m.framing.rotation, 8, accuracy: 1e-9)
        XCTAssertTrue(covers(m.framing))
        m.flip()
        m.auto()
        XCTAssertEqual(m.framing.rotation, -8, accuracy: 1e-9) // the mirror's horizon tilts the other way

        let steep = model(horizon: 70, save: { _, _, _ in self.ok })
        await steep.detectHorizon()
        steep.auto()
        XCTAssertEqual(steep.framing.rotation, 45)
    }

    /// D23: detection runs once on open.
    func testHorizonIsDetectedOnce() async {
        var runs = 0
        let m = EditGroupCoverModel(groupId: "g1", image: image(), framing: .identity, isNewPick: true, hasStoredOriginal: true,
                                    frameSize: frame, detectHorizon: { _ in await MainActor.run { runs += 1 }; return 3 },
                                    save: { _, _, _ in self.ok })
        await m.detectHorizon()
        await m.detectHorizon()
        XCTAssertEqual(runs, 1)
    }

    /// D22: Done is enabled on a re-edit only after a change; a new pick is always savable.
    func testHasChanges() {
        let stored = model(isNewPick: false, framing: CoverFraming(scale: 2, rotation: 0, offsetX: 0, offsetY: 0),
                           save: { _, _, _ in self.ok })
        XCTAssertFalse(stored.hasChanges)
        stored.updateGesture(magnification: 1.2, rotationDegrees: 0, translation: .zero)
        stored.endGesture()
        XCTAssertTrue(stored.hasChanges)

        let changes: [@MainActor (EditGroupCoverModel) -> Void] = [{ $0.flip() }, { $0.rotate90() }]
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
        m.updateGesture(magnification: 1.1, rotationDegrees: -12.4, translation: .zero)
        XCTAssertTrue(m.isTwisting)
        XCTAssertEqual(m.readoutDegrees, -12)
        m.endGesture()
        XCTAssertFalse(m.isGestureActive)
        XCTAssertFalse(m.isTwisting)
    }

    /// D13: the controls are off while saving, like the gestures.
    func testFlipRotateAutoAreIgnoredWhileSaving() async {
        var release: CheckedContinuation<Void, Never>?
        let m = model(horizon: 10, save: { _, _, _ in
            await withCheckedContinuation { release = $0 }
            return self.ok
        })
        await m.detectHorizon()
        async let first = m.save()
        while release == nil { await Task.yield() }
        m.flip(); m.rotate90(); m.auto()
        XCTAssertEqual(m.framing, .identity)
        release?.resume()
        _ = await first
    }

    /// D25: Done mid-gesture saves the settled framing (an over-pan is not a legal framing).
    func testSaveSendsASettledFraming() async {
        var sent: CoverFraming?
        let m = model(save: { _, f, _ in sent = f; return self.ok })
        m.updateGesture(magnification: 0.5, rotationDegrees: 0, translation: CGSize(width: 200, height: 0))
        _ = await m.save()
        XCTAssertEqual(sent?.scale, 1)
        XCTAssertEqual(sent?.offsetX ?? 1, 0, accuracy: 1e-6)
    }

    /// D13: a new pick sends the original; a re-edit of a stored original does not.
    func testSaveSendsTheOriginalOnlyForANewPick() async {
        var originals: [Bool] = []
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult = { _, _, o in originals.append(o != nil); return self.ok }
        _ = await model(isNewPick: true, save: save).save()
        _ = await model(isNewPick: false, save: save).save()
        XCTAssertEqual(originals, [true, false])
    }

    /// D7: the first edit of a no-original cover uses the cover as the original, so Save must store it as one.
    func testSaveSendsTheOriginalWhenTheGroupHasNoStoredOne() async {
        var originals: [Bool] = []
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult = { _, _, o in originals.append(o != nil); return self.ok }
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
        m.updateGesture(magnification: 1, rotationDegrees: 2, translation: .zero)   // live, un-snapped
        async let first = m.save()
        while release == nil { await Task.yield() }
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 2, accuracy: 1e-9)    // not snapped to 0 mid-save
        release?.resume()
        _ = await first
    }

    /// D13: success seeds the cache under the new URL so the cover does not flash the placeholder.
    func testSuccessSeedsTheImageCache() async {
        let url = "https://img/seed-\(UUID().uuidString).jpeg"
        let m = model(save: { _, _, _ in CoverSaveResult(coverImageUrl: url, coverOriginalUrl: nil, coverFraming: nil) })
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

    /// D7: the original at its framing; no original -> the cover at identity; no cover -> nil.
    func testOpening() {
        func group(cover: String?, original: String?, framing: CoverFraming?) -> UserGroup {
            UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original, coverFraming: framing,
                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
        }
        let f = CoverFraming(scale: 3, rotation: 10, offsetX: 0, offsetY: 0)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: f))?.url, "o")
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: f))?.hasOriginal, true)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: f))?.framing, f)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: nil))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: nil, framing: f))?.url, "c")
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: nil, framing: f))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: nil, framing: f))?.hasOriginal, false)
        XCTAssertNil(EditGroupCoverModel.opening(group: group(cover: nil, original: nil, framing: nil)))
    }
}
