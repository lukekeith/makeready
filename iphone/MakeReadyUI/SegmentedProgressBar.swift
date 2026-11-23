//
//  SegmentedProgressBar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-145-segmentedprogressbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-145 SegmentedProgressBar — the recorder's length bar.
///
/// A thin capsule whose full width is the chosen length (SPEC D3). Each finished segment fills its
/// fraction in `color-record`, followed by a 2 pt clear gap when more fill follows (OQ-C-145-3);
/// the live segment fills after them; a playhead marks the recorded end (OQ-C-145-2); the last
/// segment turns `color-text-primary` while its deletion is being confirmed (OQ-C-145-1).
/// Display only: it takes durations and draws them (R-01, R-04) — no callbacks, no state.
struct SegmentedProgressBar: View {

    /// §4 `length` — the chosen length in seconds (10…120, D3); the bar's full width.
    let length: TimeInterval
    /// §4 `segments` — finished segment durations in seconds, in recording order.
    let segments: [TimeInterval]
    /// §4 `liveDuration` — seconds into the segment recording now; 0 when none.
    let liveDuration: TimeInterval
    /// §4 `lastSegmentMarked` — the last finished segment is marked for deletion (D5 confirm up).
    /// Unrequired (R-07: the base look is unmarked).
    var lastSegmentMarked: Bool = false

    // FLAGGED LITERAL — C-145 §2 FL-1: 6 pt track height, no size token.
    private static let trackHeight: CGFloat = 6
    // FLAGGED LITERAL — C-145 §2 FL-2: 2 pt gap after a finished segment, no gap token.
    private static let gapWidth: CGFloat = 2
    // FLAGGED LITERAL — C-145 §2 FL-3: 2 × 10 pt playhead, no size token. The playhead's height
    // is also the bar's intrinsic height (§2).
    private static let playheadWidth: CGFloat = 2
    private static let playheadHeight: CGFloat = 10
    // GAP — C-145 §2 Rules: "a segment narrower than 1 pt still draws 1 pt", no size token.
    private static let minimumFillWidth: CGFloat = 1

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let pieces = fillPieces(width: width)
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Token.white30)
                        .ui2Element("Track")
                    ForEach(pieces) { piece in
                        Rectangle()
                            .fill(piece.marked ? Token.textPrimary : Token.record)
                            .frame(width: piece.width)
                            .ui2Element(piece.name)
                            // Padding, not offset, so the element map reports the drawn rect.
                            .padding(.leading, piece.x)
                    }
                }
                .frame(width: width, height: Self.trackHeight)
                // §2: capsule ends only at the bar's two outer ends; inner ends stay square.
                .clipShape(Capsule())
                // §2 Gap (OQ-C-145-3): neither the fill nor the track paints under a gap.
                .mask(GapCutout(gaps: pieces.compactMap(\.gapAfter)).fill(style: FillStyle(eoFill: true)))

                if let center = playheadCenter(width: width) {
                    Capsule()
                        .fill(Token.textPrimary)
                        .frame(width: Self.playheadWidth, height: Self.playheadHeight)
                        .ui2Element("Playhead")
                        .padding(.leading, center - Self.playheadWidth / 2)
                }
            }
            .frame(width: width, height: Self.playheadHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.playheadHeight)
        // §2: leading → trailing; mirrors under RTL.
        .flipsForRightToLeftLayoutDirection(true)
        // §2 Accessibility: one combined, non-interactive element.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording progress")
        .accessibilityValue(spokenValue)
        .accessibilityAddTraits(liveDuration > 0 ? .updatesFrequently : [])
        .ui2Element("SegmentedProgressBar")
    }

    // MARK: - Geometry

    private struct Piece: Identifiable {
        let id: Int
        let name: String
        let x: CGFloat
        let width: CGFloat
        let marked: Bool
        /// The gap's x range after this piece, when more fill follows it.
        let gapAfter: ClosedRange<CGFloat>?
    }

    /// Total recorded seconds (§2 Rules: Σ`segments` + `liveDuration`).
    private var total: TimeInterval {
        segments.reduce(0, +) + max(liveDuration, 0)
    }

    /// The finished segments, then the live fill, laid out as fractions of `length` (§2).
    private func fillPieces(width: CGFloat) -> [Piece] {
        guard length > 0, width > 0 else { return [] }
        var durations = segments.map { max($0, 0) }
        let hasLive = liveDuration > 0
        if hasLive { durations.append(liveDuration) }

        var pieces: [Piece] = []
        var elapsed: TimeInterval = 0
        for (index, duration) in durations.enumerated() {
            let start = CGFloat(elapsed / length) * width
            // §2 Rules: fill never exceeds the track.
            guard start < width else { break }
            elapsed += duration
            let end = min(CGFloat(elapsed / length) * width, width)
            let isLive = hasLive && index == durations.count - 1
            let followedByFill = index < durations.count - 1
            let gap = followedByFill ? Self.gapWidth : 0
            let fillWidth = max(end - start - gap, Self.minimumFillWidth)
            let fillEnd = start + fillWidth
            let marked = lastSegmentMarked && !isLive && index == segments.count - 1
            pieces.append(Piece(
                id: index,
                name: isLive ? "Live fill" : "Segment \(index + 1)",
                x: start,
                width: fillWidth,
                marked: marked,
                gapAfter: followedByFill && fillEnd < end ? fillEnd...end : nil
            ))
        }
        return pieces
    }

    /// §2 Playhead: centred on the recorded end, clamped inside the bar; nil on an empty bar.
    private func playheadCenter(width: CGFloat) -> CGFloat? {
        guard total > 0, length > 0, width > 0 else { return nil }
        let raw = CGFloat(min(total, length) / length) * width
        let half = Self.playheadWidth / 2
        return min(max(raw, half), width - half)
    }

    // MARK: - Accessibility

    /// §2: "<total m:ss> of <length m:ss>, <n> clips" — e.g. "0:23 of 1:00, 2 clips".
    private var spokenValue: String {
        let clips = segments.count + (liveDuration > 0 ? 1 : 0)
        let noun = clips == 1 ? "clip" : "clips"
        return "\(Self.minutesSeconds(min(total, length))) of \(Self.minutesSeconds(length)), \(clips) \(noun)"
    }

    private static func minutesSeconds(_ seconds: TimeInterval) -> String {
        let whole = max(Int(seconds.rounded(.down)), 0)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// The bar's paint area with each gap punched out (even-odd fill of the full rect plus the gaps).
private struct GapCutout: Shape {
    let gaps: [ClosedRange<CGFloat>]

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        for gap in gaps {
            path.addRect(CGRect(x: gap.lowerBound, y: rect.minY, width: gap.upperBound - gap.lowerBound, height: rect.height))
        }
        return path
    }
}
