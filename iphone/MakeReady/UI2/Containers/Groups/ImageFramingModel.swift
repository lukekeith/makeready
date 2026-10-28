import Observation
import UIKit

/// image-framing-editor D1 (group-cover-image §iphone Edit cover): where the framing editor opens from.
enum ImageEditSource: Hashable {
    /// A photo just picked, already upright and ≤ 2400px (group-cover-image D3/D6, image-framing-editor D7).
    case newPick(UIImage)
    /// The stored original (or the image itself) at its stored framing (group-cover-image D7, image-framing-editor D5).
    case stored
}

/// image-framing-editor D1: one framing editor's state for every framed image (today the group cover
/// at 16:9 and the member avatar at 1:1) — group-cover-image D5/D6/D7/D13/D20–D26 unchanged. The
/// frame's size (so its aspect), the output pixel size and the failure text are inputs; each image
/// kind supplies its own save, which returns the new rendered URL. Gestures accumulate on a
/// committed base (pinch × scale, rotate + degrees, pan + points); while one is active the image may
/// go past the coverage limit with rubber-band resistance, and release settles it — the ±3° snap,
/// then the nearest covering framing (D25). Flip and Rotate 90° commit at once, re-applying the
/// floor. Save renders what the frame shows at `outputSize` and maps the result to an outcome the container routes.
@MainActor
@Observable
final class ImageFramingModel {
    /// image-framing-editor D12: `.forbidden` is a 403 — each container routes it (the group cover keeps its banner).
    enum SaveOutcome: Equatable { case saved, ignored, unauthorized, forbidden, gone, failed(String) }

    /// D24: a rotation this small is the jitter of a pinch, not a twist — the readout stays hidden.
    static let twistThreshold: Double = 1

    let image: UIImage
    let isNewPick: Bool
    let frameSize: CGSize
    /// image-framing-editor D1: the rendered image's pixel size (group cover 1200×675, avatar 512×512).
    let outputSize: CGSize
    /// image-framing-editor D1: the banner text the container shows when a save fails.
    let saveFailedMessage: String
    private(set) var framing: ImageFraming
    private(set) var isSaving = false
    /// D30: any gesture (twist or dial) is in progress — the rule-of-thirds grid shows.
    private(set) var isGestureActive = false
    /// D30: the current gesture has twisted (or the dial is turning) at least `twistThreshold` — the degree readout shows.
    private(set) var isTwisting = false
    private var base: ImageFraming
    /// D22: the framing the page opened at; a re-edit is savable only once it differs.
    @ObservationIgnored private let opened: ImageFraming
    /// D7: false when there is no stored original, so `image` IS the current image and Save stores it as one.
    @ObservationIgnored private let hasStoredOriginal: Bool
    @ObservationIgnored private let send: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String

    init(image: UIImage, framing: ImageFraming, isNewPick: Bool, hasStoredOriginal: Bool,
         frameSize: CGSize, outputSize: CGSize, saveFailedMessage: String,
         save: @escaping @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String) {
        self.image = image
        self.isNewPick = isNewPick
        self.hasStoredOriginal = hasStoredOriginal
        self.frameSize = frameSize
        self.outputSize = outputSize
        self.saveFailedMessage = saveFailedMessage
        let start = ImageFramingMath.clamped(framing, image: image.size, frame: frameSize)
        self.framing = start
        self.base = start
        self.opened = start
        self.send = save
    }

    /// D22: Done is enabled for a new pick, or once a re-edit's framing has changed.
    var hasChanges: Bool { isNewPick || framing != opened }

    /// D30: the fine rotation as the readout shows it ("-12°").
    var readoutDegrees: Int { Int(framing.rotation.rounded()) }

    /// D5/D25: pinch, rotate and pan together, relative to the committed base. Past the coverage
    /// limit (a pan, or a pinch below the floor) the excess moves at 0.3; the ceiling and the ±45°
    /// twist are hard stops. Ignored while saving.
    func updateGesture(magnification: CGFloat, rotationDegrees: Double, translation: CGSize) {
        guard !isSaving else { return }
        isGestureActive = true
        if abs(rotationDegrees) >= Self.twistThreshold { isTwisting = true }
        var next = base
        next.scale = base.scale * Double(magnification)
        // D21: the raw sum stops at ±45° before `clamped` normalises — past 180° it must not wrap to the other stop.
        let maxRotation = ImageFramingMath.maxRotation
        next.rotation = min(max(base.rotation + rotationDegrees, -maxRotation), maxRotation)
        next.offsetX = base.offsetX + Double(translation.width / frameSize.width)
        next.offsetY = base.offsetY + Double(translation.height / frameSize.height)
        framing = liveFraming(next)
    }

    /// D30: the straighten dial sets the fine rotation absolutely (−45…45), keeping the committed
    /// base's scale and offsets, through the same live clamp and rubber band as a twist. Ignored while saving.
    func straighten(to degrees: Double) {
        guard !isSaving else { return }
        isGestureActive = true
        isTwisting = true
        var next = base
        let maxRotation = ImageFramingMath.maxRotation
        next.rotation = min(max(degrees, -maxRotation), maxRotation)
        framing = liveFraming(next)
    }

    /// D5/D25: release — snap within ±3°, spring back to the nearest covering framing, commit.
    func endGesture() {
        guard !isSaving else { return }
        framing = ImageFramingMath.settle(framing, image: image.size, frame: frameSize)
        base = framing
        isGestureActive = false
        isTwisting = false
    }

    /// D30: the dial's release is the twist's release — snap, settle, commit.
    func endStraighten() {
        endGesture()
    }

    /// D21/D22: mirror the framed view horizontally.
    func flip() {
        commit(ImageFramingMath.flippedHorizontally(framing))
    }

    /// D21/D22: turn the framed view a quarter counter-clockwise — the image's quarter turns step and
    /// its pan turns with it, (x, y) points → (y, −x); the floor follows the turned size.
    func rotate90() {
        var next = framing
        next.quarterTurns = (ImageFramingMath.normalized(quarterTurns: next.quarterTurns) + 1) % 4
        let w = Double(frameSize.width), h = Double(frameSize.height)
        if w > 0, h > 0 {
            next.offsetX = framing.offsetY * h / w
            next.offsetY = -framing.offsetX * w / h
        }
        commit(next)
    }

    /// D25: Flip and Rotate 90° re-apply the floor at once. Ignored while saving (D13).
    private func commit(_ next: ImageFraming) {
        guard !isSaving else { return }
        framing = ImageFramingMath.clamped(next, image: image.size, frame: frameSize)
        base = framing
    }

    /// D25: `next` clamped to coverage, then displaced back out by the rubber band (× 0.3 past the limit).
    private func liveFraming(_ next: ImageFraming) -> ImageFraming {
        let limit = ImageFramingMath.clamped(next, image: image.size, frame: frameSize)
        var live = limit
        if next.scale < limit.scale { live.scale = limit.scale + band(next.scale - limit.scale) }
        live.offsetX = limit.offsetX + band(next.offsetX - limit.offsetX)
        live.offsetY = limit.offsetY + band(next.offsetY - limit.offsetY)
        return live
    }

    private func band(_ excess: Double) -> Double {
        Double(ImageFramingMath.rubberBand(CGFloat(excess)))
    }

    /// D13: one save at a time; success seeds Ui2ImageCache under the new URL.
    func save() async -> SaveOutcome {
        guard !isSaving else { return .ignored }
        // D5/D25: Done mid-gesture saves what release would settle to — snapped and covered.
        framing = ImageFramingMath.settle(framing, image: image.size, frame: frameSize)
        base = framing
        isGestureActive = false
        isTwisting = false
        isSaving = true
        defer { isSaving = false }
        let rendered = CoverImageRendering.render(image, framing: framing, size: outputSize)
        do {
            let original = (isNewPick || !hasStoredOriginal) ? image : nil
            let url = try await send(rendered, framing, original)
            if let seeded = URL(string: url) { Ui2ImageCache.shared.seed(rendered, for: seeded) }
            return .saved
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { return .unauthorized }
            if let http = error as? APIHTTPError, http.status == 403 { return .forbidden }
            if let http = error as? APIHTTPError, http.status == 404 { return .gone }
            return .failed(error.localizedDescription)
        }
    }
}
