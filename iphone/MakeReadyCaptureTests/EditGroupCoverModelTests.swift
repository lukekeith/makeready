import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D5/D6/D7/D13: the Edit cover page's state, without the view.
@MainActor
final class EditGroupCoverModelTests: XCTestCase {
    private let frame = CGSize(width: 408, height: 180)
    private func image(_ size: CGSize = CGSize(width: 2400, height: 1600)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    private let ok = CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: "https://img/o.jpeg", coverFraming: .identity)

    private func model(isNewPick: Bool = true, hasStoredOriginal: Bool = true, framing: CoverFraming = .identity,
                       save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult) -> EditGroupCoverModel {
        EditGroupCoverModel(groupId: "g1", image: image(), framing: framing, isNewPick: isNewPick,
                            hasStoredOriginal: hasStoredOriginal, frameSize: frame, save: save)
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

    func testZoomIsClampedToTheFloorAndTheCeiling() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 0.2, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 1)
        m.updateGesture(magnification: 50, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 8)
    }

    func testPanIsClamped() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 0, translation: CGSize(width: 5000, height: 0))
        XCTAssertEqual(m.framing.offsetX, 0, accuracy: 1e-6)    // no horizontal slack at the floor for a wide image
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

    func testSaveRendersAt1200x529() async {
        var size: CGSize?
        _ = await model(save: { r, _, _ in size = CGSize(width: r.cgImage!.width, height: r.cgImage!.height); return self.ok }).save()
        XCTAssertEqual(size, CGSize(width: 1200, height: 529))
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
