import CoreGraphics
import Foundation

/// group-cover-image D5/D11/D20/D21/D25: the Edit cover geometry, pure. Frame and image sizes are in
/// points; rotation in degrees; the image is centred on the frame centre plus `imageCenter`.
///
/// The image is drawn flipped (a mirror moves no edge), then turned by `quarterTurns` (odd turns swap
/// its width and height — the "turned" size), then rotated by the fine `rotation`. Coverage: the
/// frame, mapped into the turned image's own axes, has half-extents
/// `ex = (w|cos θ| + h|sin θ|)/2`, `ey = (w|sin θ| + h|cos θ|)/2`. The frame centre, in the same
/// axes, must stay within `(s·iw/2 − ex, s·ih/2 − ey)` of the image centre.
enum CoverFramingMath {
    /// D20: the cover's aspect, 16:9.
    static let frameAspect: CGFloat = 16.0 / 9.0
    /// D5: the zoom ceiling, relative to the floor.
    static let maxRelativeScale: Double = 8
    /// D5: rotation snaps to 0° when released within this.
    static let snapDegrees: Double = 3
    /// D21: the fine rotation's range, either side of 0 (quarter turns carry the rest).
    static let maxRotation: Double = 45
    /// D25: how far the image moves per point dragged past the coverage limit.
    static let rubberBandFactor: CGFloat = 0.3

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

    /// D21: quarter turns into 0…3.
    static func normalized(quarterTurns: Int) -> Int {
        ((quarterTurns % 4) + 4) % 4
    }

    /// D21: the image's bounding size after its quarter turns — odd turns swap width and height.
    static func turnedSize(_ image: CGSize, quarterTurns: Int) -> CGSize {
        quarterTurns % 2 == 0 ? image : CGSize(width: image.height, height: image.width)
    }

    /// D25: displacement past the coverage limit, damped.
    static func rubberBand(_ excess: CGFloat) -> CGFloat {
        excess * rubberBandFactor
    }

    /// D21/D22: Flip mirrors the whole framed view about the frame's vertical centre line: the mirror
    /// toggles and the x offset, the fine rotation and the quarter turns change sign. Coverage is
    /// symmetric, so a covering framing stays covering.
    static func flippedHorizontally(_ framing: CoverFraming) -> CoverFraming {
        var f = framing
        f.flipped.toggle()
        f.offsetX = -framing.offsetX
        f.rotation = -framing.rotation
        f.quarterTurns = normalized(quarterTurns: -framing.quarterTurns)
        return f
    }

    /// D5/D25: a gesture's release — the fine rotation snaps within ±3°, then the framing is pulled
    /// back to the nearest one that covers the frame.
    static func settle(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CoverFraming {
        var f = framing
        f.rotation = snapped(rotationDegrees: f.rotation)
        return clamped(f, image: image, frame: frame)
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

    /// The drawn scale for `image` (its upright size): `scale` times the floor of its turned size.
    static func absoluteScale(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CGFloat {
        let turned = turnedSize(image, quarterTurns: normalized(quarterTurns: framing.quarterTurns))
        return CGFloat(framing.scale) * zoomFloor(image: turned, frame: frame, rotationDegrees: framing.rotation)
    }

    static func imageCenter(_ framing: CoverFraming, frame: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(framing.offsetX) * frame.width, y: CGFloat(framing.offsetY) * frame.height)
    }

    /// D11: the frozen contract range for an offset (the server 400s outside it).
    static let maxOffset: Double = 1

    /// D5/D11/D21: scale into 1…8, rotation into −45…45, quarter turns into 0…3, offsets into −1…1,
    /// and the offset pulled back (in the turned image's axes) until the frame is covered. A legal
    /// framing comes back unchanged; a non-finite one comes back as identity (D11 requires finite
    /// values; there is nothing to clamp to).
    static func clamped(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CoverFraming {
        guard framing.scale.isFinite, framing.rotation.isFinite,
              framing.offsetX.isFinite, framing.offsetY.isFinite else { return .identity }
        var f = framing
        f.scale = min(max(f.scale, 1), maxRelativeScale)
        f.rotation = min(max(normalized(degrees: f.rotation), -maxRotation), maxRotation)
        f.quarterTurns = normalized(quarterTurns: f.quarterTurns)
        f.offsetX = min(max(f.offsetX, -maxOffset), maxOffset)
        f.offsetY = min(max(f.offsetY, -maxOffset), maxOffset)
        guard frame.width > 0, frame.height > 0 else { return f }

        let t = f.rotation * .pi / 180
        let s = absoluteScale(f, image: image, frame: frame)
        let turned = turnedSize(image, quarterTurns: f.quarterTurns)
        let (ex, ey) = halfExtents(frame: frame, radians: t)
        let maxU = max(0, s * turned.width / 2 - ex)
        let maxV = max(0, s * turned.height / 2 - ey)

        // The frame centre relative to the image centre is −p; into the turned image's axes by R(−θ).
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
