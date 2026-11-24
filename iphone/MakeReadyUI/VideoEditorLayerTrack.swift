//
//  VideoEditorLayerTrack.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-154-videoeditorlayertrack in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-154 VideoEditorLayerTrack — "44pt track for one text layer or the shared captions track; text
/// and caption looks; selected state shows end handles to trim and bar drag to slide."
///
/// §2: 44 pt tall, the timeline's content width, leading edge = time 0. One bar per window, drawn
/// where C-153's time scale puts it; handles sit outside the selected bar's ends.
///
/// Controlled (R-01): the windows and the selection are displayed, never held; the only internal
/// state is a drag in flight (R-02). It reports unclamped intents — every timing rule is the
/// caller's. Width-driven, chrome-free (R-16).
struct VideoEditorLayerTrack: View {
    /// §4 `kind`: the look (R-06, R-36).
    enum Kind {
        case text, captions
    }

    /// §4 `Bar`: one window (D17's names).
    struct Bar: Identifiable, Equatable {
        let id: String
        let text: String
        let startMs: Int
        let endMs: Int
    }

    /// §4: text or captions look.
    let kind: Kind
    /// §4: one for a text layer; one per caption, in time order.
    let bars: [Bar]
    /// §4: the selected bar's id; nil or an id not in `bars` selects none.
    let selectedID: String?
    /// §4: a bar was tapped.
    var onSelect: (String) -> Void = { _ in }
    /// §4: id and the proposed `startMs`, unclamped.
    var onTrimStart: (String, Int) -> Void = { _, _ in }
    /// §4: id and the proposed `endMs`, unclamped.
    var onTrimEnd: (String, Int) -> Void = { _, _ in }
    /// §4: id and the proposed `startMs`, unclamped; the caller keeps the length.
    var onSlide: (String, Int) -> Void = { _, _ in }
    /// §4: a trim or slide ended.
    var onGestureEnded: () -> Void = {}

    /// R-02 ephemeral: the drag in flight.
    @State private var drag: Drag?

    private enum Part: Equatable {
        case body, start, end
    }

    private struct Drag {
        let part: Part
        let id: String
        /// The dragged value at touch-down.
        let originMs: Int
        /// The value last reported by this drag.
        var reportedMs: Int?
    }

    private enum Geometry {
        /// FLAGGED LITERAL — C-154 §2 FL-1: 44 height and hit area, no token.
        static let height: CGFloat = 44
        /// FLAGGED LITERAL — C-154 §2 FL-2: 1 border, no token.
        static let border: CGFloat = 1
        /// FLAGGED LITERAL — C-154 §2 FL-3: 18 glyph, no token.
        static let glyph: CGFloat = 18
        /// FLAGGED LITERAL — C-154 §2 FL-4: 2 outline, no token.
        static let outline: CGFloat = 2
        /// FLAGGED LITERAL — C-154 §2 FL-5: 12 handle, no token.
        static let handleWidth: CGFloat = 12
        /// FLAGGED LITERAL — C-154 §2 FL-6: 2 × 20 grip, no token.
        static let gripWidth: CGFloat = 2
        static let gripHeight: CGFloat = 20
    }

    /// §2 Accessibility: ±500 ms a step.
    private static let stepMs = 500

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                barView(bar, number: index + 1)
                    .offset(x: position(bar.startMs))
                    // §2 Order: array order, the selected bar and its handles last.
                    .zIndex(bar.id == selectedID ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Geometry.height, maxHeight: Geometry.height, alignment: .topLeading)
        // §2: a tap over a handle's hit area selects the bar under it, so the track resolves taps by
        // place. No content shape here: only bars and handles are hit, and handles pass the ends.
        .gesture(SpatialTapGesture().onEnded { tap in
            if let bar = bar(at: tap.location.x) { onSelect(bar.id) }
        })
        .onChange(of: selectedID) { endDrag() }
        .onDisappear { endDrag() }
        .accessibilityElement(children: .contain)
        .ui2Element("VideoEditorLayerTrack")
    }

    // MARK: - Bars

    @ViewBuilder private func barView(_ bar: Bar, number: Int) -> some View {
        let width = width(of: bar)
        if bar.id == selectedID {
            ZStack(alignment: .topLeading) {
                barBody(bar, width: width, selected: true, number: number)
                    .horizontalPan(onChanged: { pan($0, .body, bar) }, onEnded: { _ in endDrag(.body, bar.id) })
                    .accessibilityAdjustableAction { step($0, .body, bar) }
                handle(.start, bar)
                    .offset(x: -Geometry.height)
                handle(.end, bar)
                    .offset(x: width)
                RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                    .strokeBorder(selectionColor, lineWidth: Geometry.outline)
                    .frame(width: width + Geometry.handleWidth * 2, height: Geometry.height)
                    .ui2Element("Selected outline")
                    .offset(x: -Geometry.handleWidth)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            barBody(bar, width: width, selected: false, number: number)
        }
    }

    private func barBody(_ bar: Bar, width: CGFloat, selected: Bool, number: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: selected ? 0 : Token.Radius.card, style: .continuous)
        return content(bar, width: width, number: number)
            .frame(width: width, height: Geometry.height, alignment: .leading)
            .background(fill(selected: selected))
            .clipShape(shape)
            .overlay {
                if kind == .captions, !selected {
                    shape.strokeBorder(Token.cardBorder, lineWidth: Geometry.border)
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(bar))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect(bar.id) }
            .ui2Element("Bar \(number)")
    }

    /// §2 Glyph and label; nothing in a bar narrower than its glyph and gaps.
    @ViewBuilder private func content(_ bar: Bar, width: CGFloat, number: Int) -> some View {
        let gap = Token.Space.elementGap
        let minimum = gap * 2 + (kind == .text ? Geometry.glyph : 0)
        if width >= minimum {
            HStack(spacing: gap) {
                if kind == .text {
                    Image(GlyphName.textFont.rawValue, bundle: .ui2Preview)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Geometry.glyph, height: Geometry.glyph)
                        .ui2Element("Glyph \(number)")
                }
                Text(Self.oneLine(bar.text))
                    .designTextStyle(Token.TypeStyle.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .ui2Element("Label \(number)")
            }
            .foregroundStyle(Token.textPrimary)
            // §2 Label pinning (OQ-C-154-2): this view's leading edge is `gap` into the bar.
            .visualEffect { effect, proxy in
                let hidden = (proxy.bounds(of: .scrollView)?.minX ?? -.infinity) + gap
                let room = max(width - gap * 2 - proxy.size.width, 0)
                return effect.offset(x: min(max(hidden, 0), room))
            }
            .padding(.horizontal, gap)
        } else {
            Color.clear
        }
    }

    // MARK: - Handles

    /// §2 Handle: 12 pt drawn against the bar's end, inside a 44 × 44 hit area running outward.
    private func handle(_ part: Part, _ bar: Bar) -> some View {
        let leading = part == .start
        let outer = Token.Radius.card
        return UnevenRoundedRectangle(
            topLeadingRadius: leading ? outer : 0,
            bottomLeadingRadius: leading ? outer : 0,
            bottomTrailingRadius: leading ? 0 : outer,
            topTrailingRadius: leading ? 0 : outer,
            style: .continuous
        )
        .fill(selectionColor)
        .frame(width: Geometry.handleWidth, height: Geometry.height)
        .overlay {
            Capsule()
                .fill(kind == .text ? Token.textPrimary : Token.cardBackground)
                .frame(width: Geometry.gripWidth, height: Geometry.gripHeight)
                .ui2Element(leading ? "Start grip" : "End grip")
        }
        .ui2Element(leading ? "Start handle" : "End handle")
        .frame(width: Geometry.height, height: Geometry.height, alignment: leading ? .trailing : .leading)
        .contentShape(Rectangle())
        .horizontalPan(onChanged: { pan($0, part, bar) }, onEnded: { _ in endDrag(part, bar.id) })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(leading ? "Trim start" : "Trim end"), \(label(bar))")
        .accessibilityValue(Self.clock(value(part, bar)))
        .accessibilityAdjustableAction { step($0, part, bar) }
    }

    // MARK: - Gestures

    private func pan(_ pan: HorizontalPanValue, _ part: Part, _ bar: Bar) {
        if drag == nil { drag = Drag(part: part, id: bar.id, originMs: value(part, bar)) }
        guard let current = drag, current.part == part, current.id == bar.id else { return }
        let moved = Int((pan.translation / VideoEditorTimeline.pointsPerSecond * 1000).rounded())
        let next = current.originMs + moved
        guard next != (current.reportedMs ?? current.originMs) else { return }
        drag?.reportedMs = next
        report(next, part, bar.id)
    }

    private func endDrag(_ part: Part, _ id: String) {
        guard drag?.part == part, drag?.id == id else { return }
        endDrag()
    }

    /// Also runs when the dragged bar is deselected or the track goes away mid-drag.
    private func endDrag() {
        let reported = drag?.reportedMs != nil
        drag = nil
        if reported { onGestureEnded() }
    }

    private func step(_ direction: AccessibilityAdjustmentDirection, _ part: Part, _ bar: Bar) {
        switch direction {
        case .increment: report(value(part, bar) + Self.stepMs, part, bar.id)
        case .decrement: report(value(part, bar) - Self.stepMs, part, bar.id)
        @unknown default: return
        }
        onGestureEnded()
    }

    private func report(_ milliseconds: Int, _ part: Part, _ id: String) {
        switch part {
        case .body: onSlide(id, milliseconds)
        case .start: onTrimStart(id, milliseconds)
        case .end: onTrimEnd(id, milliseconds)
        }
    }

    private func value(_ part: Part, _ bar: Bar) -> Int {
        part == .end ? bar.endMs : bar.startMs
    }

    /// The topmost bar at `x`: the selected one, else the last drawn.
    private func bar(at x: CGFloat) -> Bar? {
        let hits = bars.filter { position($0.startMs) <= x && x < position($0.endMs) }
        return hits.first { $0.id == selectedID } ?? hits.last
    }

    // MARK: - Values

    private var selectionColor: Color { kind == .text ? Token.accent : Token.textPrimary }

    private func fill(selected: Bool) -> Color {
        switch kind {
        case .text: return selected ? Token.accent20 : Token.accent
        case .captions: return Token.cardBackground
        }
    }

    private func position(_ milliseconds: Int) -> CGFloat {
        CGFloat(milliseconds) / 1000 * VideoEditorTimeline.pointsPerSecond
    }

    private func width(of bar: Bar) -> CGFloat {
        max(position(bar.endMs) - position(bar.startMs), 0)
    }

    private func label(_ bar: Bar) -> String {
        "\(Self.oneLine(bar.text)), \(Self.clock(bar.startMs)) to \(Self.clock(bar.endMs))"
    }

    /// §2 Label: newlines shown as spaces.
    private static func oneLine(_ text: String) -> String {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func clock(_ milliseconds: Int) -> String {
        let seconds = max(milliseconds, 0) / 1000
        let remainder = seconds % 60
        return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
