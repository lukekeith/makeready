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

    /// §4 `manipulation` (owner ruling 2026-11-08): who recognises drag / pinch / rotate in
    /// `editor`. `own` attaches them here; `host` leaves them to the host's canvas-wide recognizers.
    enum Manipulation {
        case own, host
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

    /// §4 `verseNumbers` (SPEC D26) — how `bibleVerse` numbers are shown; ignored for the other
    /// list styles.
    enum VerseNumbers {
        case gutter, hidden, inline
    }

    /// §4 `reference` — a structured Bible reference, drawn as one trailing line by
    /// `BibleReferenceFormatter` (§2 Reference, OQ-C-092-004).
    struct Reference: Equatable {
        struct Point: Equatable {
            var book: String
            var chapter: Int
            /// nil = a whole chapter.
            var verse: Int?
            /// §4: the quotation begins mid-verse on `start` ("b") or ends mid-verse on `end`
            /// ("a"). Ignored on a whole-chapter point.
            var isPartial: Bool = false
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
    /// §4 (SPEC D26) — line height as a ratio of `size` (1.0–2.0), in every mode, to body lines,
    /// markers and the reference line; nil = the face's natural leading.
    let lineHeight: CGFloat?
    /// §4 — the glyph fill (the label fill under solidLight).
    let color: Color
    /// §4 — line alignment within the width.
    let alignment: Alignment
    /// §4 — the background box behind each line.
    let label: Label
    /// §4 — whole-block list formatting.
    let listStyle: ListStyle
    /// §4 — the number of the first item for `numbered` and `bibleVerse` (16 for John 3:16-18).
    let startNumber: Int
    /// §4 (SPEC D26) — how `bibleVerse` numbers are shown.
    let verseNumbers: VerseNumbers
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
    /// §4 — placement and layout width. Ignored while `pageLaidOut`.
    let transform: Transform
    /// §4 (SPEC D27) — the page, not the user, places and sizes this object: no drag / pinch /
    /// rotate, `onTransform` never fires, `transform` ignored. Editor only.
    let pageLaidOut: Bool
    /// §4 — who recognises drag / pinch / rotate in `editor`; ignored in `viewer`.
    let manipulation: Manipulation
    /// §4 — the first finger lands on the rendered shape, before any movement (editor only).
    let onTouchDown: () -> Void
    /// §4 — an absolute transform in wu measured from where the gesture started; fired here under
    /// `manipulation = .own`, by the host under `.host`. Never fires in `viewer`.
    let onTransform: (Transform) -> Void
    /// §4 — first responder with the caret; the keyboard is the screen's. Ignored in `viewer`,
    /// while `isLocked` and while `isHighlighting`.
    let editing: Bool
    /// §4 (SPEC D11) — no text input, caret, keyboard or deletion; still movable, scalable,
    /// rotatable, restylable and highlightable. Ignored in `viewer`.
    let isLocked: Bool
    /// §4 (SPEC D21) — highlighting mode: touch-and-hold-drag selects a word-snapped range.
    /// Editor only.
    let isHighlighting: Bool
    /// §4 — ranges drawn as highlight spans.
    let highlights: [TextRange]
    /// §4 — a finished selection, `(start, end)` in UTF-16 offsets into `text`, end exclusive.
    /// Fires in `isHighlighting` only.
    let onHighlightRange: (Int, Int) -> Void
    /// §4 — a tap with no movement on a committed object (C-091 turns it into Editing).
    let onTap: () -> Void
    /// §4 — a tap on a `link` mark in `viewer` (the href).
    let onOpenLink: (String) -> Void
    /// §4 (SPEC D43) — the laid-out lines' glyph bounds in wu: the block's own unscaled, unrotated
    /// space, origin at the layout box's top-left, label box included when `label` is on. Fired
    /// on every layout change; it changes no drawing.
    let onTextBounds: (CGRect) -> Void

    /// R-05: one parameter per §4 prop, in the contract's order. Written out because the private focus state would otherwise
    /// make the memberwise initializer private.
    init(
        text: String,
        onChange: @escaping (String) -> Void = { _ in },
        mode: Mode = .editor,
        font: Font = .sans,
        weight: Weight = .bold,
        size: CGFloat,
        lineHeight: CGFloat? = nil,
        color: Color = Token.textPrimary,
        alignment: Alignment = .center,
        label: Label = .none,
        listStyle: ListStyle = .none,
        startNumber: Int = 1,
        verseNumbers: VerseNumbers = .inline,
        reference: Reference? = nil,
        marks: [Mark] = [],
        animation: Animation = .none,
        animationStart: Date? = nil,
        effect: Effect = .none,
        transform: Transform = .identity,
        pageLaidOut: Bool = false,
        manipulation: Manipulation = .own,
        onTouchDown: @escaping () -> Void = {},
        onTransform: @escaping (Transform) -> Void = { _ in },
        editing: Bool,
        isLocked: Bool = false,
        isHighlighting: Bool = false,
        highlights: [TextRange] = [],
        onHighlightRange: @escaping (Int, Int) -> Void = { _, _ in },
        onTap: @escaping () -> Void = {},
        onOpenLink: @escaping (String) -> Void = { _ in },
        onTextBounds: @escaping (CGRect) -> Void = { _ in }
    ) {
        self.text = text
        self.onChange = onChange
        self.mode = mode
        self.font = font
        self.weight = weight
        self.size = size
        self.lineHeight = lineHeight
        self.color = color
        self.alignment = alignment
        self.label = label
        self.listStyle = listStyle
        self.startNumber = startNumber
        self.verseNumbers = verseNumbers
        self.reference = reference
        self.marks = marks
        self.animation = animation
        self.animationStart = animationStart
        self.effect = effect
        self.transform = transform
        self.pageLaidOut = pageLaidOut
        self.manipulation = manipulation
        self.onTouchDown = onTouchDown
        self.onTransform = onTransform
        self.editing = editing
        self.isLocked = isLocked
        self.isHighlighting = isHighlighting
        self.highlights = highlights
        self.onHighlightRange = onHighlightRange
        self.onTap = onTap
        self.onOpenLink = onOpenLink
        self.onTextBounds = onTextBounds
    }

    /// R-02: focus is ephemeral feedback, mirrored from the `editing` prop.
    @FocusState private var focused: Bool
    /// R-02: the transform a gesture started from, held only while the finger is down.
    @State private var gestureBase: Transform?
    /// R-02: whether this finger-down has already been reported through `onTouchDown`.
    @State private var touchReported = false
    /// R-02 / §4 `isHighlighting`: the in-progress word-snapped range (UTF-16, end exclusive),
    /// held only while the finger is down; a cancelled touch resets it and reports nothing.
    @GestureState private var selection: Range<Int>?
    /// §4 `isHighlighting`: where each item's glyphs were drawn, for the selection's hit test.
    @State private var selectionGeometry = CanvasTextSelectionGeometry()
    /// §2 Animation: Reduce Motion ignores the clock and holds the rest pose.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The block's own space: the selection gesture and each item's measured origin share it.
    private static let selectionSpace = "CanvasTextObject.selection"
    /// §4 `onTextBounds`: the layout box's own space, origin at its top-left.
    private static let boundsSpace = "CanvasTextObject.bounds"

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
    /// FLAGGED LITERAL — C-092 §4 Verse numbers (SPEC D26): the gutter's gap to the text column,
    /// 8 wu (no token).
    private let gutterGap: CGFloat = 8
    /// FLAGGED LITERAL — C-092 §4 Verse numbers (SPEC D26): gutter numbers at 0.7 × `size`, at
    /// 0.6 opacity (no token).
    private let gutterNumberScale: CGFloat = 0.7
    private let gutterNumberOpacity: Double = 0.6

    /// §2 Modes: `editing` is ignored in `viewer`; §4 Locked and highlighting: and while
    /// `isLocked` or `isHighlighting` — the block never becomes first responder.
    private var isEditing: Bool { mode == .editor && editing && !isLocked && !isHighlighting }

    /// §4 `isLocked`: an empty locked block draws nothing (no placeholder).
    private var showsPlaceholder: Bool { mode == .editor && !isLocked }

    var body: some View {
        switch mode {
        case .editor:
            // §4 Gestures: the hit area is applied inside the scale and rotation, so it is the
            // rendered (rotated, scaled) block, not the untransformed layout rectangle.
            transformed(
                laidOut
                    .contentShape(Rectangle())
                    .onTapGesture { if !isEditing { onTap() } }
                    .simultaneousGesture(touchDown, including: isEditing ? .subviews : .all)
                    // §4 `isHighlighting`: no move / pinch / rotate while it is on — the touch is
                    // the selection's. §4 `pageLaidOut`: none at all — the page places it.
                    .simultaneousGesture(
                        manipulationGesture,
                        including: isEditing || isHighlighting || pageLaidOut || manipulation == .host
                            ? .subviews : .all
                    )
                    .simultaneousGesture(selectionGesture, including: isHighlighting ? .all : .subviews)
                    .coordinateSpace(.named(Self.selectionSpace))
            )
                .accessibilityElement(children: isEditing ? .contain : .ignore)
                .accessibilityLabel(isEditing ? "" : spokenLabel)
                .accessibilityAddTraits(isEditing ? [] : .isButton)
                .onAppear { focused = isEditing }
                .onChange(of: isEditing) { _, now in focused = now }
                .ui2Element("CanvasTextObject")
        case .viewer:
            // §2 Modes: no gesture of any kind, so a vertical drag falls through to the viewer's
            // scroll and pager. Only a `link` mark is interactive, through the Text's own link.
            viewerAccessibility(transformed(laidOut))
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
    private var laidOut: some View {
        block
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(width: placement.width.map { min(max($0, widthLimits.lowerBound), widthLimits.upperBound) })
            .frame(maxWidth: placement.width == nil ? .infinity : nil, alignment: frameAlignment)
            .coordinateSpace(.named(Self.boundsSpace))
            .overlay { if isEditing { inputField } }
    }

    /// The committed scale and rotation (identity while `editing`), applied outside whatever hit
    /// area and gestures the content carries so they follow the rendered shape.
    private func transformed(_ content: some View) -> some View {
        content
            .scaleEffect(isEditing ? 1 : placement.scale)
            .rotationEffect(isEditing ? .zero : placement.rotation)
    }

    /// §4 `pageLaidOut`: `transform` is ignored entirely — identity scale and rotation, no width,
    /// so the block lays out at the frame the host gives it.
    private var placement: Transform { pageLaidOut ? .identity : transform }

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
            // §4 `lineHeight`: the extra leading over the face's natural line, between wrapped lines
            // and between items alike, so every line of the block keeps the same pitch.
            VStack(alignment: stackAlignment, spacing: lineGap) {
                if text.isEmpty {
                    placeholderRow(motion)
                } else if runsOn {
                    paragraphRow(items: items, motion: motion)
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
            // §4 `onTextBounds`: the lines' stack before it is widened to the layout width — each
            // line sized to its own glyphs, placed where the alignment put it.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(Self.boundsSpace))
            } action: { rect in
                onTextBounds(textBounds(rect))
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .lineSpacing(lineGap)
            .accessibilityHidden(isEditing)
        }
    }

    /// §4 `onTextBounds`: the glyph stack's rect grown by the label box's padding when it is on.
    private func textBounds(_ glyphs: CGRect) -> CGRect {
        label == .none ? glyphs : glyphs.insetBy(dx: -labelInsetX, dy: -labelInsetY)
    }

    /// §4 `verseNumbers = .inline` / `.hidden` (SPEC D41): the verses run on as one paragraph.
    private var runsOn: Bool { listStyle == .bibleVerse && verseNumbers != .gutter }

    /// §4 `lineHeight`: `lineHeight × size` less the face's natural line; nil = natural leading.
    private var lineGap: CGFloat {
        guard let lineHeight else { return 0 }
        return max(lineHeight * size - font.naturalLineHeight(weight: weight, size: size), 0)
    }

    /// §2 Editing: the placeholder never shows a list marker or a label box. §2 Modes: the viewer
    /// has no placeholder, so empty `text` draws nothing.
    @ViewBuilder
    private func placeholderRow(_ motion: CanvasTextRenderer.Motion) -> some View {
        if showsPlaceholder {
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
        HStack(alignment: .firstTextBaseline, spacing: inGutter ? gutterGap : 0) {
            if inGutter {
                gutterNumber(index: index, motion: motion)
            }
            if let marker = marker(for: index) {
                marker
                    .foregroundStyle(glyphColor)
                    .textRenderer(renderer(box: boxColor, caret: .none, motion: motion))
                    .ui2Element("Marker \(index + 1)")
            }
            itemText(item)
                .foregroundStyle(glyphColor)
                // §4 `.gutter`: lines are left-aligned in the text column whatever `alignment` says.
                .multilineTextAlignment(inGutter ? .leading : textAlignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: inGutter ? .infinity : nil, alignment: .leading)
                .textRenderer(renderer(
                    box: boxColor,
                    caret: isEditing && index == items.count - 1 ? .end : .none,
                    motion: motion,
                    sparkles: index == 0,
                    selectionItem: isHighlighting ? index : nil
                ))
                // §4 `isHighlighting`: the item's origin in the block, so its drawn glyph runs
                // can be hit-tested. Markers and the reference line are never recorded.
                .onGeometryChange(for: CGPoint.self) { proxy in
                    proxy.frame(in: .named(Self.selectionSpace)).origin
                } action: { origin in
                    selectionGeometry.itemOrigins[index] = origin
                }
                .ui2Element(items.count == 1 ? "Text" : "Item \(index + 1)")
        }
    }

    /// §4 `verseNumbers = .gutter`: each verse on its own line, its number right-aligned in a
    /// column to the left; every text line shares one left edge.
    private var inGutter: Bool { listStyle == .bibleVerse && verseNumbers == .gutter }

    /// The gutter number: 0.7 × size in the glyph colour at 0.6 opacity, right-aligned in a column
    /// as wide as the widest number of the passage. Never highlighted or selectable.
    private func gutterNumber(index: Int, motion: CanvasTextRenderer.Motion) -> some View {
        SwiftUI.Text(verbatim: "\(startNumber + index)")
            .font(font.face(weight: weight, size: size * gutterNumberScale))
            // §2 Label solidLight paints the box in `color`, so the number takes the glyph colour.
            .foregroundStyle(glyphColor.opacity(gutterNumberOpacity))
            .textRenderer(renderer(box: nil, caret: .none, motion: motion))
            .frame(width: gutterWidth, alignment: .trailing)
            .ui2Element("Verse number \(index + 1)")
    }

    /// The widest verse number's width at the number size.
    private var gutterWidth: CGFloat {
        let face = font.uiFont(weight: weight, size: size * gutterNumberScale)
        let count = max(items.count, 1)
        return (0..<count).reduce(0) { widest, index in
            let width = ("\(startNumber + index)" as NSString).size(withAttributes: [.font: face]).width
            return max(widest, ceil(width))
        }
    }

    /// §4 `verseNumbers = .inline` / `.hidden`: every verse in one Text, each line break drawn as
    /// a single space; under `.inline` each verse's superscript number sits immediately before its
    /// first word. `text` and every offset are unchanged — the markers and joining spaces are
    /// drawn, never segments, so they are never highlighted, selected or counted.
    private func paragraphRow(items: [Item], motion: CanvasTextRenderer.Motion) -> some View {
        let paragraph = items.enumerated().reduce(SwiftUI.Text(verbatim: "")) { partial, pair in
            var piece = itemText(pair.element)
            if let marker = marker(for: pair.offset) {
                piece = SwiftUI.Text("\(marker)\(piece)")
            }
            guard pair.offset > 0 else { return SwiftUI.Text("\(partial)\(piece)") }
            return SwiftUI.Text("\(partial)\(SwiftUI.Text(verbatim: " ").font(typeface))\(piece)")
        }
        return paragraph
            .foregroundStyle(glyphColor)
            .multilineTextAlignment(textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .textRenderer(renderer(
                box: boxColor,
                caret: isEditing ? .end : .none,
                motion: motion,
                sparkles: true,
                selectionItem: isHighlighting ? 0 : nil
            ))
            .onGeometryChange(for: CGPoint.self) { proxy in
                proxy.frame(in: .named(Self.selectionSpace)).origin
            } action: { origin in
                selectionGeometry.itemOrigins[0] = origin
            }
            .ui2Element("Text")
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
                    highlighted: segment.highlighted,
                    selecting: segment.selecting,
                    offset: segment.offset,
                    length: segment.text.utf16.count
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
            // §4 `startNumber`: the number of the first item.
            return SwiftUI.Text(verbatim: "\(startNumber + index). ").font(typeface)
        case .bibleVerse:
            // §4 `verseNumbers`: only `.inline` draws the superscript marker.
            guard verseNumbers == .inline else { return nil }
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
    /// The width handles are C-091's. Attached only under `manipulation = .own` (§4 Gestures).
    private var manipulationGesture: some Gesture {
        SimultaneousGesture(
            // Measured in C-091's fixed page space (wu), never this view's own moving frame —
            // a local-space drag jitters as the object it measures from moves under the finger.
            // pan-ok: free 2-D move on the canvas
            DragGesture(coordinateSpace: .named(ActivityCanvas.page)).onChanged { drag in
                let base = gestureBase ?? transform
                gestureBase = base
                var next = currentTransform
                next.position = CGPoint(
                    x: base.position.x + (drag.location.x - drag.startLocation.x),
                    y: base.position.y + (drag.location.y - drag.startLocation.y)
                )
                // The object tracks the finger 1:1 — no implicit animation on the drag path.
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { onTransform(next) }
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

    /// §4 `onTouchDown`: reported once per finger-down, before any movement, under either
    /// `manipulation`, so the host knows which object its canvas-level gesture drives.
    private var touchDown: some Gesture {
        // pan-ok: zero-distance touch-down probe, not a sideways drag
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !touchReported else { return }
                touchReported = true
                onTouchDown()
            }
            .onEnded { _ in touchReported = false }
    }

    // MARK: - Highlighting (§4 Locked and highlighting, SPEC D21)

    /// A touch-and-hold, then drag: the hold anchors the selection at the word under the finger,
    /// the drag extends it. Reported once, on lift, through `onHighlightRange`; a cancelled touch
    /// resets `selection` and reports nothing. Attached only while `isHighlighting`.
    private var selectionGesture: some Gesture {
        LongPressGesture()
            .sequenced(before:
                // pan-ok: a free 2-D selection drag over the text, only after the hold
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.selectionSpace))
            )
            .updating($selection) { value, state, _ in
                state = selectedRange(value)
            }
            .onEnded { value in
                guard let range = selectedRange(value), !range.isEmpty else { return }
                onHighlightRange(range.lowerBound, range.upperBound)
            }
    }

    private func selectedRange(_ value: SequenceGesture<LongPressGesture, DragGesture>.Value) -> Range<Int>? {
        guard case .second(true, let drag?) = value,
              let anchor = offset(at: drag.startLocation),
              let current = offset(at: drag.location) else { return nil }
        return wordSnapped(anchor, current)
    }

    /// The UTF-16 offset of the character drawn nearest `point` (block space): the nearest run
    /// line first, then across it, then proportionally within the run.
    private func offset(at point: CGPoint) -> Int? {
        var best: (dy: CGFloat, dx: CGFloat, offset: Int)?
        for (item, runs) in selectionGeometry.runs {
            let origin = selectionGeometry.itemOrigins[item] ?? .zero
            for run in runs where run.length > 0 {
                let rect = run.rect.offsetBy(dx: origin.x, dy: origin.y)
                let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
                let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
                if let best, (dy, dx) >= (best.dy, best.dx) { continue }
                let fraction = rect.width > 0 ? min(max((point.x - rect.minX) / rect.width, 0), 1) : 0
                let within = min(Int(fraction * CGFloat(run.length)), run.length - 1)
                best = (dy, dx, run.start + within)
            }
        }
        return best.map { min($0.offset, max(text.utf16.count - 1, 0)) }
    }

    /// §4: the range snaps outward to whole words — the start to the beginning of the word it
    /// falls in, the end to the end of the word it falls in. A word is the platform's Unicode word
    /// segment, so a space or punctuation is never a boundary by itself: an offset between words
    /// moves inward to the nearest word. Nil when no word lies between the two.
    private func wordSnapped(_ first: Int, _ second: Int) -> Range<Int>? {
        let lower = min(first, second)
        let upper = max(first, second)
        let words = wordRanges
        guard let start = words.first(where: { $0.upperBound > lower }),
              let end = words.last(where: { $0.lowerBound <= upper }),
              start.lowerBound < end.upperBound else { return nil }
        return start.lowerBound..<end.upperBound
    }

    /// Unicode word segments of `text` (ICU word boundaries), as UTF-16 ranges (D7).
    private var wordRanges: [Range<Int>] {
        let string = text as NSString
        var ranges: [Range<Int>] = []
        string.enumerateSubstrings(
            in: NSRange(location: 0, length: string.length),
            options: [.byWords, .substringNotRequired]
        ) { _, range, _, _ in
            ranges.append(range.location..<(range.location + range.length))
        }
        return ranges
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
        sparkles: Bool = false,
        selectionItem: Int? = nil
    ) -> CanvasTextRenderer {
        CanvasTextRenderer(
            motion: motion,
            box: box,
            highlightColor: Token.highlight,
            // §4 `isHighlighting`: the in-progress range on accent20 (owner-named).
            selectionColor: Token.accent20,
            selectionGeometry: selectionItem.map { _ in selectionGeometry },
            selectionItem: selectionItem,
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
        /// §4 `isHighlighting`: inside the in-progress selection.
        let selecting: Bool
        /// The segment's first UTF-16 offset in `text`.
        let offset: Int
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
        var selecting = false
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
            var currentOffset = 0
            var currentStyle = CharacterStyle()
            var previousWasSpace = true
            var count = 0
            func flush() {
                guard !current.isEmpty else { return }
                segments.append(Segment(
                    text: current, word: currentWord, grapheme: currentGrapheme,
                    highlighted: currentStyle.highlighted, selecting: currentStyle.selecting,
                    offset: currentOffset, bold: currentStyle.bold,
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
                    currentOffset = utf16Offset
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
        if let selection {
            apply(selection.lowerBound, selection.upperBound) { $0.selecting = true }
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
        guard !text.isEmpty else { return showsPlaceholder ? Self.placeholder : "" }
        var parts: [String] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            switch listStyle {
            case .none: parts.append(String(line))
            case .bullet: parts.append("bullet, \(line)")
            case .numbered: parts.append("\(startNumber + index), \(line)")
            case .bibleVerse where verseNumbers == .hidden: parts.append(String(line))
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

    /// The UIKit face behind `face(weight:size:)`, for measuring (§4 gutter width, `lineHeight`).
    func uiFont(weight: CanvasTextObject.Weight, size: CGFloat) -> UIFont {
        _ = CanvasTextFonts.registered
        let name: String
        switch self {
        case .display: name = "Poppins-\(styleName(weight: weight, italic: false))"
        case .sans: name = "Inter-\(styleName(weight: weight, italic: false))"
        case .mono: name = "CourierPrime-\(styleName(weight: weight == .medium ? .regular : weight, italic: false))"
        case .serif: name = "SourceSerif4Variable-Roman"
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }

    /// §4 `lineHeight` nil: the face's natural line height at `size`.
    func naturalLineHeight(weight: CanvasTextObject.Weight, size: CGFloat) -> CGFloat {
        uiFont(weight: weight, size: size).lineHeight
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
/// module cannot import the app, so it lives here until promotion. §4 partial verses: a partial
/// start verse takes "b", a partial end verse "a" ("John 3:16b-18a", "John 3:16b"); whole verses
/// are unchanged.
enum BibleReferenceFormatter {
    static func format(_ reference: CanvasTextObject.Reference) -> String {
        let start = reference.start
        // An end equal to the start (partial flag included) collapses to the single verse.
        guard let end = reference.end, end != start else { return point(start, suffix: "b", withBook: true) }
        if end.book != start.book {
            // Across books: the end repeats its book.
            return "\(point(start, suffix: "b", withBook: true)) – \(point(end, suffix: "a", withBook: true))"
        }
        if end.chapter == start.chapter {
            if let first = verse(start, suffix: "b"), let last = verse(end, suffix: "a") {
                return "\(start.book) \(start.chapter):\(first)-\(last)"
            }
            return point(start, suffix: "b", withBook: true)
        }
        if start.verse == nil && end.verse == nil {
            // Whole chapters within one book.
            return "\(start.book) \(start.chapter)-\(end.chapter)"
        }
        // Across chapters of one book: the end drops the repeated book name.
        return "\(point(start, suffix: "b", withBook: true)) – \(point(end, suffix: "a", withBook: false))"
    }

    /// The verse number with its partial marker; nil for a whole-chapter point.
    private static func verse(_ point: CanvasTextObject.Reference.Point, suffix: String) -> String? {
        point.verse.map { "\($0)\(point.isPartial ? suffix : "")" }
    }

    private static func point(
        _ point: CanvasTextObject.Reference.Point,
        suffix: String,
        withBook: Bool
    ) -> String {
        let place = verse(point, suffix: suffix).map { "\(point.chapter):\($0)" } ?? "\(point.chapter)"
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
    /// §4 `isHighlighting`: inside the in-progress selection (accent20, glyphs unchanged).
    let selecting: Bool
    /// The segment's first UTF-16 offset in `text`, and its UTF-16 length.
    let offset: Int
    let length: Int
}

/// §4 `isHighlighting`: where each item's glyph runs were drawn (in the item Text's own space)
/// and where each item sits in the block. Written by the renderer as it draws and read by the
/// selection gesture; a plain reference, not observed, so writing it triggers no view update.
final class CanvasTextSelectionGeometry {
    struct Run {
        let rect: CGRect
        let start: Int
        let length: Int
    }

    var runs: [Int: [Run]] = [:]
    var itemOrigins: [Int: CGPoint] = [:]
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
    /// §4 `isHighlighting`: the in-progress selection's fill.
    let selectionColor: Color
    /// §4 `isHighlighting`: set on an item's Text while highlighting, so its runs are recorded.
    let selectionGeometry: CanvasTextSelectionGeometry?
    let selectionItem: Int?
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
        recordRuns(layout)
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

    // 0 — §4 `isHighlighting`: each segment run's rect and UTF-16 range, for the hit test.
    private func recordRuns(_ layout: Text.Layout) {
        guard let selectionGeometry, let selectionItem else { return }
        var runs: [CanvasTextSelectionGeometry.Run] = []
        for line in layout {
            for run in line {
                guard let segment = run[CanvasTextSegment.self] else { continue }
                runs.append(.init(rect: run.typographicBounds.rect, start: segment.offset, length: segment.length))
            }
        }
        selectionGeometry.runs[selectionItem] = runs
    }

    // 2 — §2 Highlights: one span per wrapped line, span height = that line's box. §4
    // `isHighlighting`: the in-progress selection draws the same way, on its own colour, above.
    private func drawHighlights(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        drawSpans(layout, color: highlightColor, in: &ctx) { $0.highlighted }
        drawSpans(layout, color: selectionColor, in: &ctx) { $0.selecting }
    }

    private func drawSpans(
        _ layout: Text.Layout,
        color: Color,
        in ctx: inout GraphicsContext,
        where covered: (CanvasTextSegment) -> Bool
    ) {
        for line in layout {
            let lineRect = line.typographicBounds.rect
            var span: CGRect?
            for run in line {
                let runRect = run.typographicBounds.rect
                if let segment = run[CanvasTextSegment.self], covered(segment) {
                    span = span.map { $0.union(runRect) } ?? runRect
                } else if let open = span {
                    fillSpan(open, line: lineRect, color: color, in: &ctx)
                    span = nil
                }
            }
            if let open = span { fillSpan(open, line: lineRect, color: color, in: &ctx) }
        }
    }

    private func fillSpan(_ span: CGRect, line: CGRect, color: Color, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: span.minX, y: line.minY, width: span.width, height: line.height)
        ctx.fill(
            RoundedRectangle(cornerRadius: Token.Radius.cardSm).path(in: rect),
            with: .color(color)
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
