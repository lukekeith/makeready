//
//  ActivitiesEditorScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen activities-editor in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/lessons/:id/draft ·
//  PUT /api/activities/:id · POST /api/lesson-versions/:id/activities ·
//  DELETE /api/activities/:id · POST /api/organizations/{organizationId}/media/upload
//  (the new model's routes, specified by the server work — §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Activity Editor — "The purpose of this screen is to create new text activity." The leader's
/// edit-in-place canvas over the activity document (§5): a tap anywhere on the canvas starts a
/// text object (§3), the tool row styles the edited object, and every text on the page, a Bible
/// passage included, is a movable C-092 (D55).
///
/// §2 Units (D1): every figure on the page — object transforms, the edit slot, the handles, the
/// guides, the slider's position — is in width units; C-091 scales its page by width ÷ 440. The
/// header, the bottom container, the panels and the chips stay in points.
///
/// Composed only of §4's C-040 PageHeader, C-091 ActivityCanvas (→ C-092 CanvasTextObject, the
/// Selection row's C-102 IconButton + C-105 Button), C-093 TextSizeSlider, the bottom container's
/// C-094 TextColorPalette (→ C-095, C-096 ×9, C-097) or C-106 ChipStrip (→ C-035), the tool row of
/// C-102 IconButtons, C-081 ActivityNavBar (→ C-061, C-021), and the two §6 sheets built from the
/// same rows. Standalone: `identifiedFrom` is null, so no D7 template applies.
struct ActivitiesEditorScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State: Equatable {
        /// §3 Modes: `idle` · `editing` · `highlighting` · `manipulating`.
        var editorMode: String
        /// The tool open at first (§3 Tools): a panel — `color` · `font` · `animation` — a sheet —
        /// `background` · `actions` — or `highlight` · "" (none).
        var openTool: String
        /// §2 item 5 (first slice): tools 5 and 6 and the eyedropper are hidden unless set.
        var showsHighlightTool: Bool
        var showsEffectsTool: Bool
        var showsEyedropper: Bool
        /// C-081 `slides` ids, in lesson order (Idle).
        var slideIDs: [String]
        /// C-081 `slides` VoiceOver labels, parallel to `slideIDs` (never rendered).
        var slideLabels: [String]
        /// C-081 `activeID` — this activity's slide.
        var activeID: String
        /// `State.objects` (§9.1): the C-092 objects the container passes in and the screen
        /// displays, as parallel arrays: text, font key, colour `#RRGGBB` (§9.2; "" = the §3
        /// default), weight (`regular` · `medium` · `bold`), size in wu, alignment, list style,
        /// first list number, centre in wu, scale, rotation in degrees and layout width in wu
        /// (0 = the 392 wu edit slot). A short array takes the §3 default. The edited object is
        /// one of them (`editingIndex`).
        var objectTexts: [String]
        var objectFonts: [String]
        var objectColors: [String]
        var objectWeights: [String]
        var objectSizes: [Double]
        var objectAlignments: [String]
        var objectListStyles: [String]
        var objectStartNumbers: [Int]
        var objectXs: [Double]
        var objectYs: [Double]
        var objectScales: [Double]
        var objectRotations: [Double]
        var objectWidths: [Double]
        /// Each object's measured height in wu, seeding `contentExtent`: a capture renders in one
        /// layout pass, before the screen's own measurement can land. Live, the measurement wins.
        var objectHeights: [Double]
        /// §3 Editing (§9.1): the index in `objects` of the edited object, drawn alone at the edit
        /// slot (text "" shows the placeholder, OQ-014); −1 = none.
        var editingIndex: Int
        /// `background` (§2 item 3, D4): page colour #rrggbb ("" = `color-background-alt`), image
        /// URL ("" = none), its `focal` 0–1, and the wash colour #rrggbb and opacity.
        var pageColorHex: String
        var pageImageURL: String
        var pageImageFocalX: Double
        var pageImageFocalY: Double
        var pageWashHex: String
        var pageWashOpacity: Double
        /// A Bible passage added as one block (D55): one C-092 with `listStyle=bibleVerse`, one
        /// item per verse, numbered from `firstVerse`. Empty = none.
        var verseTexts: [String]
        var firstVerse: Int
        /// Highlights as parallel arrays: id, the object index (the passage object follows the
        /// objects above), and the UTF-16 range in that object's text (D7).
        var highlightIDs: [String]
        var highlightObjects: [Int]
        var highlightStarts: [Int]
        var highlightEnds: [Int]
        /// The selected highlight (OQ-012: the Selection row shows only while one is); "" = none.
        var selectedHighlightID: String
        /// `actions[]` (D8) as parallel arrays: id, kind, label, placement (`inline` · `pinned`)
        /// and the payload prefill — the kind's first field (title, prompt or URL) and the body.
        var actionIDs: [String]
        var actionKinds: [String]
        var actionLabels: [String]
        var actionPlacements: [String]
        var actionValues: [String]
        var actionBodies: [String]
        /// §3 Manipulating: the 1 px centre guide and the "Drag to delete" target.
        var centerGuide: Bool
        var deleteTargetShown: Bool
        /// §3 Saving: the commit's background write is in flight (D39) — no visual change.
        var saving: Bool
        /// §3 Error: the save failed and the "Couldn't save activity" alert is up.
        var saveFailed: Bool
        /// §9.4 Load-failed: the container could not load the activity — the Idle header (back
        /// only), no canvas, no bottom container; the banner, then back after 2 s.
        var loadFailed: Bool
        /// §9.3 (owner ruling 2026-11-08): the Idle header's Done — `false` muted and not
        /// tappable, `true` enabled and calling `onDone`. The container sets it on unsaved changes.
        var canSave: Bool = false
    }

    /// §9.1 (D33): one user action's edit of one object — only the fields that changed are
    /// non-nil. Adding and deleting an object are not edits (§8, OQ-activities-editor-031).
    struct ObjectEdit: Equatable {
        /// The object's centre, scale and rotation — wu, wu, unitless, degrees.
        struct Transform: Equatable {
            var x: CGFloat
            var y: CGFloat
            var scale: CGFloat
            var rotation: CGFloat
        }

        /// The object's position in `State.objects`.
        var index: Int
        var text: String?
        /// The C-092 key: `display` · `sans` · `serif` · `mono`.
        var font: String?
        /// 400 · 500 · 700.
        var weight: Int?
        /// wu.
        var size: CGFloat?
        /// `#RRGGBB`.
        var color: String?
        /// `center` · `left` · `right`.
        var alignment: String?
        /// wu, `transform.width`.
        var width: CGFloat?
        var transform: Transform?

        init(index: Int, text: String? = nil, font: String? = nil, weight: Int? = nil,
             size: CGFloat? = nil, color: String? = nil, alignment: String? = nil,
             width: CGFloat? = nil, transform: Transform? = nil) {
            self.index = index
            self.text = text
            self.font = font
            self.weight = weight
            self.size = size
            self.color = color
            self.alignment = alignment
            self.width = width
            self.transform = transform
        }
    }

    /// §3 Tools — the tool row, order 1–7.
    enum Tool: String, CaseIterable {
        case color, background, alignment, font, highlight, animation, actions
    }

    /// `actions[]` element (D8; 02 §7).
    struct PageAction: Equatable {
        enum Kind: String, CaseIterable {
            case addToPrayerList, write, openUrl, nextLesson
        }

        enum Placement: String {
            case inline, pinned
        }

        var id: String
        var kind: Kind
        var label: String
        var placement: Placement
        /// The kind's first prefill field: `addToPrayerList` title · `write` prompt · `openUrl` URL.
        var value: String
        /// `addToPrayerList` body.
        var body: String
    }

    let state: State
    var onBack: () -> Void = {}
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}
    var onSelectSlide: (String) -> Void = { _ in }
    var onAdd: () -> Void = {}
    var onTapEmpty: (CGPoint) -> Void = { _ in }
    var onTapObject: (Int) -> Void = { _ in }
    /// §9.1: one callback per user action that edits an object.
    var onEditObject: (ObjectEdit) -> Void = { _ in }
    /// §9.4: Load-failed raises the top error banner with this message; the error channel is the
    /// app's, so the container routes it there.
    var onLoadFailed: (String) -> Void = { _ in }
    var onPickImage: () -> Void = {}
    var onChangeBackground: (ActivityCanvas<AnyView>.Background) -> Void = { _ in }
    var onChangeActions: ([PageAction]) -> Void = { _ in }
    var onToggleHighlight: () -> Void = {}
    var onEyedropper: () -> Void = {}
    var onDeleteHighlight: () -> Void = {}
    var onAddNote: () -> Void = {}
    var onRetry: () -> Void = {}
    var onDiscard: () -> Void = {}

    // §9.1: the screen's display state of `State.objects` — an edit applies here and is reported
    // through `onEditObject`, without waiting for the container's echo; a new `State` re-seeds it.
    @SwiftUI.State private var shownObjects: [CommittedObject]
    @SwiftUI.State private var draftAnimation: CanvasTextObject.Animation = .none
    @SwiftUI.State private var draftEffect: CanvasTextObject.Effect = .none
    @SwiftUI.State private var draftAnimationStart: Date?
    // §6 sheets: in-flight edit buffers of the document's page properties (R-31).
    @SwiftUI.State private var pageColor: Color
    @SwiftUI.State private var pageFocal: CGPoint
    @SwiftUI.State private var pageWashColor: Color
    @SwiftUI.State private var pageWashOpacity: Double
    @SwiftUI.State private var actions: [PageAction]
    // §3 Tools: which panel and which sheet are open is ephemeral UI (R-31).
    @SwiftUI.State private var openTool: Tool?
    @SwiftUI.State private var openSheet: Tool?
    // C-094 `page` — the swatch page shown.
    @SwiftUI.State private var palettePage = 0
    // §3 Error: the alert's presented flag, seeded from `State`.
    @SwiftUI.State private var alertPresented: Bool
    // §4 C-091 `contentExtent`: "the screen measures the objects' rotated, scaled box in wu".
    @SwiftUI.State private var measuredHeights: [Int: CGFloat] = [:]
    @SwiftUI.State private var measuredDraftHeight: CGFloat?
    // §2 item 6: the container rides the keyboard's top edge; the canvas does not resize.
    @SwiftUI.State private var keyboardTop = CGFloat.infinity
    @SwiftUI.State private var containerBottom: CGFloat = 0
    // §2 scrolling insets: the bottom container's height, held while Manipulating hides it so the
    // scroll range, and so the page, does not change when the bars hide.
    @SwiftUI.State private var containerHeight: CGFloat = 0
    // §2 Autoscroll (R-02, held only while the finger is down): the touch in viewport wu; the page
    // height fixed at drag start so the page never re-places under the finger; how far autoscroll
    // has moved the page; and the object's last transform, re-emitted as the page moves.
    @SwiftUI.State private var dragPoint: CGPoint?
    @SwiftUI.State private var dragExtent: ClosedRange<CGFloat>??
    @SwiftUI.State private var dragScroll: CGFloat = 0
    @SwiftUI.State private var dragged: (index: Int, transform: CanvasTextObject.Transform)?
    // §9.1a: the object's transform when the in-flight gesture began — a gesture that ends where
    // it started reports nothing.
    @SwiftUI.State private var gestureStart: ObjectEdit.Transform?

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {},
        onSelectSlide: @escaping (String) -> Void = { _ in },
        onAdd: @escaping () -> Void = {},
        onTapEmpty: @escaping (CGPoint) -> Void = { _ in },
        onTapObject: @escaping (Int) -> Void = { _ in },
        onEditObject: @escaping (ObjectEdit) -> Void = { _ in },
        onLoadFailed: @escaping (String) -> Void = { _ in },
        onPickImage: @escaping () -> Void = {},
        onChangeBackground: @escaping (ActivityCanvas<AnyView>.Background) -> Void = { _ in },
        onChangeActions: @escaping ([PageAction]) -> Void = { _ in },
        onToggleHighlight: @escaping () -> Void = {},
        onEyedropper: @escaping () -> Void = {},
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
        self.onEditObject = onEditObject
        self.onLoadFailed = onLoadFailed
        self.onPickImage = onPickImage
        self.onChangeBackground = onChangeBackground
        self.onChangeActions = onChangeActions
        self.onToggleHighlight = onToggleHighlight
        self.onEyedropper = onEyedropper
        self.onDeleteHighlight = onDeleteHighlight
        self.onAddNote = onAddNote
        self.onRetry = onRetry
        self.onDiscard = onDiscard
        _shownObjects = SwiftUI.State(initialValue: Self.committedObjects(state))
        _pageColor = SwiftUI.State(initialValue: Self.hexColor(state.pageColorHex) ?? Token.backgroundAlt)
        _pageFocal = SwiftUI.State(initialValue: CGPoint(x: state.pageImageFocalX, y: state.pageImageFocalY))
        _pageWashColor = SwiftUI.State(initialValue: Self.hexColor(state.pageWashHex) ?? Token.black)
        _pageWashOpacity = SwiftUI.State(initialValue: state.pageWashOpacity)
        _actions = SwiftUI.State(initialValue: Self.pageActions(state))
        let seeded = Tool(rawValue: state.openTool)
        let isSheet = seeded == .background || seeded == .actions
        _openTool = SwiftUI.State(initialValue: isSheet ? nil : seeded)
        _openSheet = SwiftUI.State(initialValue: isSheet ? seeded : nil)
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

    /// Editing and Highlighting swap the header to Cancel · Done and the container to the tool
    /// row (§2 items 2 + 4).
    private var isToolMode: Bool { !state.loadFailed && (mode == .editing || mode == .highlighting) }

    var body: some View {
        if state.loadFailed {
            loadFailedPage
        } else {
            editorPage
        }
    }

    /// §9.4 Load-failed: the ground under the Idle header (back only), no canvas, no bottom
    /// container. The banner is raised through `onLoadFailed`; 2 s later the back closure pops.
    private var loadFailedPage: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
        }
        .background(Token.layoutBackground)                 // §9.4: `color-layout-background`
        .task {
            onLoadFailed(Self.loadFailedMessage)
            try? await Task.sleep(for: Self.loadFailedDelay)
            guard !Task.isCancelled else { return }
            onBack()
        }
    }

    private var editorPage: some View {
        // §2: back to front — the page, then fixed furniture, then the header and the bottom
        // container, opaque on top of it. The system status bar (deviation 1) is the harness's.
        GeometryReader { screen in
            ZStack(alignment: .top) {
                // §2: the canvas is the whole screen on any phone — canvas y 0 = screen y 0.
                GeometryReader { proxy in
                    canvas(unit: proxy.size.width / Self.referenceWidth,
                           viewport: proxy.size.height * Self.referenceWidth / proxy.size.width,
                           safeTop: screen.safeAreaInsets.top)
                }
                .ignoresSafeArea(.container)
                chrome(unit: screen.size.width / Self.referenceWidth)
            }
        }
        .background(Token.layoutBackground)                 // §2: page ground
        // §2 item 6: the keyboard never resizes the page; the container follows it by offset.
        .ignoresSafeArea(.keyboard)
        .overlay { sheetOverlay }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
            withAnimation(.easeOut(duration: duration)) { keyboardTop = frame.minY }
        }
        // §3 Error (proposed, undesigned): "Couldn't save activity" with Retry / Discard changes.
        .alert(Self.errorTitle, isPresented: $alertPresented) {
            SwiftUI.Button(Self.retryLabel, action: onRetry)
            SwiftUI.Button(Self.discardLabel, role: .destructive, action: onDiscard)
        }
        // §9.1: `State.objects` is the source — a new State from the container re-seeds the display.
        // §9.1a: never while a gesture is in flight, so a late echo cannot snap the object back.
        .onChange(of: state) { _, next in
            guard dragged == nil else { return }
            shownObjects = Self.committedObjects(next)
        }
    }

    // MARK: - §2 z-order: fixed furniture and the bars

    /// The header at the top and, at the bottom, the fixed furniture standing on the container.
    /// In Manipulating the container leaves the layout, so a pinned pill falls to the screen's foot.
    private func chrome(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            furniture(unit: unit)
                .offset(y: -keyboardOverlap)
            if mode != .manipulating {
                bottomContainer
                    .transition(.opacity)
            }
        }
        // §2 item 5: the 76pt bar is tall enough for the home indicator, so it runs to the bottom.
        .ignoresSafeArea(.container, edges: .bottom)
        // §2 item 6: the container's resting bottom is this column's bottom. Measured here, outside the
        // container's keyboard offset — measured inside it, the offset fed back and cancelled itself.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { containerBottom = $0 }
    }

    /// §2 item 3: page furniture drawn in points from wu, fixed to the screen: the Selection row
    /// and the pinned pill.
    @ViewBuilder
    private func furniture(unit: CGFloat) -> some View {
        if mode == .highlighting && !state.selectedHighlightID.isEmpty {
            selectionRow(unit: unit)
        } else if let pinned = actions.first(where: { $0.placement == .pinned }) {
            // FLAGGED LITERAL — activities-editor §2: the pinned pill, a screen-drawn preview with
            // no registry row, 46 wu tall, 16 wu inset.
            SwiftUI.Text(verbatim: pinned.label)
                .designTextStyle(Token.TypeStyle.calloutBold)
                .foregroundStyle(Token.black)
                .frame(width: Self.referenceWidth - 2 * Self.pinnedInset, height: Self.pinnedHeight)
                .background(Token.white100, in: Capsule())
                .ui2Element("Pinned action preview")
                .scaleEffect(unit)
                .frame(width: (Self.referenceWidth - 2 * Self.pinnedInset) * unit, height: Self.pinnedHeight * unit)
                .padding(.bottom, Self.pinnedInset * unit)
                .allowsHitTesting(false)
        }
    }

    // MARK: - §2 item 2: the header

    private var header: some View {
        // §2 item 2 / §9.3 (owner ruling 2026-11-08): Idle is `backAndLink` — back leading and a
        // trailing Done enabled by `canSave`; Load-failed is back only (§9.4); Editing /
        // Highlighting is `textButtons` Cancel · Done.
        PageHeader(
            style: isToolMode ? .textButtons : (state.loadFailed ? .default : .backAndLink),
            title: Self.title,
            showTitle: true,
            showIcons: false,
            leadingGlyph: .back,
            rightButtons: [],
            trailingEnabled: isToolMode || state.canSave,
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
        // §2: opaque over the page, up through the status bar.
        .background(Token.layoutBackground.ignoresSafeArea(.container, edges: .top))
        .ui2Element("C-040 PageHeader")
        // §3 Manipulating: chrome hidden (fades out); the layout keeps its place.
        .opacity(mode == .manipulating ? 0 : 1)
    }

    // MARK: - §2 item 3: the canvas

    private func canvas(unit: CGFloat, viewport: CGFloat, safeTop: CGFloat) -> some View {
        let objects = shownObjects
        // §2: fixed at drag start, so neither the page nor any object re-places under the finger.
        let extent = dragExtent ?? measuredExtent(objects)
        let headerBottom = (safeTop + Self.headerHeight) / unit
        let containerTop = viewport - (containerHeight + keyboardOverlap) / unit
        let pinned = actions.contains { $0.placement == .pinned }
        let offset = pageOffset(viewport: viewport, extent: extent, pinned: pinned)
        return ActivityCanvas<AnyView>(
            background: background,
            mode: mode,
            content: { AnyView(canvasContent(objects, unit: unit)) },
            onTapEmpty: onTapEmpty,
            centerGuide: state.centerGuide,
            deleteTarget: state.deleteTargetShown ? .visible : nil,
            verticalAnchor: .center,
            contentExtent: extent,
            // §2 (D3): the screen only turns the guides on.
            reservedZones: mode == .manipulating,
            pinnedAction: pinned,
            widthHandles: mode == .editing ? widthHandles(pageOffset: offset) : nil,
            onResizeWidth: resizeDraft,
            // §2: the screen's bars cover the page's ends; the range reaches past both.
            scrollInsets: .init(top: headerBottom, bottom: viewport - containerTop),
            dragPoint: dragPoint,
            onAutoscroll: { moved in
                dragScroll += moved
                if let dragged { emit(dragged.transform, index: dragged.index) }
            }
        )
        .coordinateSpace(.named(Self.screenSpace))
        .overlay(alignment: .topLeading) {
            if mode == .editing {
                // §2 item 3 handle / thumb separation (1): C-091 draws its handles above its slot,
                // so the slider sits over the canvas — above them in hit order, and fixed to the
                // viewport. Centred on the edit slot, clamped between the header and the container.
                TextSizeSlider(value: sliderValue, onChange: { value in
                    if let editedIndex { apply(.init(index: editedIndex, size: CGFloat(Self.size(forSlider: value)))) }
                })
                    .ui2Element("C-093 TextSizeSlider")
                    // FLAGGED LITERAL — activities-editor §2: slider 20×263.5 at x 11.
                    .offset(x: Self.sliderX,
                            y: max(min(Self.editSlotY + offset - Self.sliderHeight / 2, containerTop - Self.sliderHeight),
                                   headerBottom))
                    .scaleEffect(unit, anchor: .topLeading)
            }
        }
    }

    /// C-091's `content` slot, laid out in wu: the committed objects at their transforms, the
    /// edited object at the edit slot and the inline action previews.
    private func canvasContent(_ objects: [CommittedObject], unit: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(objects.indices, id: \.self) { index in
                if index != editedIndex {
                    committedObject(objects[index], index: index, unit: unit, extent: measuredExtent(objects))
                }
            }
            if let editedIndex, let edited {
                editedObject(edited, index: editedIndex)
            }
            actionPreviews(objects)
        }
    }

    private func committedObject(_ object: CommittedObject, index: Int, unit: CGFloat,
                                 extent: ClosedRange<CGFloat>?) -> some View {
        CanvasTextObject(
            text: object.text,
            font: object.font,
            weight: object.weight,
            size: object.size,
            color: object.color,
            alignment: object.alignment,
            listStyle: object.listStyle,
            startNumber: object.startNumber,
            transform: object.transform,
            onTransform: { emit($0, index: index) },
            editing: false,
            highlights: object.highlights,
            onTap: { onTapObject(index) }
        )
        // C-092 never offsets itself (its §2): the screen places it at `transform.position`.
        .frame(width: object.transform.width ?? Self.editSlotWidth)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeights[index] = $0 }
        .ui2Element(index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)")
        .simultaneousGesture(
            // pan-ok: reads the touch on both axes for §2's autoscroll; C-092 owns the move itself
            DragGesture(coordinateSpace: .named(Self.screenSpace))
                .onChanged { drag in
                    if dragExtent == nil { dragExtent = .some(extent) }
                    dragPoint = CGPoint(x: drag.location.x / unit, y: drag.location.y / unit)
                }
                .onEnded { _ in
                    dragPoint = nil
                    dragExtent = nil
                    dragScroll = 0
                    endGesture()
                }
        )
        // §9.1a: a pinch or rotate with no drag still ends the gesture and reports once.
        .simultaneousGesture(
            SimultaneousGesture(MagnifyGesture(), RotateGesture())
                .onEnded { _ in endGesture() }
        )
        .position(object.transform.position)
    }

    /// §2 Autoscroll: C-092 reports its move from where the drag started, so what autoscroll has
    /// moved the page goes back on, keeping the object under the finger.
    /// §9.1a: each frame goes to the display only; `endGesture` reports the final transform once.
    private func emit(_ transform: CanvasTextObject.Transform, index: Int) {
        if dragged == nil, shownObjects.indices.contains(index) {
            let start = shownObjects[index].transform
            gestureStart = .init(x: start.position.x, y: start.position.y,
                                 scale: start.scale, rotation: start.rotation.degrees)
        }
        dragged = (index, transform)
        var next = transform
        next.position.y += dragScroll
        apply(.init(index: index, transform: .init(x: next.position.x, y: next.position.y,
                                                   scale: next.scale, rotation: next.rotation.degrees)),
              report: false)
    }

    /// §9.1a: the gesture ended — one `ObjectEdit` with the final transform (none when nothing
    /// moved); the container's next `State` re-seeds the display as usual.
    private func endGesture() {
        guard let index = dragged?.index else { return }
        dragged = nil
        let start = gestureStart
        gestureStart = nil
        if shownObjects.indices.contains(index) {
            let shown = shownObjects[index].transform
            let final = ObjectEdit.Transform(x: shown.position.x, y: shown.position.y,
                                             scale: shown.scale, rotation: shown.rotation.degrees)
            if final != start { onEditObject(.init(index: index, transform: final)) }
        }
    }

    /// §9.1: applies one edit to the display state, then reports it — no wait for the echo.
    /// §9.1a: a gesture frame passes `report: false` (display only).
    private func apply(_ edit: ObjectEdit, report: Bool = true) {
        guard shownObjects.indices.contains(edit.index) else { return }
        var object = shownObjects[edit.index]
        if let text = edit.text { object.text = text }
        if let font = edit.font { object.font = Self.font(font) }
        if let weight = edit.weight { object.weight = Self.weight(code: weight) }
        if let size = edit.size { object.size = size }
        if let color = edit.color { object.colorHex = color }
        if let alignment = edit.alignment { object.alignment = Self.alignment(alignment) }
        if let width = edit.width { object.transform.width = width }
        if let transform = edit.transform {
            object.transform.position = CGPoint(x: transform.x, y: transform.y)
            object.transform.scale = transform.scale
            object.transform.rotation = .degrees(transform.rotation)
        }
        shownObjects[edit.index] = object
        if report { onEditObject(edit) }
    }

    /// §3 Editing: the edited object's index in `State.objects`, while Editing.
    private var editedIndex: Int? {
        guard mode == .editing, shownObjects.indices.contains(state.editingIndex) else { return nil }
        return state.editingIndex
    }

    private var edited: CommittedObject? { editedIndex.map { shownObjects[$0] } }

    /// §2 item 3 + §3 Editing: the edited object alone at the edit slot, centred on 478 wu before
    /// C-091's offset; alignment anchors a narrower block 24 wu from the canvas edge (tool 3).
    private func editedObject(_ object: CommittedObject, index: Int) -> some View {
        CanvasTextObject(
            text: object.text,
            onChange: { apply(.init(index: index, text: $0)) },
            font: object.font,
            weight: object.weight,
            size: object.size,
            color: object.color,
            alignment: object.alignment,
            animation: draftAnimation,
            animationStart: draftAnimationStart,
            effect: draftEffect,
            editing: true
        )
        .frame(width: draftLayoutWidth)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredDraftHeight = $0 }
        .ui2Element(index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)")
        .position(x: draftCentreX, y: Self.editSlotY)
    }

    /// §2 item 3 (D8): an inline action previews as C-105, 24 wu below the last object.
    @ViewBuilder
    private func actionPreviews(_ objects: [CommittedObject]) -> some View {
        let inline = actions.filter { $0.placement == .inline }
        ForEach(Array(inline.enumerated()), id: \.element.id) { index, action in
            Button(label: action.label, onTap: { openSheet = .actions })
                .ui2Element(index == 0 ? "C-105 Button" : "C-105 Button \(index + 1)")
                .position(x: Self.referenceWidth / 2,
                          y: objectsBottom(objects) + Self.inlineActionGap + Self.actionButtonHeight / 2
                              + CGFloat(index) * (Self.actionButtonHeight + Self.inlineActionGap))
        }
    }

    /// §2 item 4 `edit-highlights`: the highlight actions — C-102 outlined destructive trash at
    /// the leading margin, C-105 "Add note" at the trailing one — shown only while a highlight
    /// is selected (OQ-012).
    private func selectionRow(unit: CGFloat) -> some View {
        HStack(spacing: 0) {
            IconButton(
                glyph: .trash2,
                tone: .destructive,
                style: .outlined,
                selected: false,
                accessibilityLabel: Self.deleteHighlightLabel,
                onTap: onDeleteHighlight
            )
            .ui2Element("C-102 IconButton \(visibleTools.count + 1)")
            Spacer(minLength: 0)
            Button(label: Self.addNoteLabel, leadingGlyph: .addLargeCarbon, onTap: onAddNote)
                .ui2Element("C-105 Button")
        }
        .frame(width: Self.referenceWidth - 2 * Token.Space.pageMargin, height: Self.actionButtonHeight)
        .scaleEffect(unit)
        .frame(width: (Self.referenceWidth - 2 * Token.Space.pageMargin) * unit, height: Self.actionButtonHeight * unit)
        // FLAGGED LITERAL — activities-editor §2: the Selection row's bottom edge 8 wu above the
        // container (y 837 above a container at 879 on the 956 sample).
        .padding(.bottom, Self.selectionRowGap * unit)
    }

    // MARK: - §2 item 4: the bottom container

    /// One container: the panel slot and the tool row (or C-081 in Idle), with C-081's bar surface
    /// — its host's fill and a 1 px top hairline, edge to edge — riding the keyboard as one unit.
    private var bottomContainer: some View {
        VStack(spacing: 0) {
            bottomPanel
            if isToolMode {
                toolRow
            } else {
                ActivityNavBar(slides: slides, activeID: state.activeID,
                               onSelectSlide: onSelectSlide, onAdd: onAdd)
                    .ui2Element("C-081 ActivityNavBar")
            }
        }
        .background(Token.layoutBackground)
        .overlay(alignment: .top) {
            Token.layoutBorder
                // GAP — activities-editor §2 item 4: 1 px hairline, no stroke token.
                .frame(height: Self.hairline)
        }
        // The container states its own height; the canvas takes what is left (§2).
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .offset(y: -keyboardOverlap)
    }

    private var keyboardOverlap: CGFloat { max(containerBottom - keyboardTop, 0) }

    @ViewBuilder private var bottomPanel: some View {
        if mode == .editing {
            switch openTool {
            case .color:
                // §3 tool 1: C-094 — the well shows the object's colour, the equal swatch is
                // outlined (OQ-011); pages 2–3 are undesigned (04-color.md OQ-04-1) and empty.
                // §9.2: a tap resolves to its preset's hex; a colour no preset holds outlines none.
                TextColorPalette(
                    currentColor: edited?.color ?? Token.textPrimary,
                    swatches: Self.palettePages,
                    page: palettePage,
                    onSelect: { picked in
                        guard let editedIndex,
                              let preset = Self.swatchPresets.first(where: { Self.hexColor($0.hex) == picked })
                        else { return }
                        apply(.init(index: editedIndex, color: preset.hex))
                    },
                    onPageChange: { palettePage = $0 },
                    onWellTap: onEyedropper,
                    // §2 item 5: hidden, not disabled — no well unless the eyedropper is shown.
                    showsWell: state.showsEyedropper
                )
                .ui2Element("C-094 TextColorPalette")
            case .font:
                // §3 tool 4: the weight row above the font strip. C-106 is 8 + 36 + 8 tall, so the
                // two share one 8pt inset and the panel is §2's 96.
                VStack(spacing: -Token.Space.elementGap) {
                    ChipStrip(items: Self.weightItems, selectedID: Self.weightID(edited?.weight ?? .bold),
                              onSelect: { id in
                                  if let editedIndex { apply(.init(index: editedIndex, weight: Self.weightCode(Self.weight(id)))) }
                              })
                        .ui2Element("C-106 ChipStrip")
                    ChipStrip(items: Self.fontItems, selectedID: Self.fontID(edited?.font ?? .sans),
                              onSelect: { id in
                                  if let editedIndex { apply(.init(index: editedIndex, font: id)) }
                              })
                        .ui2Element("C-106 ChipStrip 2")
                }
            case .animation where state.showsEffectsTool:
                // §3 tool 6 (OQ-007): one combined strip — none, the animations, the effects.
                // C-106 has one `selectedID`, so it shows the animation when one is set, else the
                // effect (gap: two independent selections, one selected chip).
                ChipStrip(items: Self.animationItems, selectedID: animationSelectedID,
                          onSelect: selectAnimation)
                    .ui2Element("C-106 ChipStrip")
            default:
                // Tools 2 and 7 present a sheet (§6); tools 3 and 5 have no panel.
                EmptyView()
            }
        }
    }

    // MARK: - §2 item 5: the tool row

    /// §2 item 5: hidden tools are not in the layout, the accessibility tree or the focus order.
    private var visibleTools: [Tool] {
        Tool.allCases.filter { tool in
            switch tool {
            case .highlight: return state.showsHighlightTool
            case .animation: return state.showsEffectsTool
            default: return true
            }
        }
    }

    /// §2 item 5: plain C-102 IconButtons the screen lays out itself (owner ruling 2026-10-10),
    /// 32pt, left to right, centred in the span and vertically centred in the 76pt row (y +22).
    /// The pitch fits any number of visible tools to the width given.
    private var toolRow: some View {
        GeometryReader { proxy in
            HStack(spacing: Self.toolPitch(width: proxy.size.width, count: visibleTools.count) - Self.toolSize) {
                ForEach(Array(visibleTools.enumerated()), id: \.element) { index, tool in
                    IconButton(
                        glyph: Self.glyph(for: tool),
                        tone: .default,
                        style: .plain,
                        selected: isSelected(tool),
                        accessibilityLabel: Self.toolLabel(tool),
                        onTap: { tap(tool) }
                    )
                    // FLAGGED LITERAL — activities-editor §2: 32pt tools.
                    .frame(width: Self.toolSize, height: Self.toolSize)
                    .ui2Element(index == 0 ? "C-102 IconButton" : "C-102 IconButton \(index + 1)")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // GAP — activities-editor §2 item 5: the 76pt row, no spacing token.
        .frame(height: Self.barHeight)
    }

    /// §2 item 5: `min(64, (W − 2 × 44 − 32) ÷ (n − 1))` — 64 whenever it fits, an even shrink when
    /// not. Under 40 the side inset relaxes from 44 toward 16 before the pitch shrinks further.
    private static func toolPitch(width: CGFloat, count: Int) -> CGFloat {
        let maxPitch = toolSize + Token.Space.toolbarGap
        guard count > 1 else { return maxPitch }
        let gaps = CGFloat(count - 1)
        let fitted = (width - 2 * toolRowInset - toolSize) / gaps
        if fitted >= minToolPitch { return min(maxPitch, fitted) }
        return min(minToolPitch, (width - 2 * Token.Space.pageMargin - toolSize) / gaps)
    }

    /// §3 Tools: category tools (1, 2, 4, 6, 7) take `selected` while their panel or sheet is
    /// open; 3 is never selected; 5 is selected while Highlighting is on.
    private func isSelected(_ tool: Tool) -> Bool {
        switch tool {
        case .alignment: return false
        case .highlight: return mode == .highlighting
        case .background, .actions: return openSheet == tool
        default: return mode == .editing && openTool == tool
        }
    }

    private func tap(_ tool: Tool) {
        switch tool {
        case .alignment:
            // §3 tool 3: center → left → right → center, no panel.
            guard let editedIndex else { return }
            let next: String
            switch draftAlignment {
            case .center: next = "left"
            case .left: next = "right"
            case .right: next = "center"
            }
            apply(.init(index: editedIndex, alignment: next))
        case .highlight:
            onToggleHighlight()
        case .background, .actions:
            openSheet = tool
        default:
            openTool = tool
        }
    }

    // MARK: - §6: the sheets

    /// §6 names both sheets as overlays. Presentation through the app's typed `Route` is the
    /// container's wiring (§5, out of this screen's scope); here they are drawn in place, with no
    /// `.sheet` or `.fullScreenCover`.
    @ViewBuilder private var sheetOverlay: some View {
        if let openSheet {
            // §2 item 4: the sheet's height is capped at the screen minus the safe top and 16pt.
            GeometryReader { screen in
                ZStack(alignment: .bottom) {
                    Token.black50
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { self.openSheet = nil }
                        .accessibilityLabel(Self.closeSheetLabel)
                        .accessibilityAddTraits(.isButton)
                    Group {
                        if openSheet == .background {
                            backgroundSheet
                        } else {
                            ActionsSheet(
                                actions: actions,
                                onCancel: { self.openSheet = nil },
                                onDone: { edited in
                                    actions = edited
                                    onChangeActions(edited)
                                    self.openSheet = nil
                                }
                            )
                        }
                    }
                    .frame(maxHeight: sheetLayout(screen).maxHeight, alignment: .bottom)
                    .offset(y: -sheetLayout(screen).lift)
                }
            }
            // §2 item 6: the keyboard lifts a sheet ONCE, by `keyboardOverlap`. The overlay sits outside
            // the page's `.ignoresSafeArea(.keyboard)`, so without `.keyboard` here SwiftUI's avoidance
            // lifted it too, and the double lift put its header and Done off the top (walk round 2).
            .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        }
    }

    private func sheetLayout(_ screen: GeometryProxy) -> (maxHeight: CGFloat, lift: CGFloat) {
        Self.sheetLayout(available: screen.size.height, keyboardOverlap: keyboardOverlap)
    }

    /// §2 items 4 + 6: a sheet stands on the keyboard's top edge — lifted by the overlap, once — and
    /// its cap (the screen minus the safe top and 16pt) shrinks by that overlap, so its fixed header
    /// and Done stay on screen while the body scrolls. `available` is the overlay's height below the
    /// safe top.
    static func sheetLayout(available: CGFloat, keyboardOverlap: CGFloat) -> (maxHeight: CGFloat, lift: CGFloat) {
        let room = max(available - sheetTopGap, 0)
        let lift = min(max(keyboardOverlap, 0), room)
        return (room - lift, lift)
    }

    private var backgroundSheet: some View {
        BackgroundSheet(
            pageColor: pageColor,
            image: background.image,
            focal: pageFocal,
            washColor: pageWashColor,
            washOpacity: pageWashOpacity,
            swatches: Self.palettePages,
            showsWell: state.showsEyedropper,
            onPageColor: { pageColor = $0; onChangeBackground(background) },
            onPickImage: onPickImage,
            onFocal: { pageFocal = $0; onChangeBackground(background) },
            onWashColor: { pageWashColor = $0; onChangeBackground(background) },
            onWashOpacity: { pageWashOpacity = $0; onChangeBackground(background) }
        )
    }

    // MARK: - Derived values

    /// §2 item 3 (D4; 02 §5): the document's background layer. `motion` keeps C-091's default here
    /// and is never drawn or exposed; the document's own value is the container's to carry.
    private var background: ActivityCanvas<AnyView>.Background {
        var result = ActivityCanvas<AnyView>.Background(color: pageColor)
        if !state.pageImageURL.isEmpty, let url = URL(string: state.pageImageURL) {
            result.image = .init(imageURL: url, focal: pageFocal)
            if pageWashOpacity > 0 {
                result.wash = .init(color: pageWashColor, opacity: pageWashOpacity)
            }
        }
        return result
    }

    /// One committed C-092, resolved from `State` with §3's defaults. Lengths are wu.
    private struct CommittedObject {
        var text: String
        var font: CanvasTextObject.Font
        var weight: CanvasTextObject.Weight
        var size: CGFloat
        /// §9.2: `#RRGGBB`; "" = the §3 default `color-text-primary`.
        var colorHex: String
        var alignment: CanvasTextObject.Alignment
        var listStyle: CanvasTextObject.ListStyle
        var startNumber: Int
        var transform: CanvasTextObject.Transform
        var highlights: [CanvasTextObject.TextRange]

        var color: Color { ActivitiesEditorScreen.hexColor(colorHex) ?? Token.textPrimary }
    }

    /// `State.objects`, resolved with §3's defaults — the seed of the display state (§9.1).
    private static func committedObjects(_ state: State) -> [CommittedObject] {
        var result = state.objectTexts.indices.map { index in
            CommittedObject(
                text: state.objectTexts[index],
                font: font(element(state.objectFonts, index, "")),
                weight: weight(element(state.objectWeights, index, "")),
                size: CGFloat(element(state.objectSizes, index, defaultSize)),
                colorHex: element(state.objectColors, index, ""),
                alignment: alignment(element(state.objectAlignments, index, "")),
                listStyle: listStyle(element(state.objectListStyles, index, "")),
                startNumber: element(state.objectStartNumbers, index, 1),
                transform: .init(
                    position: CGPoint(x: element(state.objectXs, index, Double(referenceWidth / 2)),
                                      y: element(state.objectYs, index, Double(editSlotY))),
                    scale: CGFloat(element(state.objectScales, index, 1)),
                    rotation: .degrees(element(state.objectRotations, index, 0)),
                    width: objectWidth(state, index)
                ),
                highlights: highlights(state, forObject: index)
            )
        }
        if !state.verseTexts.isEmpty {
            // §3 (D55): a passage added as a single block is one C-092 whose items are the verses.
            result.append(CommittedObject(
                text: state.verseTexts.joined(separator: "\n"),
                font: .sans,
                weight: .regular,
                size: passageSize,
                colorHex: "",
                alignment: .left,
                listStyle: .bibleVerse,
                startNumber: state.firstVerse,
                transform: .init(position: CGPoint(x: referenceWidth / 2, y: editSlotY),
                                 scale: 1, rotation: .zero, width: nil),
                highlights: highlights(state, forObject: state.objectTexts.count)
            ))
        }
        return result
    }

    private static func objectWidth(_ state: State, _ index: Int) -> CGFloat? {
        let width = element(state.objectWidths, index, 0)
        return width > 0 ? CGFloat(width) : nil
    }

    private static func highlights(_ state: State, forObject index: Int) -> [CanvasTextObject.TextRange] {
        let count = [state.highlightObjects.count, state.highlightStarts.count, state.highlightEnds.count].min() ?? 0
        return (0..<count).compactMap { i in
            guard state.highlightObjects[i] == index, state.highlightStarts[i] <= state.highlightEnds[i] else { return nil }
            return .init(start: state.highlightStarts[i], end: state.highlightEnds[i], note: nil)
        }
    }

    /// An object's height in wu: measured live, else the capture's seed, else one line per item.
    private func objectHeight(_ object: CommittedObject, index: Int) -> CGFloat {
        if let measured = measuredHeights[index] { return measured }
        if index < state.objectHeights.count { return CGFloat(state.objectHeights[index]) }
        let lines = object.text.split(separator: "\n", omittingEmptySubsequences: false).count
        return object.size * Self.lineHeightFactor * CGFloat(lines)
    }

    /// §4 C-091 `contentExtent`: top…bottom of every object's rotated, scaled box (wu), the edited
    /// object and the inline action previews included. nil = nothing on the page.
    private func measuredExtent(_ objects: [CommittedObject]) -> ClosedRange<CGFloat>? {
        var top = CGFloat.infinity
        var bottom = -CGFloat.infinity
        for (index, object) in objects.enumerated() where index != editedIndex {
            let radians = object.transform.rotation.radians
            let width = (object.transform.width ?? Self.editSlotWidth) * object.transform.scale
            let height = objectHeight(object, index: index) * object.transform.scale
            let half = (abs(width * sin(radians)) + abs(height * cos(radians))) / 2
            top = min(top, object.transform.position.y - half)
            bottom = max(bottom, object.transform.position.y + half)
        }
        if mode == .editing {
            top = min(top, Self.editSlotY - draftHeight / 2)
            bottom = max(bottom, Self.editSlotY + draftHeight / 2)
        }
        guard top <= bottom else { return nil }
        let inlineCount = actions.filter { $0.placement == .inline }.count
        return top...(bottom + CGFloat(inlineCount) * (Self.inlineActionGap + Self.actionButtonHeight))
    }

    private func objectsBottom(_ objects: [CommittedObject]) -> CGFloat {
        guard !objects.isEmpty || mode == .editing else { return Self.editSlotY }
        var bottom = mode == .editing ? Self.editSlotY + draftHeight / 2 : -CGFloat.infinity
        for (index, object) in objects.enumerated() where index != editedIndex {
            let radians = object.transform.rotation.radians
            let width = (object.transform.width ?? Self.editSlotWidth) * object.transform.scale
            let height = objectHeight(object, index: index) * object.transform.scale
            bottom = max(bottom, object.transform.position.y + (abs(width * sin(radians)) + abs(height * cos(radians))) / 2)
        }
        return bottom
    }

    /// C-091 §2 Sizing, for the one place the screen needs it: `widthHandles.frame` is page-local
    /// and the slider follows the edit slot, while C-091 keeps the slot's offset to itself.
    private func pageOffset(viewport: CGFloat, extent: ClosedRange<CGFloat>?, pinned: Bool) -> CGFloat {
        let offset = (viewport - Self.referenceHeight) / 2
        guard let extent else { return offset }
        let bottomInset = Self.pageEndSpace + (pinned ? Self.pinnedHeight : 0)
        guard extent.upperBound - extent.lowerBound <= viewport - Self.pageTopInset - bottomInset else {
            return Self.pageTopInset - extent.lowerBound
        }
        if extent.lowerBound + offset < Self.pageTopInset { return Self.pageTopInset - extent.lowerBound }
        if extent.upperBound + offset > viewport - bottomInset { return viewport - bottomInset - extent.upperBound }
        return offset
    }

    private var draftHeight: CGFloat {
        measuredDraftHeight ?? draftSize * Self.lineHeightFactor
    }

    // The edited object's style and width (§3 Editing), or the §3 defaults while none is.
    private var draftSize: CGFloat { edited?.size ?? CGFloat(Self.defaultSize) }
    private var draftAlignment: CanvasTextObject.Alignment { edited?.alignment ?? .center }
    private var draftLayoutWidth: CGFloat { edited?.transform.width ?? Self.editSlotWidth }

    /// §3 tool 3: the edit slot re-anchors 24 wu from the canvas edge.
    private var draftCentreX: CGFloat {
        switch draftAlignment {
        case .center: return Self.referenceWidth / 2
        case .left: return Self.editSlotInset + draftLayoutWidth / 2
        case .right: return Self.referenceWidth - Self.editSlotInset - draftLayoutWidth / 2
        }
    }

    /// §2 item 3 handle / thumb separation (2): while the object's left edge is inside the slider
    /// column the handles ride 14 wu inside the text edge, so the left one clears the thumb.
    private var handleInset: CGFloat {
        draftCentreX - draftLayoutWidth / 2 < Self.sliderColumn ? Self.handleInsetWhenCrowded : 0
    }

    private func widthHandles(pageOffset: CGFloat) -> ActivityCanvas<AnyView>.WidthHandles {
        .init(
            frame: CGRect(x: draftCentreX - draftLayoutWidth / 2 + handleInset,
                          y: Self.editSlotY + pageOffset - draftHeight / 2,
                          width: draftLayoutWidth - 2 * handleInset,
                          height: draftHeight),
            rotation: .zero
        )
    }

    /// §2 item 3: `onResizeWidth` reports the handles' width; the inset goes back on, then clamps.
    private func resizeDraft(_ handleWidth: CGFloat) {
        guard let editedIndex else { return }
        let width = handleWidth + 2 * handleInset
        apply(.init(index: editedIndex, width: min(max(width, Self.minObjectWidth), Self.editSlotWidth)))
    }

    /// C-081 `slides`: every slide is a C-061 chip — `image` nil (§1 deviation 10, D52).
    private var slides: [ActivityNavBar.Slide] {
        zip(state.slideIDs, state.slideLabels).map { ActivityNavBar.Slide(id: $0, image: nil, label: $1) }
    }

    /// C-093 `value`: the object's `size` along the track (OQ-015: 12–64 wu, linear, top = 64).
    private var sliderValue: CGFloat {
        (draftSize - CGFloat(Self.minSize)) / CGFloat(Self.maxSize - Self.minSize)
    }

    private var animationSelectedID: String {
        if draftAnimation.kind != .none { return "\(draftAnimation.kind)" }
        if draftEffect != .none { return "\(draftEffect)" }
        return Self.noneID
    }

    private func selectAnimation(_ id: String) {
        if id == Self.noneID {
            draftAnimation = .none
            draftEffect = .none
        } else if let kind = Self.animations.first(where: { "\($0)" == id }) {
            draftAnimation = .init(kind: kind, loop: true)
        } else if let effect = Self.effects.first(where: { "\($0)" == id }) {
            draftEffect = effect
        }
        // C-092 §2 Animation: the host owns the clock; the editor runs it while one is chosen.
        draftAnimationStart = draftAnimation.kind == .none && draftEffect == .none ? nil : .now
    }

    /// One element of a parallel array, or `fallback` when the array is short.
    private static func element<Value>(_ values: [Value], _ index: Int, _ fallback: Value) -> Value {
        index < values.count ? values[index] : fallback
    }

    // MARK: - Mappings

    private static func pageActions(_ state: State) -> [PageAction] {
        state.actionIDs.indices.map { index in
            func value(_ values: [String]) -> String { index < values.count ? values[index] : "" }
            return PageAction(
                id: state.actionIDs[index],
                kind: PageAction.Kind(rawValue: value(state.actionKinds)) ?? .addToPrayerList,
                label: value(state.actionLabels),
                placement: PageAction.Placement(rawValue: value(state.actionPlacements)) ?? .inline,
                value: value(state.actionValues),
                body: value(state.actionBodies)
            )
        }
    }

    private static func font(_ name: String) -> CanvasTextObject.Font {
        switch name {
        case "display": return .display
        case "serif": return .serif
        case "mono": return .mono
        default: return .sans                               // C-092 §2: an unknown key is `sans`
        }
    }

    private static func fontID(_ font: CanvasTextObject.Font) -> String {
        switch font {
        case .display: return "display"
        case .sans: return "sans"
        case .serif: return "serif"
        case .mono: return "mono"
        }
    }

    private static func weight(_ name: String) -> CanvasTextObject.Weight {
        switch name {
        case "regular": return .regular
        case "medium": return .medium
        default: return .bold                               // §3: default 700
        }
    }

    /// §9.1 `ObjectEdit.weight`: 400 · 500 · 700.
    private static func weightCode(_ weight: CanvasTextObject.Weight) -> Int {
        switch weight {
        case .regular: return 400
        case .medium: return 500
        case .bold: return 700
        }
    }

    private static func weight(code: Int) -> CanvasTextObject.Weight {
        switch code {
        case 400: return .regular
        case 500: return .medium
        default: return .bold
        }
    }

    private static func weightID(_ weight: CanvasTextObject.Weight) -> String {
        switch weight {
        case .regular: return "regular"
        case .medium: return "medium"
        case .bold: return "bold"
        }
    }

    private static func alignment(_ name: String) -> CanvasTextObject.Alignment {
        switch name {
        case "left": return .left
        case "right": return .right
        default: return .center                             // §3: default center
        }
    }

    private static func listStyle(_ name: String) -> CanvasTextObject.ListStyle {
        switch name {
        case "bullet": return .bullet
        case "numbered": return .numbered
        case "bibleVerse": return .bibleVerse
        default: return .none
        }
    }

    /// §2 item 4 / deviation 5 + §9.2: the nine C-094 presets, in order, as (name, hex) pairs —
    /// the name is for accessibility only; a tap resolves to the hex, which is what `State` and
    /// `ObjectEdit` carry. White and black are `color-white-100` and `color-black`'s values.
    private static let swatchPresets: [(name: String, hex: String)] = [
        ("White", "#FFFFFF"),
        ("Black", "#000000"),
        // FLAGGED LITERAL — activities-editor §1 deviation 5: swatch hues, no colour token.
        ("Blue", "#509CEF"),
        ("Green", "#76C257"),
        ("Yellow", "#F6CB61"),
        ("Orange", "#EF8F3B"),
        ("Red", "#EA4F5E"),
        ("Pink", "#D43570"),
        ("Purple", "#A92BBD")
    ]

    /// C-094 `swatches`: page 1 as drawn; pages 2–3 undesigned (04-color.md OQ-04-1), empty so
    /// C-097 still draws the three designed dots. The outlined swatch is the one whose hex equals
    /// the current colour (§9.2); a colour no preset holds outlines none.
    private static let palettePages: [[TextColorPalette.NamedColor]] = [
        swatchPresets.map { TextColorPalette.NamedColor(name: $0.name, color: hexColor($0.hex) ?? Token.textPrimary) },
        [],
        []
    ]

    /// A colour is the leader's data, decoded from its #rrggbb (data, not style; §9.2).
    private static func hexColor(_ hex: String) -> Color? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return nil }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255,
                     green: Double((rgb >> 8) & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }

    /// §2 item 4: the four font keys, labelled with their bundled families (D6).
    private static let fontItems: [ChipStrip.Item] = [
        .init(id: "display", label: "Poppins", font: .display),
        .init(id: "sans", label: "Inter", font: .sans),
        .init(id: "serif", label: "Source Serif 4", font: .serif),
        .init(id: "mono", label: "Courier Prime", font: .mono)
    ]

    /// §3 tool 4 (D5): 400 · 500 · 700.
    private static let weightItems: [ChipStrip.Item] = [
        .init(id: "regular", label: "Regular"),
        .init(id: "medium", label: "Medium"),
        .init(id: "bold", label: "Bold")
    ]

    private static let noneID = "none"
    private static let animations: [CanvasTextObject.Animation.Kind] = [.typewriter, .pop, .jump]
    private static let effects: [CanvasTextObject.Effect] = [.sparkle, .neon, .shimmer, .pixel]

    /// §3 tool 6 (OQ-007): ⊗ none first, the three animations, then the four effects.
    private static let animationItems: [ChipStrip.Item] =
        [.init(id: noneID, label: "None")]
        + animations.map { .init(id: "\($0)", label: "\($0)".capitalized) }
        + effects.map { .init(id: "\($0)", label: "\($0)".capitalized) }

    /// §2 item 5: tool 7 is the library's `zap`. The others are interim glyphs (OQ-017 — the
    /// designed glyphs are not minted yet); tool 1's gradient sphere is artwork C-102 cannot
    /// carry, so `palette` stands in.
    private static func glyph(for tool: Tool) -> GlyphName {
        switch tool {
        case .color: return .palette
        case .background: return .file
        case .alignment: return .menu
        case .font: return .textContent
        case .highlight: return .edit
        case .animation: return .sparkles
        case .actions: return .zap
        }
    }

    /// R-17: each tool's accessibility label, from §3 Tools.
    private static func toolLabel(_ tool: Tool) -> String {
        switch tool {
        case .color: return "Colour"
        case .background: return "Background"
        case .alignment: return "Alignment"
        case .font: return "Font and weight"
        case .highlight: return "Highlight"
        case .animation: return "Animation and effects"
        case .actions: return "Actions"
        }
    }

    /// OQ-015: the slider's wu range and its 50 % default.
    private static func size(forSlider value: CGFloat) -> Double {
        minSize + Double(value) * (maxSize - minSize)
    }

    // §2 copy.
    private static let title = "Edit lesson"
    private static let deleteHighlightLabel = "Delete highlight"
    private static let addNoteLabel = "Add note"
    private static let closeSheetLabel = "Close"
    // §9.4 Load-failed copy and the banner's 2 s before the pop.
    private static let loadFailedMessage = "Couldn't load this activity."
    private static let loadFailedDelay = Duration.seconds(2)
    // §3 Error copy (proposed).
    private static let errorTitle = "Couldn't save activity"
    private static let retryLabel = "Retry"
    private static let discardLabel = "Discard changes"

    /// §2 Units (D1; 02 §4): the reference space.
    private static let referenceWidth: CGFloat = 440
    private static let referenceHeight: CGFloat = 956
    /// C-091 §2 Sizing, read by `pageOffset`: T 107 and B 85 wu.
    private static let pageTopInset: CGFloat = 107
    private static let pageEndSpace: CGFloat = 85
    /// GAP — activities-editor §3 / OQ-015: 12–64 wu, linear; the 50 % thumb is 38 wu.
    private static let minSize: Double = 12
    private static let maxSize: Double = 64
    private static let defaultSize: Double = 38
    /// GAP — activities-editor §2 item 3 `edit-highlights`: the passage's 17 wu verse text.
    private static let passageSize: CGFloat = 17
    /// FLAGGED LITERAL — activities-editor §2 item 2: C-040's height under the safe top.
    private static let headerHeight: CGFloat = 56
    /// FLAGGED LITERAL — activities-editor §2 item 4: the sheet cap's 16pt gap under the safe top.
    private static let sheetTopGap: CGFloat = 16
    /// The canvas's own space: the whole screen, in points (§2 Autoscroll's touch).
    private static let screenSpace = "ActivitiesEditorScreen.canvas"
    /// GAP — activities-editor §2 item 5: the tool row, 76pt.
    private static let barHeight: CGFloat = 76
    /// FLAGGED LITERAL — activities-editor §2 item 5: the 44 inset and the 40 pitch floor.
    private static let toolRowInset: CGFloat = 44
    private static let minToolPitch: CGFloat = 40
    /// FLAGGED LITERAL — activities-editor §2: 32pt tools.
    private static let toolSize: CGFloat = 32
    /// GAP — activities-editor §2 item 2: the 1px hairline.
    private static let hairline: CGFloat = 1
    /// activities-editor §2 item 3: the edit slot — 392 wu wide (440 − 2 × 24), centred on 478 wu.
    private static let editSlotInset: CGFloat = 24
    private static let editSlotWidth: CGFloat = 392
    private static let editSlotY: CGFloat = 478
    /// FLAGGED LITERAL — C-092 §2: the 80 wu minimum layout width.
    private static let minObjectWidth: CGFloat = 80
    /// FLAGGED LITERAL — activities-editor §2 item 3: the slider at x 11, 263.5 tall; its column
    /// ends at frame x 38; the handles' 14 wu inset.
    private static let sliderX: CGFloat = 11
    private static let sliderHeight: CGFloat = 263.5
    private static let sliderColumn: CGFloat = 38
    private static let handleInsetWhenCrowded: CGFloat = 14
    /// FLAGGED LITERAL — activities-editor §2: Selection row 8 wu above the container.
    private static let selectionRowGap: CGFloat = 8
    /// FLAGGED LITERAL — activities-editor §2: inline action 24 wu below; C-105 is 36 tall;
    /// pinned pill 46 wu tall, 16 wu inset.
    private static let inlineActionGap: CGFloat = 24
    private static let actionButtonHeight: CGFloat = 36
    private static let pinnedHeight: CGFloat = 46
    private static let pinnedInset: CGFloat = 16
    /// GAP — C-091 §4 `contentExtent`: an object not yet measured counts one line per item at
    /// this multiple of its size; the live measurement replaces it on the next pass.
    private static let lineHeightFactor: CGFloat = 1.25
}

// MARK: - §6 Background sheet (D4)

/// §6: page colour, image and — once an image is set — focal point and wash. No `motion` control.
/// Built from C-094 and C-105 on the modal surface. Controlled (R-01): every value leaves through
/// a closure.
private struct BackgroundSheet: View {
    let pageColor: Color
    let image: ActivityCanvas<AnyView>.Background.Image?
    let focal: CGPoint
    let washColor: Color
    let washOpacity: Double
    let swatches: [[TextColorPalette.NamedColor]]
    /// §2 item 4: the wash and page palettes draw no well unless the eyedropper is shown.
    let showsWell: Bool
    let onPageColor: (Color) -> Void
    let onPickImage: () -> Void
    let onFocal: (CGPoint) -> Void
    let onWashColor: (Color) -> Void
    let onWashOpacity: (Double) -> Void

    /// R-02: where a focal drag started, held only while the finger is down.
    @State private var dragBase: CGPoint?

    /// GAP — activities-editor §6: the crop preview's height; undrawn, no token.
    private let previewHeight: CGFloat = 140

    var body: some View {
        // §2 item 4: the body scrolls only when it does not fit the sheet's cap.
        ViewThatFits(in: .vertical) {
            controls
            ScrollView(.vertical) { controls }
                .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.modalBackground, in: UnevenRoundedRectangle(
            topLeadingRadius: Token.Radius.modal, topTrailingRadius: Token.Radius.modal
        ))
        .ui2Element("Background sheet")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            sectionLabel("Page colour")
            TextColorPalette(currentColor: pageColor, swatches: swatches, onSelect: onPageColor, showsWell: showsWell)
                .ui2Element("C-094 TextColorPalette")
            sectionLabel("Image")
            Button(label: image == nil ? "Choose image" : "Change image", leadingGlyph: .image, onTap: onPickImage)
                .ui2Element("C-105 Button")
                .padding(.horizontal, Token.Space.pageMargin)
            if let image {
                sectionLabel("Focal point")
                focalPreview(image)
                sectionLabel("Wash")
                TextColorPalette(currentColor: washColor, swatches: swatches, onSelect: onWashColor, showsWell: showsWell)
                    .ui2Element("C-094 TextColorPalette 2")
                // activities-editor §3 tool 2: undrawn default, the system slider (no registry row).
                SwiftUI.Slider(value: Binding(get: { washOpacity }, set: onWashOpacity), in: 0...1)
                    .tint(Token.white100)
                    .padding(.horizontal, Token.Space.pageMargin)
                    .accessibilityLabel("Wash opacity")
                    .ui2Element("Wash opacity")
            }
        }
        .padding(.top, Token.Space.pageMargin)
        .padding(.bottom, Token.Space.pageMargin * 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        SwiftUI.Text(verbatim: text)
            .designTextStyle(Token.TypeStyle.labelEmphasis)
            .foregroundStyle(Token.textPrimary)
            .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §6: "drag the image inside a crop preview; written as `focal` 0–1". R-04 / R-19: read
    /// cache-first, never fetched.
    @ViewBuilder
    private func focalPreview(_ image: ActivityCanvas<AnyView>.Background.Image) -> some View {
        if let picture = Ui2ImageCache.shared.image(for: image.imageURL) {
            GeometryReader { proxy in
                let scale = max(proxy.size.width / picture.size.width, proxy.size.height / picture.size.height)
                let drawn = CGSize(width: picture.size.width * scale, height: picture.size.height * scale)
                SwiftUI.Image(uiImage: picture)
                    .resizable()
                    .frame(width: drawn.width, height: drawn.height)
                    .offset(x: min(0, max(proxy.size.width - drawn.width, proxy.size.width / 2 - focal.x * drawn.width)),
                            y: min(0, max(proxy.size.height - drawn.height, proxy.size.height / 2 - focal.y * drawn.height)))
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        // pan-ok: moves the focal point on both axes inside its own crop box
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let base = dragBase ?? focal
                                dragBase = base
                                onFocal(CGPoint(
                                    x: min(max(base.x - drag.translation.width / drawn.width, 0), 1),
                                    y: min(max(base.y - drag.translation.height / drawn.height, 0), 1)
                                ))
                            }
                            .onEnded { _ in dragBase = nil }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Focal point")
            }
            .frame(height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.cardSm))
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("Focal crop preview")
        }
    }
}

// MARK: - §6 Actions sheet (D8)

/// §3 Actions: undrawn — a default the owner delegated, built from C-040, C-106 of C-035, C-045
/// fields and C-105. Holds an edit buffer until Done (R-31); Cancel discards it.
private struct ActionsSheet: View {
    typealias PageAction = ActivitiesEditorScreen.PageAction

    let actions: [PageAction]
    let onCancel: () -> Void
    let onDone: ([PageAction]) -> Void

    @State private var edited: [PageAction]
    @State private var selectedID: String
    @State private var isNew: Set<String> = []

    private static let addID = "add"

    init(actions: [PageAction], onCancel: @escaping () -> Void, onDone: @escaping ([PageAction]) -> Void) {
        self.actions = actions
        self.onCancel = onCancel
        self.onDone = onDone
        _edited = State(initialValue: actions)
        _selectedID = State(initialValue: actions.first?.id ?? Self.addID)
    }

    private var selectedIndex: Int? { edited.firstIndex { $0.id == selectedID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                style: .textButtons,
                title: "Action",
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onCancel: onCancel,
                onDone: { onDone(edited) }
            )
            .ui2Element("C-040 PageHeader")
            // §2 item 4: the header stays fixed; the body scrolls when it does not fit the cap.
            ViewThatFits(in: .vertical) {
                formBody
                ScrollView(.vertical) { formBody }
                    .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Token.modalBackground, in: UnevenRoundedRectangle(
            topLeadingRadius: Token.Radius.modal, topTrailingRadius: Token.Radius.modal
        ))
        .ui2Element("Actions sheet")
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChipStrip(items: listItems, selectedID: selectedID, onSelect: select)
                .ui2Element("C-106 ChipStrip")
            if let index = selectedIndex {
                form(index)
            }
        }
        .padding(.bottom, Token.Space.pageMargin * 2)
    }

    /// §3 Actions: the page's actions by label plus a trailing "+ Add" chip.
    private var listItems: [ChipStrip.Item] {
        edited.map { ChipStrip.Item(id: $0.id, label: $0.label.isEmpty ? "Action" : $0.label) }
            + [ChipStrip.Item(id: Self.addID, label: "+ Add")]
    }

    private func select(_ id: String) {
        guard id == Self.addID else {
            selectedID = id
            return
        }
        let action = PageAction(id: UUID().uuidString, kind: .addToPrayerList, label: "",
                                placement: .inline, value: "", body: "")
        edited.append(action)
        isNew.insert(action.id)
        selectedID = action.id
    }

    @ViewBuilder
    private func form(_ index: Int) -> some View {
        let action = edited[index]
        sectionLabel("Kind")
        ChipStrip(items: Self.kindItems, selectedID: action.kind.rawValue, onSelect: { id in
            edited[index].kind = PageAction.Kind(rawValue: id) ?? action.kind
        })
        .ui2Element("C-106 ChipStrip 2")
        sectionLabel("Label")
        field("Label", text: action.label, kind: .single) { edited[index].label = $0 }
        sectionLabel("Placement")
        ChipStrip(items: Self.placementItems, selectedID: action.placement.rawValue, onSelect: { id in
            setPlacement(PageAction.Placement(rawValue: id) ?? action.placement, at: index)
        })
        .ui2Element("C-106 ChipStrip 3")
        if action.kind != .nextLesson {
            sectionLabel("Prefill")
            prefill(action, index: index)
        }
        if !isNew.contains(action.id) {
            Button(label: "Remove action", onTap: { remove(action.id) })
                .ui2Element("C-105 Button")
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.top, Token.Space.pageMargin)
        }
    }

    /// §3 Actions: the fields depend on the kind.
    @ViewBuilder
    private func prefill(_ action: PageAction, index: Int) -> some View {
        switch action.kind {
        case .addToPrayerList:
            VStack(spacing: Token.Space.elementGap) {
                field("Title", text: action.value, kind: .single) { edited[index].value = $0 }
                field("Body", text: action.body, kind: .multi) { edited[index].body = $0 }
            }
        case .write:
            field("Write your thoughts", text: action.value, kind: .multi) { edited[index].value = $0 }
        case .openUrl:
            field("https://…", text: action.value, kind: .single) { edited[index].value = $0 }
        case .nextLesson:
            EmptyView()
        }
    }

    /// §3 Actions: at most one pinned per page; choosing Pinned moves the other to Inline.
    private func setPlacement(_ placement: PageAction.Placement, at index: Int) {
        if placement == .pinned {
            for other in edited.indices where other != index && edited[other].placement == .pinned {
                edited[other].placement = .inline
            }
        }
        edited[index].placement = placement
    }

    private func remove(_ id: String) {
        edited.removeAll { $0.id == id }
        selectedID = edited.first?.id ?? Self.addID
    }

    private func sectionLabel(_ text: String) -> some View {
        SwiftUI.Text(verbatim: text)
            .designTextStyle(Token.TypeStyle.labelEmphasis)
            .foregroundStyle(Token.textPrimary)
            .padding(.horizontal, Token.Space.pageMargin)
            .padding(.top, Token.Space.elementGap)
    }

    private func field(_ placeholder: String, text: String, kind: TextInput.Kind,
                       onChange: @escaping (String) -> Void) -> some View {
        TextInput(text: text, placeholder: placeholder, kind: kind, focused: false,
                  onChange: onChange, editing: .init())
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-045 TextInput \(placeholder)")
    }

    private static let kindItems: [ChipStrip.Item] = [
        .init(id: PageAction.Kind.addToPrayerList.rawValue, label: "Add to Prayer List"),
        .init(id: PageAction.Kind.write.rawValue, label: "Write"),
        .init(id: PageAction.Kind.openUrl.rawValue, label: "Open link"),
        .init(id: PageAction.Kind.nextLesson.rawValue, label: "Next lesson")
    ]

    private static let placementItems: [ChipStrip.Item] = [
        .init(id: PageAction.Placement.inline.rawValue, label: "Inline"),
        .init(id: PageAction.Placement.pinned.rawValue, label: "Pinned")
    ]
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
    /// §9.2: colours are hex — the White and Blue presets.
    private static let white = "#FFFFFF"
    private static let blue = "#509CEF"
    /// §1 deviation 10: the frame's Genesis 1 sample text.
    private static let genesisVerses = [
        "In the beginning God created the heavens and the earth.",
        "Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters.",
        "And God said, “Let there be light,” and there was light. 4 God saw that the light was good, and he separated the light from the darkness. 5 God called the light “day,” and the darkness he called “night.” And there was evening, and there was morning—the first day.",
        "And God said, “Let there be a vault between the waters to separate water from water.”",
        "God called the light “day,” and the darkness he called “night.” And there was evening, and there was morning—the first day.",
        "And God said, “Let there be a vault between the waters to separate water from water.”",
        "So God made the vault and separated the water under the vault from the water above it. And it was so.",
        "God called the vault “sky.” And there was evening, and there was morning—the second day."
    ]

    /// The Idle base every other sample varies from.
    private static let base = Self(
        editorMode: "idle", openTool: "",
        showsHighlightTool: false, showsEffectsTool: false, showsEyedropper: false,
        slideIDs: frameSlideIDs, slideLabels: frameSlideLabels, activeID: "activity-2",
        objectTexts: [], objectFonts: [], objectColors: [], objectWeights: [], objectSizes: [],
        objectAlignments: [], objectListStyles: [], objectStartNumbers: [],
        objectXs: [], objectYs: [], objectScales: [], objectRotations: [], objectWidths: [], objectHeights: [],
        editingIndex: -1,
        pageColorHex: "", pageImageURL: "", pageImageFocalX: 0.5, pageImageFocalY: 0.5,
        pageWashHex: "", pageWashOpacity: 0,
        verseTexts: [], firstVerse: 1,
        highlightIDs: [], highlightObjects: [], highlightStarts: [], highlightEnds: [],
        selectedHighlightID: "",
        actionIDs: [], actionKinds: [], actionLabels: [], actionPlacements: [], actionValues: [], actionBodies: [],
        centerGuide: false, deleteTargetShown: false, saving: false, saveFailed: false,
        loadFailed: false
    )

    /// One committed object centred on the edit slot's 478 wu, scale 1 (§2 item 3).
    private static func committed(scale: Double = 1, x: Double = 220, y: Double = 478,
                                  rotation: Double = 0) -> Self {
        var s = base
        s.objectTexts = [sampleText]
        s.objectFonts = ["sans"]
        s.objectColors = [white]
        s.objectWeights = ["bold"]
        s.objectSizes = [38]
        s.objectXs = [x]
        s.objectYs = [y]
        s.objectScales = [scale]
        s.objectRotations = [rotation]
        return s
    }

    /// §3 Idle-empty — the frozen frame `blank-canvas`.
    static let idleEmpty = base
    /// §3 Idle-populated — one committed object; Done enabled (§9.3, `canSave` true).
    static let idlePopulated: Self = {
        var s = committed()
        s.canSave = true
        return s
    }()
    /// §3 Idle-long — content taller than the viewport: the page grows and the canvas scrolls.
    static let idleLong: Self = {
        var s = committed()
        s.canSave = true
        s.objectTexts = [genesisVerses.joined(separator: "\n")]
        s.objectHeights = [1600]
        return s
    }()
    /// The object the edit slot shows (§9.1: one of `objects`, at `editingIndex`).
    private static func editing(_ text: String, color: String = white, tool: String) -> Self {
        var s = committed()
        s.objectTexts = [text]
        s.objectColors = [color]
        s.editorMode = "editing"
        s.openTool = tool
        s.editingIndex = 0
        return s
    }

    /// §3 Editing-new — a canvas tap: placeholder, the font panel on Inter (OQ-014).
    static let editingNew = editing("", tool: "font")
    /// §3 Editing-existing — the frozen frame `edit-text`: the object re-opened, the colour
    /// panel open with blue picked (the well and the outlined swatch, OQ-011).
    static let editingExisting = editing(sampleText, color: blue, tool: "color")
    /// §3 Highlighting — the frozen frame `edit-highlights`: a passage C-092 over an image with a
    /// #141F6B wash at 0.80 (§4 C-091), a highlight selected so the actions show (OQ-012).
    static let highlighting: Self = {
        var s = base
        s.editorMode = "highlighting"
        s.openTool = "highlight"
        s.showsHighlightTool = true
        s.pageImageURL = "http://localhost:5961/api/projects/makeready/images/genesis-creation-animals"
        s.pageWashHex = "#141F6B"
        s.pageWashOpacity = 0.8
        s.objectTexts = [genesisVerses.joined(separator: "\n")]
        s.objectFonts = ["sans"]
        s.objectColors = [white]
        s.objectWeights = ["regular"]
        s.objectSizes = [17]
        s.objectAlignments = ["left"]
        s.objectListStyles = ["bibleVerse"]
        s.objectStartNumbers = [1]
        s.objectHeights = [516]
        s.highlightIDs = ["h1", "h2"]
        s.highlightObjects = [0, 0]
        s.highlightStarts = [229, 317]
        s.highlightEnds = [264, 376]
        s.selectedHighlightID = "h1"
        return s
    }()
    /// §3 Manipulating — a one-finger drag: chrome hidden, centre guide, delete target and the
    /// reserved-zone guides shown (C-091's own Manipulating sample: 1.2×, −8°).
    static let manipulating: Self = {
        var s = committed(scale: 1.2, x: 220, y: 390, rotation: -8)
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
    /// §3 Bible verse — the passage as one C-092 (the owner's preview).
    static let bibleVerse: Self = {
        var s = base
        s.verseTexts = [
            "Now if we have died with Christ, we believe that we shall also live with Him,",
            "knowing that Christ, having been raised from the dead, is never to die again; death no longer is master over Him.",
            "For the death that He died, He died to sin once for all time; but the life that He lives, He lives to God.",
            "So you too, consider yourselves to be dead to sin, but alive to God in Christ Jesus."
        ]
        s.firstVerse = 8
        return s
    }()
    /// §6 Background sheet (D4) over an image, its focal point and wash set.
    static let backgroundSheet: Self = {
        var s = editing(sampleText, tool: "background")
        s.pageColorHex = "#141F6B"
        s.pageImageURL = "http://localhost:5961/api/projects/makeready/images/genesis-abram-stars"
        s.pageImageFocalX = 0.7
        s.pageImageFocalY = 0.3
        s.pageWashHex = "#141F6B"
        s.pageWashOpacity = 0.5
        return s
    }()
    /// §3 Actions / §6 Actions sheet (D8): one inline and one pinned action.
    static let actionsSheet: Self = {
        var s = editing(sampleText, tool: "actions")
        s.actionIDs = ["action-1", "action-2"]
        s.actionKinds = ["addToPrayerList", "nextLesson"]
        s.actionLabels = ["Add to Prayer List", "Next lesson"]
        s.actionPlacements = ["inline", "pinned"]
        s.actionValues = ["", ""]
        s.actionBodies = ["", ""]
        return s
    }()
    /// §2 item 3 (D8): the page's action previews, an inline C-105 and the pinned pill.
    static let actionsOnPage: Self = {
        var s = committed()
        s.canSave = true
        s.actionIDs = ["action-1", "action-2"]
        s.actionKinds = ["addToPrayerList", "nextLesson"]
        s.actionLabels = ["Add to Prayer List", "Next lesson"]
        s.actionPlacements = ["inline", "pinned"]
        s.actionValues = ["", ""]
        s.actionBodies = ["", ""]
        return s
    }()
    /// §3 tool 6 — the effects strip, shown by `showsEffectsTool` (§2 item 5).
    static let effectsStrip: Self = {
        var s = editing(sampleText, tool: "animation")
        s.showsEffectsTool = true
        return s
    }()
    /// §9.4 Load-failed — the container could not load the activity.
    static let loadFailed: Self = {
        var s = base
        s.loadFailed = true
        return s
    }()
}

#Preview("Idle-empty") {
    ActivitiesEditorScreen(state: .idleEmpty)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Idle-populated") {
    ActivitiesEditorScreen(state: .idlePopulated)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Editing-new") {
    ActivitiesEditorScreen(state: .editingNew)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Editing-existing") {
    ActivitiesEditorScreen(state: .editingExisting)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Highlighting") {
    ActivitiesEditorScreen(state: .highlighting)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Manipulating") {
    ActivitiesEditorScreen(state: .manipulating)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Saving") {
    ActivitiesEditorScreen(state: .saving)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Error") {
    ActivitiesEditorScreen(state: .error)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible verse") {
    ActivitiesEditorScreen(state: .bibleVerse)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Idle-long") {
    ActivitiesEditorScreen(state: .idleLong)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Background sheet") {
    ActivitiesEditorScreen(state: .backgroundSheet)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Actions sheet") {
    ActivitiesEditorScreen(state: .actionsSheet)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Effects strip") {
    ActivitiesEditorScreen(state: .effectsStrip)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Actions on page") {
    ActivitiesEditorScreen(state: .actionsOnPage)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Load-failed") {
    ActivitiesEditorScreen(state: .loadFailed)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}
