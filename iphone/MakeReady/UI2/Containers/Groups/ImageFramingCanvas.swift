import SwiftUI

/// image-framing-editor D1 (group-cover-image D5/D25/D30): the framed image and its three
/// simultaneous gestures, placed in the edit screen's canvas slot for any framed image. It fills the
/// whole canvas area, clipped to that slot but not to `frame` (the screen dims what lies outside
/// `frame`), and draws the image as `CoverImageRendering` renders it — mirrored, turned, rotated,
/// scaled, offset — against `frame`. The model clamps every change; release springs back to coverage (D25).
struct ImageFramingCanvas: View {
    let model: ImageFramingModel
    /// The screen's frame rect, in this view's coordinates.
    let frame: CGRect
    /// image-framing-editor D1: the caller's label ("Cover framing", "Photo framing").
    let accessibilityLabel: String

    /// D25: the spring back to the nearest covering framing on release.
    static let settle = Animation.spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        let f = model.framing
        let scale = ImageFramingMath.absoluteScale(f, image: model.image.size, frame: frame.size)
        let center = ImageFramingMath.imageCenter(f, frame: frame.size)
        ZStack(alignment: .topLeading) {
            Color.clear
            Image(uiImage: model.image)
                .resizable()
                .frame(width: model.image.size.width * scale, height: model.image.size.height * scale)
                .scaleEffect(x: f.flipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(-90 * Double(f.quarterTurns)))   // D21: counter-clockwise turns
                .rotationEffect(.degrees(f.rotation))
                .position(x: frame.midX + center.x, y: frame.midY + center.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // D30: clipped to the canvas slot, not the frame — the screen dims the overflow inside the
        // slot, and nothing paints over the header or the toolbar.
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                SimultaneousGesture(MagnifyGesture(), RotateGesture()),
                // pan-ok: the canvas move pans the image in any direction, not a sideways scroll.
                DragGesture(minimumDistance: 0)
            )
            .onChanged { value in
                model.updateGesture(magnification: value.first?.first?.magnification ?? 1,
                                    rotationDegrees: value.first?.second?.rotation.degrees ?? 0,
                                    translation: value.second?.translation ?? .zero)
            }
            .onEnded { _ in
                withAnimation(Self.settle) { model.endGesture() }
            }
        )
        .allowsHitTesting(!model.isSaving)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Pinch to zoom, rotate with two fingers, drag to move")
    }
}
