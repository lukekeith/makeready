import SwiftUI
import UIKit

/// image-viewer-zoom-dismiss (owner 2026-10-28; reference docs/ui2/references/image-viewer-zoom-dismiss.md):
/// one image full screen — pinch / double-tap zoom with pan, and Photos' drag-to-dismiss: the image
/// follows the finger, shrinks as it goes down while the page shows through, and on release flies
/// back into the frame it opened from (or back to rest). Reused by the cover viewer and the media
/// library. Build-made: no d2m design.
///
/// media-viewer-paging (owner 2026-11-01): given several images it pages sideways between them, and
/// its only chrome is C-082 ModalCloseButton at the bottom centre — hidden until a tap, then gone
/// again after `ImageViewerMath.chromeHold`.
struct ImageViewer: View {
    let urls: [String]
    let startIndex: Int
    /// Where image `i` opens from and flies back to, in GLOBAL coordinates; nil = no source (the
    /// image grows in place and leaves off the bottom).
    let sourceFrame: (Int) -> CGRect?
    let accessibilityLabel: (Int) -> String
    /// media-page D12: the tile's loaded image; the open flight (and a page) starts from it while
    /// the full image loads.
    let placeholder: (Int) -> UIImage?
    /// The page the viewer settled on.
    var onIndexChange: (Int) -> Void = { _ in }
    let onClose: () -> Void

    /// One image (the cover viewers).
    init(url: String, sourceFrame: CGRect?, accessibilityLabel: String, onClose: @escaping () -> Void,
         placeholder: UIImage? = nil) {
        self.init(urls: [url], startIndex: 0, sourceFrame: { _ in sourceFrame },
                  accessibilityLabel: { _ in accessibilityLabel }, placeholder: { _ in placeholder }, onClose: onClose)
    }

    init(urls: [String], startIndex: Int, sourceFrame: @escaping (Int) -> CGRect?,
         accessibilityLabel: @escaping (Int) -> String, placeholder: @escaping (Int) -> UIImage?,
         onIndexChange: @escaping (Int) -> Void = { _ in }, onClose: @escaping () -> Void) {
        self.urls = urls
        self.startIndex = startIndex
        self.sourceFrame = sourceFrame
        self.accessibilityLabel = accessibilityLabel
        self.placeholder = placeholder
        self.onIndexChange = onIndexChange
        self.onClose = onClose
    }

    /// The page on screen; nil until the first page change (then `startIndex`).
    @State private var pageIndex: Int?
    /// The current page's best image — what the open and dismiss flights draw.
    @State private var image: UIImage?
    /// Bumped as page images land, so the pager swaps them in.
    @State private var imageGeneration = 0
    /// The flying image's frame, in this view's coordinates — used while opening and dismissing.
    @State private var flightFrame: CGRect = .zero
    @State private var backdrop: Double = 0
    /// The pager is live (at rest, zooming, paging, or being dragged); false while flying.
    @State private var zoomLive = false
    @State private var chromeVisible = false
    @State private var chromeHideTask: Task<Void, Never>?
    /// The dismiss drag's translation while the finger is down (applied to the live view).
    @State private var drag: CGSize = .zero
    /// Where the finger first touched, in this view's coordinates: the image scales about it, so
    /// the point grabbed stays under the finger (reference rule 5).
    @State private var dragAnchor: CGPoint?
    @State private var closing = false

    private var current: Int { pageIndex ?? startIndex }

    var body: some View {
        GeometryReader { proxy in
            let viewport = CGRect(origin: .zero, size: proxy.size)
            let origin = proxy.frame(in: .global).origin
            let fitted = image.map { ImageViewerMath.fittedFrame(imageSize: $0.size, in: viewport) } ?? viewport
            let showsChrome = ImageViewerMath.showsClose(chromeVisible: chromeVisible, live: zoomLive, dragging: drag != .zero,
                                                         hasImage: image != nil, closing: closing)
            ZStack(alignment: .topLeading) {
                Token.layoutBackground.opacity(backdrop)
                if zoomLive {
                    ImagePagerView(
                        count: urls.count,
                        startIndex: current,
                        image: pageImage,
                        accessibilityLabel: accessibilityLabel,
                        imageGeneration: imageGeneration,
                        dismissing: drag != .zero,
                        onIndexChange: pageChanged,
                        onSingleTap: toggleChrome,
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
                        .accessibilityLabel(accessibilityLabel(current))
                } else if !closing {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // As on C-036 FilterMenuOverlay (OQ-C-036-6): the disc's bottom edge sits
            // max(bottom safe-area inset, `space-section-gap`) above the screen bottom.
            .overlay(alignment: .bottom) {
                ModalCloseButton(onClose: { dismiss(fitted: fitted, viewport: viewport, origin: origin) })
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, Token.Space.sectionGap))
                    .opacity(showsChrome ? 1 : 0)
                    .allowsHitTesting(showsChrome)
                    .accessibilityHidden(!showsChrome)
            }
            .task { await open(viewport: viewport, origin: origin) }
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .onDisappear { chromeHideTask?.cancel() }
    }

    // MARK: - Pages

    /// Page `i`'s best image now: the full one when cached, else the tile's.
    private func pageImage(_ i: Int) -> UIImage? {
        guard urls.indices.contains(i) else { return nil }
        if let url = URL(string: urls[i]), let full = Ui2ImageCache.shared.image(for: url) { return full }
        return placeholder(i)
    }

    private func pageChanged(_ i: Int) {
        guard i != current else { return }
        pageIndex = i
        image = pageImage(i)
        onIndexChange(i)
        Task { await loadPages(around: i) }
    }

    /// The page and its neighbours, so a swipe lands on the full image.
    @MainActor
    private func loadPages(around i: Int) async {
        let wanted = ImageViewerMath.neighbourhood(of: i, count: urls.count).map { urls[$0] }
        guard await UI2ImageLoader.seed(wanted, context: "ImageViewer"), !closing else { return }
        imageGeneration += 1
        if let full = pageImage(current) { image = full }
    }

    // MARK: - Chrome

    /// A tap shows the close button and hides it again after `chromeHold`; a tap while it shows
    /// hides it at once.
    private func toggleChrome() {
        chromeHideTask?.cancel()
        if chromeVisible {
            withAnimation(Token.Motion.menuFadeOut) { chromeVisible = false }
            return
        }
        withAnimation(Token.Motion.menuFadeIn) { chromeVisible = true }
        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(for: ImageViewerMath.chromeHold)
            guard !Task.isCancelled else { return }
            withAnimation(Token.Motion.menuFadeOut) { chromeVisible = false }
        }
    }

    // MARK: - Open (rules 1–3)

    /// media-page D12: what the open flight starts from — the full image when cached, else the tile's.
    static func openingImage(cached: UIImage?, placeholder: UIImage?) -> UIImage? { cached ?? placeholder }

    @MainActor
    private func open(viewport: CGRect, origin: CGPoint) async {
        // master-search (agent walk round 1): the viewer is full screen, and a keyboard left up
        // would cover its close button and the image's lower edge.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let url = urls.indices.contains(startIndex) ? URL(string: urls[startIndex]) : nil
        let tile = urls.indices.contains(startIndex) ? placeholder(startIndex) : nil
        let cached = { url.flatMap { Ui2ImageCache.shared.image(for: $0) } }
        if cached() == nil, tile == nil, let url {
            // Nothing to fly yet: the page goes behind the backdrop, and the close button stays usable.
            withAnimation(ImageViewerMath.openSpring) { backdrop = 1 }
            _ = await UI2ImageLoader.seed([url.absoluteString], context: "ImageViewer")
        }
        guard !closing else { return }
        guard let first = Self.openingImage(cached: cached(), placeholder: tile) else {
            // The image cannot load: a blank page, live, so the viewer can still be left.
            withAnimation(ImageViewerMath.openSpring) { backdrop = 1 } completion: {
                if !closing { zoomLive = true }
            }
            return
        }
        image = first
        let target = ImageViewerMath.fittedFrame(imageSize: first.size, in: viewport)
        flightFrame = ImageViewerMath.startFrame(source: sourceFrame(startIndex)?.offsetBy(dx: -origin.x, dy: -origin.y), fitted: target)
        withAnimation(ImageViewerMath.openSpring) {
            flightFrame = target
            backdrop = 1
        } completion: {
            zoomLive = true
        }
        await loadPages(around: startIndex)
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

    /// Fly from where the image is now into the current page's source (or off the bottom), then close.
    private func dismiss(fitted: CGRect, viewport: CGRect, origin: CGPoint) {
        guard !closing else { return }
        closing = true
        chromeHideTask?.cancel()
        chromeVisible = false
        flightFrame = ImageViewerMath.draggedFrame(fitted: fitted, translation: drag,
                                                   scale: ImageViewerMath.dragScale(dy: drag.height, height: viewport.height),
                                                   anchor: dragAnchor)
        zoomLive = false
        drag = .zero
        let source = sourceFrame(current)?.offsetBy(dx: -origin.x, dy: -origin.y)
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
    /// media-viewer-paging: how long a tap shows the close button.
    static let chromeHold: Duration = .seconds(3)

    /// media-viewer-paging: a tap shows the close button. With no image there is nothing to tap on
    /// and nothing to read as a viewer, so it stays up (master-search, agent walk round 1).
    static func showsClose(chromeVisible: Bool, live: Bool, dragging: Bool, hasImage: Bool, closing: Bool) -> Bool {
        guard !closing, !dragging else { return false }
        return hasImage ? chromeVisible && live : true
    }

    /// media-viewer-paging: the page on screen for a pager scrolled to `offsetX` — the nearest
    /// page, clamped to the list.
    static func pageIndex(offsetX: CGFloat, width: CGFloat, count: Int) -> Int {
        guard width > 0, count > 0 else { return 0 }
        return min(count - 1, max(0, Int((offsetX / width).rounded())))
    }

    /// media-viewer-paging: page `i` and its neighbours, in the list — what is mounted and loaded.
    static func neighbourhood(of i: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let clamped = min(count - 1, max(0, i))
        return Array(max(0, clamped - 1)...min(count - 1, clamped + 1))
    }

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

/// media-viewer-paging: the live viewer — a horizontal paging scroll view of zoomable pages (rules
/// 10–14 on each: a UIScrollView zoom with momentum pan and bounce, double-tap zoom, single tap
/// reported, and the dismiss pan, which begins only at 1× and vertical-first). Only the page on
/// screen and its neighbours are mounted. A zoomed page pans to its edge before the pager moves
/// (UIKit's nested scroll views); the pager's own pan begins only on a sideways-first drag, so a
/// downward drag is always the dismiss.
struct ImagePagerView: UIViewRepresentable {
    let count: Int
    /// The page shown when the pager is made; later pages are the pager's own.
    let startIndex: Int
    let image: (Int) -> UIImage?
    let accessibilityLabel: (Int) -> String
    /// Bumped when page images land; the mounted pages pick them up.
    let imageGeneration: Int
    /// A dismiss drag is under way: the neighbours hide, so the shrinking page drags alone.
    let dismissing: Bool
    var onIndexChange: (Int) -> Void
    var onSingleTap: () -> Void
    /// The dismiss drag began at this point, in global (window) coordinates.
    var onDismissBegan: (CGPoint) -> Void
    var onDismissChanged: (CGSize) -> Void
    var onDismissEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PagerScrollView {
        let pager = PagerScrollView(startIndex: startIndex)
        pager.delegate = context.coordinator
        pager.makePage = { [weak coordinator = context.coordinator] index in coordinator?.makePage(index) ?? ZoomScrollView(image: nil) }
        pager.count = count
        return pager
    }

    func updateUIView(_ pager: PagerScrollView, context: Context) {
        context.coordinator.parent = self
        pager.count = count
        for (index, page) in pager.pages where page.imageView.image !== image(index) {
            page.setImage(image(index))
        }
        for (index, page) in pager.pages {
            page.alpha = dismissing && index != pager.currentIndex ? 0 : 1
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ImagePagerView
        init(_ parent: ImagePagerView) { self.parent = parent }

        func makePage(_ index: Int) -> ZoomScrollView {
            let page = ZoomScrollView(image: parent.image(index))
            page.delegate = self
            page.imageView.isAccessibilityElement = true
            page.imageView.accessibilityLabel = parent.accessibilityLabel(index)

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
            doubleTap.numberOfTapsRequired = 2
            page.addGestureRecognizer(doubleTap)
            let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
            singleTap.require(toFail: doubleTap)
            page.addGestureRecognizer(singleTap)
            let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            dismissPan.delegate = self
            page.addGestureRecognizer(dismissPan)
            return page
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ZoomScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { (scrollView as? ZoomScrollView)?.centerImage() }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let pager = scrollView as? PagerScrollView, pager.updateCurrentIndex() else { return }
            parent.onIndexChange(pager.currentIndex)
        }

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

        /// Rule 13: the dismiss pan exists only at 1×, only for a vertical-first drag, and not while
        /// the pager is still settling on a page.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer, let view = pan.view as? ZoomScrollView else { return true }
            guard view.zoomScale <= view.minimumZoomScale + 0.01 else { return false }
            if let pager = view.superview as? PagerScrollView, pager.isDecelerating { return false }
            let v = pan.velocity(in: view)
            return abs(v.y) > abs(v.x)
        }
    }
}

/// The pager behind ImagePagerView: one page per image, side by side, with only the current page
/// and its neighbours mounted.
final class PagerScrollView: UIScrollView {
    var makePage: (Int) -> ZoomScrollView = { _ in ZoomScrollView(image: nil) }
    var count = 0 {
        didSet { if count != oldValue { setNeedsLayout() } }
    }
    private(set) var currentIndex: Int
    private(set) var pages: [Int: ZoomScrollView] = [:]
    private var laidOutSize: CGSize = .zero

    init(startIndex: Int) {
        currentIndex = startIndex
        super.init(frame: .zero)
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        alwaysBounceVertical = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The pager's own pan begins only on a sideways-first drag: a downward drag is the dismiss.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            // Velocity plus translation: a slow drag starts with almost no velocity.
            let v = panGestureRecognizer.velocity(in: self)
            let t = panGestureRecognizer.translation(in: self)
            guard abs(v.x) + abs(t.x) > abs(v.y) + abs(t.y) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        if bounds.size != laidOutSize {
            laidOutSize = bounds.size
            contentSize = CGSize(width: bounds.width * CGFloat(count), height: bounds.height)
            contentOffset = CGPoint(x: bounds.width * CGFloat(currentIndex), y: 0)
        }
        tilePages()
    }

    /// Reads the page from the offset; true when it changed. A page that leaves the screen is
    /// returned to 1×.
    func updateCurrentIndex() -> Bool {
        let next = ImageViewerMath.pageIndex(offsetX: contentOffset.x, width: bounds.width, count: count)
        guard next != currentIndex else { return false }
        pages[currentIndex]?.setZoomScale(1, animated: false)
        currentIndex = next
        tilePages()
        return true
    }

    private func tilePages() {
        let wanted = Set(ImageViewerMath.neighbourhood(of: currentIndex, count: count))
        for (index, page) in pages where !wanted.contains(index) {
            page.removeFromSuperview()
            pages[index] = nil
        }
        for index in wanted {
            let page = pages[index] ?? makePage(index)
            if pages[index] == nil {
                pages[index] = page
                addSubview(page)
            }
            let frame = CGRect(x: bounds.width * CGFloat(index), y: 0, width: bounds.width, height: bounds.height)
            if page.frame != frame { page.frame = frame }
        }
    }
}

/// One page of ImagePagerView: the image aspect-fit at 1×, centred while smaller than the viewport.
final class ZoomScrollView: UIScrollView {
    let imageView: UIImageView
    private var laidOutSize: CGSize = .zero

    init(image: UIImage?) {
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

    /// A better image for the page (the full one landed). At 1× the page re-fits it; zoomed, the
    /// same picture is swapped in place.
    func setImage(_ image: UIImage?) {
        imageView.image = image
        guard zoomScale <= minimumZoomScale + 0.01 else { return }
        laidOutSize = .zero
        setNeedsLayout()
    }

    func centerImage() {
        let x = max(0, (bounds.width - contentSize.width) / 2)
        let y = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }
}
