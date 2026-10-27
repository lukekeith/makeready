import CoreGraphics
import Foundation

/// group-cover-image D5/D11: the Edit cover geometry, pure. Frame and image sizes are in points;
/// rotation in degrees; the image is centred on the frame centre plus `imageCenter`.
///
/// Coverage: the frame, mapped into the image's own (unrotated) axes, has half-extents
/// `ex = (w|cos θ| + h|sin θ|)/2`, `ey = (w|sin θ| + h|cos θ|)/2`. The frame centre, in the same
/// axes, must stay within `(s·iw/2 − ex, s·ih/2 − ey)` of the image centre.
enum CoverFramingMath {
    /// D5: the cover's aspect, 408:180.
    static let frameAspect: CGFloat = 408.0 / 180.0
    /// D5: the zoom ceiling, relative to the floor.
    static let maxRelativeScale: Double = 8
    /// D5: rotation snaps to 0° when released within this.
    static let snapDegrees: Double = 3

    static func normalized(degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    static func snapped(rotationDegrees: Double) -> Double {
        let d = normalized(degrees: rotationDegrees)
        return abs(d) <= snapDegrees ? 0 : d
    }

    private static func halfExtents(frame: CGSize, radians t: Double) -> (CGFloat, CGFloat) {
        let c = CGFloat(abs(cos(t))), s = CGFloat(abs(sin(t)))
        return ((frame.width * c + frame.height * s) / 2, (frame.width * s + frame.height * c) / 2)
    }

    /// D5: the smallest absolute scale at which the image, rotated, covers the frame. A zero-size
    /// image has no meaningful floor; it reads as 1 so callers never divide by zero.
    static func zoomFloor(image: CGSize, frame: CGSize, rotationDegrees: Double) -> CGFloat {
        guard image.width > 0, image.height > 0 else { return 1 }
        let (ex, ey) = halfExtents(frame: frame, radians: rotationDegrees * .pi / 180)
        return max(2 * ex / image.width, 2 * ey / image.height)
    }

    static func absoluteScale(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CGFloat {
        CGFloat(framing.scale) * zoomFloor(image: image, frame: frame, rotationDegrees: framing.rotation)
    }

    static func imageCenter(_ framing: CoverFraming, frame: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(framing.offsetX) * frame.width, y: CGFloat(framing.offsetY) * frame.height)
    }

    /// D11: the frozen contract range for an offset (the server 400s outside it).
    static let maxOffset: Double = 1

    /// D5/D11: scale into 1…8, rotation into −180…180, offsets into −1…1, and the offset pulled back
    /// (in the image's axes) until the frame is covered. A legal framing comes back unchanged, and a
    /// non-finite one comes back as given (D11 requires finite values; there is nothing to clamp to).
    static func clamped(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CoverFraming {
        guard framing.scale.isFinite, framing.rotation.isFinite,
              framing.offsetX.isFinite, framing.offsetY.isFinite else { return framing }
        var f = framing
        f.scale = min(max(f.scale, 1), maxRelativeScale)
        f.rotation = normalized(degrees: f.rotation)
        f.offsetX = min(max(f.offsetX, -maxOffset), maxOffset)
        f.offsetY = min(max(f.offsetY, -maxOffset), maxOffset)
        guard frame.width > 0, frame.height > 0 else { return f }

        let t = f.rotation * .pi / 180
        let s = absoluteScale(f, image: image, frame: frame)
        let (ex, ey) = halfExtents(frame: frame, radians: t)
        let maxU = max(0, s * image.width / 2 - ex)
        let maxV = max(0, s * image.height / 2 - ey)

        // The frame centre relative to the image centre is −p; into image axes by R(−θ).
        let p = imageCenter(f, frame: frame)
        let ct = CGFloat(cos(t)), st = CGFloat(sin(t))
        let u = -p.x * ct - p.y * st
        let v = p.x * st - p.y * ct
        guard abs(u) > maxU || abs(v) > maxV else { return f }

        // Pull back to the covered rectangle, per image axis, then back to frame axes.
        let cu = min(max(u, -maxU), maxU)
        let cv = min(max(v, -maxV), maxV)
        let px = -(cu * ct - cv * st) / frame.width
        let py = -(cu * st + cv * ct) / frame.height
        if abs(px) <= maxOffset, abs(py) <= maxOffset {
            f.offsetX = Double(px)
            f.offsetY = Double(py)
            return f
        }
        // Rotation can swing a pulled-back component past ±1. The covered rectangle and the ±1 box
        // both contain the centre (scale ≥ floor), so shrinking the box-clamped offset toward the
        // centre only helps coverage: take the largest shrink that is still covered.
        let k = min(1, maxU / max(abs(u), .leastNonzeroMagnitude), maxV / max(abs(v), .leastNonzeroMagnitude))
        f.offsetX = Double(p.x * k / frame.width)
        f.offsetY = Double(p.y * k / frame.height)
        return f
    }
}
