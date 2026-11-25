//
//  VideoEditorScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-editor in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — none: no server data.
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import AVFoundation
import SwiftUI
import UIKit

/// Video Editor — timed, styled text layers and captions over a recorded clip. The view is pure
/// (§5): limits, timing, undo, transcription and the player are the app's; it reports intents.
///
/// Composed of §4's parts; screen-local (§4): the preview surface, the guides
/// (C-091's look, deviation 3) and the message line. C-066 is presented in place (§6).
/// Standalone: `identifiedFrom` is null, so no D7 template applies.
struct VideoEditorScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §5 `style`, shared by a layer and the text tool. Sizes are wu.
        struct Style: Equatable {
            enum Label: String {
                case none, solidDark, solidLight
            }

            enum Alignment: String {
                case left, center, right
            }

            /// C-092's font key: display · sans · serif · mono · classic.
            var font: String
            /// 400 · 500 · 700.
            var weight: Int
            var size: Double
            /// `#RRGGBB`.
            var color: String
            var label: Label
            var alignment: Alignment
        }

        /// §5 `layers`, oldest to newest; captions in time order.
        struct Layer: Identifiable, Equatable {
            enum Kind: String {
                case text, caption
            }

            var id: String
            var kind: Kind
            var text: String
            var style: Style
            /// Unit point in the frame rect.
            var centre: CGPoint
            var scale: Double = 1
            /// Radians.
            var rotation: Double = 0
            var startMs: Int
            var endMs: Int
        }

        enum Captions: String {
            case none, transcribing, added, unavailable
        }

        /// §5: the presented confirm (states 10 and 12).
        enum Confirm: String {
            case none, removeCaptions, cancel
        }

        /// §5 `textTool`; nil = closed.
        struct TextTool: Equatable {
            var text: String
            var style: Style
            /// False for a caption's Edit.
            var stylePanels: Bool
        }

        /// §2 tool row; "" = no rail open.
        enum Tool: String {
            case none = "", colour, alignment, font, label
        }

        var layers: [Layer] = []
        var selectedID: String?
        var playheadMs: Int = 0
        var durationMs: Int = 15000
        var playing: Bool = false
        /// §5 `frameAspect`, width / height. Renamed: the fixture's `frameAspect` is C-158's String.
        var frameAspectRatio: Double = 9.0 / 16.0
        /// Catalog URLs, resolved from `Ui2ImageCache`; the app passes `filmstripImages`.
        var filmstrip: [String] = []
        /// The capture's still in place of `feed`; "" = none.
        var stillImageURL: String = ""
        var canUndo: Bool = false
        var canSplit: Bool = false
        var captions: Captions = .none
        var captionsReason: String = ""
        var limitMessage: String = ""
        var textTool: TextTool?
        var confirm: Confirm = .none
        /// Seeds the text tool's open rail.
        var openTool: Tool = .none
        /// Seeds state 6: the layer drawn as being dragged; "" = none.
        var manipulatingID: String = ""
    }

    // MARK: - §5 Public constants

    /// FLAGGED LITERAL — video-editor §2: the 392 wu edit slot.
    static let editSlotWidth: CGFloat = 392
    /// §3 Caption house style and placement (OQ-video-editor-009).
    static let captionStyle = State.Style(
        font: "sans", weight: 700, size: 24, color: "#FFFFFF", label: .solidDark, alignment: .center
    )
    static let captionCentre = CGPoint(x: 0.5, y: 0.78)
    /// §3 Default text style.
    static let defaultTextStyle = State.Style(
        font: "sans", weight: 700, size: 38, color: "#FFFFFF", label: .none, alignment: .center
    )
    static let newTextCentre = CGPoint(x: 0.5, y: 0.5)
    /// §3: text input stops here; a caption's at max(this, its current length).
    static let textLimit = 200
    static let limitCopy = "Up to 20 text layers"
    static let removeCaptionsTitle = "Remove captions?"
    static let removeCaptionsMessage = "Every caption is removed from this video."
    static let removeCaptionsAction = "Remove captions"
    static let keepCaptionsAction = "Keep captions"
    static let discardTitle = "Discard changes?"
    static let discardMessage = "The text and captions go back to how they were."
    static let discardAction = "Discard changes"
    static let keepEditingAction = "Keep editing"

    // MARK: - Inputs

    let state: State
    /// §5 host input: the video's layer; nil = the state's still.
    var feed: CALayer?
    /// §5 `filmstrip` from the app; nil = the state's catalog URLs.
    var filmstripImages: [Image]?
    /// §5 host input: how far the keyboard reaches above this view's bottom edge; lifts the text tool.
    var keyboardInset: CGFloat = 0
    var onCancel: () -> Void = {}
    var onUndo: () -> Void = {}
    var onDone: () -> Void = {}
    var onPlayPause: () -> Void = {}
    var onScrub: (Int) -> Void = { _ in }
    var onSelect: (String) -> Void = { _ in }
    var onDeselect: () -> Void = {}
    var onText: () -> Void = {}
    /// Captions was tapped; with captions present the app raises state 10.
    var onCaptions: () -> Void = {}
    var onRemoveCaptions: () -> Void = {}
    var onSplit: () -> Void = {}
    var onEdit: (String) -> Void = { _ in }
    var onDelete: (String) -> Void = { _ in }
    var onTrimStart: (String, Int) -> Void = { _, _ in }
    var onTrimEnd: (String, Int) -> Void = { _, _ in }
    var onSlide: (String, Int) -> Void = { _, _ in }
    /// id, centre (unit point), scale, rotation (radians) — live.
    var onPlace: (String, CGPoint, Double, Double) -> Void = { _, _, _, _ in }
    var onGestureEnded: () -> Void = {}
    var onTextCommit: (String, State.Style) -> Void = { _, _ in }
    var onTextCancel: () -> Void = {}
    /// Discard, from state 12.
    var onConfirmCancel: () -> Void = {}
    var onDismissConfirm: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VideoEditorFill {
            ZStack(alignment: .top) {
                column
                    .ignoresSafeArea(.keyboard)
                    .allowsHitTesting(!isCovered)
                    .accessibilityHidden(isCovered)
                if let tool = state.textTool {
                    VideoEditorTextTool(
                        initial: tool,
                        openTool: state.openTool,
                        keyboardInset: keyboardInset,
                        onCommit: onTextCommit,
                        onCancel: onTextCancel
                    )
                    .accessibilityAddTraits(.isModal)
                    .transition(.opacity)
                }
                confirmLayer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Token.layoutBackground)
        .environment(\.colorScheme, .dark)          // §2: dark appearance
    }

    /// FLAGGED LITERAL — video-editor §2 item 6 (owner 2026-11-24, video-polish D10): 16 pt.
    private static let toolbarGap: CGFloat = 16

    private var isCovered: Bool { state.textTool != nil || state.confirm != .none }

    /// §2 items 1–7, top → bottom.
    private var column: some View {
        VStack(spacing: 0) {
            VideoEditorTopBar(canUndo: state.canUndo, onCancel: onCancel, onUndo: onUndo, onDone: onDone)
                .ui2Element("C-157 VideoEditorTopBar")
                // §2 Text tool: C-040 sits in C-157's place.
                .opacity(state.textTool == nil ? 1 : 0)
            preview
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.top, Token.Space.elementGap)
                .padding(.bottom, Token.Space.sectionGap)
            timeline
            toolbar
                // The tool row can rest here when no keyboard is up.
                .opacity(state.textTool == nil ? 1 : 0)
                .padding(.top, Self.toolbarGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var preview: some View {
        VideoEditorPreview(
            layers: state.layers.filter { $0.startMs <= state.playheadMs && state.playheadMs < $0.endMs },
            // The edited layer is drawn by the text tool, not twice.
            hiddenID: state.textTool == nil ? nil : state.selectedID,
            aspect: CGFloat(state.frameAspectRatio),
            feed: feed,
            still: Self.image(state.stillImageURL),
            manipulatingID: state.manipulatingID,
            enabled: !isCovered,
            onSelect: onSelect,
            onDeselect: onDeselect,
            onPlace: onPlace,
            onGestureEnded: onGestureEnded
        )
        .overlay(alignment: .bottom) { messageLine }
        .ui2Element("Preview")
    }

    /// §3 Message line (OQ-video-editor-010).
    @ViewBuilder private var messageLine: some View {
        if let message {
            Text(message)
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .padding(Token.Space.elementGap)
                .background(Token.black60, in: Capsule())
                .ui2Element("Message line")
        }
    }

    private var message: String? {
        if !state.limitMessage.isEmpty { return state.limitMessage }
        guard state.captions == .unavailable, !state.captionsReason.isEmpty else { return nil }
        return state.captionsReason
    }

    private var timeline: some View {
        let textLayers = state.layers.filter { $0.kind == .text }
        let captions = state.layers.filter { $0.kind == .caption }.sorted { $0.startMs < $1.startMs }
        return VideoEditorTimeline(
            playing: state.playing,
            onPlayPause: onPlayPause,
            playheadMs: state.playheadMs,
            onScrub: onScrub,
            durationMs: state.durationMs,
            filmstrip: filmstripImages ?? state.filmstrip.compactMap(Self.image)
        ) {
            // §2 item 5: newest first.
            ForEach(textLayers.reversed()) { layer in
                track(.text, [layer])
                    .ui2Element("C-154 VideoEditorLayerTrack \(layer.id)")
            }
            if !captions.isEmpty {
                track(.captions, captions)
                    .ui2Element("C-154 VideoEditorLayerTrack")
            }
        }
        .ui2Element("C-153 VideoEditorTimeline")
    }

    private func track(_ kind: VideoEditorLayerTrack.Kind, _ layers: [State.Layer]) -> some View {
        VideoEditorLayerTrack(
            kind: kind,
            bars: layers.map { .init(id: $0.id, text: $0.text, startMs: $0.startMs, endMs: $0.endMs) },
            selectedID: state.selectedID,
            onSelect: onSelect,
            onTrimStart: onTrimStart,
            onTrimEnd: onTrimEnd,
            onSlide: onSlide,
            onGestureEnded: onGestureEnded
        )
    }

    private var selectedLayer: State.Layer? {
        state.layers.first { $0.id == state.selectedID }
    }

    /// §2 item 7 / §3 Motion: the two toolbars cross-fade in one region.
    private var toolbar: some View {
        ZStack {
            if let layer = selectedLayer {
                VideoEditorLayerToolbar(
                    text: layer.text,
                    startMs: layer.startMs,
                    endMs: layer.endMs,
                    canSplit: state.canSplit,
                    onSplit: onSplit,
                    onEdit: { onEdit(layer.id) },
                    onDelete: { onDelete(layer.id) }
                )
                .ui2Element("C-156 VideoEditorLayerToolbar")
                .transition(toolbarFade)
            } else {
                VideoEditorToolbar(
                    transcribing: state.captions == .transcribing,
                    onText: onText,
                    onCaptions: onCaptions
                )
                .ui2Element("C-155 VideoEditorToolbar")
                .transition(toolbarFade)
            }
        }
        .animation(reduceMotion ? nil : Token.Motion.menuFadeIn, value: selectedLayer == nil)
    }

    private var toolbarFade: AnyTransition {
        reduceMotion ? .identity : .asymmetric(
            insertion: .opacity.animation(Token.Motion.menuFadeIn),
            removal: .opacity.animation(Token.Motion.menuFadeOut)
        )
    }

    // MARK: - §3 states 10 and 12

    @ViewBuilder private var confirmLayer: some View {
        switch state.confirm {
        case .none:
            EmptyView()
        case .removeCaptions:
            confirmation(title: Self.removeCaptionsTitle, message: Self.removeCaptionsMessage,
                         action: Self.removeCaptionsAction, keep: Self.keepCaptionsAction,
                         onConfirm: onRemoveCaptions)
        case .cancel:
            confirmation(title: Self.discardTitle, message: Self.discardMessage,
                         action: Self.discardAction, keep: Self.keepEditingAction,
                         onConfirm: onConfirmCancel)
        }
    }

    /// C-066 drawn in place over `color-scrim`, at C-066's own edge inset.
    private func confirmation(title: String, message: String, action: String, keep: String,
                              onConfirm: @escaping () -> Void) -> some View {
        ZStack(alignment: .bottom) {
            Token.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismissConfirm)
                .accessibilityHidden(true)
                .ui2Element("Scrim")
            ActionMenuOverlay(
                title: title,
                message: message,
                // C-066 §3 Confirmation draws no glyph; the name only completes the item.
                actions: [.init(glyph: GlyphName.trash2.rawValue, label: action, tone: .destructive)],
                doneLabel: keep,
                onSelect: { _ in onConfirm() },
                onDone: onDismissConfirm
            )
            .ui2Element("C-066 ActionMenuOverlay")
            .padding(.horizontal, ActionMenuMotion.edgeInset)
            .padding(.bottom, ActionMenuMotion.edgeInset)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismissConfirm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private static func image(_ raw: String) -> Image? {
        guard !raw.isEmpty, let url = URL(string: raw),
              let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
    }
}

// MARK: - Page frame

/// Takes the height it is offered. With none offered (the capture's sizing pass) it states the
/// device canvas's content height.
private struct VideoEditorFill: Layout {
    /// GAP — video-editor §2 "takes all remaining height": the device canvas 956 less its 59 top
    /// and 34 bottom safe areas (iphone-16-pro-max); no device-size token.
    private static let contentHeight: CGFloat = 863

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = proposal.height ?? 0
        return CGSize(
            width: proposal.width ?? 0,
            height: height > 0 && height.isFinite ? height : Self.contentHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

// MARK: - Values

private enum VideoEditorValue {
    /// A colour is the leader's data, decoded from its #rrggbb.
    static func color(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return Token.textPrimary }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    static func hex(_ color: Color, in environment: EnvironmentValues) -> String {
        let resolved = color.resolve(in: environment)
        func byte(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }

    static func font(_ key: String) -> CanvasTextObject.Font {
        switch key {
        case "display": return .display
        case "serif": return .serif
        case "mono": return .mono
        case "classic": return .classic
        default: return .sans                               // C-092 §2: an unknown key is `sans`
        }
    }

    static func weight(_ value: Int) -> CanvasTextObject.Weight {
        switch value {
        case 400: return .regular
        case 500: return .medium
        default: return .bold
        }
    }

    static func alignment(_ value: VideoEditorScreen.State.Style.Alignment) -> CanvasTextObject.Alignment {
        switch value {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    static func label(_ value: VideoEditorScreen.State.Style.Label) -> CanvasTextObject.Label {
        switch value {
        case .none: return .none
        case .solidDark: return .solidDark
        case .solidLight: return .solidLight
        }
    }
}

// MARK: - Preview (screen-local: deviations 2 and 3)

private struct VideoEditorPreview: View {
    typealias Layer = VideoEditorScreen.State.Layer

    let layers: [Layer]
    let hiddenID: String?
    let aspect: CGFloat
    let feed: CALayer?
    let still: Image?
    let manipulatingID: String
    let enabled: Bool
    let onSelect: (String) -> Void
    let onDeselect: () -> Void
    let onPlace: (String, CGPoint, Double, Double) -> Void
    let onGestureEnded: () -> Void

    private struct Place: Equatable {
        var id: String
        var centre: CGPoint
        var scale: Double
        var rotation: Double
    }

    private struct Engaged: Equatable {
        var x: Snap?
        var y: Snap?
    }

    /// One snap target on one axis, frame wu: which line of the layer meets it, and where.
    private struct Snap: Equatable {
        /// nil = a frame centre line; else the other layer's id.
        var source: String?
        /// −1 leading, 0 centre, 1 trailing.
        var anchor: CGFloat
        var value: CGFloat
    }

    // R-02 / R-31 ephemeral: measurements and the gesture in flight.
    @SwiftUI.State private var sizes: [String: CGSize] = [:]
    @SwiftUI.State private var glyphs: [String: CGRect] = [:]
    @SwiftUI.State private var touchedID: String?
    @SwiftUI.State private var live: Place?
    @SwiftUI.State private var active: Set<CanvasManipulation.Kind> = []
    @SwiftUI.State private var moveBase: CGPoint = .zero
    @SwiftUI.State private var scaleBase: Double = 1
    @SwiftUI.State private var rotationBase: Double = 0
    @SwiftUI.State private var engaged = Engaged()
    @SwiftUI.State private var engagedAngle: Double?
    @SwiftUI.State private var guides: [ActivityCanvasGuideSegment] = []
    private enum Geometry {
        /// §2: 1 wu = the frame's short side / 440.
        static let reference: CGFloat = 440
        /// FLAGGED LITERAL — video-editor §2: 1 pt guides.
        static let guide: CGFloat = 1
        /// FLAGGED LITERAL — the 44 pt minimum touch box.
        static let minHit: CGFloat = 44
        /// FLAGGED LITERAL — video-editor §3: engage 8 pt, release 12 pt.
        static let engage: CGFloat = 8
        static let release: CGFloat = 12
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = frameRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                frameContent(frame.size)
                    .frame(width: frame.width, height: frame.height)
                    // §2: `radius-card`, clipped — the layers and C-158 alike.
                    .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
                    .ui2Element("Frame")
                    .offset(x: frame.minX, y: frame.minY)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                let point = CGPoint(x: tap.location.x - frame.minX, y: tap.location.y - frame.minY)
                if let id = hit(point, frame: frame.size, textOnly: false) { onSelect(id) } else { onDeselect() }
            })
            .background(bridge(frame))
        }
        .onChange(of: enabled) { _, now in
            if !now { cancelGesture() }
        }
    }

    /// §2: `frameAspect` fitted and centred.
    private func frameRect(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0, aspect > 0 else { return .zero }
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func unit(_ frame: CGSize) -> CGFloat {
        max(min(frame.width, frame.height) / Geometry.reference, .leastNonzeroMagnitude)
    }

    private func frameContent(_ frame: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            video
            ForEach(ordered) { layer in
                layerView(layer, frame: frame)
            }
            manipulationOverlays(frame)
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
    }

    /// §2 Preview, backmost: the feed, else the still, else the page colour.
    @ViewBuilder private var video: some View {
        Group {
            if let feed {
                VideoEditorFeed(layer: feed)
            } else if let still {
                Color.clear
                    .overlay { still.resizable().scaledToFill() }
                    .clipped()
            } else {
                Token.layoutBackground
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video preview")
        .accessibilityAddTraits(.isImage)
        .ui2Element("Video")
    }

    /// §3: captions first, then text layers oldest to newest.
    private var ordered: [Layer] {
        let shown = layers.filter { $0.id != hiddenID }
        return shown.filter { $0.kind == .caption } + shown.filter { $0.kind == .text }
    }

    // MARK: Layers

    private func layerView(_ layer: Layer, frame: CGSize) -> some View {
        let u = unit(frame)
        let place = place(of: layer)
        return CanvasTextObject(
            text: layer.text,
            font: VideoEditorValue.font(layer.style.font),
            weight: VideoEditorValue.weight(layer.style.weight),
            size: CGFloat(layer.style.size),
            color: VideoEditorValue.color(layer.style.color),
            alignment: VideoEditorValue.alignment(layer.style.alignment),
            label: VideoEditorValue.label(layer.style.label),
            transform: .init(
                position: .zero,
                scale: CGFloat(place.scale),
                rotation: .radians(place.rotation),
                width: VideoEditorScreen.editSlotWidth
            ),
            manipulation: .host,
            editing: false,
            onTextBounds: { rect in if glyphs[layer.id] != rect { glyphs[layer.id] = rect } }
        )
        .ui2Element("C-092 CanvasTextObject \(layer.id)")
        // The block states its own height whatever the frame's (a landscape frame is short).
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { sizes[layer.id] = $0 }
        .scaleEffect(u)
        .position(CGPoint(x: place.centre.x * frame.width, y: place.centre.y * frame.height))
        // The preview resolves touches by the drawn glyphs, not C-092's 392 wu block.
        .allowsHitTesting(false)
        .accessibilityAction { onSelect(layer.id) }
    }

    private func place(of layer: Layer) -> Place {
        if let live, live.id == layer.id { return live }
        return Place(id: layer.id, centre: layer.centre, scale: layer.scale, rotation: layer.rotation)
    }

    /// The layer's glyph box: size (wu, unrotated, scaled) and its centre's offset from the layer's
    /// centre (activities-editor §29: glyphs, not the layout box).
    private func glyphBox(_ place: Place) -> (size: CGSize, shift: CGVector) {
        let layout = sizes[place.id] ?? CGSize(width: VideoEditorScreen.editSlotWidth, height: 0)
        var rect = CGRect(origin: .zero, size: layout)
        if let measured = glyphs[place.id], measured.width > 0, measured.height > 0 { rect = measured }
        let dx = (rect.midX - layout.width / 2) * place.scale
        let dy = (rect.midY - layout.height / 2) * place.scale
        return (
            CGSize(width: rect.width * place.scale, height: rect.height * place.scale),
            CGVector(
                dx: dx * cos(place.rotation) - dy * sin(place.rotation),
                dy: dx * sin(place.rotation) + dy * cos(place.rotation)
            )
        )
    }

    /// The rotated glyph box in frame wu.
    private func bounds(_ place: Place, frame: CGSize) -> CGRect {
        let u = unit(frame)
        let box = glyphBox(place)
        return ActivitiesEditorScreen.rotatedBounds(
            center: CGPoint(
                x: place.centre.x * frame.width / u + box.shift.dx,
                y: place.centre.y * frame.height / u + box.shift.dy
            ),
            size: box.size,
            rotation: .radians(place.rotation)
        )
    }

    /// The topmost layer whose box (at least 44 pt each way) holds `point`, in frame points.
    private func hit(_ point: CGPoint, frame: CGSize, textOnly: Bool) -> String? {
        let u = unit(frame)
        guard CGRect(origin: .zero, size: frame).contains(point) else { return nil }
        return ordered.reversed().first { layer in
            if textOnly, layer.kind != .text { return false }
            let place = place(of: layer)
            let box = glyphBox(place)
            let dx = point.x - place.centre.x * frame.width - box.shift.dx * u
            let dy = point.y - place.centre.y * frame.height - box.shift.dy * u
            let x = dx * cos(-place.rotation) - dy * sin(-place.rotation)
            let y = dx * sin(-place.rotation) + dy * cos(-place.rotation)
            return abs(x) <= max(box.size.width * u, Geometry.minHit) / 2
                && abs(y) <= max(box.size.height * u, Geometry.minHit) / 2
        }?.id
    }

    // MARK: Manipulation overlays

    /// State 6 seeded, or a gesture in flight.
    private var seededPlace: Place? {
        layers.first { $0.id == manipulatingID && $0.kind == .text }.map { place(of: $0) }
    }

    private func manipulationOverlays(_ frame: CGSize) -> some View {
        let moving = !active.isEmpty || seededPlace != nil
        return ZStack(alignment: .topLeading) {
            if moving {
                snapGuides(frame)
                UnsafeBandOverlay()
                    .ui2Element("C-158 UnsafeBandOverlay")
            }
        }
        .allowsHitTesting(false)
    }

    private func snapGuides(_ frame: CGSize) -> some View {
        let u = unit(frame)
        var segments = guides
        if active.isEmpty, let seededPlace {
            segments = snapped(seededPlace, frame: frame, engaged: Engaged()).guides
        }
        return Path { path in
            for segment in segments {
                path.move(to: CGPoint(x: segment.from.x * u, y: segment.from.y * u))
                path.addLine(to: CGPoint(x: segment.to.x * u, y: segment.to.y * u))
            }
        }
        .stroke(Token.white80, lineWidth: Geometry.guide)
        .ui2Element("Snap guides")
        .accessibilityHidden(true)
    }

    // MARK: Gestures

    private func bridge(_ frame: CGRect) -> some View {
        CanvasManipulation(
            accepts: { point in enabled && frame.contains(point) },
            canBegin: { _ in enabled && (live?.id ?? touchedID) != nil },
            onUpdate: { manipulate($0, frame: frame) },
            onTouchDown: { point in
                touchedID = point.flatMap {
                    hit(CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY), frame: frame.size, textOnly: true)
                }
            },
            onManipulation: {},
            onAllUp: { touchedID = nil }
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func manipulate(_ update: CanvasManipulation.Update, frame: CGRect) {
        switch update.phase {
        case .began: begin(update)
        case .changed: change(update, frame: frame)
        case .ended: end(update)
        }
    }

    private func begin(_ update: CanvasManipulation.Update) {
        if live == nil {
            guard let layer = layers.first(where: { $0.id == touchedID }) else { return }
            let place = place(of: layer)
            live = place
        }
        guard let place = live else { return }
        active.insert(update.kind)
        // Each recognizer starts from the layer as it is now, so one restarting never jumps it.
        switch update.kind {
        case .move: moveBase = place.centre
        case .pinch: scaleBase = place.scale
        case .rotate: rotationBase = place.rotation
        }
    }

    private func change(_ update: CanvasManipulation.Update, frame: CGRect) {
        guard active.contains(update.kind), var next = live, frame.width > 0, frame.height > 0 else { return }
        switch update.kind {
        case .move:
            next.centre = CGPoint(
                x: moveBase.x + update.translation.width / frame.width,
                y: moveBase.y + update.translation.height / frame.height
            )
            let result = snapped(next, frame: frame.size, engaged: engaged)
            let gained = (result.engaged.x != nil && result.engaged.x != engaged.x)
                || (result.engaged.y != nil && result.engaged.y != engaged.y)
            if gained { Self.haptic() }
            engaged = result.engaged
            guides = result.guides
            next.centre = result.centre
        case .pinch:
            next.scale = scaleBase * Double(update.scale)
        case .rotate:
            let raw = (rotationBase + update.rotation) * 180 / .pi
            let result = ActivitiesEditorScreen.snapRotation(raw, engaged: engagedAngle)
            if result.engaged != nil, result.engaged != engagedAngle { Self.haptic() }
            engagedAngle = result.engaged
            next.rotation = result.angle * .pi / 180
        }
        guard next != live else { return }
        live = next
        onPlace(next.id, next.centre, next.scale, next.rotation)
    }

    private func end(_ update: CanvasManipulation.Update) {
        guard active.contains(update.kind) else { return }
        active.remove(update.kind)
        if update.kind == .move { guides = [] }
        guard active.isEmpty else { return }
        // §3: dropping a layer anywhere keeps its new place.
        reset()
        onGestureEnded()
    }

    /// The preview was covered mid-gesture.
    private func cancelGesture() {
        let moved = live != nil
        reset()
        if moved { onGestureEnded() }
    }

    private func reset() {
        active = []
        live = nil
        engaged = Engaged()
        engagedAngle = nil
        guides = []
    }

    private static func haptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Snapping

    /// §3: the frame's centre lines and the other visible layers' edges and centres, in frame wu.
    private func snapped(_ place: Place, frame: CGSize, engaged: Engaged)
        -> (centre: CGPoint, guides: [ActivityCanvasGuideSegment], engaged: Engaged) {
        let u = unit(frame)
        let size = CGSize(width: frame.width / u, height: frame.height / u)
        let box = bounds(place, frame: frame)
        let others = ordered.filter { $0.id != place.id }.map { ($0.id, bounds(self.place(of: $0), frame: frame)) }
        func targets(_ middle: CGFloat, _ lines: (CGRect) -> [CGFloat]) -> [Snap] {
            let sources: [(String?, CGFloat)] = [(nil, middle)] + others.flatMap { other in
                lines(other.1).map { (Optional(other.0), $0) }
            }
            return sources.flatMap { source in
                // The frame's centre line takes the layer's centre only.
                (source.0 == nil ? [0] : [-1, 0, 1]).map { Snap(source: source.0, anchor: $0, value: source.1) }
            }
        }
        let x = snapAxis(box.midX, extent: box.width, unit: u, engaged: engaged.x,
                         targets: targets(size.width / 2) { [$0.minX, $0.midX, $0.maxX] })
        let y = snapAxis(box.midY, extent: box.height, unit: u, engaged: engaged.y,
                         targets: targets(size.height / 2) { [$0.minY, $0.midY, $0.maxY] })
        let moved = box.offsetBy(dx: x.delta, dy: y.delta)
        var guides: [ActivityCanvasGuideSegment] = []
        if let snap = x.engaged {
            let other = others.first { $0.0 == snap.source }?.1
            guides.append(.init(
                from: CGPoint(x: snap.value, y: other.map { min($0.minY, moved.minY) } ?? 0),
                to: CGPoint(x: snap.value, y: other.map { max($0.maxY, moved.maxY) } ?? size.height)
            ))
        }
        if let snap = y.engaged {
            let other = others.first { $0.0 == snap.source }?.1
            guides.append(.init(
                from: CGPoint(x: other.map { min($0.minX, moved.minX) } ?? 0, y: snap.value),
                to: CGPoint(x: other.map { max($0.maxX, moved.maxX) } ?? size.width, y: snap.value)
            ))
        }
        let centre = CGPoint(
            x: place.centre.x + x.delta * u / max(frame.width, 1),
            y: place.centre.y + y.delta * u / max(frame.height, 1)
        )
        return (centre, guides, Engaged(x: x.engaged, y: y.engaged))
    }

    /// The shift that puts the layer's line on the engaged target, else on the nearest within reach.
    private func snapAxis(_ middle: CGFloat, extent: CGFloat, unit: CGFloat, engaged: Snap?, targets: [Snap])
        -> (delta: CGFloat, engaged: Snap?) {
        func gap(_ snap: Snap) -> CGFloat { snap.value - (middle + snap.anchor * extent / 2) }
        if let engaged, targets.contains(engaged), abs(gap(engaged)) * unit <= Geometry.release {
            return (gap(engaged), engaged)
        }
        guard let best = targets.min(by: { abs(gap($0)) < abs(gap($1)) }),
              abs(gap(best)) * unit <= Geometry.engage else { return (0, nil) }
        return (gap(best), best)
    }
}

/// Hosts the app's display layer: sets its frame and aspect-fit gravity, nothing else.
private struct VideoEditorFeed: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.host(layer)
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        view.host(layer)
    }

    final class HostView: UIView {
        private var hosted: CALayer?

        func host(_ layer: CALayer) {
            guard hosted !== layer else { return }
            hosted?.removeFromSuperlayer()
            hosted = layer
            switch layer {
            case let player as AVPlayerLayer: player.videoGravity = .resizeAspect
            case let sampleBuffer as AVSampleBufferDisplayLayer: sampleBuffer.videoGravity = .resizeAspect
            default: layer.contentsGravity = .resizeAspect
            }
            self.layer.addSublayer(layer)
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted?.frame = bounds
            CATransaction.commit()
        }
    }
}

// MARK: - Text tool (§2, §3)

private struct VideoEditorTextTool: View {
    typealias Style = VideoEditorScreen.State.Style
    typealias Tool = VideoEditorScreen.State.Tool

    let stylePanels: Bool
    let limit: Int
    let keyboardInset: CGFloat
    let onCommit: (String, Style) -> Void
    let onCancel: () -> Void

    // §3: "Style changes stay in the tool until Done" — the edit buffer.
    @SwiftUI.State private var text: String
    @SwiftUI.State private var style: Style
    @SwiftUI.State private var openTool: Tool
    @SwiftUI.State private var palettePage = 0
    @Environment(\.self) private var environment

    init(
        initial: VideoEditorScreen.State.TextTool,
        openTool: Tool,
        keyboardInset: CGFloat,
        onCommit: @escaping (String, Style) -> Void,
        onCancel: @escaping () -> Void
    ) {
        stylePanels = initial.stylePanels
        let base = VideoEditorScreen.textLimit
        limit = initial.stylePanels ? base : max(base, initial.text.count)
        self.keyboardInset = keyboardInset
        self.onCommit = onCommit
        self.onCancel = onCancel
        _text = SwiftUI.State(initialValue: initial.text)
        _style = SwiftUI.State(initialValue: initial.style)
        _openTool = SwiftUI.State(initialValue: initial.stylePanels ? openTool : .none)
    }

    private enum Geometry {
        static let reference: CGFloat = 440
        /// GAP — activities-editor §3 / OQ-015, cited by video-editor §3: 12–64 wu, linear.
        static let minSize: CGFloat = 12
        static let maxSize: CGFloat = 64
        /// FLAGGED LITERAL — video-editor §2 (video-polish D11): C-093 fixed 11 from the trailing edge.
        static let sliderInset: CGFloat = 11
        /// FLAGGED LITERAL — C-093 §4: `min(263.5, freeHeight − 32)`.
        static let sliderLength: CGFloat = 263.5
        static let sliderClearance: CGFloat = 32
        /// FLAGGED LITERAL — activities-editor §15.1: 32 pt tools, 4 padding, 8 radius, 16 gap.
        static let tool: CGFloat = 32
        static let toolPadding: CGFloat = 4
        static let toolRadius: CGFloat = 8
        static let toolGap: CGFloat = 16
        /// FLAGGED LITERAL — video-editor §2: the tool row 16 pt above the keyboard.
        static let keyboardGap: CGFloat = 16
        /// FLAGGED LITERAL — video-editor §2: the 34 pt well; C-094 §2 places it 23 in and 8 down.
        static let well: CGFloat = 34
        static let wellX: CGFloat = 23
        static let wellY: CGFloat = 8
        /// C-094 §2: the row (well, 16 gap, 344 presets), centred when wider than its insets.
        static let paletteRow: CGFloat = 394
        /// Not drawn, still hit-testable.
        static let wellOpacity: Double = 0.02
    }

    var body: some View {
        ZStack {
            Token.black60
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: commit)
                .accessibilityHidden(true)
                .ui2Element("Text tool backdrop")
            VStack(spacing: 0) {
                PageHeader(style: .textButtons, title: nil, showTitle: false, rightButtons: [],
                           onCancel: onCancel, onDone: commit)
                    .ui2Element("C-040 PageHeader")
                slot
                if stylePanels {
                    rail
                    toolRow
                }
            }
            .padding(.bottom, keyboardInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commit() { onCommit(text, style) }

    // MARK: Slot

    private var slot: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / Geometry.reference
            CanvasTextObject(
                text: text,
                onChange: { text = String($0.prefix(limit)) },
                font: VideoEditorValue.font(style.font),
                weight: VideoEditorValue.weight(style.weight),
                size: CGFloat(style.size),
                color: VideoEditorValue.color(style.color),
                alignment: VideoEditorValue.alignment(style.alignment),
                label: VideoEditorValue.label(style.label),
                transform: .init(position: .zero, scale: 1, rotation: .zero, width: VideoEditorScreen.editSlotWidth),
                manipulation: .host,
                editing: true
            )
            .ui2Element("C-092 CanvasTextObject")
            .fixedSize()
            .scaleEffect(unit)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            // §2: whenever text is being edited — never on a caption, whose Edit has header, text
            // and keyboard only (§2; captions carry no style panels).
            .overlay { if stylePanels { slider(free: proxy.size) } }
        }
    }

    private var sliderValue: CGFloat {
        (CGFloat(style.size) - Geometry.minSize) / (Geometry.maxSize - Geometry.minSize)
    }

    private func setSlider(_ value: CGFloat) {
        let clamped = min(max(value, 0), 1)
        style.size = Double(Geometry.minSize + clamped * (Geometry.maxSize - Geometry.minSize))
    }

    /// C-093 §2: placed by layout — trailing edge, centred in the free space between the header and
    /// the tool stack, which is the slot. Its gesture is its own.
    private func slider(free: CGSize) -> some View {
        TextSizeSlider(value: sliderValue,
                       length: max(min(Geometry.sliderLength, free.height - Geometry.sliderClearance), 0),
                       onChange: setSlider)
            .ui2Element("C-093 TextSizeSlider")
            .padding(.trailing, Geometry.sliderInset)
            .frame(width: free.width, height: free.height, alignment: .trailing)
    }

    // MARK: Tool row

    private static let tools: [(tool: Tool, glyph: GlyphName, label: String)] = [
        (.colour, .palette, "Colour"),
        (.alignment, .menu, "Alignment"),
        (.font, .textFont, "Font and weight"),
        (.label, .tag, "Label")
    ]

    private var toolRow: some View {
        HStack(spacing: Geometry.toolGap) {
            ForEach(Array(Self.tools.enumerated()), id: \.element.tool) { index, item in
                IconButton(
                    glyph: item.glyph, tone: .default, style: .plain, selected: openTool == item.tool,
                    accessibilityLabel: item.label,
                    onTap: { openTool = openTool == item.tool ? .none : item.tool }
                )
                .frame(width: Geometry.tool, height: Geometry.tool)
                .ui2Element(index == 0 ? "C-102 IconButton" : "C-102 IconButton \(index + 1)")
            }
        }
        .padding(Geometry.toolPadding)
        .background { material }
        .ui2Element("Tool row")
        .frame(maxWidth: .infinity)
        .padding(.bottom, Geometry.keyboardGap)
    }

    /// FLAGGED LITERAL — activities-editor §15.1: the system dark ultra-thin material.
    private var material: some View {
        RoundedRectangle(cornerRadius: Geometry.toolRadius)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
    }

    // MARK: Rails

    @ViewBuilder private var rail: some View {
        switch openTool {
        case .none:
            EmptyView()
        case .colour:
            palette
        case .alignment:
            alignmentRail
        case .font:
            VStack(spacing: 0) {
                ChipStrip(items: Self.weights, selectedID: String(style.weight),
                          onSelect: { style.weight = Int($0) ?? style.weight }, chipMaterial: true)
                    .ui2Element("C-106 ChipStrip 2")
                ChipStrip(items: Self.fonts, selectedID: style.font,
                          onSelect: { style.font = $0 }, chipMaterial: true)
                    .ui2Element("C-106 ChipStrip")
            }
        case .label:
            ChipStrip(items: Self.labels, selectedID: style.label.rawValue,
                      onSelect: { style.label = Style.Label(rawValue: $0) ?? style.label }, chipMaterial: true)
                .ui2Element("C-106 ChipStrip")
        }
    }

    private var palette: some View {
        TextColorPalette(
            currentColor: VideoEditorValue.color(style.color),
            swatches: Self.palettePages,
            page: palettePage,
            onSelect: { style.color = VideoEditorValue.hex($0, in: environment) },
            onPageChange: { palettePage = $0 },
            showsWell: true,
            swatchMaterial: true
        )
        .ui2Element("C-094 TextColorPalette")
        .overlay {
            GeometryReader { proxy in
                // OQ-video-editor-013: SwiftUI's ColorPicker over the C-095 well.
                ColorPicker("Text colour", selection: Binding(
                    get: { VideoEditorValue.color(style.color) },
                    set: { style.color = VideoEditorValue.hex($0, in: environment) }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: Geometry.well, height: Geometry.well)
                .contentShape(Rectangle())
                .opacity(Geometry.wellOpacity)
                .accessibilityLabel("Text colour")
                .ui2Element("C-095 ColorPickerWell")
                .offset(x: max((proxy.size.width - Geometry.paletteRow) / 2, Geometry.wellX), y: Geometry.wellY)
            }
        }
    }

    private static let alignments: [(value: Style.Alignment, glyph: GlyphName, label: String)] = [
        (.left, .textAlignStart, "Align left"),
        (.center, .textAlignCenter, "Align centre"),
        (.right, .textAlignEnd, "Align right")
    ]

    private var alignmentRail: some View {
        HStack(spacing: Token.Space.elementGap) {
            ForEach(Array(Self.alignments.enumerated()), id: \.element.value) { index, item in
                IconButton(
                    glyph: item.glyph, tone: .default, style: .plain, selected: style.alignment == item.value,
                    accessibilityLabel: item.label,
                    onTap: { style.alignment = item.value }
                )
                .frame(width: Geometry.tool, height: Geometry.tool)
                .padding(Geometry.toolPadding)
                .background { material }
                .ui2Element("C-102 IconButton Align \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Token.Space.elementGap)
    }

    private static let fonts: [ChipStrip.Item] = [
        .init(id: "display", label: "Poppins", font: .display),
        .init(id: "sans", label: "Inter", font: .sans),
        .init(id: "serif", label: "Source Serif 4", font: .serif),
        .init(id: "mono", label: "Courier Prime", font: .mono),
        .init(id: "classic", label: "Playfair Display", font: .classic)
    ]

    private static let weights: [ChipStrip.Item] = [
        .init(id: "400", label: "Regular"),
        .init(id: "500", label: "Medium"),
        .init(id: "700", label: "Bold")
    ]

    private static let labels: [ChipStrip.Item] = [
        .init(id: Style.Label.none.rawValue, label: "None"),
        .init(id: Style.Label.solidDark.rawValue, label: "Dark"),
        .init(id: Style.Label.solidLight.rawValue, label: "Light")
    ]

    private static let palettePages: [[TextColorPalette.NamedColor]] = presetPages.map { page in
        page.map { .init(name: $0.name, color: VideoEditorValue.color($0.hex)) }
    }

    /// activities-editor §19.6's six pages (video-editor §2), repeated: that screen's are private.
    // FLAGGED LITERAL — activities-editor §19.6: swatch hues, no colour token.
    private static let presetPages: [[(name: String, hex: String)]] = [
        // 1 General
        [("White", "#FFFFFF"), ("Black", "#000000"), ("Blue", "#509CEF"), ("Green", "#76C257"),
         ("Yellow", "#F6CB61"), ("Orange", "#EF8F3B"), ("Red", "#EA4F5E"), ("Pink", "#D43570"),
         ("Purple", "#A92BBD")],
        // 2 Blues & teals
        [("Mist", "#E0F4FA"), ("Sky", "#B3E5F2"), ("Aqua", "#7DD3E8"), ("Cyan", "#3FBFD6"),
         ("Teal", "#1FA3B8"), ("Azure", "#2B8CD6"), ("Cobalt", "#1F6FB8"), ("Navy", "#1B4F8C"),
         ("Midnight", "#0F2F5C")],
        // 3 Greens
        [("Frost", "#E4F5DA"), ("Pistachio", "#C3E6AC"), ("Spring", "#9FD683"), ("Leaf", "#78C25A"),
         ("Grass", "#4FAE45"), ("Emerald", "#2E9A44"), ("Forest", "#1F7A3A"), ("Pine", "#165A2E"),
         ("Evergreen", "#0D3B1F")],
        // 4 Yellows, oranges & reds
        [("Butter", "#FFF1A8"), ("Lemon", "#FBE16B"), ("Sunflower", "#F7C948"), ("Amber", "#F5A83A"),
         ("Tangerine", "#F27A2E"), ("Vermilion", "#E8552F"), ("Red", "#D92B3A"), ("Crimson", "#B3202D"),
         ("Burgundy", "#7F1520")],
        // 5 Purples & pinks
        [("Blush", "#FBE0EC"), ("Lilac", "#E1CCF5"), ("Rose", "#F2A3C6"), ("Orchid", "#C98BE0"),
         ("Magenta", "#D13F94"), ("Violet", "#9B4FD0"), ("Plum", "#7B2FA8"), ("Grape", "#55207A"),
         ("Aubergine", "#35124D")],
        // 6 Neutrals
        [("White", "#FFFFFF"), ("Cool 100", "#E8ECF0"), ("Warm 100", "#EFEBE5"), ("Cool 300", "#C5CCD3"),
         ("Warm 300", "#CCC6BC"), ("Cool 500", "#8F99A3"), ("Warm 500", "#968F84"), ("Charcoal", "#3A3F45"),
         ("Black", "#000000")]
    ]
}

// MARK: - §3 states

private let sampleFilmstrip: [String] = [
    "http://localhost:5961/api/projects/makeready/images/wade-wilson",
    "http://localhost:5961/api/projects/makeready/images/tony-stark",
    "http://localhost:5961/api/projects/makeready/images/luke-cage",
    "http://localhost:5961/api/projects/makeready/images/logan",
    "http://localhost:5961/api/projects/makeready/images/clark-kent"
]

#Preview("empty") {
    VideoEditorScreen(state: .init(
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5"
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("layer-selected") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        selectedID: "t2",
        playheadMs: 4000,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        canSplit: true
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("split-disabled") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        selectedID: "t2",
        playheadMs: 9000,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("text-tool-new") {
    VideoEditorScreen(state: .init(
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        textTool: .init(text: "", style: VideoEditorScreen.defaultTextStyle, stylePanels: true)
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("text-tool-edit") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        selectedID: "t2",
        playheadMs: 4000,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        canSplit: true,
        textTool: .init(text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, stylePanels: true),
        openTool: .colour
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("manipulating") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        selectedID: "t2",
        playheadMs: 4000,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        canSplit: true,
        manipulatingID: "t2"
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("transcribing") {
    VideoEditorScreen(state: .init(
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        captions: .transcribing
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("captions-added") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "c1", kind: .caption, text: "Welcome back everyone", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 0, endMs: 3200),
            .init(id: "c2", kind: .caption, text: "Today we are in", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 3200, endMs: 5400),
            .init(id: "c3", kind: .caption, text: "John chapter three", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 6000, endMs: 9000)
        ],
        playheadMs: 1500,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        captions: .added
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("captions-unavailable") {
    VideoEditorScreen(state: .init(
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        captions: .unavailable,
        captionsReason: "Captions unavailable"
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("remove-captions") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "c1", kind: .caption, text: "Welcome back everyone", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 0, endMs: 3200),
            .init(id: "c2", kind: .caption, text: "Today we are in", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 3200, endMs: 5400),
            .init(id: "c3", kind: .caption, text: "John chapter three", style: VideoEditorScreen.captionStyle, centre: CGPoint(x: 0.5, y: 0.78), startMs: 6000, endMs: 9000)
        ],
        playheadMs: 1500,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        captions: .added,
        confirm: .removeCaptions
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("layer-limit") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.05), startMs: 0, endMs: 3000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.095), startMs: 700, endMs: 3700),
            .init(id: "t3", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.14), startMs: 1400, endMs: 4400),
            .init(id: "t4", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.185), startMs: 2100, endMs: 5100),
            .init(id: "t5", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.23), startMs: 2800, endMs: 5800),
            .init(id: "t6", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.275), startMs: 3500, endMs: 6500),
            .init(id: "t7", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.32), startMs: 4200, endMs: 7200),
            .init(id: "t8", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.365), startMs: 4900, endMs: 7900),
            .init(id: "t9", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.41), startMs: 5600, endMs: 8600),
            .init(id: "t10", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.455), startMs: 6300, endMs: 9300),
            .init(id: "t11", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.5), startMs: 7000, endMs: 10000),
            .init(id: "t12", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.545), startMs: 7700, endMs: 10700),
            .init(id: "t13", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.59), startMs: 8400, endMs: 11400),
            .init(id: "t14", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.635), startMs: 9100, endMs: 12100),
            .init(id: "t15", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.68), startMs: 9800, endMs: 12800),
            .init(id: "t16", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.725), startMs: 10500, endMs: 13500),
            .init(id: "t17", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.77), startMs: 11200, endMs: 14200),
            .init(id: "t18", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.815), startMs: 11900, endMs: 14900),
            .init(id: "t19", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.86), startMs: 12600, endMs: 15000),
            .init(id: "t20", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.905), startMs: 13300, endMs: 15000)
        ],
        playheadMs: 12500,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        limitMessage: "Up to 20 text layers"
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("cancel-confirm") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        playheadMs: 4000,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true,
        confirm: .cancel
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("playing") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        playheadMs: 9000,
        playing: true,
        filmstrip: sampleFilmstrip,
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/image-5",
        canUndo: true
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}

#Preview("landscape") {
    VideoEditorScreen(state: .init(
        layers: [
            .init(id: "t1", kind: .text, text: "Title", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.3), startMs: 0, endMs: 12000),
            .init(id: "t2", kind: .text, text: "Adding text to video", style: VideoEditorScreen.defaultTextStyle, centre: CGPoint(x: 0.5, y: 0.55), startMs: 2000, endMs: 7000)
        ],
        playheadMs: 4000,
        frameAspectRatio: 16.0 / 9.0,
        filmstrip: ["http://localhost:5961/api/projects/makeready/images/matthew-mountain-teaching"],
        stillImageURL: "http://localhost:5961/api/projects/makeready/images/matthew-mountain-teaching",
        canUndo: true
    ))
    .padding(.top, 59)
    .frame(width: 440, alignment: .top)
    .frame(minHeight: 956, alignment: .top)
}
