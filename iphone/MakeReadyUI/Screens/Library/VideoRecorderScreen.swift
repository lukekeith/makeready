//
//  VideoRecorderScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-recorder in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/videos/upload-url ·
//  POST /api/videos · POST /api/videos/:videoId/refresh · GET /api/notes · GET /api/notes/:noteId
//  (the container's — VideoRecorderContainer owns capture, drafts, export and upload).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI
import UIKit

/// Video Recorder — the leader's camera for a short teaching video, in two layouts (§2): inside
/// Edit lesson (`lessonInline`, Figma) or full screen from the + menu (`fullScreen`). Every
/// recorder part floats over C-152 CameraPreview (§2c); the view is pure (§5): it reads nothing,
/// calls nothing and reports every action through an `on…` closure.
///
/// Composed only of §4's C-152 CameraPreview, C-013 RecordButton (`video`), C-144 TimerPill,
/// C-145 SegmentedProgressBar, C-146 CameraRail (→ C-147 RailTool), C-147 RailTool (Review's
/// Edit and Filters), C-148 CountdownNumerals, C-149 LengthSlider, C-150 FilterStrip, C-151
/// TeleprompterBand, C-159 DoneCheck, C-004 ScrubTrack, C-047 RadioOptionRow, C-132 EmptyState, and the lessonInline host chrome C-040 PageHeader and
/// C-081 ActivityNavBar (deviation 3). §2's C-021 GlyphButton roles (close, import, undo, ✓) and
/// C-105 Button roles (Retake, Save) are NOT in §4's roll-call (§4: "they join the roll-call
/// with drawings once a frame draws them"), so this build draws none of them — a spec gap,
/// reported, never improvised. Standalone: `identifiedFrom` is null, so no D7 template applies.
struct VideoRecorderScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2d Countdown panel: Off · 3 s · 10 s, in seconds (0 = Off).
        enum PreRoll: Int, CaseIterable {
            case off = 0, three = 3, ten = 10

            /// §2d: the segment's label.
            var label: String { self == .off ? "Off" : "\(rawValue) s" }

            /// §5 `countdown` as the rail shows it: "" Off, "3s", "10s".
            var railValue: String { self == .off ? "" : "\(rawValue)s" }
        }

        /// §5 `layout`.
        enum Layout: String {
            case lessonInline, fullScreen
        }

        /// §3 Phases (closed list — `State.phase`).
        enum Phase: String {
            case ready, preRoll, recording, paused, endCountdown, permissionDenied, review, trim
        }

        /// §3: "Sheets (Length, Countdown, Filters, Teleprompter) open over `ready`/`paused`/`review` and
        /// are screen-local presentation state" — this seeds it; "" = none.
        enum Sheet: String {
            case none = "", length, countdown, filters, teleprompter
        }

        // Defaults: D3's 1:00 length, Countdown Off (D2), Normal at 100 (D6), the teleprompter
        // off with C-151's medium size and speed 3 — each §3 state overrides what differs.
        var layout: Layout = .lessonInline
        var phase: Phase = .ready
        /// §3 `preRoll(n)` / `endCountdown(n)`: the numeral *n* shown.
        var countdownNumeral: Int = 3
        /// §5 `segments` — finished segment durations in seconds, in order (C-145's §4 unit).
        var segments: [Double] = []
        /// C-145 `liveDuration` — seconds into the segment recording now; 0 when none.
        var liveDuration: Double = 0
        /// §5 `length` — the chosen length in seconds (5…120, default 60).
        var length: Double = 60
        /// §5 `countdown` as the rail shows it: "" Off, "3s", "10s" (D2).
        var countdownValue: String = ""
        /// §5 `lengthMode` — "any" | "specify" (the Length panel's row).
        var lengthMode: String = "any"
        /// §5 `endCountdown` — 0 | 3 | 10 seconds (Length panel, Specify length).
        var endCountdown: Int = 0
        /// §5 `countdownSound` — the Countdown panel's Sound switch; the container plays the beeps.
        var countdownSound: Bool = false
        /// §5 `filter` — a C-150 look by name ("Normal" … "Noir"); unknown = Normal.
        var filterLook: String = "Normal"
        /// §5 `strength` — 0…100 (D6).
        var strength: Int = 100
        /// §5 `teleprompter.on`.
        var teleprompterOn: Bool = false
        /// §5 `teleprompter.script`.
        var script: String = ""
        /// §5 `teleprompter.speed` — 1…5.
        var speed: Int = 3
        /// §5 `teleprompter.size` — "Small" | "Medium" | "Large".
        var textSize: String = "Medium"
        /// §5 Review playback — the container's player.
        var reviewPlaying: Bool = false
        var reviewElapsed: TimeInterval = 0
        var reviewDuration: TimeInterval = 0
        /// True while a finger is on Review's C-004.
        var reviewScrubbing: Bool = false
        /// §3 Rail labels: whether they show at first; the screen times them from there.
        var railLabelsVisible: Bool = true
        /// The sheet open at first (§3 Sheets).
        var sheet: Sheet = .none
        /// §1 deviation 4: the capture's fixed sample still in place of the live feed — a
        /// catalog image URL, resolved from `Ui2ImageCache`; "" = no feed (the surface alone).
        var cameraImageURL: String = ""
    }

    let state: State
    /// §3: record disc / stop (also cancels `preRoll`).
    var onRecord: () -> Void = {}
    /// §3: pause (recording).
    var onPause: () -> Void = {}
    /// §3: each rail tool — the container flips; the rest open their sheets here.
    var onRail: (RailTool.Tool) -> Void = { _ in }
    /// §3: back (inline host) — the container confirms a discard mid-recording.
    var onClose: () -> Void = {}
    /// §3: Open Settings (permissionDenied).
    var onOpenSettings: () -> Void = {}
    /// §5: the sheet values' change callbacks.
    var onLengthChange: (TimeInterval) -> Void = { _ in }
    var onFilterChange: (String) -> Void = { _ in }
    var onStrengthChange: (Int) -> Void = { _ in }
    var onScriptChange: (String) -> Void = { _ in }
    var onUseNote: () -> Void = {}
    var onSpeedChange: (Int) -> Void = { _ in }
    var onTextSizeChange: (String) -> Void = { _ in }
    /// §3 Countdown panel: Off · 3 s · 10 s chosen; the Sound switch changed.
    var onPreRollChange: (State.PreRoll) -> Void = { _ in }
    var onCountdownSoundChange: (Bool) -> Void = { _ in }
    /// §3 Length panel: a row chosen ("any" | "specify"); End countdown chosen (0 | 3 | 10).
    var onLengthModeChange: (String) -> Void = { _ in }
    var onEndCountdownChange: (Int) -> Void = { _ in }
    /// §3 Review: a tap on the video (play / pause); C-004's seek and touch state.
    var onReviewTap: () -> Void = {}
    var onReviewSeek: (TimeInterval) -> Void = { _ in }
    var onReviewScrubbingChange: (Bool) -> Void = { _ in }
    /// fullScreen Review: the C-159 check, "Save" to VoiceOver.
    var onSave: () -> Void = {}

    // Host inputs (every default renders as captured).
    /// The live feed: the capture engine's display layer, or Review's player layer. nil = the
    /// state's sample still (§1 deviation 4).
    var feed: CameraPreview<AnyView>.Feed?
    /// False when the lessonInline host draws its own header and activity nav (deviation 3).
    var hostChrome: Bool
    /// C-151 `scrollOffset`.
    var teleprompterOffset: CGFloat
    /// C-150 `thumbnails`.
    var filterThumbnails: [FilterStrip.Look: Image]
    /// True: the screen takes the height it is offered, so a sheet sits at the host's bottom edge
    /// (the fullScreen preview is shorter than the screen).
    var fillsHeight: Bool
    /// Space under a sheet's content, inside its surface: the home indicator or the keyboard.
    var sheetBottomInset: CGFloat
    /// Laid over the preview in every phase (§2b close; §2d trim's window).
    var previewSlot: () -> AnyView
    /// Laid over the record row, bottom-aligned; hidden with it (§2c import, undo, ✓).
    var recordRowSlot: () -> AnyView
    /// The bottom row of `review` (trailing of Edit + Filters, sized to the width left) and `trim`
    /// (§2d Retake, Save; Cancel, Next).
    var reviewSlot: () -> AnyView
    /// §3: Review's Edit — the container opens the video editor. nil hides the control.
    var onEdit: (() -> Void)?

    // §3 UI-only rule: "Sheets (Length, Countdown, Filters, Teleprompter) … are screen-local
    // presentation state" (R-31).
    @SwiftUI.State private var sheet: State.Sheet
    /// The sheet drawn: stays until its slide-out ends, then becomes `sheet`.
    @SwiftUI.State private var mountedSheet: State.Sheet
    /// The mounted sheet is the seeded one, at rest from the first frame.
    @SwiftUI.State private var mountedAtRest: Bool
    // §3 Rail labels: shown on appear and on each tool tap, then faded (video-polish D7).
    @SwiftUI.State private var labelsVisible: Bool
    @SwiftUI.State private var railTaps = 0
    @SwiftUI.State private var shownRailTaps = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// True only beneath the capture harness's element map (UI2Element.swift).
    @Environment(\.ui2ElementCollecting) private var capturing

    init(
        state: State,
        onRecord: @escaping () -> Void = {},
        onPause: @escaping () -> Void = {},
        onRail: @escaping (RailTool.Tool) -> Void = { _ in },
        onClose: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onLengthChange: @escaping (TimeInterval) -> Void = { _ in },
        onFilterChange: @escaping (String) -> Void = { _ in },
        onStrengthChange: @escaping (Int) -> Void = { _ in },
        onScriptChange: @escaping (String) -> Void = { _ in },
        onUseNote: @escaping () -> Void = {},
        onSpeedChange: @escaping (Int) -> Void = { _ in },
        onTextSizeChange: @escaping (String) -> Void = { _ in },
        onPreRollChange: @escaping (State.PreRoll) -> Void = { _ in },
        onCountdownSoundChange: @escaping (Bool) -> Void = { _ in },
        feed: CameraPreview<AnyView>.Feed? = nil,
        hostChrome: Bool = true,
        teleprompterOffset: CGFloat = 0,
        filterThumbnails: [FilterStrip.Look: Image] = [:],
        fillsHeight: Bool = false,
        sheetBottomInset: CGFloat = 0,
        previewSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        recordRowSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        reviewSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        onEdit: (() -> Void)? = nil,
        onLengthModeChange: @escaping (String) -> Void = { _ in },
        onEndCountdownChange: @escaping (Int) -> Void = { _ in },
        onReviewTap: @escaping () -> Void = {},
        onReviewSeek: @escaping (TimeInterval) -> Void = { _ in },
        onReviewScrubbingChange: @escaping (Bool) -> Void = { _ in },
        onSave: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onRecord = onRecord
        self.onPause = onPause
        self.onRail = onRail
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
        self.onLengthChange = onLengthChange
        self.onFilterChange = onFilterChange
        self.onStrengthChange = onStrengthChange
        self.onScriptChange = onScriptChange
        self.onUseNote = onUseNote
        self.onSpeedChange = onSpeedChange
        self.onTextSizeChange = onTextSizeChange
        self.onPreRollChange = onPreRollChange
        self.onCountdownSoundChange = onCountdownSoundChange
        self.feed = feed
        self.hostChrome = hostChrome
        self.teleprompterOffset = teleprompterOffset
        self.filterThumbnails = filterThumbnails
        self.fillsHeight = fillsHeight
        self.sheetBottomInset = sheetBottomInset
        self.previewSlot = previewSlot
        self.recordRowSlot = recordRowSlot
        self.reviewSlot = reviewSlot
        self.onEdit = onEdit
        self.onLengthModeChange = onLengthModeChange
        self.onEndCountdownChange = onEndCountdownChange
        self.onReviewTap = onReviewTap
        self.onReviewSeek = onReviewSeek
        self.onReviewScrubbingChange = onReviewScrubbingChange
        self.onSave = onSave
        _sheet = SwiftUI.State(initialValue: state.sheet)
        _mountedSheet = SwiftUI.State(initialValue: state.sheet)
        _mountedAtRest = SwiftUI.State(initialValue: state.sheet != .none)
        _labelsVisible = SwiftUI.State(initialValue: state.railLabelsVisible)
    }

    // MARK: - Geometry (§2c, relative to the preview's own rect)

    private enum Geometry {
        /// GAP — video-recorder §2c: C-144 TimerPill "centred, top 20"; no spacing token.
        static let timerTop: CGFloat = 20
        /// GAP — video-recorder §2c: C-013 record / stop "centred, bottom 6"; no spacing token.
        static let recordBottom: CGFloat = 6
        /// GAP — video-recorder §2c: C-013 pause "leading 18"; no spacing token.
        static let pauseLeading: CGFloat = 18
        /// GAP — video-recorder §2c: C-013 pause "bottom 20"; no spacing token.
        static let pauseBottom: CGFloat = 20
        /// GAP — video-recorder §2d Review: the Filters C-147 tool sits "on the record row" — its
        /// 50 pt slot centred on the 80 pt record row at bottom 6: 6 + (80 − 50) / 2.
        static let reviewToolBottom: CGFloat = 21
        /// GAP — video-recorder §2d Review: Edit and Filters "10 pt gap"; no spacing token.
        static let reviewToolGap: CGFloat = 10
        /// GAP — video-recorder §2a: the host's "hairline divider"; no stroke token.
        static let hairline: CGFloat = 1
    }

    /// GAP — video-recorder §2c Rail labels: 0.2 s in, 0.3 s out, held 1.0 s on appear and 2.0 s
    /// after a tap; no motion token names them.
    private enum RailLabelMotion {
        static let fadeIn = Animation.easeOut(duration: 0.2)
        static let fadeOut = Animation.easeOut(duration: 0.3)
        static let appearHold = Duration.seconds(1)
        /// The 0.2 s fade-in, then 2.0 s.
        static let tapHold = Duration.seconds(2.2)
    }

    // MARK: - Derived (§3)

    private var phase: State.Phase { state.phase }

    /// The camera phases — every phase with the live preview and its overlays.
    private var isCameraPhase: Bool {
        [.ready, .preRoll, .recording, .paused, .endCountdown].contains(phase)
    }

    /// §3: a segment is being recorded (or ending).
    private var isRecording: Bool { phase == .recording || phase == .endCountdown }

    /// §3 / §2a: "While recording the host hides C-040, both dividers and C-081"; the chrome also
    /// fades on record start (01 §9), so it is hidden through `preRoll` too.
    private var hostChromeVisible: Bool {
        ![.preRoll, .recording, .endCountdown].contains(phase)
    }

    /// §3 `paused` / `recording`: total recorded time.
    private var elapsed: TimeInterval { state.segments.reduce(0, +) + state.liveDuration }

    /// §2c TimerPill: recording, paused (with ≥1 segment), endCountdown.
    private var showsTimer: Bool {
        isRecording || (phase == .paused && !state.segments.isEmpty)
    }

    /// §2c CameraRail: ready, paused.
    private var showsRail: Bool { phase == .ready || phase == .paused }

    /// §2c RecordButton: "always except permissionDenied, review, trim".
    private var showsRecordRow: Bool { isCameraPhase }

    /// §2d Length panel: Specify length chosen.
    private var specifiesLength: Bool { state.lengthMode == "specify" }

    /// §5 `countdown`, as the Countdown panel's selection.
    private var preRoll: State.PreRoll {
        State.PreRoll.allCases.first { $0.railValue == state.countdownValue } ?? .off
    }

    /// §2c TeleprompterBand: "any camera phase while the teleprompter is on".
    private var showsTeleprompter: Bool { isCameraPhase && state.teleprompterOn }

    private var look: FilterStrip.Look {
        FilterStrip.Look.allCases.first { $0.name.caseInsensitiveCompare(state.filterLook) == .orderedSame } ?? .normal
    }

    private var teleprompterSize: TeleprompterBand.TextSize {
        TeleprompterBand.TextSize.allCases.first {
            $0.label.caseInsensitiveCompare(state.textSize) == .orderedSame
        } ?? .medium
    }

    /// C-146 `lengthValue` — `m:ss`; under Any length, the 2:00 cap.
    private var lengthValue: String {
        guard specifiesLength else { return LengthEntry.format(LengthEntry.maximumSeconds) }
        return LengthEntry.format(max(Int(state.length.rounded()), 0))
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch state.layout {
            case .lessonInline: inlineLayout
            case .fullScreen: fullScreenLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .top)
        .background(Token.layoutBackground)
        // §2d: the sheets, in place over the recorder.
        .overlayPreferenceValue(PreviewBoundsKey.self) { anchor in
            GeometryReader { proxy in
                sheetLayer(previewRect: anchor.map { proxy[$0] } ?? .zero)
            }
        }
        .onChange(of: sheet) { _, next in
            // An open sheet slides off first (`sheetHidden`); from none, the new one mounts now.
            guard mountedSheet == .none, next != .none else { return }
            mountedAtRest = false
            mountedSheet = next
        }
        .task(id: RailLabelKey(railShown: showsRail, taps: railTaps)) { await showRailLabels() }
    }

    /// The preview's rect, for the rail the Countdown sheet keeps above its dim.
    private struct PreviewBoundsKey: PreferenceKey {
        static let defaultValue: Anchor<CGRect>? = nil
        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    // MARK: - §3 Rail labels

    private struct RailLabelKey: Equatable {
        let railShown: Bool
        let taps: Int
    }

    /// Shown as the rail appears (held 1.0 s) and on a tool tap (faded in, held 2.0 s), then faded
    /// out. A new tap or the rail leaving cancels the hold. A capture keeps its seeded labels.
    private func showRailLabels() async {
        guard showsRail, !capturing else { return }
        let tapped = railTaps != shownRailTaps
        shownRailTaps = railTaps
        if tapped {
            withAnimation(RailLabelMotion.fadeIn) { labelsVisible = true }
        } else {
            labelsVisible = true
        }
        do {
            try await Task.sleep(for: tapped ? RailLabelMotion.tapHold : RailLabelMotion.appearHold)
        } catch {
            return // cancelled: the next task times the labels
        }
        withAnimation(RailLabelMotion.fadeOut) { labelsVisible = false }
    }

    private func railTapped(_ action: () -> Void) {
        railTaps += 1
        action()
    }

    // MARK: - §2a lessonInline

    /// §2a: C-040 · hairline · CameraPreview 440 wide · hairline · C-081. The host chrome hides
    /// while recording and the preview keeps its idle rect (deviation 6), so the chrome is hidden
    /// in place, not removed.
    private var inlineLayout: some View {
        VStack(spacing: 0) {
            if hostChrome {
                chromePart(header, name: "C-040 PageHeader")
                chromePart(hairline, name: nil)
            }
            preview(corners: .square)
            if hostChrome {
                chromePart(hairline, name: nil)
                chromePart(navBar, name: "C-081 ActivityNavBar")
            }
        }
    }

    /// Deviation 3: drawn by the activities-editor host; here so the capture lines up with the
    /// Figma frame.
    @ViewBuilder
    private func chromePart(_ content: some View, name: String?) -> some View {
        if hostChromeVisible {
            if let name {
                content.ui2Element(name)
            } else {
                content
            }
        } else {
            content.hidden()
        }
    }

    /// §2a: C-040 `Default`, "Edit lesson", back + settings.
    private var header: some View {
        PageHeader(
            style: .default,
            title: "Edit lesson",
            showTitle: true,
            showIcons: true,
            leadingGlyph: .back,
            rightButtons: [.settings],
            onLeading: onClose
        )
    }

    /// §2a: hairline divider, `color-layout-border`.
    private var hairline: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(height: Geometry.hairline)
    }

    /// §2a: C-081, padding `space-page-margin`. Sample from frame 01 (03 §Frame 01): four
    /// slides, the last one the active video slide.
    private var navBar: some View {
        ActivityNavBar(
            slides: Self.hostSlides,
            activeID: Self.hostSlides.last?.id,
            bottomInset: Token.Space.pageMargin
        )
    }

    private static let hostSlides: [ActivityNavBar.Slide] = (1...4).map {
        ActivityNavBar.Slide(id: "activity-\($0)", image: nil, label: "Activity \($0)")
    }

    // MARK: - §2b fullScreen

    /// §2b: the preview from the top safe-area inset, corners `radius-card`;
    /// `color-layout-background` below it. (§2b's C-021 close is not in §4 — not drawn.)
    private var fullScreenLayout: some View {
        preview(corners: .rounded)
    }

    // MARK: - The preview and §2c overlays

    private func preview(corners: CameraPreview<AnyView>.Corners) -> some View {
        CameraPreview(feed: feed ?? sampleFeed, corners: corners) {
            AnyView(overlays)
        }
        .ui2Element("C-152 CameraPreview")
        .transformAnchorPreference(key: PreviewBoundsKey.self, value: .bounds) { value, anchor in
            value = value ?? anchor
        }
    }

    /// §1 deviation 4: the capture renders a fixed sample still; the app passes the live layer.
    private var sampleFeed: CameraPreview<AnyView>.Feed {
        guard let url = URL(string: state.cameraImageURL), !state.cameraImageURL.isEmpty,
              let image = Ui2ImageCache.shared.image(for: url) else { return .none }
        return .still(Image(uiImage: image))
    }

    private var overlays: some View {
        ZStack {
            if phase == .permissionDenied {
                // §2c: "C-132 EmptyState with action 'Open Settings' … replaces every overlay".
                // Copy: C-132's `with-action` sample (D19).
                EmptyState(
                    glyph: .videoRecord,
                    title: "Camera access is off",
                    message: "Allow camera and microphone access in Settings to record.",
                    actionLabel: "Open Settings",
                    onAction: onOpenSettings
                )
                .ui2Element("C-132 EmptyState")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cameraOverlays
            }
            previewSlot()
        }
    }

    @ViewBuilder private var cameraOverlays: some View {
        if phase == .review {
            // §3 Review: a tap on the video plays or pauses, under every control.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onReviewTap)
                .accessibilityElement()
                .accessibilityLabel(state.reviewPlaying ? "Pause" : "Play")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onReviewTap() }
                .ui2Element("Review video")
        }

        // video-activity-basics: fullScreen Review's Save, opposite the app's ✕.
        if phase == .review && state.layout == .fullScreen {
            DoneCheck(onTap: onSave)
                // C-159 names itself "Done"; here it is Save.
                .accessibilityRepresentation { SwiftUI.Button("Save", action: onSave) }
                .ui2Element("C-159 DoneCheck")
                .padding(Token.Space.pageMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }

        // Top: bar, timer, teleprompter band (§2c).
        VStack(spacing: 0) {
            if isCameraPhase {
                SegmentedProgressBar(
                    length: state.length,
                    segments: state.segments,
                    liveDuration: state.liveDuration
                )
                .ui2Element("C-145 SegmentedProgressBar")
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.top, Token.Space.step8)
            }
            Spacer(minLength: 0)
        }

        if showsTimer {
            VStack(spacing: 0) {
                TimerPill(elapsed: elapsed)
                    .ui2Element("C-144 TimerPill")
                    .padding(.top, Geometry.timerTop)
                Spacer(minLength: 0)
            }
        }

        if showsTeleprompter {
            VStack(spacing: 0) {
                TeleprompterBand(
                    surface: .band,
                    script: state.script,
                    textSize: teleprompterSize,
                    speed: state.speed,
                    scrollOffset: teleprompterOffset
                )
                .ui2Element("C-151 TeleprompterBand")
                .padding(.horizontal, Token.Space.pageMargin)
                .padding(.top, Token.Space.step48)
                Spacer(minLength: 0)
            }
        }

        // Centre: the rail (trailing) and the countdown numeral.
        if showsRail && mountedSheet != .countdown {
            rail
                .padding(.trailing, Token.Space.pageMargin)
        }

        if phase == .preRoll || phase == .endCountdown {
            CountdownNumerals(
                value: state.countdownNumeral,
                phase: phase == .preRoll ? .preRoll : .ending
            )
            .ui2Element("C-148 CountdownNumerals")
        }

        // Bottom: the record row, or Review's and Trim's.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bottomRow
        }
    }

    private var rail: some View {
        CameraRail(
            countdownValue: state.countdownValue.isEmpty ? nil : state.countdownValue,
            lengthValue: lengthValue,
            // D3: "It cannot change once the first segment is recorded."
            lengthEnabled: state.segments.isEmpty,
            filtersActive: look != .normal,
            teleprompterActive: state.teleprompterOn,
            labelsVisible: labelsVisible,
            onFlip: { railTapped { onRail(.flip) } },
            onCountdown: { railTapped(toggleCountdown) },
            onLength: { railTapped { openSheet(.length, tool: .length) } },
            onFilters: { railTapped { openSheet(.filters, tool: .filters) } },
            onTeleprompter: { railTapped { openSheet(.teleprompter, tool: .teleprompter) } }
        )
        .ui2Element("C-146 CameraRail")
    }

    @ViewBuilder private var bottomRow: some View {
        if showsRecordRow {
            recordRow
        } else if phase == .review {
            // §2d Review: C-004 directly above the bottom row.
            VStack(spacing: Token.Space.elementGap) {
                ScrubTrack(
                    elapsed: state.reviewElapsed,
                    duration: state.reviewDuration,
                    dragging: state.reviewScrubbing,
                    onSeek: onReviewSeek,
                    onDraggingChange: onReviewScrubbingChange
                )
                .ui2Element("C-004 ScrubTrack")
                .padding(.horizontal, Token.Space.pageMargin)
                reviewRow
            }
        } else if phase == .trim {
            reviewSlot()
        }
    }

    /// §2c: C-013 `.video` record / stop centred, and pause bottom-leading while recording.
    private var recordRow: some View {
        ZStack(alignment: .bottom) {
            RecordButton(kind: isRecording || phase == .preRoll ? .stop : .record, size: .video, onTap: onRecord)
                .ui2Element("C-013 RecordButton")
                .padding(.bottom, Geometry.recordBottom)
                .frame(maxWidth: .infinity)
            if isRecording {
                RecordButton(kind: .pause, size: .video, onTap: onPause)
                    .ui2Element("C-013 RecordButton 2")
                    .padding(.leading, Geometry.pauseLeading)
                    .padding(.bottom, Geometry.pauseBottom)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            recordRowSlot()
        }
    }

    /// §2d Review: Edit + Filters (C-147 tools) leading, the app's row trailing (Retake / Save: C-105,
    /// not in §4 — not drawn). Without `onEdit`, Filters alone "exactly as before".
    @ViewBuilder private var reviewRow: some View {
        if let onEdit {
            HStack(alignment: .bottom, spacing: Token.Space.metaGap) {
                // OQ-video-recorder-45: the labels stay, so each tool takes its natural width.
                HStack(spacing: Geometry.reviewToolGap) {
                    RailTool(tool: .edit, onTap: onEdit)
                        .fixedSize(horizontal: true, vertical: false)
                        .ui2Element("C-147 RailTool")
                    filtersTool
                        .fixedSize(horizontal: true, vertical: false)
                        .ui2Element("C-147 RailTool 2")
                }
                .padding(.bottom, Geometry.reviewToolBottom)
                reviewSlot()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Token.Space.pageMargin)
        } else {
            ZStack(alignment: .bottom) {
                filtersTool
                    .ui2Element("C-147 RailTool")
                    .padding(.trailing, Token.Space.pageMargin)
                    .padding(.bottom, Geometry.reviewToolBottom)
                reviewSlot()
            }
        }
    }

    private var filtersTool: some View {
        RailTool(tool: .filters, active: look != .normal, onTap: { openSheet(.filters, tool: .filters) })
    }

    private func openSheet(_ next: State.Sheet, tool: RailTool.Tool) {
        sheet = next
        onRail(tool)
    }

    /// §3: the rail's Countdown tool opens the panel; again, it closes it.
    private func toggleCountdown() {
        if sheet == .countdown {
            sheet = .none
        } else {
            openSheet(.countdown, tool: .countdown)
        }
    }

    // MARK: - §2d sheets

    @ViewBuilder private func sheetLayer(previewRect: CGRect) -> some View {
        if mountedSheet != .none {
            VideoRecorderPanelSheet(
                visible: sheet == mountedSheet,
                startsShown: mountedAtRest,
                // C-150 insets its own rows.
                contentInset: mountedSheet == .filters ? 0 : Token.Space.pageMargin,
                bottomInset: sheetBottomInset,
                coversScreen: state.layout == .fullScreen,
                // Owner 2026-11-24 (video-polish D1, in part): Filters draws no dim, so the look can
                // be judged on the live picture.
                dims: mountedSheet != .filters,
                onDismiss: { sheet = .none },
                onHidden: sheetHidden,
                aboveDim: {
                    if mountedSheet == .countdown && showsRail {
                        // §2d Countdown: the rail stays tappable above the dim, where it was. Its
                        // natural width, so the dim beside it still takes the dismissing tap.
                        rail
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, Token.Space.pageMargin)
                            .frame(width: previewRect.width, height: previewRect.height, alignment: .trailing)
                            .padding(.top, previewRect.minY)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                },
                content: { sheetContent(mountedSheet) }
            )
            .id(mountedSheet)
        }
    }

    /// The slide-out ended: unmount it, or mount the sheet that replaced it.
    private func sheetHidden() {
        guard sheet != mountedSheet else { return }
        mountedAtRest = false
        mountedSheet = sheet
    }

    @ViewBuilder private func sheetContent(_ shown: State.Sheet) -> some View {
        switch shown {
        case .length:
            VideoRecorderLengthPanel(
                specifies: specifiesLength,
                length: state.length,
                endCountdown: State.PreRoll(rawValue: state.endCountdown) ?? .off,
                onModeChange: onLengthModeChange,
                onLengthChange: onLengthChange,
                onEndCountdownChange: { onEndCountdownChange($0.rawValue) }
            )
        case .countdown:
            countdownPanel
        case .filters:
            FilterStrip(
                selected: look,
                onSelect: { onFilterChange($0.name) },
                strength: state.strength,
                onStrengthChange: onStrengthChange,
                thumbnails: filterThumbnails,
                onDone: { sheet = .none }
            )
            .ui2Element("C-150 FilterStrip")
        case .teleprompter:
            TeleprompterBand(
                surface: .panel,
                script: state.script,
                textSize: teleprompterSize,
                speed: state.speed,
                onScriptChange: onScriptChange,
                onUseNote: onUseNote,
                onSpeedChange: onSpeedChange,
                onTextSizeChange: { onTextSizeChange($0.label) },
                onDone: { sheet = .none }
            )
            .ui2Element("C-151 TeleprompterBand")
        case .none:
            EmptyView()
        }
    }

    /// §2d Countdown panel: "both controls are drawn by this screen's sheet, not by a registry part".
    private var countdownPanel: some View {
        VStack(alignment: .leading, spacing: Token.Space.rowGap) {
            VideoRecorderPreRollChoice(caption: "Countdown", selected: preRoll, onSelect: onPreRollChange)
            soundRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: preRoll)
        .ui2Element("Countdown panel")
    }

    /// §2d: the Sound switch, "dimmed and not tappable while Countdown is Off".
    private var soundRow: some View {
        let enabled = preRoll != .off
        return Toggle(isOn: Binding(get: { state.countdownSound }, set: onCountdownSoundChange)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sound")
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(enabled ? Token.textPrimary : Token.white50)
                Text("Beeps each second. Silent when your phone is on silent.")
                    .designTextStyle(Token.TypeStyle.footnote)
                    .foregroundStyle(enabled ? Token.textSecondary : Token.white50)
            }
        }
        .toggleStyle(SoundSwitchStyle(animation: reduceMotion ? nil : Token.Motion.chipSelect))
        .disabled(!enabled)
        .ui2Element("Sound")
    }

    /// §2d Sound switch: the iOS switch's geometry in tokens — the system control's knob is drawn
    /// by the render server and comes out missing in a capture.
    private struct SoundSwitchStyle: ToggleStyle {
        let animation: Animation?

        /// GAP — video-recorder §2d: the iOS switch, 51 × 31 with a 27 pt knob inset 2; no size token.
        private static let track = CGSize(width: 51, height: 31)
        private static let knob: CGFloat = 27
        private static let knobInset: CGFloat = 2

        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            SwiftUI.Button { configuration.isOn.toggle() } label: {
                HStack(spacing: Token.Space.stackGap) {
                    configuration.label
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Capsule()
                        .fill(configuration.isOn ? Token.accent : Token.white20)
                        .frame(width: Self.track.width, height: Self.track.height)
                        .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                            Circle()
                                .fill(Token.textPrimary)
                                .frame(width: Self.knob, height: Self.knob)
                                .padding(Self.knobInset)
                        }
                        // §2d "dimmed", at C-147's disabled 50 % (`color-white-50`).
                        .opacity(isEnabled ? 1 : 0.5)
                        .animation(animation, value: configuration.isOn)
                        .ui2Element("Switch")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // One switch to VoiceOver: its own label, value and on/off action.
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        }
    }
}

// MARK: - Previews (one per §3 state; the device canvas, D22)

#Preview("Ready to record") {
    VideoRecorderScreen(state: .init(phase: .ready))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Pre-roll") {
    VideoRecorderScreen(state: .init(phase: .preRoll, countdownNumeral: 3, countdownValue: "3s"))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Recording") {
    VideoRecorderScreen(state: .init(phase: .recording, liveDuration: 1))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Paused") {
    VideoRecorderScreen(state: .init(phase: .paused, segments: [7.8, 7.0]))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("End countdown") {
    VideoRecorderScreen(state: .init(phase: .endCountdown, countdownNumeral: 10, segments: [42], liveDuration: 8))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Permission denied") {
    VideoRecorderScreen(state: .init(phase: .permissionDenied))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Review") {
    VideoRecorderScreen(
        state: .init(phase: .review, segments: [7.8, 7.0], reviewElapsed: 4, reviewDuration: 14.8),
        onEdit: {}
    )
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Review — full screen") {
    VideoRecorderScreen(
        state: .init(layout: .fullScreen, phase: .review, segments: [7.8, 7.0], reviewElapsed: 4, reviewDuration: 14.8),
        onEdit: {}
    )
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Trim") {
    VideoRecorderScreen(state: .init(phase: .trim))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Length sheet") {
    VideoRecorderScreen(state: .init(phase: .ready, lengthMode: "specify", sheet: .length))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Filters") {
    VideoRecorderScreen(state: .init(phase: .ready, filterLook: "Vivid", sheet: .filters))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Teleprompter panel") {
    VideoRecorderScreen(state: .init(phase: .ready, teleprompterOn: true, script: "Good morning, everyone. This week we're reading the Sermon on the Mount, starting in Matthew five. Before you press play on the first lesson, take a minute and ask yourself one question: what am I hoping to hear from God this week? Write it down. We'll come back to it on Friday.", sheet: .teleprompter))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Ready — full screen") {
    VideoRecorderScreen(state: .init(layout: .fullScreen, phase: .ready, teleprompterOn: true, script: "Good morning, everyone. This week we're reading the Sermon on the Mount, starting in Matthew five. Before you press play on the first lesson, take a minute and ask yourself one question: what am I hoping to hear from God this week? Write it down. We'll come back to it on Friday."))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Countdown panel — Off") {
    VideoRecorderScreen(state: .init(phase: .ready, sheet: .countdown))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Countdown panel — 3 s") {
    VideoRecorderScreen(state: .init(phase: .ready, countdownValue: "3s", sheet: .countdown))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Countdown panel — 10 s") {
    VideoRecorderScreen(state: .init(phase: .ready, countdownValue: "10s", sheet: .countdown))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Length sheet — Any length") {
    VideoRecorderScreen(state: .init(phase: .ready, sheet: .length))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Teleprompter panel — empty") {
    VideoRecorderScreen(state: .init(phase: .ready, sheet: .teleprompter))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Rail labels hidden") {
    VideoRecorderScreen(state: .init(phase: .ready, railLabelsVisible: false))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
