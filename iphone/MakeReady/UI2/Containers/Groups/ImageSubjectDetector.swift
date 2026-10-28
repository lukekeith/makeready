import CoreGraphics
import UIKit
import Vision

/// image-framing-editor D17: what Auto frames on — a box in the upright image's unit space (0…1,
/// top-left origin, the image's own axes before any flip or turn).
struct ImageSubject: Equatable {
    enum Kind: Equatable { case faces, salient }
    let kind: Kind
    let box: CGRect
}

/// image-framing-editor D17: on-device Vision — the union of the faces when there are any, else the
/// union of the attention-salient regions, else nothing (Auto then centres at the floor).
enum ImageSubjectDetector {
    static func detect(in image: UIImage) async -> ImageSubject? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            let faces = VNDetectFaceRectanglesRequest()
            let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
            do {
                try handler.perform([faces, saliency])
            } catch {
                // Silent: Auto with nothing found still centres the image — a Vision failure is that case.
                Log.media.error("auto-frame detection failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            if let box = topLeftUnion((faces.results ?? []).map(\.boundingBox)) {
                return ImageSubject(kind: .faces, box: box)
            }
            let salient = (saliency.results?.first?.salientObjects ?? []).map(\.boundingBox)
            return topLeftUnion(salient).map { ImageSubject(kind: .salient, box: $0) }
        }.value
    }

    /// Vision's normalised boxes are bottom-left-origin; one top-left box around them all, or nil.
    static func topLeftUnion(_ boxes: [CGRect]) -> CGRect? {
        guard let first = boxes.first else { return nil }
        let union = boxes.dropFirst().reduce(first) { $0.union($1) }
        return CGRect(x: union.minX, y: 1 - union.maxY, width: union.width, height: union.height)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
