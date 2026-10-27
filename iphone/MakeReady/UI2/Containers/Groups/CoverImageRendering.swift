import ImageIO
import UIKit

/// group-cover-image D12: the phone renders exactly what the Edit cover frame shows; D3: a pick is
/// made upright and ≤ 2400px before Edit cover opens (memory, and D16's body size).
enum CoverImageRendering {
    /// D12/D20: 16:9 at 1200 wide.
    static let renderSize = CGSize(width: 1200, height: 675)
    /// D3 / D10: the original's longest side.
    static let originalMaxPixels: CGFloat = 2400

    /// D12/D21: the framed image at `renderSize`, scale 1, opaque — the image flipped, then turned
    /// counter-clockwise by its quarter turns, then rotated by the fine angle, then scaled and offset.
    /// `UIImage.draw(in:)` applies the image's orientation (`APIClient.resizeImageIfNeeded` does not).
    static func render(_ image: UIImage, framing: CoverFraming) -> UIImage {
        let frame = renderSize
        let f = CoverFramingMath.clamped(framing, image: image.size, frame: frame)
        let scale = CoverFramingMath.absoluteScale(f, image: image.size, frame: frame)
        let center = CoverFramingMath.imageCenter(f, frame: frame)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: frame, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: frame.width / 2 + center.x, y: frame.height / 2 + center.y)
            cg.rotate(by: CGFloat(f.rotation * .pi / 180))
            // Context transforms apply to the drawing innermost-last: this turn acts before the fine
            // rotation, and the mirror below before the turn. Negative = counter-clockwise (y down).
            cg.rotate(by: -CGFloat(f.quarterTurns) * .pi / 2)
            if f.flipped { cg.scaleBy(x: -1, y: 1) }
            let w = image.size.width * scale, h = image.size.height * scale
            image.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
    }

    /// D3: decode with the EXIF transform applied, longest side ≤ `maxPixels`, never enlarged.
    static func uprightDownsampled(_ data: Data, maxPixels: CGFloat = originalMaxPixels) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
        guard w > 0, h > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixels, max(w, h))
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
