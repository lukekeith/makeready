//
//  CanvasTextObject.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-092-canvastextobject in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import CoreText
import SwiftUI

/// C-092 CanvasTextObject — one text object on the activity canvas.
///
/// §2: a single text block with no outline, handles or padding of its own beyond the optional
/// label box. The frame, the position on the canvas, the side width handles, the scrim, the
/// delete target and the centre guide are C-091 ActivityCanvas's (R-16, OQ-C-092-001).
///
/// §2 Units (D1): every length here is a width unit (wu), the 440-wide reference space. C-091
/// lays its slot out in that space and scales the whole page by `canvas width / 440`, so inside
/// the canvas one point of layout IS one wu and this view adds no second conversion.
///
/// The block is `text` split into items on newlines. Each item is a Text drawn by
/// `CanvasTextRenderer`, which paints back to front (§2 Label): the label box per wrapped line,
/// the highlight spans, the glyphs (with the animation), the effect, and the caret.
///
/// Controlled (R-01): the caller owns `text` and `transform` and gets every change back through
/// `onChange` / `onTransform`; the host owns the animation clock through `animationStart` (D10).
/// Width-driven, chrome-free (R-16): with `transform.width` nil the block fills the width it is
/// given (C-091's edit slot) and states its own intrinsic height.
struct CanvasTextObject: View {
    /// §4 `mode` (D9).
    enum Mode {
        case editor, viewer
    }

    /// §4 `font` — a key, never a platform name (D6); this row owns the set.
    enum Font: CaseIterable {
        case display, sans, serif, mono
    }

    /// §4 `weight` — applied to the whole block (D5).
    enum Weight {
        case regular, medium, bold
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

    /// §4 `marks` element — inline styling over `start..<end`, in UTF-16 code units of `text`
    /// (D5, D7). Kinds combine on overlapping ranges.
    struct Mark: Equatable {
        enum Kind: Equatable {
            case bold, italic
            case link(href: String)
        }

        var start: Int
        var end: Int
        var kind: Kind
    }

    /// §4 `animation` (D10). It runs only while the host's clock runs.
    struct Animation: Equatable {
        enum Kind {
            case none, typewriter, pop, jump
        }

        enum Trigger {
            case onActive
        }

        var kind: Kind
        var trigger: Trigger = .onActive
        var loop: Bool = false

        static let none = Animation(kind: .none)
    }

    /// §4 `effect` — glyph effect, defined in §2 Effects (D11).
    enum Effect {
        case none, sparkle, neon, shimmer, pixel
    }

    /// §4 `transform` — canvas placement and layout width, all in wu.
    struct Transform: Equatable {
        /// The centre point C-091 places the block at; this view never offsets itself (R-16).
        var position: CGPoint
        var scale: CGFloat
        var rotation: Angle
        /// The layout width set by C-091's side handles; nil = the edit slot.
        var width: CGFloat?

        static let identity = Transform(position: .zero, scale: 1, rotation: .zero, width: nil)
    }

    /// §4 `highlights` element — `start..<end` in UTF-16 code units of `text` (D7).
    struct TextRange: Equatable {
        var start: Int
        var end: Int
        var note: String?
    }

    /// §4 — multi-line content, one item per line when `listStyle` is not none.
    let text: String
    /// §4 — the caller stores every edit (R-01).
    let onChange: (String) -> Void
    /// §4 — `viewer`: no gestures, no input field, no caret, no placeholder (D9).
    let mode: Mode
    /// §4 — the typeface key.
    let font: Font
    /// §4 — whole-block weight.
    let weight: Weight
    /// §4 — the size in wu, written by C-093 TextSizeSlider.
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
    /// §4 — inline bold / italic / link.
    let marks: [Mark]
    /// §4 — the animation definition.
    let animation: Animation
    /// §4 — the host's clock: nil = stopped at the rest pose; a date = running since then (D10).
    let animationStart: Date?
    /// §4 — the glyph effect.
    let effect: Effect
    /// §4 — placement and layout width.
    let transform: Transform
    /// §4 — drag / pinch / rotate updates while Manipulating; the caller stores them (R-01).
    let onTransform: (Transform) -> Void
    /// §4 — first responder with the caret; the keyboard is the screen's. Ignored in `viewer`.
    let editing: Bool
    /// §4 — ranges drawn as highlight spans.
    let highlights: [TextRange]
    /// §4 — a tap with no movement on a committed object (C-091 turns it into Editing).
    let onTap: () -> Void
    /// §4 — a tap on a `link` mark in `viewer` (the href).
    let onOpenLink: (String) -> Void

    /// R-05: one parameter per §4 prop, in the contract's order (`startNumber` after
    /// `listStyle`, OQ-C-092-003). Written out because the private focus state would otherwise
    /// make the memberwise initializer private.
    init(
        text: String,
        onChange: @escaping (String) -> Void = { _ in },
        mode: Mode = .editor,
        font: Font = .sans,
        weight: Weight = .bold,
        size: CGFloat,
        color: Color = Token.textPrimary,
        alignment: Alignment = .center,
        label: Label = .none,
        listStyle: ListStyle = .none,
        startNumber: Int = 1,
        reference: Reference? = nil,
        marks: [Mark] = [],
        animation: Animation = .none,
        animationStart: Date? = nil,
        effect: Effect = .none,
        transform: Transform = .identity,
        onTransform: @escaping (Transform) -> Void = { _ in },
        editing: Bool,
        highlights: [TextRange] = [],
        onTap: @escaping () -> Void = {},
        onOpenLink: @escaping (String) -> Void = { _ in }
    ) {
        self.text = text
        self.onChange = onChange
        self.mode = mode
        self.font = font
        self.weight = weight
        self.size = size
        self.color = color
        self.alignment = alignment
        self.label = label
        self.listStyle = listStyle
        self.startNumber = startNumber
        self.reference = reference
        self.marks = marks
        self.animation = animation
        self.animationStart = animationStart
        self.effect = effect
        self.transform = transform
        self.onTransform = onTransform
        self.editing = editing
        self.highlights = highlights
        self.onTap = onTap
        self.onOpenLink = onOpenLink
    }

    /// R-02: focus is ephemeral feedback, mirrored from the `editing` prop.
    @FocusState private var focused: Bool
    /// R-02: the transform a gesture started from, held only while the finger is down.
    @State private var gestureBase: Transform?
    /// §2 Animation: Reduce Motion ignores the clock and holds the rest pose.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// §2 Editing — the placeholder copy (OQ-activities-editor-014).
    private static let placeholder = "Type something…"
    /// FLAGGED LITERAL — C-092 §2 Width & wrapping: 80 wu minimum width, 392 wu maximum (the edit
    /// slot, C-091's 24 wu inset).
    private let widthLimits: ClosedRange<CGFloat> = 80...392
    /// FLAGGED LITERAL — C-092 §2 Label: box = glyph width + 8 wu each side, line box + 4 wu each
    /// side (measured on the Instagram recording, no token).
    private let labelInsetX: CGFloat = 8
    private let labelInsetY: CGFloat = 4
    /// FLAGGED LITERAL — C-092 §2 Effects: Pixel adds 3 wu per side to the bounds.
    private let pixelInset: CGFloat = 3

    /// §2 Modes: `editing` is ignored in `viewer`.
    private var isEditing: Bool { mode == .editor && editing }

    var body: some View {
        switch mode {
        case .editor:
            placed
                .contentShape(Rectangle())
                .onTapGesture { if !isEditing { onTap() } }
                .simultaneousGesture(manipulation, including: isEditing ? .subviews : .all)
                .accessibilityElement(children: isEditing ? .contain : .ignore)
                .accessibilityLabel(isEditing ? "" : spokenLabel)
                .accessibilityAddTraits(isEditing ? [] : .isButton)
                .onAppear { focused = isEditing }
                .onChange(of: isEditing) { _, now in focused = now }
                .ui2Element("CanvasTextObject")
        case .viewer:
            // §2 Modes: no gesture of any kind, so a vertical drag falls through to the viewer's
            // scroll and pager. Only a `link` mark is interactive, through the Text's own link.
            viewerAccessibility(placed)
                .tint(glyphColor)
                .environment(\.openURL, OpenURLAction { url in
                    onOpenLink(url.absoluteString)
                    return .handled
                })
                .ui2Element("CanvasTextObject")
        }
    }

    /// The block at its layout width, with the committed transform applied about its centre.
    /// Every inset is symmetric, so the block's measured centre is the glyph run's (§2 Centring).
    private var placed: some View {
        block
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(width: transform.width.map { min(max($0, widthLimits.lowerBound), widthLimits.upperBound) })
            .frame(maxWidth: transform.width == nil ? .infinity : nil, alignment: frameAlignment)
            .overlay { if isEditing { inputField } }
            .scaleEffect(isEditing ? 1 : transform.scale)
            .rotationEffect(isEditing ? .zero : transform.rotation)
    }

    /// §2 Accessibility: static text, not a button. A `link` range is exposed as a link, which
    /// needs the Text's own element; without one the spoken label carries markers and reference.
    @ViewBuilder
    private func viewerAccessibility(_ content: some View) -> some View {
        if marks.contains(where: { if case .link = $0.kind { return true } else { return false } }) {
            content.accessibilityElement(children: .combine)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Block

    private var block: some View {
        let items = self.items
        let graphemes = items.reduce(0) { $0 + $1.graphemes }
        let words = max(text.split(whereSeparator: { $0.isWhitespace }).count, 1)
        // §2 Animation: the clock is one value. The timeline only ticks while it runs, and it is
        // always here so that starting the clock never rebuilds the block under the input field.
        return TimelineView(.animation(paused: !clockRuns)) { timeline in
            let elapsed = clockRuns ? animationStart.map { timeline.date.timeIntervalSince($0) } : nil
            let motion = CanvasTextRenderer.Motion(elapsed: elapsed, graphemes: graphemes, words: words)
            VStack(alignment: stackAlignment, spacing: 0) {
                if text.isEmpty {
                    placeholderRow(motion)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        itemRow(index: index, item: item, motion: motion)
                    }
                }
                if let reference {
                    // §2 Reference: one natural line below the last item; no marker, never
                    // highlighted, not editable in place.
                    SwiftUI.Text(verbatim: BibleReferenceFormatter.format(reference))
                        .font(typeface)
                        .foregroundStyle(glyphColor)
                        .multilineTextAlignment(textAlignment)
                        .textRenderer(renderer(box: boxColor, caret: .none, motion: motion))
                        .ui2Element("Reference")
                }
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .accessibilityHidden(isEditing)
        }
    }

    /// §2 Editing: the placeholder never shows a list marker or a label box. §2 Modes: the viewer
    /// has no placeholder, so empty `text` draws nothing.
    @ViewBuilder
    private func placeholderRow(_ motion: CanvasTextRenderer.Motion) -> some View {
        if mode == .editor {
            SwiftUI.Text(verbatim: Self.placeholder)
                .font(typeface)
                .foregroundStyle(Token.white50)
                .multilineTextAlignment(textAlignment)
                .textRenderer(renderer(box: nil, caret: isEditing ? .start : .none, motion: motion))
                .ui2Element("Placeholder")
        }
    }

    private func itemRow(index: Int, item: Item, motion: CanvasTextRenderer.Motion) -> some View {
        // §2 List: markers hang in a gutter — wrapped lines align with the item's first glyph.
        // The gap is the marker's own trailing space in the object's font, not a spacing value.
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let marker = marker(for: index) {
                marker
                    .foregroundStyle(glyphColor)
                    .textRenderer(renderer(box: boxColor, caret: .none, motion: motion))
                    .ui2Element("Marker \(index + 1)")
            }
            itemText(item)
                .foregroundStyle(glyphColor)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .textRenderer(renderer(
                    box: boxColor,
                    caret: isEditing && index == items.count - 1 ? .end : .none,
                    motion: motion,
                    sparkles: index == 0
                ))
                .ui2Element(items.count == 1 ? "Text" : "Item \(index + 1)")
        }
    }

    /// One item as concatenated segments, each carrying its word and grapheme index (for the
    /// animations) and whether it sits inside a highlight range.
    private func itemText(_ item: Item) -> SwiftUI.Text {
        item.segments.reduce(SwiftUI.Text(verbatim: "")) { partial, segment in
            let piece = segmentText(segment)
                .font(font.face(weight: segment.bold ? .bold : weight, italic: segment.italic, size: size))
                .underline(segment.href != nil)
                .customAttribute(CanvasTextSegment(
                    word: segment.word,
                    grapheme: segment.grapheme,
                    highlighted: segment.highlighted
                ))
            // §2 Highlights (legibility fix): glyphs inside a span draw `color-black`.
            let inked = segment.highlighted ? piece.foregroundStyle(Token.black) : piece
            return SwiftUI.Text("\(partial)\(inked)")
        }
    }

    /// §2 Marks: a link is only a real link in the viewer; in the editor it is drawn, not tappable.
    private func segmentText(_ segment: Segment) -> SwiftUI.Text {
        guard mode == .viewer, let href = segment.href, let url = URL(string: href) else {
            return SwiftUI.Text(verbatim: segment.text)
        }
        var linked = AttributedString(segment.text)
        linked.link = url
        return SwiftUI.Text(linked)
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
                .font(font.face(weight: weight, size: size * 0.5))
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

    /// §4 `onTransform`: drag / pinch / rotate while Manipulating; the caller stores each update,
    /// in wu — C-091's scale is applied outside this view, so a translation here is already wu.
    /// The width handles are C-091's.
    private var manipulation: some Gesture {
        SimultaneousGesture(
            // pan-ok: free 2-D move on the canvas
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

    // MARK: - Clock

    /// §2 Animation: motion runs only while the host's clock runs, and never under Reduce Motion.
    /// A static effect (neon, pixel) needs no clock.
    private var clockRuns: Bool {
        guard animationStart != nil, !reduceMotion else { return false }
        return animation.kind != .none || effect == .shimmer || effect == .sparkle
    }

    private func renderer(
        box: Color?,
        caret: CanvasTextRenderer.Caret,
        motion: CanvasTextRenderer.Motion,
        sparkles: Bool = false
    ) -> CanvasTextRenderer {
        CanvasTextRenderer(
            motion: motion,
            box: box,
            highlightColor: Token.highlight,
            caret: caret,
            animation: animation,
            effect: effect,
            glowColor: color,
            size: size,
            sparkles: sparkles
        )
    }

    // MARK: - Items

    private struct Segment {
        let text: String
        let word: Int
        let grapheme: Int
        let highlighted: Bool
        let bold: Bool
        let italic: Bool
        let href: String?
    }

    private struct Item {
        let segments: [Segment]
        let graphemes: Int
    }

    /// What one grapheme's UTF-16 start offset is styled with; two graphemes with equal styles
    /// share a segment.
    private struct CharacterStyle: Equatable {
        var highlighted = false
        var bold = false
        var italic = false
        var href: String?
    }

    /// `text` split on newlines (§2 List: one item per line), each item cut into segments at word,
    /// highlight and mark boundaries — and at every grapheme under the typewriter, which reveals
    /// one at a time. Words and graphemes are counted across the whole block; offsets walk
    /// `utf16` (D7), never grapheme distance.
    private var items: [Item] {
        let styles = styledOffsets
        let perGrapheme = animation.kind == .typewriter
        var result: [Item] = []
        var utf16Offset = 0
        var word = -1
        var grapheme = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var segments: [Segment] = []
            var current = ""
            var currentWord = 0
            var currentGrapheme = 0
            var currentStyle = CharacterStyle()
            var previousWasSpace = true
            var count = 0
            func flush() {
                guard !current.isEmpty else { return }
                segments.append(Segment(
                    text: current, word: currentWord, grapheme: currentGrapheme,
                    highlighted: currentStyle.highlighted, bold: currentStyle.bold,
                    italic: currentStyle.italic, href: currentStyle.href
                ))
                current = ""
            }
            for character in line {
                let isSpace = character.isWhitespace
                if !isSpace && previousWasSpace { word += 1 }
                let segmentWord = max(word, 0)
                let style = styles[utf16Offset] ?? CharacterStyle()
                if perGrapheme || segmentWord != currentWord || style != currentStyle { flush() }
                if current.isEmpty {
                    currentWord = segmentWord
                    currentGrapheme = grapheme
                    currentStyle = style
                }
                current.append(character)
                previousWasSpace = isSpace
                utf16Offset += character.utf16.count
                grapheme += 1
                count += 1
            }
            flush()
            result.append(Item(segments: segments, graphemes: count))
            utf16Offset += 1
        }
        return result
    }

    /// The style of each styled UTF-16 offset of `text`. §2 Highlights / Marks: a range is
    /// `start..<end` in UTF-16 code units; out-of-range is clamped, reversed is dropped, never a
    /// crash. Markers and the reference line are never covered.
    private var styledOffsets: [Int: CharacterStyle] {
        let total = text.utf16.count
        var styles: [Int: CharacterStyle] = [:]
        func apply(_ start: Int, _ end: Int, _ change: (inout CharacterStyle) -> Void) {
            let lower = max(start, 0)
            let upper = min(end, total)
            guard lower < upper else { return }
            for offset in lower..<upper { change(&styles[offset, default: CharacterStyle()]) }
        }
        for highlight in highlights {
            apply(highlight.start, highlight.end) { $0.highlighted = true }
        }
        for mark in marks {
            switch mark.kind {
            case .bold: apply(mark.start, mark.end) { $0.bold = true }
            case .italic: apply(mark.start, mark.end) { $0.italic = true }
            case .link(let href): apply(mark.start, mark.end) { $0.href = href }
            }
        }
        return styles
    }

    // MARK: - Style

    /// §2 Typeface + Weight, at the object's size.
    private var typeface: SwiftUI.Font {
        font.face(weight: weight, size: size)
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

    /// §2 Label: the box adds its padding to the block's bounds; §2 Effects: Pixel adds 3 wu per
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

    /// §2 Accessibility (R-17): `text` (the placeholder copy when empty in the editor), each
    /// marker spoken before its item, the formatted reference last. The label box is decorative.
    private var spokenLabel: String {
        guard !text.isEmpty else { return mode == .editor ? Self.placeholder : "" }
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

// MARK: - Fonts

/// §2 Typeface (D6): the four bundled open-licensed families, registered once, before first draw,
/// with no Info.plist entry. Copy Bundle Resources flattens them into the bundle's root.
private enum CanvasTextFonts {
    static let registered: Void = {
        let urls = Bundle.ui2Preview.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            // Silent: a file that fails to register falls back to the system face of its role.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    /// The OpenType `wght` axis tag.
    static let weightAxis = 0x7767_6874
}

extension CanvasTextObject.Font {
    /// The face for this key. C-035 `type=Font` samples through this too, so one row owns the
    /// mapping.
    func face(weight: CanvasTextObject.Weight, italic: Bool = false, size: CGFloat) -> SwiftUI.Font {
        _ = CanvasTextFonts.registered
        let name: String
        switch self {
        case .display: name = "Poppins-\(styleName(weight: weight, italic: italic))"
        case .sans: name = "Inter-\(styleName(weight: weight, italic: italic))"
        // §2 Weight: Courier Prime ships 400 and 700 only, so `mono` at 500 draws 400.
        case .mono: name = "CourierPrime-\(styleName(weight: weight == .medium ? .regular : weight, italic: italic))"
        case .serif: return serifFace(weight: weight, italic: italic, size: size)
        }
        guard UIFont(name: name, size: size) != nil else {
            return systemFallback(weight: weight, italic: italic, size: size)
        }
        return .custom(name, fixedSize: size)
    }

    private func styleName(weight: CanvasTextObject.Weight, italic: Bool) -> String {
        switch weight {
        case .regular: return italic ? "Italic" : "Regular"
        case .medium: return italic ? "MediumItalic" : "Medium"
        case .bold: return italic ? "BoldItalic" : "Bold"
        }
    }

    /// Source Serif 4 ships no static 500, so its variable files carry every weight.
    private func serifFace(weight: CanvasTextObject.Weight, italic: Bool, size: CGFloat) -> SwiftUI.Font {
        let name = italic ? "SourceSerif4Variable-Italic" : "SourceSerif4Variable-Roman"
        guard UIFont(name: name, size: size) != nil else {
            return systemFallback(weight: weight, italic: italic, size: size)
        }
        let wght: Double
        switch weight {
        case .regular: wght = 400
        case .medium: wght = 500
        case .bold: wght = 700
        }
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: name,
            kCTFontVariationAttribute: [CanvasTextFonts.weightAxis: wght]
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return SwiftUI.Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }

    /// §2 Typeface: a face whose file failed to register falls back to the system face of the
    /// same role; the key is unchanged.
    private func systemFallback(weight: CanvasTextObject.Weight, italic: Bool, size: CGFloat) -> SwiftUI.Font {
        let uiWeight: UIFont.Weight
        switch weight {
        case .regular: uiWeight = .regular
        case .medium: uiWeight = .medium
        case .bold: uiWeight = .bold
        }
        var descriptor = UIFont.systemFont(ofSize: size, weight: uiWeight).fontDescriptor
        let design: UIFontDescriptor.SystemDesign
        switch self {
        case .sans: design = .default
        case .serif: design = .serif
        case .mono: design = .monospaced
        case .display: design = .rounded
        }
        descriptor = descriptor.withDesign(design) ?? descriptor
        if italic { descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor }
        return SwiftUI.Font(UIFont(descriptor: descriptor, size: size) as CTFont)
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

/// FLAGGED LITERAL — C-092 §2 Animation / Effects: every motion and effect figure, wu and seconds,
/// no `motion-*` token. Both platforms follow them.
private enum CanvasTextMotion {
    static let typewriterPerGrapheme: Double = 0.04
    static let typewriterHold: Double = 1
    static let wordDuration: Double = 0.3
    static let wordRest: Double = 1
    static let popStagger: Double = 0.1
    static let popPeak: CGFloat = 1.15
    static let jumpStagger: Double = 0.15
    static let jumpRise: CGFloat = 10
    static let jumpTilt: Double = -10
    static let neonGlows: [(blur: CGFloat, opacity: Double)] = [(4, 1), (10, 0.8), (20, 0.6)]
    static let shimmerWidth: CGFloat = 0.35
    static let shimmerLean: Double = 20
    static let shimmerPeak: Double = 0.6
    static let shimmerSweep: Double = 1
    static let shimmerPeriod: Double = 2
    static let sparkleSpots: [CGPoint] = [
        CGPoint(x: 0.15, y: 0.20), CGPoint(x: 0.55, y: 0.80), CGPoint(x: 0.85, y: 0.30)
    ]
    static let sparkleGlint: Double = 0.3
    static let sparklePeriod: Double = 1.2
    static let sparkleSpan: CGFloat = 0.6
    static let pixelOutline: CGFloat = 1
    static let pixelShadow: CGFloat = 2
}

/// What each concatenated segment of an item carries into the renderer.
private struct CanvasTextSegment: TextAttribute {
    let word: Int
    let grapheme: Int
    let highlighted: Bool
}

/// Draws one Text of the block, back to front (§2 Label): label box per wrapped line, highlight
/// spans, glyphs (with the animation), the effect, and the caret.
private struct CanvasTextRenderer: TextRenderer {
    enum Caret { case none, start, end }

    /// §2 Animation: the seconds since the host's clock started, or nil at the rest pose.
    struct Motion {
        let elapsed: Double?
        /// Totals across the whole block: they set each animation's cycle.
        let graphemes: Int
        let words: Int
    }

    let motion: Motion
    let box: Color?
    let highlightColor: Color
    let caret: Caret
    let animation: CanvasTextObject.Animation
    let effect: CanvasTextObject.Effect
    let glowColor: Color
    let size: CGFloat
    /// §2 Effects: the sparkle's three glints belong to the block, so one Text draws them.
    let sparkles: Bool

    /// FLAGGED LITERAL — C-092 §2 Label: box radius 6 wu (no token).
    private let boxRadius: CGFloat = 6
    /// FLAGGED LITERAL — C-092 §2 Label: box padding 8 / 4 wu.
    private let boxInsetX: CGFloat = 8
    private let boxInsetY: CGFloat = 4
    /// FLAGGED LITERAL — C-092 §2 Editing: the system caret, 2 wu wide.
    private let caretWidth: CGFloat = 2

    /// Room to draw above and below the text's frame: the label box, the jump rise, the glints
    /// and the widest neon glow. §2 Centring: vertical only. SwiftUI aligns a Text's lines inside
    /// the width widened by this padding, so horizontal padding pushed centred lines right by it
    /// and right-aligned lines by twice it (the ~12 wu defect at size 24).
    var displayPadding: EdgeInsets {
        let widestGlow = effect == .neon ? (CanvasTextMotion.neonGlows.last?.blur ?? 0) * 1.5 : 0
        let pad = max(boxInsetY, CanvasTextMotion.jumpRise, size * 0.5, widestGlow)
        return EdgeInsets(top: pad, leading: 0, bottom: pad, trailing: 0)
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

    // 3 — glyphs, with the animation per grapheme / per word, and the glyph effects.
    private func drawGlyphs(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        let revealed = revealedGraphemes
        let wordRects = wordBounds(layout)
        for line in layout {
            for run in line {
                let segment = run[CanvasTextSegment.self]
                // §2 typewriter: hidden graphemes are transparent, not removed, so nothing reflows.
                if let segment, segment.grapheme >= revealed { continue }
                var glyph = ctx
                if let word = segment?.word, let rect = wordRects[word] {
                    applyWordMotion(word: word, rect: rect, to: &glyph)
                }
                for slice in run {
                    drawWithEffect(slice, in: glyph)
                }
            }
        }
    }

    private func drawWithEffect(_ slice: Text.Layout.RunSlice, in ctx: GraphicsContext) {
        switch effect {
        case .neon:
            // §2 neon: three glow layers in `color`, no offset. SwiftUI's shadow radius is the
            // blur's standard deviation, half the CSS blur the definition is written in.
            for glow in CanvasTextMotion.neonGlows {
                var layer = ctx
                layer.addFilter(.shadow(color: glowColor.opacity(glow.opacity), radius: glow.blur / 2))
                layer.draw(slice)
            }
            ctx.draw(slice)
        case .pixel:
            // §2 pixel: the coarse raster is dropped. A 1 wu black outline around every glyph
            // plus a hard black offset shadow of (2, 2) wu, no blur.
            var dark = ctx
            dark.addFilter(.colorMultiply(Token.black))
            var shadow = dark
            shadow.translateBy(x: CanvasTextMotion.pixelShadow, y: CanvasTextMotion.pixelShadow)
            shadow.draw(slice)
            let outline = CanvasTextMotion.pixelOutline
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

    // 4 — the effects drawn over the glyphs; with the clock stopped they hold their rest pose.
    private func drawEffectOverlay(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        guard let elapsed = motion.elapsed else { return }
        let bounds = layout.reduce(CGRect.null) { $0.union($1.typographicBounds.rect) }
        guard !bounds.isNull, bounds.width > 0 else { return }
        switch effect {
        case .shimmer:
            drawShimmer(layout, bounds: bounds, elapsed: elapsed, in: &ctx)
        case .sparkle where sparkles:
            drawSparkles(bounds: bounds, elapsed: elapsed, in: &ctx)
        case .none, .neon, .pixel, .sparkle:
            break
        }
    }

    /// §2 shimmer: a white band, peak 0.6 fading linearly to its edges, 0.35 × the block's width,
    /// leaning 20° from vertical, masked to the glyphs; sweeps left → right in 1000 ms, then rests
    /// for 1000 ms.
    private func drawShimmer(_ layout: Text.Layout, bounds: CGRect, elapsed: Double, in ctx: inout GraphicsContext) {
        let phase = elapsed.truncatingRemainder(dividingBy: CanvasTextMotion.shimmerPeriod) / CanvasTextMotion.shimmerSweep
        guard phase < 1 else { return }
        let band = bounds.width * CanvasTextMotion.shimmerWidth
        let centreX = bounds.minX - band + CGFloat(phase) * (bounds.width + band * 2)
        let lean = CanvasTextMotion.shimmerLean * .pi / 180
        // The gradient runs across the leaning band: along its normal, its width measured
        // horizontally.
        let half = CGVector(dx: cos(lean) * cos(lean) * band / 2, dy: sin(lean) * cos(lean) * band / 2)
        let centre = CGPoint(x: centreX, y: bounds.midY)
        ctx.drawLayer { layer in
            layer.clipToLayer { mask in
                for line in layout { mask.draw(line) }
            }
            layer.fill(Path(bounds), with: .linearGradient(
                Gradient(colors: [
                    Token.white100.opacity(0),
                    Token.white100.opacity(CanvasTextMotion.shimmerPeak),
                    Token.white100.opacity(0)
                ]),
                startPoint: CGPoint(x: centre.x - half.dx, y: centre.y - half.dy),
                endPoint: CGPoint(x: centre.x + half.dx, y: centre.y + half.dy)
            ))
        }
    }

    /// §2 sparkle: three white four-point glints at fixed fractions of the bounds, tip to tip
    /// 0.6 × size; glint k runs from k × 300 ms, scale and opacity 0 → 1 → 0; period 1200 ms.
    private func drawSparkles(bounds: CGRect, elapsed: Double, in ctx: inout GraphicsContext) {
        let time = elapsed.truncatingRemainder(dividingBy: CanvasTextMotion.sparklePeriod)
        for (glint, spot) in CanvasTextMotion.sparkleSpots.enumerated() {
            let local = (time - Double(glint) * CanvasTextMotion.sparkleGlint) / CanvasTextMotion.sparkleGlint
            guard local > 0, local < 1 else { continue }
            let pulse = sin(local * .pi)
            let centre = CGPoint(x: bounds.minX + bounds.width * spot.x, y: bounds.minY + bounds.height * spot.y)
            let radius = size * CanvasTextMotion.sparkleSpan / 2 * CGFloat(pulse)
            var layer = ctx
            layer.opacity = pulse
            layer.fill(fourPointStar(centre: centre, radius: radius), with: .color(Token.white100))
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

    /// The animation's time within its cycle, or nil at the rest pose: the clock stopped, or a
    /// one-shot that has finished (§2: `loop = false` plays once and holds the rest pose).
    private func cycleTime(_ cycle: Double) -> Double? {
        guard let elapsed = motion.elapsed, elapsed >= 0 else { return nil }
        if animation.loop { return elapsed.truncatingRemainder(dividingBy: cycle) }
        return elapsed < cycle ? elapsed : nil
    }

    /// §2 typewriter: one grapheme every 40 ms from empty; when all are shown, a 1000 ms hold.
    private var revealedGraphemes: Int {
        guard animation.kind == .typewriter else { return Int.max }
        let typing = CanvasTextMotion.typewriterPerGrapheme * Double(motion.graphemes)
        guard let time = cycleTime(typing + CanvasTextMotion.typewriterHold), time < typing else { return Int.max }
        return Int(time / CanvasTextMotion.typewriterPerGrapheme)
    }

    /// §2 pop / jump: how far word `word` is through its 300 ms, eased in and out, as 0 → 1 → 0;
    /// nil outside it.
    private func wordPulse(word: Int, stagger: Double) -> CGFloat? {
        let cycle = Double(motion.words) * stagger + CanvasTextMotion.wordRest
        guard let time = cycleTime(cycle) else { return nil }
        let local = (time - Double(word) * stagger) / CanvasTextMotion.wordDuration
        guard local > 0, local < 1 else { return nil }
        let rising = local < 0.5 ? local * 2 : 2 - local * 2
        return CGFloat(rising * rising * (3 - 2 * rising))
    }

    private func applyWordMotion(word: Int, rect: CGRect, to ctx: inout GraphicsContext) {
        switch animation.kind {
        case .pop:
            // §2 pop: word i starts at i × 100 ms, scale 1.0 → 1.15 → 1.0 about its own centre.
            guard let pulse = wordPulse(word: word, stagger: CanvasTextMotion.popStagger) else { return }
            let scale = 1 + (CanvasTextMotion.popPeak - 1) * pulse
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
        case .jump:
            // §2 jump: word i starts at i × 150 ms, rises 10 wu and turns −10° about its own centre.
            guard let pulse = wordPulse(word: word, stagger: CanvasTextMotion.jumpStagger) else { return }
            ctx.translateBy(x: rect.midX, y: rect.midY - CanvasTextMotion.jumpRise * pulse)
            ctx.rotate(by: .degrees(CanvasTextMotion.jumpTilt * Double(pulse)))
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
        case .none, .typewriter:
            break
        }
    }

    /// Each word's bounds, so pop and jump move a word about its own centre.
    private func wordBounds(_ layout: Text.Layout) -> [Int: CGRect] {
        guard animation.kind == .pop || animation.kind == .jump else { return [:] }
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
