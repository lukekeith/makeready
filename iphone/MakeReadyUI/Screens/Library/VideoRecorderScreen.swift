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
/// TeleprompterBand, C-132 EmptyState, and the lessonInline host chrome C-040 PageHeader and
/// C-081 ActivityNavBar (deviation 3). §2's C-021 GlyphButton roles (close, import, undo, ✓) and
/// C-105 Button roles (Retake, Save) are NOT in §4's roll-call (§4: "they join the roll-call
/// with drawings once a frame draws them"), so this build draws none of them — a spec gap,
/// reported, never improvised. Standalone: `identifiedFrom` is null, so no D7 template applies.
struct VideoRecorderScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §5 `layout`.
        enum Layout: String {
            case lessonInline, fullScreen
        }

        /// §3 Phases (closed list — `State.phase`).
        enum Phase: String {
            case ready, preRoll, recording, paused, endCountdown, permissionDenied, review, trim
        }

        /// §3: "Sheets (Length, Filters, Teleprompter) open over `ready`/`paused`/`review` and
        /// are screen-local presentation state" — this seeds it; "" = none.
        enum Sheet: String {
            case none = "", length, filters, teleprompter
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
        /// §5 `length` — the chosen length in seconds (D3: 10…120, default 60).
        var length: Double = 60
        /// §5 `countdown` as the rail shows it: "" Off, "3s", "10s" (D2).
        var countdownValue: String = ""
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
    /// §3: each rail tool — the container flips, cycles the countdown, etc.
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

    // §3 UI-only rule: "Sheets (Length, Filters, Teleprompter) … are screen-local presentation
    // state" (R-31).
    @SwiftUI.State private var sheet: State.Sheet

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
        feed: CameraPreview<AnyView>.Feed? = nil,
        hostChrome: Bool = true,
        teleprompterOffset: CGFloat = 0,
        filterThumbnails: [FilterStrip.Look: Image] = [:],
        fillsHeight: Bool = false,
        sheetBottomInset: CGFloat = 0,
        previewSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        recordRowSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        reviewSlot: @escaping () -> AnyView = { AnyView(EmptyView()) },
        onEdit: (() -> Void)? = nil
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
        _sheet = SwiftUI.State(initialValue: state.sheet)
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

    /// §2c CameraRail: ready, paused; §2d: hidden while a sheet is open.
    private var showsRail: Bool { (phase == .ready || phase == .paused) && sheet == .none }

    /// §2c SegmentedProgressBar: every camera phase; §2d Length: "rail, bar and record row hide".
    private var showsProgress: Bool { isCameraPhase && sheet != .length }

    /// §2c RecordButton: "always except permissionDenied, review, trim"; §2d: the Length sheet
    /// hides the record row and Filters takes its place.
    private var showsRecordRow: Bool {
        isCameraPhase && sheet != .length && sheet != .filters
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

    /// C-146 `lengthValue` — D3: "shows the value as `m:ss`".
    private var lengthValue: String {
        let total = max(Int(state.length.rounded()), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
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
        // §2d: the Length sheet and the Teleprompter panel — house overlay chrome over the page.
        .overlay(alignment: .bottom) { sheetContent }
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
            if sheet == .length {
                // §2d Length: "the preview dims behind it" — house overlay chrome.
                // A tap outside closes it: C-149 has no Done.
                Token.scrim
                    .onTapGesture { sheet = .none }
            }
        }
    }

    @ViewBuilder private var cameraOverlays: some View {
        // Top: bar, timer, teleprompter band (§2c).
        VStack(spacing: 0) {
            if showsProgress {
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
        if showsRail {
            CameraRail(
                countdownValue: state.countdownValue.isEmpty ? nil : state.countdownValue,
                lengthValue: lengthValue,
                // D3: "It cannot change once the first segment is recorded."
                lengthEnabled: state.segments.isEmpty,
                filtersActive: look != .normal,
                teleprompterActive: state.teleprompterOn,
                onFlip: { onRail(.flip) },
                onCountdown: { onRail(.countdown) },
                onLength: { openSheet(.length, tool: .length) },
                onFilters: { openSheet(.filters, tool: .filters) },
                onTeleprompter: { openSheet(.teleprompter, tool: .teleprompter) }
            )
            .ui2Element("C-146 CameraRail")
            .padding(.trailing, Token.Space.pageMargin)
        }

        if phase == .preRoll || phase == .endCountdown {
            CountdownNumerals(
                value: state.countdownNumeral,
                phase: phase == .preRoll ? .preRoll : .ending
            )
            .ui2Element("C-148 CountdownNumerals")
        }

        // Bottom: the record row, or the Filters strip in its place (§2d).
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bottomRow
        }
    }

    @ViewBuilder private var bottomRow: some View {
        if sheet == .filters && (isCameraPhase || phase == .review) {
            // §2d Filters: C-150 "laid over the bottom of the preview in place of the record row".
            FilterStrip(
                selected: look,
                onSelect: { onFilterChange($0.name) },
                strength: state.strength,
                onStrengthChange: onStrengthChange,
                thumbnails: filterThumbnails,
                onDone: { sheet = .none }
            )
            .ui2Element("C-150 FilterStrip")
        } else if showsRecordRow {
            recordRow
        } else if phase == .review {
            reviewRow
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

    // MARK: - §2d sheets (house overlay chrome)

    @ViewBuilder private var sheetContent: some View {
        switch sheet {
        case .length:
            sheetSurface {
                LengthSlider(length: state.length, onChange: onLengthChange)
                    .ui2Element("C-149 LengthSlider")
            }
        case .teleprompter:
            sheetSurface {
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
            }
        case .filters, .none:
            EmptyView()
        }
    }

    /// The house sheet surface (ActionMenuOverlay's): `color-modal-background`, `radius-modal`
    /// top corners, `space-page-margin` inset.
    private func sheetSurface(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(Token.Space.pageMargin)
            .padding(.bottom, sheetBottomInset)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: Token.Radius.modal,
                    topTrailingRadius: Token.Radius.modal,
                    style: .continuous
                )
                .fill(Token.modalBackground)
            )
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
    VideoRecorderScreen(state: .init(phase: .review, segments: [7.8, 7.0]), onEdit: {})
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
    VideoRecorderScreen(state: .init(phase: .ready, sheet: .length))
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
