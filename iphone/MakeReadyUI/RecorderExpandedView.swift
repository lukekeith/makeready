//
//  RecorderExpandedView.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-018-recorder-expanded-view in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-018 RecorderExpandedView — the recorder sheet's expanded-detent content: `⋯` and Done,
/// the title with its start time and length, C-012's waveform under a fixed playhead, the big
/// timer and the pause/resume capsule. While the microphone is denied it shows a message with
/// Open Settings instead (memo-screens D11).
///
/// It fills the width AND the height it is given (§1 deviation 8, OQ-C-018-4) and paints no
/// background and no outer padding (R-16); the header row pads itself. The sheet's fill,
/// grabber and drag belong to C-016.
///
/// Controlled (R-01): `phase`, `elapsed` and `samples` are display-only, `menu` is a caller-owned
/// value with its change callbacks. No timer, audio, navigation or settings call (R-04/R-19).
struct RecorderExpandedView: View {

    /// §4 `phase` — which body the view draws (§2, §3).
    enum Phase {
        case recording
        case paused
        case micDenied
    }

    /// §4 `menu` — which C-066 card is over the view (OQ-C-018-2).
    enum Menu {
        case none
        case actions
        case discardConfirm
    }

    // MARK: - Props (§4, R-05 order)

    /// §4 `title` — the memo's title; one line, truncated. Required (R-07).
    let title: String
    /// §4 `startTime` — when recording started, already formatted by the caller. Required.
    let startTime: String
    /// §4 `elapsed` — seconds recorded; drives the big timer, the subtitle and C-012's ruler.
    let elapsed: TimeInterval
    /// §4 `samples` — levels 0…1, oldest first; passed straight to C-012.
    let samples: [Float]
    /// §4 `sampleTime` — the recording time the newest sample stands for; passed to C-012.
    /// Defaults to `0`, so callers that omit it keep C-012's still, stepped look.
    var sampleTime: Double = 0
    /// §4 `isRunning` — `true` while recording; passed to C-012. Defaults to `false`.
    var isRunning: Bool = false
    /// §4 `phase`. Required.
    let phase: Phase
    /// §4 `menu`. Required; the caller owns it (`onMore` → `.actions`, `onDiscardRequest` →
    /// `.discardConfirm`, `onDismissMenu` → `.none`).
    let menu: Menu
    /// §4 `onMore` — `⋯` tapped.
    var onMore: () -> Void = {}
    /// §4 `onDone` — Done tapped; the caller stops, saves and dismisses (D3).
    var onDone: () -> Void = {}
    /// §4 `onPause` — the capsule tapped while recording.
    var onPause: () -> Void = {}
    /// §4 `onResume` — the capsule tapped while paused.
    var onResume: () -> Void = {}
    /// §4 `onDiscardRequest` — "Discard recording" chosen in the menu.
    var onDiscardRequest: () -> Void = {}
    /// §4 `onDiscard` — Discard confirmed (D7).
    var onDiscard: () -> Void = {}
    /// §4 `onDismissMenu` — Cancel, Keep recording, or a scrim tap.
    var onDismissMenu: () -> Void = {}
    /// §4 `onOpenSettings` — Open Settings tapped (mic-denied, D11).
    var onOpenSettings: () -> Void = {}
    /// §4 `onClose` — the mic-denied close button (D11).
    var onClose: () -> Void = {}

    // MARK: - Geometry

    private enum Geometry {
        /// FLAGGED LITERAL — C-018 §2 FL-1: 44 pt circle (measured 131 px); no sizing token.
        static let circle: CGFloat = 44
        /// FLAGGED LITERAL — C-018 §2 FL-2: 156×60 pt capsule (measured 466×179 px).
        static let capsuleWidth: CGFloat = 156
        static let capsuleHeight: CGFloat = 60
        /// FLAGGED LITERAL — C-018 §2 FL-3: the drawn 24 pt record dot (OQ-C-018-6).
        static let recordDot: CGFloat = 24
        /// GAP — C-018 §2 items 1 and 11: "1 pt `color-white-10` stroke"; no stroke token.
        static let stroke: CGFloat = 1
        /// GAP — C-018 §2 Press feedback: "dim to 0.6 opacity while pressed" (as OQ-C-017-3);
        /// no opacity token.
        static let pressedOpacity: Double = 0.6
        /// GAP — C-018 §2 item 7: C-012 at "its own 432.33 pt intrinsic height" (a 400 pt pane +
        /// 32.33 pt caps and ruler); C-012 fills what it is given (OQ-C-012-6), so the height is
        /// passed here.
        static let waveformHeight: CGFloat = 1297.0 / 3.0
        /// GAP — C-018 §2 Phase micDenied: "one region of the same height (616.33)".
        static let micDeniedRegion: CGFloat = 1849.0 / 3.0
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch phase {
            case .recording, .paused:
                recorderBody
            case .micDenied:
                micDeniedBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // §2 Motion: a new elapsed/samples value re-renders without implicit animation.
        .transaction { $0.animation = nil }
        // §2 Menu overlays (OQ-C-018-2): C-066 over the whole component.
        .actionMenuPresentation(isPresented: menu != .none, onDismiss: onDismissMenu) {
            menuCard
        }
        .ui2Element("RecorderExpandedView")     // capture element map — UI2Element.swift
    }

    // MARK: - Recording / paused

    private var recorderBody: some View {
        VStack(spacing: 0) {
            // §2 items 1–9: header, title, subtitle, C-012 and the big timer, 48 between.
            VStack(spacing: Token.Space.step48) {
                VStack(spacing: Token.Space.elementGap) {
                    headerRow(leading: AnyView(moreButton), trailing: AnyView(doneButton))
                    VStack(spacing: Token.Space.metaGap) {
                        titleText
                        subtitle
                    }
                    .padding(.horizontal, Token.Space.pageMargin)
                }
                PlayheadWaveformView(
                    samples: samples,
                    elapsed: elapsed,
                    sampleTime: sampleTime,
                    isRunning: isRunning
                )
                    .frame(height: Geometry.waveformHeight)
                    .ui2Element("Waveform")
                bigTimer
            }
            // §2 item 10: flexible gap, at least `space-section-gap`.
            Spacer(minLength: Token.Space.sectionGap)
            pauseResumeButton
        }
    }

    /// §2 item 1: 44 tall, padded `space-page-margin` both sides.
    private func headerRow(leading: AnyView?, trailing: AnyView) -> some View {
        HStack(spacing: 0) {
            if let leading { leading }
            Spacer(minLength: 0)
            trailing
        }
        .frame(height: Geometry.circle)
        .padding(.horizontal, Token.Space.pageMargin)
        .ui2Element("Header")
    }

    /// §2 MoreButton: ringed 44 pt circle, `more-horizontal` 24 pt `color-text-secondary`.
    private var moreButton: some View {
        SwiftUI.Button(action: onMore) {
            Glyph(.moreHorizontal, size: .md, tint: Token.textSecondary)
                .accessibilityHidden(true)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .overlay(Circle().strokeBorder(Token.white10, lineWidth: Geometry.stroke))
                .contentShape(Circle())
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel("More options")
        .accessibilityAddTraits(.isButton)
        .ui2Element("MoreButton")
    }

    /// §2 DoneButton: 44 pt `color-accent` circle, `checkmark-carbon` 24 pt `color-text-primary`.
    private var doneButton: some View {
        SwiftUI.Button(action: onDone) {
            Glyph(.checkmarkCarbon, size: .md, tint: Token.textPrimary)
                .accessibilityHidden(true)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .background(Circle().fill(Token.accent))
                .contentShape(Circle())
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel("Done")
        .accessibilityHint("Saves the memo")
        .accessibilityAddTraits(.isButton)
        .ui2Element("DoneButton")
    }

    /// §2 item 3: `type-value-emphasis`, `color-text-primary`, one line, centred, tail-truncated.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.valueEmphasis)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
            .ui2Element("Title")
    }

    /// §2 item 5: `startTime`, `space-element-gap`, the whole-second length; `type-body-sm`,
    /// `color-text-secondary`, monospaced digits. Hidden from VoiceOver (the timer carries it).
    private var subtitle: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(startTime)
                .monospacedDigit()
            Text(Self.length(elapsed))
                .monospacedDigit()
        }
        .designTextStyle(Token.TypeStyle.bodySm)
        .foregroundStyle(Token.textSecondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
        .ui2Element("Subtitle")
    }

    /// §2 item 9: `type-calendar-date` (OQ-C-018-3), monospaced digits, centred.
    private var bigTimer: some View {
        Text(Self.timer(elapsed))
            .monospacedDigit()
            .designTextStyle(Token.TypeStyle.calendarDate)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("\(phase == .paused ? "Paused" : "Recording"), \(Self.spoken(elapsed))")
            .accessibilityAddTraits(.updatesFrequently)
            .ui2Element("Big timer")
    }

    /// §2 item 11: 156×60 ringed capsule; pause glyph while recording, the record dot while
    /// paused (OQ-C-018-6). The whole capsule is the hit target.
    private var pauseResumeButton: some View {
        let paused = phase == .paused
        return SwiftUI.Button(action: paused ? onResume : onPause) {
            Group {
                if paused {
                    Circle()
                        .fill(Token.error)
                        .frame(width: Geometry.recordDot, height: Geometry.recordDot)
                        .ui2Element("Record dot")
                } else {
                    Glyph(.pauseFilled, size: .md, tint: Token.error)
                        .ui2Element("Pause glyph")
                }
            }
            .accessibilityHidden(true)
            .frame(width: Geometry.capsuleWidth, height: Geometry.capsuleHeight)
            // A capsule as a circular rounded rectangle (radius = half its height): `Capsule()`'s
            // strokeBorder drew stray end segments in the capture render.
            .overlay(capsuleShape.strokeBorder(Token.white10, lineWidth: Geometry.stroke))
            .contentShape(capsuleShape)
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel(paused ? "Resume recording" : "Pause recording")
        .accessibilityAddTraits(.isButton)
        .ui2Element("PauseResumeButton")
    }

    private var capsuleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Geometry.capsuleHeight / 2, style: .circular)
    }

    // MARK: - Mic denied (OQ-C-018-5)

    private var micDeniedBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: Token.Space.elementGap) {
                headerRow(leading: nil, trailing: AnyView(
                    ModalCloseButton(onClose: onClose).ui2Element("CloseButton")
                ))
                titleText
                    .padding(.horizontal, Token.Space.pageMargin)
            }
            VStack(spacing: Token.Space.stackGap) {
                Glyph(.microphone, size: .lg, tint: Token.textSecondary)
                    .accessibilityHidden(true)
                    .ui2Element("Microphone glyph")
                Text("MakeReady needs microphone access to record")
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Token.Space.pageMargin)
                    .ui2Element("Message")
                Button(label: "Open Settings", onTap: onOpenSettings)
                    .ui2Element("Open Settings")
            }
            .frame(maxWidth: .infinity)
            .frame(height: Geometry.micDeniedRegion)
            .ui2Element("Message region")
            Spacer(minLength: 0)
        }
    }

    // MARK: - Menu overlays (OQ-C-018-2)

    @ViewBuilder private var menuCard: some View {
        switch menu {
        case .none, .actions:
            ActionMenuOverlay(
                actions: [.init(glyph: GlyphName.trash2.rawValue, label: "Discard recording", tone: .destructive)],
                doneLabel: "Cancel",
                onSelect: { _ in onDiscardRequest() },
                onDone: onDismissMenu
            )
        case .discardConfirm:
            ActionMenuOverlay(
                title: "Discard this recording?",
                actions: [.init(glyph: GlyphName.trash2.rawValue, label: "Discard", tone: .destructive)],
                doneLabel: "Keep recording",
                onSelect: { _ in onDiscard() },
                onDone: onDismissMenu
            )
        }
    }

    // MARK: - Formatting (pure, R-04)

    /// §2 item 5: whole seconds, `m:ss` under one hour, `h:mm:ss` from one hour, truncated.
    static func length(_ elapsed: TimeInterval) -> String {
        let total = Int(max(0, elapsed).rounded(.down))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// §2 item 9 (as C-017): `MM:SS.cc` under one hour, `HH:MM:SS.cc` from one hour, hundredths
    /// truncated, negative → `00:00.00`.
    static func timer(_ elapsed: TimeInterval) -> String {
        // The epsilon keeps a value like 9.25 from flooring to 924 through float error.
        let hundredths = Int((max(0, elapsed) * 100 + 1e-6).rounded(.down))
        let total = hundredths / 100, cc = hundredths % 100
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, cc)
            : String(format: "%02d:%02d.%02d", minutes, seconds, cc)
    }

    /// §2 Accessibility: the spoken elapsed for the timer's label ("9 seconds").
    static func spoken(_ elapsed: TimeInterval) -> String {
        spokenFormatter.string(from: max(0, elapsed).rounded(.down)) ?? length(elapsed)
    }

    private static let spokenFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .full
        return f
    }()

    /// §2 Press feedback (R-02, internal): dim while pressed, no scale.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? Geometry.pressedOpacity : 1)
        }
    }
}
