//
//  ActivityCanvas.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-091-activitycanvas in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-091 ActivityCanvas — "The activity page surface: tap anywhere to add a text object; hosts
/// text objects, the size slider and, for a Bible verse activity, the passage."
///
/// §2 layers, bottom → top: the ground (plain or image + wash), the passage with its highlight
/// spans, the `content` slot (C-092 objects, C-093, the Selection row's C-102 + C-105 — placed
/// by the screen), and the Manipulating overlays (centre guide, "Drag to delete" target).
///
/// Width-driven (R-16): the canvas fills the width AND the height the screen gives it and states
/// no intrinsic height. Disclosed R-16 exception (§2): it paints its own ground, because the
/// ground is its content — `background` is the leader's page property, not chrome.
///
/// Controlled (R-01): it holds no value of its own; every gesture leaves through a closure.
struct ActivityCanvas<Content: View>: View {
    /// §4 `background` — the ground (§2 layer 1).
    enum Background {
        case plain
        case image(imageURL: URL, washColor: Color, washOpacity: Double)
    }

    /// §4 `mode` — which gestures the canvas takes and which overlays it draws.
    enum Mode {
        case idle, editing, highlighting, manipulating
    }

    /// §4 `deleteTarget` — OQ-C-091-002 (owner, ratified): armed = 1.15×.
    enum DeleteTarget {
        case visible, armed
    }

    /// §4 — the highlight entity's id as the store names it (R-38); the canvas never resolves it.
    typealias HighlightID = String

    /// §4 `passage` — the Bible verse passage the canvas renders itself (D55).
    struct Passage {
        var verses: [Verse]
        var highlights: [Highlight]
    }

    /// §4 `Verse`.
    struct Verse {
        var number: Int
        var text: String
    }

    /// §4 `Highlight` — `range` is a character range of its verse's `text`.
    struct Highlight {
        var id: HighlightID
        var verse: Int
        var range: Range<Int>
        var note: String?
    }

    /// §4 — the ground.
    let background: Background
    /// §4 — gestures and overlays.
    let mode: Mode
    /// §4 — default nil (a Text activity has none).
    var passage: Passage?
    /// §4 — default nil; OQ-C-091-001 (owner, ratified): its spans take a 1pt outline.
    var selectedHighlightID: HighlightID?
    /// §4 — the designed slot (R-08): placed and positioned by the screen.
    @ViewBuilder let content: () -> Content
    /// §4 — a tap no slot child took, canvas-local; `idle` only.
    var onTapEmpty: (CGPoint) -> Void = { _ in }
    /// §4 — a completed drag across passage text in `highlighting`: verse number + range.
    var onHighlight: (Int, Range<Int>) -> Void = { _, _ in }
    /// §4 — a tap on a span (its id) or on passage text outside every span (nil).
    var onSelectHighlight: (HighlightID?) -> Void = { _ in }
    /// §4 — OQ-C-091-002 (owner, ratified): the 1px vertical centre guide in `manipulating`.
    var centerGuide: Bool = false
    /// §4 — OQ-C-091-002 (owner, ratified): the "Drag to delete" target in `manipulating`.
    var deleteTarget: DeleteTarget?

    /// FLAGGED LITERAL — C-091 §2 layer 2: the 32×32 verse-number box.
    private let numberBox: CGFloat = 32
    /// FLAGGED LITERAL — C-091 §2 layer 2: number box → verse text gap 10.
    private let numberGap: CGFloat = 10
    /// FLAGGED LITERAL — C-091 §2 layer 6 (OQ-C-091-002): the delete disc is 44pt, centred at
    /// 88 % of the canvas height, 1.15× when armed.
    private let deleteDisc: CGFloat = 44
    private let deleteHeightFraction: CGFloat = 0.88
    private let deleteArmedScale: CGFloat = 1.15
    /// C-091 §2 layer 6 (OQ-C-091-002): the 1px centre guide.
    private let guideWidth: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ground
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { onTapEmpty($0.location) }, isEnabled: mode == .idle)
                    .accessibilityElement()
                    .accessibilityLabel("Activity canvas")
                    .accessibilityHint(mode == .idle ? "Adds a text object" : "")
                    .accessibilityAddTraits(mode == .idle ? .isButton : [])
                    .accessibilityAction { if mode == .idle { onTapEmpty(CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)) } }
                    .ui2Element("Ground")
                if let passage {
                    passageColumn(passage)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ui2Element("Passage")
                }
                content()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .ui2Element("Content")
                if mode == .manipulating {
                    manipulatingOverlays(in: proxy.size)
                }
            }
        }
        .ui2Element("ActivityCanvas")
    }

    // MARK: - §2 layer 1: the ground

    @ViewBuilder private var ground: some View {
        switch background {
        case .plain:
            Token.backgroundAlt
        case let .image(imageURL, washColor, washOpacity):
            ZStack {
                // §2: the symbol's #2e2e2e base, shown until the image resolves.
                Token.activitySlidePlaceholder
                // R-04 / R-19: the caller resolves the image; the canvas reads it cache-first and
                // never fetches (Ui2ImageCache.swift).
                if let image = Ui2ImageCache.shared.image(for: imageURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .accessibilityHidden(true)
                }
                // §2 / deviation 4: a full-bleed wash of `washColor` at `washOpacity` (sample
                // content — the leader's page properties).
                washColor.opacity(washOpacity)
            }
        }
    }

    // MARK: - §2 layers 2–3: the passage and its highlight spans

    private func passageColumn(_ passage: Passage) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                ForEach(Array(passage.verses.enumerated()), id: \.offset) { index, verse in
                    verseRow(verse, highlights: passage.highlights.filter { $0.verse == verse.number })
                        .ui2Element("Verse \(index + 1)")
                }
            }
            .padding(Token.Space.pageMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(mode != .highlighting && mode != .idle)
    }

    private func verseRow(_ verse: Verse, highlights: [Highlight]) -> some View {
        HStack(alignment: .top, spacing: numberGap) {
            SwiftUI.Text(verbatim: "\(verse.number)")
                .designTextStyle(Token.TypeStyle.passageVerse)
                .foregroundStyle(Token.textPrimary)
                .frame(width: numberBox, height: numberBox)
                .accessibilityHidden(true)
                .ui2Element("Verse number")
            verseText(verse, highlights: highlights)
                .passageVerseStyle()
                .foregroundStyle(Token.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textRenderer(PassageSpanRenderer(selectedID: selectedHighlightID))
                .overlay { highlightGestureLayer(verse, highlights: highlights) }
                .accessibilityElement()
                .accessibilityLabel("Verse \(verse.number), \(verse.text)")
                .ui2Element("Verse text")
        }
    }

    /// The verse as concatenated runs, each highlighted run carrying its highlight's id so the
    /// renderer can draw one span per wrapped line behind it (§2 layer 3).
    private func verseText(_ verse: Verse, highlights: [Highlight]) -> SwiftUI.Text {
        let characters = Array(verse.text)
        let ranges = highlights
            .map { (id: $0.id, range: $0.range.clamped(to: 0..<characters.count)) }
            .filter { !$0.range.isEmpty }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
        var result = SwiftUI.Text(verbatim: "")
        var cursor = 0
        for item in ranges where item.range.lowerBound >= cursor {
            if item.range.lowerBound > cursor {
                result = result + SwiftUI.Text(verbatim: String(characters[cursor..<item.range.lowerBound]))
            }
            result = result + SwiftUI.Text(verbatim: String(characters[item.range]))
                .customAttribute(PassageSpanMark(id: item.id))
            cursor = item.range.upperBound
        }
        if cursor < characters.count {
            result = result + SwiftUI.Text(verbatim: String(characters[cursor...]))
        }
        return result
    }

    // MARK: - §2 layer 5: the highlighting gestures

    /// In `highlighting` a drag across a verse selects a character range (`onHighlight`) and a
    /// tap selects the span under it, or clears the selection (`onSelectHighlight`). Character
    /// positions come from a TextKit layout of the same string at the same width; nothing is
    /// drawn here.
    @ViewBuilder
    private func highlightGestureLayer(_ verse: Verse, highlights: [Highlight]) -> some View {
        if mode == .highlighting {
            GeometryReader { textProxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        // pan-ok: text-range highlight across lines
                        DragGesture(minimumDistance: 4).onEnded { drag in
                            let hit = PassageHitTester(text: verse.text, width: textProxy.size.width)
                            guard let start = hit.index(at: drag.startLocation),
                                  let end = hit.index(at: drag.location) else { return }
                            let range = min(start, end)..<(max(start, end) + 1)
                            onHighlight(verse.number, range)
                        }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { tap in
                            let hit = PassageHitTester(text: verse.text, width: textProxy.size.width)
                            let index = hit.index(at: tap.location)
                            let match = index.flatMap { i in highlights.first { $0.range.contains(i) } }
                            onSelectHighlight(match?.id)
                        }
                    )
                    .accessibilityHidden(true)
            }
            .accessibilityActions {
                ForEach(highlights, id: \.id) { highlight in
                    SwiftUI.Button("Select highlight") { onSelectHighlight(highlight.id) }
                }
            }
        }
    }

    // MARK: - §2 layer 6: the Manipulating overlays (OQ-C-091-002, owner-ratified)

    @ViewBuilder
    private func manipulatingOverlays(in size: CGSize) -> some View {
        if centerGuide {
            Token.white100
                .frame(width: guideWidth, height: size.height)
                .offset(x: (size.width - guideWidth) / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .ui2Element("Center guide")
        }
        if let deleteTarget {
            ZStack {
                Circle()
                    .fill(Token.black50)
                Glyph(.trash2, size: .md, tint: Token.white100)
            }
            .frame(width: deleteDisc, height: deleteDisc)
            .scaleEffect(deleteTarget == .armed ? deleteArmedScale : 1)
            .position(x: size.width / 2, y: size.height * deleteHeightFraction)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(deleteTarget == .armed ? "Release to delete" : "Drag to delete")
            .ui2Element("Delete target")
        }
    }
}

// MARK: - Passage metrics

/// `type-passage-verse` laid out at its 25.2pt line pitch (§2 layer 2: two-line rows are 50 tall).
/// `designTextStyle` adds `lineHeight − size` (7.2) on top of the font's own ≈21.5pt line, which
/// lands the pitch at ≈28.7; the gap is the spacing above the font's line height instead.
private enum PassageMetrics {
    static var lineSpacing: CGFloat {
        let style = Token.TypeStyle.passageVerse
        let natural = UIFont.systemFont(ofSize: style.size).lineHeight
        return max((style.lineHeight ?? style.size) - natural, 0)
    }
}

private extension View {
    func passageVerseStyle() -> some View {
        let style = Token.TypeStyle.passageVerse
        return font(style.font).tracking(style.tracking).lineSpacing(PassageMetrics.lineSpacing)
    }
}

// MARK: - Highlight span rendering

/// Marks a highlighted run of a verse with its highlight's id.
private struct PassageSpanMark: TextAttribute {
    let id: String
}

/// Draws one span per wrapped line of each highlighted run, behind that line's glyphs (§2
/// layer 3), then the glyphs. The selected highlight's spans take a 1pt `color-white-100`
/// outline (OQ-C-091-001, owner-ratified); the fill is unchanged.
private struct PassageSpanRenderer: TextRenderer {
    let selectedID: String?

    /// FLAGGED LITERAL — C-091 §2 layer 3: span height 26 (the 25.2 line pitch rounded up).
    private let spanHeight: CGFloat = 26
    /// GAP — C-091 §2 layer 3 / OQ-C-091-004 (owner, 2026-10-13): mint `color-highlight-span` =
    /// #FFEE00 at 0.50. The ruling stands but the token row is not minted yet, so this is the
    /// ruled value as a literal until it is.
    private let spanFill = Color(red: 1.0, green: 0.9333, blue: 0.0, opacity: 0.5)
    /// C-091 §2 layer 3 (OQ-C-091-001): the selected outline is 1pt.
    private let outlineWidth: CGFloat = 1

    var displayPadding: EdgeInsets {
        let pad = spanHeight / 2
        return EdgeInsets(top: pad, leading: 0, bottom: pad, trailing: 0)
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            let lineRect = line.typographicBounds.rect
            var open: (id: String, rect: CGRect)?
            for run in line {
                let runRect = run.typographicBounds.rect
                if let mark = run[PassageSpanMark.self] {
                    if let current = open, current.id == mark.id {
                        open = (current.id, current.rect.union(runRect))
                    } else {
                        if let current = open { fillSpan(current, line: lineRect, in: &ctx) }
                        open = (mark.id, runRect)
                    }
                } else if let current = open {
                    fillSpan(current, line: lineRect, in: &ctx)
                    open = nil
                }
            }
            if let current = open { fillSpan(current, line: lineRect, in: &ctx) }
        }
        for line in layout {
            ctx.draw(line)
        }
    }

    private func fillSpan(_ span: (id: String, rect: CGRect), line: CGRect, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: span.rect.minX, y: line.midY - spanHeight / 2, width: span.rect.width, height: spanHeight)
        let shape = RoundedRectangle(cornerRadius: Token.Radius.cardSm).path(in: rect)
        ctx.fill(shape, with: .color(spanFill))
        if span.id == selectedID {
            ctx.stroke(
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .path(in: rect.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)),
                with: .color(Token.white100),
                lineWidth: outlineWidth
            )
        }
    }
}

// MARK: - Highlight hit testing

/// Maps a point in a verse's text frame to a character offset, by laying the same string out
/// with TextKit at the same width and the same `type-passage-verse` metrics. Gesture-only: it
/// draws nothing.
private struct PassageHitTester {
    let text: String
    let width: CGFloat

    func index(at point: CGPoint) -> Int? {
        let style = Token.TypeStyle.passageVerse
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = PassageMetrics.lineSpacing
        let storage = NSTextStorage(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: style.size),
            .kern: style.tracking,
            .paragraphStyle: paragraph,
        ])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        guard !text.isEmpty else { return nil }
        let glyph = manager.glyphIndex(for: point, in: container)
        let utf16 = manager.characterIndexForGlyph(at: glyph)
        let stringIndex = String.Index(utf16Offset: utf16, in: text)
        return text.distance(from: text.startIndex, to: stringIndex)
    }
}
