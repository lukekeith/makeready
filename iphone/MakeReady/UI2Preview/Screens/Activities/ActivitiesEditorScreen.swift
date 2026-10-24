//
//  ActivitiesEditorScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen activities-editor in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/lessons/{id}/preview-data ·
//  GET /api/activities/{id}/preview-data ·
//  GET /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities ·
//  PATCH /api/activities/{id} · PATCH /api/scheduled-activities/{id} ·
//  POST /api/organizations/{organizationId}/media/upload ·
//  GET/POST /api/scheduled-activities/{activityId}/exegesis-highlights ·
//  PATCH/DELETE /api/scheduled-activities/{activityId}/exegesis-highlights/{highlightId}
//  (§5 API-GAP: no activity field stores a text object or the page background + wash — OQ-018).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Activity Editor — "The purpose of this screen is to create new text activity." The leader's
/// edit-in-place canvas: a tap anywhere on the canvas starts a text object (§3), the tool row
/// styles the edited object, and on a Bible verse activity (D55) the canvas renders the passage
/// and highlight mode marks it.
///
/// Composed only of §4's C-040 PageHeader, C-091 ActivityCanvas (→ C-092 CanvasTextObject,
/// C-093 TextSizeSlider, the Selection row's C-102 IconButton + C-105 Button), the bottom-panel
/// C-094 TextColorPalette (→ C-095, C-096 ×9, C-097) or C-106 ChipStrip (→ C-035 ×n), the tool
/// row of six C-102 IconButtons, and C-081 ActivityNavBar (→ C-061, C-021). Standalone: the
/// screen is not minted from a collection (`identifiedFrom` is null), so no D7 template applies.
struct ActivitiesEditorScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3 Modes: `idle` · `editing` · `highlighting` · `manipulating`.
        var editorMode: String
        /// The tool whose panel is open (§3 Tools): `color` · `image` · `font` · `animation` ·
        /// `highlight` · "" (none). Seeds the screen's local panel state.
        var openTool: String
        /// C-081 `slides` ids, in lesson order (§2 item 5, Idle).
        var slideIDs: [String]
        /// C-081 `slides` VoiceOver labels, parallel to `slideIDs` (never rendered).
        var slideLabels: [String]
        /// C-081 `activeID` — this activity's slide.
        var activeID: String
        /// The committed C-092 objects on the canvas (note 2026-10-13T04:14:15.022Z: one or
        /// more), as parallel arrays — text, font case name, swatch colour name, point size,
        /// canvas-local centre, scale and rotation in degrees. The edited object is not here.
        var objectTexts: [String]
        var objectFonts: [String]
        var objectColors: [String]
        var objectSizes: [Double]
        var objectXs: [Double]
        var objectYs: [Double]
        var objectScales: [Double]
        var objectRotations: [Double]
        /// The edited object in Editing (§3 Editing-new / Editing-existing): its text ("" shows
        /// the placeholder, OQ-014), font case name, swatch colour name, point size and
        /// alignment (`center` · `left` · `right`).
        var draftText: String
        var draftFont: String
        var draftColor: String
        var draftSize: Double
        var draftAlignment: String
        /// The page background (§2 item 3, a page property): "" = plain `color-background-alt`;
        /// otherwise the image URL, its wash colour as #rrggbb and the wash opacity.
        var pageImageURL: String
        var pageWashHex: String
        var pageWashOpacity: Double
        /// The Bible verse passage C-091 renders itself (D55): verse texts from `firstVerse`.
        /// Empty = a Text activity.
        var verseTexts: [String]
        var firstVerse: Int
        /// The passage's highlights as parallel arrays: id, verse number, character range.
        var highlightIDs: [String]
        var highlightVerses: [Int]
        var highlightStarts: [Int]
        var highlightEnds: [Int]
        /// The selected highlight (OQ-012: the Selection row shows only while one is); "" = none.
        var selectedHighlightID: String
        /// §3 Manipulating: the 1px centre guide and the "Drag to delete" target.
        var centerGuide: Bool
        var deleteTargetShown: Bool
        /// §3 Saving: the commit's background write is in flight (D39) — no visual change.
        var saving: Bool
        /// §3 Error: the save failed and the "Couldn't save activity" alert is up.
        var saveFailed: Bool
    }

    /// §3 Tools — the tool row, order 1–6.
    enum Tool: String, CaseIterable {
        case color, image, alignment, font, highlight, animation
    }

    let state: State
    var onBack: () -> Void = {}
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}
    var onSelectSlide: (String) -> Void = { _ in }
    var onAdd: () -> Void = {}
    var onTapEmpty: (CGPoint) -> Void = { _ in }
    var onTapObject: (Int) -> Void = { _ in }
    var onTransformObject: (Int, CanvasTextObject.Transform) -> Void = { _, _ in }
    var onPickImage: () -> Void = {}
    var onToggleHighlight: () -> Void = {}
    var onEyedropper: () -> Void = {}
    var onHighlight: (Int, Range<Int>) -> Void = { _, _ in }
    var onSelectHighlight: (String?) -> Void = { _ in }
    var onDeleteHighlight: () -> Void = {}
    var onAddNote: () -> Void = {}
    var onRetry: () -> Void = {}
    var onDiscard: () -> Void = {}

    // §3 Editing: the edited object is an in-flight edit buffer (R-31), seeded from `State`;
    // every tool writes it and Done / Cancel leave through the closures.
    @SwiftUI.State private var draftText: String
    @SwiftUI.State private var draftFont: CanvasTextObject.Font
    @SwiftUI.State private var draftColor: String
    @SwiftUI.State private var draftSize: Double
    @SwiftUI.State private var draftAlignment: CanvasTextObject.Alignment
    @SwiftUI.State private var draftAnimation: CanvasTextObject.Animation = .none
    @SwiftUI.State private var draftEffect: CanvasTextObject.Effect = .none
    // §3 Tools: which category panel is open is ephemeral UI (R-31).
    @SwiftUI.State private var openTool: Tool?
    // C-094 `page` — the swatch page shown.
    @SwiftUI.State private var palettePage = 0
    // §3 Error: the alert's presented flag, seeded from `State`.
    @SwiftUI.State private var alertPresented: Bool

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {},
        onSelectSlide: @escaping (String) -> Void = { _ in },
        onAdd: @escaping () -> Void = {},
        onTapEmpty: @escaping (CGPoint) -> Void = { _ in },
        onTapObject: @escaping (Int) -> Void = { _ in },
        onTransformObject: @escaping (Int, CanvasTextObject.Transform) -> Void = { _, _ in },
        onPickImage: @escaping () -> Void = {},
        onToggleHighlight: @escaping () -> Void = {},
        onEyedropper: @escaping () -> Void = {},
        onHighlight: @escaping (Int, Range<Int>) -> Void = { _, _ in },
        onSelectHighlight: @escaping (String?) -> Void = { _ in },
        onDeleteHighlight: @escaping () -> Void = {},
        onAddNote: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onCancel = onCancel
        self.onDone = onDone
        self.onSelectSlide = onSelectSlide
        self.onAdd = onAdd
        self.onTapEmpty = onTapEmpty
        self.onTapObject = onTapObject
        self.onTransformObject = onTransformObject
        self.onPickImage = onPickImage
        self.onToggleHighlight = onToggleHighlight
        self.onEyedropper = onEyedropper
        self.onHighlight = onHighlight
        self.onSelectHighlight = onSelectHighlight
        self.onDeleteHighlight = onDeleteHighlight
        self.onAddNote = onAddNote
        self.onRetry = onRetry
        self.onDiscard = onDiscard
        _draftText = SwiftUI.State(initialValue: state.draftText)
        _draftFont = SwiftUI.State(initialValue: Self.font(state.draftFont))
        _draftColor = SwiftUI.State(initialValue: state.draftColor)
        _draftSize = SwiftUI.State(initialValue: state.draftSize)
        _draftAlignment = SwiftUI.State(initialValue: Self.alignment(state.draftAlignment))
        _openTool = SwiftUI.State(initialValue: Tool(rawValue: state.openTool))
        _alertPresented = SwiftUI.State(initialValue: state.saveFailed)
    }

    private var mode: ActivityCanvas<AnyView>.Mode {
        switch state.editorMode {
        case "editing": return .editing
        case "highlighting": return .highlighting
        case "manipulating": return .manipulating
        default: return .idle
        }
    }

    /// Editing and Highlighting swap the header to Cancel · Done and the bottom bar to the tool
    /// row (§2 items 2 + 5).
    private var isToolMode: Bool { mode == .editing || mode == .highlighting }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 1) is the harness's, not drawn here.
        VStack(spacing: 0) {
            header
            // §2 items 3–4: the canvas and the bottom-panel slot share the region between the
            // header and the bottom bar; the panel takes its own height, the canvas the rest.
            VStack(spacing: 0) {
                canvas
                    .ui2Element("C-091 ActivityCanvas")
                bottomPanel
            }
            // GAP — activities-editor §2 item 3: canvas + panel = 775pt (775 Idle; 709 + 66
            // edit-text; 723 + 52 font-picker), no spacing token. Fixed so the region measures
            // when the harness proposes no height.
            .frame(height: Self.contentRegionHeight)
            bottomBar
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: page ground
        // §3 Error (proposed, undesigned): "system alert \"Couldn't save activity\" with
        // Retry / Discard changes".
        .alert(Self.errorTitle, isPresented: $alertPresented) {
            SwiftUI.Button(Self.retryLabel, action: onRetry)
            SwiftUI.Button(Self.discardLabel, role: .destructive, action: onDiscard)
        }
    }

    // MARK: - §2 item 2: the header

    private var header: some View {
        PageHeader(
            style: isToolMode ? .textButtons : .default,
            title: Self.title,
            showTitle: true,
            showIcons: false,
            leadingGlyph: .back,
            rightButtons: [],
            onLeading: onBack,
            onCancel: onCancel,
            onDone: onDone
        )
        // §2 deviation 7: the 1px hairline under C-040 is the screen's, not the component's.
        .overlay(alignment: .bottom) {
            Token.layoutBorder
                // GAP — activities-editor §2 item 2: 1px hairline, no stroke token.
                .frame(height: Self.hairline)
        }
        // §3 Manipulating: chrome hidden (fades out); the layout keeps its place.
        .opacity(mode == .manipulating ? 0 : 1)
        .ui2Element("C-040 PageHeader")
    }

    // MARK: - §2 item 3: the canvas

    private var canvas: some View {
        ActivityCanvas<AnyView>(
            background: background,
            mode: mode,
            passage: passage,
            selectedHighlightID: state.selectedHighlightID.isEmpty ? nil : state.selectedHighlightID,
            content: { AnyView(canvasContent) },
            onTapEmpty: onTapEmpty,
            onHighlight: onHighlight,
            onSelectHighlight: onSelectHighlight,
            centerGuide: state.centerGuide,
            deleteTarget: state.deleteTargetShown ? .visible : nil
        )
    }

    /// C-091's `content` slot: the committed objects at their transforms, the edited object at
    /// the edit slot with C-093 beside it, and the Selection row (§2 items 3–4).
    private var canvasContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(state.objectTexts.indices, id: \.self) { index in
                    committedObject(index, in: proxy.size)
                }
                if mode == .editing {
                    editedObject(in: proxy.size)
                    // §2 item 3: C-093 at x 11, y 358 on the page — visible whenever an object
                    // is edited (OQ-005; its absence on font-picker is deviation 6).
                    TextSizeSlider(value: sliderValue, onChange: { draftSize = Self.size(forSlider: $0) })
                        .ui2Element("C-093 TextSizeSlider")
                        // GAP — activities-editor §2 item 3: slider origin x 11, y 358 on the
                        // page (253 in the canvas), no spacing token.
                        .offset(x: Self.sliderOrigin.x, y: Self.sliderOrigin.y)
                }
                if mode == .highlighting && !state.selectedHighlightID.isEmpty {
                    selectionRow
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func committedObject(_ index: Int, in size: CGSize) -> some View {
        let position = CGPoint(x: value(state.objectXs, index, Double(size.width / 2)),
                               y: value(state.objectYs, index, Double(size.height / 2)))
        let transform = CanvasTextObject.Transform(
            position: position,
            scale: CGFloat(value(state.objectScales, index, 1)),
            rotation: .degrees(value(state.objectRotations, index, 0)),
            width: nil
        )
        return CanvasTextObject(
            text: state.objectTexts[index],
            font: Self.font(index < state.objectFonts.count ? state.objectFonts[index] : ""),
            size: CGFloat(value(state.objectSizes, index, Self.defaultSize)),
            color: Self.swatch(index < state.objectColors.count ? state.objectColors[index] : ""),
            transform: transform,
            onTransform: { onTransformObject(index, $0) },
            editing: false,
            onTap: { onTapObject(index) }
        )
        // C-092 never offsets itself (its §2): the canvas places it at `transform.position`,
        // laid out at the edit slot's width.
        .frame(width: editSlotWidth(size.width))
        .ui2Element(index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)")
        .position(position)
    }

    /// §2 item 3 + §3 Editing: the edited object alone at the edit slot — horizontally inset
    /// 24pt (its alignment lines it up inside), vertically centred at ≈ 51 % of the canvas.
    private func editedObject(in size: CGSize) -> some View {
        CanvasTextObject(
            text: draftText,
            onChange: { draftText = $0 },
            font: draftFont,
            size: CGFloat(draftSize),
            color: Self.swatch(draftColor),
            alignment: draftAlignment,
            animation: draftAnimation,
            effect: draftEffect,
            editing: true
        )
        .frame(width: editSlotWidth(size.width))
        .ui2Element(state.objectTexts.isEmpty
                    ? "C-092 CanvasTextObject"
                    : "C-092 CanvasTextObject \(state.objectTexts.count + 1)")
        // GAP — activities-editor §2 item 3: the edit slot centred on ≈ 51 % of the canvas
        // height, no token.
        .position(x: size.width / 2, y: size.height * Self.editSlotFraction)
    }

    /// §2 item 4 `edit-highlights`: the highlight actions — C-102 outlined destructive trash at
    /// the leading margin, C-105 "Add note" at the trailing one — shown only while a highlight
    /// is selected (OQ-012).
    private var selectionRow: some View {
        HStack(spacing: 0) {
            IconButton(
                glyph: .trash2,
                tone: .destructive,
                style: .outlined,
                selected: false,
                accessibilityLabel: Self.deleteHighlightLabel,
                onTap: onDeleteHighlight
            )
            .ui2Element("C-102 IconButton \(Tool.allCases.count + 1)")
            Spacer(minLength: 0)
            Button(label: Self.addNoteLabel, leadingGlyph: .addLargeCarbon, onTap: onAddNote)
                .ui2Element("C-105 Button")
        }
        .padding(.horizontal, Token.Space.pageMargin)
        // GAP — activities-editor §2 item 4: the highlight actions at y 837 on the page (733 in
        // the 775pt canvas, overlapping its last 50pt — deviation 9), no spacing token.
        .padding(.top, Self.selectionRowTop)
    }

    // MARK: - §2 item 4: the bottom-panel slot

    @ViewBuilder private var bottomPanel: some View {
        if mode == .editing {
            switch openTool {
            case .color:
                // §3 tool 1: C-094 — the well shows the object's colour, the equal swatch is
                // outlined (OQ-011); pages 2–3 are undesigned (04-color.md OQ-04-1) and empty.
                TextColorPalette(
                    currentColor: Self.swatch(draftColor),
                    swatches: Self.palettePages,
                    page: palettePage,
                    onSelect: { picked in
                        draftColor = Self.swatchNames.first { Self.swatch($0) == picked } ?? draftColor
                    },
                    onPageChange: { palettePage = $0 },
                    onWellTap: onEyedropper
                )
                .ui2Element("C-094 TextColorPalette")
            case .font:
                // §3 tool 4: C-106 of C-035 `type=Font` chips, the object's font selected.
                ChipStrip(items: Self.fontItems, selectedID: Self.fontID(draftFont),
                          onSelect: { draftFont = Self.font($0) })
                    .ui2Element("C-106 ChipStrip")
            case .animation:
                // §3 tool 6 (OQ-007): one combined strip — none, the animations, the effects.
                // C-106 has one `selectedID`, so it shows the animation when one is set, else the
                // effect (gap: two independent selections, one selected chip).
                ChipStrip(items: Self.animationItems, selectedID: animationSelectedID,
                          onSelect: selectAnimation)
                    .ui2Element("C-106 ChipStrip")
            case .image, .alignment, .highlight, .none:
                // Tool 2 presents a sheet (§6 overlay, OQ-023); tools 3 and 5 have no panel.
                EmptyView()
            }
        }
    }

    // MARK: - §2 item 5: the bottom bar

    @ViewBuilder private var bottomBar: some View {
        if isToolMode {
            toolRow
        } else {
            ActivityNavBar(slides: slides, activeID: state.activeID,
                           onSelectSlide: onSelectSlide, onAdd: onAdd)
                .ui2Element("C-081 ActivityNavBar")
                // §3 Manipulating: chrome hidden (fades out); the layout keeps its place.
                .opacity(mode == .manipulating ? 0 : 1)
        }
    }

    /// §2 item 5: the tool row — six plain C-102 IconButtons the screen lays out itself (owner
    /// ruling 2026-10-10), 32pt at a 64pt pitch (gap `space-toolbar-gap`), centred in the bar
    /// (x 44 + 64·i), vertically centred in its 76pt (y +22).
    private var toolRow: some View {
        HStack(spacing: Token.Space.toolbarGap) {
            ForEach(Array(Tool.allCases.enumerated()), id: \.element) { index, tool in
                IconButton(
                    glyph: Self.glyph(for: tool),
                    tone: .default,
                    style: .plain,
                    selected: isSelected(tool),
                    accessibilityLabel: Self.toolLabel(tool),
                    onTap: { tap(tool) }
                )
                // FLAGGED LITERAL — activities-editor §2: 32pt tools at a 64pt pitch.
                .frame(width: Self.toolSize, height: Self.toolSize)
                .ui2Element(index == 0 ? "C-102 IconButton" : "C-102 IconButton \(index + 1)")
            }
        }
        // GAP — activities-editor §2 item 5: the 440×76 bar, no spacing token.
        .frame(maxWidth: .infinity, minHeight: Self.barHeight, maxHeight: Self.barHeight)
    }

    /// §3 Tools: category tools (1, 2, 4, 6) take `selected` while their panel is open; 3 is
    /// never selected; 5 is selected while Highlighting is on.
    private func isSelected(_ tool: Tool) -> Bool {
        switch tool {
        case .alignment: return false
        case .highlight: return mode == .highlighting
        default: return mode == .editing && openTool == tool
        }
    }

    private func tap(_ tool: Tool) {
        switch tool {
        case .alignment:
            // §3 tool 3: center → left → right → center, no panel.
            switch draftAlignment {
            case .center: draftAlignment = .left
            case .left: draftAlignment = .right
            case .right: draftAlignment = .center
            }
        case .highlight:
            onToggleHighlight()
        case .image:
            openTool = .image
            onPickImage()
        default:
            openTool = tool
        }
    }

    // MARK: - Derived values

    private var background: ActivityCanvas<AnyView>.Background {
        guard !state.pageImageURL.isEmpty, let url = URL(string: state.pageImageURL) else { return .plain }
        return .image(imageURL: url, washColor: Self.washColor(state.pageWashHex),
                      washOpacity: state.pageWashOpacity)
    }

    private var passage: ActivityCanvas<AnyView>.Passage? {
        guard !state.verseTexts.isEmpty else { return nil }
        let verses = state.verseTexts.enumerated().map {
            ActivityCanvas<AnyView>.Verse(number: state.firstVerse + $0.offset, text: $0.element)
        }
        let count = [state.highlightIDs.count, state.highlightVerses.count,
                     state.highlightStarts.count, state.highlightEnds.count].min() ?? 0
        let highlights = (0..<count).compactMap { i -> ActivityCanvas<AnyView>.Highlight? in
            guard state.highlightStarts[i] <= state.highlightEnds[i] else { return nil }
            return .init(id: state.highlightIDs[i], verse: state.highlightVerses[i],
                         range: state.highlightStarts[i]..<state.highlightEnds[i], note: nil)
        }
        return .init(verses: verses, highlights: highlights)
    }

    /// C-081 `slides`: every slide is a C-061 chip — `image` nil (§1 deviation 10, D52).
    private var slides: [ActivityNavBar.Slide] {
        zip(state.slideIDs, state.slideLabels).map { ActivityNavBar.Slide(id: $0, image: nil, label: $1) }
    }

    /// C-093 `value`: the object's `size` along the track (OQ-015: 12–64pt, linear, top = 64).
    private var sliderValue: CGFloat {
        CGFloat((draftSize - Self.minSize) / (Self.maxSize - Self.minSize))
    }

    private var animationSelectedID: String {
        if draftAnimation != .none { return "\(draftAnimation)" }
        if draftEffect != .none { return "\(draftEffect)" }
        return Self.noneID
    }

    private func selectAnimation(_ id: String) {
        if id == Self.noneID {
            draftAnimation = .none
            draftEffect = .none
        } else if let animation = Self.animations.first(where: { "\($0)" == id }) {
            draftAnimation = animation
        } else if let effect = Self.effects.first(where: { "\($0)" == id }) {
            draftEffect = effect
        }
    }

    private func editSlotWidth(_ canvasWidth: CGFloat) -> CGFloat {
        max(canvasWidth - 2 * Self.editSlotInset, 0)
    }

    /// One element of a parallel array, or `fallback` when the array is short.
    private func value(_ values: [Double], _ index: Int, _ fallback: Double) -> Double {
        index < values.count ? values[index] : fallback
    }

    // MARK: - Mappings

    private static func font(_ name: String) -> CanvasTextObject.Font {
        switch name {
        case "poppins": return .poppins
        case "georgia": return .georgia
        case "typewriter": return .typewriter
        default: return .sfPro                              // §3: default SF Pro (OQ-016)
        }
    }

    private static func fontID(_ font: CanvasTextObject.Font) -> String {
        switch font {
        case .poppins: return "poppins"
        case .sfPro: return "sfPro"
        case .georgia: return "georgia"
        case .typewriter: return "typewriter"
        }
    }

    private static func alignment(_ name: String) -> CanvasTextObject.Alignment {
        switch name {
        case "left": return .left
        case "right": return .right
        default: return .center                             // §3: default center
        }
    }

    /// §2 item 4 / deviation 5: the nine swatch hues, in order. White and black are tokens; the
    /// other seven have no colour token. An unknown name is the default `color-text-primary`.
    private static func swatch(_ name: String) -> Color {
        switch name {
        case "black": return Token.black
        // FLAGGED LITERAL — activities-editor §1 deviation 5: swatch hues, no colour token.
        case "blue": return Color(red: 0x50 / 255, green: 0x9C / 255, blue: 0xEF / 255)
        case "green": return Color(red: 0x76 / 255, green: 0xC2 / 255, blue: 0x57 / 255)
        case "yellow": return Color(red: 0xF6 / 255, green: 0xCB / 255, blue: 0x61 / 255)
        case "orange": return Color(red: 0xEF / 255, green: 0x8F / 255, blue: 0x3B / 255)
        case "red": return Color(red: 0xEA / 255, green: 0x4F / 255, blue: 0x5E / 255)
        case "pink": return Color(red: 0xD4 / 255, green: 0x35 / 255, blue: 0x70 / 255)
        case "purple": return Color(red: 0xA9 / 255, green: 0x2B / 255, blue: 0xBD / 255)
        case "white": return Token.white100
        default: return Token.textPrimary                   // §3: default `color-text-primary`
        }
    }

    private static let swatchNames = ["white", "black", "blue", "green", "yellow", "orange", "red", "pink", "purple"]

    /// C-094 `swatches`: page 1 as drawn; pages 2–3 undesigned (04-color.md OQ-04-1), empty so
    /// C-097 still draws the three designed dots.
    private static let palettePages: [[TextColorPalette.NamedColor]] = [
        swatchNames.map { TextColorPalette.NamedColor(name: $0.capitalized, color: swatch($0)) },
        [],
        []
    ]

    /// The page wash is the leader's page property, decoded from its #rrggbb (data, not style).
    private static func washColor(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return Token.black }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255,
                     green: Double((rgb >> 8) & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }

    /// §2 item 4: the four fonts, labelled with their display names (OQ-016).
    private static let fontItems: [ChipStrip.Item] = [
        .init(id: "poppins", label: "Poppins", font: .poppins),
        .init(id: "sfPro", label: "SF Pro", font: .sfPro),
        .init(id: "georgia", label: "Georgia", font: .georgia),
        .init(id: "typewriter", label: "Typewriter", font: .typewriter)
    ]

    private static let noneID = "none"
    private static let animations: [CanvasTextObject.Animation] = [.typewriter, .pop, .jump]
    private static let effects: [CanvasTextObject.Effect] = [.sparkle, .neon, .shimmer, .pixel]

    /// §3 tool 6 (OQ-007): ⊗ none first, the three animations, then the four effects.
    private static let animationItems: [ChipStrip.Item] =
        [.init(id: noneID, label: "None")]
        + animations.map { .init(id: "\($0)", label: "\($0)".capitalized) }
        + effects.map { .init(id: "\($0)", label: "\($0)".capitalized) }

    /// §2 item 5 interim glyphs (OQ-017 — the designed glyphs are not minted yet). Tool 1's
    /// gradient sphere is artwork C-102 cannot carry; `palette` stands in.
    private static func glyph(for tool: Tool) -> GlyphName {
        switch tool {
        case .color: return .palette
        case .image: return .file
        case .alignment: return .menu
        case .font: return .textContent
        case .highlight: return .edit
        case .animation: return .sparkles
        }
    }

    /// R-17: each tool's accessibility label, from §3 Tools.
    private static func toolLabel(_ tool: Tool) -> String {
        switch tool {
        case .color: return "Colour"
        case .image: return "Background image"
        case .alignment: return "Alignment"
        case .font: return "Font"
        case .highlight: return "Highlight"
        case .animation: return "Animation and effects"
        }
    }

    /// OQ-015: the slider's point range and its 50 % default.
    private static func size(forSlider value: CGFloat) -> Double {
        minSize + Double(value) * (maxSize - minSize)
    }

    // §2 copy.
    private static let title = "Edit lesson"
    private static let deleteHighlightLabel = "Delete highlight"
    private static let addNoteLabel = "Add note"
    // §3 Error copy (proposed).
    private static let errorTitle = "Couldn't save activity"
    private static let retryLabel = "Retry"
    private static let discardLabel = "Discard changes"

    /// GAP — activities-editor §3 / OQ-015: 12–64pt, linear; the 50 % thumb is 38pt.
    private static let minSize: Double = 12
    private static let maxSize: Double = 64
    private static let defaultSize: Double = 38
    /// GAP — activities-editor §2 item 3: canvas + bottom panel, 775pt.
    private static let contentRegionHeight: CGFloat = 775
    /// GAP — activities-editor §2 item 5: the bottom bar, 76pt.
    private static let barHeight: CGFloat = 76
    /// FLAGGED LITERAL — activities-editor §2: 32pt tools.
    private static let toolSize: CGFloat = 32
    /// GAP — activities-editor §2 item 2: the 1px hairline.
    private static let hairline: CGFloat = 1
    /// GAP — activities-editor §3 tool 3: the edit slot's left/right edge 24pt from the canvas.
    private static let editSlotInset: CGFloat = 24
    /// GAP — activities-editor §2 item 3: the edit slot centred at ≈ 51 % of the canvas.
    private static let editSlotFraction: CGFloat = 0.51
    /// GAP — activities-editor §2 item 3: C-093 at x 11, y 358 on the page (253 in the canvas).
    private static let sliderOrigin = CGPoint(x: 11, y: 253)
    /// GAP — activities-editor §2 item 4: highlight actions at y 837 (733 in the canvas).
    private static let selectionRowTop: CGFloat = 733
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension ActivitiesEditorScreen.State {
    /// §2 item 5 `blank-canvas`: two C-061 chips, the second (this activity) active. Labels are
    /// VoiceOver-only.
    private static let frameSlideIDs = ["activity-1", "activity-2"]
    private static let frameSlideLabels = ["Activity 1", "Activity 2"]
    /// §1 deviation 10: "Text I just added" is the frames' sample copy.
    private static let sampleText = "Text I just added"

    /// The Idle base every other sample varies from.
    private static let base = Self(
        editorMode: "idle", openTool: "",
        slideIDs: frameSlideIDs, slideLabels: frameSlideLabels, activeID: "activity-2",
        objectTexts: [], objectFonts: [], objectColors: [], objectSizes: [],
        objectXs: [], objectYs: [], objectScales: [], objectRotations: [],
        draftText: "", draftFont: "sfPro", draftColor: "white", draftSize: 38, draftAlignment: "center",
        pageImageURL: "", pageWashHex: "", pageWashOpacity: 0,
        verseTexts: [], firstVerse: 1,
        highlightIDs: [], highlightVerses: [], highlightStarts: [], highlightEnds: [],
        selectedHighlightID: "",
        centerGuide: false, deleteTargetShown: false, saving: false, saveFailed: false
    )

    /// One committed object at the edit slot's centre, scale 1 (§2 item 3: y ≈ 377).
    private static func committed(scale: Double = 1, x: Double = 220, y: Double = 377,
                                  rotation: Double = 0) -> Self {
        var s = base
        s.objectTexts = [sampleText]
        s.objectFonts = ["sfPro"]
        s.objectColors = ["white"]
        s.objectSizes = [38]
        s.objectXs = [x]
        s.objectYs = [y]
        s.objectScales = [scale]
        s.objectRotations = [rotation]
        return s
    }

    /// §3 Idle-empty — the frozen frame `blank-canvas`.
    static let idleEmpty = base
    /// §3 Idle-populated — one committed object.
    static let idlePopulated = committed()
    /// §3 Editing-new — a canvas tap: placeholder, fonts panel on SF Pro (OQ-014).
    static let editingNew: Self = {
        var s = base
        s.editorMode = "editing"
        s.openTool = "font"
        return s
    }()
    /// §3 Editing-existing — the frozen frame `edit-text`: the object re-opened, the colour
    /// panel open with blue picked (the well and the outlined swatch, OQ-011).
    static let editingExisting: Self = {
        var s = base
        s.editorMode = "editing"
        s.openTool = "color"
        s.draftText = sampleText
        s.draftColor = "blue"
        return s
    }()
    /// §3 Highlighting — the frozen frame `edit-highlights`: a Bible verse passage over an image
    /// with a #141F6B wash at 0.80 (§4 C-091), a highlight selected so the actions show (OQ-012).
    static let highlighting: Self = {
        var s = base
        s.editorMode = "highlighting"
        s.openTool = "highlight"
        s.pageImageURL = "https://www.figma.com/api/mcp/asset/a841c951-5193-4242-96f6-5bffdc4a5d79"
        s.pageWashHex = "#141F6B"
        s.pageWashOpacity = 0.8
        s.verseTexts = [
            "In the beginning God created the heavens and the earth.",
            "Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters.",
            "And God said, “Let there be light,” and there was light. 4 God saw that the light was good, and he separated the light from the darkness. 5 God called the light “day,” and the darkness he called “night.” And there was evening, and there was morning—the first day.",
            "And God said, “Let there be a vault between the waters to separate water from water.”",
            "God called the light “day,” and the darkness he called “night.” And there was evening, and there was morning—the first day.",
            "And God said, “Let there be a vault between the waters to separate water from water.”",
            "So God made the vault and separated the water under the vault from the water above it. And it was so.",
            "God called the vault “sky.” And there was evening, and there was morning—the second day."
        ]
        s.firstVerse = 1
        s.highlightIDs = ["h1", "h2"]
        s.highlightVerses = [3, 3]
        s.highlightStarts = [40, 128]
        s.highlightEnds = [75, 187]
        s.selectedHighlightID = "h1"
        return s
    }()
    /// §3 Manipulating — a one-finger drag: chrome hidden, centre guide and delete target shown
    /// (C-091's own Manipulating sample: 1.2×, −8°).
    static let manipulating: Self = {
        var s = committed(scale: 1.2, x: 220, y: 300, rotation: -8)
        s.editorMode = "manipulating"
        s.centerGuide = true
        s.deleteTargetShown = true
        return s
    }()
    /// §3 Saving — after Done the object is committed optimistically; the write runs behind.
    static let saving: Self = {
        var s = committed()
        s.saving = true
        return s
    }()
    /// §3 Error — the save failed; the alert is up over the committed canvas.
    static let error: Self = {
        var s = committed()
        s.saveFailed = true
        return s
    }()
}

#Preview("Idle-empty") {
    ActivitiesEditorScreen(state: .idleEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Idle-populated") {
    ActivitiesEditorScreen(state: .idlePopulated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Editing-new") {
    ActivitiesEditorScreen(state: .editingNew)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Editing-existing") {
    ActivitiesEditorScreen(state: .editingExisting)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Highlighting") {
    ActivitiesEditorScreen(state: .highlighting)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Manipulating") {
    ActivitiesEditorScreen(state: .manipulating)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Saving") {
    ActivitiesEditorScreen(state: .saving)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Error") {
    ActivitiesEditorScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
