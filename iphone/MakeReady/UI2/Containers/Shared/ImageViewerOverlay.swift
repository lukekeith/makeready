import SwiftUI
import UIKit

/// image-viewer-zoom-dismiss (owner 2026-10-28; reference docs/ui2/references/image-viewer-zoom-dismiss.md):
/// one image full screen — pinch / double-tap zoom with pan, and Photos' drag-to-dismiss: the image
/// follows the finger, shrinks as it goes down while the page shows through, and on release flies
/// back into the frame it opened from (or back to rest). Reused by the cover viewer now and the
/// media library later. Build-made: no d2m design; its chrome is one close control.
struct ImageViewerOverlay: View {
    let url: String
    /// Where the image opens from and flies back to, in GLOBAL coordinates; nil = no source (the
    /// image grows in place and leaves off the bottom).
    let sourceFrame: CGRect?
    let accessibilityLabel: String
    let onClose: () -> Void

    @State private var image: UIImage?
    /// The flying image's frame, in this view's coordinates — used while opening and dismissing.
    @State private var flightFrame: CGRect = .zero
    @State private var backdrop: Double = 0
    /// The zoomable view is live (at rest, zooming, or being dragged); false while flying.
    @State private var zoomLive = false
    @State private var chromeVisible = true
    /// The dismiss drag's translation while the finger is down (applied to the live view).
    @State private var drag: CGSize = .zero
    /// Where the finger first touched, in this view's coordinates: the image scales about it, so
    /// the point grabbed stays under the finger (reference rule 5).
    @State private var dragAnchor: CGPoint?
    @State private var closing = false

    var body: some View {
        GeometryReader { proxy in
            let viewport = CGRect(origin: .zero, size: proxy.size)
            let origin = proxy.frame(in: .global).origin
            let fitted = image.map { ImageViewerMath.fittedFrame(imageSize: $0.size, in: viewport) } ?? viewport
            ZStack(alignment: .topLeading) {
                Token.layoutBackground.opacity(backdrop)
                if let image, zoomLive {
                    ZoomableImageView(
                        image: image,
                        accessibilityLabel: accessibilityLabel,
                        onSingleTap: { withAnimation(Token.Motion.menuFadeOut) { chromeVisible.toggle() } },
                        onDismissBegan: { start in dragAnchor = CGPoint(x: start.x - origin.x, y: start.y - origin.y) },
                        onDismissChanged: { t in dragChanged(t, height: viewport.height) },
                        onDismissEnded: { t, v in dragEnded(t, velocity: v, fitted: fitted, viewport: viewport, origin: origin) }
                    )
                    .scaleEffect(ImageViewerMath.dragScale(dy: drag.height, height: viewport.height),
                                 anchor: ImageViewerMath.unitAnchor(dragAnchor, in: viewport))
                    .offset(drag)
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: flightFrame.width, height: flightFrame.height)
                        .clipped()
                        .position(x: flightFrame.midX, y: flightFrame.midY)
                        .accessibilityLabel(accessibilityLabel)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                closeButton(fitted: fitted, viewport: viewport, origin: origin)
                    .padding(.top, proxy.safeAreaInsets.top + Token.Space.pageMargin)
                    .padding(.leading, Token.Space.pageMargin)
                    .opacity(chromeVisible && zoomLive && drag == .zero ? 1 : 0)
            }
            .task(id: url) { await open(viewport: viewport, origin: origin) }
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private func closeButton(fitted: CGRect, viewport: CGRect, origin: CGPoint) -> some View {
        IconButton(glyph: .x, tone: .default, style: .outlined, selected: false,
                   accessibilityLabel: "Close", onTap: { dismiss(fitted: fitted, viewport: viewport, origin: origin) })
    }

    // MARK: - Open (rules 1–3)

    @MainActor
    private func open(viewport: CGRect, origin: CGPoint) async {
        guard let u = URL(string: url) else { return }
        if Ui2ImageCache.shared.image(for: u) == nil { _ = await UI2ImageLoader.seed([url], context: "ImageViewerOverlay") }
        guard let loaded = Ui2ImageCache.shared.image(for: u) else { return }
        image = loaded
        let target = ImageViewerMath.fittedFrame(imageSize: loaded.size, in: viewport)
        flightFrame = ImageViewerMath.startFrame(source: sourceFrame?.offsetBy(dx: -origin.x, dy: -origin.y), fitted: target)
        withAnimation(ImageViewerMath.openSpring) {
            flightFrame = target
            backdrop = 1
        } completion: {
            zoomLive = true
        }
    }

    // MARK: - Drag to dismiss (rules 4–9)

    private func dragChanged(_ translation: CGSize, height: CGFloat) {
        drag = translation
        backdrop = ImageViewerMath.backdropOpacity(dy: translation.height, height: height)
    }

    private func dragEnded(_ translation: CGSize, velocity: CGSize, fitted: CGRect, viewport: CGRect, origin: CGPoint) {
        if ImageViewerMath.shouldDismiss(dy: translation.height, velocityY: velocity.height, height: viewport.height) {
            dismiss(fitted: fitted, viewport: viewport, origin: origin)
        } else {
            withAnimation(ImageViewerMath.openSpring) {
                drag = .zero
                backdrop = 1
            } completion: {
                dragAnchor = nil
            }
        }
    }

    /// Fly from where the image is now into the source (or off the bottom), then close.
    private func dismiss(fitted: CGRect, viewport: CGRect, origin: CGPoint) {
        guard !closing else { return }
        closing = true
        flightFrame = ImageViewerMath.draggedFrame(fitted: fitted, translation: drag,
                                                   scale: ImageViewerMath.dragScale(dy: drag.height, height: viewport.height),
                                                   anchor: dragAnchor)
        zoomLive = false
        drag = .zero
        let source = sourceFrame?.offsetBy(dx: -origin.x, dy: -origin.y)
        withAnimation(ImageViewerMath.flightSpring) {
            flightFrame = ImageViewerMath.endFrame(source: source, from: flightFrame, viewport: viewport)
            backdrop = 0
        } completion: {
            onClose()
        }
    }

    private func close() {
        // Accessibility escape: no geometry in hand, so leave at once.
        onClose()
    }
}

/// The viewer's measurements (reference §2), pure for tests.
enum ImageViewerMath {
    /// Rule 1: open ≈0.25 s, no overshoot.
    static let openSpring = Animation.spring(duration: 0.25, bounce: 0)
    /// Rule 8: the dismiss flight ≈0.15–0.2 s, no overshoot.
    static let flightSpring = Animation.spring(duration: 0.18, bounce: 0)
    /// Rule 6: the smallest the dragged image gets.
    static let minDragScale: CGFloat = 0.5
    /// Rule 7: the backdrop is gone by this fraction of the height.
    static let backdropFadeDistance: CGFloat = 0.4
    /// Rule 8: dismiss past this fraction of the height, or this downward speed (pt/s).
    static let dismissDistance: CGFloat = 0.15
    static let dismissVelocity: CGFloat = 800
    /// Rules 10–12.
    static let maxZoom: CGFloat = 4
    static let doubleTapZoom: CGFloat = 2.5

    /// Aspect-fit, centred.
    static func fittedFrame(imageSize: CGSize, in viewport: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return viewport }
        let scale = min(viewport.width / imageSize.width, viewport.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: viewport.midX - size.width / 2, y: viewport.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// Rule 6: shrinks with the downward distance only.
    static func dragScale(dy: CGFloat, height: CGFloat) -> CGFloat {
        guard height > 0 else { return 1 }
        return max(minDragScale, 1 - max(dy, 0) / height)
    }

    /// Rule 7.
    static func backdropOpacity(dy: CGFloat, height: CGFloat) -> Double {
        guard height > 0 else { return 1 }
        return Double(max(0, 1 - max(dy, 0) / (height * backdropFadeDistance)))
    }

    /// Rule 8.
    static func shouldDismiss(dy: CGFloat, velocityY: CGFloat, height: CGFloat) -> Bool {
        dy > height * dismissDistance || velocityY > dismissVelocity
    }

    /// Rule 5: the fitted frame scaled about the point the finger grabbed (its centre when there is
    /// none), then moved with the finger — so the grabbed point stays under the finger.
    static func draggedFrame(fitted: CGRect, translation: CGSize, scale: CGFloat, anchor: CGPoint? = nil) -> CGRect {
        let a = anchor ?? CGPoint(x: fitted.midX, y: fitted.midY)
        return CGRect(x: a.x + (fitted.minX - a.x) * scale + translation.width,
                      y: a.y + (fitted.minY - a.y) * scale + translation.height,
                      width: fitted.width * scale, height: fitted.height * scale)
    }

    /// The grab point as a scale anchor within the viewport (centre when there is none).
    static func unitAnchor(_ point: CGPoint?, in viewport: CGRect) -> UnitPoint {
        guard let point, viewport.width > 0, viewport.height > 0 else { return .center }
        return UnitPoint(x: (point.x - viewport.minX) / viewport.width, y: (point.y - viewport.minY) / viewport.height)
    }

    /// Rule 1 / 9: from the source, else a slightly smaller fitted frame.
    static func startFrame(source: CGRect?, fitted: CGRect) -> CGRect {
        if let source, !source.isEmpty { return source }
        return fitted.insetBy(dx: fitted.width * 0.05, dy: fitted.height * 0.05)
    }

    /// Rule 8 / 9: into the source, else on down past the bottom edge.
    static func endFrame(source: CGRect?, from current: CGRect, viewport: CGRect) -> CGRect {
        if let source, !source.isEmpty { return source }
        return current.offsetBy(dx: 0, dy: viewport.maxY - current.minY)
    }
}

/// Rules 10–14: a UIScrollView zoom (pinch about the fingers, momentum pan, bounce), double-tap to
/// zoom, single tap reported, and the dismiss pan — which only begins at 1× and vertical-first.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let accessibilityLabel: String
    var onSingleTap: () -> Void
    /// The dismiss drag began at this point, in global (window) coordinates.
    var onDismissBegan: (CGPoint) -> Void
    var onDismissChanged: (CGSize) -> Void
    var onDismissEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView(image: image)
        view.delegate = context.coordinator
        view.imageView.isAccessibilityElement = true
        view.imageView.accessibilityLabel = accessibilityLabel

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTapped))
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
        let dismissPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panned(_:)))
        dismissPan.delegate = context.coordinator
        view.addGestureRecognizer(dismissPan)
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableImageView
        init(_ parent: ZoomableImageView) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ZoomScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { (scrollView as? ZoomScrollView)?.centerImage() }

        @objc func singleTapped() { parent.onSingleTap() }

        @objc func doubleTapped(_ tap: UITapGestureRecognizer) {
            guard let view = tap.view as? ZoomScrollView else { return }
            if view.zoomScale > view.minimumZoomScale + 0.01 {
                view.setZoomScale(view.minimumZoomScale, animated: true)
            } else {
                let point = tap.location(in: view.imageView)
                let size = CGSize(width: view.bounds.width / ImageViewerMath.doubleTapZoom,
                                  height: view.bounds.height / ImageViewerMath.doubleTapZoom)
                view.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                     width: size.width, height: size.height), animated: true)
            }
        }

        @objc func panned(_ pan: UIPanGestureRecognizer) {
            // Window coordinates: the view itself is scaled and offset by the drag, so measuring in
            // its own space would inflate the translation by 1/scale and run ahead of the finger.
            let t = pan.translation(in: nil)
            switch pan.state {
            case .began:
                // The pan begins a few points into the drag: the grab point is where it started.
                let now = pan.location(in: nil)
                parent.onDismissBegan(CGPoint(x: now.x - t.x, y: now.y - t.y))
            case .changed:
                parent.onDismissChanged(CGSize(width: t.x, height: t.y))
            case .ended, .cancelled, .failed:
                let v = pan.velocity(in: nil)
                parent.onDismissEnded(CGSize(width: t.x, height: t.y), CGSize(width: v.x, height: v.y))
            default:
                break
            }
        }

        /// Rule 13: the dismiss pan exists only at 1×, and only for a vertical-first drag.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer, let view = pan.view as? ZoomScrollView else { return true }
            guard view.zoomScale <= view.minimumZoomScale + 0.01 else { return false }
            let v = pan.velocity(in: view)
            return abs(v.y) > abs(v.x)
        }
    }
}

/// The scroll view behind ZoomableImageView: the image aspect-fit at 1×, centred while smaller than
/// the viewport.
final class ZoomScrollView: UIScrollView {
    let imageView: UIImageView
    private var laidOutSize: CGSize = .zero

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        minimumZoomScale = 1
        maximumZoomScale = ImageViewerMath.maxZoom
        bouncesZoom = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize, bounds.width > 0 else { return }
        laidOutSize = bounds.size
        zoomScale = 1
        let fitted = ImageViewerMath.fittedFrame(imageSize: imageView.image?.size ?? bounds.size, in: CGRect(origin: .zero, size: bounds.size))
        imageView.frame = CGRect(origin: .zero, size: fitted.size)
        contentSize = fitted.size
        centerImage()
    }

    func centerImage() {
        let x = max(0, (bounds.width - contentSize.width) / 2)
        let y = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }
}
