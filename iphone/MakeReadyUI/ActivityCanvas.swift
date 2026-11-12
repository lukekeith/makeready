//
//  ActivityCanvas.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-091-activitycanvas in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-091 ActivityCanvas — the activity page surface: tap anywhere to add a text object; hosts the
/// page's objects. Every text on the page, a Bible passage included, is a C-092 in the slot.
///
/// §2 units (D1): the canvas composes in a 440 × 956 reference space of width units (wu); one wu
/// is `canvas width / 440` points. Every length it takes or emits is in wu, converted at render.
///
/// §2 layers, bottom → top: the ground (colour, blob gradient, image, wash), the reserved-zone guides, the
/// `content` slot, the width handles, and the Manipulating overlays (centre guide, delete target).
///
/// Width-driven (R-16): the page height is computed (§2 Sizing, D2) and a page taller than the
/// viewport scrolls inside the canvas. Disclosed R-16 exception (§2): it paints its own ground —
/// `background` is the leader's page property, not chrome.
///
/// §2 Viewer mode (D69): `viewer` keeps the same ground and placement but holds no scroll position
/// — a viewport-tall clipped window onto the page, moved by the engine's `scrollOffset`.
///
/// §2 Fixed canvas (D24): with `scrolls = false` the page is the viewport — no scroll, the offset
/// is 02 §4 step 1 only, `scrollInsets` are ignored and autoscroll is off.
///
/// Controlled (R-01): it holds no value of its own; every gesture leaves through a closure.
struct ActivityCanvas<Content: View>: View {
    /// §4 `background` — the document's background layer (§2 layer 1, D4; 02 §5).
    struct Background {
        /// §4 `image` — the caller resolves it (R-04 / R-19).
        struct Image {
            var imageURL: URL
            /// The point kept visible when cropped, 0–1.
            var focal: CGPoint
        }

        /// §4 `wash` — drawn over the image.
        struct Wash {
            var color: Color
            var opacity: Double
        }

        /// §4 `gradient` — the blob gradient (§2 layer 1). Declared outside the generic canvas
        /// so every specialization, and `ActivityBlobGradient`, shares one type.
        typealias Gradient = ActivityCanvasGradient

        /// §4 `motion` — stored and written back unchanged, never drawn (§2 layer 1).
        enum Motion {
            case scroll(rate: Double)
            case fixed
            case parallax(rate: Double)
        }

        var color: Color
        var gradient: Gradient?
        var image: Image?
        var wash: Wash?
        var motion: Motion = .scroll(rate: 1)
    }

    /// §4 `mode` — which gestures the canvas takes and which overlays it draws.
    enum Mode {
        case idle, editing, highlighting, manipulating, viewer
    }

    /// §4 `deleteTarget` — D50 (owner, 2026-11-12): armed = ring 1.2×, label 1.35×.
    enum DeleteTarget {
        case visible, armed
    }

    /// §4 `verticalAnchor` — 02 §4 step 1.
    enum VerticalAnchor {
        case center, top
    }

    /// §4 `widthHandles` — the active object's layout frame, page-local wu (OQ-C-091-005).
    struct WidthHandles {
        var frame: CGRect
        var rotation: Angle
    }

    /// §4 `scrollInsets` — how far past each end of the page the scroll range reaches (wu), so
    /// content under a caller's opaque bar can be scrolled clear of it. The page does not move:
    /// at rest, page y 0 stays at viewport y 0.
    struct ScrollInsets: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0
    }

    /// §4 — the ground.
    let background: Background
    /// §4 — gestures and overlays.
    let mode: Mode
    /// §4 — the designed slot (R-08): placed and positioned by the screen.
    @ViewBuilder let content: () -> Content
    /// §4 — a tap no slot child took, page-local wu; `idle`, `editing` and `highlighting` (§2 layer 3).
    let onTapEmpty: (CGPoint) -> Void
    /// §4 — draw the centre guide in `manipulating`.
    let centerGuide: Bool
    /// §4 (activities-editor §18.7, D33) — the snap guides active now, viewport wu; each draws
    /// 1pt `white-80` over the page. Empty (the default) draws nothing, so other users are unchanged.
    let activeGuides: [GuideSegment]
    typealias GuideSegment = ActivityCanvasGuideSegment
    /// §4 — draw the "Drag to delete" target in `manipulating` (D50 look); placed by D48.
    let deleteTarget: DeleteTarget?
    /// §4 (D50) — the target zone (label + ring, rest size) in the canvas's own points, reported
    /// whenever it is laid out. The canvas does no hit-testing; the host arms against this.
    let onDeleteTargetFrame: (CGRect) -> Void
    /// D48 — the viewport's bottom safe-area inset, points. The canvas is laid out under the
    /// safe area, so the host passes it; the delete target's bottom edge sits 16 pt above it.
    let bottomSafeArea: CGFloat
    /// §4 — 02 §4 step 1.
    let verticalAnchor: VerticalAnchor
    /// §4 — top…bottom of all objects' rotated, scaled box (wu); nil = the page is the viewport.
    let contentExtent: ClosedRange<CGFloat>?
    /// §4 — draw the viewer's reserved-zone guides (§2 layer 6).
    let reservedZones: Bool
    /// §4 — the page has a pinned action: B grows and the pinned band is drawn.
    let pinnedAction: Bool
    /// §4 — the active object's layout frame (OQ-C-091-005).
    let widthHandles: WidthHandles?
    /// §4 — the clamped new layout width, wu, live while a handle is dragged.
    let onResizeWidth: (CGFloat) -> Void
    /// §4 — the scroll range past each end of the page (wu).
    let scrollInsets: ScrollInsets
    /// §4 — the dragging finger, viewport wu; near an edge in `manipulating` the page autoscrolls.
    let dragPoint: CGPoint?
    /// §4 — how far an autoscroll step moved the page (wu), so the caller can re-express the
    /// dragged object's page position and it stays under the finger.
    let onAutoscroll: (CGFloat) -> Void
    /// §4 (activities-editor §33, D51) — the page's current scroll (wu), reported whenever it
    /// changes, so a host can place screen-fixed things in page space. Defaults to a no-op and
    /// changes nothing drawn, so other users are unchanged.
    let onPageScrollChange: (CGFloat) -> Void
    /// §4 — the page's scroll position (wu), supplied each frame by the viewer's engine; `viewer` only.
    let scrollOffset: CGFloat
    /// §4 — `false` = a fixed canvas (§2 Fixed canvas, D24): no scroll, page = viewport, insets
    /// ignored, autoscroll off. No effect in `viewer`.
    let scrolls: Bool

    /// R-02: how far the page has scrolled (wu), so the viewport-fixed layers stay put.
    @State private var scrolled: CGFloat = 0
    /// R-02: the layout width a handle drag started from, held only while the finger is down.
    @State private var resizeBase: CGFloat?
    /// D50: show / hide and arming animate — not under Reduce Motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// §2 Units (D1): the reference space. 02 §4.
    private let referenceWidth: CGFloat = 440
    /// Static so `placement(...)` reads them too (a generic type holds no static stored property).
    private static var referenceHeight: CGFloat { 956 }
    private var referenceHeight: CGFloat { Self.referenceHeight }
    /// FLAGGED LITERAL — C-091 §2 Sizing: T 107 (clear of the top chrome) / B 85 (end space).
    private static var topInset: CGFloat { 107 }
    private static var endSpace: CGFloat { 85 }
    private var topInset: CGFloat { Self.topInset }
    private var endSpace: CGFloat { Self.endSpace }
    /// GAP — C-091 §2 Sizing: "the pinned action's height", no value stated. 46 = 846 (§2 layer 6,
    /// pill top) to 892 (01 §10: ≈30 above the 34 safe bottom of 956).
    private static var pinnedHeight: CGFloat { 46 }
    /// FLAGGED LITERAL — C-091 §4 `deleteTarget` (D50): the white outline ring is 44 wu, its
    /// stroke ≈ 1.5–2 pt (2), the label sits 8 pt above it; armed = ring 1.2×, label 1.35×.
    /// D48 (owner, 2026-11-11) position stands: centred horizontally, the ring's bottom edge 16 pt
    /// above the bottom safe-area inset.
    static var deleteRing: CGFloat { 44 }
    private static var deleteBottomGap: CGFloat { 16 }
    private let deleteRingStroke: CGFloat = 2
    private let deleteLabelGap: CGFloat = 8
    private let deleteRingArmedScale: CGFloat = 1.2
    private let deleteLabelArmedScale: CGFloat = 1.35
    /// D50: show / hide fade ≈ 170 ms and arming ≈ 100 ms, ease-out, one curve each.
    private let deleteFade = Animation.easeOut(duration: 0.17)
    private let deleteArm = Animation.easeOut(duration: 0.1)
    private let viewportSpace = "ActivityCanvas.viewport"
    /// FLAGGED LITERAL — C-091 §2 layer 5 (OQ-C-091-002): the 1 px centre guide.
    private let guideWidth: CGFloat = 1
    /// FLAGGED LITERAL — activities-editor §18.7 (D33): each active snap guide is 1pt.
    private let snapGuideWidth: CGFloat = 1
    /// FLAGGED LITERAL — C-091 §2 layer 4 (E4): the capsule, its hit area, the resize clamp.
    private let handleSize = CGSize(width: 6, height: 28)
    private let handleHitSize: CGFloat = 44
    private let resizeLimits: ClosedRange<CGFloat> = 80...392
    /// GAP — C-091 §2 layer 4: no VoiceOver step stated for the handles (R-17).
    private let resizeAccessibilityStep: CGFloat = 8
    /// FLAGGED LITERAL — C-091 §2 layer 6: the zone fill's opacity and 1 px dashed edge.
    private let zoneFillOpacity: Double = 0.10
    /// GAP — C-091 §2 layer 6: "dashed", no dash pattern stated.
    private let zoneEdge = StrokeStyle(lineWidth: 1, dash: [4, 4])

    /// FLAGGED LITERAL — C-091 §2 layer 6 (01 §8): the rail, 23 × 88, right edge 28 from the
    /// screen's right, centred at 81 % of the screen height.
    private let railSize = CGSize(width: 23, height: 88)
    private let railRightInset: CGFloat = 28
    private let railHeightFraction: CGFloat = 0.81
    /// FLAGGED LITERAL — C-091 §2 layer 6: the pinned band, the viewport's bottom 110.
    private let pinnedBand: CGFloat = 110
    /// FLAGGED LITERAL — C-091 §2 Autoscroll: the 64 wu edge band, rising to 600 wu/s.
    private let autoscrollBand: CGFloat = 64
    private let autoscrollSpeed: CGFloat = 600
    /// GAP — C-091 §2 Autoscroll: no longest step stated; a late frame moves at most this far in time.
    private let autoscrollMaxStep: TimeInterval = 1.0 / 30

    private let pageSpace = ActivityCanvasSpace.page
    private let scrollSpace = "ActivityCanvas.scroll"
    private let columnID = "ActivityCanvas.column"

    init(
        background: Background,
        mode: Mode,
        @ViewBuilder content: @escaping () -> Content,
        onTapEmpty: @escaping (CGPoint) -> Void = { _ in },
        centerGuide: Bool = false,
        activeGuides: [GuideSegment] = [],
        deleteTarget: DeleteTarget? = nil,
        onDeleteTargetFrame: @escaping (CGRect) -> Void = { _ in },
        bottomSafeArea: CGFloat = 0,
        verticalAnchor: VerticalAnchor = .center,
        contentExtent: ClosedRange<CGFloat>? = nil,
        reservedZones: Bool = false,
        pinnedAction: Bool = false,
        widthHandles: WidthHandles? = nil,
        onResizeWidth: @escaping (CGFloat) -> Void = { _ in },
        scrollInsets: ScrollInsets = .init(),
        dragPoint: CGPoint? = nil,
        onAutoscroll: @escaping (CGFloat) -> Void = { _ in },
        onPageScrollChange: @escaping (CGFloat) -> Void = { _ in },
        scrollOffset: CGFloat = 0,
        scrolls: Bool = true
    ) {
        self.background = background
        self.mode = mode
        self.content = content
        self.onTapEmpty = onTapEmpty
        self.centerGuide = centerGuide
        self.activeGuides = activeGuides
        self.deleteTarget = deleteTarget
        self.onDeleteTargetFrame = onDeleteTargetFrame
        self.bottomSafeArea = bottomSafeArea
        self.verticalAnchor = verticalAnchor
        self.contentExtent = contentExtent
        self.reservedZones = reservedZones
        self.pinnedAction = pinnedAction
        self.widthHandles = widthHandles
        self.onResizeWidth = onResizeWidth
        self.scrollInsets = scrollInsets
        self.dragPoint = dragPoint
        self.onAutoscroll = onAutoscroll
        self.onPageScrollChange = onPageScrollChange
        self.scrollOffset = scrollOffset
        self.scrolls = scrolls
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / referenceWidth
            let viewport = proxy.size.height / unit
            let layout = pageLayout(viewport: viewport)
            if mode == .viewer {
                viewerWindow(viewport: viewport, layout: layout, unit: unit, width: proxy.size.width)
            } else if !scrolls {
                // §2 Fixed canvas (D24): the page is the viewport — no ScrollView, nothing to scroll.
                viewerWindow(viewport: viewport, layout: layout, unit: unit, width: proxy.size.width, scroll: 0)
            } else {
                // The column is the page plus the insets' empty ends, which the caller's bars cover.
                let column = layout.height + scrollInsets.top + scrollInsets.bottom
                let range = column - viewport
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: scrollInsets.top * unit)
                            page(viewport: viewport, layout: layout, unit: unit)
                                .frame(width: referenceWidth, height: layout.height, alignment: .topLeading)
                                .scaleEffect(unit, anchor: .topLeading)
                                .frame(width: proxy.size.width, height: layout.height * unit, alignment: .topLeading)
                                .background {
                                    GeometryReader { scroll in
                                        Color.clear.onChange(of: scroll.frame(in: .named(scrollSpace)).minY) { _, minY in
                                            scrolled = -minY / unit
                                        }
                                    }
                                }
                            Color.clear.frame(height: scrollInsets.bottom * unit)
                        }
                        .id(columnID)
                    }
                    .coordinateSpace(.named(scrollSpace))
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    // §2 Scrolling insets: at rest page y 0 sits at viewport y 0, the top inset above it.
                    .defaultScrollAnchor(columnAnchor(scrolled: 0, range: range))
                    // D49: the canvas scrolls in idle only — editing, highlighting and manipulating
                    // lock it so the slider, handles and edited text get every drag. The offset,
                    // range and insets are untouched; idle resumes from the kept offset.
                    .scrollDisabled(range <= 0 || mode != .idle)
                    // A bar changing height resizes the column; the page stays where it was scrolled.
                    .onChange(of: column) {
                        if range > 0 { reader.scrollTo(columnID, anchor: columnAnchor(scrolled: scrolled, range: range)) }
                    }
                    .background {
                        autoscrollClock(viewport: viewport, pageHeight: layout.height) { target in
                            reader.scrollTo(columnID, anchor: columnAnchor(scrolled: target, range: range))
                        }
                    }
                }
            }
        }
        .coordinateSpace(.named(viewportSpace))
        // §4 `onPageScrollChange` (D51): report the page's scroll (wu) as it changes.
        .onChange(of: pageScroll, initial: true) { _, scroll in onPageScrollChange(scroll) }
        .ui2Element("ActivityCanvas")
    }

    // MARK: - §2 Viewer mode (D69; OQ-activities-player-001)

    /// A viewport-tall window onto the page, translated up by `scrollOffset` and clipped: no
    /// ScrollView, and no clamp, animation or memory — the range is the engine's (01 §4).
    /// §2 Fixed canvas reuses it with `scroll` 0: the page is exactly the viewport.
    private func viewerWindow(viewport: CGFloat, layout: (offset: CGFloat, height: CGFloat),
                              unit: CGFloat, width: CGFloat, scroll: CGFloat? = nil) -> some View {
        page(viewport: viewport, layout: layout, unit: unit)
            .frame(width: referenceWidth, height: layout.height, alignment: .topLeading)
            .scaleEffect(unit, anchor: .topLeading)
            .frame(width: width, height: layout.height * unit, alignment: .topLeading)
            .offset(y: -(scroll ?? scrollOffset) * unit)
            .frame(width: width, height: viewport * unit, alignment: .topLeading)
            .clipped()
    }

    // MARK: - §2 Scrolling insets and autoscroll

    /// The column's anchor that puts page y `scrolled` at viewport y 0: scrolling to anchor `a`
    /// lines the column's `a` up with the viewport's `a`, an offset of `a × range`.
    private func columnAnchor(scrolled: CGFloat, range: CGFloat) -> UnitPoint {
        guard range > 0 else { return UnitPoint(x: 0, y: 0) }
        return UnitPoint(x: 0, y: min(max((scrolled + scrollInsets.top) / range, 0), 1))
    }

    /// §2 Autoscroll: ticks only while a drag is in an edge band of a page taller than the viewport.
    private func autoscrollClock(viewport: CGFloat, pageHeight: CGFloat,
                                 scrollTo: @escaping (CGFloat) -> Void) -> some View {
        let velocity = autoscrollVelocity(viewport: viewport, pageHeight: pageHeight)
        return TimelineView(.animation(paused: velocity == 0)) { context in
            Color.clear.onChange(of: context.date) { previous, now in
                let elapsed = min(now.timeIntervalSince(previous), autoscrollMaxStep)
                let target = min(max(scrolled + velocity * CGFloat(elapsed), 0), pageHeight - viewport)
                let moved = target - scrolled
                guard moved != 0 else { return }
                scrolled = target
                scrollTo(target)
                onAutoscroll(moved)
            }
        }
        .accessibilityHidden(true)
    }

    /// wu/s toward the nearer edge, rising from 0 at the band's inner edge to full at the screen's.
    private func autoscrollVelocity(viewport: CGFloat, pageHeight: CGFloat) -> CGFloat {
        guard mode == .manipulating, scrolls, pageHeight > viewport, let dragPoint else { return 0 }
        let intoTop = autoscrollBand - dragPoint.y
        let intoBottom = dragPoint.y - (viewport - autoscrollBand)
        if intoTop > 0 { return -autoscrollSpeed * min(intoTop / autoscrollBand, 1) }
        if intoBottom > 0 { return autoscrollSpeed * min(intoBottom / autoscrollBand, 1) }
        return 0
    }

    // MARK: - §2 Sizing (D2; 02 §4)

    private func pageLayout(viewport: CGFloat) -> (offset: CGFloat, height: CGFloat) {
        // §2 Fixed canvas (D24): page = viewport, offset = step 1 only (no nudge, no growth), so the
        // objects sit where the author put them and may lie outside the viewport.
        if !scrolls && mode != .viewer {
            return (verticalAnchor == .center ? (viewport - referenceHeight) / 2 : 0, viewport)
        }
        let placed = Self.placement(viewportHeight: viewport, contentExtent: contentExtent,
                                    verticalAnchor: verticalAnchor, pinnedAction: pinnedAction, unit: 1)
        return (placed.offset, placed.pageHeight)
    }

    /// §2 Placement function (OQ-C-091-006): 02 §4's three steps as a pure function of its
    /// arguments, so the canvas and the host (the viewer's engine) call the same code.
    /// `viewportHeight` is in points and `unit` is points per wu (`V = viewportHeight / unit`);
    /// `contentExtent`, `offset` and `pageHeight` are in wu.
    static func placement(
        viewportHeight: CGFloat,
        contentExtent: ClosedRange<CGFloat>?,
        verticalAnchor: VerticalAnchor = .center,
        pinnedAction: Bool = false,
        unit: CGFloat
    ) -> (offset: CGFloat, pageHeight: CGFloat) {
        let viewport = viewportHeight / unit
        var offset = verticalAnchor == .center ? (viewport - referenceHeight) / 2 : 0
        guard let extent = contentExtent else { return (offset, viewport) }
        let bottomInset = endSpace + (pinnedAction ? pinnedHeight : 0)
        if extent.upperBound - extent.lowerBound <= viewport - topInset - bottomInset {
            if extent.lowerBound + offset < topInset {
                offset = topInset - extent.lowerBound
            } else if extent.upperBound + offset > viewport - bottomInset {
                offset = viewport - bottomInset - extent.upperBound
            }
            return (offset, viewport)
        }
        offset = topInset - extent.lowerBound
        return (offset, extent.upperBound + offset + bottomInset)
    }

    /// How far the page sits scrolled under the viewport (wu): the engine's `scrollOffset` in
    /// `viewer`, 0 on a fixed canvas, else the canvas's own scroll.
    private var pageScroll: CGFloat {
        if mode == .viewer { return scrollOffset }
        return scrolls ? scrolled : 0
    }

    private func page(viewport: CGFloat, layout: (offset: CGFloat, height: CGFloat), unit: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ground(height: layout.height)
            if reservedZones && mode != .viewer {
                reservedZoneGuides(viewport: viewport, layout: layout)
            }
            content()
                .frame(width: referenceWidth, height: layout.height, alignment: .topLeading)
                .offset(y: layout.offset)
                // §2 Viewer mode: furniture stays fixed against `V` as it does when the page scrolls.
                .environment(\.activityCanvasFixedShift, pageScroll - layout.offset)
                .ui2Element("Content")
            if let widthHandles, mode != .viewer {
                widthHandleLayer(widthHandles)
            }
            if !activeGuides.isEmpty && mode != .viewer {
                snapGuides()
            }
            if mode == .manipulating {
                manipulatingOverlays(viewport: viewport, pageHeight: layout.height, unit: unit)
            }
            // D50: the delete target's own layer, so its show / hide fade is scoped to it alone.
            ZStack(alignment: .topLeading) {
                if mode == .manipulating, let deleteTarget {
                    deleteTargetView(deleteTarget, viewport: viewport, unit: unit)
                }
            }
            .frame(width: referenceWidth, height: layout.height, alignment: .topLeading)
            .animation(reduceMotion ? nil : deleteFade, value: mode == .manipulating && deleteTarget != nil)
        }
        .coordinateSpace(.named(pageSpace))
    }

    // MARK: - §2 layer 1: the ground; layer 3: the tap target

    private func ground(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            background.color
            if let gradient = background.gradient {
                ActivityBlobGradient(gradient: gradient, pageSize: CGSize(width: referenceWidth, height: height))
            }
            if let image = background.image, let picture = Ui2ImageCache.shared.image(for: image.imageURL) {
                coverImage(picture, focal: image.focal, in: CGSize(width: referenceWidth, height: height))
            }
            if let wash = background.wash {
                wash.color.opacity(wash.opacity)
            }
        }
        .frame(width: referenceWidth, height: height)
        .clipped()
        .contentShape(Rectangle())
        // §2 layer 3 (D10, D21): idle, editing and highlighting report a tap no child took; the
        // screen decides what it means.
        .gesture(SpatialTapGesture().onEnded { onTapEmpty($0.location) }, isEnabled: tapsEmpty)
        .accessibilityElement()
        .accessibilityLabel("Activity canvas")
        .accessibilityHint(mode == .idle ? "Adds a text object" : "")
        .accessibilityAddTraits(mode == .idle ? .isButton : [])
        .accessibilityAction {
            if mode == .idle { onTapEmpty(CGPoint(x: referenceWidth / 2, y: height / 2)) }
        }
        // §2 VoiceOver (OQ-C-091-008): the "Activity canvas" button is idle's only; in the other
        // modes the screen announces what a tap means, and in `viewer` the page (01 §12).
        .accessibilityHidden(mode != .idle)
        .allowsHitTesting(mode != .viewer)
        .ui2Element("Ground")
    }

    /// §2 layer 3: the modes whose empty-canvas tap is reported.
    private var tapsEmpty: Bool {
        mode == .idle || mode == .editing || mode == .highlighting
    }

    /// §2 layer 1 Cover rule: drawn at `max(P.w / I.w, P.h / I.h)`, cropped from
    /// `(D − P) × focal`, so the crop never leaves the image at any focal point. The picture hangs
    /// in an overlay from the page's top-left corner: an overlay's size never feeds back, so the
    /// ground stays exactly `P` whatever the image's size. R-04 / R-19: read cache-first, never
    /// fetched (Ui2ImageCache.swift).
    private func coverImage(_ picture: UIImage, focal: CGPoint, in size: CGSize) -> some View {
        let scale = max(size.width / picture.size.width, size.height / picture.size.height)
        let drawn = CGSize(width: picture.size.width * scale, height: picture.size.height * scale)
        let cropX = (drawn.width - size.width) * min(max(focal.x, 0), 1)
        let cropY = (drawn.height - size.height) * min(max(focal.y, 0), 1)
        return Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                SwiftUI.Image(uiImage: picture)
                    .resizable()
                    .frame(width: drawn.width, height: drawn.height)
                    .offset(x: -cropX, y: -cropY)
            }
            .accessibilityHidden(true)
    }

    // MARK: - §2 layer 4: the width handles (E4, OQ-C-091-005)

    private func widthHandleLayer(_ handles: WidthHandles) -> some View {
        ZStack {
            widthHandle(handles, sign: -1, label: "Left width handle")
                .position(x: 0, y: handles.frame.height / 2)
            widthHandle(handles, sign: 1, label: "Right width handle")
                .position(x: handles.frame.width, y: handles.frame.height / 2)
        }
        .frame(width: handles.frame.width, height: handles.frame.height)
        .rotationEffect(handles.rotation)
        .position(x: handles.frame.midX, y: handles.frame.midY)
    }

    private func widthHandle(_ handles: WidthHandles, sign: CGFloat, label: String) -> some View {
        Capsule()
            .fill(Token.white100)
            .frame(width: handleSize.width, height: handleSize.height)
            .frame(width: handleHitSize, height: handleHitSize)
            .contentShape(Rectangle())
            .gesture(
                // pan-ok: along the object's rotated axis, not the screen's sideways axis
                DragGesture(minimumDistance: 0, coordinateSpace: .named(pageSpace))
                    .onChanged { drag in
                        let base = resizeBase ?? handles.frame.width
                        resizeBase = base
                        // Read along the rotated axis, in the page's fixed space: the handle itself
                        // moves as the width changes. Symmetric about the object's centre.
                        let radians = handles.rotation.radians
                        let along = drag.translation.width * cos(radians) + drag.translation.height * sin(radians)
                        onResizeWidth(clampedWidth(base + 2 * sign * along))
                    }
                    .onEnded { _ in resizeBase = nil }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(handles.frame.width))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onResizeWidth(clampedWidth(handles.frame.width + resizeAccessibilityStep))
                case .decrement: onResizeWidth(clampedWidth(handles.frame.width - resizeAccessibilityStep))
                @unknown default: break
                }
            }
            .ui2Element(label)
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, resizeLimits.lowerBound), resizeLimits.upperBound)
    }

    // MARK: - §2 layer 5: the Manipulating overlays (OQ-C-091-002, owner-ratified)

    @ViewBuilder
    private func manipulatingOverlays(viewport: CGFloat, pageHeight: CGFloat, unit: CGFloat) -> some View {
        if centerGuide {
            Token.white100
                .frame(width: guideWidth, height: pageHeight)
                .ui2Element("Center guide")
                .offset(x: (referenceWidth - guideWidth) / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// D50: the white outline ring + trash glyph + "Drag to delete" label (§4 `deleteTarget`).
    private func deleteTargetView(_ deleteTarget: DeleteTarget, viewport: CGFloat, unit: CGFloat) -> some View {
        let armed = deleteTarget == .armed
        return Group {
            // D50: the label centred 8 pt above the white outline ring holding the trash glyph; no
            // backing. Each part scales about its own centre, so both stay on the same axis.
            VStack(spacing: deleteLabelGap) {
                Text("Drag to delete")
                    // GAP — C-091 §4 `deleteTarget` (D50): semibold 13 pt; no token matches exactly —
                    // the closest semibold style.
                    .designTextStyle(Token.TypeStyle.captionSemibold)
                    .foregroundStyle(Token.white100)
                    .fixedSize()
                    .scaleEffect(armed ? deleteLabelArmedScale : 1)
                ZStack {
                    Circle()
                        .strokeBorder(Token.white100, lineWidth: deleteRingStroke)
                    Glyph(.trash2, size: .md, tint: Token.white100)
                }
                .frame(width: Self.deleteRing, height: Self.deleteRing)
                .scaleEffect(armed ? deleteRingArmedScale : 1)
            }
            // D50: arming / disarming, scoped to the scale.
            .animation(reduceMotion ? nil : deleteArm, value: armed)
            // D50: the zone at rest size — the stack's layout frame ignores the armed scale.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(viewportSpace)) } action: { frame in
                onDeleteTargetFrame(frame)
            }
            .ui2Element("Delete target")
            // The stack sits on the ring's bottom edge (D48), whatever the label's measured height.
            .frame(height: Self.deleteBox, alignment: .bottom)
            .position(x: referenceWidth / 2,
                      y: Self.deleteRingBottom(viewport: viewport, bottomSafeArea: bottomSafeArea, unit: unit)
                        - Self.deleteBox / 2 + pageScroll)
            .transition(.opacity)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(armed ? "Release to delete" : "Drag to delete")
        }
    }

    /// D48: the ring's bottom edge in viewport wu — `deleteBottomGap` pt above the bottom
    /// safe-area inset (both in points, `unit` points per wu).
    private static func deleteRingBottom(viewport: CGFloat, bottomSafeArea: CGFloat, unit: CGFloat) -> CGFloat {
        viewport - (bottomSafeArea + deleteBottomGap) / max(unit, .leastNonzeroMagnitude)
    }

    /// D50: the ring's top edge in viewport wu, for a host that docks something on it (the
    /// zone itself is reported through `onDeleteTargetFrame`).
    static func deleteRingTop(viewport: CGFloat, bottomSafeArea: CGFloat, unit: CGFloat) -> CGFloat {
        deleteRingBottom(viewport: viewport, bottomSafeArea: bottomSafeArea, unit: unit) - deleteRing
    }

    /// D50: the box the label + ring stack is bottom-aligned in — room for both, armed.
    private static var deleteBox: CGFloat { deleteRing * 3 }

    // MARK: - activities-editor §18.7 (D33): the active snap guides

    /// Over the page, taking no hits, held still against the viewport like the reserved zones.
    private func snapGuides() -> some View {
        Path { path in
            for segment in activeGuides {
                path.move(to: segment.from)
                path.addLine(to: segment.to)
            }
        }
        .stroke(Token.white80, lineWidth: snapGuideWidth)
        .frame(width: referenceWidth, alignment: .topLeading)
        .offset(y: pageScroll)
        .ui2Element("Snap guides")
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - §2 layer 6: the reserved-zone guides (D3; 01 §8–§10)

    /// Under the slot, taking no hits. The zones sit at the viewer's real positions on this
    /// viewport's height and hold still against it; only the fold marks a page position.
    private func reservedZoneGuides(viewport: CGFloat, layout: (offset: CGFloat, height: CGFloat)) -> some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                zone("Top chrome zone", CGRect(x: 0, y: 0, width: referenceWidth, height: topInset))
                zone("Rail zone", CGRect(x: referenceWidth - railRightInset - railSize.width,
                                         y: viewport * railHeightFraction - railSize.height / 2,
                                         width: railSize.width, height: railSize.height))
                zone("End space zone", CGRect(x: 0, y: viewport - endSpace, width: referenceWidth, height: endSpace))
                if pinnedAction {
                    zone("Pinned action zone", CGRect(x: 0, y: viewport - pinnedBand, width: referenceWidth, height: pinnedBand))
                }
            }
            .offset(y: pageScroll)
            // §2 layer 6: "marking where a 956-tall phone ends when the page is taller".
            if layout.height > referenceHeight + layout.offset {
                ScreenFoldLine()
                    .stroke(Token.white50, style: zoneEdge)
                    .frame(width: referenceWidth, height: 1)
                    .ui2Element("Screen fold")
                    .offset(y: referenceHeight + layout.offset)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func zone(_ name: String, _ rect: CGRect) -> some View {
        Rectangle()
            .fill(Token.white50.opacity(zoneFillOpacity))
            .overlay(Rectangle().stroke(Token.white50, style: zoneEdge))
            .frame(width: rect.width, height: rect.height)
            .ui2Element(name)
            .offset(x: rect.minX, y: rect.minY)
    }
}

// MARK: - activities-editor §18.7: one snap guide

/// §4 `activeGuides` — one guide line from `from` to `to`, viewport wu. Spelled
/// `ActivityCanvas.GuideSegment`.
struct ActivityCanvasGuideSegment: Equatable, Hashable {
    var from: CGPoint
    var to: CGPoint
}

// MARK: - §2 layer 1: the blob gradient

/// §4 `background.gradient` — the blob gradient, drawn between `color` and `image` in every mode
/// (§2 layer 1; text-activity-v2 D1, D2, D14, D17). `base` is carried and written back unchanged,
/// never painted (OQ-schat-C-091-1); `hidden` skips only the blobs. Spelled
/// `ActivityCanvas.Background.Gradient`.
struct ActivityCanvasGradient {
    /// One radial blob: `color` at its centre to fully transparent at radius `r`.
    /// `x`, `y` and `r` are fractions of the page width.
    struct Blob {
        var x: Double
        var y: Double
        var r: Double
        var color: Color
    }

    var base: Color
    var hidden: Bool
    var blobs: [Blob]
}

/// §2 layer 1 Public view — the blob gradient alone (not `color`, `base`, image or wash), drawn at
/// `pageSize`; nothing when `gradient.hidden`. Each blob, in array order (later on top), is a
/// radial gradient from its colour at `(x · w, y · w)` to clear at `r · w`, normal blending.
/// The canvas uses it for its ground; the app's slide thumbnails draw it on a 440 × 956 page.
struct ActivityBlobGradient: View {
    let gradient: ActivityCanvasGradient
    let pageSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !gradient.hidden {
                ForEach(gradient.blobs.indices, id: \.self) { index in
                    blob(gradient.blobs[index])
                }
            }
        }
        .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ui2Element("Gradient")
    }

    private func blob(_ blob: ActivityCanvasGradient.Blob) -> some View {
        let width = pageSize.width
        let radius = max(blob.r * width, 0)
        return Rectangle()
            .fill(RadialGradient(
                colors: [blob.color, blob.color.opacity(0)],
                // x, y are fractions of the page WIDTH (§2 layer 1), so y rescales by w / h.
                center: UnitPoint(x: blob.x, y: blob.y * width / max(pageSize.height, 1)),
                startRadius: 0,
                endRadius: radius
            ))
            .frame(width: pageSize.width, height: pageSize.height)
    }
}

/// §2 layer 6: the screen fold's dashed line.
private struct ScreenFoldLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - §2 layer 2: fixed screen furniture

/// The page's coordinate space name, in wu (C-091's scale is applied outside it): an object's
/// move drag measures in it so the finger and the object stay locked together. Spelled
/// `ActivityCanvas.page` (the type is generic, so the constant is pinned to one specialization).
enum ActivityCanvasSpace {
    static let page = "ActivityCanvas.page"
}

extension ActivityCanvas where Content == EmptyView {
    static var page: String { ActivityCanvasSpace.page }
}

/// §2 layer 2: a slot child positioned against the viewport, not the scrolling page (C-093, the
/// Selection row). The slot is translated by the page offset and scrolls; this undoes both.
struct ActivityCanvasViewportFixed<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.activityCanvasFixedShift) private var shift

    var body: some View {
        content().offset(y: shift)
    }
}

private struct ActivityCanvasFixedShiftKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var activityCanvasFixedShift: CGFloat {
        get { self[ActivityCanvasFixedShiftKey.self] }
        set { self[ActivityCanvasFixedShiftKey.self] = newValue }
    }
}
