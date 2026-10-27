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
/// inside a fixed 16:9 frame, then saves. The screen draws the chrome AROUND the image — header,
/// toolbar, the frame's dim, the thirds grid and the bottom straighten dial with its degree
/// readout — and reports the frame rect;
/// the image and every gesture are the app's, passed in as the `canvas` slot (owner description
/// item 4, R-08). The screen never draws or transforms the image itself.
///
/// Composed only of §4's C-040 PageHeader and two C-102 IconButtons; the straighten dial (ticks,
/// index mark, readout — OQ-007), the dim and the grid are §4's screen-local anatomy. Standalone: `identifiedFrom` is null, so no D7
/// template applies.
struct EditCoverScreen<Canvas: View>: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3 gesture-active: the rule-of-thirds grid shows inside the frame.
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

    private static var title: String { "Edit cover" }
    private static var cancelLabel: String { "Cancel" }
    private static var doneLabel: String { "Done" }
    /// §2 item 3: the frame is fixed 16:9 (OQ-002, group-cover-image D20).
    private static var frameAspect: CGFloat { 16.0 / 9.0 }
    /// GAP — edit-cover §2 item 2: "44pt tall" toolbar row; no sizing token.
    private static var toolbarHeight: CGFloat { 44 }
    /// GAP — edit-cover §2 item 3: the canvas "fills the remaining height to the bottom safe
    /// area" — the device canvas (956) minus its top (59) and bottom (34) insets on
    /// iphone-16-pro-max; no device-size token. The page still fills whatever height the app
    /// proposes; this is only its floor (the harness proposes zero height).
    private static var contentRegionHeight: CGFloat { 863 }
    /// GAP — edit-cover §2 item 3 Dim: `color-layout-background` "at 0.6 opacity"; no opacity token.
    private static var dimOpacity: Double { 0.6 }
    /// FLAGGED LITERAL — edit-cover §2 item 3 Grid: 1pt lines, the program-wide hairline; no stroke token.
    private static var gridLineWidth: CGFloat { 1 }
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
            title: Self.title,
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
            Spacer(minLength: 0)                                    // §2 trailing: nothing
        }
        // §3 saving: Flip + Rotate stay visible and ignore taps (OQ-004; C-102 has no disabled look).
        .allowsHitTesting(!state.saving)
        .frame(height: Self.toolbarHeight)
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: - §2 item 3: canvas

    /// The page's coordinate space — the canvas measures its offset from the page's top in it.
    private static var pageSpace: String { "EditCoverScreen.page" }

    /// `screenMidY` is the device midline in the page's coordinates (§2 Frame position).
    private func canvasArea(screenMidY: CGFloat) -> some View {
        GeometryReader { proxy in
            let frame = Self.frameRect(in: proxy.size, midY: screenMidY - proxy.frame(in: .named(Self.pageSpace)).minY)
            ZStack(alignment: .topLeading) {
                canvas()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                dim(frame: frame, size: proxy.size)
                grid(frame: frame)
            }
            .onAppear { onFrameLayout(frame) }
            // §2 Frame geometry out: the rect moves with the canvas's position as well as its size.
            .onChange(of: frame) { _, rect in onFrameLayout(rect) }
        }
        // §3 saving: the canvas takes no hits.
        .allowsHitTesting(!state.saving)
    }

    /// §2 Frame: full width inside `space-page-margin`, height = width × 9⁄16, its mid-y on the
    /// screen's vertical midline (`midY`, in the canvas's coordinates) — clamped inside the canvas
    /// when the canvas is too short to hold it there.
    private static func frameRect(in size: CGSize, midY: CGFloat) -> CGRect {
        let width = max(0, size.width - Token.Space.pageMargin * 2)
        let height = width / frameAspect
        let top = min(max(0, midY - height / 2), max(0, size.height - height))
        return CGRect(x: Token.Space.pageMargin, y: top, width: width, height: height)
    }

    /// §2 Dim: `color-layout-background` at 0.6 over the canvas area outside the frame (even-odd).
    private func dim(frame: CGRect, size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(frame)
        }
        .fill(Token.layoutBackground.opacity(Self.dimOpacity), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    /// §2 Grid: rule of thirds inside the frame, 1pt `color-white-50`; fades with `motion-chip-select`.
    private func grid(frame: CGRect) -> some View {
        Path { path in
            for third in 1...2 {
                let x = frame.minX + frame.width * CGFloat(third) / 3
                let y = frame.minY + frame.height * CGFloat(third) / 3
                path.move(to: CGPoint(x: x, y: frame.minY))
                path.addLine(to: CGPoint(x: x, y: frame.maxY))
                path.move(to: CGPoint(x: frame.minX, y: y))
                path.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
        }
        .stroke(Token.white50, lineWidth: Self.gridLineWidth)
        .opacity(state.showsGrid ? 1 : 0)
        .animation(Token.Motion.chipSelect, value: state.showsGrid)
        .allowsHitTesting(false)
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

#Preview("Done disabled") {
    EditCoverScreen(state: .doneDisabled) { EditCoverPreviewCanvas() }
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
