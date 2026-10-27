import Observation
import UIKit

/// group-cover-image §iphone Edit cover: where the page opens from (D1/D2 → D6/D7).
enum CoverEditSource: Hashable {
    /// D6: a photo just picked, already upright and ≤ 2400px (D3).
    case newPick(UIImage)
    /// D7: the stored original (or the cover itself) at its stored framing.
    case stored
}

/// group-cover-image D5/D6/D7/D13/D20–D26: the Edit cover page's state. Gestures accumulate on a
/// committed base (pinch × scale, rotate + degrees, pan + points); while one is active the image may
/// go past the coverage limit with rubber-band resistance, and release settles it — the ±3° snap,
/// then the nearest covering framing (D25). Flip and Rotate 90° commit at once, re-applying the
/// floor. Save renders what the frame shows (D12) and maps the result to an outcome the container routes.
@MainActor
@Observable
final class EditGroupCoverModel {
    enum SaveOutcome: Equatable { case saved, ignored, unauthorized, gone, failed(String) }

    static let saveFailedMessage = "Couldn't save the cover"
    /// D24: a rotation this small is the jitter of a pinch, not a twist — the readout stays hidden.
    static let twistThreshold: Double = 1

    let groupId: String
    let image: UIImage
    let isNewPick: Bool
    let frameSize: CGSize
    private(set) var framing: CoverFraming
    private(set) var isSaving = false
    /// D30: any gesture (twist or dial) is in progress — the rule-of-thirds grid shows.
    private(set) var isGestureActive = false
    /// D30: the current gesture has twisted (or the dial is turning) at least `twistThreshold` — the degree readout shows.
    private(set) var isTwisting = false
    private var base: CoverFraming
    /// D22: the framing the page opened at; a re-edit is savable only once it differs.
    @ObservationIgnored private let opened: CoverFraming
    /// D7: false when the group has no stored original, so `image` IS the cover and Save stores it as one.
    @ObservationIgnored private let hasStoredOriginal: Bool
    @ObservationIgnored private let send: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult

    init(groupId: String, image: UIImage, framing: CoverFraming, isNewPick: Bool, hasStoredOriginal: Bool,
         frameSize: CGSize,
         save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult) {
        self.groupId = groupId
        self.image = image
        self.isNewPick = isNewPick
        self.hasStoredOriginal = hasStoredOriginal
        self.frameSize = frameSize
        let start = CoverFramingMath.clamped(framing, image: image.size, frame: frameSize)
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
        let maxRotation = CoverFramingMath.maxRotation
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
        let maxRotation = CoverFramingMath.maxRotation
        next.rotation = min(max(degrees, -maxRotation), maxRotation)
        framing = liveFraming(next)
    }

    /// D5/D25: release — snap within ±3°, spring back to the nearest covering framing, commit.
    func endGesture() {
        guard !isSaving else { return }
        framing = CoverFramingMath.settle(framing, image: image.size, frame: frameSize)
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
        commit(CoverFramingMath.flippedHorizontally(framing))
    }

    /// D21/D22: turn the framed view a quarter counter-clockwise — the image's quarter turns step and
    /// its pan turns with it, (x, y) points → (y, −x); the floor follows the turned size.
    func rotate90() {
        var next = framing
        next.quarterTurns = (CoverFramingMath.normalized(quarterTurns: next.quarterTurns) + 1) % 4
        let w = Double(frameSize.width), h = Double(frameSize.height)
        if w > 0, h > 0 {
            next.offsetX = framing.offsetY * h / w
            next.offsetY = -framing.offsetX * w / h
        }
        commit(next)
    }

    /// D25: Flip and Rotate 90° re-apply the floor at once. Ignored while saving (D13).
    private func commit(_ next: CoverFraming) {
        guard !isSaving else { return }
        framing = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
        base = framing
    }

    /// D25: `next` clamped to coverage, then displaced back out by the rubber band (× 0.3 past the limit).
    private func liveFraming(_ next: CoverFraming) -> CoverFraming {
        let limit = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
        var live = limit
        if next.scale < limit.scale { live.scale = limit.scale + band(next.scale - limit.scale) }
        live.offsetX = limit.offsetX + band(next.offsetX - limit.offsetX)
        live.offsetY = limit.offsetY + band(next.offsetY - limit.offsetY)
        return live
    }

    private func band(_ excess: Double) -> Double {
        Double(CoverFramingMath.rubberBand(CGFloat(excess)))
    }

    /// D13: one save at a time; success seeds Ui2ImageCache under the new URL.
    func save() async -> SaveOutcome {
        guard !isSaving else { return .ignored }
        // D5/D25: Done mid-gesture saves what release would settle to — snapped and covered.
        framing = CoverFramingMath.settle(framing, image: image.size, frame: frameSize)
        base = framing
        isGestureActive = false
        isTwisting = false
        isSaving = true
        defer { isSaving = false }
        let rendered = CoverImageRendering.render(image, framing: framing)
        do {
            let original = (isNewPick || !hasStoredOriginal) ? image : nil
            let result = try await send(rendered, framing, original)
            if let url = URL(string: result.coverImageUrl) { Ui2ImageCache.shared.seed(rendered, for: url) }
            return .saved
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { return .unauthorized }
            if let http = error as? APIHTTPError, http.status == 404 { return .gone }
            return .failed(error.localizedDescription)
        }
    }

    /// D7: Edit image reopens the original at its framing; a cover with no original opens the
    /// cover itself at identity; no cover → nil (the menu is not offered then, D2).
    /// `hasOriginal` is false for the cover fallback: the caller passes it on as `hasStoredOriginal`.
    static func opening(group: UserGroup) -> (url: String, framing: CoverFraming, hasOriginal: Bool)? {
        if let original = group.coverOriginalUrl, !original.isEmpty {
            return (original, group.coverFraming ?? .identity, true)
        }
        if let cover = group.coverImageUrl, !cover.isEmpty { return (cover, .identity, false) }
        return nil
    }
}
