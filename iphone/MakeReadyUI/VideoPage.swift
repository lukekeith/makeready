//
//  VideoPage.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-135-video-page in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-135 §2's literal geometry, measured on the recording's 440 × 956 screen. Sizes and side insets
/// are fixed points that do not scale with the page's `u` (§2). File scope because `VideoPage` is
/// generic, and a generic type cannot hold static stored properties.
private enum VideoPageGeometry {
    /// FLAGGED LITERAL — C-135 §2: the gradient spans 25 % of the page's height.
    static let gradientHeightFraction: CGFloat = 0.25
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-003: the band starts `bottomInset` + 140 above the bottom.
    static let bandAboveInset: CGFloat = 140
    /// FLAGGED LITERAL — C-135 §2: the caption box's centre sits at 68.4 % of the page's height.
    static let captionCentreFraction: CGFloat = 0.684
    /// FLAGGED LITERAL — C-135 §2: 9 pt side padding in the caption box.
    static let captionSidePadding: CGFloat = 9
    /// FLAGGED LITERAL — C-135 §2: 1 pt top and bottom padding in the caption box.
    static let captionVerticalPadding: CGFloat = 1
    /// FLAGGED LITERAL — C-135 §2: the 29 pt pitch less SF Pro 19's natural 22.67 pt line.
    static let captionLeading: CGFloat = 6.33
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-008: SF Pro Regular 19, no type token.
    static let captionStyle = DesignTextStyle(weight: .regular, size: 19, lineHeight: 19 + captionLeading, tracking: 0)
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-008: SF Pro Regular 15, no type token.
    static let timeStyle = DesignTextStyle(weight: .regular, size: 15, lineHeight: nil, tracking: 0)
    /// FLAGGED LITERAL — C-135 §2: the presenter row's centre, `bottomInset` + 74 above the bottom (y 848).
    static let presenterAboveInset: CGFloat = 74
    /// FLAGGED LITERAL — C-135 §2: the presenter row's leading edge.
    static let presenterLeading: CGFloat = 17
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-001: a 38 pt photo.
    static let avatar: CGFloat = 38
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-001: inside a 2 pt ring, 42 outer.
    static let avatarRing: CGFloat = 2
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-003: the control row's centre, `bottomInset` + 22 above the bottom.
    static let controlsAboveInset: CGFloat = 22
    /// FLAGGED LITERAL — C-135 §2: the remaining time's leading edge.
    static let timeLeading: CGFloat = 18
    /// FLAGGED LITERAL — C-135 §2: 6 pt from the time to the track.
    static let timeToTrack: CGFloat = 6
    /// FLAGGED LITERAL — C-135 §2: 4 pt from the track to the play button.
    static let trackToButton: CGFloat = 4
    /// FLAGGED LITERAL — C-135 §2: the play button's trailing edge.
    static let buttonTrailing: CGFloat = 10
    /// FLAGGED LITERAL — C-135 §2: the play button's 44 pt hit frame.
    static let button: CGFloat = 44
    /// FLAGGED LITERAL — C-135 §2: the pause glyph's box; its ink is about 25.5 × 30.
    static let pauseGlyph: CGFloat = 30
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-007: the play glyph's box, so its ink is also 30 tall.
    static let playGlyph: CGFloat = 40
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-007: the play button dims to 60 % while pressed.
    static let pressedOpacity: Double = 0.6
    /// FLAGGED LITERAL — C-135 §2: the 6 pt track.
    static let track: CGFloat = 6
    /// FLAGGED LITERAL — C-135 §2: the 8 pt thumb.
    static let thumb: CGFloat = 8
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-005: the scrubber's 44 pt touch band.
    static let scrubBand: CGFloat = 44
    /// FLAGGED LITERAL — C-135 §2: VoiceOver moves the position by 0.05.
    static let adjustStep: Double = 0.05
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-006: the buffering spinner's 40 pt ring.
    static let spinner: CGFloat = 40
    /// FLAGGED LITERAL — C-135 §2, OQ-C-135-006: the buffering spinner's 3 pt stroke.
    static let spinnerStroke: CGFloat = 3
}

/// C-135 VideoPage — one viewport-tall video page of the stitched viewer: the host's video, with
/// captions, presenter and playback controls laid over it.
///
/// Pure and controlled (R-01, R-04, R-19): the host resolves the cue, time and position and owns all
/// of playback; the view emits what the finger or VoiceOver asks for. It fills the width and height
/// it is given and paints its own black ground (OQ-C-135-004, carved out of R-16). Only the scrubber
/// band and the play button take touches, so the pager keeps a drag that starts anywhere else (§2).
struct VideoPage<Video: View>: View {

    /// C-135 §4 `video` — the §2 slot (R-08): the host's player or poster.
    @ViewBuilder let video: () -> Video
    /// C-135 §4 `captionLines` — the current cue's lines, 0 to 2. Empty shows no box.
    let captionLines: [String]
    /// C-135 §4 `presenterName`.
    let presenterName: String
    /// C-135 §4 `presenterImageURL` — passed to C-038 `imageURL`.
    let presenterImageURL: URL?
    /// C-135 §4 `presenterInitials` — passed to C-038 `initials`.
    let presenterInitials: String?
    /// C-135 §4 `reference` — the line under the name.
    let reference: String
    /// C-135 §4 `remainingTime` — already formatted.
    let remainingTime: String
    /// C-135 §4 `progress` — playback position, 0 to 1.
    let progress: Double
    /// C-135 §4 `playing` — picks the glyph.
    let playing: Bool
    /// C-135 §4 `buffering` — shows the spinner.
    let buffering: Bool
    /// C-135 §4 `bottomInset` — the host's bottom safe-area inset (OQ-C-135-003).
    let bottomInset: CGFloat
    /// C-135 §4 `onProgressChange` — the position asked for, continuous during a drag.
    var onProgressChange: (Double) -> Void = { _ in }
    /// C-135 §4 `onScrubbingChange` — true when a scrub starts, false when it ends.
    var onScrubbingChange: (Bool) -> Void = { _ in }
    /// C-135 §4 `onPlayingChange` — the play button asks for the opposite of `playing`.
    var onPlayingChange: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { page in
            let width = page.size.width
            let height = page.size.height

            // §2 Layers, bottom to top.
            ZStack {
                Token.black100
                    .allowsHitTesting(false)
                    .ui2Element("Ground")

                video()
                    .frame(width: width, height: height)
                    .clipped()
                    .allowsHitTesting(false)
                    .ui2Element("Video")

                legibilityLayers(width: width, height: height)

                if !captionLines.isEmpty {
                    captionBox(pageWidth: width)
                        .position(x: width / 2, y: height * VideoPageGeometry.captionCentreFraction)
                }

                presenterRow
                    .frame(width: width)
                    .position(x: width / 2, y: height - bottomInset - VideoPageGeometry.presenterAboveInset)

                controlRow
                    .frame(width: width)
                    .position(x: width / 2, y: height - bottomInset - VideoPageGeometry.controlsAboveInset)

                if buffering {
                    spinner
                        .position(x: width / 2, y: height / 2)
                }
            }
        }
        .ui2Element("VideoPage")
    }

    /// §2 Bottom gradient and solid band: the gradient ends where the band starts.
    @ViewBuilder
    private func legibilityLayers(width: CGFloat, height: CGFloat) -> some View {
        let bandHeight = bottomInset + VideoPageGeometry.bandAboveInset
        let bandTop = height - bandHeight
        let gradientHeight = height * VideoPageGeometry.gradientHeightFraction

        LinearGradient(
            colors: [Token.black100.opacity(0), Token.black100],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: gradientHeight)
        .ui2Element("Bottom gradient")
        .position(x: width / 2, y: bandTop - gradientHeight / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)

        Token.black100
            .frame(width: width, height: bandHeight)
            .ui2Element("Solid band")
            .position(x: width / 2, y: bandTop + bandHeight / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// §2 Caption box: hugs its text, capped at the page width less the margins; a long line wraps
    /// and the box grows around its centre (OQ-C-135-009). Both lines paint white (OQ-C-135-002).
    private func captionBox(pageWidth: CGFloat) -> some View {
        VStack(spacing: VideoPageGeometry.captionLeading) {
            ForEach(captionLines.indices, id: \.self) { index in
                Text(captionLines[index])
                    .designTextStyle(VideoPageGeometry.captionStyle)
                    .foregroundStyle(Token.white100)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .ui2Element("Caption line \(index + 1)")
            }
        }
        .padding(.horizontal, VideoPageGeometry.captionSidePadding)
        .padding(.vertical, VideoPageGeometry.captionVerticalPadding)
        .background(Token.black50, in: RoundedRectangle(cornerRadius: Token.Radius.cardSm))
        .ui2Element("Caption box")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captionLines.joined(separator: " "))
        .frame(maxWidth: pageWidth - 2 * Token.Space.pageMargin)
        .allowsHitTesting(false)
    }

    /// §2 Presenter row: C-038 in a ring this component owns, then name and reference.
    private var presenterRow: some View {
        HStack(spacing: Token.Space.elementGap) {
            Avatar(imageURL: presenterImageURL, initials: presenterInitials, size: VideoPageGeometry.avatar)
                .padding(VideoPageGeometry.avatarRing)
                .overlay(Circle().strokeBorder(Token.white100, lineWidth: VideoPageGeometry.avatarRing))
                .ui2Element("Presenter avatar")

            VStack(alignment: .leading, spacing: Token.Space.metaGap) {
                Text(presenterName)
                    .designTextStyle(Token.TypeStyle.calloutBold)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .ui2Element("Presenter name")

                Text(reference)
                    .designTextStyle(Token.TypeStyle.byline)
                    .foregroundStyle(Token.white80)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .ui2Element("Reference")
            }

            Spacer(minLength: 0)
        }
        .ui2Element("Presenter row")
        .padding(.leading, VideoPageGeometry.presenterLeading)
        .padding(.trailing, Token.Space.pageMargin)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presenterName), \(reference)")
    }

    /// §2 Control row: remaining time, scrubber, play button.
    private var controlRow: some View {
        HStack(spacing: 0) {
            // The scrubber's accessibility value already speaks the time (§2).
            Text(remainingTime)
                .monospacedDigit()
                .designTextStyle(VideoPageGeometry.timeStyle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityHidden(true)
                .ui2Element("Remaining time")
                .padding(.leading, VideoPageGeometry.timeLeading)
                .padding(.trailing, VideoPageGeometry.timeToTrack)
                .allowsHitTesting(false)

            VideoPageScrubber(
                progress: progress,
                remainingTime: remainingTime,
                onProgressChange: onProgressChange,
                onScrubbingChange: onScrubbingChange
            )

            playButton
                .padding(.leading, VideoPageGeometry.trackToButton)
                .padding(.trailing, VideoPageGeometry.buttonTrailing)
        }
        .ui2Element("Control row")
    }

    /// §2 Play button: `pause-filled` while playing, `play-filled-alt-carbon` otherwise. The swap is
    /// immediate; the only motion is the press dim (OQ-C-135-007).
    private var playButton: some View {
        SwiftUI.Button {
            onPlayingChange(!playing)
        } label: {
            Image((playing ? GlyphName.pauseFilled : GlyphName.playFilledAltCarbon).rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: playing ? VideoPageGeometry.pauseGlyph : VideoPageGeometry.playGlyph,
                    height: playing ? VideoPageGeometry.pauseGlyph : VideoPageGeometry.playGlyph
                )
                .foregroundStyle(Token.white100)
                .accessibilityHidden(true)
                .ui2Element(playing ? "Pause glyph" : "Play glyph")
        }
        .buttonStyle(VideoPagePlayButtonStyle())
        .accessibilityLabel(playing ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
        .ui2Element("Play button")
    }

    /// §2 Spinner: C-076 at the ruled size and colour (OQ-C-135-006). C-076 hides itself from
    /// accessibility and expects its consumer to label the region.
    private var spinner: some View {
        ActivitySpinner(
            size: VideoPageGeometry.spinner,
            strokeWidth: VideoPageGeometry.spinnerStroke,
            color: Token.white100
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Buffering")
        .ui2Element("Spinner")
    }
}

/// §2 Track, Progress and Thumb, with the touch band over them (inline, OQ-C-135-010). The two
/// `@State`-like values are gesture bookkeeping (R-02); the position itself is always the prop.
private struct VideoPageScrubber: View {
    let progress: Double
    let remainingTime: String
    let onProgressChange: (Double) -> Void
    let onScrubbingChange: (Bool) -> Void

    /// Resets on lift AND on a cancelled touch, so the host always hears the scrub end.
    @GestureState private var touching = false
    @State private var scrubbing = false

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { band in
            let width = band.size.width
            let thumbCentre = width * clampedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Token.white50)
                    .frame(height: VideoPageGeometry.track)
                    .ui2Element("Track")

                Capsule()
                    .fill(Token.white100)
                    .frame(width: thumbCentre, height: VideoPageGeometry.track)
                    .ui2Element("Progress")

                Circle()
                    .fill(Token.white100)
                    .frame(width: VideoPageGeometry.thumb, height: VideoPageGeometry.thumb)
                    .ui2Element("Thumb")
                    .offset(x: thumbCentre - VideoPageGeometry.thumb / 2)
            }
            .frame(width: width, height: band.size.height)
            .contentShape(Rectangle())
            .gesture(
                // pan-ok: the scrubber claims the touch and seeks on touch-down (C-135 §2, 01 §5)
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { drag in
                        if !scrubbing {
                            scrubbing = true
                            onScrubbingChange(true)
                        }
                        onProgressChange(min(max(drag.location.x / max(width, 1), 0), 1))
                    }
            )
        }
        .frame(height: VideoPageGeometry.scrubBand)
        .onChange(of: touching) { _, isTouching in
            guard !isTouching, scrubbing else { return }
            scrubbing = false
            onScrubbingChange(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(remainingTime) remaining")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onProgressChange(min(clampedProgress + VideoPageGeometry.adjustStep, 1))
            case .decrement:
                onProgressChange(max(clampedProgress - VideoPageGeometry.adjustStep, 0))
            @unknown default:
                break
            }
        }
    }
}

/// §2 Play button: the 44 pt hit frame and the press dim (R-02, R-11).
private struct VideoPagePlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: VideoPageGeometry.button, height: VideoPageGeometry.button)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? VideoPageGeometry.pressedOpacity : 1)
    }
}
