//
//  ActivitiesPlayerScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen activities-player in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/lesson-versions/:id
//  (API-GAP: specified by docs/features/text-activity/SPEC.md §Contract, not yet on the server).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Activity viewer — the leader's stitched lesson stack (§1): every activity of a lesson as one
/// full-screen page, stacked in lesson order with no gap, under a fixed rail and chrome.
///
/// Pure (§3, R-01, R-04, R-19): the screen holds no position. The engine in
/// `MakeReady/UI2/Viewer` passes `anchor`, `drag`, `inner[]`, the active page and the rail values
/// every frame, and the screen draws them. No gesture and no ScrollView of its own (D69): only a
/// control that claims its touch by 01 §5 takes one.
///
/// §2 Units: page content is in width units, `u = viewportWidth / 440`; C-091 scales its page by
/// `u`. C-133, C-134, C-135, C-136, C-137 and C-138 are fixed points by their own contracts; C-139
/// takes `u` as its `unit`.
///
/// Composed only of §4's C-133 ActivityRail, C-134 ViewerChrome, C-135 VideoPage, C-136
/// ViewerEndPage, C-137 ActionSheetPreview, C-138 InlineActionRow, C-139 PinnedActionPill, C-091
/// ActivityCanvas (viewer mode), C-092 CanvasTextObject (viewer mode) and C-045 TextInput.
/// Standalone: `identifiedFrom` is null, so no D7 template applies.
struct ActivitiesPlayerScreen: View {

    /// One §3 state's inputs (§5 "Screen input, by value"). Every §3 state is reachable by these
    /// alone. Per-page values are parallel arrays over `pageIndexes`; objects and actions name
    /// their page by its position in those arrays. A short array takes the default.
    struct State {
        // MARK: The stack (01 §4)

        /// Pages in the lesson (C-133 `pageCount`; "Activity n of N").
        var pageCount: Int
        /// The lesson index of the page the stack rests on or drags away from.
        var anchor: Int
        /// Points; positive moves toward the next page. 0 at rest.
        var drag: Double
        /// C-133 `activePage` — the page on the viewport's midline; C-133 `morphProgress`.
        var activePage: Int
        var morphProgress: Double
        /// C-133 `thumbFraction` — `inner / maxInner` on the active page; nil = a solid capsule.
        var thumbFraction: Double?
        /// C-133 `visible` — held by the host per 01 §8; the screen applies no delay.
        var railVisible: Bool
        /// C-134 `topAction` from the active page's `chrome.topAction`: `share` · `menu` · `none`.
        var topAction: String
        /// The host's safe-area insets (C-134 `topInset`; C-135, C-136, C-137 `bottomInset`).
        var topInset: CGFloat
        var bottomInset: CGFloat

        // MARK: Pages (02 §2, §8)

        /// Each given page's lesson index. Only the anchor and its neighbours are drawn (01 §2).
        var pageIndexes: [Int]
        /// `canvas` · `video` · `youtube` · `write` · `end` · `fallback` (§2 Page types).
        var pageKinds: [String]
        /// Each page's own scroll, wu: C-091 `scrollOffset` (D69). 0 on a page that does not scroll.
        var inner: [Double]
        /// `background` (02 §5): colour #rrggbb, image URL ("" = none), focal 0–1, wash #rrggbb
        /// ("" = none) and its opacity. `motion` is not carried: C-091 never draws it (deviation 9).
        var pageColorHexes: [String]
        var pageImageURLs: [String]
        var pageImageFocalXs: [Double]
        var pageImageFocalYs: [Double]
        var pageWashHexes: [String]
        var pageWashOpacities: [Double]
        /// `background.gradient` (text-activity-v2 D1, D12): each page's blob gradient, C-091's
        /// type, passed through uninterpreted. nil (or past the end) = no gradient, today's look.
        var pageGradients: [ActivityCanvas<AnyView>.Background.Gradient?] = []
        /// `content.verticalAnchor`: `center` · `top`.
        var pageVerticalAnchors: [String]
        /// `end`: the lesson title. `fallback`: `fallback.title`.
        var pageTitles: [String]
        /// `fallback`: `fallback.body`.
        var pageBodies: [String]
        /// `write`: `content.placeholder`, the disabled field's placeholder.
        var pagePlaceholders: [String]
        /// `video` (C-135 §4): the current cue's lines, presenter, reference, remaining time,
        /// position 0–1, playing and buffering.
        var pageCaptionLines: [[String]]
        var pagePresenterNames: [String]
        var pagePresenterImageURLs: [String]
        var pagePresenterInitials: [String]
        var pageReferences: [String]
        var pageRemainingTimes: [String]
        var pageProgresses: [Double]
        var pagePlaying: [Bool]
        var pageBuffering: [Bool]

        // MARK: Text objects (02 §3) — every C-092, `mode=viewer`

        /// The page each object is on (a position in `pageIndexes`). A `write` page's prompt is
        /// its one object.
        var objectPages: [Int]
        var objectTexts: [String]
        /// Font key (02 §6): `display` · `sans` · `serif` · `mono`; unknown is `sans`.
        var objectFonts: [String]
        /// #rrggbb.
        var objectColors: [String]
        /// `regular` · `medium` · `bold`.
        var objectWeights: [String]
        /// Size in wu.
        var objectSizes: [Double]
        /// `left` · `center` · `right`.
        var objectAlignments: [String]
        /// `none` · `solidDark` · `solidLight`.
        var objectLabels: [String]
        /// `none` · `bullet` · `numbered` · `bibleVerse`, and the first number.
        var objectListStyles: [String]
        var objectStartNumbers: [Int]
        /// `none` · `typewriter` · `pop` · `jump`, and whether it loops; `none` · `sparkle` ·
        /// `neon` · `shimmer` · `pixel`.
        var objectAnimations: [String]
        var objectAnimationLoops: [Bool]
        var objectEffects: [String]
        /// `transform`: centre in wu, scale, rotation in degrees, layout width in wu.
        var objectXs: [Double]
        var objectYs: [Double]
        var objectScales: [Double]
        var objectRotations: [Double]
        var objectWidths: [Double]
        /// Each object's measured height in wu, seeding `contentExtent`: a capture renders in one
        /// layout pass, before the screen's own measurement lands. Live, the measurement wins.
        var objectHeights: [Double]
        /// `marks` (02 §3), UTF-16 offsets: object index, range, `bold` · `italic` · `link`, href.
        var markObjects: [Int]
        var markStarts: [Int]
        var markEnds: [Int]
        var markKinds: [String]
        var markHrefs: [String]
        /// `highlights` (02 §3): object index and UTF-16 range.
        var highlightObjects: [Int]
        var highlightStarts: [Int]
        var highlightEnds: [Int]

        // MARK: Actions (02 §7, D70)

        /// The page each action is on, its id, kind (`addToPrayerList` · `write` · `openUrl` ·
        /// `nextLesson`), label, placement (`inline` · `pinned`) and value (`openUrl`'s URL).
        var actionPages: [Int]
        var actionIDs: [String]
        var actionKinds: [String]
        var actionLabels: [String]
        var actionPlacements: [String]
        var actionValues: [String]

        // MARK: The sheet (01 §10)

        /// C-137 `kind` — `addToPrayerList` · `write`; "" = no sheet. Then its draft.
        var sheetKind: String
        var sheetTitle: String
        var sheetBodyText: String
        var sheetPrompt: String

        /// C-092 `animationStart` for the active page: the host's date, nil at rest (§3).
        var animationStart: Date?

        /// §3 Load failed: the container could not load the activity — the header and close only
        /// (C-134 `close`, no top action), no pages, no rail; `onLoadFailed`, then `onClose` after 2 s.
        var loadFailed: Bool = false
    }

    let state: State
    /// §2 `video`: the host's player in C-135's slot, per lesson index.
    let videoSlot: (Int) -> AnyView
    /// §2 `youtube`: the host's YouTube player in the page's slot, per lesson index.
    let youtubeSlot: (Int) -> AnyView
    /// §3 Taps (R-03): C-134 or C-136 Close.
    let onClose: () -> Void
    /// OQ-004: shown per the document, inert in this build.
    let onShare: () -> Void
    let onMenu: () -> Void
    /// An `addToPrayerList` or `write` action: its id. The host sets `sheet`.
    let onOpenSheet: (String) -> Void
    /// An `openUrl` action (OQ-005): its URL.
    let onOpenURL: (String) -> Void
    /// A link mark in C-092: its href.
    let onOpenLink: (String) -> Void
    /// C-135's callbacks, by lesson index.
    let onVideoProgressChange: (Int, Double) -> Void
    let onVideoScrubbingChange: (Int, Bool) -> Void
    let onVideoPlayingChange: (Int, Bool) -> Void
    /// C-137's close and draft edits; the host discards the draft on close (§3 Sheet).
    let onCloseSheet: () -> Void
    let onSheetTitleChange: (String) -> Void
    let onSheetBodyTextChange: (String) -> Void
    /// §3 Load failed: the container raises the error banner with this message.
    let onLoadFailed: (String) -> Void

    // §2 Canvas placement: "the screen measures the objects' rotated, scaled box" — C-091
    // `contentExtent`, measured per object index. Ephemeral layout feedback (R-31).
    @SwiftUI.State private var measuredHeights: [Int: CGFloat] = [:]

    init(
        state: State,
        videoSlot: @escaping (Int) -> AnyView = { _ in Self.slotStandIn },
        youtubeSlot: @escaping (Int) -> AnyView = { _ in Self.slotStandIn },
        onClose: @escaping () -> Void = {},
        onShare: @escaping () -> Void = {},
        onMenu: @escaping () -> Void = {},
        onOpenSheet: @escaping (String) -> Void = { _ in },
        onOpenURL: @escaping (String) -> Void = { _ in },
        onOpenLink: @escaping (String) -> Void = { _ in },
        onVideoProgressChange: @escaping (Int, Double) -> Void = { _, _ in },
        onVideoScrubbingChange: @escaping (Int, Bool) -> Void = { _, _ in },
        onVideoPlayingChange: @escaping (Int, Bool) -> Void = { _, _ in },
        onCloseSheet: @escaping () -> Void = {},
        onSheetTitleChange: @escaping (String) -> Void = { _ in },
        onSheetBodyTextChange: @escaping (String) -> Void = { _ in },
        onLoadFailed: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.videoSlot = videoSlot
        self.youtubeSlot = youtubeSlot
        self.onClose = onClose
        self.onShare = onShare
        self.onMenu = onMenu
        self.onOpenSheet = onOpenSheet
        self.onOpenURL = onOpenURL
        self.onOpenLink = onOpenLink
        self.onVideoProgressChange = onVideoProgressChange
        self.onVideoScrubbingChange = onVideoScrubbingChange
        self.onVideoPlayingChange = onVideoPlayingChange
        self.onCloseSheet = onCloseSheet
        self.onSheetTitleChange = onSheetTitleChange
        self.onSheetBodyTextChange = onSheetBodyTextChange
        self.onLoadFailed = onLoadFailed
    }

    /// The host's player is not this screen's (§2): until the host supplies one, the slot shows
    /// the activity slide placeholder.
    static var slotStandIn: AnyView { AnyView(Token.activitySlidePlaceholder) }

    var body: some View {
        if state.loadFailed {
            loadFailedPage
        } else {
            playerPage
        }
    }

    /// §3 Load failed (mirrors activities-editor §9.4): C-134 with close only over the ground, no
    /// pages, no rail. The banner is raised through `onLoadFailed`; 2 s later `onClose` leaves. The
    /// wait is cancelled with the task when the state ends first.
    private var loadFailedPage: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Token.layoutBackground
                    .frame(width: proxy.size.width, height: proxy.size.height)
                ViewerChrome(
                    topAction: ViewerChrome.TopAction.none,
                    topInset: state.topInset,
                    onClose: onClose,
                    onShare: onShare,
                    onMenu: onMenu
                )
                .ui2Element("C-134 ViewerChrome")
                .frame(width: proxy.size.width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .task {
            onLoadFailed(Self.loadFailedMessage)
            try? await Task.sleep(for: Self.loadFailedDelay)
            guard !Task.isCancelled else { return }
            onClose()
        }
    }

    private var playerPage: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let unit = width / Self.referenceWidth
            let pages = self.pages

            // §2 Layers, back to front: pages → C-133 → C-134 → the sheet's dim → C-137.
            ZStack(alignment: .topLeading) {
                ForEach(pages.filter { abs($0.index - state.anchor) <= 1 }, id: \.index) { page in
                    pageView(page, unit: unit, width: width, height: height)
                        .frame(width: width, height: height)
                        .clipped()
                        // §2 The stack: the anchor's top at −drag, a neighbour one viewport away.
                        .offset(y: CGFloat(page.index - state.anchor) * height - CGFloat(state.drag))
                        // §3 Accessibility: "Activity n of N", mounted pages only, lesson order.
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Activity \(page.index + 1) of \(state.pageCount)")
                        .accessibilitySortPriority(Double(-page.index))
                }

                ActivityRail(
                    pageCount: state.pageCount,
                    activePage: state.activePage,
                    morphProgress: state.morphProgress,
                    thumbFraction: state.thumbFraction,
                    visible: state.railVisible
                )
                .ui2Element("C-133 ActivityRail")
                // FLAGGED LITERAL — activities-player §2 (C-133 §2): right edge 28 from the
                // screen's right, vertical centre at 81 % of its height; the pill is 23 wide.
                .position(x: width - Self.railRightInset - Self.railWidth / 2,
                          y: height * Self.railHeightFraction)

                ViewerChrome(
                    topAction: ViewerChrome.TopAction(rawValue: state.topAction) ?? ViewerChrome.TopAction.none,
                    topInset: state.topInset,
                    onClose: onClose,
                    onShare: onShare,
                    onMenu: onMenu
                )
                .ui2Element("C-134 ViewerChrome")
                .frame(width: width)

                if let kind = ActionSheetPreview.Kind(rawValue: state.sheetKind) {
                    // FLAGGED LITERAL — activities-player §2: the sheet's dim 0.5 (`color-black-50`).
                    Token.black50
                        .frame(width: width, height: height)
                        .accessibilityHidden(true)

                    ActionSheetPreview(
                        kind: kind,
                        title: state.sheetTitle,
                        bodyText: state.sheetBodyText,
                        prompt: state.sheetPrompt,
                        bottomInset: state.bottomInset,
                        onClose: onCloseSheet,
                        onTitleChange: onSheetTitleChange,
                        onBodyTextChange: onSheetBodyTextChange
                    )
                    .ui2Element("C-137 ActionSheetPreview")
                    // FLAGGED LITERAL — activities-player §2 (C-137 §2): top edge `topInset` + 13,
                    // filling to the screen's bottom.
                    .frame(width: width, height: height - state.topInset - Self.sheetBelowInset)
                    .offset(y: state.topInset + Self.sheetBelowInset)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
    }

    // MARK: - Pages (§2 Page types)

    @ViewBuilder
    private func pageView(_ page: Page, unit: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        switch page.kind {
        case .canvas, .write:
            canvasPage(page, unit: unit)
        case .video:
            VideoPage(
                video: { videoSlot(page.index) },
                captionLines: page.video.captionLines,
                presenterName: page.video.presenterName,
                presenterImageURL: URL(string: page.video.presenterImageURL),
                presenterInitials: page.video.presenterInitials.isEmpty ? nil : page.video.presenterInitials,
                reference: page.video.reference,
                remainingTime: page.video.remainingTime,
                progress: page.video.progress,
                playing: page.video.playing,
                buffering: page.video.buffering,
                bottomInset: state.bottomInset,
                onProgressChange: { onVideoProgressChange(page.index, $0) },
                onScrubbingChange: { onVideoScrubbingChange(page.index, $0) },
                onPlayingChange: { onVideoPlayingChange(page.index, $0) }
            )
            .ui2Element("C-135 VideoPage")
        case .youtube:
            // §2 `youtube`: `color-black-100` ground and the host's player filling the page; its
            // controls and captions are YouTube's (02 §8). No C-135.
            ZStack {
                Token.black100
                youtubeSlot(page.index)
            }
        case .end:
            ViewerEndPage(title: page.title, bottomInset: state.bottomInset, onClose: onClose)
                .ui2Element("C-136 ViewerEndPage")
        case .fallback:
            fallbackPage(page)
        }
    }

    /// `canvas` and `write`: C-091 in viewer mode with `scrollOffset` = `inner`, the document's
    /// objects as C-092, the inline rows in the content, and the pinned pill over the window.
    private func canvasPage(_ page: Page, unit: CGFloat) -> some View {
        let layout = contentLayout(page, unit: unit)
        let pinned = page.actions.first { $0.placement == .pinned }
        return ActivityCanvas<AnyView>(
            background: page.background,
            mode: .viewer,
            content: { AnyView(canvasContent(page, layout: layout, unit: unit)) },
            verticalAnchor: page.verticalAnchor,
            contentExtent: layout.extent,
            pinnedAction: pinned != nil,
            scrollOffset: CGFloat(page.inner)
        )
        .ui2Element(canvasName(page))
        .overlay(alignment: .bottom) {
            if let pinned {
                // §2 Pinned: 408u wide (16 wu inset), bottom edge 30 above the safe bottom. It
                // stays put while the content scrolls and moves with the page.
                PinnedActionPill(label: pinned.label, unit: unit, onTap: { tap(pinned) })
                    .ui2Element("C-139 PinnedActionPill")
                    // FLAGGED LITERAL — activities-player §2: the pill's 16 wu inset.
                    .padding(.horizontal, Self.pinnedInset * unit)
                    // FLAGGED LITERAL — activities-player §2 (01 §10): 30 above the safe bottom.
                    .padding(.bottom, state.bottomInset + Self.pinnedAboveSafeBottom)
            }
        }
    }

    /// C-091's slot, in wu: the objects at their transforms, the write field, then the inline rows.
    private func canvasContent(_ page: Page, layout: ContentLayout, unit: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(page.objects, id: \.index) { object in
                textObject(object)
                    .frame(width: object.transform.width ?? Self.slotWidth)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeights[object.index] = $0 }
                    .ui2Element(objectName(object))
                    // §3 Accessibility: reading order top to bottom by `y`, then array order.
                    .accessibilitySortPriority(Double(-object.transform.position.y))
                    // C-092 never offsets itself: the screen places it at `transform.position`.
                    .position(object.transform.position)
            }

            if page.kind == .write, let fieldTop = layout.writeFieldTop {
                writeField(page)
                    .offset(x: (Self.referenceWidth - Self.writeFieldWidth) / 2, y: fieldTop)
            }

            ForEach(Array(layout.inlineTops.enumerated()), id: \.offset) { position, top in
                let action = page.inlineActions[position]
                // §2 Inline: C-138 is 44 pt tall in fixed points, so it is laid out in points and
                // scaled back out of the canvas's `u`; its content is centred on the page's width.
                InlineActionRow(label: action.label, onTap: { tap(action) })
                    .ui2Element(position == 0 ? "C-138 InlineActionRow" : "C-138 InlineActionRow \(position + 1)")
                    .frame(width: Self.referenceWidth * unit, height: Self.inlineRowHeight)
                    .scaleEffect(1 / unit, anchor: .topLeading)
                    .frame(width: Self.referenceWidth, height: Self.inlineRowHeight / unit, alignment: .topLeading)
                    .offset(y: top)
            }
        }
        .frame(width: Self.referenceWidth, alignment: .topLeading)
    }

    private func textObject(_ object: TextObject) -> CanvasTextObject {
        CanvasTextObject(
            text: object.text,
            mode: .viewer,
            font: object.font,
            weight: object.weight,
            size: object.size,
            color: object.color,
            alignment: object.alignment,
            label: object.label,
            listStyle: object.listStyle,
            startNumber: object.startNumber,
            marks: object.marks,
            animation: object.animation,
            animationStart: state.animationStart,
            effect: object.effect,
            transform: object.transform,
            editing: false,
            highlights: object.highlights,
            onOpenLink: onOpenLink
        )
    }

    /// §2 `write` (OQ-006): C-045 `kind=multi`, disabled, 392 × 120 wu, and "Preview" in
    /// `type-caption`, `color-text-secondary`, 8 wu under the field.
    private func writeField(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: Self.writeCaptionGap) {
            TextInput(
                text: "",
                placeholder: page.placeholder,
                kind: .multi,
                focused: false,
                editing: TextInput.Editing(isEnabled: false)
            )
            .ui2Element("C-045 TextInput")
            // FLAGGED LITERAL — activities-player §2: the write field's 392 × 120 wu.
            .frame(width: Self.writeFieldWidth, height: Self.writeFieldHeight, alignment: .topLeading)

            Text("Preview")
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .ui2Element("Preview")
        }
        .frame(width: Self.writeFieldWidth, alignment: .topLeading)
    }

    /// §2 `fallback`: C-091 with `background.color` only, and the title and body centred on the
    /// viewport as C-092 `font=sans`, 392 wu wide.
    private func fallbackPage(_ page: Page) -> some View {
        let start = fallbackObjectIndex(page)
        return ActivityCanvas<AnyView>(
            background: .init(color: page.background.color),
            mode: .viewer,
            content: {
                AnyView(
                    VStack(spacing: Self.fallbackGap) {
                        // FLAGGED LITERAL — activities-player §2: title weight 700, size 24.
                        fallbackText(page.title, weight: .bold, size: Self.fallbackTitleSize)
                            .ui2Element(objectName(index: start))
                        // FLAGGED LITERAL — activities-player §2: body weight 400, size 16.
                        fallbackText(page.body, weight: .regular, size: Self.fallbackBodySize)
                            .ui2Element(objectName(index: start + 1))
                    }
                    .frame(width: Self.slotWidth)
                    // With no extent the page is the viewport, and C-091's offset centres the
                    // reference canvas on it: its middle is the viewport's.
                    .position(x: Self.referenceWidth / 2, y: Self.referenceHeight / 2)
                )
            },
            verticalAnchor: .center
        )
        .ui2Element(canvasName(page))
    }

    private func fallbackText(_ text: String, weight: CanvasTextObject.Weight, size: CGFloat) -> CanvasTextObject {
        CanvasTextObject(text: text, mode: .viewer, font: .sans, weight: weight, size: size,
                         alignment: .center, editing: false)
    }

    // MARK: - §2 Canvas placement and actions

    private struct ContentLayout {
        /// C-091 `contentExtent`, wu; nil = nothing on the page.
        var extent: ClosedRange<CGFloat>?
        /// The write group's top, wu.
        var writeFieldTop: CGFloat?
        /// Each inline row's frame top, wu.
        var inlineTops: [CGFloat]
    }

    /// The objects' rotated, scaled box, then the write group 24 wu under the prompt, then the
    /// inline rows (deviation 12: they count in the extent).
    private func contentLayout(_ page: Page, unit: CGFloat) -> ContentLayout {
        var top = CGFloat.infinity
        var bottom = -CGFloat.infinity
        for object in page.objects {
            let radians = object.transform.rotation.radians
            let width = (object.transform.width ?? Self.slotWidth) * object.transform.scale
            let height = (measuredHeights[object.index] ?? object.seedHeight) * object.transform.scale
            let half = (abs(width * sin(radians)) + abs(height * cos(radians))) / 2
            top = min(top, object.transform.position.y - half)
            bottom = max(bottom, object.transform.position.y + half)
        }
        var layout = ContentLayout(extent: nil, writeFieldTop: nil, inlineTops: [])
        if page.kind == .write {
            let fieldTop = top <= bottom ? bottom + Self.writeFieldGap : Self.referenceHeight / 2
            layout.writeFieldTop = fieldTop
            top = min(top, fieldTop)
            bottom = fieldTop + Self.writeFieldHeight + Self.writeCaptionGap + Self.captionLineHeight
        }
        guard top <= bottom else { return layout }
        // §2 Inline: 58 wu to the glyph's top, so the frame's top is 10 pt above it (OQ-C-138-001);
        // further rows 24 wu apart, frame to frame.
        var rowTop = bottom + Self.inlineGap - Self.inlineGlyphInset / unit
        for _ in page.inlineActions {
            layout.inlineTops.append(rowTop)
            bottom = rowTop + Self.inlineRowHeight / unit
            rowTop = bottom + Self.inlinePitch
        }
        layout.extent = top...bottom
        return layout
    }

    /// §3 Taps: the sheet kinds open the sheet, `openUrl` its link, `nextLesson` is inert (OQ-005).
    private func tap(_ action: Action) {
        switch action.kind {
        case .addToPrayerList, .write: onOpenSheet(action.id)
        case .openUrl: onOpenURL(action.value)
        case .nextLesson: break
        }
    }

    // MARK: - Part names (D11)

    private func canvasName(_ page: Page) -> String {
        let canvases = pages.filter { abs($0.index - state.anchor) <= 1 && $0.kind.drawsCanvas }
        let position = canvases.firstIndex { $0.index == page.index } ?? 0
        return position == 0 ? "C-091 ActivityCanvas" : "C-091 ActivityCanvas \(position + 1)"
    }

    private func objectName(_ object: TextObject) -> String { objectName(index: object.index) }

    private func objectName(index: Int) -> String {
        index == 0 ? "C-092 CanvasTextObject" : "C-092 CanvasTextObject \(index + 1)"
    }

    /// A fallback page's two texts are numbered after the document's objects.
    private func fallbackObjectIndex(_ page: Page) -> Int {
        state.objectTexts.count + pages.filter { $0.kind == .fallback && $0.position < page.position }.count * 2
    }

    // MARK: - §2 literals

    /// 02 §4: the 440 × 956 reference canvas, and the 392 wu slot (24 wu each side).
    private static let referenceWidth: CGFloat = 440
    /// §3 Load failed: the banner's copy, and FLAGGED LITERAL — the 2 s wait before `onClose`.
    private static let loadFailedMessage = "Couldn't load this activity."
    private static let loadFailedDelay = Duration.seconds(2)
    private static let referenceHeight: CGFloat = 956
    private static let slotWidth: CGFloat = 392
    /// FLAGGED LITERAL — activities-player §2 (C-133 §2): rail geometry.
    private static let railWidth: CGFloat = 23
    private static let railRightInset: CGFloat = 28
    private static let railHeightFraction: CGFloat = 0.81
    /// FLAGGED LITERAL — activities-player §2 (C-137 §2): the sheet's top edge, `topInset` + 13.
    private static let sheetBelowInset: CGFloat = 13
    /// FLAGGED LITERAL — activities-player §2: the pill's 16 wu inset and 30 above the safe bottom.
    private static let pinnedInset: CGFloat = 16
    private static let pinnedAboveSafeBottom: CGFloat = 30
    /// FLAGGED LITERAL — activities-player §2 (D70, OQ-C-138-001): inline gap 58 wu to the glyph,
    /// whose top is 10 pt inside C-138's 44 pt frame; stack pitch 24 wu.
    private static let inlineGap: CGFloat = 58
    private static let inlineGlyphInset: CGFloat = 10
    private static let inlineRowHeight: CGFloat = 44
    private static let inlinePitch: CGFloat = 24
    /// FLAGGED LITERAL — activities-player §2 (OQ-006): the write field 392 × 120 wu, 24 wu under
    /// the prompt, its caption 8 wu under it.
    private static let writeFieldWidth: CGFloat = 392
    private static let writeFieldHeight: CGFloat = 120
    private static let writeFieldGap: CGFloat = 24
    private static let writeCaptionGap: CGFloat = 8
    private static var captionLineHeight: CGFloat {
        Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size
    }
    /// FLAGGED LITERAL — activities-player §2: fallback sizes 24 and 16, 16 wu apart.
    private static let fallbackTitleSize: CGFloat = 24
    private static let fallbackBodySize: CGFloat = 16
    private static let fallbackGap: CGFloat = 16
    /// GAP — activities-player §2: an object not yet measured counts one line per item at this
    /// multiple of its size (the editor's figure); the measurement replaces it.
    private static let lineHeightFactor: CGFloat = 1.25
}

// MARK: - The page model, decoded from State

extension ActivitiesPlayerScreen {
    fileprivate enum Kind: String {
        case canvas, video, youtube, write, end, fallback

        var drawsCanvas: Bool { self == .canvas || self == .write || self == .fallback }
    }

    fileprivate struct Video {
        var captionLines: [String]
        var presenterName: String
        var presenterImageURL: String
        var presenterInitials: String
        var reference: String
        var remainingTime: String
        var progress: Double
        var playing: Bool
        var buffering: Bool
    }

    fileprivate struct TextObject {
        var index: Int
        var text: String
        var font: CanvasTextObject.Font
        var weight: CanvasTextObject.Weight
        var size: CGFloat
        var color: Color
        var alignment: CanvasTextObject.Alignment
        var label: CanvasTextObject.Label
        var listStyle: CanvasTextObject.ListStyle
        var startNumber: Int
        var marks: [CanvasTextObject.Mark]
        var highlights: [CanvasTextObject.TextRange]
        var animation: CanvasTextObject.Animation
        var effect: CanvasTextObject.Effect
        var transform: CanvasTextObject.Transform
        var seedHeight: CGFloat
    }

    fileprivate struct Action {
        enum Kind: String { case addToPrayerList, write, openUrl, nextLesson }
        enum Placement: String { case inline, pinned }

        var id: String
        var kind: Kind
        var label: String
        var placement: Placement
        var value: String
    }

    fileprivate struct Page {
        /// The position in `pageIndexes`, and the lesson index.
        var position: Int
        var index: Int
        var kind: Kind
        var inner: Double
        var background: ActivityCanvas<AnyView>.Background
        var verticalAnchor: ActivityCanvas<AnyView>.VerticalAnchor
        var title: String
        var body: String
        var placeholder: String
        var video: Video
        var objects: [TextObject]
        var actions: [Action]

        var inlineActions: [Action] { actions.filter { $0.placement == .inline } }
    }

    private static func value<T>(_ array: [T], _ index: Int, _ fallback: T) -> T {
        array.indices.contains(index) ? array[index] : fallback
    }

    /// 02 §9: an unknown kind is a `fallback` page, and a `poll` is one too (deviation 14).
    private var pages: [Page] {
        state.pageIndexes.enumerated().map { position, index in
            let v = { (array: [String]) in Self.value(array, position, "") }
            return Page(
                position: position,
                index: index,
                kind: Kind(rawValue: v(state.pageKinds)) ?? .fallback,
                inner: Self.value(state.inner, position, 0),
                background: pageBackground(position),
                verticalAnchor: v(state.pageVerticalAnchors) == "top" ? .top : .center,
                title: v(state.pageTitles),
                body: v(state.pageBodies),
                placeholder: v(state.pagePlaceholders),
                video: Video(
                    captionLines: Self.value(state.pageCaptionLines, position, []),
                    presenterName: v(state.pagePresenterNames),
                    presenterImageURL: v(state.pagePresenterImageURLs),
                    presenterInitials: v(state.pagePresenterInitials),
                    reference: v(state.pageReferences),
                    remainingTime: v(state.pageRemainingTimes),
                    progress: Self.value(state.pageProgresses, position, 0),
                    playing: Self.value(state.pagePlaying, position, false),
                    buffering: Self.value(state.pageBuffering, position, false)
                ),
                objects: state.objectTexts.indices
                    .filter { Self.value(state.objectPages, $0, 0) == position }
                    .map(decodedObject),
                // 02 §9: an unknown action kind is not drawn.
                actions: state.actionIDs.indices
                    .filter { Self.value(state.actionPages, $0, 0) == position }
                    .compactMap(action)
            )
        }
    }

    private func pageBackground(_ position: Int) -> ActivityCanvas<AnyView>.Background {
        let image = URL(string: Self.value(state.pageImageURLs, position, "")).map {
            ActivityCanvas<AnyView>.Background.Image(
                imageURL: $0,
                focal: CGPoint(x: Self.value(state.pageImageFocalXs, position, 0.5),
                               y: Self.value(state.pageImageFocalYs, position, 0.5))
            )
        }
        let wash = Self.hexColor(Self.value(state.pageWashHexes, position, "")).map {
            ActivityCanvas<AnyView>.Background.Wash(color: $0, opacity: Self.value(state.pageWashOpacities, position, 0))
        }
        return .init(
            // The document always carries a colour (02 §5); a missing one is the 2.0 page ground.
            color: Self.hexColor(Self.value(state.pageColorHexes, position, "")) ?? Token.layoutBackground,
            gradient: Self.value(state.pageGradients, position, nil),
            image: image,
            wash: wash
        )
    }

    private func decodedObject(_ index: Int) -> TextObject {
        let size = CGFloat(Self.value(state.objectSizes, index, 24))
        let text = state.objectTexts[index]
        let lines = CGFloat(text.split(separator: "\n", omittingEmptySubsequences: false).count)
        let width = Self.value(state.objectWidths, index, 0)
        let measured = Self.value(state.objectHeights, index, 0)
        return TextObject(
            index: index,
            text: text,
            font: Self.font(Self.value(state.objectFonts, index, "sans")),
            weight: Self.weight(Self.value(state.objectWeights, index, "bold")),
            size: size,
            color: Self.hexColor(Self.value(state.objectColors, index, "")) ?? Token.textPrimary,
            alignment: Self.alignment(Self.value(state.objectAlignments, index, "center")),
            label: Self.label(Self.value(state.objectLabels, index, "none")),
            listStyle: Self.listStyle(Self.value(state.objectListStyles, index, "none")),
            startNumber: Self.value(state.objectStartNumbers, index, 1),
            marks: marks(for: index),
            highlights: state.highlightObjects.indices.filter { state.highlightObjects[$0] == index }.map {
                CanvasTextObject.TextRange(start: Self.value(state.highlightStarts, $0, 0),
                                           end: Self.value(state.highlightEnds, $0, 0))
            },
            animation: CanvasTextObject.Animation(
                kind: Self.animationKind(Self.value(state.objectAnimations, index, "none")),
                loop: Self.value(state.objectAnimationLoops, index, false)
            ),
            effect: Self.effect(Self.value(state.objectEffects, index, "none")),
            transform: CanvasTextObject.Transform(
                position: CGPoint(x: Self.value(state.objectXs, index, 220), y: Self.value(state.objectYs, index, 478)),
                scale: CGFloat(Self.value(state.objectScales, index, 1)),
                rotation: .degrees(Self.value(state.objectRotations, index, 0)),
                width: width > 0 ? CGFloat(width) : nil
            ),
            seedHeight: measured > 0 ? CGFloat(measured) : size * Self.lineHeightFactor * lines
        )
    }

    private func marks(for index: Int) -> [CanvasTextObject.Mark] {
        state.markObjects.indices.filter { state.markObjects[$0] == index }.compactMap { mark in
            let start = Self.value(state.markStarts, mark, 0)
            let end = Self.value(state.markEnds, mark, 0)
            switch Self.value(state.markKinds, mark, "") {
            case "bold": return .init(start: start, end: end, kind: .bold)
            case "italic": return .init(start: start, end: end, kind: .italic)
            case "link": return .init(start: start, end: end, kind: .link(href: Self.value(state.markHrefs, mark, "")))
            default: return nil                                   // 02 §9: rendered without it
            }
        }
    }

    private func action(_ index: Int) -> Action? {
        guard let kind = Action.Kind(rawValue: Self.value(state.actionKinds, index, "")) else { return nil }
        return Action(
            id: state.actionIDs[index],
            kind: kind,
            label: Self.value(state.actionLabels, index, ""),
            placement: Action.Placement(rawValue: Self.value(state.actionPlacements, index, "")) ?? .inline,
            value: Self.value(state.actionValues, index, "")
        )
    }

    /// A page colour or wash is the document's data, decoded from its #rrggbb (data, not style).
    private static func hexColor(_ hex: String) -> Color? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return nil }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255,
                     green: Double((rgb >> 8) & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }

    /// 02 §6: an unknown key falls back to `sans`.
    private static func font(_ key: String) -> CanvasTextObject.Font {
        switch key {
        case "display": return .display
        case "serif": return .serif
        case "mono": return .mono
        default: return .sans
        }
    }

    private static func weight(_ key: String) -> CanvasTextObject.Weight {
        switch key {
        case "regular": return .regular
        case "medium": return .medium
        default: return .bold
        }
    }

    private static func alignment(_ key: String) -> CanvasTextObject.Alignment {
        switch key {
        case "left": return .left
        case "right": return .right
        default: return .center
        }
    }

    private static func label(_ key: String) -> CanvasTextObject.Label {
        switch key {
        case "solidDark": return .solidDark
        case "solidLight": return .solidLight
        default: return .none
        }
    }

    private static func listStyle(_ key: String) -> CanvasTextObject.ListStyle {
        switch key {
        case "bullet": return .bullet
        case "numbered": return .numbered
        case "bibleVerse": return .bibleVerse
        default: return .none
        }
    }

    /// 02 §9: an unknown animation or effect renders without it.
    private static func animationKind(_ key: String) -> CanvasTextObject.Animation.Kind {
        switch key {
        case "typewriter": return .typewriter
        case "pop": return .pop
        case "jump": return .jump
        default: return .none
        }
    }

    private static func effect(_ key: String) -> CanvasTextObject.Effect {
        switch key {
        case "sparkle": return .sparkle
        case "neon": return .neon
        case "shimmer": return .shimmer
        case "pixel": return .pixel
        default: return .none
        }
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case). Copy is the frozen stills' (§1 deviation 1: the reference app's content stands in
// for a lesson's); colours are sampled from them; the envelope copy is 02 §2's.

extension ActivitiesPlayerScreen.State {
    /// The recorded lesson (01 §2): video, long article, scripture, share, prayer, video, article
    /// with a pinned action, end.
    private static let lessonPages = 8
    /// The recording's page ground, sampled from t12.5, t24.0 and t38.5.
    private static let teal = "#064648"
    private static let white = "#FFFFFF"

    private static let scripture = "Finally, brothers and sisters, whatever is true, whatever is noble, "
        + "whatever is right, whatever is pure, whatever is lovely, whatever is admirable—if anything is "
        + "excellent or praiseworthy—think about such things."
    private static let prayer = "God, sometimes it’s hard to focus my mind on good things. But I know You "
        + "are true, noble, right, pure, lovely, admirable, excellent, and praiseworthy—and I am grateful I "
        + "can focus my mind on You at all times. When I go through challenging situations, please remind "
        + "me of Your goodness. In Jesus’ name, Amen."
    private static let article = [
        "Do you ever think about what you think about? Or recognize that your thoughts have power? Or "
            + "consider how, over time, you’ll become what you think?",
        "Writing from a Roman prison to the believers in the Greek city of Philippi, the apostle Paul knew "
            + "firsthand the importance of battling hard things with true thoughts. He regularly dealt with "
            + "opposition, weakness, hardship, and persecution.",
        "But Paul also knew that Jesus-followers were called to a different way of thinking…",
        "“Finally, brothers and sisters, whatever is true, whatever is noble, whatever is right, whatever is "
            + "pure, whatever is lovely, whatever is admirable—anything is excellent or praiseworthy—think "
            + "about such things.”\nPhilippians 4:8 NIV",
        "Even in a broken world, God has created good things, and He’s empowered us to notice and to praise "
            + "Him for it.",
        "Focusing on what is good might look like reflecting on Jesus’ sacrifice for you. It could mean "
            + "remembering a time when you felt God protect, provide, or prepare you. Or it could look like "
            + "thanking God for the promises He’s kept, and the love He’s shown you.",
        "Following Paul’s advice isn’t about practicing positive thinking—it’s about fixing our thoughts on "
            + "God in order to cultivate the mind of Christ in our everyday lives.",
        "So today, think about what you think about. Search for a rhythm of gratefulness and worship. Thank "
            + "God for opportunities to shine light into a dark world. And look for what is good, pure, and "
            + "true wherever you go."
    ].joined(separator: "\n\n")

    private static let base = Self(
        pageCount: lessonPages, anchor: 0, drag: 0, activePage: 0, morphProgress: 0, thumbFraction: nil,
        railVisible: true, topAction: "share", topInset: 59, bottomInset: 34,
        pageIndexes: [], pageKinds: [], inner: [], pageColorHexes: [], pageImageURLs: [],
        pageImageFocalXs: [], pageImageFocalYs: [], pageWashHexes: [], pageWashOpacities: [],
        pageVerticalAnchors: [], pageTitles: [], pageBodies: [], pagePlaceholders: [],
        pageCaptionLines: [], pagePresenterNames: [], pagePresenterImageURLs: [], pagePresenterInitials: [],
        pageReferences: [], pageRemainingTimes: [], pageProgresses: [], pagePlaying: [], pageBuffering: [],
        objectPages: [], objectTexts: [], objectFonts: [], objectColors: [], objectWeights: [], objectSizes: [],
        objectAlignments: [], objectLabels: [], objectListStyles: [], objectStartNumbers: [],
        objectAnimations: [], objectAnimationLoops: [], objectEffects: [], objectXs: [], objectYs: [],
        objectScales: [], objectRotations: [], objectWidths: [], objectHeights: [],
        markObjects: [], markStarts: [], markEnds: [], markKinds: [], markHrefs: [],
        highlightObjects: [], highlightStarts: [], highlightEnds: [],
        actionPages: [], actionIDs: [], actionKinds: [], actionLabels: [], actionPlacements: [], actionValues: [],
        sheetKind: "", sheetTitle: "", sheetBodyText: "", sheetPrompt: "", animationStart: nil
    )

    /// One left-aligned object on page `page`, at centre (220, y), `width` wu wide.
    private mutating func addObject(page: Int, text: String, font: String, weight: String, size: Double,
                                    y: Double, width: Double, height: Double) {
        objectPages.append(page)
        objectTexts.append(text)
        objectFonts.append(font)
        objectColors.append(Self.white)
        objectWeights.append(weight)
        objectSizes.append(size)
        objectAlignments.append("left")
        objectXs.append(220)
        objectYs.append(y)
        objectWidths.append(width)
        objectHeights.append(height)
    }

    private mutating func addPage(index: Int, kind: String, color: String = teal) {
        pageIndexes.append(index)
        pageKinds.append(kind)
        inner.append(0)
        pageColorHexes.append(color)
    }

    /// t22.5 / t24.0: the scripture page — eyebrow, passage and reference.
    private mutating func addScripturePage(index: Int) {
        let page = pageIndexes.count
        addPage(index: index, kind: "canvas")
        addObject(page: page, text: "SCRIPTURE", font: "sans", weight: "bold", size: 11, y: 347, width: 360, height: 13.3)
        // 02 §3's own sample of this passage: serif 700 at 26.
        addObject(page: page, text: Self.scripture, font: "serif", weight: "bold", size: 26, y: 511, width: 360, height: 285.3)
        addObject(page: page, text: "Philippians 4:8 NIV", font: "sans", weight: "regular", size: 15, y: 679, width: 360, height: 18.3)
    }

    /// t38.5 (02 §11): the prayer page with its inline Add to Prayer List.
    private mutating func addPrayerPage(index: Int) {
        let page = pageIndexes.count
        addPage(index: index, kind: "canvas")
        addObject(page: page, text: "PRAYER", font: "sans", weight: "bold", size: 11, y: 183, width: 360, height: 13.3)
        addObject(page: page, text: Self.prayer, font: "sans", weight: "bold", size: 28, y: 445, width: 360, height: 474)
        actionPages.append(page)
        actionIDs.append("a1")
        actionKinds.append("addToPrayerList")
        actionLabels.append("Add to Prayer List")
        actionPlacements.append("inline")
        actionValues.append("A Prayer to Focus My Mind on God")
    }

    /// A write page (D25): the prompt (t17.5's copy) and 02 §7's placeholder.
    private mutating func addWritePage(index: Int) {
        let page = pageIndexes.count
        addPage(index: index, kind: "write")
        pagePlaceholders = Array(repeating: "", count: page) + ["Write your thoughts"]
        addObject(page: page, text: "So today, think about what you think about.", font: "sans", weight: "bold",
                  size: 28, y: 380, width: 360, height: 68)
    }

    private mutating func rest(on index: Int, topAction: String = "share") {
        anchor = index
        activePage = index
        self.topAction = topAction
    }

    /// `canvas-short`: a canvas that fits, at rest — the safe band, a solid capsule, `share`.
    static let canvasShort: Self = {
        var s = base
        s.addScripturePage(index: 2)
        s.rest(on: 2)
        return s
    }()

    /// `inline-action`: as above, with the row under the last object.
    static let inlineAction: Self = {
        var s = base
        s.addPrayerPage(index: 4)
        s.rest(on: 4)
        return s
    }()

    /// `pinned-action` (t50.0 at rest, deviations 7–8): the article's heading and opening, and its
    /// pinned Start Plan; `menu`.
    static let pinnedAction: Self = {
        var s = base
        s.addPage(index: 6, kind: "canvas", color: "#0E0E0E")
        s.addObject(page: 0, text: "Transformation Starts with Your Thoughts", font: "serif", weight: "bold",
                    size: 22, y: 406, width: 392, height: 60.3)
        s.addObject(page: 0, text: "Have you ever noticed how much time you spend thinking? From the moment you "
                        + "wake up to the moment you fall asleep, your mind is always on. It replays conversations, "
                        + "plans your day, worries about what could go wrong, and imagines what could go right.\n\n"
                        + "Your thoughts are constant. And whether you realize it or not, they’re shaping "
                        + "everything about you.",
                    font: "serif", weight: "regular", size: 18, y: 578, width: 392, height: 236.7)
        s.actionPages = [0]
        s.actionIDs = ["a1"]
        s.actionKinds = ["nextLesson"]
        s.actionLabels = ["Start Plan"]
        s.actionPlacements = ["pinned"]
        s.actionValues = [""]
        s.rest(on: 6, topAction: "menu")
        return s
    }()

    /// `long-page-thumb` (t12.5 + t17.5): a long canvas scrolled mid-range, the thumb at
    /// `inner / maxInner`.
    static let longPageThumb: Self = {
        var s = base
        s.addPage(index: 1, kind: "canvas")
        s.addObject(page: 0, text: "Think About It", font: "sans", weight: "bold", size: 32, y: 277, width: 360, height: 39)
        s.addObject(page: 0, text: article, font: "sans", weight: "regular", size: 17, y: 773, width: 360, height: 881)
        s.inner = [96]
        s.thumbFraction = 0.5
        s.rest(on: 1)
        return s
    }()

    /// `mid-drag` (t24.0): the scripture page dragged 328 pt, 34 % of 956, onto the page below
    /// (deviation 10: a blank page, sampled from the still).
    static let midDrag: Self = {
        var s = base
        s.addScripturePage(index: 2)
        s.addPage(index: 3, kind: "canvas", color: "#211F22")
        s.rest(on: 2)
        s.drag = 328
        return s
    }()

    /// The recording's first page (t02.0): its cue, presenter, reference and time; position from the
    /// still's thumb (x 87 on the 52–381 track).
    private mutating func addVideoPage(playing: Bool) {
        addPage(index: 0, kind: "video", color: "")
        pageCaptionLines = [["You watch one, then another one,", "then another, and the next time"]]
        pagePresenterNames = ["Jackie Bledsoe"]
        pagePresenterImageURLs = ["http://localhost:5961/api/projects/makeready/images/luke-cage"]
        pagePresenterInitials = ["JB"]
        pageReferences = ["Philippians 4:8"]
        pageRemainingTimes = ["1:47"]
        pageProgresses = [0.106]
        pagePlaying = [playing]
        pageBuffering = [false]
        rest(on: 0, topAction: "menu")
    }

    /// `video-rail-hidden`: playing, the rail faded out.
    static let videoRailHidden: Self = {
        var s = base
        s.addVideoPage(playing: true)
        s.railVisible = false
        return s
    }()

    /// `video-paused`: the play glyph, the rail visible.
    static let videoPaused: Self = {
        var s = base
        s.addVideoPage(playing: false)
        return s
    }()

    /// `youtube`: the host's player in its slot; `menu`.
    static let youtube: Self = {
        var s = base
        s.addPage(index: 5, kind: "youtube", color: "")
        s.rest(on: 5, topAction: "menu")
        return s
    }()

    /// `write`: the prompt, the disabled field and "Preview".
    static let write: Self = {
        var s = base
        s.addWritePage(index: 3)
        s.rest(on: 3)
        return s
    }()

    /// `end`: C-136 with the recorded lesson's title (04 §Source), the rail on the last slot.
    static let end: Self = {
        var s = base
        s.addPage(index: 7, kind: "end", color: "")
        s.pageTitles = ["Guided Scripture"]
        s.rest(on: 7, topAction: "none")
        return s
    }()

    /// `sheet-open` (t42.0): Add to Prayer List open over the prayer page.
    static let sheetOpen: Self = {
        var s = inlineAction
        s.sheetKind = "addToPrayerList"
        s.sheetTitle = "A Prayer to Focus My Mind on God"
        s.sheetBodyText = prayer
        return s
    }()

    /// `sheet-open-write`: the write sheet over the write page, its prompt the placeholder.
    static let sheetOpenWrite: Self = {
        var s = write
        s.sheetKind = "write"
        s.sheetPrompt = "Write your thoughts"
        return s
    }()

    /// `fallback`: an unknown kind — 02 §2's fallback copy over its page colour (02 §5).
    static let fallback: Self = {
        var s = base
        s.addPage(index: 4, kind: "poll", color: "#0E4A4D")
        s.pageTitles = ["A new activity"]
        s.pageBodies = ["Update the app to see this."]
        s.rest(on: 4)
        return s
    }()

    /// `load-failed`: the container could not load the activity — header and close only.
    static let loadFailed: Self = {
        var s = base
        s.loadFailed = true
        return s
    }()
}

// MARK: - Previews (one per §3 state, in §3's order; the device canvas is the 440 × 956 recording)

#Preview("canvas-short") {
    ActivitiesPlayerScreen(state: .canvasShort)
        .frame(width: 440, height: 956)
}

#Preview("inline-action") {
    ActivitiesPlayerScreen(state: .inlineAction)
        .frame(width: 440, height: 956)
}

#Preview("pinned-action") {
    ActivitiesPlayerScreen(state: .pinnedAction)
        .frame(width: 440, height: 956)
}

#Preview("long-page-thumb") {
    ActivitiesPlayerScreen(state: .longPageThumb)
        .frame(width: 440, height: 956)
}

#Preview("mid-drag") {
    ActivitiesPlayerScreen(state: .midDrag)
        .frame(width: 440, height: 956)
}

#Preview("video-rail-hidden") {
    ActivitiesPlayerScreen(state: .videoRailHidden)
        .frame(width: 440, height: 956)
}

#Preview("video-paused") {
    ActivitiesPlayerScreen(state: .videoPaused)
        .frame(width: 440, height: 956)
}

#Preview("youtube") {
    ActivitiesPlayerScreen(state: .youtube)
        .frame(width: 440, height: 956)
}

#Preview("write") {
    ActivitiesPlayerScreen(state: .write)
        .frame(width: 440, height: 956)
}

#Preview("end") {
    ActivitiesPlayerScreen(state: .end)
        .frame(width: 440, height: 956)
}

#Preview("sheet-open") {
    ActivitiesPlayerScreen(state: .sheetOpen)
        .frame(width: 440, height: 956)
}

#Preview("sheet-open-write") {
    ActivitiesPlayerScreen(state: .sheetOpenWrite)
        .frame(width: 440, height: 956)
}

#Preview("fallback") {
    ActivitiesPlayerScreen(state: .fallback)
        .frame(width: 440, height: 956)
}

#Preview("load-failed") {
    ActivitiesPlayerScreen(state: .loadFailed)
        .frame(width: 440, height: 956)
}
