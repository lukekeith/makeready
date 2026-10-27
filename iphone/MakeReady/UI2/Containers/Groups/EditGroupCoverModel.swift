import Observation
import UIKit

/// group-cover-image §iphone Edit cover: where the page opens from (D1/D2 → D6/D7).
enum CoverEditSource: Hashable {
    /// D6: a photo just picked, already upright and ≤ 2400px (D3).
    case newPick(UIImage)
    /// D7: the stored original (or the cover itself) at its stored framing.
    case stored
}

/// group-cover-image D5/D6/D7/D13: the Edit cover page's state. Gestures accumulate on a committed
/// base (pinch × scale, rotate + degrees, pan + points) and every change is clamped (D5); release
/// snaps the rotation. Save renders what the frame shows (D12) and maps the result to an outcome
/// the container routes.
@MainActor
@Observable
final class EditGroupCoverModel {
    enum SaveOutcome: Equatable { case saved, ignored, unauthorized, gone, failed(String) }

    static let saveFailedMessage = "Couldn't save the cover"

    let groupId: String
    let image: UIImage
    let isNewPick: Bool
    let frameSize: CGSize
    private(set) var framing: CoverFraming
    private(set) var isSaving = false
    private var base: CoverFraming
    /// D7: false when the group has no stored original, so `image` IS the cover and Save stores it as one.
    @ObservationIgnored private let hasStoredOriginal: Bool
    @ObservationIgnored private let send: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult

    init(groupId: String, image: UIImage, framing: CoverFraming, isNewPick: Bool, hasStoredOriginal: Bool = true,
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
        self.send = save
    }

    /// D5: pinch, rotate and pan together, relative to the committed base. Ignored while saving.
    func updateGesture(magnification: CGFloat, rotationDegrees: Double, translation: CGSize) {
        guard !isSaving else { return }
        var next = base
        next.scale = base.scale * Double(magnification)
        next.rotation = base.rotation + rotationDegrees
        next.offsetX = base.offsetX + Double(translation.width / frameSize.width)
        next.offsetY = base.offsetY + Double(translation.height / frameSize.height)
        framing = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
    }

    /// D5: release — snap within ±3°, re-clamp (the floor changes with rotation), commit.
    func endGesture() {
        var next = framing
        next.rotation = CoverFramingMath.snapped(rotationDegrees: next.rotation)
        framing = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
        base = framing
    }

    /// D13: one save at a time; success seeds Ui2ImageCache under the new URL.
    func save() async -> SaveOutcome {
        guard !isSaving else { return .ignored }
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
    static func opening(group: UserGroup) -> (url: String, framing: CoverFraming)? {
        if let original = group.coverOriginalUrl, !original.isEmpty {
            return (original, group.coverFraming ?? .identity)
        }
        if let cover = group.coverImageUrl, !cover.isEmpty { return (cover, .identity) }
        return nil
    }
}
