//
//  CanvasTextObject.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-092-canvastextobject in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-092 CanvasTextObject — one text object on the activity canvas.
///
/// §2: a single text block with no outline, handles or padding of its own beyond the optional
/// label box. The frame, the position on the canvas, the side width handles, the scrim, the
/// delete target and the centre guide are C-091 ActivityCanvas's (R-16, OQ-C-092-001).
///
/// The block is `text` split into items on newlines. Each item is a Text drawn by
/// `CanvasTextRenderer`, which paints back to front (§2 Label): the label box per wrapped line,
/// the highlight spans, the glyphs (with the animation), the effect, and the caret.
///
/// Controlled (R-01): the caller owns `text` and `transform` and gets every change back through
/// `onChange` / `onTransform`. Width-driven, chrome-free (R-16): with `transform.width` nil the
/// block fills the width it is given (C-091's edit slot) and states its own intrinsic height.
struct CanvasTextObject: View {
    /// §4 `font` — this row owns the set (OQ-activities-editor-016, closed).
    enum Font: CaseIterable {
        case poppins, sfPro, georgia, typewriter
    }

    /// §4 `alignment` — lines align within the block's width (OQ-C-092-002).
    enum Alignment {
        case center, left, right
    }

    /// §4 `label` — a filled rounded box behind each wrapped line (OQ-C-092-005).
    enum Label {
        case none, solidDark, solidLight
    }

    /// §4 `listStyle` — whole-block formatting, one item per line; markers are drawn, never
    /// stored in `text`.
    enum ListStyle {
        case none, bullet, numbered, bibleVerse
    }

    /// §4 `reference` — a structured Bible reference, drawn as one trailing line by
    /// `BibleReferenceFormatter` (§2 Reference, OQ-C-092-004).
    struct Reference: Equatable {
        struct Point: Equatable {
            var book: String
            var chapter: Int
            /// nil = a whole chapter.
            var verse: Int?
        }

        var start: Point
        /// nil = a single verse or chapter.
        var end: Point?
    }

    /// §4 `animation` — looping (OQ-activities-editor-007).
    enum Animation {
        case none, typewriter, pop, jump
    }

    /// §4 `effect` — glyph effect (OQ-activities-editor-007).
    enum Effect {
        case none, sparkle, neon, shimmer, pixel
    }

    /// §4 `transform` — canvas placement and layout width.
    struct Transform: Equatable {
        /// The centre point C-091 places the block at; this view never offsets itself (R-16).
        var position: CGPoint
        var scale: CGFloat
        var rotation: Angle
        /// The layout width set by C-091's side handles; nil = the edit slot.
        var width: CGFloat?

        static let identity = Transform(position: .zero, scale: 1, rotation: .zero, width: nil)
    }

    /// §4 `highlights` element — a character range of `text` with an optional note.
    struct TextRange: Equatable {
        var range: Range<String.Index>
        var note: String?
    }

    /// §4 — multi-line content, one item per line when `listStyle` is not none.
    let text: String
    /// §4 — the caller stores every edit (R-01).
    let onChange: (String) -> Void
    /// §4 — the typeface.
    let font: Font
    /// §4 — the point size, written by C-093 TextSizeSlider.
    let size: CGFloat
    /// §4 — the glyph fill (the label fill under solidLight).
    let color: Color
    /// §4 — line alignment within the width.
    let alignment: Alignment
    /// §4 — the background box behind each line.
    let label: Label
    /// §4 — whole-block list formatting.
    let listStyle: ListStyle
    /// OQ-C-092-003 (owner, 2026-10-13): the first verse number, so a passage starting at verse
    /// 16 numbers 16, 17, …. Not yet in the §4 table — the answered question is the ruling.
    let startNumber: Int
    /// §4 — the structured Bible reference drawn after the last item.
    let reference: Reference?
    /// §4 — the looping animation.
    let animation: Animation
    /// §4 — the glyph effect.
    let effect: Effect
    /// §4 — placement and layout width.
    let transform: Transform
    /// §4 — drag / pinch / rotate updates while Manipulating; the caller stores them (R-01).
    let onTransform: (Transform) -> Void
    /// §4 — first responder with the caret; the keyboard is the screen's.
    let editing: Bool
    /// §4 — ranges drawn as highlight spans.
    let highlights: [TextRange]
    /// §4 — a tap with no movement on a committed object (C-091 turns it into Editing).
    let onTap: () -> Void

    /// R-05: one parameter per §4 prop, in the contract's order (`startNumber` after
    /// `listStyle`, OQ-C-092-003). Written out because the private focus state would otherwise
    /// make the memberwise initializer private.
    init(
        text: String,
        onChange: @escaping (String) -> Void = { _ in },
        font: Font,
        size: CGFloat,
        color: Color = Token.textPrimary,
        alignment: Alignment = .center,
        label: Label = .none,
        listStyle: ListStyle = .none,
        startNumber: Int = 1,
        reference: Reference? = nil,
        animation: Animation = .none,
        effect: Effect = .none,
        transform: Transform = .identity,
        onTransform: @escaping (Transform) -> Void = { _ in },
        editing: Bool,
        highlights: [TextRange] = [],
        onTap: @escaping () -> Void = {}
    ) {
        self.text = text
        self.onChange = onChange
        self.font = font
        self.size = size
        self.color = color
        self.alignment = alignment
        self.label = label
        self.listStyle = listStyle
        self.startNumber = startNumber
        self.reference = reference
        self.animation = animation
        self.effect = effect
        self.transform = transform
        self.onTransform = onTransform
        self.editing = editing
        self.highlights = highlights
        self.onTap = onTap
    }

    /// R-02: focus is ephemeral feedback, mirrored from the `editing` prop.
    @FocusState private var focused: Bool
    /// R-02: the transform a gesture started from, held only while the finger is down.
    @State private var gestureBase: Transform?
    /// R-02: animation phases, 0 → 1 on a repeating loop. 0 and 1 are both the rest pose, so a
    /// capture with animations disabled draws the object fully set.
    @State private var animationClock: Double = 0
    @State private var effectClock: Double = 0

    /// §2 Editing — the placeholder copy (OQ-activities-editor-014).
    private static let placeholder = "Type something…"
    /// FLAGGED LITERAL — C-092 §2 Width & wrapping: 80pt minimum width (proposed).
    private let minimumWidth: CGFloat = 80
    /// FLAGGED LITERAL — C-092 §2 Label: box = glyph width + 8pt each side, line box + 4pt each
    /// side (measured on the Instagram recording, no token).
    private let labelInsetX: CGFloat = 8
    private let labelInsetY: CGFloat = 4
    /// FLAGGED LITERAL — C-092 §2 Animation / effect: Pixel adds ≈3pt per side to the bounds.
    private let pixelInset: CGFloat = 3

    var body: some View {
        block
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(width: transform.width.map { max($0, minimumWidth) })
            .frame(maxWidth: transform.width == nil ? .infinity : nil, alignment: frameAlignment)
            .overlay { if editing { inputField } }
            .scaleEffect(editing ? 1 : transform.scale)
            .rotationEffect(editing ? .zero : transform.rotation)
            .contentShape(Rectangle())
            .onTapGesture { if !editing { onTap() } }
            .simultaneousGesture(manipulation, including: editing ? .subviews : .all)
            .accessibilityElement(children: editing ? .contain : .ignore)
            .accessibilityLabel(editing ? "" : spokenLabel)
            .accessibilityAddTraits(editing ? [] : .isButton)
            .onAppear {
                focused = editing
                startClocks()
            }
            .onChange(of: editing) { _, now in focused = now }
            .onChange(of: animation) { _, _ in startClocks() }
            .onChange(of: effect) { _, _ in startClocks() }
            .ui2Element("CanvasTextObject")
    }

    // MARK: - Block

    private var block: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            if text.isEmpty {
                // §2 Editing: the placeholder never shows a list marker or a label box.
                SwiftUI.Text(verbatim: Self.placeholder)
                    .font(typeface)
                    .foregroundStyle(Token.white50)
                    .multilineTextAlignment(textAlignment)
                    .textRenderer(renderer(box: nil, caret: editing ? .start : .none))
                    .ui2Element("Placeholder")
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    itemRow(index: index, item: item)
                }
            }
            if let reference {
                // §2 Reference: one natural line below the last item; no marker, never
                // highlighted, not editable in place.
                SwiftUI.Text(verbatim: BibleReferenceFormatter.format(reference))
                    .font(typeface)
                    .foregroundStyle(glyphColor)
                    .multilineTextAlignment(textAlignment)
                    .textRenderer(renderer(box: boxColor, caret: .none))
                    .ui2Element("Reference")
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityHidden(editing)
    }

    private func itemRow(index: Int, item: Item) -> some View {
        // §2 List: markers hang in a gutter — wrapped lines align with the item's first glyph.
        // The gap is the marker's own trailing space in the object's font, not a spacing value.
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let marker = marker(for: index) {
                marker
                    .foregroundStyle(glyphColor)
                    .textRenderer(renderer(box: boxColor, caret: .none))
                    .ui2Element("Marker \(index + 1)")
            }
            itemText(item)
                .foregroundStyle(glyphColor)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .textRenderer(renderer(
                    box: boxColor,
                    caret: editing && index == items.count - 1 ? .end : .none,
                    typewriterOffset: item.charOffset
                ))
                .ui2Element(items.count == 1 ? "Text" : "Item \(index + 1)")
        }
    }

    /// One item as concatenated segments, each carrying its word index (for pop / jump) and
    /// whether it sits inside a highlight range.
    private func itemText(_ item: Item) -> SwiftUI.Text {
        item.segments.reduce(SwiftUI.Text(verbatim: "")) { partial, segment in
            let piece = SwiftUI.Text(verbatim: segment.text)
                .font(typeface)
                .customAttribute(CanvasTextSegment(word: segment.word, highlighted: segment.highlighted))
            return SwiftUI.Text("\(partial)\(piece)")
        }
    }

    private func marker(for index: Int) -> SwiftUI.Text? {
        switch listStyle {
        case .none:
            return nil
        case .bullet:
            return SwiftUI.Text(verbatim: "• ").font(typeface)
        case .numbered:
            return SwiftUI.Text(verbatim: "\(index + 1). ").font(typeface)
        case .bibleVerse:
            // §2 List: a superscript verse number in the Bible reader's verse-number style;
            // OQ-C-092-003: counting from `startNumber`.
            // OQ-C-092-6 (owner): the number at 0.5× the object's size, raised 0.4× size, in
            // the object's font and colour.
            let number = SwiftUI.Text(verbatim: "\(startNumber + index)")
                .font(typefaceAt(size * 0.5))
                .baselineOffset(size * 0.4)
            let gap = SwiftUI.Text(verbatim: " ").font(typeface)
            return SwiftUI.Text("\(number)\(gap)")
        }
    }

    // MARK: - Editing input

    /// §2 Editing: when `editing` is true the block is the first responder. The field carries
    /// the input only — its glyphs and caret are clear, and the drawn block shows the text and
    /// the caret at the end of `text` (§2: "system caret at the end of `text`").
    private var inputField: some View {
        // No title: a TextField draws its title as its own prompt, which `.foregroundStyle`
        // does not clear — the drawn block already shows the placeholder.
        TextField(
            "",
            text: Binding(get: { text }, set: { onChange($0) }),
            axis: .vertical
        )
        .accessibilityLabel(Self.placeholder)
        .font(typeface)
        .multilineTextAlignment(textAlignment)
        .foregroundStyle(.clear)
        .tint(.clear)
        .focused($focused)
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
    }

    // MARK: - Manipulation

    /// §4 `onTransform`: drag / pinch / rotate while Manipulating; the caller stores each update.
    /// The width handles are C-091's.
    private var manipulation: some Gesture {
        SimultaneousGesture(
            DragGesture().onChanged { drag in
                let base = gestureBase ?? transform
                gestureBase = base
                var next = currentTransform
                next.position = CGPoint(
                    x: base.position.x + drag.translation.width,
                    y: base.position.y + drag.translation.height
                )
                onTransform(next)
            },
            SimultaneousGesture(
                MagnifyGesture().onChanged { pinch in
                    let base = gestureBase ?? transform
                    gestureBase = base
                    var next = currentTransform
                    next.scale = base.scale * pinch.magnification
                    onTransform(next)
                },
                RotateGesture().onChanged { turn in
                    let base = gestureBase ?? transform
                    gestureBase = base
                    var next = currentTransform
                    next.rotation = base.rotation + turn.rotation
                    onTransform(next)
                }
            )
        )
        .onEnded { _ in gestureBase = nil }
    }

    private var currentTransform: Transform { transform }

    // MARK: - Animation clocks

    /// §2 Animation / effect: looping while editing and after commit. Each clock runs 0 → 1 over
    /// its loop and repeats; a render with animations disabled lands on 1, the rest pose.
    private func startClocks() {
        animationClock = 0
        effectClock = 0
        if animation != .none {
            withAnimation(.linear(duration: animationPeriod).repeatForever(autoreverses: false)) {
                animationClock = 1
            }
        }
        if effect == .sparkle || effect == .shimmer {
            withAnimation(.linear(duration: effectPeriod).repeatForever(autoreverses: false)) {
                effectClock = 1
            }
        }
    }

    /// FLAGGED LITERAL — C-092 §2 Animation / effect (06-animations-and-effects, no `motion-*`
    /// token): typewriter 40 ms/char then a 1 s hold; pop 1 s period; jump 150 ms stagger.
    private var animationPeriod: Double {
        switch animation {
        case .none: return 1
        case .typewriter: return CanvasTextMotion.typewriterHold + CanvasTextMotion.typewriterPerChar * Double(characterTotal)
        case .pop: return CanvasTextMotion.popPeriod
        case .jump: return CanvasTextMotion.jumpStagger * Double(wordTotal) + CanvasTextMotion.jumpDuration
        }
    }

    /// FLAGGED LITERAL — C-092 §2: sparkle glints 300 ms each (three of them); shimmer 1 s sweep.
    private var effectPeriod: Double {
        effect == .sparkle ? CanvasTextMotion.sparkleGlint * 3 : CanvasTextMotion.shimmerSweep
    }

    private func renderer(box: Color?, caret: CanvasTextRenderer.Caret, typewriterOffset: Int? = nil) -> CanvasTextRenderer {
        CanvasTextRenderer(
            animationClock: animationClock,
            effectClock: effectClock,
            box: box,
            highlightColor: Token.highlight,
            caret: caret,
            animation: animation,
            effect: effect,
            glowColor: color,
            size: size,
            typewriterOffset: typewriterOffset,
            animationPeriod: animationPeriod
        )
    }

    // MARK: - Items

    private struct Segment {
        let text: String
        let word: Int
        let highlighted: Bool
    }

    private struct Item {
        let segments: [Segment]
        /// Character offset of the item's first character in `text`.
        let charOffset: Int
    }

    /// `text` split on newlines (§2 List: one item per line), each item cut into segments at
    /// word and highlight boundaries. Words are counted across the whole block.
    private var items: [Item] {
        let highlighted = highlightedOffsets
        var result: [Item] = []
        var charOffset = 0
        var word = -1
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var segments: [Segment] = []
            var current = ""
            var currentWord = 0
            var currentHighlighted = false
            var previousWasSpace = true
            for (i, character) in line.enumerated() {
                let isSpace = character.isWhitespace
                if !isSpace && previousWasSpace { word += 1 }
                let segmentWord = max(word, 0)
                let isHighlighted = highlighted.contains(charOffset + i)
                if !current.isEmpty && (segmentWord != currentWord || isHighlighted != currentHighlighted) {
                    segments.append(Segment(text: current, word: currentWord, highlighted: currentHighlighted))
                    current = ""
                }
                if current.isEmpty {
                    currentWord = segmentWord
                    currentHighlighted = isHighlighted
                }
                current.append(character)
                previousWasSpace = isSpace
            }
            if !current.isEmpty {
                segments.append(Segment(text: current, word: currentWord, highlighted: currentHighlighted))
            }
            result.append(Item(segments: segments, charOffset: charOffset))
            charOffset += line.count + 1
        }
        return result
    }

    /// Character offsets of `text` covered by any highlight range (§2 Highlights: ranges index
    /// into `text`; markers and the reference line are never highlighted).
    private var highlightedOffsets: Set<Int> {
        var offsets = Set<Int>()
        for highlight in highlights {
            let lower = text.distance(from: text.startIndex, to: highlight.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: highlight.range.upperBound)
            if lower < upper { offsets.formUnion(lower..<upper) }
        }
        return offsets
    }

    private var characterTotal: Int {
        max(text.count, 1)
    }

    private var wordTotal: Int {
        max(text.split(whereSeparator: { $0.isWhitespace }).count, 1)
    }

    // MARK: - Style

    /// §2 Typeface: Bold in every face.
    private var typeface: SwiftUI.Font {
        typefaceAt(size)
    }

    private func typefaceAt(_ points: CGFloat) -> SwiftUI.Font {
        switch font {
        case .sfPro:
            return DesignTextStyle(weight: .bold, size: points, lineHeight: nil, tracking: 0).font
        case .poppins:
            return .custom("Poppins-Bold", fixedSize: points).weight(.bold)
        case .georgia:
            return .custom("Georgia-Bold", fixedSize: points)
        case .typewriter:
            return .custom("AmericanTypewriter-Bold", fixedSize: points)
        }
    }

    /// §2 Label: solidLight draws the glyphs black on a box filled with `color`.
    private var glyphColor: Color {
        label == .solidLight ? Token.black : color
    }

    /// §2 Label: solidDark = a black box; solidLight = a box filled with `color`.
    private var boxColor: Color? {
        switch label {
        case .none: return nil
        case .solidDark: return Token.black
        case .solidLight: return color
        }
    }

    /// §2 Label: the box adds its padding to the block's bounds; §2 Effect: Pixel adds ≈3pt per
    /// side, and the box is not expanded for it.
    private var horizontalInset: CGFloat {
        max(label == .none ? 0 : labelInsetX, effect == .pixel ? pixelInset : 0)
    }

    private var verticalInset: CGFloat {
        max(label == .none ? 0 : labelInsetY, effect == .pixel ? pixelInset : 0)
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .center: return .center
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .center: return .center
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var frameAlignment: SwiftUI.Alignment {
        switch alignment {
        case .center: return .center
        case .left: return .leading
        case .right: return .trailing
        }
    }

    // MARK: - Accessibility

    /// §2 Accessibility (R-17): `text` (the placeholder copy when empty), each marker spoken
    /// before its item, the formatted reference last. The label box is decorative.
    private var spokenLabel: String {
        guard !text.isEmpty else { return Self.placeholder }
        var parts: [String] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            switch listStyle {
            case .none: parts.append(String(line))
            case .bullet: parts.append("bullet, \(line)")
            case .numbered: parts.append("\(index + 1), \(line)")
            case .bibleVerse: parts.append("verse \(startNumber + index), \(line)")
            }
        }
        if let reference { parts.append(BibleReferenceFormatter.format(reference)) }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Reference formatter

/// §2 Reference: a pure function of the `Reference` value (R-04). OQ-C-092-004 (owner): a hyphen
/// without spaces within a chapter ("1:1-2"), a spaced en dash across chapters or books
/// ("1:1 – 2:3"). The ruling makes this ONE formatter shared with the Bible reader; the preview
/// module cannot import the app, so it lives here until promotion.
enum BibleReferenceFormatter {
    static func format(_ reference: CanvasTextObject.Reference) -> String {
        let start = reference.start
        guard let end = reference.end, end != start else { return point(start, withBook: true) }
        if end.book != start.book {
            // Across books: the end repeats its book.
            return "\(point(start, withBook: true)) – \(point(end, withBook: true))"
        }
        if end.chapter == start.chapter {
            if let first = start.verse, let last = end.verse {
                return "\(start.book) \(start.chapter):\(first)-\(last)"
            }
            return point(start, withBook: true)
        }
        if start.verse == nil && end.verse == nil {
            // Whole chapters within one book.
            return "\(start.book) \(start.chapter)-\(end.chapter)"
        }
        // Across chapters of one book: the end drops the repeated book name.
        return "\(point(start, withBook: true)) – \(point(end, withBook: false))"
    }

    private static func point(_ point: CanvasTextObject.Reference.Point, withBook: Bool) -> String {
        let place = point.verse.map { "\(point.chapter):\($0)" } ?? "\(point.chapter)"
        return withBook ? "\(point.book) \(place)" : place
    }
}

// MARK: - Rendering

/// FLAGGED LITERAL — C-092 §2 Animation / effect: motion literals from 06-animations-and-effects,
/// no `motion-*` token.
private enum CanvasTextMotion {
    static let typewriterPerChar: Double = 0.04
    static let typewriterHold: Double = 1
    static let popPeriod: Double = 1
    static let popPeak: CGFloat = 1.15
    static let jumpStagger: Double = 0.15
    static let jumpRise: CGFloat = 10
    static let jumpTilt: Double = -10
    /// OQ-C-092-7 (owner): 300 ms per word's jump (two staggers); the loop restarts when the
    /// last word lands.
    static let jumpDuration: Double = 0.3
    static let sparkleGlint: Double = 0.3
    static let shimmerSweep: Double = 1
}

/// What each concatenated segment of an item carries into the renderer.
private struct CanvasTextSegment: TextAttribute {
    let word: Int
    let highlighted: Bool
}

/// Draws one Text of the block, back to front (§2 Label): label box per wrapped line, highlight
/// spans, glyphs (with the animation), the effect, and the caret.
private struct CanvasTextRenderer: TextRenderer, Animatable {
    enum Caret { case none, start, end }

    var animationClock: Double
    var effectClock: Double
    let box: Color?
    let highlightColor: Color
    let caret: Caret
    let animation: CanvasTextObject.Animation
    let effect: CanvasTextObject.Effect
    let glowColor: Color
    let size: CGFloat
    /// The Text's first character offset in `text` when the typewriter types it; nil for the
    /// markers, the reference and the placeholder, which are never typed.
    let typewriterOffset: Int?
    let animationPeriod: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(animationClock, effectClock) }
        set {
            animationClock = newValue.first
            effectClock = newValue.second
        }
    }

    /// FLAGGED LITERAL — C-092 §2 Label: box radius 6pt (no token).
    private let boxRadius: CGFloat = 6
    /// FLAGGED LITERAL — C-092 §2 Label: box padding 8pt / 4pt.
    private let boxInsetX: CGFloat = 8
    private let boxInsetY: CGFloat = 4
    /// FLAGGED LITERAL — C-092 §2 Editing: the system caret, 2pt wide.
    private let caretWidth: CGFloat = 2

    /// Room to draw outside the text's frame: the label box, the jump rise and the glow.
    var displayPadding: EdgeInsets {
        let pad = max(boxInsetX, CanvasTextMotion.jumpRise, size * 0.5)
        return EdgeInsets(top: pad, leading: pad, bottom: pad, trailing: pad)
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        drawBoxes(layout, in: &ctx)
        drawHighlights(layout, in: &ctx)
        drawGlyphs(layout, in: &ctx)
        drawEffectOverlay(layout, in: &ctx)
        drawCaret(layout, in: &ctx)
    }

    // 1 — §2 Label: one box per wrapped line (OQ-C-092-005), never one around the block.
    private func drawBoxes(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        guard let box else { return }
        for line in layout {
            let rect = line.typographicBounds.rect
            guard rect.width > 0 else { continue }
            let boxRect = rect.insetBy(dx: -boxInsetX, dy: -boxInsetY)
            ctx.fill(RoundedRectangle(cornerRadius: boxRadius).path(in: boxRect), with: .color(box))
        }
    }

    // 2 — §2 Highlights: one span per wrapped line, span height = that line's box.
    private func drawHighlights(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            let lineRect = line.typographicBounds.rect
            var span: CGRect?
            for run in line {
                let runRect = run.typographicBounds.rect
                if run[CanvasTextSegment.self]?.highlighted == true {
                    span = span.map { $0.union(runRect) } ?? runRect
                } else if let open = span {
                    fillSpan(open, line: lineRect, in: &ctx)
                    span = nil
                }
            }
            if let open = span { fillSpan(open, line: lineRect, in: &ctx) }
        }
    }

    private func fillSpan(_ span: CGRect, line: CGRect, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: span.minX, y: line.minY, width: span.width, height: line.height)
        ctx.fill(
            RoundedRectangle(cornerRadius: Token.Radius.cardSm).path(in: rect),
            with: .color(highlightColor)
        )
    }

    // 3 — glyphs, with the animation per character / per word, and the glyph effects.
    private func drawGlyphs(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        let visible = visibleCharacters
        let wordRects = wordBounds(layout)
        var index = 0
        for line in layout {
            for run in line {
                let word = run[CanvasTextSegment.self]?.word
                for slice in run {
                    defer { index += 1 }
                    if let typewriterOffset, typewriterOffset + index >= visible { continue }
                    var glyph = ctx
                    if let word, let rect = wordRects[word] {
                        applyWordMotion(word: word, rect: rect, to: &glyph)
                    }
                    drawWithEffect(slice, in: &glyph)
                }
            }
        }
    }

    private func drawWithEffect(_ slice: Text.Layout.RunSlice, in ctx: inout GraphicsContext) {
        switch effect {
        case .neon:
            // §2: glow in `color`. OQ-C-092-8 (owner): blur radius = size / 4, one glow pass
            // under the glyphs.
            var glow = ctx
            glow.addFilter(.shadow(color: glowColor, radius: size * 0.25))
            glow.draw(slice)
            ctx.draw(slice)
        case .pixel:
            // §2: a dark outline and an offset shadow inside the ≈3pt the bounds grow by
            // (1.5pt outline + 1.5pt shadow offset). The coarse raster is not drawn — see the
            // build report's gaps.
            var dark = ctx
            dark.addFilter(.colorMultiply(Token.black))
            let outline: CGFloat = 1.5
            var shadow = dark
            shadow.translateBy(x: outline * 2, y: outline * 2)
            shadow.draw(slice)
            for dx in [-outline, 0, outline] {
                for dy in [-outline, 0, outline] where dx != 0 || dy != 0 {
                    var ring = dark
                    ring.translateBy(x: dx, y: dy)
                    ring.draw(slice)
                }
            }
            ctx.draw(slice)
        case .none, .sparkle, .shimmer:
            ctx.draw(slice)
        }
    }

    // 4 — the effects drawn over the glyphs.
    private func drawEffectOverlay(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        switch effect {
        case .shimmer:
            // §2: a diagonal light band sweeping the glyphs once per second.
            // OQ-C-092-9 (owner): one line-height wide, slanted 20°, peaking at color-white-50,
            // clipped to the glyphs.
            for line in layout {
                let rect = line.typographicBounds.rect
                guard rect.width > 0 else { continue }
                let band = rect.height
                let x = rect.minX - band + CGFloat(effectClock) * (rect.width + band * 2)
                ctx.drawLayer { layer in
                    layer.clipToLayer { mask in mask.draw(line) }
                    let shape = Path(CGRect(x: x, y: rect.minY - band, width: band, height: rect.height + band * 2))
                        .applying(CGAffineTransform(a: 1, b: 0, c: -0.36, d: 1, tx: rect.midY * 0.36, ty: 0))
                    layer.fill(shape, with: .linearGradient(
                        Gradient(colors: [.clear, Token.white50, .clear]),
                        startPoint: CGPoint(x: x, y: rect.midY),
                        endPoint: CGPoint(x: x + band, y: rect.midY)
                    ))
                }
            }
        case .sparkle:
            // §2: 1–3 white four-point glints, 300 ms each. OQ-C-092-10 (owner): three glints in
            // turn at ¼, ½ and ¾ of the first line, up to 0.4× size, color-white-100.
            guard let line = layout.first else { return }
            let rect = line.typographicBounds.rect
            for glint in 0..<3 {
                let local = effectClock * 3 - Double(glint)
                guard local > 0, local < 1 else { continue }
                let fraction = CGFloat(glint + 1) / 4
                let centre = CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY + rect.height * (glint == 1 ? 0.15 : 0.3))
                let radius = size * 0.4 * CGFloat(sin(local * .pi))
                ctx.fill(fourPointStar(centre: centre, radius: radius), with: .color(Token.white100))
            }
        case .none, .neon, .pixel:
            break
        }
    }

    // 5 — §2 Editing: the caret, after the last glyph (or before the placeholder).
    private func drawCaret(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        let lines = Array(layout)
        let x: CGFloat
        let rect: CGRect
        switch caret {
        case .none:
            return
        case .start:
            guard let first = lines.first else { return }
            rect = first.typographicBounds.rect
            x = rect.minX - caretWidth - 1
        case .end:
            guard let last = lines.last else { return }
            rect = last.typographicBounds.rect
            x = rect.maxX + 1
        }
        // FLAGGED LITERAL — C-092 §2 Editing: the caret takes the system tint, no token.
        ctx.fill(
            RoundedRectangle(cornerRadius: caretWidth / 2)
                .path(in: CGRect(x: x, y: rect.minY, width: caretWidth, height: rect.height)),
            with: .color(.accentColor)
        )
    }

    // MARK: Animation

    /// §2 typewriter: 40 ms per character, then a 1 s hold, looping. The loop starts in the hold
    /// so phase 0 and phase 1 both draw every character.
    private var visibleCharacters: Int {
        guard animation == .typewriter else { return Int.max }
        let elapsed = animationClock * animationPeriod
        guard elapsed > CanvasTextMotion.typewriterHold else { return Int.max }
        return Int((elapsed - CanvasTextMotion.typewriterHold) / CanvasTextMotion.typewriterPerChar)
    }

    private func applyWordMotion(word: Int, rect: CGRect, to ctx: inout GraphicsContext) {
        switch animation {
        case .pop:
            // §2: per word, scale 1.0 → 1.15 → 1.0 over a 1 s period.
            let scale = 1 + (CanvasTextMotion.popPeak - 1) * CGFloat(sin(animationClock * .pi))
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
        case .jump:
            // §2: per word +10pt / −10°, 150 ms stagger.
            let elapsed = animationClock * animationPeriod - CanvasTextMotion.jumpStagger * Double(word)
            guard elapsed > 0, elapsed < CanvasTextMotion.jumpDuration else { return }
            let lift = sin(elapsed / CanvasTextMotion.jumpDuration * .pi)
            ctx.translateBy(x: rect.midX, y: rect.midY - CanvasTextMotion.jumpRise * CGFloat(lift))
            ctx.rotate(by: .degrees(CanvasTextMotion.jumpTilt * lift))
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
        case .none, .typewriter:
            break
        }
    }

    /// Each word's bounds, so pop and jump move a word about its own centre.
    private func wordBounds(_ layout: Text.Layout) -> [Int: CGRect] {
        guard animation == .pop || animation == .jump else { return [:] }
        var rects: [Int: CGRect] = [:]
        for line in layout {
            for run in line {
                guard let word = run[CanvasTextSegment.self]?.word else { continue }
                let rect = run.typographicBounds.rect
                rects[word] = rects[word].map { $0.union(rect) } ?? rect
            }
        }
        return rects
    }

    private func fourPointStar(centre: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let waist = radius * 0.25
        path.move(to: CGPoint(x: centre.x, y: centre.y - radius))
        path.addLine(to: CGPoint(x: centre.x + waist, y: centre.y - waist))
        path.addLine(to: CGPoint(x: centre.x + radius, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x + waist, y: centre.y + waist))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y + radius))
        path.addLine(to: CGPoint(x: centre.x - waist, y: centre.y + waist))
        path.addLine(to: CGPoint(x: centre.x - radius, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x - waist, y: centre.y - waist))
        path.closeSubpath()
        return path
    }
}
