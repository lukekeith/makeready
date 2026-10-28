//
//  EditCoverScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen edit-cover in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/groups/:id/cover-image
//  (§5 API-GAP: `framing` / `originalData` are group-cover-image SC1–SC3, not yet on the route).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Edit cover — "frame a group's cover image". The leader pinches, twists and pans a photo
/// inside a fixed-aspect frame, then saves. image-framing-editor D9: the frame's `aspect`, its
/// `mask` and the `title` are inputs — the group cover is 16:9 · `.rectangle` · "Edit cover" (the
/// defaults), the member avatar 1:1 · `.circle` · "Edit photo". The screen draws the chrome AROUND the image — header,
/// toolbar, the frame's dim, its border, corner elbows and edge bars, the thirds / fine grid and the bottom
/// straighten dial with its degree readout — and reports the frame rect;
/// the image and every gesture are the app's, passed in as the `canvas` slot (owner description
/// item 4, R-08). The screen never draws or transforms the image itself.
///
/// Composed only of §4's C-040 PageHeader and two C-102 IconButtons; the straighten dial (ticks,
/// index mark, readout — OQ-007), the frame chrome (border, corner elbows, edge bars — OQ-008), the dim and the
/// two-density grid are §4's screen-local anatomy. Standalone: `identifiedFrom` is null, so no D7
/// template applies.
struct EditCoverScreen<Canvas: View>: View {

    /// image-framing-editor D9: what the dim leaves clear and the border outlines.
    enum Mask: Equatable {
        /// The frame rect itself, with the border, corner elbows and edge bars (the group cover).
        case rectangle
        /// The circle inscribed in the frame (the member avatar): the dim, border and grid follow
        /// the circle; the corner elbows and edge bars belong to a rectangle and are not drawn.
        case circle
    }

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3 gesture-active: the grid shows inside the frame — 3×3 thirds, or 9×9 fine while
        /// `readoutDegrees` is non-nil (§3 Grid density rule).
        var showsGrid: Bool
        /// §3 twisting: the signed integer readout inside the dial; nil = none (fades out).
        var readoutDegrees: Int?
        /// §2 item 4: the straighten value the dial ruler is centred on, ±45°.
        var rotationDegrees: Double
        /// §3 saving: Done spins, Cancel / toolbar / dial / canvas take no taps (OQ-003, D66).
        var saving: Bool
        /// §3 Done disabled: false on a re-edit with no change.
        var doneEnabled: Bool
    }

    let state: State
    /// image-framing-editor D9: the frame's width ÷ height (16:9 the group cover, 1 the avatar).
    var aspect: CGFloat = 16.0 / 9.0
    /// image-framing-editor D9: the mask the dim and border follow.
    var mask: Mask = .rectangle
    /// image-framing-editor D9: the header title ("Edit cover", "Edit photo").
    var title: String = "Edit cover"
    /// §2 item 3 Image slot — the app's content view (e.g. `CoverFramingCanvas`); it fills the
    /// whole canvas area, unclipped, under the dim.
    @ViewBuilder let canvas: () -> Canvas
    /// §2 Frame geometry out: the frame rect in the canvas slot's coordinate space, on layout and
    /// on every size change.
    var onFrameLayout: (CGRect) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}
    var onFlip: () -> Void = {}
    var onRotate90: () -> Void = {}
    /// §3 Dial drag: every change, clamped to ±45.
    var onStraighten: (Double) -> Void = { _ in }
    /// §3 Dial drag: on release.
    var onStraightenEnd: () -> Void = {}

    // §3 Motion: the readout keeps its last value while it fades out after release — ephemeral
    // view state (R-02); the app only clears `readoutDegrees`.
    @SwiftUI.State private var shownDegrees: Int?
    // §3 Dial drag: the value under the centre when the drag began; nil = not dragging (the
    // ruler animates only a change the dial did not cause). Ephemeral view state (R-02).
    @SwiftUI.State private var dragStartDegrees: Double?

    init(
        state: State,
        aspect: CGFloat = 16.0 / 9.0,
        mask: Mask = .rectangle,
        title: String = "Edit cover",
        @ViewBuilder canvas: @escaping () -> Canvas,
        onFrameLayout: @escaping (CGRect) -> Void = { _ in },
        onCancel: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {},
        onFlip: @escaping () -> Void = {},
        onRotate90: @escaping () -> Void = {},
        onStraighten: @escaping (Double) -> Void = { _ in },
        onStraightenEnd: @escaping () -> Void = {}
    ) {
        self.state = state
        self.aspect = aspect
        self.mask = mask
        self.title = title
        self.canvas = canvas
        self.onFrameLayout = onFrameLayout
        self.onCancel = onCancel
        self.onDone = onDone
        self.onFlip = onFlip
        self.onRotate90 = onRotate90
        self.onStraighten = onStraighten
        self.onStraightenEnd = onStraightenEnd
        _shownDegrees = SwiftUI.State(initialValue: state.readoutDegrees)
    }

    // MARK: - §2 constants (values that no §3 state changes)

    private static var cancelLabel: String { "Cancel" }
    private static var doneLabel: String { "Done" }
    /// GAP — edit-cover §2 item 2: "44pt tall" toolbar row; no sizing token.
    private static var toolbarHeight: CGFloat { 44 }
    /// GAP — edit-cover §2 item 3: the canvas "fills the remaining height to the bottom safe
    /// area" — the device canvas (956) minus its top (59) and bottom (34) insets on
    /// iphone-16-pro-max; no device-size token. The page still fills whatever height the app
    /// proposes; this is only its floor (the harness proposes zero height).
    private static var contentRegionHeight: CGFloat { 863 }
    /// GAP — edit-cover §2 item 3 Dim: `color-layout-background` "at 0.6 opacity"; no opacity token.
    private static var dimOpacity: Double { 0.6 }
    /// GAP — edit-cover §2 item 3 Grid: "0.5pt" lines (both densities); no stroke token.
    private static var gridLineWidth: CGFloat { 0.5 }
    /// GAP — edit-cover §2 item 3 Grid: the 9×9 fine grid is `color-white-50` "at 0.6 opacity"; no
    /// opacity token.
    private static var fineGridOpacity: Double { 0.6 }
    /// GAP — edit-cover §2 item 3 Frame chrome (OQ-008): the border is "a continuous 1pt line"; no
    /// stroke token.
    private static var borderWidth: CGFloat { 1 }
    /// GAP — edit-cover §2 item 3 Corner elbows (OQ-008): "each arm 20pt long"; no sizing token.
    private static var elbowArm: CGFloat { 20 }
    /// GAP — edit-cover §2 item 3 Corner elbows + Edge bars (OQ-008): "3pt stroke" / "3pt thick"; no
    /// stroke token.
    private static var elbowStroke: CGFloat { 3 }
    /// GAP — edit-cover §2 item 3 Edge bars (OQ-008): "24pt long"; no sizing token.
    private static var edgeBarLength: CGFloat { 24 }
    /// GAP — edit-cover §3 Motion: the readout "fades out over 0.6s"; no motion token.
    private static var readoutFade: Animation { .easeOut(duration: 0.6) }
    /// GAP — edit-cover §2 item 4 (OQ-007): the dial is "56pt tall"; no sizing token.
    private static var dialHeight: CGFloat { 56 }
    /// GAP — edit-cover §2 item 4: the readout sits in the dial's "upper 20pt".
    private static var dialReadoutHeight: CGFloat { 20 }
    /// GAP — edit-cover §2 item 4: the ruler is "2.4pt per degree".
    private static var pointsPerDegree: CGFloat { 2.4 }
    /// GAP — edit-cover §2 item 4 Range: "±45°".
    private static var dialRange: Double { 45 }
    /// GAP — edit-cover §2 item 4: "a tick every 5°", "every 15° a … major tick".
    private static var tickStep: Int { 5 }
    private static var majorTickStep: Int { 15 }
    /// GAP — edit-cover §2 item 4: ticks "8pt tall", major "14pt"; no sizing token.
    private static var tickHeight: CGFloat { 8 }
    private static var majorTickHeight: CGFloat { 14 }
    /// FLAGGED LITERAL — edit-cover §2 item 4: ticks "1pt wide", the program-wide hairline.
    private static var tickWidth: CGFloat { 1 }
    /// GAP — edit-cover §2 item 4 Index mark: "2×20pt".
    private static var indexMarkSize: CGSize { CGSize(width: 2, height: 20) }
    /// GAP — edit-cover §2 item 4: ticks "fade out over the outer 24pt of each side".
    private static var tickFadeWidth: CGFloat { 24 }
    /// GAP — edit-cover §3 4 saving: the dial "at 0.5 opacity"; no opacity token.
    private static var savingDialOpacity: Double { 0.5 }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // §2 Frame position: the device midline in the page's own coordinates — the page sits
        // between the safe areas, so the screen spans −top … height + bottom — read in the same
        // layout pass as the canvas.
        GeometryReader { page in
            // D22: no ScrollView at the root — §2 "No scroll: the page is fixed."
            VStack(spacing: 0) {
                header
                toolbar
                    .padding(.top, Token.Space.elementGap)          // §2: `space-element-gap` below the header
                canvasArea(screenMidY: (page.size.height + page.safeAreaInsets.bottom - page.safeAreaInsets.top) / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                dial
                    .padding(.horizontal, Token.Space.pageMargin)
                    .padding(.bottom, Token.Space.pageMargin)        // §2 item 4: above the bottom safe area
            }
        }
        .coordinateSpace(.named(Self.pageSpace))
        .frame(maxWidth: .infinity, minHeight: Self.contentRegionHeight, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                         // §2: full-bleed
    }

    // MARK: - §2 item 1: C-040 PageHeader

    private var header: some View {
        PageHeader(
            style: .textButtons,
            title: title,
            rightButtons: [],
            leadingLabel: Self.cancelLabel,
            leadingEnabled: !state.saving,                          // §3 saving (D66)
            trailingLabel: Self.doneLabel,
            trailingEnabled: state.doneEnabled,                     // §3 Done disabled
            trailingLoading: state.saving,                          // §3 saving: C-076 replaces "Done"
            onCancel: onCancel,
            onDone: onDone
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: - §2 item 2: toolbar row

    private var toolbar: some View {
        HStack(spacing: Token.Space.elementGap) {
            IconButton(
                glyph: .arrowLeftRight,
                tone: .default,
                style: .plain,
                selected: false,
                accessibilityLabel: "Flip horizontal",
                onTap: onFlip
            )
            .ui2Element("C-102 IconButton")
            IconButton(
                glyph: .rotateCcw,
                tone: .default,
                style: .plain,
                selected: false,
                accessibilityLabel: "Rotate 90° counter-clockwise",
                onTap: onRotate90
            )
            .ui2Element("C-102 IconButton 2")
        }
        // §3 saving: Flip + Rotate stay visible and ignore taps (OQ-004; C-102 has no disabled look).
        .allowsHitTesting(!state.saving)
        // §2 item 2 (owner, 2026-10-27): the pair is one group centred in the row.
        .frame(maxWidth: .infinity)
        .frame(height: Self.toolbarHeight)
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: - §2 item 3: canvas

    /// The page's coordinate space — the canvas measures its offset from the page's top in it.
    private static var pageSpace: String { "EditCoverScreen.page" }

    /// `screenMidY` is the device midline in the page's coordinates (§2 Frame position).
    private func canvasArea(screenMidY: CGFloat) -> some View {
        GeometryReader { proxy in
            let frame = Self.frameRect(in: proxy.size, aspect: aspect, midY: screenMidY - proxy.frame(in: .named(Self.pageSpace)).minY)
            ZStack(alignment: .topLeading) {
                canvas()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                dim(frame: frame, size: proxy.size)
                grid(frame: frame)
                border(frame: frame)
                if mask == .rectangle {
                    elbows(frame: frame)
                    edgeBars(frame: frame)
                }
            }
            .onAppear { onFrameLayout(frame) }
            // §2 Frame geometry out: the rect moves with the canvas's position as well as its size.
            .onChange(of: frame) { _, rect in onFrameLayout(rect) }
        }
        // §3 saving: the canvas takes no hits.
        .allowsHitTesting(!state.saving)
    }

    /// §2 Frame: full width inside `space-page-margin`, height = width ÷ `aspect` (9⁄16 for the
    /// group cover — OQ-002, group-cover-image D20; square for the avatar — image-framing-editor D9),
    /// its mid-y on the screen's vertical midline (`midY`, in the canvas's coordinates) — clamped
    /// inside the canvas when the canvas is too short to hold it there.
    private static func frameRect(in size: CGSize, aspect: CGFloat, midY: CGFloat) -> CGRect {
        let width = max(0, size.width - Token.Space.pageMargin * 2)
        let height = aspect > 0 ? width / aspect : width
        let top = min(max(0, midY - height / 2), max(0, size.height - height))
        return CGRect(x: Token.Space.pageMargin, y: top, width: width, height: height)
    }

    /// The clear shape inside `frame`: the frame rect, or (image-framing-editor D9) its inscribed circle.
    private func maskPath(_ frame: CGRect) -> Path {
        switch mask {
        case .rectangle: return Path(frame)
        case .circle:
            let side = min(frame.width, frame.height)
            return Path(ellipseIn: CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side))
        }
    }

    /// §2 Dim: `color-layout-background` at 0.6 over the canvas area outside the mask (even-odd).
    private func dim(frame: CGRect, size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addPath(maskPath(frame))
        }
        .fill(Token.layoutBackground.opacity(Self.dimOpacity), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    /// §2 Border (OQ-008): a continuous 1pt `color-text-primary` line on the frame's four edges,
    /// inside the frame rect. Above the grid; always shown; never hit-tested.
    private func border(frame: CGRect) -> some View {
        maskPath(frame.insetBy(dx: Self.borderWidth / 2, dy: Self.borderWidth / 2))
            .stroke(Token.textPrimary, lineWidth: Self.borderWidth)
            .allowsHitTesting(false)
    }

    /// §2 Corner elbows (OQ-008): an L on each frame corner, 20pt arms, 3pt `color-text-primary`,
    /// square ends; the stroke's outer edge sits on the frame edge, so no elbow leaves the frame.
    /// Over the border; always shown; never hit-tested.
    private func elbows(frame: CGRect) -> some View {
        let edge = frame.insetBy(dx: Self.elbowStroke / 2, dy: Self.elbowStroke / 2)
        let arm = Self.elbowArm - Self.elbowStroke / 2
        return Path { path in
            for (corner, dx, dy) in [
                (CGPoint(x: edge.minX, y: edge.minY), CGFloat(1), CGFloat(1)),
                (CGPoint(x: edge.maxX, y: edge.minY), -1, 1),
                (CGPoint(x: edge.minX, y: edge.maxY), 1, -1),
                (CGPoint(x: edge.maxX, y: edge.maxY), -1, -1)
            ] {
                path.move(to: CGPoint(x: corner.x + arm * dx, y: corner.y))
                path.addLine(to: corner)
                path.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * dy))
            }
        }
        .stroke(Token.textPrimary, style: StrokeStyle(lineWidth: Self.elbowStroke, lineCap: .butt, lineJoin: .miter))
        .allowsHitTesting(false)
    }

    /// §2 Edge bars (OQ-008): a 24×3pt `color-text-primary` bar centred on each edge's midpoint,
    /// flush on the frame's outer edge. Over the border; always shown; never hit-tested.
    private func edgeBars(frame: CGRect) -> some View {
        let half = Self.edgeBarLength / 2
        let thick = Self.elbowStroke
        return Path { path in
            path.addRect(CGRect(x: frame.midX - half, y: frame.minY, width: Self.edgeBarLength, height: thick))
            path.addRect(CGRect(x: frame.midX - half, y: frame.maxY - thick, width: Self.edgeBarLength, height: thick))
            path.addRect(CGRect(x: frame.minX, y: frame.midY - half, width: thick, height: Self.edgeBarLength))
            path.addRect(CGRect(x: frame.maxX - thick, y: frame.midY - half, width: thick, height: Self.edgeBarLength))
        }
        .fill(Token.textPrimary)
        .allowsHitTesting(false)
    }

    /// §2 Grid: inside the frame, 0.5pt `color-white-50`, clipped to the frame rect so no line
    /// overshoots onto the dim. §3 Grid density rule: 3×3 thirds while `readoutDegrees` is nil,
    /// the 9×9 fine grid (at 0.6) while it is non-nil; both fade and cross-fade with
    /// `motion-chip-select`.
    private func grid(frame: CGRect) -> some View {
        let fine = state.readoutDegrees != nil
        return ZStack {
            gridLines(frame: frame, divisions: 3)
                .opacity(state.showsGrid && !fine ? 1 : 0)
            gridLines(frame: frame, divisions: 9)
                .opacity(state.showsGrid && fine ? Self.fineGridOpacity : 0)
        }
        .clipShape(maskPath(frame))
        .animation(Token.Motion.chipSelect, value: state.showsGrid)
        .animation(Token.Motion.chipSelect, value: fine)
        .allowsHitTesting(false)
    }

    /// `divisions − 1` vertical and horizontal lines at k/`divisions` of the frame, edge to edge.
    private func gridLines(frame: CGRect, divisions: Int) -> some View {
        Path { path in
            for k in 1..<divisions {
                let x = frame.minX + frame.width * CGFloat(k) / CGFloat(divisions)
                let y = frame.minY + frame.height * CGFloat(k) / CGFloat(divisions)
                path.move(to: CGPoint(x: x, y: frame.minY))
                path.addLine(to: CGPoint(x: x, y: frame.maxY))
                path.move(to: CGPoint(x: frame.minX, y: y))
                path.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
        }
        .stroke(Token.white50, lineWidth: Self.gridLineWidth)
    }

    // MARK: - §2 item 4: straighten dial

    private var dial: some View {
        VStack(spacing: 0) {
            readout
                .frame(height: Self.dialReadoutHeight)
            ruler
                .frame(height: Self.dialHeight - Self.dialReadoutHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.dialHeight)
        .contentShape(Rectangle())
        .horizontalPan(onChanged: straighten, onEnded: endStraighten)
        // §3 saving: the dial stays visible at 0.5 and ignores drags.
        .opacity(state.saving ? Self.savingDialOpacity : 1)
        .allowsHitTesting(!state.saving)
        .onChange(of: state.readoutDegrees) { _, degrees in
            if let degrees { shownDegrees = degrees }
        }
    }

    /// §2 Readout: "-12°", `type-body-sm`, `color-text-primary`, centred in the dial's upper 20pt;
    /// fades out 0.6s after it clears.
    private var readout: some View {
        Text(shownDegrees.map { "\($0)°" } ?? "")
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textPrimary)
            .fixedSize()
            .frame(maxWidth: .infinity)
            .opacity(state.readoutDegrees == nil ? 0 : 1)
            .animation(state.readoutDegrees == nil ? Self.readoutFade : nil, value: state.readoutDegrees)
            .accessibilityHidden(state.readoutDegrees == nil)
    }

    /// §2 Ticks + Index mark: the ruler slides so `rotationDegrees` sits under the fixed centre mark.
    private var ruler: some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let midY = proxy.size.height / 2
            ZStack(alignment: .topLeading) {
                Path { path in
                    let limit = Int(Self.dialRange)
                    for degree in stride(from: -limit, through: limit, by: Self.tickStep) {
                        let height = degree % Self.majorTickStep == 0 ? Self.majorTickHeight : Self.tickHeight
                        let x = midX + CGFloat(Double(degree) - state.rotationDegrees) * Self.pointsPerDegree
                        path.move(to: CGPoint(x: x, y: midY - height / 2))
                        path.addLine(to: CGPoint(x: x, y: midY + height / 2))
                    }
                }
                .stroke(Token.white50, lineWidth: Self.tickWidth)
                // §3 Motion: no animation while dragging; any other change ≈150ms ease-out.
                .animation(dragStartDegrees == nil ? Token.Motion.chipSelect : nil, value: state.rotationDegrees)
                .mask(tickFade)
                Capsule()
                    .fill(Token.accent)
                    .frame(width: Self.indexMarkSize.width, height: Self.indexMarkSize.height)
                    .position(x: midX, y: midY)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Straighten")
        .accessibilityValue("\(Int(state.rotationDegrees.rounded()))°")
    }

    /// §2 Ticks "fade out over the outer 24pt of each side".
    private var tickFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.tickFadeWidth)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.tickFadeWidth)
        }
    }

    /// §3 Dial drag: the ruler follows the finger (2.4pt per degree), clamped to ±45.
    private func straighten(_ pan: HorizontalPanValue) {
        let start = dragStartDegrees ?? state.rotationDegrees
        if dragStartDegrees == nil { dragStartDegrees = start }
        let degrees = start - Double(pan.translation / Self.pointsPerDegree)
        onStraighten(min(Self.dialRange, max(-Self.dialRange, degrees)))
    }

    private func endStraighten(_ pan: HorizontalPanValue) {
        dragStartDegrees = nil
        onStraightenEnd()
    }
}

// MARK: - §3 samples (single-sourced: the previews below and the capture case read these)

extension EditCoverScreen.State {
    /// §3 1 default.
    static var `default`: Self {
        .init(showsGrid: false, readoutDegrees: nil, rotationDegrees: 0, saving: false, doneEnabled: true)
    }
    /// §3 2 gesture-active.
    static var gestureActive: Self {
        .init(showsGrid: true, readoutDegrees: nil, rotationDegrees: 0, saving: false, doneEnabled: true)
    }
    /// §3 3 twisting.
    static var twisting: Self {
        .init(showsGrid: true, readoutDegrees: -12, rotationDegrees: -12, saving: false, doneEnabled: true)
    }
    /// §3 4 saving.
    static var saving: Self {
        .init(showsGrid: false, readoutDegrees: nil, rotationDegrees: 0, saving: true, doneEnabled: true)
    }
    /// §3 5 Done disabled.
    static var doneDisabled: Self {
        .init(showsGrid: false, readoutDegrees: nil, rotationDegrees: 0, saving: false, doneEnabled: false)
    }
}

// MARK: - Previews (one per §3 state, in §3 order)

/// The caller's slot in a preview: the catalog's group cover `image-10` at the zoom floor
/// (full frame width), centred — standing in for the app's `CoverFramingCanvas`.
private struct EditCoverPreviewCanvas: View {
    var body: some View {
        AsyncImage(url: URL(string: "http://localhost:5961/api/projects/makeready/images/image-10")) { image in
            image.resizable().aspectRatio(contentMode: .fit)
        } placeholder: {
            Color.clear
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }
}

#Preview("default") {
    EditCoverScreen(state: .default) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("gesture-active") {
    EditCoverScreen(state: .gestureActive) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("twisting") {
    EditCoverScreen(state: .twisting) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("saving") {
    EditCoverScreen(state: .saving) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("avatar 1:1 circle") {
    EditCoverScreen(state: .gestureActive, aspect: 1, mask: .circle, title: "Edit photo") { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Done disabled") {
    EditCoverScreen(state: .doneDisabled) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
