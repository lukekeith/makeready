//
//  VideoEditorTimeline.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-153-videoeditortimeline in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-153 VideoEditorTimeline — "Editor timeline: play/pause, seconds ruler, fixed centre playhead,
/// video filmstrip, scrub by dragging; hosts the layer tracks."
///
/// §2: a 44 pt header (play/pause, time label, ruler), a 4 pt gap and a 219 pt body (the tracks
/// slot over the filmstrip) = 267 pt. The playhead stays at width / 2 and the timeline moves
/// under it: time t is drawn at `x = width/2 + (t − playhead) × 40`.
///
/// Controlled (R-01): it displays `playing` and `playheadMs` and never holds them; the only
/// internal state is a drag in flight (R-02). It owns no player and no layers (R-04).
/// Width-driven, chrome-free (R-16).
struct VideoEditorTimeline<Tracks: View>: View {
    /// §4: pause glyph when true, play when false.
    let playing: Bool
    /// §4: play/pause tapped; the caller plays, pauses, or restarts at the end (D23).
    var onPlayPause: () -> Void = {}
    /// §4: time under the playhead, ms from the kept window's start (D20); clamped to 0…`durationMs`.
    let playheadMs: Int
    /// §4: each new playhead time while dragging, or an accessibility step.
    var onScrub: (Int) -> Void = { _ in }
    /// §4: the clip's length in ms, up to 120000 (P4).
    let durationMs: Int
    /// §4: frames in time order, evenly spaced, resolved by the caller; empty draws the placeholder.
    let filmstrip: [Image]
    /// §4: the §2 slot — C-154 rows (R-08, OQ-C-153-1).
    @ViewBuilder let tracks: () -> Tracks

    /// R-02 ephemeral: the playhead at touch-down of the drag in flight (nil = not dragging).
    @State private var dragStartMs: Int?
    /// R-02 ephemeral: the time last reported by this drag, so each change is reported once.
    @State private var dragReportedMs: Int?

    private typealias Geometry = VideoEditorTimelineGeometry

    private var duration: Int { max(durationMs, 0) }
    private var playhead: Int { min(max(playheadMs, 0), duration) }
    private var playheadSeconds: CGFloat { CGFloat(playhead) / 1000 }
    private var contentWidth: CGFloat { CGFloat(duration) / 1000 * Geometry.pointsPerSecond }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                scrubElement
                VStack(spacing: Token.Space.metaGap) {
                    header(width: width)
                    timelineBody(width: width)
                }
                playheadLine(width: width)
            }
            .frame(width: width, height: Geometry.height, alignment: .topLeading)
            // §2: "Everything is clipped at the component's left and right edges."
            .clipped()
            .contentShape(Rectangle())
            // §2 Gestures: axis-locked, no momentum (OQ-C-153-3). A row's own gesture is deeper and wins.
            .horizontalPan(onChanged: scrub, onEnded: { _ in endScrub() })
            // Above the pan, so a tap is the button's.
            .overlay(alignment: .topLeading) { playPauseButton }
        }
        .frame(height: Geometry.height)
        .ui2Element("VideoEditorTimeline")
    }

    // MARK: - Header (§2 y 0–44)

    private func header(width: CGFloat) -> some View {
        VideoEditorRulerLayout(playheadSeconds: playheadSeconds) {
            timeLabel
            ForEach(visibleHalfSeconds(width: width), id: \.self) { half in
                tick(half: half)
                    .layoutValue(key: VideoEditorTickSeconds.self, value: CGFloat(half) / 2)
            }
        }
        .frame(width: width, height: Geometry.headerHeight)
        .accessibilityHidden(true)
        .ui2Element("Header")
    }

    /// §2 Time label: `m:ss / m:ss`, whole seconds rounded down, monospaced digits.
    private var timeLabel: some View {
        Text("\(Self.clock(playhead)) / \(Self.clock(duration))")
            .designTextStyle(Token.TypeStyle.captionBold)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Token.textPrimary)
            .ui2Element("Time label")
    }

    /// §2 Ruler: a label on each second, a dot on each half second.
    @ViewBuilder private func tick(half: Int) -> some View {
        if half.isMultiple(of: 2) {
            Text("\(half / 2)s")
                .designTextStyle(Token.TypeStyle.caption)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Token.textSecondary)
                .ui2Element("Ruler label \(half / 2)s")
        } else {
            Circle()
                .fill(Token.textSecondary)
                .frame(width: Geometry.dotDiameter, height: Geometry.dotDiameter)
                .ui2Element("Ruler dot \(half / 2).5s")
        }
    }

    /// The half seconds on screen, plus one second each side for a label part-way off an edge.
    /// §2: from 0.5 s (no "0s"), and on past the clip's end to the trailing edge.
    private func visibleHalfSeconds(width: CGFloat) -> ClosedRange<Int> {
        let reach = max(width, 0) / 2 / Geometry.pointsPerSecond + 1
        let first = max(Int(((playheadSeconds - reach) * 2).rounded(.down)), 1)
        let last = max(Int(((playheadSeconds + reach) * 2).rounded(.up)), first)
        return first...last
    }

    private var playPauseButton: some View {
        SwiftUI.Button(action: onPlayPause) {
            ZStack {
                // `radius-circle` is 50 %, not a point value — the disc is a Circle() (C-149).
                Circle()
                    .fill(Token.white10)
                    .frame(width: Geometry.discDiameter, height: Geometry.discDiameter)
                    .ui2Element("Play/pause disc")
                Image((playing ? GlyphName.pauseFilled : GlyphName.playFilledAltCarbon).rawValue, bundle: .ui2Preview)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Geometry.glyphSize, height: Geometry.glyphSize)
                    .foregroundStyle(Token.textPrimary)
                    .ui2Element(playing ? "Pause glyph" : "Play glyph")
            }
            .frame(width: Geometry.headerHeight, height: Geometry.headerHeight)
            .contentShape(Rectangle())
            // §2 Motion: the glyph swaps without animation.
            .transaction(value: playing) { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
        .ui2Element("Play/pause")
        // The 44 pt hit area is centred on the 40 pt disc, whose leading edge is the page margin.
        .padding(.leading, Token.Space.pageMargin - (Geometry.headerHeight - Geometry.discDiameter) / 2)
    }

    // MARK: - Body (§2 y 48–267)

    private func timelineBody(width: CGFloat) -> some View {
        VideoEditorBodyLayout {
            trackRows(width: width)
            filmstripRow(width: width)
        }
        .frame(width: width, height: Geometry.bodyHeight, alignment: .topLeading)
        .ui2Element("Body")
    }

    /// §2 Tracks slot: content width, leading edge at t = 0, rows `space-element-gap` apart. The
    /// scroll view spans the component, so a row's end handles may pass t = 0 and the duration.
    private func trackRows(width: CGFloat) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: Token.Space.elementGap) { tracks() }
                .frame(width: contentWidth)
                .padding(.leading, contentLeading(width: width))
                .frame(width: width, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .ui2Element("Tracks")
    }

    /// §2 Filmstrip: 55 pt, content width, leading edge at t = 0.
    private func filmstripRow(width: CGFloat) -> some View {
        VideoEditorFilmstrip(images: filmstrip, width: contentWidth)
            .equatable()
            .padding(.leading, contentLeading(width: width))
            .frame(width: width, alignment: .leading)
            .accessibilityHidden(true)
    }

    /// Where t = 0 is drawn.
    private func contentLeading(width: CGFloat) -> CGFloat {
        width / 2 - playheadSeconds * Geometry.pointsPerSecond
    }

    /// §2 Playhead: 1 pt at width / 2, y 44–267, above everything in the body, not hit-testable.
    private func playheadLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(Token.textPrimary)
            .frame(width: Geometry.playheadWidth, height: Geometry.height - Geometry.headerHeight)
            .ui2Element("Playhead")
            .padding(.leading, (width - Geometry.playheadWidth) / 2)
            .padding(.top, Geometry.headerHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Scrubbing

    private func scrub(_ pan: HorizontalPanValue) {
        let start = dragStartMs ?? playhead
        if dragStartMs == nil { dragStartMs = start }
        let moved = Int((pan.translation / Geometry.pointsPerSecond * 1000).rounded())
        let next = min(max(start - moved, 0), duration)
        guard next != (dragReportedMs ?? start) else { return }
        dragReportedMs = next
        onScrub(next)
    }

    private func endScrub() {
        dragStartMs = nil
        dragReportedMs = nil
    }

    /// §2 Accessibility (R-17): one adjustable element over the scrub area, ±1 s per step.
    private var scrubElement: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityLabel("Playhead")
            .accessibilityValue("\(Self.clock(playhead)) of \(Self.clock(duration))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onScrub(min(playhead + 1000, duration))
                case .decrement: onScrub(max(playhead - 1000, 0))
                @unknown default: break
                }
            }
    }

    private static func clock(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        let remainder = seconds % 60
        return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}

extension VideoEditorTimeline where Tracks == EmptyView {
    /// §4 constant, shared with the host's rows: a bar starts at `startMs / 1000 × pointsPerSecond`.
    /// Computed and constrained because a generic type holds no static stored property; the
    /// constraint lets callers write `VideoEditorTimeline.pointsPerSecond`.
    static var pointsPerSecond: CGFloat { VideoEditorTimelineGeometry.pointsPerSecond }
}

// MARK: - Geometry

private enum VideoEditorTimelineGeometry {
    /// FLAGGED LITERAL — C-153 §2 FL-1: 40 pt per second, no token.
    static let pointsPerSecond: CGFloat = 40
    /// FLAGGED LITERAL — C-153 §2 FL-2: 40 disc, no token.
    static let discDiameter: CGFloat = 40
    /// FLAGGED LITERAL — C-153 §2 FL-3: 18 glyph, no token.
    static let glyphSize: CGFloat = 18
    /// FLAGGED LITERAL — C-153 §2 FL-4: 2 dot, no token.
    static let dotDiameter: CGFloat = 2
    /// FLAGGED LITERAL — C-153 §2 FL-5: 55 filmstrip, no token.
    static let filmstripHeight: CGFloat = 55
    /// FLAGGED LITERAL — C-153 §2 FL-6: 1 playhead, no token.
    static let playheadWidth: CGFloat = 1
    /// FLAGGED LITERAL — C-153 §2 FL-7: 44 header and hit area, no token.
    static let headerHeight: CGFloat = 44
    /// FLAGGED LITERAL — C-153 §2 FL-8: 148 tracks maximum, no token.
    static let tracksMaximum: CGFloat = 148
    /// FLAGGED LITERAL — C-153 §2 FL-9: 267 height, no token.
    static let height: CGFloat = 267
    /// §2: 267 − 44 − 4 = 219.
    static var bodyHeight: CGFloat { height - headerHeight - Token.Space.metaGap }
}

// MARK: - Filmstrip

/// §2 Filmstrip: the images share the width equally, each aspect-filled and clipped; with none, a
/// `color-white-10` strip (OQ-C-153-4). Equatable, so its frames are not rebuilt on every tick.
private struct VideoEditorFilmstrip: View, Equatable {
    let images: [Image]
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            if images.isEmpty {
                Token.white10
            } else {
                ForEach(images.indices, id: \.self) { index in
                    Color.clear
                        .overlay {
                            images[index]
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .ui2Element("Frame \(index + 1)")
                }
            }
        }
        .frame(width: width, height: VideoEditorTimelineGeometry.filmstripHeight)
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        .ui2Element("Filmstrip")
    }
}

// MARK: - Layouts

/// The second a ruler tick sits on; nil marks the time label.
private struct VideoEditorTickSeconds: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

/// §2 Ruler: centres each tick on its second and the time label at width / 2. A layout, so ruler
/// hiding uses the label's real measured width in the same pass.
private struct VideoEditorRulerLayout: Layout {
    let playheadSeconds: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let disc = VideoEditorTimelineGeometry.discDiameter
        // §2 Ruler hiding: the disc and the time label, each grown by `space-element-gap`.
        var keepOut = [grown(CGRect(
            x: bounds.minX + Token.Space.pageMargin, y: bounds.midY - disc / 2, width: disc, height: disc
        ))]
        for subview in subviews where subview[VideoEditorTickSeconds.self] == nil {
            let size = subview.sizeThatFits(.unspecified)
            keepOut.append(grown(frame(size, centreX: bounds.midX, centreY: bounds.midY)))
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
        }
        for subview in subviews {
            guard let seconds = subview[VideoEditorTickSeconds.self] else { continue }
            let x = bounds.midX + (seconds - playheadSeconds) * VideoEditorTimelineGeometry.pointsPerSecond
            let rect = frame(subview.sizeThatFits(.unspecified), centreX: x, centreY: bounds.midY)
            let hidden = keepOut.contains { touches($0, rect) }
            // A hidden tick is laid out far outside the component's clip, so it is not drawn.
            let y = hidden ? bounds.minY - VideoEditorTimelineGeometry.height * 2 : bounds.midY
            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)
        }
    }

    private func grown(_ rect: CGRect) -> CGRect {
        rect.insetBy(dx: -Token.Space.elementGap, dy: -Token.Space.elementGap)
    }

    private func frame(_ size: CGSize, centreX: CGFloat, centreY: CGFloat) -> CGRect {
        CGRect(x: centreX - size.width / 2, y: centreY - size.height / 2, width: size.width, height: size.height)
    }

    /// Edge contact counts: §2 hides a tick whose frame touches.
    private func touches(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX <= b.maxX && b.minX <= a.maxX && a.minY <= b.maxY && b.minY <= a.maxY
    }
}

/// §2 Body: the tracks take their rows' height up to 148 pt, then the filmstrip sits
/// `space-stack-gap` under them; with no rows the slot and its gap take no space.
private struct VideoEditorBodyLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let ideal = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let tracksHeight = min(ideal, VideoEditorTimelineGeometry.tracksMaximum)
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: tracksHeight)
        )
        let top = tracksHeight > 0 ? tracksHeight + Token.Space.stackGap : 0
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + top),
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
    }
}
