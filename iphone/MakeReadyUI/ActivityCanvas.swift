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
/// §2 layers, bottom → top: the ground (colour, image, wash), the reserved-zone guides, the
/// `content` slot, the width handles, and the Manipulating overlays (centre guide, delete target).
///
/// Width-driven (R-16): the page height is computed (§2 Sizing, D2) and a page taller than the
/// viewport scrolls inside the canvas. Disclosed R-16 exception (§2): it paints its own ground —
/// `background` is the leader's page property, not chrome.
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

        /// §4 `motion` — stored and written back unchanged, never drawn (§2 layer 1).
        enum Motion {
            case scroll(rate: Double)
            case fixed
            case parallax(rate: Double)
        }

        var color: Color
        var image: Image?
        var wash: Wash?
        var motion: Motion = .scroll(rate: 1)
    }

    /// §4 `mode` — which gestures the canvas takes and which overlays it draws.
    enum Mode {
        case idle, editing, highlighting, manipulating
    }

    /// §4 `deleteTarget` — OQ-C-091-002 (owner, ratified): armed = 1.15×.
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
    /// §4 — a tap no slot child took, page-local wu; `idle` only.
    let onTapEmpty: (CGPoint) -> Void
    /// §4 — draw the centre guide in `manipulating`.
    let centerGuide: Bool
    /// §4 — draw the "Drag to delete" target in `manipulating`.
    let deleteTarget: DeleteTarget?
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

    /// R-02: how far the page has scrolled (wu), so the viewport-fixed layers stay put.
    @State private var scrolled: CGFloat = 0
    /// R-02: the layout width a handle drag started from, held only while the finger is down.
    @State private var resizeBase: CGFloat?

    /// §2 Units (D1): the reference space. 02 §4.
    private let referenceWidth: CGFloat = 440
    private let referenceHeight: CGFloat = 956
    /// FLAGGED LITERAL — C-091 §2 Sizing: T 107 (clear of the top chrome) / B 85 (end space).
    private let topInset: CGFloat = 107
    private let endSpace: CGFloat = 85
    /// GAP — C-091 §2 Sizing: "the pinned action's height", no value stated. 46 = 846 (§2 layer 6,
    /// pill top) to 892 (01 §10: ≈30 above the 34 safe bottom of 956).
    private let pinnedHeight: CGFloat = 46
    /// FLAGGED LITERAL — C-091 §2 layer 5 (OQ-C-091-002): the delete disc is 44 wu, centred at
    /// 88 % of the viewport height, 1.15× when armed.
    private let deleteDisc: CGFloat = 44
    private let deleteHeightFraction: CGFloat = 0.88
    private let deleteArmedScale: CGFloat = 1.15
    /// FLAGGED LITERAL — C-091 §2 layer 5 (OQ-C-091-002): the 1 px centre guide.
    private let guideWidth: CGFloat = 1
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

    private let pageSpace = "ActivityCanvas.page"
    private let scrollSpace = "ActivityCanvas.scroll"
    private let columnID = "ActivityCanvas.column"

    init(
        background: Background,
        mode: Mode,
        @ViewBuilder content: @escaping () -> Content,
        onTapEmpty: @escaping (CGPoint) -> Void = { _ in },
        centerGuide: Bool = false,
        deleteTarget: DeleteTarget? = nil,
        verticalAnchor: VerticalAnchor = .center,
        contentExtent: ClosedRange<CGFloat>? = nil,
        reservedZones: Bool = false,
        pinnedAction: Bool = false,
        widthHandles: WidthHandles? = nil,
        onResizeWidth: @escaping (CGFloat) -> Void = { _ in },
        scrollInsets: ScrollInsets = .init(),
        dragPoint: CGPoint? = nil,
        onAutoscroll: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.background = background
        self.mode = mode
        self.content = content
        self.onTapEmpty = onTapEmpty
        self.centerGuide = centerGuide
        self.deleteTarget = deleteTarget
        self.verticalAnchor = verticalAnchor
        self.contentExtent = contentExtent
        self.reservedZones = reservedZones
        self.pinnedAction = pinnedAction
        self.widthHandles = widthHandles
        self.onResizeWidth = onResizeWidth
        self.scrollInsets = scrollInsets
        self.dragPoint = dragPoint
        self.onAutoscroll = onAutoscroll
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / referenceWidth
            let viewport = proxy.size.height / unit
            let layout = pageLayout(viewport: viewport)
            // The column is the page plus the insets' empty ends, which the caller's bars cover.
            let column = layout.height + scrollInsets.top + scrollInsets.bottom
            let range = column - viewport
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: scrollInsets.top * unit)
                        page(viewport: viewport, layout: layout)
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
                // While an object follows the finger the drag is the object's, not the page's.
                .scrollDisabled(range <= 0 || mode == .manipulating)
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
        .ui2Element("ActivityCanvas")
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
        guard mode == .manipulating, pageHeight > viewport, let dragPoint else { return 0 }
        let intoTop = autoscrollBand - dragPoint.y
        let intoBottom = dragPoint.y - (viewport - autoscrollBand)
        if intoTop > 0 { return -autoscrollSpeed * min(intoTop / autoscrollBand, 1) }
        if intoBottom > 0 { return autoscrollSpeed * min(intoBottom / autoscrollBand, 1) }
        return 0
    }

    // MARK: - §2 Sizing (D2; 02 §4)

    private func pageLayout(viewport: CGFloat) -> (offset: CGFloat, height: CGFloat) {
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

    private func page(viewport: CGFloat, layout: (offset: CGFloat, height: CGFloat)) -> some View {
        ZStack(alignment: .topLeading) {
            ground(height: layout.height)
            if reservedZones {
                reservedZoneGuides(viewport: viewport, layout: layout)
            }
            content()
                .frame(width: referenceWidth, height: layout.height, alignment: .topLeading)
                .offset(y: layout.offset)
                .environment(\.activityCanvasFixedShift, scrolled - layout.offset)
                .ui2Element("Content")
            if let widthHandles {
                widthHandleLayer(widthHandles)
            }
            if mode == .manipulating {
                manipulatingOverlays(viewport: viewport, pageHeight: layout.height)
            }
        }
        .coordinateSpace(.named(pageSpace))
    }

    // MARK: - §2 layer 1: the ground; layer 3: the tap target

    private func ground(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            background.color
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
        .gesture(SpatialTapGesture().onEnded { onTapEmpty($0.location) }, isEnabled: mode == .idle)
        .accessibilityElement()
        .accessibilityLabel("Activity canvas")
        .accessibilityHint(mode == .idle ? "Adds a text object" : "")
        .accessibilityAddTraits(mode == .idle ? .isButton : [])
        .accessibilityAction {
            if mode == .idle { onTapEmpty(CGPoint(x: referenceWidth / 2, y: height / 2)) }
        }
        .ui2Element("Ground")
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
    private func manipulatingOverlays(viewport: CGFloat, pageHeight: CGFloat) -> some View {
        if centerGuide {
            Token.white100
                .frame(width: guideWidth, height: pageHeight)
                .ui2Element("Center guide")
                .offset(x: (referenceWidth - guideWidth) / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        if let deleteTarget {
            ZStack {
                Circle()
                    .fill(Token.black50)
                Glyph(.trash2, size: .md, tint: Token.white100)
            }
            .frame(width: deleteDisc, height: deleteDisc)
            .scaleEffect(deleteTarget == .armed ? deleteArmedScale : 1)
            .ui2Element("Delete target")
            .position(x: referenceWidth / 2, y: viewport * deleteHeightFraction + scrolled)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(deleteTarget == .armed ? "Release to delete" : "Drag to delete")
        }
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
            .offset(y: scrolled)
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
