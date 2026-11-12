//
//  BibleVerseReader.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-140-bible-verse-reader in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI
import UIKit

/// C-140 BibleVerseReader — the Bible passage picker's reader body: a chapter heading, one row per
/// verse (the number in a left gutter, the text beside it), word-level touch-and-hold selection with
/// a handle at each end, verse-number taps, an `accent50` selection (D36) over a fainter used-range
/// underlay, a horizontal chapter swipe, and its own vertical scroll ending in the copyright line.
///
/// Controlled (R-01): `selection` is a value and `onSelectionChange` its change callback; the reader
/// never holds the selection. Its `@State` is ephemeral only (R-02): the swipe offset, a handle drag,
/// the scroll position and the last reported top verse.
///
/// §2 / R-16: fills the width it is given and paints no background or outer padding. Unlike most
/// rows it owns a vertical ScrollView (ruled exception, OQ-bible-reader-003), so its height is the
/// height it is given.
struct BibleVerseReader: View {

    /// C-140 §4 nested type (R-36): one verse of the chapter.
    struct Verse: Hashable, Codable {
        let number: Int
        /// The server's canonical verse text (SPEC D9), never re-normalized here.
        let text: String
    }

    /// C-140 §4 nested type (R-36): one contiguous range in this chapter. Offsets are UTF-16 into
    /// the `text` of `startVerse` / `endVerse`, end exclusive, always word-snapped; a whole verse
    /// is `startOffset` 0 … `endOffset` = `text.utf16.count`.
    struct Selection: Hashable, Codable {
        let startVerse: Int
        let startOffset: Int
        let endVerse: Int
        let endOffset: Int
    }

    /// C-140 §4 `chapterHeading` — e.g. "John 3".
    let chapterHeading: String
    /// C-140 §4 `verses` — the chapter's verses in order.
    let verses: [Verse]
    /// C-140 §4 `selection` — the current selection; nil = none.
    let selection: Selection?
    /// C-140 §4 `usedRanges` — ranges this lesson already uses in this chapter (SPEC D16).
    let usedRanges: [Selection]
    /// C-140 §4 `copyright` — the line under the last verse (SPEC D20); empty = omitted.
    let copyright: String
    /// C-140 §4 `scrollToVerse` — when it changes to a verse number, that row scrolls near the top.
    let scrollToVerse: Int?
    /// C-140 §4 `hasPreviousChapter` — false = swiping right rubber-bands (Genesis 1).
    let hasPreviousChapter: Bool
    /// C-140 §4 `hasNextChapter` — false = swiping left rubber-bands (Revelation 22).
    let hasNextChapter: Bool
    /// C-140 §4 `onSelectionChange` — every selection change, nil when cleared.
    var onSelectionChange: (Selection?) -> Void = { _ in }
    /// C-140 §4 `onTopVerseChange` — the topmost visible verse number, on change.
    var onTopVerseChange: (Int) -> Void = { _ in }
    /// C-140 §4 `onPreviousChapter` — a committed swipe to the previous chapter.
    var onPreviousChapter: () -> Void = {}
    /// C-140 §4 `onNextChapter` — a committed swipe to the next chapter.
    var onNextChapter: () -> Void = {}

    // MARK: - Literals

    /// GAP — C-140 §2 / OQ-C-140-003: the 32pt verse-number gutter, ruled "minted as token
    /// space-verse-gutter"; no token row exists yet.
    static let gutterWidth: CGFloat = 32
    /// GAP — C-140 §2 / OQ-C-140-004: the used underlay, ruled "mint color-accent-10 (color-accent
    /// at 10% opacity)"; no token row exists yet.
    static let usedUnderlay = Token.accent.opacity(0.1)
    /// FLAGGED LITERAL — C-140 §2 / OQ-C-140-005: the handle bar is 2pt wide.
    static let handleBarWidth: CGFloat = 2
    /// FLAGGED LITERAL — C-140 §2 / OQ-C-140-005: the handle dot is 8pt.
    static let handleDot: CGFloat = 8
    /// FLAGGED LITERAL — C-140 §2 / §3: 44pt hit areas (handles, verse numbers) and the 44pt
    /// auto-scroll band at the top and bottom edges.
    static let hitTarget: CGFloat = 44
    /// FLAGGED LITERAL — C-140 §3 / OQ-C-140-006: a swipe commits past 25% of the width.
    static let swipeCommitFraction: CGFloat = 0.25
    /// GAP — C-140 §3 / OQ-C-140-006: "or a fling" names no speed; one reader width per second.
    static let flingWidthsPerSecond: CGFloat = 1
    /// GAP — C-140 §3 / OQ-C-140-006: "rubber-bands" names no resistance; the content follows the
    /// finger at this fraction when there is no neighbouring chapter.
    static let rubberBand: CGFloat = 0.3

    private static let space = "BibleVerseReader"
    private static let verseStyle = Token.TypeStyle.passageVerse

    // MARK: - Ephemeral state (R-02)

    /// Where each verse's glyph runs were drawn; written by the renderer, read by the gestures.
    @State private var geometry = BibleVerseReaderGeometry()
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    @State private var metrics = ScrollMetrics()
    @State private var swipeOffset: CGFloat = 0
    /// The fixed end while a handle is dragged; nil when no handle is held.
    @State private var handleAnchor: Position?
    @State private var lastTopVerse: Int?
    /// A `scrollToVerse` request not yet overtaken by the user's own scroll.
    @State private var pendingScroll = false
    /// The word a held press anchored; non-nil while the press is held (scrolling suspended).
    @State private var selectAnchor: Position?
    /// D56: the bottom safe-area inset (home indicator) the scroll end clears, read from geometry.
    @State private var bottomSafeArea: CGFloat = 0

    private var selecting: Bool { selectAnchor != nil }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                content
                    .coordinateSpace(.named(Self.space))
                    // The first layout pass measures the verses before they wrap, so a scroll
                    // requested then lands short; it is re-applied as the height settles.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
                        if pendingScroll { scroll(proxy, to: scrollToVerse) }
                    }
            }
            // §4 `scrollToVerse`: on first layout and on every change, that row near the top.
            .onAppear {
                pendingScroll = scrollToVerse != nil
                scroll(proxy, to: scrollToVerse)
            }
            .onChange(of: scrollToVerse) { _, verse in
                pendingScroll = verse != nil
                scroll(proxy, to: verse)
            }
            // The reader's own scroll wins once the user touches it.
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { pendingScroll = false }
            }
        }
        .scrollPosition($scrollPosition)
        // D56: the reader may sit in a full-screen page whose shell adds no bottom padding.
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomSafeArea = $0 }
        // §3: while a selection is held or a handle dragged, vertical scrolling is suspended.
        .scrollDisabled(selecting || handleAnchor != nil)
        .onScrollGeometryChange(for: ScrollMetrics.self) { scroll in
            ScrollMetrics(
                offset: scroll.contentOffset.y + scroll.contentInsets.top,
                height: scroll.containerSize.height,
                width: scroll.containerSize.width
            )
        } action: { _, now in
            metrics = now
            reportTopVerse(at: now.offset)
        }
        .offset(x: swipeOffset)
        .horizontalPan(onChanged: swipeChanged, onEnded: swipeEnded)
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if hasNextChapter {
                SwiftUI.Button("Next chapter") { commitSwipe(forward: true) }
            }
            if hasPreviousChapter {
                SwiftUI.Button("Previous chapter") { commitSwipe(forward: false) }
            }
        }
        .ui2Element("BibleVerseReader")
    }

    // MARK: - Layout (§2)

    private var content: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            VStack(alignment: .leading, spacing: Token.Space.rowGap) {
                heading
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    ForEach(verses, id: \.number) { verse in
                        row(verse)
                    }
                }
                // D54: a bridged UIKit long-press that recognizes alongside the ScrollView's pan, so a
                // plain drag scrolls; a SwiftUI drag on the rows swallowed every touch. A recognized
                // hold sets `selectAnchor`, which suspends scrolling below.
                .gesture(SelectionPress(space: Self.space, onPress: selectionPress))
                .simultaneousGesture(textTap)
                .ui2Element("Verse rows")
            }
            if !copyright.isEmpty {
                footnote
            }
        }
        // §2 item 0 / D56: `space-row-gap` above the heading, inside the content so it scrolls away.
        .padding(.top, Token.Space.rowGap)
        // §2 item 5 / D56: `space-section-gap` plus the bottom safe-area inset below the last line.
        .padding(.bottom, Token.Space.sectionGap + bottomSafeArea)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §2 item 1 / OQ-C-140-002: `type-value-hero`, `color-text-primary`, centred, one line.
    private var heading: some View {
        Text(chapterHeading)
            .designTextStyle(Token.TypeStyle.valueHero)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
            .ui2Element("Chapter heading")
    }

    /// §2 item 3: the gutter number and the verse text, first baselines aligned.
    private func row(_ verse: Verse) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.elementGap) {
            gutterNumber(verse)
            VerseText(
                verse: verse,
                selected: selection.flatMap { range(of: $0, in: verse) },
                used: usedRanges.compactMap { range(of: $0, in: verse) },
                drawsStartHandle: selection?.startVerse == verse.number,
                drawsEndHandle: selection?.endVerse == verse.number,
                geometry: geometry,
                space: Self.space,
                onHandleDrag: dragHandle,
                onHandleEnd: { handleAnchor = nil },
                onHandleAdjust: adjustHandle
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // §3 / D56: the scroll target is a marker the top padding's height above the row, so
        // `scrollToVerse` lands the row just below the top padding, never under it.
        .background(alignment: .top) {
            Color.clear
                .frame(height: Token.Space.rowGap)
                .alignmentGuide(.top) { $0[.bottom] }
                .id(verse.number)
        }
        .ui2Element("Verse \(verse.number)")
    }

    /// §2 Gutter number: `type-passage-verse`, `color-text-secondary`, right-aligned in the gutter;
    /// a button whose hit area is at least 44pt tall without changing the row's height.
    private func gutterNumber(_ verse: Verse) -> some View {
        let slop = max((Self.hitTarget - Self.verseStyle.size) / 2, 0)
        return SwiftUI.Button {
            tapNumber(verse)
        } label: {
            Text(verbatim: "\(verse.number)")
                .designTextStyle(Self.verseStyle)
                .foregroundStyle(Token.textSecondary)
                .frame(width: Self.gutterWidth, alignment: .trailing)
                .padding(.vertical, slop)
                .contentShape(Rectangle())
                .padding(.vertical, -slop)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Verse \(verse.number)")
        .accessibilityHint("Selects the verse")
        .ui2Element("Gutter number")
    }

    /// §2 item 4: `type-footnote`, `color-text-secondary`, aligned with the verse-text column.
    private var footnote: some View {
        HStack(alignment: .top, spacing: Token.Space.elementGap) {
            Color.clear.frame(width: Self.gutterWidth, height: 0)
            Text(copyright)
                .designTextStyle(Token.TypeStyle.footnote)
                .foregroundStyle(Token.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .ui2Element("Copyright footnote")
        }
    }

    // MARK: - Selection by touch-and-hold (§3 Behaviour)

    /// A touch-and-hold on a word, then a drag (D54): *began* anchors the selection at the word under
    /// the finger and suspends scrolling, *changed* extends it across rows, snapped outward to whole
    /// words, auto-scrolling near the edges, *ended* stops. Every change is reported.
    private func selectionPress(_ phase: SelectionPress.Phase, _ location: CGPoint) {
        switch phase {
        case .began:
            guard let anchor = position(at: location, strict: true) else { return }
            selectAnchor = anchor
            emit(snappedSelection(anchor, anchor))
        case .changed:
            guard let anchor = selectAnchor, let current = position(at: location, strict: false) else { return }
            emit(snappedSelection(anchor, current))
            autoScroll(near: location)
        case .ended:
            selectAnchor = nil
        }
    }

    /// §3: a tap on text outside the selection clears it; with no selection it does nothing.
    private var textTap: some Gesture {
        SpatialTapGesture(coordinateSpace: .named(Self.space))
            .onEnded { value in
                guard let selection, let point = position(at: value.location, strict: true) else { return }
                if !contains(selection, point) { onSelectionChange(nil) }
            }
    }

    /// §3 Verse-number tap: none → the whole verse; outside → extends to include it; inside → clears.
    private func tapNumber(_ verse: Verse) {
        let whole = Selection(
            startVerse: verse.number, startOffset: 0,
            endVerse: verse.number, endOffset: verse.text.utf16.count
        )
        guard let selection else {
            onSelectionChange(whole)
            return
        }
        if verse.number >= selection.startVerse && verse.number <= selection.endVerse {
            onSelectionChange(nil)
            return
        }
        let start = min(Position(selection.startVerse, selection.startOffset), Position(whole.startVerse, 0))
        let end = max(Position(selection.endVerse, selection.endOffset), Position(whole.endVerse, whole.endOffset))
        onSelectionChange(Selection(startVerse: start.verse, startOffset: start.offset,
                                    endVerse: end.verse, endOffset: end.offset))
    }

    // MARK: - Handles (§3 Behaviour, OQ-C-140-005)

    /// Dragging either handle moves that end, word-snapped; past the other end, the ends swap.
    private func dragHandle(_ end: HandleEnd, _ location: CGPoint) {
        guard let selection else { return }
        if handleAnchor == nil {
            // The fixed end is the OTHER end, held inside its word so snapping keeps that word.
            handleAnchor = end == .start
                ? Position(selection.endVerse, max(selection.endOffset - 1, 0))
                : Position(selection.startVerse, selection.startOffset)
        }
        guard let anchor = handleAnchor, let current = position(at: location, strict: false) else { return }
        emit(snappedSelection(anchor, current))
        autoScroll(near: location)
    }

    /// R-17: each handle is adjustable — increment/decrement moves that end by one word.
    private func adjustHandle(_ end: HandleEnd, _ direction: AccessibilityAdjustmentDirection) {
        guard let selection else { return }
        let words = allWords
        guard let first = words.firstIndex(where: { $0.verse == selection.startVerse && $0.range.lowerBound == selection.startOffset }),
              let last = words.lastIndex(where: { $0.verse == selection.endVerse && $0.range.upperBound == selection.endOffset })
        else { return }
        let step = direction == .increment ? 1 : (direction == .decrement ? -1 : 0)
        var lower = first
        var upper = last
        if end == .start { lower = min(max(first + step, 0), last) } else { upper = max(min(last + step, words.count - 1), first) }
        emit(Selection(startVerse: words[lower].verse, startOffset: words[lower].range.lowerBound,
                       endVerse: words[upper].verse, endOffset: words[upper].range.upperBound))
    }

    // MARK: - Chapter swipe (§3 Behaviour, OQ-C-140-006)

    private func swipeChanged(_ value: HorizontalPanValue) {
        guard !selecting, handleAnchor == nil else { return }
        let allowed = value.translation < 0 ? hasNextChapter : hasPreviousChapter
        swipeOffset = allowed ? value.translation : value.translation * Self.rubberBand
    }

    private func swipeEnded(_ value: HorizontalPanValue) {
        defer { withAnimation(.spring) { swipeOffset = 0 } }
        guard !selecting, handleAnchor == nil, metrics.width > 0 else { return }
        let forward = value.translation < 0
        guard forward ? hasNextChapter : hasPreviousChapter else { return }
        let far = abs(value.translation) > metrics.width * Self.swipeCommitFraction
        let fling = abs(value.velocity) > metrics.width * Self.flingWidthsPerSecond
            && (value.velocity < 0) == forward
        if far || fling { commitSwipe(forward: forward) }
    }

    /// A committed swipe clears the selection, then reports the chapter step.
    private func commitSwipe(forward: Bool) {
        if selection != nil { onSelectionChange(nil) }
        if forward { onNextChapter() } else { onPreviousChapter() }
    }

    // MARK: - Scrolling

    private func scroll(_ proxy: ScrollViewProxy, to verse: Int?) {
        guard let verse else { return }
        proxy.scrollTo(verse, anchor: .top)
    }

    /// §3: a selection or handle drag within 44pt of the top or bottom edge scrolls by one line.
    private func autoScroll(near location: CGPoint) {
        let line = Self.verseStyle.lineHeight ?? Self.verseStyle.size
        if location.y - metrics.offset < Self.hitTarget {
            scrollPosition.scrollTo(y: max(metrics.offset - line, 0))
        } else if metrics.offset + metrics.height - location.y < Self.hitTarget {
            scrollPosition.scrollTo(y: metrics.offset + line)
        }
    }

    /// §4 `onTopVerseChange`: the first verse whose text reaches below the scroll offset plus the
    /// top padding (D56), so a verse scrolled to sits at the top and is the one reported.
    private func reportTopVerse(at offset: CGFloat) {
        let edge = offset + Token.Space.rowGap
        let top = verses.first { (geometry.textFrames[$0.number]?.maxY ?? 0) > edge }?.number
        guard let top, top != lastTopVerse else { return }
        lastTopVerse = top
        onTopVerseChange(top)
    }

    // MARK: - Ranges, words and hit-testing

    private func emit(_ next: Selection?) {
        guard let next, next != selection else { return }
        onSelectionChange(next)
    }

    /// The part of `selection` that falls in `verse`, as a UTF-16 range of its text.
    private func range(of selection: Selection, in verse: Verse) -> Range<Int>? {
        guard verse.number >= selection.startVerse, verse.number <= selection.endVerse else { return nil }
        let length = verse.text.utf16.count
        let lower = verse.number == selection.startVerse ? min(selection.startOffset, length) : 0
        let upper = verse.number == selection.endVerse ? min(selection.endOffset, length) : length
        return lower < upper ? lower..<upper : nil
    }

    private func contains(_ selection: Selection, _ point: Position) -> Bool {
        point >= Position(selection.startVerse, selection.startOffset)
            && point < Position(selection.endVerse, selection.endOffset)
    }

    /// OQ-C-140-008: the two positions, ordered, snapped outward — the start to the beginning of
    /// the word it falls in (or the next word), the end to the end of its word (or the previous).
    private func snappedSelection(_ first: Position, _ second: Position) -> Selection? {
        let lower = min(first, second)
        let upper = max(first, second)
        let words = allWords
        guard let start = words.first(where: { Position($0.verse, $0.range.upperBound) > lower }) else { return nil }
        let end = words.last(where: { Position($0.verse, $0.range.lowerBound) <= upper }) ?? start
        let ordered = Position(end.verse, end.range.upperBound) > Position(start.verse, start.range.lowerBound)
        let last = ordered ? end : start
        return Selection(startVerse: start.verse, startOffset: start.range.lowerBound,
                         endVerse: last.verse, endOffset: last.range.upperBound)
    }

    private var allWords: [VerseWord] {
        verses.flatMap { verse in
            BibleVerseWords.ranges(verse.text).map { VerseWord(verse: verse.number, range: $0) }
        }
    }

    /// The verse position drawn nearest `point` (content space). `strict` requires the point to
    /// lie on a verse's text; otherwise the nearest text wins (a drag past the edge).
    private func position(at point: CGPoint, strict: Bool) -> Position? {
        var bestVerse: (distance: CGFloat, number: Int, frame: CGRect)?
        for verse in verses {
            guard let frame = geometry.textFrames[verse.number] else { continue }
            if strict && !frame.contains(point) { continue }
            let distance = max(frame.minY - point.y, 0, point.y - frame.maxY)
            if let bestVerse, distance >= bestVerse.distance { continue }
            bestVerse = (distance, verse.number, frame)
        }
        guard let bestVerse, let runs = geometry.runs[bestVerse.number] else { return nil }
        let local = CGPoint(x: point.x - bestVerse.frame.minX, y: point.y - bestVerse.frame.minY)
        var best: (dy: CGFloat, dx: CGFloat, offset: Int)?
        for run in runs where run.length > 0 {
            let dy = max(run.rect.minY - local.y, 0, local.y - run.rect.maxY)
            let dx = max(run.rect.minX - local.x, 0, local.x - run.rect.maxX)
            if let best, (dy, dx) >= (best.dy, best.dx) { continue }
            let fraction = run.rect.width > 0 ? min(max((local.x - run.rect.minX) / run.rect.width, 0), 1) : 0
            best = (dy, dx, run.start + min(Int(fraction * CGFloat(run.length)), run.length - 1))
        }
        return best.map { Position(bestVerse.number, $0.offset) }
    }
}

// MARK: - Verse text

private enum HandleEnd { case start, end }

/// C-140 §3 (D54): the selection's touch-and-hold, a UIKit `UILongPressGestureRecognizer` (0.4s,
/// 10pt allowable movement, touches not cancelled) that recognizes simultaneously with the
/// ScrollView's pan, so a plain vertical drag still scrolls. Locations are in the named space.
private struct SelectionPress: UIGestureRecognizerRepresentable {
    enum Phase { case began, changed, ended }

    /// FLAGGED LITERAL — C-140 §3 / D54: `minimumPressDuration` 0.4s.
    static let pressDuration: TimeInterval = 0.4
    /// FLAGGED LITERAL — C-140 §3 / D54: `allowableMovement` 10pt.
    static let allowableMovement: CGFloat = 10

    let space: String
    let onPress: (Phase, CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = Self.pressDuration
        press.allowableMovement = Self.allowableMovement
        press.cancelsTouchesInView = false
        press.delegate = context.coordinator
        return press
    }

    func handleUIGestureRecognizerAction(_ press: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.location(in: .named(space))
        switch press.state {
        case .began: onPress(.began, location)
        case .changed: onPress(.changed, location)
        case .ended, .cancelled, .failed: onPress(.ended, location)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

/// One verse's text, drawn by `VerseTextRenderer`: the used underlay, the selection, the glyphs and
/// the handles. Owns the 44×44 handle hit areas, placed where the renderer drew the handles.
private struct VerseText: View {
    let verse: BibleVerseReader.Verse
    let selected: Range<Int>?
    let used: [Range<Int>]
    let drawsStartHandle: Bool
    let drawsEndHandle: Bool
    let geometry: BibleVerseReaderGeometry
    let space: String
    let onHandleDrag: (HandleEnd, CGPoint) -> Void
    let onHandleEnd: () -> Void
    let onHandleAdjust: (HandleEnd, AccessibilityAdjustmentDirection) -> Void

    /// Where the renderer last drew the handles (this Text's space). Ephemeral (R-02).
    @State private var handles = VerseHandleRects()

    var body: some View {
        segmentedText
            .designTextStyle(Token.TypeStyle.passageVerse)
            .foregroundStyle(Token.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textRenderer(VerseTextRenderer(
                verse: verse.number,
                drawsStartHandle: drawsStartHandle,
                drawsEndHandle: drawsEndHandle,
                geometry: geometry,
                handles: $handles
            ))
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(space))
            } action: { frame in
                geometry.textFrames[verse.number] = frame
            }
            .accessibilityLabel("\(verse.number), \(verse.text)")
            .accessibilityValue(selected == nil ? "" : "selected")
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if drawsStartHandle, let rect = handles.start {
                        handleHitArea(.start, rect: rect, label: "Selection start")
                    }
                    if drawsEndHandle, let rect = handles.end {
                        handleHitArea(.end, rect: rect, label: "Selection end")
                    }
                }
            }
            .ui2Element("Verse text")
    }

    /// The text as word and whitespace segments, each carrying its UTF-16 range and coverage.
    private var segmentedText: Text {
        BibleVerseWords.segments(verse.text).reduce(Text(verbatim: "")) { partial, segment in
            let piece = Text(verbatim: segment.text)
                .customAttribute(VerseSegment(
                    offset: segment.range.lowerBound,
                    length: segment.range.count,
                    selected: selected.map { $0.lowerBound <= segment.range.lowerBound && segment.range.upperBound <= $0.upperBound } ?? false,
                    used: used.contains { $0.lowerBound <= segment.range.lowerBound && segment.range.upperBound <= $0.upperBound },
                    isSpace: segment.isSpace
                ))
            return Text("\(partial)\(piece)")
        }
    }

    /// §2 SelectionHandle: a 44×44 hit area centred on the bar (OQ-C-140-005), adjustable (R-17).
    private func handleHitArea(_ end: HandleEnd, rect: CGRect, label: String) -> some View {
        Color.clear
            .frame(width: BibleVerseReader.hitTarget, height: BibleVerseReader.hitTarget)
            .contentShape(Rectangle())
            .offset(x: rect.midX - BibleVerseReader.hitTarget / 2, y: rect.midY - BibleVerseReader.hitTarget / 2)
            .gesture(
                // pan-ok: a free 2-D handle drag across rows, not a sideways pan
                DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                    .onChanged { onHandleDrag(end, $0.location) }
                    .onEnded { _ in onHandleEnd() }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAdjustableAction { onHandleAdjust(end, $0) }
            .ui2Element(end == .start ? "Selection start handle" : "Selection end handle")
    }
}

/// What each segment of a verse's Text carries into the renderer.
private struct VerseSegment: TextAttribute {
    let offset: Int
    let length: Int
    let selected: Bool
    let used: Bool
    /// A whitespace run: covered only between two covered words on the same line, so a span never
    /// runs past the last glyph of a wrapped line.
    let isSpace: Bool
}

/// Paints one verse back to front: used underlay, selection, glyphs, handles (§2 Overlays).
private struct VerseTextRenderer: TextRenderer {
    let verse: Int
    let drawsStartHandle: Bool
    let drawsEndHandle: Bool
    let geometry: BibleVerseReaderGeometry
    let handles: Binding<VerseHandleRects>

    /// Room for the handle dots above the first line and below the last; vertical only, so line
    /// alignment inside the width is untouched.
    var displayPadding: EdgeInsets {
        EdgeInsets(top: BibleVerseReader.handleDot, leading: 0, bottom: BibleVerseReader.handleDot, trailing: 0)
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        recordRuns(layout)
        drawSpans(layout, color: BibleVerseReader.usedUnderlay, in: &ctx) { $0.used }
        drawSpans(layout, color: Token.accent50, in: &ctx) { $0.selected }   // D36
        for line in layout {
            ctx.draw(line)
        }
        drawHandles(layout, in: &ctx)
    }

    private func recordRuns(_ layout: Text.Layout) {
        var runs: [BibleVerseReaderGeometry.Run] = []
        for line in layout {
            for run in line {
                guard let segment = run[VerseSegment.self] else { continue }
                runs.append(.init(rect: run.typographicBounds.rect, start: segment.offset, length: segment.length))
            }
        }
        geometry.runs[verse] = runs
    }

    /// One span per wrapped line, the height of that line, no corner radius (§2 Overlays).
    private func drawSpans(
        _ layout: Text.Layout,
        color: Color,
        in ctx: inout GraphicsContext,
        where covered: (VerseSegment) -> Bool
    ) {
        for span in spans(layout, where: covered) {
            ctx.fill(Path(span), with: .color(color))
        }
    }

    private func spans(_ layout: Text.Layout, where covered: (VerseSegment) -> Bool) -> [CGRect] {
        var rects: [CGRect] = []
        for line in layout {
            let lineRect = line.typographicBounds.rect
            var open: CGRect?
            var pendingSpace: CGRect?
            for run in line {
                let runRect = run.typographicBounds.rect
                if let segment = run[VerseSegment.self], covered(segment), segment.isSpace {
                    // Held until a covered word follows on this line.
                    if open != nil { pendingSpace = pendingSpace.map { $0.union(runRect) } ?? runRect }
                } else if let segment = run[VerseSegment.self], covered(segment) {
                    let joined = pendingSpace.map { runRect.union($0) } ?? runRect
                    open = open.map { $0.union(joined) } ?? runRect
                    pendingSpace = nil
                } else if let span = open {
                    pendingSpace = nil
                    rects.append(CGRect(x: span.minX, y: lineRect.minY, width: span.width, height: lineRect.height))
                    open = nil
                }
            }
            if let span = open {
                rects.append(CGRect(x: span.minX, y: lineRect.minY, width: span.width, height: lineRect.height))
            }
        }
        return rects
    }

    /// §2 SelectionHandle (OQ-C-140-005): a 2pt `color-accent` bar the height of its line, an 8pt
    /// dot above the start bar and below the end bar. Reports the bars so the hit areas follow.
    private func drawHandles(_ layout: Text.Layout, in ctx: inout GraphicsContext) {
        let selected = spans(layout) { $0.selected }
        var drawn = VerseHandleRects()
        let bar = BibleVerseReader.handleBarWidth
        let dot = BibleVerseReader.handleDot
        if drawsStartHandle, let first = selected.first {
            let barRect = CGRect(x: first.minX - bar / 2, y: first.minY, width: bar, height: first.height)
            ctx.fill(Path(barRect), with: .color(Token.accent))
            ctx.fill(Path(ellipseIn: CGRect(x: first.minX - dot / 2, y: first.minY - dot, width: dot, height: dot)),
                     with: .color(Token.accent))
            drawn.start = barRect
        }
        if drawsEndHandle, let last = selected.last {
            let barRect = CGRect(x: last.maxX - bar / 2, y: last.minY, width: bar, height: last.height)
            ctx.fill(Path(barRect), with: .color(Token.accent))
            ctx.fill(Path(ellipseIn: CGRect(x: last.maxX - dot / 2, y: last.maxY, width: dot, height: dot)),
                     with: .color(Token.accent))
            drawn.end = barRect
        }
        if drawn != handles.wrappedValue {
            let binding = handles
            Task { @MainActor in binding.wrappedValue = drawn }
        }
    }
}

// MARK: - Support types

/// Where each verse's glyph runs were drawn (its Text's own space) and where each verse's Text
/// sits in the content. Written while drawing and laying out; read by the gestures. A plain
/// reference, not observed, so writing it triggers no view update.
final class BibleVerseReaderGeometry {
    struct Run {
        let rect: CGRect
        let start: Int
        let length: Int
    }

    var runs: [Int: [Run]] = [:]
    var textFrames: [Int: CGRect] = [:]
}

private struct VerseHandleRects: Equatable {
    var start: CGRect?
    var end: CGRect?
}

private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var height: CGFloat = 0
    var width: CGFloat = 0
}

/// A point in the chapter: a verse and a UTF-16 offset into its text.
private struct Position: Comparable {
    let verse: Int
    let offset: Int

    init(_ verse: Int, _ offset: Int) {
        self.verse = verse
        self.offset = offset
    }

    static func < (lhs: Position, rhs: Position) -> Bool {
        (lhs.verse, lhs.offset) < (rhs.verse, rhs.offset)
    }
}

private struct VerseWord {
    let verse: Int
    let range: Range<Int>
}

/// OQ-C-140-008: a word is a maximal run of non-whitespace characters, so punctuation attached
/// to a word is selected with it. Offsets are UTF-16 into the canonical verse text (SPEC D8/D9).
private enum BibleVerseWords {
    struct Segment {
        let text: String
        let range: Range<Int>

        var isSpace: Bool { text.unicodeScalars.allSatisfy(\.properties.isWhitespace) }
    }

    static func ranges(_ text: String) -> [Range<Int>] {
        segments(text).filter { !$0.isSpace }.map(\.range)
    }

    /// The text cut into alternating word and whitespace runs, covering every character.
    static func segments(_ text: String) -> [Segment] {
        var result: [Segment] = []
        var current = ""
        var currentStart = 0
        var currentIsSpace: Bool?
        var offset = 0
        for scalar in text.unicodeScalars {
            let isSpace = scalar.properties.isWhitespace
            if let currentIsSpace, currentIsSpace != isSpace {
                result.append(Segment(text: current, range: currentStart..<offset))
                current = ""
                currentStart = offset
            }
            currentIsSpace = isSpace
            current.unicodeScalars.append(scalar)
            offset += scalar.utf16.count
        }
        if !current.isEmpty {
            result.append(Segment(text: current, range: currentStart..<offset))
        }
        return result
    }
}
