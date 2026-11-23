//
//  FilterStrip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-150-filterstrip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-150 FilterStrip — "Horizontal strip of 7 filter looks (d2m picks them, D6) with a strength slider."
///
/// §2: three rows top to bottom — the 44 pt strength slider (hidden under Normal, its space kept),
/// the 44 pt header ("Filters" and a ✓ Done), and the 74 pt scrolling row of eight tiles — with
/// `space-element-gap` between rows: 44 + 8 + 44 + 8 + 74 = 178 pt.
///
/// Controlled (R-01): it displays `selected` and `strength` and never holds them; the caller
/// resets strength to 100 on each new pick (D6). It runs no Core Image (R-04, R-19): the graded
/// swatches arrive in `thumbnails`. Width-driven, chrome-free (R-16).
struct FilterStrip: View {
    /// §4 / OQ-C-150-001: Normal plus the seven looks, in tile order.
    enum Look: CaseIterable {
        case normal, vivid, warm, cool, fade, chrome, mono, noir

        /// §2: the name shown under the tile.
        var name: String {
            switch self {
            case .normal: return "Normal"
            case .vivid: return "Vivid"
            case .warm: return "Warm"
            case .cool: return "Cool"
            case .fade: return "Fade"
            case .chrome: return "Chrome"
            case .mono: return "Mono"
            case .noir: return "Noir"
            }
        }
    }

    /// §4: the chosen look; outlined and scrolled into view.
    let selected: Look
    /// §4: a tile was tapped (also the selected one). The caller sets `selected` and resets
    /// `strength` to 100 (D6).
    var onSelect: (Look) -> Void = { _ in }
    /// §4: 0…100 (clamped); ignored while `selected == .normal`.
    let strength: Int
    /// §4: each integer change while dragging, or an accessibility step.
    var onStrengthChange: (Int) -> Void = { _ in }
    /// §4: the graded swatch per look, resolved by the caller; a missing key draws the placeholder.
    let thumbnails: [Look: Image]
    /// §4: ✓ tapped; the caller closes the strip, keeping the look.
    var onDone: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// R-02 ephemeral: the value shown in the bubble while a finger is down (nil = not dragging).
    @State private var dragValue: Int?

    // §2 geometry: this component's own (contract: "Literals: none — 44 / 56 / 24 / 6 / 2 / 28 /
    // 40 pt are this component's geometry, as in C-149 and C-093").
    private static let rowHeight: CGFloat = 44
    private static let swatchSize: CGFloat = 56
    private static let glyphSize: CGFloat = 24
    private static let trackHeight: CGFloat = 6
    private static let thumbDiameter: CGFloat = 24
    private static let outlineWidth: CGFloat = 2
    private static let bubbleDiameter: CGFloat = 28
    private static let bubbleRise: CGFloat = 40
    /// §2 Tiles row: 56 swatch + 4 + the caption's 14 pt line = 74.
    private static var tileHeight: CGFloat {
        swatchSize + Token.Space.metaGap + (Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size)
    }
    /// §2: 178 pt.
    private static var intrinsicHeight: CGFloat {
        rowHeight + Token.Space.elementGap + rowHeight + Token.Space.elementGap + tileHeight
    }

    private var animation: Animation? { reduceMotion ? nil : Token.Motion.chipSelect }
    private var clampedStrength: Int { min(max(strength, 0), 100) }
    private var strengthVisible: Bool { selected != .normal }

    var body: some View {
        VStack(spacing: 0) {
            strengthRow
                .frame(height: Self.rowHeight)
                .padding(.bottom, Token.Space.elementGap)
            header
                .frame(height: Self.rowHeight)
                .padding(.bottom, Token.Space.elementGap)
            tiles
                .frame(height: Self.tileHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.intrinsicHeight)
        // §2 Motion & haptics: the outline moves and the strength row fades over
        // `motion-chip-select` (Reduce Motion: none); a selection haptic per change of `selected`.
        .animation(animation, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .ui2Element("FilterStrip")
    }

    // MARK: - Strength row (§2 row 1)

    /// The slider, inset `space-page-margin` both sides; hidden under Normal with its 44 pt kept
    /// (deviation 5, OQ-C-150-003).
    private var strengthRow: some View {
        GeometryReader { proxy in
            slider(width: proxy.size.width)
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .opacity(strengthVisible ? 1 : 0)
        .allowsHitTesting(strengthVisible)
        .accessibilityHidden(!strengthVisible)
        .ui2Element("Strength")
    }

    /// §2 Slider (the C-149 look, OQ-C-150-004): a 6 pt `color-white-20` track, a `color-accent`
    /// fill to the thumb's centre, a 24 pt white thumb with `elevation-thumb`; centre 12 … w − 12.
    private func slider(width: CGFloat) -> some View {
        let shown = dragValue ?? clampedStrength
        let centre = thumbCentre(for: shown, width: width)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Token.white20)
                .frame(height: Self.trackHeight)
                .ui2Element("Track")
            Capsule()
                .fill(Token.accent)
                .frame(width: centre, height: Self.trackHeight)
                .ui2Element("Fill")
            // `radius-circle` is 50 %, not a point value — the disc is a Circle() (C-093, C-149).
            Circle()
                .fill(Token.white100)
                .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                .designShadow(Token.Elevation.thumb)
                .ui2Element("Thumb")
                // Padding, not offset: the thumb's layout frame (and its element-map rect) moves too.
                .padding(.leading, centre - Self.thumbDiameter / 2)
        }
        .frame(width: width, height: Self.rowHeight, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if let value = dragValue {
                valueBubble(value)
                    .offset(
                        x: centre - Self.bubbleDiameter / 2,
                        y: Self.rowHeight / 2 - Self.bubbleRise - Self.bubbleDiameter / 2
                    )
            }
        }
        .contentShape(Rectangle())
        .gesture(
            // pan-ok: slider — tracks the finger's absolute x on its own 44 pt row
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let next = value(atX: drag.location.x, width: width)
                    guard next != (dragValue ?? clampedStrength) else {
                        if dragValue == nil { dragValue = next }
                        return
                    }
                    dragValue = next
                    onStrengthChange(next)
                }
                .onEnded { _ in dragValue = nil }
        )
        // §2 Accessibility (R-17): one adjustable element, ±10 clamped.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter strength")
        .accessibilityValue("\(clampedStrength) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 10)
            case .decrement: step(by: -10)
            @unknown default: break
            }
        }
    }

    /// §2 / OQ-C-150-006: a 28 pt `color-black-60` circle, the integer in `type-caption-semibold`,
    /// its centre 40 pt above the thumb's — drag feedback only (R-02).
    private func valueBubble(_ value: Int) -> some View {
        Text("\(value)")
            .designTextStyle(Token.TypeStyle.captionSemibold)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(Token.textPrimary)
            .frame(width: Self.bubbleDiameter, height: Self.bubbleDiameter)
            .background(Circle().fill(Token.black60))
            .allowsHitTesting(false)
            .ui2Element("Value bubble")
    }

    // MARK: - Header (§2 row 2)

    /// "Filters" leading at `space-page-margin`; Done — the `check` glyph, 24 pt, in a 44 pt hit
    /// square whose trailing edge sits at `space-page-margin` − 10 (the glyph's at 16).
    private var header: some View {
        HStack(spacing: 0) {
            Text("Filters")
                .designTextStyle(Token.TypeStyle.sectionTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .ui2Element("Title")
            Spacer(minLength: 0)
            SwiftUI.Button(action: onDone) {
                Glyph(.check, size: .md, tint: Token.textPrimary)
                    .frame(width: Self.rowHeight, height: Self.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
            .ui2Element("Done")
        }
        .padding(.leading, Token.Space.pageMargin)
        .padding(.trailing, Token.Space.pageMargin - (Self.rowHeight - Self.glyphSize) / 2)
        .ui2Element("Header")
    }

    // MARK: - Tiles (§2 row 3)

    /// A horizontal scroll row, content inset `space-page-margin` at both ends, tiles
    /// `space-element-gap` apart (64 pt pitch); the selection scrolled into view on appear and
    /// on every change of `selected` (ephemeral scroll position, R-02).
    private var tiles: some View {
        ScrollViewReader { proxy in
            HorizontalRail(showsIndicators: false) {
                HStack(alignment: .top, spacing: Token.Space.elementGap) {
                    ForEach(Array(Look.allCases.enumerated()), id: \.element) { index, look in
                        tile(look)
                            .id(look)
                            .ui2Element("Tile \(index + 1)")
                    }
                }
            }
            .contentMargins(.horizontal, Token.Space.pageMargin, for: .scrollContent)
            .onAppear { proxy.scrollTo(selected) }
            .onChange(of: selected) {
                withAnimation(animation) { proxy.scrollTo(selected) }
            }
        }
        .ui2Element("Tiles")
    }

    /// §2 Tile: a 56 pt swatch (`radius-card`, the image aspect-filled, `color-white-10` when
    /// missing), the name `space-meta-gap` below in `type-caption`; selected → a 2 pt white
    /// `strokeBorder`. The whole 56 × 74 tile is the hit area.
    private func tile(_ look: Look) -> some View {
        let isSelected = look == selected
        return SwiftUI.Button { onSelect(look) } label: {
            VStack(spacing: Token.Space.metaGap) {
                swatch(look)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Token.Radius.card)
                                .strokeBorder(Token.white100, lineWidth: Self.outlineWidth)
                                .ui2Element("Outline")
                        }
                    }
                    .ui2Element("Swatch")
                Text(look.name)
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: Self.swatchSize)
                    .ui2Element("Name")
            }
            .frame(width: Self.swatchSize, height: Self.tileHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(look.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func swatch(_ look: Look) -> some View {
        RoundedRectangle(cornerRadius: Token.Radius.card)
            .fill(Token.white10)
            .frame(width: Self.swatchSize, height: Self.swatchSize)
            .overlay {
                if let image = thumbnails[look] {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Self.swatchSize, height: Self.swatchSize)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
    }

    // MARK: - Value mapping (§2)

    /// §2: the thumb's centre runs from 12 (strength 0) to w − 12 (strength 100).
    private func thumbCentre(for value: Int, width: CGFloat) -> CGFloat {
        let travel = max(width - Self.thumbDiameter, 0)
        return Self.thumbDiameter / 2 + CGFloat(value) / 100 * travel
    }

    private func value(atX x: CGFloat, width: CGFloat) -> Int {
        let travel = max(width - Self.thumbDiameter, 1)
        let fraction = (x - Self.thumbDiameter / 2) / travel
        return min(max(Int((fraction * 100).rounded()), 0), 100)
    }

    private func step(by delta: Int) {
        let next = min(max(clampedStrength + delta, 0), 100)
        guard next != clampedStrength else { return }
        onStrengthChange(next)
    }
}
