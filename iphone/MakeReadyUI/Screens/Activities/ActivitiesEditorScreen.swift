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
import UIKit
import UIKit.UIGestureRecognizerSubclass

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
/// Selection row's C-102 IconButton + C-105 Button), C-093 TextSizeSlider, and §10's rail stack:
/// C-081 ActivityNavBar (→ C-061, C-021) as the chips rail, the tool row of C-102 IconButtons, and
/// the middle and top rails of C-106 ChipStrip (→ C-035), C-094 TextColorPalette (→ C-095, C-096,
/// C-097), C-102, C-105 and C-045 TextInput. No tool presents a sheet (§10.1). Standalone:
/// `identifiedFrom` is null, so no D7 template applies.
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
        /// C-081 `slides` screenshots, parallel to `slideIDs`: each chip's image URL, resolved from
        /// `Ui2ImageCache` like `lessonSlideImages` ("" or not yet cached = none → the empty C-061
        /// chip; OQ-C-081-6). A short array leaves the rest empty.
        var slideImages: [String] = []
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
        /// §10.3 / §10.8: the Background rail's selected option, derived by the container —
        /// `gradient` · `colour` · `image`.
        var backgroundOption: String = "colour"
        /// §10.8 `gradient` (`02` §5, D1/D17): drawn through C-091 in every mode; nil = none.
        var gradient: Gradient?
        /// §10.3 / D13: the 12 palettes, each a list of `#RRGGBB` (base first, then blob colours).
        var palettes: [[String]] = []
        /// §10.3 / D22: the library's images, newest first.
        var libraryImages: [LibraryImage] = []
        /// §10.3: more library images can load as the Image rail scrolls.
        var hasMoreImages: Bool = false
        /// §10.9 (OQ-activities-editor-43): the Actions top rail's field drawn focused —
        /// `label` · `value` · `body` · "" (none). A preview seed; live, focus is the field's own.
        var focusedActionField: String = ""
        /// §14.1 (owner ruling 2026-11-09, D26–D28): what the area between the header and the
        /// chips rail shows — `activity` (the editable canvas) · `typeGrid` (C-086 in place of the
        /// canvas) · `readOnly` (a kind the editor can't edit, drawn as a member sees it).
        var canvasContent: String = "activity"
        /// §14.3 `typeGrid`: C-086 `unavailableTypes` as raw case names — the dimmed, inert tiles.
        var unavailableTypes: [String] = []
        /// §14.3 `typeGrid`: C-086 `pendingType` as its raw case name — the create in flight;
        /// "" = nil (interactive).
        var pendingType: String = ""
        /// §14.3 `readOnly`: the activity's kind — `video` · `youtube` · `write` · `poll`.
        var readOnlyKind: String = "video"
        /// §14.3 `readOnly`: the activity's title; "" = the kind's C-086 title.
        var readOnlyTitle: String = ""
        /// §14.3 `readOnly`: the poster drawn as the page's image; "" = none.
        var readOnlyPosterURL: String = ""

        /// §10.8 `gradient`: `base` `#RRGGBB`, `blobs`, `hidden`.
        struct Gradient: Equatable {
            /// One radial blob — `x`, `y`, `r` fractions of the page width, `color` `#RRGGBB`.
            struct Blob: Equatable {
                var x: Double
                var y: Double
                var r: Double
                var color: String
            }

            var base: String
            var hidden: Bool
            var blobs: [Blob]
        }

        /// §10.8 `libraryImages` element: the media id and its thumbnail URL.
        struct LibraryImage: Equatable {
            var id: String
            var thumbnailURL: String
        }
    }

    /// §10.8 `BackgroundCommand` — every choice the Background rail reports; the container owns
    /// what each does to the document (D14, D17, D18).
    enum BackgroundCommand: Equatable {
        /// The Gradient option.
        case gradient
        /// The Colour option (nil) or a swatch (`#RRGGBB`).
        case colour(String?)
        /// ↻ Shuffle — a new blob layout from the current palette (D13).
        case shuffle
        /// A palette chip, by its index in `State.palettes` (D13).
        case palette(Int)
        /// A library thumbnail, by media id.
        case image(String)
        /// "More…" — the container pushes the existing media-pick page (D22).
        case moreImages
        /// The Image rail scrolled to its end while `hasMoreImages`.
        case loadMoreImages
        /// A canvas drag while Image is open — the focal point, 0–1 (proposed payload).
        case focal(x: Double, y: Double)
        /// The wash colour `#RRGGBB` and opacity 0–1 (proposed payload).
        case wash(color: String, opacity: Double)
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
    /// §14.1 `typeGrid`: a C-086 tile was tapped — its raw case name. The container creates the
    /// activity and swaps the canvas to it; the screen only reports.
    var onPickType: (String) -> Void = { _ in }
    var onTapEmpty: (CGPoint) -> Void = { _ in }
    var onTapObject: (Int) -> Void = { _ in }
    /// §9.1: one callback per user action that edits an object.
    var onEditObject: (ObjectEdit) -> Void = { _ in }
    /// §9.4: Load-failed raises the top error banner with this message; the error channel is the
    /// app's, so the container routes it there.
    var onLoadFailed: (String) -> Void = { _ in }
    /// §10.5: a tap on the empty canvas while Editing — the container commits the edit (D10).
    var onTapOff: () -> Void = {}
    /// §10.3: every Background rail choice.
    var onBackground: (BackgroundCommand) -> Void = { _ in }
    /// §10.4: the page's whole action list, on every live edit.
    var onActionsChange: ([PageAction]) -> Void = { _ in }
    /// §10.6: a Background or Actions rail closed — the container's save moment in Idle (D19).
    var onPageRailsClosed: () -> Void = {}
    /// Superseded by §10 (no sheet, no pick push): kept so the app container compiles until
    /// text-activity-v2 rewires it. `onPickImage` still fires on "More…" and `onChangeActions`
    /// when the Actions rail closes, as the sheet's Done did; `onChangeBackground` is not called.
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
    // §10.4: the page's actions, edited live and reported through `onActionsChange` (R-31).
    @SwiftUI.State private var actions: [PageAction]
    // §10.4: the action the top rail shows, and the ones added in this rail (no Remove).
    @SwiftUI.State private var selectedActionID: String?
    @SwiftUI.State private var newActionIDs: Set<String> = []
    // §10.1: the open tool — its rails show; ephemeral UI (R-31).
    @SwiftUI.State private var openTool: Tool?
    // §10.3: the Background option chosen in the rail before the document follows (Image with no
    // image yet shows the Image rail); nil = `State.backgroundOption`.
    @SwiftUI.State private var pickedBackgroundOption: String?
    // §10.4 / D8: the rail field that has focus — `label` · `value` · `body`.
    @SwiftUI.State private var focusedField: String?
    // §10.3: where a focal drag on the canvas started, held only while the finger is down (R-02).
    @SwiftUI.State private var focalDragBase: CGPoint?
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
    // §2: the bottom container's height, held while Manipulating hides it so the slider's clamp
    // does not change when the bars hide.
    @SwiftUI.State private var containerHeight: CGFloat = 0
    // §11 Fixed canvas (D24, held only while the finger is down): the content extent fixed at drag
    // start so placement never re-runs under the finger, and the object's last transform.
    @SwiftUI.State private var dragExtent: ClosedRange<CGFloat>??
    @SwiftUI.State private var dragged: (index: Int, transform: CanvasTextObject.Transform)?
    // §9.1a: the object's transform when the in-flight gesture began — a gesture that ends where
    // it started reports nothing.
    @SwiftUI.State private var gestureStart: ObjectEdit.Transform?
    // §10.10 (R-02, held only while fingers are down): the object the first touch grabbed (D25 —
    // picked by the bridge by geometry, never by C-092 `onTouchDown`), the recognizers in flight,
    // and each one's starting value.
    @SwiftUI.State private var touchedIndex: Int?
    // D25: the object the last finger-down grabbed, kept past the lift so the tap that follows uses
    // it; replaced at the next finger-down.
    @SwiftUI.State private var tapTarget: Int?
    // §13.1: the bridge marked the current (or last) touch sequence a manipulation — a move, pinch
    // or rotate began, or the first finger travelled 10pt. Kept past the lift so the SwiftUI tap
    // that fires on lift-off is ignored; cleared at the next finger-down.
    @SwiftUI.State private var touchWasManipulation = false
    @SwiftUI.State private var activeManipulations: Set<CanvasManipulation.Kind> = []
    @SwiftUI.State private var moveBase: CGPoint = .zero
    @SwiftUI.State private var scaleBase: CGFloat = 1
    @SwiftUI.State private var rotationBase: Double = 0

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {},
        onSelectSlide: @escaping (String) -> Void = { _ in },
        onAdd: @escaping () -> Void = {},
        onPickType: @escaping (String) -> Void = { _ in },
        onTapEmpty: @escaping (CGPoint) -> Void = { _ in },
        onTapObject: @escaping (Int) -> Void = { _ in },
        onEditObject: @escaping (ObjectEdit) -> Void = { _ in },
        onLoadFailed: @escaping (String) -> Void = { _ in },
        onTapOff: @escaping () -> Void = {},
        onBackground: @escaping (BackgroundCommand) -> Void = { _ in },
        onActionsChange: @escaping ([PageAction]) -> Void = { _ in },
        onPageRailsClosed: @escaping () -> Void = {},
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
        self.onPickType = onPickType
        self.onTapEmpty = onTapEmpty
        self.onTapObject = onTapObject
        self.onEditObject = onEditObject
        self.onLoadFailed = onLoadFailed
        self.onTapOff = onTapOff
        self.onBackground = onBackground
        self.onActionsChange = onActionsChange
        self.onPageRailsClosed = onPageRailsClosed
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
        let actions = Self.pageActions(state)
        _actions = SwiftUI.State(initialValue: actions)
        _selectedActionID = SwiftUI.State(initialValue: actions.first?.id)
        _openTool = SwiftUI.State(initialValue: Tool(rawValue: state.openTool))
        _focusedField = SwiftUI.State(initialValue: state.focusedActionField.isEmpty ? nil : state.focusedActionField)
        _alertPresented = SwiftUI.State(initialValue: state.saveFailed)
    }

    /// §14.1: the editable canvas shows — `typeGrid` and `readOnly` have no edit mode and no
    /// tool stack.
    private var showsActivity: Bool { state.canvasContent != "typeGrid" && state.canvasContent != "readOnly" }

    private var mode: ActivityCanvas<AnyView>.Mode {
        // §14.1: no edit mode outside the editable canvas — the Idle header and the chips rail.
        guard showsActivity else { return .idle }
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
                if showsActivity {
                    GeometryReader { proxy in
                        canvas(unit: proxy.size.width / Self.referenceWidth,
                               viewport: proxy.size.height * Self.referenceWidth / proxy.size.width,
                               safeTop: screen.safeAreaInsets.top)
                            .background(manipulationBridge(size: proxy.size, safeTop: screen.safeAreaInsets.top))
                    }
                    .ignoresSafeArea(.container)
                } else if state.canvasContent == "readOnly" {
                    readOnlyPage
                        .ignoresSafeArea(.container)
                }
                if showsActivity && isImageRailOpen {
                    focalDragLayer
                        .ignoresSafeArea(.container)
                }
                chrome(unit: screen.size.width / Self.referenceWidth)
            }
        }
        .background(Token.layoutBackground)                 // §2: page ground
        // §2 item 6: the keyboard never resizes the page; the stack follows it by offset (§10.1).
        .ignoresSafeArea(.keyboard)
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
        // §10.6 (round 2): a text edit opens with no rail open, and ending it closes every rail —
        // a page rail closing through `setOpenTool`, so `onPageRailsClosed` fires (D19).
        .onChange(of: mode) { previous, next in
            let wasEditing = previous == .editing || previous == .highlighting
            let isEditing = next == .editing || next == .highlighting
            guard wasEditing != isEditing, openTool != nil else { return }
            endField()
            closeRails()
        }
        // §10.3: once the document follows the rail's pick, the derived option rules again.
        .onChange(of: state.backgroundOption) { _, _ in pickedBackgroundOption = nil }
    }

    /// §10.3: while Image is open, a drag on the canvas moves the focal point and the canvas does
    /// not scroll; a tap still only closes the rails (§10.5).
    private var focalDragLayer: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    // pan-ok: moves the focal point on both axes, so a vertical drag must not scroll
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let base = focalDragBase ?? CGPoint(x: state.pageImageFocalX, y: state.pageImageFocalY)
                            focalDragBase = base
                            guard abs(drag.translation.width) + abs(drag.translation.height) > 0 else { return }
                            onBackground(.focal(
                                x: min(max(base.x - drag.translation.width / max(proxy.size.width, 1), 0), 1),
                                y: min(max(base.y - drag.translation.height / max(proxy.size.height, 1), 0), 1)
                            ))
                        }
                        .onEnded { drag in
                            focalDragBase = nil
                            if abs(drag.translation.width) + abs(drag.translation.height) < Self.tapSlop {
                                tapCanvas()
                            }
                        }
                )
                .accessibilityHidden(true)
        }
    }

    // MARK: - §2 z-order: fixed furniture and the bars

    /// The header at the top and, at the bottom, the fixed furniture standing on the container.
    /// In Manipulating the container leaves the layout, so a pinned pill falls to the screen's foot.
    private func chrome(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            if state.canvasContent == "typeGrid" {
                typeGrid
            } else {
                Spacer(minLength: 0)
            }
            if showsActivity {
                furniture(unit: unit)
                    .offset(y: -keyboardOverlap)
            }
            if mode != .manipulating {
                railStack
                    .transition(.opacity)
            }
        }
        // §2 item 5: the stack runs to the bottom; C-081's 16pt inset clears the corners (§10.1).
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

    // MARK: - §14: the type grid and the read-only page

    /// §14.1 `typeGrid`: C-086 in place of the canvas, between the header and the chips rail —
    /// laid out as ActivityNewScreen lays it (page-margin inset, scrolls when it overflows).
    private var typeGrid: some View {
        ScrollView(.vertical) {
            ActivityTypeGrid(
                pendingType: ActivityTypeGrid.ActivityType(rawValue: state.pendingType),
                unavailableTypes: Set(state.unavailableTypes.compactMap(ActivityTypeGrid.ActivityType.init(rawValue:))),
                onSelect: { onPickType($0.rawValue) }
            )
            .ui2Element("C-086 ActivityTypeGrid")
            .padding(Token.Space.pageMargin)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(maxHeight: .infinity)
    }

    /// §14.1 `readOnly`: the activity drawn as a member sees a page the player can't play here —
    /// C-091 in viewer mode with the poster as the page image, the title and the note as C-092,
    /// centred (the player's fallback page). Not interactive; no edit mode, no tool stack.
    private var readOnlyPage: some View {
        var page = ActivityCanvas<AnyView>.Background(color: pageColor)
        if let url = URL(string: state.readOnlyPosterURL), !state.readOnlyPosterURL.isEmpty {
            page.image = .init(imageURL: url, focal: CGPoint(x: 0.5, y: 0.5))
        }
        let title = state.readOnlyTitle.isEmpty
            ? (ActivityTypeGrid.ActivityType(rawValue: state.readOnlyKind)?.title ?? "")
            : state.readOnlyTitle
        return ActivityCanvas<AnyView>(
            background: page,
            mode: .viewer,
            content: {
                AnyView(
                    VStack(spacing: Self.readOnlyGap) {
                        // FLAGGED LITERAL — activities-player §2 fallback page: title 700, 24.
                        CanvasTextObject(text: title, mode: .viewer, font: .sans, weight: .bold,
                                         size: Self.readOnlyTitleSize, alignment: .center, editing: false)
                            .ui2Element("C-092 CanvasTextObject")
                        // FLAGGED LITERAL — activities-player §2 fallback page: body 400, 16.
                        CanvasTextObject(text: Self.readOnlyNote, mode: .viewer, font: .sans, weight: .regular,
                                         size: Self.readOnlyNoteSize, alignment: .center, editing: false)
                            .ui2Element("C-092 CanvasTextObject 2")
                    }
                    .frame(width: Self.editSlotWidth)
                    .position(x: Self.referenceWidth / 2, y: Self.referenceHeight / 2)
                )
            },
            verticalAnchor: .center
        )
        .ui2Element("C-091 ActivityCanvas")
        .allowsHitTesting(false)
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
        let offset = pageOffset(viewport: viewport)
        return ActivityCanvas<AnyView>(
            background: background,
            mode: mode,
            content: { AnyView(canvasContent(objects, unit: unit)) },
            onTapEmpty: { point in tapCanvas(at: point) },
            centerGuide: state.centerGuide,
            deleteTarget: state.deleteTargetShown ? .visible : nil,
            verticalAnchor: .center,
            contentExtent: extent,
            // §2 (D3): the screen only turns the guides on.
            reservedZones: mode == .manipulating,
            pinnedAction: pinned,
            widthHandles: mode == .editing ? widthHandles(pageOffset: offset) : nil,
            onResizeWidth: resizeDraft,
            // §11 (D24): the canvas is fixed to the screen in every mode — no scroll range, no
            // scroll insets, no autoscroll. The header and bottom area stay opaque over it.
            scrolls: false
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
                canvasObject(objects[index], index: index)
            }
            actionPreviews(objects)
                // The edited object renders above the others (OQ-010), still under the previews.
                .zIndex(2)
        }
    }

    /// One C-092 per object, the same view whether committed or edited (§13.2): entering or
    /// leaving Editing changes its placement, so the object animates between its committed
    /// transform and the edit slot — position, scale and rotation in one curve — and never jumps.
    private func canvasObject(_ object: CommittedObject, index: Int) -> some View {
        let isEdited = index == editedIndex
        return CanvasTextObject(
            text: object.text,
            onChange: { if isEdited { apply(.init(index: index, text: $0)) } },
            font: object.font,
            weight: object.weight,
            size: object.size,
            color: object.color,
            alignment: object.alignment,
            listStyle: isEdited ? .none : object.listStyle,
            startNumber: isEdited ? 1 : object.startNumber,
            animation: isEdited ? draftAnimation : .none,
            animationStart: isEdited ? draftAnimationStart : nil,
            effect: isEdited ? draftEffect : .none,
            // C-092 draws scale 1 and rotation 0 while editing (§3: re-opening shows the object at
            // `size`, unscaled); its committed transform returns on Done.
            transform: isEdited ? .identity : object.transform,
            // §10.10: drag, pinch and rotate are the canvas-wide recognizers' (`CanvasManipulation`);
            // the object only says it is under the first touch.
            manipulation: .host,
            editing: isEdited,
            highlights: isEdited ? [] : object.highlights,
            // D25: the object the finger-down grabbed — the topmost grab area may not be this box.
            onTap: {
                let target = tapTarget ?? index
                if target != editedIndex { tapObject(target) }
            }
        )
        // §2 item 3 + §3 Editing: the edited object alone at the edit slot, centred on 478 wu
        // before C-091's offset; alignment anchors a narrower block 24 wu from the canvas edge
        // (tool 3). C-092 never offsets itself (its §2): the screen places a committed object at
        // `transform.position`.
        .frame(width: isEdited ? draftLayoutWidth : object.transform.width ?? Self.editSlotWidth)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if index == editedIndex { measuredDraftHeight = height } else { measuredHeights[index] = height }
        }
        .ui2Element(index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)")
        .position(isEdited ? CGPoint(x: draftCentreX, y: Self.editSlotY) : object.transform.position)
        .zIndex(isEdited ? 1 : 0)
        // §13.2: Idle ↔ Editing is one animation — one ease-out for position, scale and rotation,
        // no delayed dispatch. A gesture frame never changes `editedIndex`, so it stays 1:1.
        .animation(Self.editTransition, value: editedIndex)
    }

    // MARK: - §10.10: pinch and rotate anywhere on the canvas

    /// §10.10: the canvas-wide drag / pinch / rotate recognizers. They take touches only between
    /// the header and the stack (the canvas a leader sees), in points from the screen's top.
    private func manipulationBridge(size: CGSize, safeTop: CGFloat) -> some View {
        let unit = size.width / Self.referenceWidth
        let top = safeTop + Self.headerHeight
        let bottom = size.height - containerHeight - keyboardOverlap
        return CanvasManipulation(
            accepts: { point in point.y > top && point.y < bottom },
            canBegin: { kind in
                guard manipulationTarget != nil, !isImageRailOpen else { return false }
                // §10.10: while editing, two fingers pinch and rotate the edited object; it never moves.
                return kind != .move || editedIndex == nil
            },
            onUpdate: { manipulate($0, unit: unit) },
            onTouchDown: { point in
                // D25: the canvas picks the object at the first finger-down, by geometry.
                let target = point.flatMap {
                    Self.grabTarget(at: $0, objects: grabAreas(unit: unit, viewport: size.height / unit),
                                    editedIndex: editedIndex)
                }
                touchedIndex = target
                tapTarget = target
                touchWasManipulation = false
            },
            onManipulation: { touchWasManipulation = true },
            onAllUp: { touchedIndex = nil }
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// §10.10: the object two fingers act on — while editing the edited object, otherwise the
    /// committed object under the first touch; none when that touch landed on no object.
    private var manipulationTarget: Int? {
        if let editedIndex { return editedIndex }
        guard mode == .idle || mode == .manipulating, let touchedIndex,
              shownObjects.indices.contains(touchedIndex) else { return nil }
        return touchedIndex
    }

    /// D25: one object's rendered box in the bridge's points — centre, layout width × measured
    /// height, scale and rotation as drawn.
    struct GrabArea: Equatable {
        var center: CGPoint
        var size: CGSize
        var scale: CGFloat = 1
        var rotation: Angle = .zero
    }

    /// D25: every shown object's box, by index, in points from the screen's top (the canvas is the
    /// whole screen; content y is page y less C-091's fixed offset, §11). The edited object sits
    /// at the edit slot, unscaled and unrotated, as `editedObject` draws it.
    private func grabAreas(unit: CGFloat, viewport: CGFloat) -> [GrabArea] {
        let offset = pageOffset(viewport: viewport)
        return shownObjects.indices.map { index in
            if index == editedIndex {
                return GrabArea(center: CGPoint(x: draftCentreX * unit, y: (Self.editSlotY + offset) * unit),
                                size: CGSize(width: draftLayoutWidth * unit, height: draftHeight * unit))
            }
            let object = shownObjects[index]
            return GrabArea(
                center: CGPoint(x: object.transform.position.x * unit,
                                y: (object.transform.position.y + offset) * unit),
                size: CGSize(width: (object.transform.width ?? Self.editSlotWidth) * unit,
                             height: objectHeight(object, index: index) * unit),
                scale: object.transform.scale,
                rotation: object.transform.rotation
            )
        }
    }

    /// D25: the object a touch at `point` grabs. Each grab area is the box scaled, padded by
    /// `grabPadding` on every side and at least `grabMinimum` square, tested in the object's
    /// rotated frame. The edited object wins while editing; otherwise the topmost (last drawn)
    /// object whose grab area holds the touch; nil when none does.
    static func grabTarget(at point: CGPoint, objects: [GrabArea], editedIndex: Int?) -> Int? {
        func holds(_ area: GrabArea) -> Bool {
            let dx = point.x - area.center.x
            let dy = point.y - area.center.y
            let radians = -area.rotation.radians
            let x = dx * cos(radians) - dy * sin(radians)
            let y = dx * sin(radians) + dy * cos(radians)
            let width = max(area.size.width * area.scale + 2 * grabPadding, grabMinimum)
            let height = max(area.size.height * area.scale + 2 * grabPadding, grabMinimum)
            return abs(x) <= width / 2 && abs(y) <= height / 2
        }
        if let editedIndex, objects.indices.contains(editedIndex), holds(objects[editedIndex]) {
            return editedIndex
        }
        return objects.indices.reversed().first { $0 != editedIndex && holds(objects[$0]) }
    }

    /// §10.10: the move follows the touches' centroid (1:1 in wu), pinch writes `scale` and rotate
    /// `rotation`, simultaneously, about the object's centre. §9.1a: each frame goes to the display
    /// only; when the last recognizer ends, `endGesture` reports the final transform once.
    private func manipulate(_ update: CanvasManipulation.Update, unit: CGFloat) {
        if update.phase == .ended {
            activeManipulations.remove(update.kind)
            guard activeManipulations.isEmpty else { return }
            dragExtent = nil
            endGesture()
            return
        }
        guard let index = dragged?.index ?? manipulationTarget, shownObjects.indices.contains(index) else { return }
        let shown = shownObjects[index].transform
        switch update.phase {
        case .began:
            if activeManipulations.isEmpty, dragExtent == nil { dragExtent = .some(measuredExtent(shownObjects)) }
            activeManipulations.insert(update.kind)
            // Each recognizer starts from the object as it is now, so one restarting mid-gesture
            // (a finger lifted and put back) never snaps the object back.
            switch update.kind {
            case .move: moveBase = shown.position
            case .pinch: scaleBase = shown.scale
            case .rotate: rotationBase = shown.rotation.degrees
            }
        case .changed:
            guard activeManipulations.contains(update.kind) else { return }
            var next = shown
            switch update.kind {
            case .move:
                next.position = CGPoint(x: moveBase.x + update.translation.width / unit,
                                        y: moveBase.y + update.translation.height / unit)
            case .pinch:
                next.scale = scaleBase * update.scale
            case .rotate:
                next.rotation = .degrees(rotationBase + update.rotation * 180 / .pi)
            }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { emit(next, index: index) }
        case .ended:
            break
        }
    }

    /// §9.1a: each frame goes to the display only; `endGesture` reports the final transform once.
    private func emit(_ transform: CanvasTextObject.Transform, index: Int) {
        if dragged == nil, shownObjects.indices.contains(index) {
            let start = shownObjects[index].transform
            gestureStart = .init(x: start.position.x, y: start.position.y,
                                 scale: start.scale, rotation: start.rotation.degrees)
        }
        dragged = (index, transform)
        apply(.init(index: index, transform: .init(x: transform.position.x, y: transform.position.y,
                                                   scale: transform.scale, rotation: transform.rotation.degrees)),
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

    /// §2 item 3 (D8): an inline action previews as C-105, 24 wu below the last object.
    @ViewBuilder
    private func actionPreviews(_ objects: [CommittedObject]) -> some View {
        let inline = actions.filter { $0.placement == .inline }
        ForEach(Array(inline.enumerated()), id: \.element.id) { index, action in
            // §10.4: a tap on an inline action preview opens the Actions rail on that action.
            Button(label: action.label, onTap: { openActions(on: action.id) })
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

    // MARK: - §10: the rail stack

    /// §10.1 (round 2): two forms swapped by mode. Idle is the chips rail (C-081) alone; editing
    /// is the tool stack covering it — bottom → top the tool row, the middle rail (the open tool's
    /// choices) and the top rail (the pick's details). One surface on `color-layout-background`, no
    /// hairlines; it rides the keyboard as one unit, so the tool row stays visible.
    private var railStack: some View {
        VStack(spacing: 0) {
            if isToolMode {
                topRail
                middleRail
                toolRow
            } else {
                // C-081 §5: the editor passes `bottomInset: 16`, measured from the bar's position
                // before the inset (the chrome ignores the bottom safe area) — SPEC D11, D23.
                // §14.2: chips and ＋ only report; ＋ is disabled while the type grid shows.
                ActivityNavBar(slides: slides, activeID: state.activeID, bottomInset: Token.Space.pageMargin,
                               onSelectSlide: onSelectSlide,
                               addEnabled: state.canvasContent != "typeGrid", onAdd: onAdd)
                    .ui2Element("C-081 ActivityNavBar")
            }
        }
        .background(Token.layoutBackground)
        // The stack states its own height; the canvas takes what is left (§2).
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .offset(y: -keyboardOverlap)
    }

    private var keyboardOverlap: CGFloat { max(containerBottom - keyboardTop, 0) }

    /// §10.1 middle rail — the open tool's choices.
    @ViewBuilder private var middleRail: some View {
        switch openTool {
        case .color where mode == .editing:
            // §3 tool 1: C-094 — the well shows the object's colour, the equal swatch is
            // outlined (OQ-011); pages 2–3 are undesigned (04-color.md OQ-04-1) and empty.
            // §9.2: a tap resolves to its preset's hex; a colour no preset holds outlines none.
            TextColorPalette(
                currentColor: edited?.color ?? Token.textPrimary,
                swatches: Self.palettePages,
                page: palettePage,
                onSelect: { picked in
                    guard let editedIndex, let hex = Self.presetHex(picked) else { return }
                    apply(.init(index: editedIndex, color: hex))
                },
                onPageChange: { palettePage = $0 },
                onWellTap: onEyedropper,
                // §2 item 5: hidden, not disabled — no well unless the eyedropper is shown.
                showsWell: state.showsEyedropper
            )
            .ui2Element("C-094 TextColorPalette")
        case .font where mode == .editing:
            // §3 tool 4: the font strip; its weight row is the top rail.
            ChipStrip(items: Self.fontItems, selectedID: Self.fontID(edited?.font ?? .sans),
                      onSelect: { id in
                          if let editedIndex { apply(.init(index: editedIndex, font: id)) }
                      })
                .ui2Element("C-106 ChipStrip 2")
        case .animation where mode == .editing && state.showsEffectsTool:
            // §3 tool 6 (OQ-007): one combined strip — none, the animations, the effects.
            // C-106 has one `selectedID`, so it shows the animation when one is set, else the
            // effect (gap: two independent selections, one selected chip).
            ChipStrip(items: Self.animationItems, selectedID: animationSelectedID,
                      onSelect: selectAnimation)
                .ui2Element("C-106 ChipStrip")
        case .background:
            // §10.3: Gradient · Colour · Image; the selected option is derived.
            ChipStrip(items: Self.backgroundItems, selectedID: backgroundOption, onSelect: selectBackgroundOption)
                .ui2Element("C-106 ChipStrip")
        case .actions:
            // §10.4: the page's actions, then + Add.
            ChipStrip(items: actionItems, selectedID: selectedActionID ?? "", onSelect: selectAction)
                .ui2Element("C-106 ChipStrip 3")
        default:
            // Tools 3 and 5 have no rail.
            EmptyView()
        }
    }

    /// §10.1 top rail — the picked choice's details, only when it has some. Its height is pinned
    /// (§10.1): taller content scrolls inside it.
    @ViewBuilder private var topRail: some View {
        switch openTool {
        case .font where mode == .editing:
            // §3 tool 4: the weight row above the font strip. C-106 is 8 + 36 + 8 tall, so the
            // two share one 8pt inset and the pair stays §2's 96.
            ChipStrip(items: Self.weightItems, selectedID: Self.weightID(edited?.weight ?? .bold),
                      onSelect: { id in
                          if let editedIndex { apply(.init(index: editedIndex, weight: Self.weightCode(Self.weight(id)))) }
                      })
                .ui2Element("C-106 ChipStrip")
                .padding(.bottom, -Token.Space.elementGap)
        case .background:
            pinnedTopRail { backgroundDetails }
        case .actions:
            if let index = actions.firstIndex(where: { $0.id == selectedActionID }) {
                pinnedTopRail { actionDetails(actions[index]) }
            }
        default:
            EmptyView()
        }
    }

    /// §10.1: the top rail's pinned height — content that fits sits at its own height, taller
    /// content scrolls, and a focused field scrolls into view (D8).
    private func pinnedTopRail<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let body = content()
        return ScrollViewReader { proxy in
            ViewThatFits(in: .vertical) {
                body
                ScrollView(.vertical) { body }
                    .scrollIndicators(.hidden)
            }
            .frame(maxHeight: Self.topRailMaxHeight)
            .onChange(of: focusedField) { _, field in
                if let field { withAnimation { proxy.scrollTo(field) } }
            }
        }
    }

    // MARK: §10.3 Background

    /// §10.3: Gradient — ↻ Shuffle then one chip per palette; Colour — C-094 swatches; Image —
    /// the library's thumbnails then "More…", and once an image is set the wash.
    @ViewBuilder private var backgroundDetails: some View {
        switch backgroundOption {
        case "gradient":
            HorizontalRail(showsIndicators: false) {
                HStack(spacing: Token.Space.elementGap) {
                    IconButton(glyph: .refreshCw, tone: .default, style: .outlined, selected: false,
                               accessibilityLabel: Self.shuffleLabel, onTap: { onBackground(.shuffle) })
                        .ui2Element("C-102 IconButton \(visibleTools.count + 1)")
                    ForEach(Array(state.palettes.enumerated()), id: \.offset) { index, palette in
                        paletteTile(palette, index: index)
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.vertical, Token.Space.elementGap)
            }
        case "image":
            VStack(alignment: .leading, spacing: 0) {
                HorizontalRail(showsIndicators: false) {
                    HStack(spacing: Token.Space.elementGap) {
                        ForEach(Array(state.libraryImages.enumerated()), id: \.element.id) { index, image in
                            thumbnail(image, index: index)
                                .onAppear {
                                    if index == state.libraryImages.count - 1, state.hasMoreImages {
                                        onBackground(.loadMoreImages)
                                    }
                                }
                        }
                        FilterChip(type: .button, active: false, label: Self.moreImagesLabel, onSelect: {
                            onBackground(.moreImages)
                            onPickImage()
                        })
                        .ui2Element("C-035 FilterChip")
                    }
                    .padding(.horizontal, Token.Space.pageMargin)
                    .padding(.vertical, Token.Space.elementGap)
                }
                if !state.pageImageURL.isEmpty {
                    // §10.3: the wash colour (C-094, swatches only) and opacity (system Slider).
                    TextColorPalette(currentColor: washColor, swatches: Self.palettePages,
                                     onSelect: { picked in
                                         guard let hex = Self.presetHex(picked) else { return }
                                         onBackground(.wash(color: hex, opacity: state.pageWashOpacity))
                                     },
                                     showsWell: false)
                        .ui2Element("C-094 TextColorPalette 2")
                    // activities-editor §3 tool 2: undrawn default, the system slider (no registry row).
                    SwiftUI.Slider(value: Binding(get: { state.pageWashOpacity },
                                                  set: { onBackground(.wash(color: washHex, opacity: $0)) }),
                                   in: 0...1)
                        .tint(Token.white100)
                        .padding(.horizontal, Token.Space.pageMargin)
                        .padding(.vertical, Token.Space.elementGap)
                        .accessibilityLabel("Wash opacity")
                        .ui2Element("Wash opacity")
                }
            }
        default:
            // §10.3 Colour: C-094, swatches only — no well (§2 item 4).
            TextColorPalette(
                currentColor: pageColor,
                swatches: Self.palettePages,
                page: palettePage,
                onSelect: { picked in
                    guard let hex = Self.presetHex(picked) else { return }
                    onBackground(.colour(hex))
                },
                onPageChange: { palettePage = $0 },
                showsWell: false
            )
            .ui2Element("C-094 TextColorPalette")
        }
    }

    /// GAP — OQ-activities-editor-41: the palette chip, screen-drawn until a registry row exists —
    /// a 33×44 `radius-card` tile of the palette's base under C-091's own blob gradient, outlined
    /// 1pt `color-white-100` when it is the page's palette.
    private func paletteTile(_ palette: [String], index: Int) -> some View {
        let tile = CGSize(width: Self.paletteTileWidth, height: Self.paletteTileHeight)
        return SwiftUI.Button(action: { onBackground(.palette(index)) }) {
            ZStack(alignment: .topLeading) {
                Self.hexColor(palette.first ?? "") ?? Token.activitySlidePlaceholder
                ActivityBlobGradient(gradient: Self.tileGradient(palette), pageSize: tile)
            }
            .frame(width: tile.width, height: tile.height)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
            .overlay {
                if index == selectedPaletteIndex {
                    RoundedRectangle(cornerRadius: Token.Radius.card)
                        .strokeBorder(Token.white100, lineWidth: Self.hairline)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Palette \(index + 1)")
        .accessibilityAddTraits(index == selectedPaletteIndex ? [.isButton, .isSelected] : .isButton)
        .ui2Element("Palette chip \(index + 1)")
    }

    /// GAP — OQ-activities-editor-42: the library thumbnail, screen-drawn until a registry row
    /// exists — 44×44 `radius-card`, read cache-first (R-04 / R-19), never fetched here.
    private func thumbnail(_ image: State.LibraryImage, index: Int) -> some View {
        SwiftUI.Button(action: { onBackground(.image(image.id)) }) {
            ZStack {
                Token.activitySlidePlaceholder
                if let url = URL(string: image.thumbnailURL), let picture = Ui2ImageCache.shared.image(for: url) {
                    SwiftUI.Image(uiImage: picture)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Library image \(index + 1)")
        .ui2Element("Thumbnail \(index + 1)")
    }

    /// §10.3: the option the rail shows — the rail's own pick until the document follows it.
    private var backgroundOption: String { pickedBackgroundOption ?? state.backgroundOption }

    private var isImageRailOpen: Bool {
        openTool == .background && backgroundOption == "image" && !state.pageImageURL.isEmpty
    }

    private func selectBackgroundOption(_ id: String) {
        endField()
        pickedBackgroundOption = id
        guard id != state.backgroundOption else { return }
        switch id {
        case "gradient": onBackground(.gradient)
        case "colour": onBackground(.colour(nil))
        default: break                                       // Image: a thumbnail tap reports it
        }
    }

    /// D13: the palette whose colours are the page gradient's (base + blob colours), if any.
    private var selectedPaletteIndex: Int? {
        guard let gradient = state.gradient else { return nil }
        let colours = Set(([gradient.base] + gradient.blobs.map(\.color)).map { $0.uppercased() })
        return state.palettes.firstIndex { Set($0.map { $0.uppercased() }) == colours }
    }

    // MARK: §10.4 Actions

    /// §10.4: the page's actions by label ("Action" when empty), then + Add.
    private var actionItems: [ChipStrip.Item] {
        actions.map { ChipStrip.Item(id: $0.id, label: $0.label.isEmpty ? "Action" : $0.label) }
            + [ChipStrip.Item(id: Self.addActionID, label: "+ Add")]
    }

    /// §10.4: Kind, the label, Placement, the kind's fields, then Remove (hidden on a just-added
    /// action). Edits are live; there is no Done.
    private func actionDetails(_ action: PageAction) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ChipStrip(items: Self.kindItems, selectedID: action.kind.rawValue, onSelect: { id in
                endField()
                updateAction(action.id) { $0.kind = PageAction.Kind(rawValue: id) ?? $0.kind }
            })
            .ui2Element("C-106 ChipStrip")
            field("label", placeholder: "Label", text: action.label, kind: .single) { text in
                updateAction(action.id) { $0.label = text }
            }
            ChipStrip(items: Self.placementItems, selectedID: action.placement.rawValue, onSelect: { id in
                endField()
                setPlacement(PageAction.Placement(rawValue: id) ?? action.placement, of: action.id)
            })
            .ui2Element("C-106 ChipStrip 2")
            prefill(action)
            if !newActionIDs.contains(action.id) {
                Button(label: "Remove action", onTap: { remove(action.id) })
                    .ui2Element("C-105 Button")
                    .padding(.horizontal, Token.Space.pageMargin)
                    .padding(.vertical, Token.Space.elementGap)
            }
        }
    }

    /// §10.4: the fields depend on the kind — title + multiline body, write prompt multiline,
    /// URL single-line.
    @ViewBuilder
    private func prefill(_ action: PageAction) -> some View {
        switch action.kind {
        case .addToPrayerList:
            VStack(spacing: Token.Space.elementGap) {
                field("value", placeholder: "Title", text: action.value, kind: .single) { text in
                    updateAction(action.id) { $0.value = text }
                }
                field("body", placeholder: "Body", text: action.body, kind: .multi) { text in
                    updateAction(action.id) { $0.body = text }
                }
            }
            .padding(.vertical, Token.Space.elementGap)
        case .write:
            field("value", placeholder: "Write your thoughts", text: action.value, kind: .multi) { text in
                updateAction(action.id) { $0.value = text }
            }
            .padding(.vertical, Token.Space.elementGap)
        case .openUrl:
            field("value", placeholder: "https://…", text: action.value, kind: .single) { text in
                updateAction(action.id) { $0.value = text }
            }
            .padding(.vertical, Token.Space.elementGap)
        case .nextLesson:
            EmptyView()
        }
    }

    /// D8: a C-045 in the top rail. A single-line field ends on Return; any field ends on a
    /// canvas tap or a tool tap, keeping its value.
    private func field(_ key: String, placeholder: String, text: String, kind: TextInput.Kind,
                       onChange: @escaping (String) -> Void) -> some View {
        let submit: (() -> Void)? = kind == .single ? { endField() } : nil
        return TextInput(
            text: text,
            placeholder: placeholder,
            kind: kind,
            focused: focusedField == key,
            onChange: onChange,
            onFocusChange: { focused in
                if focused {
                    focusedField = key
                } else if focusedField == key {
                    focusedField = nil
                }
            },
            editing: .init(onSubmit: submit)
        )
        .padding(.horizontal, Token.Space.pageMargin)
        .id(key)
        .ui2Element("C-045 TextInput \(placeholder)")
    }

    private func selectAction(_ id: String) {
        endField()
        guard id == Self.addActionID else {
            selectedActionID = id
            return
        }
        // §10.4: a new action is Add to Prayer List, Inline, empty label.
        let action = PageAction(id: UUID().uuidString, kind: .addToPrayerList, label: "",
                                placement: .inline, value: "", body: "")
        newActionIDs.insert(action.id)
        actions.append(action)
        selectedActionID = action.id
        onActionsChange(actions)
    }

    private func updateAction(_ id: String, _ change: (inout PageAction) -> Void) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        change(&actions[index])
        onActionsChange(actions)
    }

    /// §10.4: Pinned demotes the page's other pinned action to Inline.
    private func setPlacement(_ placement: PageAction.Placement, of id: String) {
        if placement == .pinned {
            for other in actions.indices where actions[other].id != id && actions[other].placement == .pinned {
                actions[other].placement = .inline
            }
        }
        updateAction(id) { $0.placement = placement }
    }

    private func remove(_ id: String) {
        endField()
        actions.removeAll { $0.id == id }
        selectedActionID = actions.first?.id
        onActionsChange(actions)
    }

    private func openActions(on id: String) {
        // §10.4 (round 2, OQ-activities-editor-44): in Idle the tap does nothing — Actions are
        // reached only through the Actions tool while editing.
        guard isToolMode else { return }
        endField()
        selectedActionID = id
        setOpenTool(.actions)
    }

    // MARK: - §2 item 5 / §10.2: the tool row

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

    /// §3 Tools: category tools take `selected` while their rails are open; 3 is never selected;
    /// 5 is selected while Highlighting is on.
    private func isSelected(_ tool: Tool) -> Bool {
        switch tool {
        case .alignment: return false
        case .highlight: return mode == .highlighting
        default: return openTool == tool
        }
    }

    private func tap(_ tool: Tool) {
        // D8: a tool tap ends a rail field, keeping its value.
        endField()
        switch tool {
        case .alignment:
            // §3 tool 3: center → left → right → center, no rail.
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
        default:
            // §10.1: tapping the open tool again closes its rails.
            setOpenTool(openTool == tool ? nil : tool)
        }
    }

    // MARK: - §10.5 / §10.6: taps and closing rails

    /// §11.2 (D10, D21): exactly one per empty-canvas tap, which C-091 reports in Idle and while
    /// editing — a focused rail field → end it; a Background or Actions rail open → close it;
    /// editing (Highlighting is part of the edit) → tap-off, which ends the edit exactly like Done;
    /// Idle → add a text object.
    private func tapCanvas(at point: CGPoint? = nil) {
        // §13.1: a touch the bridge marked as a manipulation is never a tap.
        guard !touchWasManipulation else { return }
        if focusedField != nil {
            endField()
        } else if openTool == .background || openTool == .actions {
            setOpenTool(nil)
        } else if point != nil, let tapTarget {
            // D25: a tap inside a grab area opens that object (D20); inside the edited object's,
            // it stays in the edit.
            if tapTarget != editedIndex { tapObject(tapTarget) }
        } else if mode == .editing || mode == .highlighting {
            onTapOff()
        } else if mode == .idle, let point {
            onTapEmpty(point)
        }
    }

    /// §10.5: a tap on an object — the container commits any current edit, then edits it (D20).
    private func tapObject(_ index: Int) {
        // §13.1: a touch the bridge marked as a manipulation is never a tap.
        guard !touchWasManipulation else { return }
        endField()
        onTapObject(index)
    }

    private func closeRails() { setOpenTool(nil) }

    /// §10.6: when a Background or Actions rail closes, an action still empty is dropped (D19) and
    /// `onPageRailsClosed` fires — the container's save moment in Idle.
    private func setOpenTool(_ tool: Tool?) {
        let closing = openTool
        openTool = tool
        pickedBackgroundOption = nil
        guard let closing, closing == .background || closing == .actions, closing != tool else { return }
        if closing == .actions {
            let kept = actions.filter { !$0.label.isEmpty }
            if kept.count != actions.count {
                actions = kept
                onActionsChange(kept)
            }
            newActionIDs = []
            if !kept.contains(where: { $0.id == selectedActionID }) { selectedActionID = kept.first?.id }
            onChangeActions(actions)
        }
        onPageRailsClosed()
    }

    /// D8: ends the focused rail field; its value is already reported.
    private func endField() {
        guard focusedField != nil else { return }
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Superseded by §10 (there is no sheet to lift): kept, unused by the view, for the existing
    /// screen contract tests until text-activity-v2 rewrites them. A sheet stood on the keyboard's
    /// top edge — lifted once, by the overlap — and its cap shrank by that overlap.
    static func sheetLayout(available: CGFloat, keyboardOverlap: CGFloat) -> (maxHeight: CGFloat, lift: CGFloat) {
        let room = max(available - sheetTopGap, 0)
        let lift = min(max(keyboardOverlap, 0), room)
        return (room - lift, lift)
    }

    // MARK: - Derived values

    /// §2 item 3 (D4; 02 §5) + §10.8: the document's background layer, from `State` — colour,
    /// gradient, image, wash. `motion` keeps C-091's default here and is never drawn or exposed.
    private var background: ActivityCanvas<AnyView>.Background {
        var result = ActivityCanvas<AnyView>.Background(color: pageColor)
        if let gradient = state.gradient {
            result.gradient = .init(
                base: Self.hexColor(gradient.base) ?? pageColor,
                hidden: gradient.hidden,
                blobs: gradient.blobs.map { .init(x: $0.x, y: $0.y, r: $0.r, color: Self.hexColor($0.color) ?? pageColor) }
            )
        }
        if !state.pageImageURL.isEmpty, let url = URL(string: state.pageImageURL) {
            result.image = .init(imageURL: url, focal: CGPoint(x: state.pageImageFocalX, y: state.pageImageFocalY))
            if state.pageWashOpacity > 0 {
                result.wash = .init(color: washColor, opacity: state.pageWashOpacity)
            }
        }
        return result
    }

    private var pageColor: Color { Self.hexColor(state.pageColorHex) ?? Token.backgroundAlt }
    private var washHex: String { state.pageWashHex.isEmpty ? Self.defaultWashHex : state.pageWashHex }
    private var washColor: Color { Self.hexColor(washHex) ?? Token.black }

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
    /// §11 (D24): on the fixed canvas (`scrolls: false`) the offset is 02 §4 step 1 only — no nudge
    /// and no growth — so objects stay where the author put them, past an edge if need be.
    private func pageOffset(viewport: CGFloat) -> CGFloat {
        (viewport - Self.referenceHeight) / 2
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

    /// C-081 `slides`: each chip's screenshot resolved from the image cache — a cached image
    /// renders C-081's filled chip, none the empty C-061 chip (OQ-C-081-6, restored 2026-11-09).
    private var slides: [ActivityNavBar.Slide] {
        zip(state.slideIDs, state.slideLabels).enumerated().map { index, slide in
            ActivityNavBar.Slide(id: slide.0, image: Self.cachedSlideImage(state.slideImages.indices.contains(index) ? state.slideImages[index] : nil),
                                 label: slide.1)
        }
    }

    /// C-081 slide `image` is `Image?`, resolved by the caller (R-19 / R-32): read from the
    /// preview module's image cache — which the container and the capture case seed — never loaded.
    private static func cachedSlideImage(_ raw: String?) -> Image? {
        guard let raw, !raw.isEmpty, let url = URL(string: raw),
              let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
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

    /// §10.2 / §10.6: the tools that act on a selected text object.
    private static let textTools: Set<Tool> = [.color, .alignment, .font, .animation]

    /// §9.2: a C-094 tap resolves to its preset's hex; a colour no preset holds resolves to none.
    private static func presetHex(_ picked: Color) -> String? {
        swatchPresets.first { hexColor($0.hex) == picked }?.hex
    }

    /// §10.3: the Background rail's three options.
    private static let backgroundItems: [ChipStrip.Item] = [
        .init(id: "gradient", label: "Gradient"),
        .init(id: "colour", label: "Colour"),
        .init(id: "image", label: "Image")
    ]

    /// §10.4: the Actions rail's trailing chip.
    private static let addActionID = "add"

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

    /// GAP — OQ-activities-editor-41: the palette chip's blob layout, `x`, `y`, `r` as fractions
    /// of the tile width (C-091's D2 units), screen-drawn until a registry row exists. The
    /// palette's base is the tile's fill; its other colours take these blobs in turn.
    private static let tileBlobs: [(x: Double, y: Double, r: Double)] = [
        (0.15, 0.25, 0.95), (0.9, 0.55, 0.9), (0.25, 1.1, 0.9), (0.85, 1.3, 0.85), (0.5, 0.7, 0.6)
    ]

    private static func tileGradient(_ palette: [String]) -> ActivityCanvasGradient {
        let colours = palette.dropFirst().compactMap(hexColor)
        let blobs = tileBlobs.indices.compactMap { index -> ActivityCanvasGradient.Blob? in
            guard !colours.isEmpty else { return nil }
            let place = tileBlobs[index]
            return .init(x: place.x, y: place.y, r: place.r, color: colours[index % colours.count])
        }
        return .init(base: hexColor(palette.first ?? "") ?? Token.activitySlidePlaceholder, hidden: false, blobs: blobs)
    }

    /// OQ-015: the slider's wu range and its 50 % default.
    private static func size(forSlider value: CGFloat) -> Double {
        minSize + Double(value) * (maxSize - minSize)
    }

    // §2 copy.
    private static let title = "Edit lesson"
    private static let deleteHighlightLabel = "Delete highlight"
    private static let addNoteLabel = "Add note"
    /// §14.1 `readOnly`: the note under the read-only page's title.
    private static let readOnlyNote = "This activity can't be edited yet."
    /// FLAGGED LITERAL — activities-player §2 fallback page: title 24, body 16, 16 wu apart.
    private static let readOnlyTitleSize: CGFloat = 24
    private static let readOnlyNoteSize: CGFloat = 16
    private static let readOnlyGap: CGFloat = 16
    private static let shuffleLabel = "Shuffle"
    private static let moreImagesLabel = "More…"
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
    /// FLAGGED LITERAL — activities-editor D25: a grab area is the rendered box padded by 24 pt on
    /// every side and at least 88 × 88 pt.
    static let grabPadding: CGFloat = 24
    static let grabMinimum: CGFloat = 88
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
    /// GAP — activities-editor §2 item 2: the 1px hairline (also the palette chip's outline).
    private static let hairline: CGFloat = 1
    /// GAP — OQ-activities-editor-41 / 42: the palette chip 33×44 and the thumbnail 44×44.
    private static let paletteTileWidth: CGFloat = 33
    private static let paletteTileHeight: CGFloat = 44
    private static let thumbnailSize: CGFloat = 44
    /// FLAGGED LITERAL — activities-editor §10.1: the top rail's pinned height — two C-106 rows
    /// (52 each) and a single-line C-045 (44), whole rows; the rest scrolls inside the rail.
    private static let topRailMaxHeight: CGFloat = 148
    /// §10.3: a canvas touch that moves less than this is a tap, not a focal drag.
    private static let tapSlop: CGFloat = 10
    /// §13.2 FLAGGED LITERAL — activities-editor §3 Transitions (no `motion-*` token holds it):
    /// the object between its transform and the edit slot, ease-out 150 ms, both directions.
    private static let editTransition = Animation.easeOut(duration: 0.15)
    /// §10.3: the wash colour before one is chosen — `color-black`'s value.
    private static let defaultWashHex = "#000000"
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
    /// D4 / D13: the 12 palettes (base first) — text-activity-v2's curated set.
    private static let samplePalettes: [[String]] = [
        ["#1B1F4A", "#3B3F9E", "#5B3E96", "#2E5C8A", "#7A2E8E"],
        ["#0B3440", "#0F6B6E", "#1F5F8B", "#13807A", "#2A4E7A"],
        ["#3A0F1A", "#A3262E", "#B4442A", "#8C1F4F", "#9A3B12"],
        ["#0F2E1F", "#1E6B3A", "#2F7A55", "#4A6B1E", "#14625E"],
        ["#2A0F33", "#6B2380", "#8E2C6E", "#4B2A8C", "#A0285A"],
        ["#0A1F3D", "#1A4C8C", "#2563A8", "#0F6E8C", "#3A3F9E"],
        ["#3A1030", "#B03A4A", "#A8462E", "#7A2F7A", "#C0392B"],
        ["#0D2233", "#14736B", "#3A4FA0", "#6A2E8C", "#1C6B8C"],
        ["#33071F", "#9C1F55", "#7A1F7A", "#B0284A", "#5A2A9C"],
        ["#1A2410", "#4F6B1A", "#2E6B3F", "#6B5A12", "#1F5E4A"],
        ["#1F1433", "#4A3A8C", "#7A3A7A", "#2E4A8C", "#8C3A5A"],
        ["#2E1408", "#8C3A12", "#A0461F", "#7A2E1F", "#6B4A12"]
    ]
    /// D3: a generated gradient from the first palette — base its darkest colour, four blobs.
    private static let sampleGradient = Gradient(
        base: "#1B1F4A",
        hidden: false,
        blobs: [
            .init(x: 0.2, y: 0.3, r: 0.7, color: "#3B3F9E"),
            .init(x: 0.85, y: 0.65, r: 0.65, color: "#5B3E96"),
            .init(x: 0.3, y: 1.2, r: 0.75, color: "#2E5C8A"),
            .init(x: 0.75, y: 1.55, r: 0.6, color: "#7A2E8E")
        ]
    )
    /// §10.3 / D22: library thumbnails from the project's image catalog, newest first.
    private static let sampleLibrary: [LibraryImage] = [
        "revelation-new-creation-city", "revelation-multitude-worship", "revelation-lampstands-witness",
        "revelation-lamb-scroll-v02", "jude-mercy-rescue", "jude-kept-standing"
    ].map { .init(id: $0, thumbnailURL: "http://localhost:5961/api/projects/makeready/images/\($0)") }

    /// §10.9 (round 2) — a page rail open in the editing form: the object being edited, the tool
    /// stack covering the chips rail, all five tools enabled.
    private static func pageRail(_ tool: String, option: String) -> Self {
        var s = committed()
        s.canSave = true
        s.editorMode = "editing"
        s.editingIndex = 0
        s.openTool = tool
        s.backgroundOption = option
        s.gradient = sampleGradient
        s.pageColorHex = sampleGradient.base
        s.palettes = samplePalettes
        s.libraryImages = sampleLibrary
        s.hasMoreImages = true
        return s
    }

    /// §10.9 background-gradient — ↻ Shuffle and the 12 palette chips, the page's palette outlined.
    static let backgroundGradient = pageRail("background", option: "gradient")
    /// §10.9 background-colour — C-094 swatches; the gradient kept but hidden (D14).
    static let backgroundColour: Self = {
        var s = pageRail("background", option: "colour")
        s.gradient?.hidden = true
        s.pageColorHex = "#509CEF"
        return s
    }()
    /// §10.9 background-image — the thumbnails and More…, then the wash (C-094 + opacity).
    static let backgroundImage: Self = {
        var s = pageRail("background", option: "image")
        s.pageImageURL = "http://localhost:5961/api/projects/makeready/images/genesis-abram-stars"
        s.pageImageFocalX = 0.7
        s.pageImageFocalY = 0.3
        s.pageWashHex = "#141F6B"
        s.pageWashOpacity = 0.5
        return s
    }()
    /// §10.9 actions-rail — the page's actions in the middle rail, the first in the top rail.
    static let actionsRail: Self = {
        var s = pageRail("actions", option: "gradient")
        s.actionIDs = ["action-1", "action-2"]
        s.actionKinds = ["addToPrayerList", "nextLesson"]
        s.actionLabels = ["Add to Prayer List", "Next lesson"]
        s.actionPlacements = ["inline", "pinned"]
        s.actionValues = ["", ""]
        s.actionBodies = ["", ""]
        return s
    }()
    /// §10.9 rails-375 (OQ-activities-editor-43) — the Actions rail with its label field focused;
    /// the keyboard check at 375×667 is a device-walk item.
    static let rails375: Self = {
        var s = actionsRail
        s.focusedActionField = "label"
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

#Preview("Background gradient") {
    ActivitiesEditorScreen(state: .backgroundGradient)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Background colour") {
    ActivitiesEditorScreen(state: .backgroundColour)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Background image") {
    ActivitiesEditorScreen(state: .backgroundImage)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Actions rail") {
    ActivitiesEditorScreen(state: .actionsRail)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Rails 375") {
    ActivitiesEditorScreen(state: .rails375)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

// MARK: - §10.10: the canvas-wide manipulation recognizers (UIKit bridge)

/// §10.10: UIPan, UIPinch and UIRotation recognizing simultaneously, attached to the window so a
/// pinch or rotate works wherever on the canvas the fingers are. UIPan's translation is already the
/// centroid of the touches. §11 (D24): they act on the manipulated object only and never pan the
/// canvas, which is fixed. `cancelsTouchesInView = false` on every one, so a single tap is never
/// swallowed and always reaches `tapCanvas` (taps, C-092's touch-down). Draws nothing.
struct CanvasManipulation: UIViewRepresentable {
    enum Kind: Hashable { case move, pinch, rotate }
    enum Phase { case began, changed, ended }

    struct Update {
        var phase: Phase
        var kind: Kind
        /// `move`: the centroid's translation and location, in points in this view.
        var translation: CGSize = .zero
        var location: CGPoint = .zero
        /// `pinch`: the magnification since the pinch began.
        var scale: CGFloat = 1
        /// `rotate`: radians since the rotation began.
        var rotation: Double = 0
    }

    /// Whether a touch at this point (in this view) is on the canvas.
    let accepts: (CGPoint) -> Bool
    let canBegin: (Kind) -> Bool
    let onUpdate: (Update) -> Void
    /// D25: the first finger is down — its point in this view, or nil when it is off the canvas.
    let onTouchDown: (CGPoint?) -> Void
    /// §13.1: the touch sequence is a manipulation, not a tap — a move, pinch or rotate began, or
    /// the first finger travelled `TouchTracker.tapTravel` from finger-down. Once per sequence.
    let onManipulation: () -> Void
    /// Every finger is up — the touch sequence is over.
    let onAllUp: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        context.coordinator.view = view
        context.coordinator.source = self
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        context.coordinator.source = self
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            coordinator?.detach()
            if let newWindow { coordinator?.attach(to: newWindow) }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var view: UIView?
        var source: CanvasManipulation?
        private lazy var pan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            recognizer.maximumNumberOfTouches = 2
            return recognizer
        }()
        private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        private lazy var rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        private lazy var tracker = TouchTracker(
            onFirstDown: { [weak self] touch in self?.firstDown(touch) },
            onTravelled: { [weak self] in self?.markManipulation() },
            onAllUp: { [weak self] in self?.source?.onAllUp() }
        )
        /// §13.1: the current sequence is already marked.
        private var marked = false

        private func markManipulation() {
            guard !marked else { return }
            marked = true
            source?.onManipulation()
        }

        /// D25: reports the first finger-down before any recognizer begins.
        private func firstDown(_ touch: UITouch) {
            marked = false
            guard let view, let source else { return }
            let point = touch.location(in: view)
            source.onTouchDown(source.accepts(point) ? point : nil)
        }

        private var recognizers: [UIGestureRecognizer] { [pan, pinch, rotation, tracker] }

        func attach(to window: UIWindow) {
            for recognizer in recognizers {
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesEnded = false
                recognizer.delegate = self
                window.addGestureRecognizer(recognizer)
            }
        }

        func detach() {
            for recognizer in recognizers { recognizer.view?.removeGestureRecognizer(recognizer) }
        }

        private func kind(of recognizer: UIGestureRecognizer) -> Kind? {
            if recognizer === pan { return .move }
            if recognizer === pinch { return .pinch }
            if recognizer === rotation { return .rotate }
            return nil
        }

        private func phase(_ state: UIGestureRecognizer.State) -> Phase? {
            switch state {
            case .began: return .began
            case .changed: return .changed
            case .ended, .cancelled, .failed: return .ended
            default: return nil
            }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let phase = phase(recognizer.state) else { return }
            if phase == .began { markManipulation() }
            let moved = recognizer.translation(in: view)
            source?.onUpdate(.init(phase: phase, kind: .move,
                                   translation: CGSize(width: moved.x, height: moved.y),
                                   location: recognizer.location(in: view)))
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let phase = phase(recognizer.state) else { return }
            if phase == .began { markManipulation() }
            source?.onUpdate(.init(phase: phase, kind: .pinch, scale: recognizer.scale))
        }

        @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
            guard let phase = phase(recognizer.state) else { return }
            if phase == .began { markManipulation() }
            source?.onUpdate(.init(phase: phase, kind: .rotate, rotation: Double(recognizer.rotation)))
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if recognizer === tracker { return true }
            guard let view, let source else { return false }
            return source.accepts(touch.location(in: view))
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let kind = kind(of: recognizer) else { return true }
            return source?.canBegin(kind) ?? false
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(recognizer === pan && Self.isScrollPan(other))
        }

        /// A scroll view's pan (the rails') waits for the move to fail, so a drag that moves an object
        /// never scrolls anything; the canvas itself has no scroll (§11, D24).
        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            recognizer === pan && Self.isScrollPan(other)
        }

        private static func isScrollPan(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let scroll = recognizer.view as? UIScrollView else { return false }
            return recognizer === scroll.panGestureRecognizer
        }
    }

    /// Recognizes nothing: it watches every touch so the bridge knows when the first finger lands
    /// (D25) and when the last finger lifts.
    final class TouchTracker: UIGestureRecognizer {
        /// §13.1 FLAGGED LITERAL — activities-editor §13: a first finger that travels this far from
        /// finger-down makes the sequence a manipulation, never a tap.
        static let tapTravel: CGFloat = 10

        private let onFirstDown: (UITouch) -> Void
        private let onTravelled: () -> Void
        private let onAllUp: () -> Void
        private var touching = 0
        /// §13.1: the first finger of the sequence and where it landed (window points).
        private weak var firstTouch: UITouch?
        private var firstPoint: CGPoint = .zero

        init(onFirstDown: @escaping (UITouch) -> Void, onTravelled: @escaping () -> Void,
             onAllUp: @escaping () -> Void) {
            self.onFirstDown = onFirstDown
            self.onTravelled = onTravelled
            self.onAllUp = onAllUp
            super.init(target: nil, action: nil)
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if touching == 0, let first = touches.first {
                firstTouch = first
                firstPoint = first.location(in: nil)
                onFirstDown(first)
            }
            touching += touches.count
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let firstTouch, touches.contains(firstTouch) else { return }
            let point = firstTouch.location(in: nil)
            if hypot(point.x - firstPoint.x, point.y - firstPoint.y) >= Self.tapTravel { onTravelled() }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }

        private func lift(_ touches: Set<UITouch>) {
            touching = max(touching - touches.count, 0)
            guard touching == 0 else { return }
            onAllUp()
            state = .failed
        }

        override func reset() {
            super.reset()
            touching = 0
            firstTouch = nil
        }

        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}
