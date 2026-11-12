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
        /// §15.2 (D30): C-093 drawn docked at the screen's left edge when the edit opens (the
        /// slider-docked preview). The live view docks it itself after 2 s untouched.
        var sliderDocked: Bool = false
        /// §18.8 (D32, D33): in Manipulating, the object drawn as the one being dragged — its
        /// active guides are `snapPosition`'s at its seeded position, and C-091's reserved zones
        /// draw only while its box enters one. −1 = none (the snap-centre / -edge / -gap previews).
        var snapIndex: Int = -1
        /// §20.1 (D11): per object, `isLocked` (parallel to `objectTexts`; a short array leaves the
        /// rest unlocked) — no text input, no keyboard, no text deletion; still movable, scalable,
        /// rotatable, restylable and highlightable. Set only for `bible` activities' scripture.
        var objectLocks: [Bool] = []
        /// §20.1: each object's id, parallel to `objectTexts` — what `highlightingObjectID` names.
        var objectIDs: [String] = []
        /// §20.1 / §20.2: the object in highlighting mode — drawn at full size with its spans;
        /// nil = none (the text activity's Highlighting, unchanged).
        var highlightingObjectID: String?
        /// §21.1 (D26): the page's height in wu. Above 956 the page scrolls vertically inside the
        /// canvas (header and tool stack fixed) and the background fills the whole height; at or
        /// below 956 nothing changes (§11).
        var pageHeight: CGFloat = 956
        /// §21.2 (D28): per object, the page provides its frame (parallel to `objectLocks`; a short
        /// array leaves the rest unset) — C-092 `pageLaidOut`: no handles, no drag, pinch or rotate.
        var objectPageLaidOut: [Bool] = []
        /// §21.3 (D29) / §23 (D33): a `bible` activity — the eight-tool row (Colour · Background ·
        /// Align · Font · Size · Line height · Padding · Highlight) and its panels.
        var isBible: Bool = false
        /// §21.4: the scripture's current style — face `display` · `sans` · `serif` · `mono`,
        /// weight 400 · 500 · 700, size (pt), line height (×), inset from the page edge (pt) and
        /// verse numbers `gutter` · `hidden` · `inline`.
        var bibleFace: String = "serif"
        var bibleWeight: Int = 400
        var bibleSize: CGFloat = 18
        var bibleLineHeight: CGFloat = 1.4
        /// §23.4 (D33): Padding's default is 32.
        var bibleInset: CGFloat = 32
        var bibleVerseNumbers: String = "gutter"
        /// §22.2 (D28 fix): the scripture's colour `#RRGGBB` and alignment `left` · `center` ·
        /// `right` — the seeds the Idle Colour and Alignment tools mark; "" = the scripture
        /// object's own.
        var bibleColor: String = ""
        var bibleAlignment: String = ""
        /// §23.5 (D32): where the page-laid-out block sits between the 956 wu page's 96 wu top and
        /// bottom insets — `top` · `center` · `bottom`; anything else reads as `top`, and a page
        /// taller than 956 has no slack, so it reads as `top` whatever the value.
        var bibleVerticalAlignment: String = "top"
        /// §25 (D35): the tone of every tool bar icon, Idle and editing — `.light` today's colours,
        /// `.dark` `color-black`. The container computes it from the page background (WCAG
        /// relative luminance ≥ 0.5 → `.dark`); the screen only takes it. §27.1 (D38): `ToolbarTone`
        /// is the top-level type the components share.
        var toolbarTone: ToolbarTone = .light

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

    /// §20.3 (D12): one row of the locked-object C-066 menu the container presents.
    struct LockedObjectMenuRow: Equatable, Identifiable {
        enum ID: String { case changePassage, highlight }
        let id: ID
        let label: String
        /// The row's Glyph raw name (C-066 / ActionMenuRow `glyph`).
        let glyph: String
    }

    /// §20.3: the rows a tap on a locked scripture or citation object in Idle offers, in order
    /// Change passage · Highlight. The screen presents nothing; the container shows them.
    static let lockedObjectMenuRows: [LockedObjectMenuRow] = [
        .init(id: .changePassage, label: "Change passage", glyph: GlyphName.bookOpen.rawValue),
        .init(id: .highlight, label: "Highlight", glyph: GlyphName.textHighlight.rawValue)
    ]

    /// §21.4 (D29): one Bible font panel change — the container writes it into the scripture
    /// object's `font`, `weight`, `size`, `lineHeight`, the page padding and the verse-number mode.
    enum BibleStyleChange: Equatable {
        /// `display` · `sans` · `serif` · `mono`.
        case face(String)
        /// 400 · 500 · 700.
        case weight(Int)
        /// pt, 14–40.
        case size(CGFloat)
        /// ×, 1.0–2.0.
        case lineHeight(CGFloat)
        /// pt from the page edge, 16–64.
        case inset(CGFloat)
        /// `gutter` · `hidden` · `inline`.
        case verseNumbers(String)
        /// §22.2: `#RRGGBB` — the Colour tool in Idle on a bible activity.
        case color(String)
        /// §22.2 / §23.2: `left` · `center` · `right` — the Align panel's horizontal row.
        case alignment(String)
        /// §23.2 (D32): `top` · `center` · `bottom` — the Align panel's vertical row.
        case verticalAlignment(String)
    }

    /// §3 Tools — the tool row, order 1–7. §23.1 (D33): `size`, `lineHeight` and `padding` are a
    /// `bible` activity's own tools — never in any other activity's row.
    enum Tool: String, CaseIterable {
        case color, background, alignment, font, highlight, animation, actions
        case size, lineHeight, padding
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
    /// §20.1: a selected range in the highlighting object — UTF-16 offsets into its text, `end`
    /// exclusive, reported by C-092's highlighting mode on lift.
    var onHighlightRange: (_ objectIndex: Int, _ start: Int, _ end: Int) -> Void = { _, _, _ in }
    /// §20.2: tool 5 again, or Done, while `highlightingObjectID` is set.
    var onEndHighlighting: () -> Void = {}
    /// §21.4 (D29): a Bible font panel change — chips at once, a slider once when the finger lifts.
    var onBibleStyleChange: (BibleStyleChange) -> Void = { _ in }

    // §21.3: the Bible font panel's values as shown — each change applies here at once (a slider
    // per frame) and is reported through `onBibleStyleChange`; a new `State` re-seeds them.
    @SwiftUI.State private var bibleStyle: BibleStyle
    // §21.3: a Bible panel slider is under the finger — a new `State` does not re-seed meanwhile.
    @SwiftUI.State private var bibleSliding = false

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
    // §19.3 (D34.3): the gradient rail's width, so a rail that fits centres (layout only).
    @SwiftUI.State private var gradientRailWidth: CGFloat = 0
    // §3 Error: the alert's presented flag, seeded from `State`.
    @SwiftUI.State private var alertPresented: Bool
    // §4 C-091 `contentExtent`: "the screen measures the objects' rotated, scaled box in wu".
    @SwiftUI.State private var measuredHeights: [Int: CGFloat] = [:]
    /// §29.1 (D43): each object's measured glyph rect (C-092 `onTextBounds`), kept like
    /// `measuredHeights` — wu, unscaled and unrotated, origin at the layout box's top-left.
    @SwiftUI.State private var measuredGlyphRects: [Int: CGRect] = [:]
    @SwiftUI.State private var measuredDraftHeight: CGFloat?
    // §2 item 6: the container rides the keyboard's top edge; the canvas does not resize.
    @SwiftUI.State private var keyboardTop = CGFloat.infinity
    @SwiftUI.State private var containerBottom: CGFloat = 0
    // §2: the bottom container's height, held while Manipulating hides it so the slider's clamp
    // does not change when the bars hide.
    @SwiftUI.State private var containerHeight: CGFloat = 0
    // §19.1 (D34.1): the bottom safe area the tool row clears when no keyboard is up — the chrome
    // ignores it, so it is read from the screen and kept here (layout only).
    @SwiftUI.State private var safeBottom: CGFloat = 0
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
    // §18 (D32, D33): the move's and the rotation's engaged snap targets (hysteresis) and the
    // guides the move draws — set per gesture frame, cleared when the gesture ends.
    @SwiftUI.State private var snapEngaged = SnapEngaged()
    @SwiftUI.State private var rotationEngaged: Double?
    @SwiftUI.State private var liveGuides: [ActivityCanvasGuideSegment] = []
    // §15.2 (D30): C-093 docked half off the left edge; a finger on it; and the dock timer's
    // generation — bumping it cancels the running 2 s task and starts a new one (no `asyncAfter`).
    @SwiftUI.State private var sliderDocked: Bool
    @SwiftUI.State private var sliderTouching = false
    @SwiftUI.State private var sliderDockTimer = 0
    // §15.2 (round 8): the slider drag in flight — its touch-down reference in the global space —
    // and the track's on-screen frame.
    @SwiftUI.State private var sliderDrag: SliderDrag?
    @SwiftUI.State private var sliderFrame: CGRect = .zero
    // §15.2: Reduce Motion cuts between docked and full.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        onDiscard: @escaping () -> Void = {},
        onHighlightRange: @escaping (_ objectIndex: Int, _ start: Int, _ end: Int) -> Void = { _, _, _ in },
        onEndHighlighting: @escaping () -> Void = {},
        onBibleStyleChange: @escaping (BibleStyleChange) -> Void = { _ in }
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
        self.onHighlightRange = onHighlightRange
        self.onEndHighlighting = onEndHighlighting
        self.onBibleStyleChange = onBibleStyleChange
        _bibleStyle = SwiftUI.State(initialValue: BibleStyle(state))
        _shownObjects = SwiftUI.State(initialValue: Self.committedObjects(state))
        let actions = Self.pageActions(state)
        _actions = SwiftUI.State(initialValue: actions)
        _selectedActionID = SwiftUI.State(initialValue: actions.first?.id)
        _openTool = SwiftUI.State(initialValue: Tool(rawValue: state.openTool))
        _focusedField = SwiftUI.State(initialValue: state.focusedActionField.isEmpty ? nil : state.focusedActionField)
        _alertPresented = SwiftUI.State(initialValue: state.saveFailed)
        _sliderDocked = SwiftUI.State(initialValue: state.sliderDocked)
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

    /// §22.1 (D28 fix): a bible activity in Idle — the eight-tool row (§23.1) shows and works above the
    /// chips rail with no object selected; its tools act on the page's scripture.
    private var isBibleIdle: Bool { state.isBible && !state.loadFailed && mode == .idle }
    /// §24.3: the tool row is the Bible set when `mode == .idle && state.isBible`, else the text tools.
    private var isBibleToolSet: Bool { state.isBible && mode == .idle }

    /// §22.2: the scripture as shown — the `bibleVerse` object the Idle tools act on.
    private var bibleScripture: CommittedObject? {
        shownObjects.first { $0.listStyle == .bibleVerse }.map(bibleStyled)
    }

    var body: some View {
        Group {
            if state.loadFailed {
                loadFailedPage
            } else {
                editorPage
            }
        }
        // §26.3 (D38): every `floatingControlMaterial` backing reads the tone from here.
        .environment(\.editorToolbarTone, state.toolbarTone)
    }

    /// §26.2 (D38): the ink of every control the screen draws over the page — `color-black` when
    /// `toolbarTone` is `.dark`; nil keeps each control's own paint (`.light`, today's).
    private var toneInk: Color? { state.toolbarTone == .dark ? Token.black : nil }

    /// §27.3 (D38): C-045 TextInput and C-105 Button take no tone input; with `.dark` the screen
    /// multiplies their paint to `color-black` (each part keeps its own opacity). White is a no-op.
    private var toneMultiply: Color { state.toolbarTone == .dark ? Token.black : Token.white100 }

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
                    .onChange(of: screen.safeAreaInsets.bottom, initial: true) { _, inset in safeBottom = inset }
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
            guard dragged == nil, sliderDrag == nil else { return }
            shownObjects = Self.committedObjects(next)
            if !bibleSliding { bibleStyle = BibleStyle(next) }
        }
        // §10.6 (round 2): a text edit opens with no rail open, and ending it closes every rail —
        // a page rail closing through `setOpenTool`, so `onPageRailsClosed` fires (D19).
        .onChange(of: mode) { previous, next in
            // §15.2 (D30): when an edit begins C-093 first appears in full.
            if next == .editing && previous != .editing {
                sliderDocked = state.sliderDocked
                sliderTouching = false
                sliderDrag = nil
            }
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
                    // §28 (D39): the pinned pill is a page object too — dimmed while editing.
                    .opacity(editedIndex != nil ? Self.editDimOpacity : 1)
                    .animation(Self.editTransition, value: editedIndex)
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
            // §20.2: Done ends the highlighting mode of a locked object.
            onDone: highlightingIndex != nil ? onEndHighlighting : onDone
        )
        // OQ-activities-editor-49 (owner, 2026-11-12): the header keeps C-040's `.light`
        // `toolbarTone` default whatever the page tone — its band is opaque, not over the page.
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
        let headerBottom = (safeTop + Self.headerHeight) / unit
        let containerTop = viewport - (containerHeight + keyboardOverlap) / unit
        let pinned = actions.contains { $0.placement == .pinned }
        // §21.1 (D26): a tall page states its own height — C-091 sizes the page from it — else
        // §2: fixed at drag start, so neither the page nor any object re-places under the finger.
        let extent = isTallPage ? tallPageExtent(pinned: pinned) : (dragExtent ?? measuredExtent(objects))
        let offset = pageOffset(viewport: viewport)
        return ActivityCanvas<AnyView>(
            background: background,
            mode: mode,
            content: { AnyView(canvasContent(objects, unit: unit)) },
            onTapEmpty: { point in tapCanvas(at: point) },
            // §18.7 (D33): the guides active now — the centre guide is one of them.
            activeGuides: canvasGuides(viewport: viewport, unit: unit),
            deleteTarget: state.deleteTargetShown ? .visible : nil,
            verticalAnchor: .center,
            contentExtent: extent,
            // §2 (D3): the screen only turns the guides on — §18.7 (D33): only while the
            // dragged layer enters a zone.
            reservedZones: draggedEntersZone(viewport: viewport),
            pinnedAction: pinned,
            // §21.2: a page-laid-out object has no transform handles.
            widthHandles: mode == .editing && !editedIsPageLaidOut ? widthHandles(pageOffset: offset) : nil,
            onResizeWidth: resizeDraft,
            // §21.1 (D26): a page taller than 956 scrolls inside the canvas and §2's scroll insets
            // apply again, so the first and last content clear the bars; autoscroll stays off (a
            // page-laid-out object cannot be dragged).
            scrollInsets: isTallPage
                ? .init(top: headerBottom, bottom: (containerHeight + keyboardOverlap) / unit)
                : .init(),
            // §11 (D24): otherwise the canvas is fixed to the screen in every mode — no scroll range,
            // no scroll insets, no autoscroll. The header and bottom area stay opaque over it.
            scrolls: isTallPage
        )
        .coordinateSpace(.named(Self.screenSpace))
        .overlay(alignment: .topLeading) {
            // §21.3: a page-laid-out object's size is the Bible panel's slider, not C-093's wedge.
            if mode == .editing && !editedIsPageLaidOut {
                // §2 item 3 handle / thumb separation (1): C-091 draws its handles above its slot,
                // so the slider sits over the canvas — above them in hit order, and fixed to the
                // viewport. Centred on the edit slot, clamped between the header and the container.
                // C-093's own `onChange` now only carries its accessibility adjustable action (one
                // edit per step); the drag is the screen's gesture below.
                TextSizeSlider(value: sliderValue, onChange: { value in
                    if let editedIndex { apply(.init(index: editedIndex, size: CGFloat(Self.size(forSlider: value)))) }
                })
                    .ui2Element("C-093 TextSizeSlider")
                    // §15.2 (round 8): ONE gesture owns the slider's touch — it holds the dock timer,
                    // undocks on touch-down and keeps tracking the same drag. It is measured in the
                    // global space, so the undock's slide cannot move the finger's reference, and
                    // each frame is display-only (§9.1a) with one ObjectEdit on lift.
                    .highPriorityGesture(
                        // pan-ok: vertical slider — tracks the finger on C-093's strip
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { drag in dragSlider(drag) }
                            .onEnded { _ in endSliderDrag() }
                    )
                    // FLAGGED LITERAL — activities-editor §2: slider 20×263.5 at x 11; §15.2 (D30)
                    // docked: its centre line on the screen's left edge, only its right half shows.
                    .offset(x: sliderDocked ? -Self.sliderWidth / 2 : Self.sliderX,
                            y: max(min(Self.editSlotY + offset - Self.sliderHeight / 2, containerTop - Self.sliderHeight),
                                   headerBottom))
                    .scaleEffect(unit, anchor: .topLeading)
                    // §15.2 (round 8): the track's on-screen frame, for a touch-down on the full slider.
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sliderFrame = $0 }
                    // §15.2: the dock timer is a cancellable task owned by this view — restarted
                    // when a touch on C-093 ends, cancelled when the edit ends (the slider leaves).
                    .task(id: sliderDockTimer) {
                        guard !sliderTouching, !sliderDocked else { return }
                        try? await Task.sleep(for: Self.sliderDockDelay)
                        guard !Task.isCancelled, !sliderTouching else { return }
                        setSliderDocked(true)
                    }
            }
        }
    }

    // MARK: - §15.2 (D30): the docking size slider

    private func beginSliderTouch() {
        guard !sliderTouching else { return }
        sliderTouching = true
        sliderDockTimer += 1                                 // cancels a running dock timer
        if sliderDocked { setSliderDocked(false) }
    }

    private func endSliderTouch() {
        sliderTouching = false
        sliderDockTimer += 1                                 // restarts the 2 s
    }

    /// §15.2 (round 8): one slider frame. Touch-down undocks and fixes the reference: from docked
    /// the thumb moves relative to where the finger went down (no jump); on the full slider it
    /// jumps to the touch first, as C-093 does (OQ-C-093-002). Display only — no report.
    private func dragSlider(_ drag: DragGesture.Value) {
        guard let editedIndex else { return }
        if sliderDrag == nil {
            let wasDocked = sliderDocked
            beginSliderTouch()
            let height = max(sliderFrame.height, 1)
            let start = wasDocked
                ? sliderValue
                : min(max(1 - (drag.startLocation.y - sliderFrame.minY) / height, 0), 1)
            sliderDrag = SliderDrag(startY: drag.startLocation.y, startValue: start,
                                    height: height, startSize: draftSize)
        }
        guard let reference = sliderDrag else { return }
        let value = min(max(reference.startValue + (reference.startY - drag.location.y) / reference.height, 0), 1)
        let size = CGFloat(Self.size(forSlider: value))
        if size != shownObjects[editedIndex].size {
            apply(.init(index: editedIndex, size: size), report: false)
        }
    }

    /// §9.1a parity: the lift reports the size once.
    private func endSliderDrag() {
        if let reference = sliderDrag, let editedIndex, draftSize != reference.startSize {
            apply(.init(index: editedIndex, size: draftSize))
        }
        sliderDrag = nil
        endSliderTouch()
    }

    /// §15.2: one ease-out, ≈ 250 ms, both ways; Reduce Motion cuts.
    private func setSliderDocked(_ docked: Bool) {
        withAnimation(reduceMotion ? nil : Self.sliderDockAnimation) { sliderDocked = docked }
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
        // §21.3: the scripture of a `bible` activity shows the Bible panel's values at once.
        let object = bibleStyled(object)
        // §21.2 (D28): a page-laid-out object stays at the frame the page gives it — it never
        // takes the edit slot, and keeps its verses and spans while its tools are open.
        let laidOut = object.pageLaidOut
        let isEdited = index == editedIndex
        // §20.2: the highlighting object takes the edit slot at full size, with its spans.
        let isSlotted = !laidOut && (isEdited || index == highlightingIndex)
        let isDrafted = isEdited && !laidOut
        // §20.1 (D11): a locked object takes no text input — editing it is tools only, no caret.
        let isLocked = object.isLocked
        return CanvasTextObject(
            text: object.text,
            onChange: { if isEdited && !isLocked { apply(.init(index: index, text: $0)) } },
            font: object.font,
            weight: object.weight,
            size: object.size,
            lineHeight: object.lineHeight,
            color: object.color,
            alignment: object.alignment,
            listStyle: isDrafted ? .none : object.listStyle,
            startNumber: isDrafted ? 1 : object.startNumber,
            verseNumbers: object.verseNumbers,
            animation: isEdited ? draftAnimation : .none,
            animationStart: isEdited ? draftAnimationStart : nil,
            effect: isEdited ? draftEffect : .none,
            // C-092 draws scale 1 and rotation 0 while editing (§3: re-opening shows the object at
            // `size`, unscaled); its committed transform returns on Done.
            transform: isSlotted ? .identity : object.transform,
            // §21.2 (D28): no handles, no drag, pinch or rotate — the host supplies the frame.
            pageLaidOut: laidOut,
            // §10.10: drag, pinch and rotate are the canvas-wide recognizers' (`CanvasManipulation`);
            // the object only says it is under the first touch.
            manipulation: .host,
            editing: isEdited && !isLocked,
            // §20.1 (D11): C-092 itself refuses text input on a locked object.
            isLocked: isLocked,
            // §20.2 (D21): the highlighting object takes C-092's hold-drag selection.
            isHighlighting: index == highlightingIndex,
            highlights: isDrafted ? [] : object.highlights,
            onHighlightRange: { start, end in onHighlightRange(index, start, end) },
            // D25: the object the finger-down grabbed — the topmost grab area may not be this box.
            onTap: {
                // D42: while the text editor is active the canvas owns every tap (tap-off).
                guard !isEditingText || index == highlightingIndex else { return }
                let target = tapTarget ?? index
                if target != editedIndex { tapObject(target) }
            },
            // §29.1 (D43): updated on every report; the edited object's draft layout is not kept.
            onTextBounds: { rect in if index != editedIndex { measuredGlyphRects[index] = rect } }
        )
        // D42: while the text editor is active only the edited object takes touches; a tap on any
        // other falls through to the canvas, which ends the edit.
        .allowsHitTesting(!isEditingText || isEdited || index == highlightingIndex)
        // §2 item 3 + §3 Editing: the edited object alone at the edit slot, centred on 478 wu
        // before C-091's offset; alignment anchors a narrower block 24 wu from the canvas edge
        // (tool 3). C-092 never offsets itself (its §2): the screen places a committed object at
        // `transform.position`.
        .frame(width: isDrafted ? draftLayoutWidth : object.transform.width ?? Self.editSlotWidth)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if index == editedIndex { measuredDraftHeight = height } else { measuredHeights[index] = height }
        }
        .ui2Element(index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)")
        .position(isDrafted ? CGPoint(x: draftCentreX, y: Self.editSlotY)
                  : isSlotted ? CGPoint(x: Self.referenceWidth / 2, y: Self.editSlotY)
                  : CGPoint(x: object.transform.position.x,
                            y: object.transform.position.y + (laidOut ? bibleVerticalShift : 0)))
        .zIndex(isSlotted ? 1 : 0)
        // §28 (D39): while one object is edited, every other object fades to 10 % so the edited
        // text reads over any page; it rides the same edit transition in and out.
        .opacity(editedIndex != nil && !isEdited ? Self.editDimOpacity : 1)
        // §13.2: Idle ↔ Editing is one animation — one ease-out for position, scale and rotation,
        // no delayed dispatch. A gesture frame never changes `editedIndex`, so it stays 1:1.
        .animation(Self.editTransition, value: editedIndex)
        .animation(Self.editTransition, value: highlightingIndex)
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
                guard let target = manipulationTarget, !isImageRailOpen else { return false }
                // §21.2 (D28): a page-laid-out object takes no drag, pinch or rotate.
                guard !shownObjects[target].pageLaidOut else { return false }
                // §10.10: while editing, two fingers pinch and rotate the edited object; it never moves.
                return kind != .move || editedIndex == nil
            },
            onUpdate: { manipulate($0, unit: unit, viewport: size.height / unit) },
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
            let shift = object.pageLaidOut ? bibleVerticalShift : 0
            return GrabArea(
                center: CGPoint(x: object.transform.position.x * unit,
                                y: (object.transform.position.y + shift + offset) * unit),
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
    private func manipulate(_ update: CanvasManipulation.Update, unit: CGFloat, viewport: CGFloat) {
        if update.phase == .ended {
            activeManipulations.remove(update.kind)
            guard activeManipulations.isEmpty else { return }
            dragExtent = nil
            // §18.7: guides draw only while active.
            snapEngaged = SnapEngaged()
            rotationEngaged = nil
            liveGuides = []
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
                // §18.2: the position snaps per axis; the snapped value is what the frame shows.
                next.position = snappedMove(CGPoint(x: moveBase.x + update.translation.width / unit,
                                                    y: moveBase.y + update.translation.height / unit),
                                            index: index, unit: unit, viewport: viewport)
            case .pinch:
                // §18.3: pinch never snaps.
                next.scale = scaleBase * update.scale
            case .rotate:
                // §18.3: the angle snaps to every 45° within 4°.
                let snapped = Self.snapRotation(rotationBase + update.rotation * 180 / .pi, engaged: rotationEngaged)
                if let angle = snapped.engaged, angle != rotationEngaged { Self.snapHaptic() }
                rotationEngaged = snapped.engaged
                next.rotation = .degrees(snapped.angle)
            }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) { emit(next, index: index) }
        case .ended:
            break
        }
    }

    // MARK: - §18 (D32, D33): snapping, wired

    /// §18.2: one move frame — the raw page position snapped in viewport wu, the guides and the
    /// engaged targets kept, the haptic fired on a new engage (§18.4). Returns page wu.
    private func snappedMove(_ raw: CGPoint, index: Int, unit: CGFloat, viewport: CGFloat) -> CGPoint {
        let offset = pageOffset(viewport: viewport)
        // §29.2: the dragged object's own extent is its glyph rect, whose centre sits `shift` from
        // the object's centre; snap that centre, then move the object by the same amount.
        let shift = glyphShift(index)
        let result = Self.snapPosition(
            CGPoint(x: raw.x + shift.dx, y: raw.y + offset + shift.dy),
            size: snapSize(index),
            rotation: shownObjects[index].transform.rotation,
            others: snapBoxes(excluding: index, offset: offset),
            viewport: viewport,
            pinnedAction: hasPinnedAction,
            unit: unit,
            engaged: snapEngaged
        )
        let gainedX = result.engaged.x != nil && result.engaged.x != snapEngaged.x
        let gainedY = result.engaged.y != nil && result.engaged.y != snapEngaged.y
        if gainedX || gainedY { Self.snapHaptic() }
        snapEngaged = result.engaged
        liveGuides = result.guides
        return CGPoint(x: result.position.x - shift.dx, y: result.position.y - offset - shift.dy)
    }

    /// §18.7: the guides C-091 draws — the live move's, else (a Manipulating preview) the seeded
    /// `snapIndex` object's at its position, plus the centre guide when `centerGuide` asks for it.
    private func canvasGuides(viewport: CGFloat, unit: CGFloat) -> [ActivityCanvasGuideSegment] {
        var guides = liveGuides
        if dragged == nil, mode == .manipulating, shownObjects.indices.contains(state.snapIndex) {
            let offset = pageOffset(viewport: viewport)
            let index = state.snapIndex
            let box = snapBox(index, offset: offset)
            guides = Self.snapPosition(
                CGPoint(x: box.midX, y: box.midY),
                size: snapSize(index),
                rotation: shownObjects[index].transform.rotation,
                others: snapBoxes(excluding: index, offset: offset),
                viewport: viewport,
                pinnedAction: hasPinnedAction,
                unit: unit,
                engaged: SnapEngaged()
            ).guides
        }
        if state.centerGuide, mode == .manipulating {
            let centre = Self.pageGuide(x: Snap.pageCentre, viewport: viewport)
            if !guides.contains(centre) { guides.append(centre) }
        }
        return guides
    }

    /// §18.7: C-091's reserved zones draw only while the dragged layer's box enters one.
    private func draggedEntersZone(viewport: CGFloat) -> Bool {
        let seeded = mode == .manipulating && shownObjects.indices.contains(state.snapIndex) ? state.snapIndex : nil
        guard let index = dragged?.index ?? seeded, shownObjects.indices.contains(index) else { return false }
        return Self.entersReservedZone(snapBox(index, offset: pageOffset(viewport: viewport)),
                                       viewport: viewport, pinnedAction: hasPinnedAction)
    }

    private var hasPinnedAction: Bool { actions.contains { $0.placement == .pinned } }

    /// An object's layout box as drawn, unscaled (wu).
    private func layoutSize(_ index: Int) -> CGSize {
        let object = shownObjects[index]
        return CGSize(width: object.transform.width ?? Self.editSlotWidth, height: objectHeight(object, index: index))
    }

    /// §29.1 + §29.3: the glyph rect in the layout box's space; the layout box itself while the
    /// object is not yet measured or its text is empty.
    private func glyphRect(_ index: Int) -> CGRect {
        let layout = CGRect(origin: .zero, size: layoutSize(index))
        guard !shownObjects[index].text.isEmpty, let rect = measuredGlyphRects[index],
              rect.width > 0, rect.height > 0 else { return layout }
        return rect
    }

    /// §29.2: the snap rectangle's size — the glyph rect scaled (wu), before rotation.
    private func snapSize(_ index: Int) -> CGSize {
        let scale = shownObjects[index].transform.scale
        let rect = glyphRect(index)
        return CGSize(width: rect.width * scale, height: rect.height * scale)
    }

    /// §29.2: where the snap rectangle's centre sits from the object's centre (the layout box's
    /// centre, which the object is drawn about), scaled and rotated (wu).
    private func glyphShift(_ index: Int) -> CGVector {
        let transform = shownObjects[index].transform
        let layout = layoutSize(index)
        let rect = glyphRect(index)
        let dx = (rect.midX - layout.width / 2) * transform.scale
        let dy = (rect.midY - layout.height / 2) * transform.scale
        let radians = transform.rotation.radians
        return CGVector(dx: dx * cos(radians) - dy * sin(radians), dy: dx * sin(radians) + dy * cos(radians))
    }

    /// §29.2: an object's snap rectangle — its glyph rect placed in its layout box, scaled and
    /// rotated about the object's centre — as a rotated bounding box in viewport wu.
    private func snapBox(_ index: Int, offset: CGFloat) -> CGRect {
        let position = shownObjects[index].transform.position
        let shift = glyphShift(index)
        return Self.rotatedBounds(center: CGPoint(x: position.x + shift.dx, y: position.y + offset + shift.dy),
                                  size: snapSize(index), rotation: shownObjects[index].transform.rotation)
    }

    /// §18.2: every other layer's box — the edited object (drawn at the edit slot) excluded.
    private func snapBoxes(excluding index: Int, offset: CGFloat) -> [CGRect] {
        shownObjects.indices.filter { $0 != index && $0 != editedIndex }.map { snapBox($0, offset: offset) }
    }

    /// §18.4: a light selection haptic on each engage.
    private static func snapHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
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

    /// §20.2: the index of the object `highlightingObjectID` names, while Highlighting; nil
    /// otherwise (a text activity never sets it).
    private var highlightingIndex: Int? {
        guard mode == .highlighting, let id = state.highlightingObjectID,
              let index = state.objectIDs.firstIndex(of: id), shownObjects.indices.contains(index) else { return nil }
        return index
    }

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
                toolbarTone: state.toolbarTone,                         // §27.2 (D38)
                onTap: onDeleteHighlight
            )
            .ui2Element("C-102 IconButton \(visibleTools.count + 1)")
            Spacer(minLength: 0)
            Button(label: Self.addNoteLabel, leadingGlyph: .addLargeCarbon, onTap: onAddNote)
                .colorMultiply(toneMultiply)                            // §27.3 (D38)
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
    /// choices) and the top rail (the pick's details). §15.1 (D29): the editing stack has no
    /// surface — the canvas shows through between controls, each of which carries its own blur;
    /// the Idle chips rail keeps `color-layout-background`. No hairlines; it rides the keyboard as
    /// one unit, so the tool row stays visible.
    private var railStack: some View {
        VStack(spacing: 0) {
            if isToolMode {
                topRail
                middleRail
                toolRow()
            } else {
                // §22.1 (D28 fix): on a bible activity in Idle the eight-tool row (§23.1) sits directly
                // above the chips rail, which stays; the rails open above the row (§10).
                if isBibleIdle {
                    topRail
                    middleRail
                    toolRow(aboveChips: true)
                }
                // C-081 §5: the editor passes `bottomInset: 16`, measured from the bar's position
                // before the inset (the chrome ignores the bottom safe area) — SPEC D11, D23.
                // §14.2: chips and ＋ only report; ＋ is disabled while the type grid shows.
                ActivityNavBar(slides: slides, activeID: state.activeID, bottomInset: Token.Space.pageMargin,
                               onSelectSlide: onSelectSlide,
                               addEnabled: state.canvasContent != "typeGrid", onAdd: onAdd)
                    .ui2Element("C-081 ActivityNavBar")
                    // §15.1 (D29): nothing opaque spans the width while editing; the chips rail is
                    // unchanged.
                    .background(Token.layoutBackground)
            }
        }
        // The stack states its own height; the canvas takes what is left (§2).
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .offset(y: -keyboardOverlap)
    }

    private var keyboardOverlap: CGFloat { max(containerBottom - keyboardTop, 0) }

    /// §10.1 middle rail — the open tool's choices.
    @ViewBuilder private var middleRail: some View {
        switch openTool {
        case .color where isBibleIdle:
            // §22.2: Colour in Idle acts on the scripture — the swatch matching `bibleColor`
            // (else the scripture's own) is outlined; a pick reports `.color`.
            TextColorPalette(
                currentColor: bibleScripture?.color ?? Token.textPrimary,
                swatches: Self.palettePages,
                page: palettePage,
                onSelect: { picked in
                    guard let hex = Self.presetHex(picked) else { return }
                    setBibleStyle(.color(hex))
                },
                onPageChange: { palettePage = $0 },
                onWellTap: onEyedropper,
                showsWell: state.showsEyedropper,
                swatchMaterial: true,
                toolbarTone: state.toolbarTone
            )
            .ui2Element("C-094 TextColorPalette")
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
                showsWell: state.showsEyedropper,
                // §15.1 (OQ-activities-editor-46): the blur behind each swatch.
                swatchMaterial: true,
                toolbarTone: state.toolbarTone
            )
            .ui2Element("C-094 TextColorPalette")
        case .font where isBibleIdle:
            // §21.3 (D29): the Bible font panel's face — the four font keys as C-035 `Font` chips,
            // centred (§19.3); the rest of the panel is the top rail.
            ChipStrip(items: Self.fontItems, selectedID: bibleStyle.face,
                      onSelect: { id in setBibleStyle(.face(id)) }, chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip 2")
        case .font where mode == .editing:
            // §3 tool 4: the font strip; its weight row is the top rail.
            ChipStrip(items: Self.fontItems, selectedID: Self.fontID(edited?.font ?? .sans),
                      onSelect: { id in
                          if let editedIndex { apply(.init(index: editedIndex, font: id)) }
                      }, chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip 2")
        case .animation where mode == .editing && state.showsEffectsTool:
            // §3 tool 6 (OQ-007): one combined strip — none, the animations, the effects.
            // C-106 has one `selectedID`, so it shows the animation when one is set, else the
            // effect (gap: two independent selections, one selected chip).
            ChipStrip(items: Self.animationItems, selectedID: animationSelectedID,
                      onSelect: selectAnimation, chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip")
        case .background:
            // §10.3: Gradient · Colour · Image; the selected option is derived.
            ChipStrip(items: Self.backgroundItems, selectedID: backgroundOption, onSelect: selectBackgroundOption,
                      chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip")
        case .actions:
            // §10.4: the page's actions, then + Add.
            ChipStrip(items: actionItems, selectedID: selectedActionID ?? "", onSelect: selectAction, chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip 3")
        case .alignment where isBibleIdle:
            // §23.2 (D33): Align opens ONE panel — horizontal, vertical, verse numbers.
            pinnedTopRail(maxHeight: Self.bibleAlignPanelMaxHeight) { bibleAlignPanel }
        case .size where isBibleIdle:
            // §23.4 (D33): Size is its own tool and opens its own slider.
            bibleSlider(label: "Size", value: \.size, range: Self.bibleSizeRange, step: Self.bibleSizeStep,
                        format: { "\(Int($0.rounded())) pt" }, change: BibleStyleChange.size)
        case .lineHeight where isBibleIdle:
            bibleSlider(label: "Line height", value: \.lineHeight, range: Self.bibleLineHeightRange,
                        step: Self.bibleLineHeightStep,
                        format: { String(format: "%.1f×", $0) }, change: BibleStyleChange.lineHeight)
        case .padding where isBibleIdle:
            bibleSlider(label: "Padding", value: \.inset, range: Self.bibleInsetRange, step: Self.bibleInsetStep,
                        format: { "\(Int($0.rounded())) pt" }, change: BibleStyleChange.inset)
        case .alignment where mode == .editing:
            alignmentRail(selected: draftAlignment, onSelect: selectAlignment)
        default:
            // Tool 5 has no rail.
            EmptyView()
        }
    }

    /// §3 tool 3 (D36): three C-102 IconButtons — align left, centre, right — centred (D34) 8pt
    /// above the tool row, each on the rail controls' blur (§15.1). The one matching
    /// `draftAlignment` is `selected`; a tap applies it at once and the rail stays open.
    private func alignmentRail(selected: CanvasTextObject.Alignment,
                               onSelect: @escaping (String) -> Void) -> some View {
        buttonRail(options: Self.alignmentOptions.map { ($0.code, $0.glyph, $0.label) },
                   selectedCode: Self.alignmentOptions.first { $0.alignment == selected }?.code ?? "",
                   element: "C-102 IconButton Align", onSelect: onSelect)
    }

    /// §3 tool 3 / §23.2: a centred row of C-102 IconButtons on the rail controls' blur; the one
    /// whose code is `selectedCode` is `selected`.
    private func buttonRail(options: [(code: String, glyph: GlyphName, label: String)],
                            selectedCode: String, element: String,
                            onSelect: @escaping (String) -> Void) -> some View {
        HStack(spacing: Token.Space.elementGap) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                IconButton(
                    glyph: option.glyph,
                    tone: .default,
                    style: .plain,
                    selected: selectedCode == option.code,
                    accessibilityLabel: option.label,
                    // §27.2 (D38): the rail's C-102s take the tone (selected: black fill in `.dark`).
                    toolbarTone: state.toolbarTone,
                    onTap: { onSelect(option.code) }
                )
                // FLAGGED LITERAL — activities-editor §2: 32pt tools, the tool row's tile.
                .frame(width: Self.toolSize, height: Self.toolSize)
                .padding(Self.toolRowPadding)
                .floatingControlMaterial(cornerRadius: Self.toolRowRadius)
                .ui2Element(index == 0 ? element : "\(element) \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Token.Space.elementGap)
    }

    /// §23.2 (D33): the Align panel, top → bottom — horizontal (C-102 ×3, `.alignment`), vertical
    /// (D32: C-102 ×3, `.verticalAlignment`) and verse numbers (D27: C-035 chips in a centred
    /// C-106, `.verseNumbers`). A tap applies at once; the panel stays open.
    private var bibleAlignPanel: some View {
        VStack(spacing: 0) {
            alignmentRail(selected: bibleScripture?.alignment ?? .left,
                          onSelect: { setBibleStyle(.alignment($0)) })
            buttonRail(options: Self.verticalAlignmentOptions,
                       selectedCode: Self.verticalAlignmentCode(bibleStyle.verticalAlignment),
                       element: "C-102 IconButton Vertical", onSelect: { setBibleStyle(.verticalAlignment($0)) })
            ChipStrip(items: Self.verseNumberItems, selectedID: bibleStyle.verseNumbers,
                      onSelect: { id in setBibleStyle(.verseNumbers(id)) }, chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip 3")
        }
    }

    /// §3 tool 3 (D36): one `ObjectEdit` with `alignment`, as the cycle did.
    private func selectAlignment(_ code: String) {
        guard let editedIndex else { return }
        apply(.init(index: editedIndex, alignment: code))
    }

    /// §10.1 top rail — the picked choice's details, only when it has some. Its height is pinned
    /// (§10.1): taller content scrolls inside it.
    @ViewBuilder private var topRail: some View {
        switch openTool {
        case .font where isBibleIdle:
            // §23.3 (D33): the Font panel is face + weight only — the weight chips above the face
            // strip, as the text activity's Font tool lays them out.
            ChipStrip(items: Self.weightItems, selectedID: Self.weightID(Self.weight(code: bibleStyle.weight)),
                      onSelect: { id in setBibleStyle(.weight(Self.weightCode(Self.weight(id)))) },
                      chipMaterial: true, toolbarTone: state.toolbarTone)
                .ui2Element("C-106 ChipStrip")
                .padding(.bottom, -Token.Space.elementGap)
        case .font where mode == .editing:
            // §3 tool 4: the weight row above the font strip. C-106 is 8 + 36 + 8 tall, so the
            // two share one 8pt inset and the pair stays §2's 96.
            ChipStrip(items: Self.weightItems, selectedID: Self.weightID(edited?.weight ?? .bold),
                      onSelect: { id in
                          if let editedIndex { apply(.init(index: editedIndex, weight: Self.weightCode(Self.weight(id)))) }
                      }, chipMaterial: true, toolbarTone: state.toolbarTone)
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
    private func pinnedTopRail<Content: View>(maxHeight: CGFloat = topRailMaxHeight,
                                              @ViewBuilder _ content: () -> Content) -> some View {
        let body = content()
        return ScrollViewReader { proxy in
            ViewThatFits(in: .vertical) {
                body
                ScrollView(.vertical) { body }
                    .scrollIndicators(.hidden)
            }
            .frame(maxHeight: maxHeight)
            .onChange(of: focusedField) { _, field in
                if let field { withAnimation { proxy.scrollTo(field) } }
            }
        }
    }

    // MARK: §23 (D33): the Bible panels

    /// §21.3 / §23.4: one undrawn-default slider row, docked above the tool row — the system
    /// `Slider` on the rails' blur material with its label and value. The display follows every frame; the value is reported once,
    /// when the finger lifts (§16).
    private func bibleSlider(label: String, value: WritableKeyPath<BibleStyle, CGFloat>,
                             range: ClosedRange<CGFloat>, step: CGFloat,
                             format: @escaping (CGFloat) -> String,
                             change: @escaping (CGFloat) -> BibleStyleChange) -> some View {
        HStack(spacing: Token.Space.elementGap) {
            SwiftUI.Text(verbatim: label)
                .designTextStyle(Token.TypeStyle.footnote)
                .foregroundStyle(toneInk ?? Token.textPrimary)          // §26.2 (D38)
            SwiftUI.Slider(
                value: Binding(get: { bibleStyle[keyPath: value] }, set: { bibleStyle[keyPath: value] = $0 }),
                in: range, step: step,
                onEditingChanged: { editing in
                    bibleSliding = editing
                    if !editing { onBibleStyleChange(change(bibleStyle[keyPath: value])) }
                }
            )
            .tint(toneInk ?? Token.white100)                                // §26.2 (D38)
            .accessibilityLabel(label)
            SwiftUI.Text(verbatim: format(bibleStyle[keyPath: value]))
                .designTextStyle(Token.TypeStyle.footnote)
                .foregroundStyle(toneInk ?? Token.textPrimary)          // §26.2 (D38)
                .monospacedDigit()
        }
        .padding(.horizontal, Token.Space.elementGap)
        .frame(height: Self.bibleSliderRowHeight)
        .floatingControlMaterial(cornerRadius: Token.Radius.card)
        .padding(.horizontal, Token.Space.pageMargin)
        .padding(.vertical, Token.Space.elementGap / 2)
        .ui2Element("Bible \(label.lowercased()) slider")
    }

    /// §21.4: a chip change applies to the display and is reported at once.
    private func setBibleStyle(_ change: BibleStyleChange) {
        switch change {
        case .face(let face): bibleStyle.face = face
        case .weight(let weight): bibleStyle.weight = weight
        case .size(let size): bibleStyle.size = size
        case .lineHeight(let lineHeight): bibleStyle.lineHeight = lineHeight
        case .inset(let inset): bibleStyle.inset = inset
        case .verseNumbers(let mode): bibleStyle.verseNumbers = mode
        case .color(let hex): bibleStyle.color = hex
        case .alignment(let code): bibleStyle.alignment = code
        case .verticalAlignment(let code): bibleStyle.verticalAlignment = code
        }
        onBibleStyleChange(change)
    }

    // MARK: §10.3 Background

    /// §10.3: Gradient — ↻ Shuffle then one chip per palette; Colour — C-094 swatches; Image —
    /// the library's thumbnails then "More…", and once an image is set the wash.
    @ViewBuilder private var backgroundDetails: some View {
        switch backgroundOption {
        case "gradient":
            HorizontalRail(showsIndicators: false) {
                HStack(spacing: Token.Space.elementGap) {
                    shuffleTile
                    ForEach(Array(state.palettes.enumerated()), id: \.offset) { index, palette in
                        paletteTile(palette, index: index)
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.vertical, Token.Space.elementGap)
                // §19.3 (D34.3): centred when it fits the width; leading-aligned and scrolling
                // when it overflows (C-106's rule).
                .frame(minWidth: gradientRailWidth, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gradientRailWidth = $0 }
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
                        }, toolbarTone: state.toolbarTone)                 // §27.2 (D38)
                        // §15.1: the blur behind "More…" (C-035's `radius-card`).
                        .floatingControlMaterial(cornerRadius: Token.Radius.card)
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
                                     showsWell: false,
                                     swatchMaterial: true,
                                     toolbarTone: state.toolbarTone)
                        .ui2Element("C-094 TextColorPalette 2")
                    // activities-editor §3 tool 2: undrawn default, the system slider (no registry row).
                    SwiftUI.Slider(value: Binding(get: { state.pageWashOpacity },
                                                  set: { onBackground(.wash(color: washHex, opacity: $0)) }),
                                   in: 0...1)
                        .tint(toneInk ?? Token.white100)                // §26.2 (D38)
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
                showsWell: false,
                // §15.1 (OQ-activities-editor-46): the blur behind each swatch.
                swatchMaterial: true,
                toolbarTone: state.toolbarTone
            )
            .ui2Element("C-094 TextColorPalette")
        }
    }

    /// §19.5 (D34.5): ↻ Shuffle as a 33×44 `radius-card` tile with the palette tiles' dark blur,
    /// its glyph centred — the palette tile's size, not C-102's 34×34 (a flagged literal tile; C-102
    /// is not used for it).
    private var shuffleTile: some View {
        SwiftUI.Button(action: { onBackground(.shuffle) }) {
            Image(GlyphName.refreshCw.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                // FLAGGED LITERAL — the 18pt glyph C-102 draws, in its default tone.
                .frame(width: Self.shuffleGlyph, height: Self.shuffleGlyph)
                .foregroundStyle(toneInk ?? Token.navText)              // §26.2 (D38)
                .accessibilityHidden(true)
                .frame(width: Self.paletteTileWidth, height: Self.paletteTileHeight)
                .contentShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(.plain)
        // §19.5: the same dark blur material as the palette tiles (§15.1).
        .floatingControlMaterial(cornerRadius: Token.Radius.card)
        .accessibilityLabel(Self.shuffleLabel)
        .ui2Element("Shuffle")
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
                        // §26.2 (D38): the selected outline keeps contrast on a light page.
                        .strokeBorder(toneInk ?? Token.white100, lineWidth: Self.hairline)
                }
            }
        }
        .buttonStyle(.plain)
        // §15.1: the blur behind each palette tile.
        .floatingControlMaterial(cornerRadius: Token.Radius.card)
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
        // §15.1: the blur behind each thumbnail.
        .floatingControlMaterial(cornerRadius: Token.Radius.card)
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
            }, chipMaterial: true, toolbarTone: state.toolbarTone)
            .ui2Element("C-106 ChipStrip")
            field("label", placeholder: "Label", text: action.label, kind: .single) { text in
                updateAction(action.id) { $0.label = text }
            }
            ChipStrip(items: Self.placementItems, selectedID: action.placement.rawValue, onSelect: { id in
                endField()
                setPlacement(PageAction.Placement(rawValue: id) ?? action.placement, of: action.id)
            }, chipMaterial: true, toolbarTone: state.toolbarTone)
            .ui2Element("C-106 ChipStrip 2")
            prefill(action)
            if !newActionIDs.contains(action.id) {
                Button(label: "Remove action", onTap: { remove(action.id) })
                    .colorMultiply(toneMultiply)                        // §27.3 (D38)
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
        // §27.3 (D38): C-045 takes no tone input — `.dark` multiplies its paint to `color-black`.
        .colorMultiply(toneMultiply)
        // §15.1: the blur behind each C-045 field (its box is `radius-card-sm`).
        .floatingControlMaterial(cornerRadius: Token.Radius.cardSm)
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
        // §23.1 (D33) / §24.3: a `bible` activity shows exactly its eight tools in Idle only;
        // `.editing` on a bible page keeps the text tools for the mode (§24.2).
        if isBibleToolSet { return Self.bibleTools }
        return Tool.allCases.filter { tool in
            switch tool {
            case .highlight: return state.showsHighlightTool
            case .animation: return state.showsEffectsTool
            case .size, .lineHeight, .padding: return false
            default: return true
            }
        }
    }

    /// §2 item 5: plain C-102 IconButtons the screen lays out itself (owner ruling 2026-10-10),
    /// 32pt, left to right. §15.1 (D29, supersedes the pitch layout): the visible tools sit in ONE
    /// container centred horizontally — 4pt padding, 8pt radius, 16pt gap, the dark blur material —
    /// hugging its contents; §19.1 (D34.1): the band hugs it too (40pt, 16pt above the keyboard).
    /// §22.1: `aboveChips` — the bible Idle row sits directly above the C-081 chips rail, one
    /// §19 element gap above it, instead of above the keyboard or the bottom safe area.
    private func toolRow(aboveChips: Bool = false) -> some View {
        // §23.1 (D33): a row wider than the screen (eight tools at 375) scrolls horizontally
        // under the rails — it never wraps.
        ViewThatFits(in: .horizontal) {
            toolRowContainer
            HorizontalRail(showsIndicators: false) { toolRowContainer }
        }
        .frame(maxWidth: .infinity)
        // §19.1 (D34.1): the row hugs its own 40pt band (4 + 32 + 4) — no longer C-081's bar
        // height; its bottom edge sits 16pt above the keyboard or the bottom safe area.
        .padding(.bottom, aboveChips ? Token.Space.elementGap
                                     : Token.Space.pageMargin + max(safeBottom - keyboardOverlap, 0))
    }

    private var toolRowContainer: some View {
        HStack(spacing: Self.toolRowGap) {
            ForEach(Array(visibleTools.enumerated()), id: \.element) { index, tool in
                IconButton(
                    glyph: Self.glyph(for: tool, isBible: isBibleToolSet),
                    tone: .default,
                    style: .plain,
                    selected: isSelected(tool),
                    accessibilityLabel: Self.toolLabel(tool),
                    // §27.2 (D38): C-102 paints the tone — `.dark` a `color-black` glyph, selected a
                    // black fill with a white glyph; `.light` is today's paint.
                    toolbarTone: state.toolbarTone,
                    onTap: { tap(tool) }
                )
                // FLAGGED LITERAL — activities-editor §2: 32pt tools.
                .frame(width: Self.toolSize, height: Self.toolSize)
                .ui2Element(index == 0 ? "C-102 IconButton" : "C-102 IconButton \(index + 1)")
            }
        }
        .padding(Self.toolRowPadding)
        .floatingControlMaterial(cornerRadius: Self.toolRowRadius)
        .ui2Element("Tool row")
    }

    /// §3 Tools: category tools (1, 2, 3, 4, 6, 7) take `selected` while their rails are open
    /// (D36: 3 is a category tool); 5 is selected while Highlighting is on.
    private func isSelected(_ tool: Tool) -> Bool {
        switch tool {
        case .highlight: return mode == .highlighting
        default: return openTool == tool
        }
    }

    private func tap(_ tool: Tool) {
        // D8: a tool tap ends a rail field, keeping its value.
        endField()
        switch tool {
        case .highlight:
            // §20.2: tool 5 again ends a locked object's highlighting mode.
            if highlightingIndex != nil { onEndHighlighting() } else { onToggleHighlight() }
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
        } else if point != nil, let tapTarget, tapTarget == editedIndex {
            // D25: a tap inside the edited object's grab area stays in the edit.
        } else if point != nil, let tapTarget, !isEditingText || tapTarget == highlightingIndex {
            // D25: in Idle a tap inside a grab area opens that object (D20); the object being
            // highlighted keeps its own taps.
            tapObject(tapTarget)
        } else if isEditingText {
            // D42: while the text editor is active nothing else on the canvas is tappable — a tap
            // on another object (a Bible passage included) is a tap-off, never that object's tap.
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

    /// §15.2 (round 8): a slider drag's touch-down reference — the finger's global y, the value
    /// it starts from, the track's on-screen height, and the size before the drag (for the lift).
    private struct SliderDrag {
        var startY: CGFloat
        var startValue: CGFloat
        var height: CGFloat
        var startSize: CGFloat
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
        /// §20.1 (D11).
        var isLocked = false
        /// §21.2 (D28): C-092 `pageLaidOut` — the page provides the frame.
        var pageLaidOut = false
        /// §21.3: C-092 `lineHeight` and `verseNumbers` — set only on a `bible` activity's
        /// scripture; otherwise C-092's defaults (natural leading, inline numbers).
        var lineHeight: CGFloat?
        var verseNumbers: CanvasTextObject.VerseNumbers = .inline

        var color: Color { ActivitiesEditorScreen.hexColor(colorHex) ?? Token.textPrimary }
    }

    /// §21.3 / §21.4: the Bible font panel's values as shown. Seeded from `State`.
    private struct BibleStyle: Equatable {
        var face: String
        var weight: Int
        var size: CGFloat
        var lineHeight: CGFloat
        var inset: CGFloat
        var verseNumbers: String
        /// §22.2: "" = the scripture object's own.
        var color: String
        var alignment: String
        /// §23.5 (D32).
        var verticalAlignment: String

        init(_ state: State) {
            face = state.bibleFace
            weight = state.bibleWeight
            size = state.bibleSize
            lineHeight = state.bibleLineHeight
            inset = state.bibleInset
            verseNumbers = state.bibleVerseNumbers
            color = state.bibleColor
            alignment = state.bibleAlignment
            verticalAlignment = state.bibleVerticalAlignment
        }
    }

    /// §21.3: on a `bible` activity the scripture — the `bibleVerse` object — draws with the
    /// panel's face, weight, size, line height and verse numbers; a page-laid-out scripture also
    /// takes the inset as its margin from each page edge. Every other object is unchanged.
    private func bibleStyled(_ object: CommittedObject) -> CommittedObject {
        guard state.isBible, object.listStyle == .bibleVerse else { return object }
        var styled = object
        styled.font = Self.font(bibleStyle.face)
        styled.weight = Self.weight(code: bibleStyle.weight)
        styled.size = bibleStyle.size
        styled.lineHeight = bibleStyle.lineHeight
        styled.verseNumbers = Self.verseNumbers(bibleStyle.verseNumbers)
        // §22.2: the Idle Colour and Alignment picks show at once; "" keeps the object's own.
        if !bibleStyle.color.isEmpty { styled.colorHex = bibleStyle.color }
        if let alignment = Self.alignmentOptions.first(where: { $0.code == bibleStyle.alignment }) {
            styled.alignment = alignment.alignment
        }
        if styled.pageLaidOut {
            styled.transform.width = Self.referenceWidth - 2 * bibleStyle.inset
        }
        return styled
    }

    /// §23.5 (D32): how far the page-laid-out block (scripture + citation) moves down from the
    /// container's top-at-96 frames — none for `top`, half the slack for `center`, all of it for
    /// `bottom`, where the slack is the room between the block's bottom and 96 wu above the 956
    /// page's bottom. A page taller than 956 has no slack.
    private var bibleVerticalShift: CGFloat {
        guard state.isBible, state.pageHeight <= Self.referenceHeight else { return 0 }
        let fraction: CGFloat
        switch Self.verticalAlignmentCode(bibleStyle.verticalAlignment) {
        case "center": fraction = 0.5
        case "bottom": fraction = 1
        default: return 0
        }
        var bottom = -CGFloat.infinity
        for (index, object) in shownObjects.enumerated() where object.pageLaidOut {
            let styled = bibleStyled(object)
            bottom = max(bottom, styled.transform.position.y + objectHeight(styled, index: index) / 2)
        }
        guard bottom.isFinite else { return 0 }
        return max(Self.referenceHeight - Self.bibleBlockInset - bottom, 0) * fraction
    }

    private static func verseNumbers(_ name: String) -> CanvasTextObject.VerseNumbers {
        switch name {
        case "hidden": return .hidden
        case "inline": return .inline
        default: return .gutter
        }
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
                highlights: highlights(state, forObject: index),
                isLocked: element(state.objectLocks, index, false),
                pageLaidOut: element(state.objectPageLaidOut, index, false)
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
        // §21.1 (D26): a tall page sits at page y 0 = viewport y 0 at rest (`tallPageExtent`).
        isTallPage ? 0 : (viewport - Self.referenceHeight) / 2
    }

    /// §21.1 (D26): the page is taller than the 956 reference — it scrolls inside the canvas.
    private var isTallPage: Bool { state.pageHeight > Self.referenceHeight }

    /// §21.1: the `contentExtent` that makes C-091's placement give exactly `pageHeight` with
    /// offset 0 — top at C-091's T, bottom `pageHeight` less its B (and the pinned band).
    private func tallPageExtent(pinned: Bool) -> ClosedRange<CGFloat> {
        let bottom = state.pageHeight - Self.canvasEndSpace - (pinned ? Self.pinnedHeight : 0)
        return Self.canvasTopInset...max(bottom, Self.canvasTopInset)
    }

    /// D42: the text editor is active (Editing, or Highlighting within an edit).
    private var isEditingText: Bool { mode == .editing || mode == .highlighting }

    /// §21.2: the edited object is page-laid-out — no C-093 wedge, no width handles.
    private var editedIsPageLaidOut: Bool { edited?.pageLaidOut ?? false }

    private var draftHeight: CGFloat {
        measuredDraftHeight ?? draftSize * Self.lineHeightFactor
    }

    // The edited object's style and width (§3 Editing), or the §3 defaults while none is.
    private var draftSize: CGFloat { edited?.size ?? CGFloat(Self.defaultSize) }
    private var draftAlignment: CanvasTextObject.Alignment { edited?.alignment ?? .center }
    private var draftLayoutWidth: CGFloat { edited?.transform.width ?? Self.editSlotWidth }

    /// §3 tool 3: the edit slot re-anchors 24 wu from the canvas edge.
    private var slotCentreX: CGFloat {
        switch draftAlignment {
        case .center: return Self.referenceWidth / 2
        case .left: return Self.editSlotInset + draftLayoutWidth / 2
        case .right: return Self.referenceWidth - Self.editSlotInset - draftLayoutWidth / 2
        }
    }

    /// §2 item 3 (D40, owner 2026-11-11): the width handles sit OUTSIDE the text box — the bar's
    /// inner edge `handleGap` from the text, never on a glyph. While the box's left handle would
    /// fall in the size-slider column, the edited block is nudged in just far enough to clear it
    /// (it returns to its own place on Done); when the block is too wide for both handles at the
    /// full gap, the gap shrinks (to 0 at the widest) instead of the handles touching the text.
    private var draftHandleLayout: (centreX: CGFloat, gap: CGFloat) {
        let width = draftLayoutWidth
        // Where the box edge may sit with a zero gap: the left bar (its full width) clears the
        // slider column, the right bar stays wholly on the canvas.
        let leftLimit = Self.sliderColumn + Self.handleBarWidth
        let rightLimit = Self.referenceWidth - Self.handleBarWidth
        let fullGap = Self.handleGap
        // The largest gap both handles can have with the block anywhere between the limits.
        let room = (rightLimit - leftLimit - width) / 2
        let gap = min(fullGap, max(room, 0))
        let minLeft = leftLimit + gap                     // the box's left edge may not go further left
        let maxLeft = rightLimit - gap - width            // nor its right edge further right
        let left = min(max(slotCentreX - width / 2, minLeft), max(maxLeft, minLeft))
        return (left + width / 2, gap)
    }

    /// The edited block's centre while editing — the slot, nudged per D40.
    private var draftCentreX: CGFloat { draftHandleLayout.centreX }

    private func widthHandles(pageOffset: CGFloat) -> ActivityCanvas<AnyView>.WidthHandles {
        let layout = draftHandleLayout
        let outset = layout.gap + Self.handleBarWidth / 2
        return .init(
            frame: CGRect(x: layout.centreX - draftLayoutWidth / 2 - outset,
                          y: Self.editSlotY + pageOffset - draftHeight / 2,
                          width: draftLayoutWidth + 2 * outset,
                          height: draftHeight),
            rotation: .zero
        )
    }

    /// §2 item 3: `onResizeWidth` reports the handles' span; the outset comes off, then clamps.
    private func resizeDraft(_ handleWidth: CGFloat) {
        guard let editedIndex else { return }
        let width = handleWidth - 2 * (draftHandleLayout.gap + Self.handleBarWidth / 2)
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

    /// §19.6 (D35): six pages of nine C-094 presets, each page light → dark, as (name, hex)
    /// pairs — the name is for accessibility only; a tap resolves to the hex, which is what
    /// `State` and `ObjectEdit` carry. Shared by the text colour, page colour and wash colour.
    /// Page 1 is today's nine in today's order (§1 deviation 5).
    // FLAGGED LITERAL — activities-editor §1 deviation 5 / §19.6: swatch hues, no colour token
    // (White and Black are `color-white-100` and `color-black`'s values).
    private static let swatchPresetPages: [[(name: String, hex: String)]] = [
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

    /// Every preset, in page order — a tap resolves against these (§9.2).
    private static let swatchPresets: [(name: String, hex: String)] = swatchPresetPages.flatMap { $0 }

    /// C-094 `swatches` (§19.6, D35; supersedes §17's one page): six pages, so C-097 draws six
    /// dots and the row pages. The outlined swatch is the one whose hex equals the current colour
    /// (§9.2); a colour not on the shown page outlines none there.
    private static let palettePages: [[TextColorPalette.NamedColor]] = swatchPresetPages.map { page in
        page.map { TextColorPalette.NamedColor(name: $0.name, color: hexColor($0.hex) ?? Token.textPrimary) }
    }

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
    /// carry, so `palette` stands in. §26.1 (D37): the Font tool draws the
    /// library's `text-font` (Figma 4800:11365) on text and bible activities alike.
    private static func glyph(for tool: Tool, isBible: Bool) -> GlyphName {
        switch tool {
        case .color: return .palette
        case .background: return .file
        case .alignment: return .menu
        case .font: return .textFont
        case .highlight: return .edit
        case .animation: return .sparkles
        case .actions: return .zap
        // §23.1 (D33): Figma 4800:11364's `text--scale`, `pan--vertical`, `pan--horizontal`.
        case .size: return .textScale
        case .lineHeight: return .panVertical
        case .padding: return .panHorizontal
        }
    }

    /// §3 tool 3 (D36): the alignment rail's buttons, left to right.
    private static let alignmentOptions: [(alignment: CanvasTextObject.Alignment, code: String,
                                           glyph: GlyphName, label: String)] = [
        (.left, "left", .textAlignStart, "Align left"),
        (.center, "center", .textAlignCenter, "Align centre"),
        (.right, "right", .textAlignEnd, "Align right")
    ]

    /// §23.2 (D32): the Align panel's vertical row, top to bottom — Figma 4800:11364's
    /// `align--vertical-top` · `-center` · `-bottom`.
    private static let verticalAlignmentOptions: [(code: String, glyph: GlyphName, label: String)] = [
        ("top", .alignVerticalTop, "Align top"),
        ("center", .alignVerticalCenter, "Align middle"),
        ("bottom", .alignVerticalBottom, "Align bottom")
    ]

    /// §23.5: a value other than the three reads as `top`.
    private static func verticalAlignmentCode(_ value: String) -> String {
        verticalAlignmentOptions.contains { $0.code == value } ? value : "top"
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
        case .size: return "Size"
        case .lineHeight: return "Line height"
        case .padding: return "Padding"
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
    /// FLAGGED LITERAL — activities-editor §15.1 (D29; no `material` token family): the tool-row
    /// container's 4pt padding, 8pt radius and 16pt gap.
    private static let toolRowPadding: CGFloat = 4
    private static let toolRowRadius: CGFloat = 8
    private static let toolRowGap: CGFloat = 16
    /// FLAGGED LITERAL — activities-editor §2: 32pt tools.
    private static let toolSize: CGFloat = 32
    /// GAP — activities-editor §2 item 2: the 1px hairline (also the palette chip's outline).
    private static let hairline: CGFloat = 1
    /// GAP — OQ-activities-editor-41 / 42: the palette chip 33×44 and the thumbnail 44×44.
    private static let paletteTileWidth: CGFloat = 33
    private static let paletteTileHeight: CGFloat = 44
    /// FLAGGED LITERAL — activities-editor §19.5: the Shuffle tile's 18pt glyph (C-102's size).
    private static let shuffleGlyph: CGFloat = 18
    private static let thumbnailSize: CGFloat = 44
    /// FLAGGED LITERAL — activities-editor §10.1: the top rail's pinned height — two C-106 rows
    /// (52 each) and a single-line C-045 (44), whole rows; the rest scrolls inside the rail.
    private static let topRailMaxHeight: CGFloat = 148
    /// §10.3: a canvas touch that moves less than this is a tap, not a focal drag.
    private static let tapSlop: CGFloat = 10
    /// §13.2 FLAGGED LITERAL — activities-editor §3 Transitions (no `motion-*` token holds it):
    /// the object between its transform and the edit slot, ease-out 150 ms, both directions.
    private static let editTransition = Animation.easeOut(duration: 0.15)
    /// FLAGGED LITERAL — §28 (D39, owner 2026-11-11): the other objects' opacity while one is edited.
    private static let editDimOpacity: Double = 0.1
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
    /// FLAGGED LITERAL — C-093 §2: the 20pt track (§15.2 docks it by half).
    private static let sliderWidth: CGFloat = 20
    /// FLAGGED LITERAL — activities-editor §15.2 (D30): docks after 2 s untouched, one ease-out
    /// ≈ 250 ms (no `motion-*` token holds either).
    private static let sliderDockDelay: Duration = .seconds(2)
    private static let sliderDockAnimation = Animation.easeOut(duration: 0.25)
    private static let sliderColumn: CGFloat = 38
    /// FLAGGED LITERAL — D40 (owner 2026-11-11): the gap between a width handle's bar and the text.
    private static let handleGap: CGFloat = 6
    /// C-091's width-handle bar width (`ActivityCanvas.handleSize.width`), mirrored for placement.
    private static let handleBarWidth: CGFloat = 6
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
    /// C-091 §2 Sizing T / B (§18.2's padding lines), which the tall page's extent is set from
    /// (§21.1) so C-091's placement yields `pageHeight`.
    private static var canvasTopInset: CGFloat { Snap.top }
    private static var canvasEndSpace: CGFloat { Snap.bottom }
    /// §21.3 (D29): the Bible font panel's sliders — size 14–40 pt step 1, line height 1.0–2.0×
    /// step 0.1, inset 16–64 pt step 4 (on the 440 reference).
    private static let bibleSizeRange: ClosedRange<CGFloat> = 14...40
    private static let bibleSizeStep: CGFloat = 1
    private static let bibleLineHeightRange: ClosedRange<CGFloat> = 1.0...2.0
    private static let bibleLineHeightStep: CGFloat = 0.1
    private static let bibleInsetRange: ClosedRange<CGFloat> = 16...64
    private static let bibleInsetStep: CGFloat = 4
    /// FLAGGED LITERAL — activities-editor §23.2: the Align panel's pinned height — two button
    /// rows (40 + 8 each) and the verse-numbers strip (52); a panel taller than the room left
    /// above the keyboard scrolls under the tool row.
    private static let bibleAlignPanelMaxHeight: CGFloat = 148
    /// §23.5 (D32): the page-laid-out block's 96 wu top and bottom insets on the 956 wu page.
    private static let bibleBlockInset: CGFloat = 96
    /// FLAGGED LITERAL — activities-editor §21.3: a slider row's 44pt height (undrawn default).
    private static let bibleSliderRowHeight: CGFloat = 44
    /// §21.3: the verse-number options, in order.
    private static let verseNumberItems: [ChipStrip.Item] = [
        .init(id: "gutter", label: "Gutter"),
        .init(id: "hidden", label: "Hidden"),
        .init(id: "inline", label: "Inline")
    ]
    /// §23.1 (D33): the eight tools of a `bible` activity, left to right — Animation, the effects
    /// tool and Actions hidden.
    private static let bibleTools: [Tool] = [.color, .background, .alignment, .font, .size, .lineHeight,
                                             .padding, .highlight]
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
    /// §18.8 snap-centre — a drag snapped to the page centre (x 220): its page guide.
    static let snapCentre: Self = {
        var s = committed(x: 220, y: 390)
        s.objectTexts = [snapSampleText]
        s.objectWidths = [280]
        s.objectHeights = [snapSampleHeight]
        s.editorMode = "manipulating"
        s.deleteTargetShown = true
        s.snapIndex = 0
        return s
    }()
    /// §18.8 snap-edge — the dragged layer (2) snapped to the other layer's left edge (x 60):
    /// the layer guide runs between the two.
    static let snapEdge: Self = {
        var s = twoLayers(first: (x: 180, y: 300, width: 240), second: (x: 160, y: 560, width: 200))
        // Left-aligned, so the text's left edge is the box's and the guide reads at the glyphs.
        s.objectAlignments = ["left", "left"]
        s.snapIndex = 1
        return s
    }()
    /// §18.8 snap-gap — the dragged layer (2) 24 wu below the other: the short gap guide.
    static let snapGap: Self = {
        let top: Double = 360
        var s = twoLayers(first: (x: 220, y: top, width: 240),
                          second: (x: 250, y: top + snapSampleHeight + 24, width: 200))
        s.snapIndex = 1
        return s
    }()

    /// §18.8: two committed one-line layers in Manipulating, for the edge and gap previews.
    private static func twoLayers(first: (x: Double, y: Double, width: Double),
                                  second: (x: Double, y: Double, width: Double)) -> Self {
        var s = base
        s.editorMode = "manipulating"
        s.deleteTargetShown = true
        s.objectTexts = [snapSampleText, snapSampleText]
        s.objectFonts = ["sans", "sans"]
        s.objectColors = [white, white]
        s.objectWeights = ["bold", "bold"]
        s.objectSizes = [38, 38]
        s.objectXs = [first.x, second.x]
        s.objectYs = [first.y, second.y]
        s.objectScales = [1, 1]
        s.objectRotations = [0, 0]
        s.objectWidths = [first.width, second.width]
        s.objectHeights = [snapSampleHeight, snapSampleHeight]
        return s
    }

    /// §18.8: a one-line sample, 38 × 1.25 = 47.5 wu tall.
    private static let snapSampleText = "Be still"
    private static let snapSampleHeight: Double = 47.5

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
    /// §20.4: a `bible` activity's starter document — the citation (14pt) over the scripture
    /// (serif 18pt, verses numbered 16–18), both locked.
    private static let bibleLocked: Self = {
        var s = base
        // §22.4 / §23.1: a bible activity — Idle shows the eight-tool row above the chips.
        s.isBible = true
        s.showsHighlightTool = true
        s.canSave = true
        s.objectIDs = ["citation", "scripture"]
        s.objectTexts = [
            "John 3:16b-18 ENGKJV",
            [
                "that whosoever believeth in him should not perish, but have everlasting life.",
                "For God sent not his Son into the world to condemn the world; but that the world through him might be saved.",
                "He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God."
            ].joined(separator: "\n")
        ]
        s.objectFonts = ["sans", "serif"]
        s.objectColors = [white, white]
        s.objectWeights = ["medium", "regular"]
        s.objectSizes = [14, 18]
        s.objectAlignments = ["left", "left"]
        s.objectListStyles = ["", "bibleVerse"]
        s.objectStartNumbers = [1, 16]
        s.objectXs = [220, 220]
        s.objectYs = [300, 470]
        s.objectScales = [1, 1]
        s.objectRotations = [0, 0]
        s.objectHeights = [17.5, 270]
        s.objectLocks = [true, true]
        return s
    }()
    /// §20.5 bible-idle-locked — Idle, both objects locked.
    static let bibleIdleLocked = bibleLocked
    /// §20.5 bible-highlighting — the scripture in highlighting mode, a range selected.
    static let bibleHighlighting: Self = {
        var s = bibleLocked
        s.editorMode = "highlighting"
        s.openTool = "highlight"
        s.highlightingObjectID = "scripture"
        s.highlightIDs = ["h1"]
        s.highlightObjects = [1]
        s.highlightStarts = [78]
        s.highlightEnds = [117]
        s.selectedHighlightID = "h1"
        return s
    }()
    /// §21.5 bible-tall — John 3:1–36 laid out by the page, the citation below verse 36, on a
    /// page that scrolls; the gradient fills the whole page. §21.5 says ≈ 2400: at serif 18 pt
    /// ×1.4 the 36 verses measure ≈ 2720 wu, so the page is 3000 to keep the citation on it.
    static let bibleTall: Self = {
        var s = base
        s.isBible = true
        s.showsHighlightTool = true
        s.canSave = true
        s.pageHeight = 3000
        s.gradient = sampleGradient
        s.pageColorHex = sampleGradient.base
        s.objectIDs = ["scripture", "citation"]
        s.objectTexts = [john3.joined(separator: "\n"), "John 3:1-36 KJV"]
        s.objectFonts = ["serif", "sans"]
        s.objectColors = [white, white]
        s.objectWeights = ["regular", "medium"]
        s.objectSizes = [18, 14]
        s.objectAlignments = ["left", "left"]
        s.objectListStyles = ["bibleVerse", ""]
        s.objectStartNumbers = [1, 1]
        s.objectXs = [220, 220]
        s.objectYs = [1480, 2880]
        s.objectScales = [1, 1]
        s.objectRotations = [0, 0]
        s.objectWidths = [392, 392]
        s.objectHeights = [2720, 17.5]
        s.objectLocks = [true, true]
        s.objectPageLaidOut = [true, true]
        return s
    }()
    /// §21.5 bible-style-panel — the Font tool open on a bible activity: the eight-tool row, the
    /// face strip and the weight chips (§23.3).
    static let bibleStylePanel: Self = {
        var s = bibleLocked
        s.isBible = true
        s.editorMode = "editing"
        s.editingIndex = 1
        s.openTool = "font"
        s.objectYs = [140, 300]
        s.objectWidths = [392, 392]
        s.objectPageLaidOut = [true, true]
        return s
    }()
    /// §22.4 bible-idle-style-panel — a bible activity in Idle with the Bible style panel open:
    /// no object selected, the eight-tool row above the chips rail.
    static let bibleIdleStylePanel: Self = {
        var s = bibleLocked
        s.openTool = "font"
        s.objectYs = [140, 300]
        s.objectWidths = [392, 392]
        s.objectPageLaidOut = [true, true]
        return s
    }()
    /// §23.7 bible-toolbar — Idle on a bible activity: the eight-tool row above the chips rail.
    static let bibleToolbar: Self = {
        var s = bibleLocked
        s.bibleColor = white
        s.bibleAlignment = "left"
        s.objectYs = [140, 300]
        s.objectWidths = [392, 392]
        s.objectPageLaidOut = [true, true]
        return s
    }()
    /// §25.4 toolbar-dark-on-light — a white solid page: the tool bar takes `.dark`.
    static let toolbarDarkOnLight: Self = {
        var s = bibleToolbar
        s.backgroundOption = "colour"
        s.gradient = nil
        s.pageColorHex = "#FFFFFF"
        s.objectColors = ["#000000", "#000000"]
        s.bibleColor = "#000000"
        s.toolbarTone = .dark
        return s
    }()
    /// §25.4 toolbar-light-on-dark — a dark solid page: the tool bar keeps `.light`.
    static let toolbarLightOnDark: Self = {
        var s = bibleToolbar
        s.backgroundOption = "colour"
        s.gradient = nil
        s.pageColorHex = "#141F6B"
        s.toolbarTone = .light
        return s
    }()
    /// §23.7 bible-align-panel — Align open in Idle: the horizontal, vertical and verse-number rows.
    static let bibleAlignPanel: Self = {
        var s = bibleToolbar
        s.openTool = "alignment"
        return s
    }()
    /// §23.7 bible-font-panel — Font open in Idle: the face strip and the weight chips only.
    static let bibleFontPanel: Self = {
        var s = bibleToolbar
        s.openTool = "font"
        return s
    }()
    /// §23.7 bible-size-slider — Size open in Idle: its slider docked above the tool row.
    static let bibleSizeSlider: Self = {
        var s = bibleToolbar
        s.openTool = "size"
        return s
    }()
    /// §23.7 bible-vertical-center — John 3:16 on a 956 page, the block (scripture over citation)
    /// centred between the 96 wu insets; the container's frames are the top-at-96 layout.
    static let bibleVerticalCenter: Self = {
        var s = bibleToolbar
        s.objectIDs = ["scripture", "citation"]
        s.objectTexts = [
            "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            "John 3:16 KJV"
        ]
        s.objectFonts = ["serif", "sans"]
        s.objectWeights = ["regular", "medium"]
        s.objectSizes = [18, 14]
        s.objectListStyles = ["bibleVerse", ""]
        s.objectStartNumbers = [16, 1]
        s.objectYs = [146, 229]
        s.objectHeights = [100, 17.5]
        s.bibleVerticalAlignment = "center"
        return s
    }()
    /// §24.4 bible-editing-caption — a bible activity in `.editing` on a caption the leader added:
    /// the text-activity tool row with the per-object alignment rail open (§24.2).
    static let bibleEditingCaption: Self = {
        var s = bibleToolbar
        s.editorMode = "editing"
        s.openTool = "alignment"
        s.editingIndex = 2
        s.objectIDs += ["caption"]
        s.objectTexts += ["Read it slowly"]
        s.objectFonts += ["sans"]
        s.objectColors += [white]
        s.objectWeights += ["bold"]
        s.objectSizes += [24]
        s.objectAlignments += ["center"]
        s.objectListStyles += [""]
        s.objectStartNumbers += [1]
        s.objectXs += [220]
        s.objectYs += [640]
        s.objectScales += [1]
        s.objectRotations += [0]
        s.objectWidths += [392]
        s.objectHeights += [30]
        s.objectLocks += [false]
        s.objectPageLaidOut += [false]
        return s
    }()
    /// §21.5: John 3:1–36 (KJV), one verse per line.
    private static let john3: [String] = [
        "There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:",
        "The same came to Jesus by night, and said unto him, Rabbi, we know that thou art a teacher come from God: for no man can do these miracles that thou doest, except God be with him.",
        "Jesus answered and said unto him, Verily, verily, I say unto thee, Except a man be born again, he cannot see the kingdom of God.",
        "Nicodemus saith unto him, How can a man be born when he is old? can he enter the second time into his mother's womb, and be born?",
        "Jesus answered, Verily, verily, I say unto thee, Except a man be born of water and of the Spirit, he cannot enter into the kingdom of God.",
        "That which is born of the flesh is flesh; and that which is born of the Spirit is spirit.",
        "Marvel not that I said unto thee, Ye must be born again.",
        "The wind bloweth where it listeth, and thou hearest the sound thereof, but canst not tell whence it cometh, and whither it goeth: so is every one that is born of the Spirit.",
        "Nicodemus answered and said unto him, How can these things be?",
        "Jesus answered and said unto him, Art thou a master of Israel, and knowest not these things?",
        "Verily, verily, I say unto thee, We speak that we do know, and testify that we have seen; and ye receive not our witness.",
        "If I have told you earthly things, and ye believe not, how shall ye believe, if I tell you of heavenly things?",
        "And no man hath ascended up to heaven, but he that came down from heaven, even the Son of man which is in heaven.",
        "And as Moses lifted up the serpent in the wilderness, even so must the Son of man be lifted up:",
        "That whosoever believeth in him should not perish, but have eternal life.",
        "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
        "For God sent not his Son into the world to condemn the world; but that the world through him might be saved.",
        "He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God.",
        "And this is the condemnation, that light is come into the world, and men loved darkness rather than light, because their deeds were evil.",
        "For every one that doeth evil hateth the light, neither cometh to the light, lest his deeds should be reproved.",
        "But he that doeth truth cometh to the light, that his deeds may be made manifest, that they are wrought in God.",
        "After these things came Jesus and his disciples into the land of Judaea; and there he tarried with them, and baptized.",
        "And John also was baptizing in Aenon near to Salim, because there was much water there: and they came, and were baptized.",
        "For John was not yet cast into prison.",
        "Then there arose a question between some of John's disciples and the Jews about purifying.",
        "And they came unto John, and said unto him, Rabbi, he that was with thee beyond Jordan, to whom thou barest witness, behold, the same baptizeth, and all men come to him.",
        "John answered and said, A man can receive nothing, except it be given him from heaven.",
        "Ye yourselves bear me witness, that I said, I am not the Christ, but that I am sent before him.",
        "He that hath the bride is the bridegroom: but the friend of the bridegroom, which standeth and heareth him, rejoiceth greatly because of the bridegroom's voice: this my joy therefore is fulfilled.",
        "He must increase, but I must decrease.",
        "He that cometh from above is above all: he that is of the earth is earthly, and speaketh of the earth: he that cometh from heaven is above all.",
        "And what he hath seen and heard, that he testifieth; and no man receiveth his testimony.",
        "He that hath received his testimony hath set to his seal that God is true.",
        "For he whom God hath sent speaketh the words of God: for God giveth not the Spirit by measure unto him.",
        "The Father loveth the Son, and hath given all things into his hand.",
        "He that believeth on the Son hath everlasting life: and he that believeth not the Son shall not see life; but the wrath of God abideth on him."
    ]
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
    /// §15.3 editing-rails-gradient (D29) — editing over a gradient page with the font tool open:
    /// the weight and font rails and the tool-row container float with no rail background.
    static let editingRailsGradient: Self = {
        var s = pageRail("font", option: "gradient")
        s.objectTexts = [sampleText]
        return s
    }()
    /// §15.3 slider-docked (D30) — editing, C-093 docked: only its right half shows at the
    /// screen's left edge.
    static let sliderDocked: Self = {
        var s = editing(sampleText, tool: "font")
        s.sliderDocked = true
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

#Preview("Snap centre") {
    ActivitiesEditorScreen(state: .snapCentre)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Snap edge") {
    ActivitiesEditorScreen(state: .snapEdge)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Snap gap") {
    ActivitiesEditorScreen(state: .snapGap)
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

#Preview("Bible idle locked") {
    ActivitiesEditorScreen(state: .bibleIdleLocked)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible highlighting") {
    ActivitiesEditorScreen(state: .bibleHighlighting)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible tall") {
    ActivitiesEditorScreen(state: .bibleTall)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible style panel") {
    ActivitiesEditorScreen(state: .bibleStylePanel)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible idle style panel") {
    ActivitiesEditorScreen(state: .bibleIdleStylePanel)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible toolbar") {
    ActivitiesEditorScreen(state: .bibleToolbar)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Toolbar dark on light") {
    ActivitiesEditorScreen(state: .toolbarDarkOnLight)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Toolbar light on dark") {
    ActivitiesEditorScreen(state: .toolbarLightOnDark)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible align panel") {
    ActivitiesEditorScreen(state: .bibleAlignPanel)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible font panel") {
    ActivitiesEditorScreen(state: .bibleFontPanel)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible size slider") {
    ActivitiesEditorScreen(state: .bibleSizeSlider)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible vertical center") {
    ActivitiesEditorScreen(state: .bibleVerticalCenter)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Bible editing caption") {
    ActivitiesEditorScreen(state: .bibleEditingCaption)
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

#Preview("Editing rails gradient") {
    ActivitiesEditorScreen(state: .editingRailsGradient)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

#Preview("Slider docked") {
    ActivitiesEditorScreen(state: .sliderDocked)
        .safeAreaPadding(.top, 59)
        .frame(width: 440, height: 956, alignment: .top)
}

// MARK: - §15.1 (D29): the floating controls' material

private extension View {
    /// §15.1: the blur material behind one floating control (or the tool-row container),
    /// blurring the canvas behind it. FLAGGED LITERAL — the system ultra-thin material; no
    /// `material` token family exists. §26.3 (D38): tone `.dark` → the LIGHT material (dark glyphs
    /// on a light blur); `.light` → today's dark one. The scheme is scoped to the material only.
    func floatingControlMaterial(cornerRadius: CGFloat) -> some View {
        modifier(FloatingControlMaterial(cornerRadius: cornerRadius))
    }
}

private struct FloatingControlMaterial: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.editorToolbarTone) private var tone

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, tone == .dark ? .light : .dark)
        }
    }
}

private extension EnvironmentValues {
    /// §26.3 (D38): the screen's `toolbarTone`, for the floating controls' backing.
    @Entry var editorToolbarTone: ToolbarTone = .light
}

// MARK: - §18 (D32, D33): snapping — pure static functions

extension ActivitiesEditorScreen {
    /// §18.1: the constants, in one place. The pure functions and the guides read these only.
    enum Snap {
        /// FLAGGED LITERAL — §18.1: the standard padding and gap, wu.
        static let padding: CGFloat = 24
        static let gap: CGFloat = 24
        /// FLAGGED LITERAL — §18.1: engage within 8 pt on screen, release 12 pt past (hysteresis).
        static let engage: CGFloat = 8
        static let release: CGFloat = 12
        /// FLAGGED LITERAL — §18.3: every multiple of 45°, within 4°.
        static let rotationStep: Double = 45
        static let rotationWindow: Double = 4
        /// GAP — §18.3: "the window plus hysteresis", no value stated; position's 8 → 12 ratio.
        static let rotationRelease: Double = 6
        /// FLAGGED LITERAL — §18.2: the padding lines T 107 and viewport − B, B 85 (110 pinned).
        static let top: CGFloat = 107
        static let bottom: CGFloat = 85
        static let bottomPinned: CGFloat = 110
        /// §18.2: the page vertical centre, x 220 wu.
        static let pageCentre: CGFloat = 220
        /// FLAGGED LITERAL — C-091 §2 layer 6 (01 §8): the rail zone, 23 × 88, right edge 28 from
        /// the screen's right, centred at 81 % of the viewport — for the §18.7 zone test only.
        static let railSize = CGSize(width: 23, height: 88)
        static let railRightInset: CGFloat = 28
        static let railHeightFraction: CGFloat = 0.81
    }

    /// §18.2: what a target is — the page centre, a padding line, another layer's edge or centre
    /// line, or the standard gap to another layer (by its index in `others`).
    enum SnapSource: Hashable {
        case pageCentre
        case padding
        case layer(Int)
        case gap(Int)
    }

    /// §18.2: the dragged layer's line tested — left/top, centre, right/bottom.
    enum SnapAnchor: Hashable {
        case leading
        case centre
        case trailing
    }

    /// One engaged target on one axis: its source, the dragged anchor and the value (viewport wu).
    struct SnapTarget: Hashable {
        var source: SnapSource
        var anchor: SnapAnchor
        var value: CGFloat
    }

    /// §18.6: the engaged target per axis, carried frame to frame for hysteresis.
    struct SnapEngaged: Hashable {
        var x: SnapTarget?
        var y: SnapTarget?
    }

    /// §18.6: `snapPosition`'s answer — the snapped centre (viewport wu), the active guide
    /// segments and the new `engaged`.
    struct SnapResult: Equatable {
        var position: CGPoint
        var guides: [ActivityCanvasGuideSegment]
        var engaged: SnapEngaged
    }

    /// The axis-aligned box of a `size` box rotated by `rotation` about `center`.
    static func rotatedBounds(center: CGPoint, size: CGSize, rotation: Angle) -> CGRect {
        let radians = rotation.radians
        let width = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
        let height = abs(size.width * sin(radians)) + abs(size.height * cos(radians))
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    /// §18.2 + §18.6: snaps a moved layer's centre per axis, independently, to the nearest target
    /// within `Snap.engage` pt; an engaged target holds until the touch is `Snap.release` pt past
    /// it. All lengths are viewport wu; `unit` is points per wu (for the on-screen distances);
    /// `size` is the layer's scaled box before `rotation`; `others` the other layers' rotated
    /// boxes. No UIKit, no haptic, no state: the caller fires the haptic when `engaged` gains one.
    static func snapPosition(
        _ position: CGPoint,
        size: CGSize,
        rotation: Angle,
        others: [CGRect],
        viewport: CGFloat,
        pinnedAction: Bool,
        unit: CGFloat,
        engaged: SnapEngaged
    ) -> SnapResult {
        let extent = rotatedBounds(center: .zero, size: size, rotation: rotation).size
        let bottom = viewport - (pinnedAction ? Snap.bottomPinned : Snap.bottom)
        let anchors: [SnapAnchor] = [.leading, .centre, .trailing]
        func every(_ source: SnapSource, _ value: CGFloat) -> [SnapTarget] {
            anchors.map { SnapTarget(source: source, anchor: $0, value: value) }
        }
        var xTargets = every(.pageCentre, Snap.pageCentre)
            + every(.padding, Snap.padding) + every(.padding, referenceWidth - Snap.padding)
        var yTargets = every(.padding, Snap.top) + every(.padding, bottom)
        for (index, box) in others.enumerated() {
            xTargets += every(.layer(index), box.minX) + every(.layer(index), box.midX) + every(.layer(index), box.maxX)
            yTargets += every(.layer(index), box.minY) + every(.layer(index), box.midY) + every(.layer(index), box.maxY)
            // §18.2: the standard gap — 24 wu below or above the other layer.
            yTargets.append(SnapTarget(source: .gap(index), anchor: .leading, value: box.maxY + Snap.gap))
            yTargets.append(SnapTarget(source: .gap(index), anchor: .trailing, value: box.minY - Snap.gap))
        }
        let engageDistance = Snap.engage / unit
        let releaseDistance = Snap.release / unit
        func snapAxis(_ centre: CGFloat, extent: CGFloat, targets: [SnapTarget],
                      engaged: SnapTarget?) -> (value: CGFloat, engaged: SnapTarget?) {
            func shift(_ anchor: SnapAnchor) -> CGFloat {
                switch anchor {
                case .leading: return -extent / 2
                case .centre: return 0
                case .trailing: return extent / 2
                }
            }
            if let engaged, targets.contains(engaged),
               abs(centre + shift(engaged.anchor) - engaged.value) <= releaseDistance {
                return (engaged.value - shift(engaged.anchor), engaged)
            }
            var best: (distance: CGFloat, target: SnapTarget)?
            for target in targets {
                let distance = abs(centre + shift(target.anchor) - target.value)
                if distance <= engageDistance, distance < (best?.distance ?? .infinity) {
                    best = (distance, target)
                }
            }
            guard let target = best?.target else { return (centre, nil) }
            return (target.value - shift(target.anchor), target)
        }
        let x = snapAxis(position.x, extent: extent.width, targets: xTargets, engaged: engaged.x)
        let y = snapAxis(position.y, extent: extent.height, targets: yTargets, engaged: engaged.y)
        let snapped = CGPoint(x: x.value, y: y.value)
        let box = CGRect(x: snapped.x - extent.width / 2, y: snapped.y - extent.height / 2,
                         width: extent.width, height: extent.height)
        var guides: [ActivityCanvasGuideSegment] = []
        if let target = x.engaged {
            switch target.source {
            case .layer(let index):
                // §18.7: a layer guide runs between the two layers.
                let other = others[index]
                guides.append(.init(from: CGPoint(x: target.value, y: min(box.minY, other.minY)),
                                    to: CGPoint(x: target.value, y: max(box.maxY, other.maxY))))
            default:
                guides.append(pageGuide(x: target.value, viewport: viewport))
            }
        }
        if let target = y.engaged {
            switch target.source {
            case .layer(let index):
                let other = others[index]
                guides.append(.init(from: CGPoint(x: min(box.minX, other.minX), y: target.value),
                                    to: CGPoint(x: max(box.maxX, other.maxX), y: target.value)))
            case .gap(let index):
                // §18.7: a gap guide is a short segment across the gap, where the boxes overlap.
                let other = others[index]
                let low = max(box.minX, other.minX)
                let high = min(box.maxX, other.maxX)
                let lineX = low <= high ? (low + high) / 2 : box.midX
                let from = target.anchor == .leading ? other.maxY : box.maxY
                let to = target.anchor == .leading ? box.minY : other.minY
                guides.append(.init(from: CGPoint(x: lineX, y: from), to: CGPoint(x: lineX, y: to)))
            default:
                guides.append(.init(from: CGPoint(x: 0, y: target.value),
                                    to: CGPoint(x: referenceWidth, y: target.value)))
            }
        }
        return SnapResult(position: snapped, guides: guides, engaged: SnapEngaged(x: x.engaged, y: y.engaged))
    }

    /// §18.3 + §18.6: snaps a raw angle (degrees) to the nearest multiple of 45° within 4°; the
    /// engaged multiple holds until the raw angle leaves it by more than `Snap.rotationRelease`.
    /// Returns the angle to draw and the new engaged multiple (nil = none).
    static func snapRotation(_ degrees: Double, engaged: Double?) -> (angle: Double, engaged: Double?) {
        if let engaged, abs(degrees - engaged) <= Snap.rotationRelease { return (engaged, engaged) }
        let nearest = (degrees / Snap.rotationStep).rounded() * Snap.rotationStep
        if abs(degrees - nearest) <= Snap.rotationWindow { return (nearest, nearest) }
        return (degrees, nil)
    }

    /// §18.7: a page guide spans the canvas — a vertical line at `x`, viewport wu.
    static func pageGuide(x: CGFloat, viewport: CGFloat) -> ActivityCanvasGuideSegment {
        .init(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: viewport))
    }

    /// §18.7: does a box (viewport wu) enter C-091's reserved zones — the top chrome, the rail,
    /// the end space or the pinned band?
    static func entersReservedZone(_ box: CGRect, viewport: CGFloat, pinnedAction: Bool) -> Bool {
        let bottom = viewport - (pinnedAction ? Snap.bottomPinned : Snap.bottom)
        let zones = [
            CGRect(x: 0, y: 0, width: referenceWidth, height: Snap.top),
            CGRect(x: referenceWidth - Snap.railRightInset - Snap.railSize.width,
                   y: viewport * Snap.railHeightFraction - Snap.railSize.height / 2,
                   width: Snap.railSize.width, height: Snap.railSize.height),
            CGRect(x: 0, y: bottom, width: referenceWidth, height: viewport - bottom)
        ]
        return zones.contains { $0.intersects(box) }
    }
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
