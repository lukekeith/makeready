//
//  MediaBrowser.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-129-media-browser in d2m (§2 geometry, §2b behaviour, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  No Figma picture exists (OQ-C-129-001, owner 2026-10-31: "build it from the attached
//  reference … treat the §2 proposals as the values"). The normative source is the markdown
//  reference media-browser.md, rules 1–25.
//

import SwiftUI
import UIKit

/// C-129 MediaBrowser: a zoomable, bottom-anchored photo grid. It has four discrete column
/// levels, a pinch crossfade between them, and sticky month/year pills with push-off.
///
/// It is the media library's browsing surface: one continuous chronological mosaic, oldest at
/// the top and newest at the bottom, resting at the newest end. It does no image work at all
/// (R-04, R-19). It draws what `image` returns and reports `onVisibleRangeChange`.
///
/// R-16: it fills the size it is given (the host's height, because it is a scroller) and paints
/// no background, so the host's `layoutBackground` shows in a short last row's empty cells
/// (rule 3).
struct MediaBrowser: View {
    /// C-129 §4 `level` (R-06, R-36: nested). The column count is fixed per level (§2).
    /// `three` is off the pinch chain (owner 2026-11-01: media-home's search results) and draws like `five`.
    enum Level: String, CaseIterable {
        case three, five, eight, fourteen, thirty

        var columns: Int {
            switch self {
            case .three: return 3
            case .five: return 5
            case .eight: return 8
            case .fourteen: return 14
            case .thirty: return 30
            }
        }

        /// §2 Tile: `space-chip-gap` at `five` (deviation 1), 0 elsewhere (one mosaic, rule 6).
        var gutter: CGFloat { self == .three || self == .five ? Token.Space.chipGap : 0 }
        /// §2 Badges: `five` only (rule 8), and `three`.
        var showsBadges: Bool { self == .three || self == .five }
        /// §2 Pill: `eight` / `fourteen` / `thirty` (rules 19–22).
        var showsPills: Bool { self != .three && self != .five }
        /// §2 Pill text: "yyyy" at `thirty`, "MMM yyyy" at the month levels.
        var sectionsByYear: Bool { self == .thirty }
        /// OQ-C-129-005 (owner): a tap opens the viewer at `five` and `eight` only.
        var tappable: Bool { self == .three || self == .five || self == .eight }

        /// One step toward more columns (pinch out, §2b).
        var denser: Level? {
            switch self {
            case .three: return nil
            case .five: return .eight
            case .eight: return .fourteen
            case .fourteen: return .thirty
            case .thirty: return nil
            }
        }

        /// One step toward fewer columns (pinch in, §2b).
        var sparser: Level? {
            switch self {
            case .three, .five: return nil
            case .eight: return .five
            case .fourteen: return .eight
            case .thirty: return .fourteen
            }
        }
    }

    /// C-129 §4 `items[]` — oldest → newest.
    struct Item: Identifiable, Equatable {
        let id: String
        let date: Date
        let accessibilityLabel: String
        /// OQ-C-129-002: draws the bottom-right duration badge at `five`.
        var duration: String? = nil
        /// OQ-C-129-002: draws the bottom-left `heart` badge at `five`.
        var favorite: Bool = false
    }

    // §4, in the contract's order (R-05). Callbacks are on-prefixed no-op defaults (R-03, R-33).
    let items: [Item]
    let image: (String) -> UIImage?
    let imageGeneration: Int
    let level: Level
    var onLevelChange: (Level) -> Void = { _ in }
    /// Whether pinch steps between levels (§2b). false: the grid stays at `level` (owner
    /// 2026-11-01, media-home holds `five` until the pinch is reworked).
    var pinchEnabled: Bool = true
    var hiddenItemID: String? = nil
    var frozen: Bool = false
    var scrollToNewestToken: Int = 0
    var timeZone: TimeZone = .current
    var refreshing: Bool = false
    var onVisibleRangeChange: (Range<Int>) -> Void = { _ in }
    /// The indices on screen, with no prefetch margin — what a date-range line describes.
    var onVisibleItemsChange: (Range<Int>) -> Void = { _ in }
    var onTap: (String, CGRect) -> Void = { _, _ in }
    var onScrollChange: (CGFloat, Bool) -> Void = { _, _ in }
    var onRefresh: () -> Void = {}

    /// Scroll, pinch and section bookkeeping. This is a plain reference that is never observed,
    /// so a scroll frame never re-renders the view (rule 17a). It is ephemeral feedback state (R-02).
    @State private var tracker = MediaBrowserTracker()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Only the pill levels cut sections: the cut compares every item, and this body runs on
            // every resize and image redraw.
            let sections = level.showsPills
                ? tracker.sections(items: items, byYear: level.sectionsByYear, timeZone: timeZone)
                : []
            ZStack(alignment: .topLeading) {
                MediaBrowserLevelGrid(
                    items: items,
                    image: image,
                    imageGeneration: imageGeneration,
                    level: level,
                    hiddenItemID: hiddenItemID,
                    frozen: frozen,
                    scrollToNewestToken: scrollToNewestToken,
                    refreshing: refreshing,
                    sections: sections,
                    size: size,
                    initialOffset: tracker.initialOffset(for: level, size: size, count: items.count, refreshing: refreshing),
                    fadePillsIn: tracker.geometry != nil,
                    tracker: tracker,
                    onVisibleRangeChange: onVisibleRangeChange,
                    onVisibleItemsChange: onVisibleItemsChange,
                    onTap: onTap,
                    onScrollChange: onScrollChange,
                    onRefresh: onRefresh
                )
                // §2b: "a crossfade between two mounted layouts: the outgoing grid scales toward
                // the new tile size while the incoming one fades in."
                .id(level)
                .transition(MediaBrowserCrossfade(tracker: tracker))
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .animation(MediaBrowserMotion.crossfade, value: level)
            .simultaneousGesture(pinch(size: size), including: frozen || !pinchEnabled ? .none : .all)
        }
        .ui2Element("MediaBrowser")
    }

    /// §2b Pinch: discrete levels, never free zoom. The level steps when the cumulative scale
    /// passes ×0.7 (out) or ×1.4 (in) from the current base, and then the base resets, so one
    /// pinch can cross several levels. Each step fires `onLevelChange`.
    private func pinch(size: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                if !tracker.pinching {
                    tracker.beginPinch(at: value.startLocation, level: level, size: size, count: items.count)
                }
                let ratio = value.magnification / tracker.pinchBase
                let current = tracker.pinchLevel
                if ratio < MediaBrowserMotion.pinchOutThreshold, let next = current.denser {
                    tracker.step(from: current, to: next, base: value.magnification, width: size.width)
                    onLevelChange(next)
                } else if ratio > MediaBrowserMotion.pinchInThreshold, let next = current.sparser {
                    tracker.step(from: current, to: next, base: value.magnification, width: size.width)
                    onLevelChange(next)
                }
            }
            .onEnded { _ in tracker.pinching = false }
    }
}

// MARK: - One level's grid

/// One level's scroller. It is re-created (`.id(level)`) on every level change, so the
/// outgoing and incoming grids are both mounted for the crossfade (§2b).
///
/// Rows are windowed by hand rather than by a lazy container: only the rows within one viewport
/// of the visible ones are mounted, over a content frame of exact height. The exact height is
/// what lets the first render rest at the newest end (rule 2) with no estimation.
private struct MediaBrowserLevelGrid: View {
    let items: [MediaBrowser.Item]
    let image: (String) -> UIImage?
    let imageGeneration: Int
    let level: MediaBrowser.Level
    let hiddenItemID: String?
    let frozen: Bool
    let scrollToNewestToken: Int
    let refreshing: Bool
    let sections: [MediaBrowserSection]
    let size: CGSize
    let tracker: MediaBrowserTracker
    let onVisibleRangeChange: (Range<Int>) -> Void
    let onVisibleItemsChange: (Range<Int>) -> Void
    let onTap: (String, CGRect) -> Void
    let onScrollChange: (CGFloat, Bool) -> Void
    let onRefresh: () -> Void

    @State private var position: ScrollPosition
    @State private var window: Range<Int>
    @State private var pillsShown: Bool

    private let metrics: MediaBrowserMetrics

    init(
        items: [MediaBrowser.Item],
        image: @escaping (String) -> UIImage?,
        imageGeneration: Int,
        level: MediaBrowser.Level,
        hiddenItemID: String?,
        frozen: Bool,
        scrollToNewestToken: Int,
        refreshing: Bool,
        sections: [MediaBrowserSection],
        size: CGSize,
        initialOffset: CGFloat?,
        fadePillsIn: Bool,
        tracker: MediaBrowserTracker,
        onVisibleRangeChange: @escaping (Range<Int>) -> Void,
        onVisibleItemsChange: @escaping (Range<Int>) -> Void,
        onTap: @escaping (String, CGRect) -> Void,
        onScrollChange: @escaping (CGFloat, Bool) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.items = items
        self.image = image
        self.imageGeneration = imageGeneration
        self.level = level
        self.hiddenItemID = hiddenItemID
        self.frozen = frozen
        self.scrollToNewestToken = scrollToNewestToken
        self.refreshing = refreshing
        self.sections = sections
        self.size = size
        self.tracker = tracker
        self.onVisibleRangeChange = onVisibleRangeChange
        self.onVisibleItemsChange = onVisibleItemsChange
        self.onTap = onTap
        self.onScrollChange = onScrollChange
        self.onRefresh = onRefresh
        let metrics = MediaBrowserMetrics(level: level, width: size.width, count: items.count, refreshing: refreshing)
        self.metrics = metrics
        // Rule 2: the first appearance rests at the newest end. A level change rests where the
        // anchor puts it (rule 13).
        let startOffset = initialOffset ?? metrics.maxOffset(viewport: size.height)
        _position = State(initialValue: initialOffset.map { ScrollPosition(y: $0) } ?? ScrollPosition(edge: .bottom))
        _window = State(initialValue: metrics.window(visibleTop: startOffset, viewport: size.height))
        // Rule 14: pills fade in after the new level settles, never during the crossfade.
        _pillsShown = State(initialValue: !fadePillsIn)
    }

    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: size.width, height: metrics.contentHeight)

                // The window is clamped to the CURRENT row count: `items` can shrink (a refresh
                // reloading page 1, a filter) while the mounted window still points past the
                // new end, until the next scroll geometry callback moves it.
                ForEach(Array(window.clamped(to: 0..<metrics.rowCount)), id: \.self) { row in
                    tileRow(row)
                        .padding(.top, CGFloat(row) * metrics.pitch)
                }

                if level.showsPills {
                    pills
                        .opacity(pillsShown ? 1 : 0)
                }

                if refreshing {
                    refreshIndicator
                        .padding(.top, metrics.gridHeight)
                }
            }
            .frame(width: size.width, height: metrics.contentHeight, alignment: .topLeading)
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .scrollDisabled(frozen)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { tracker.globalFrame = $0 })
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }, action: { _, geometry in
            scrolled(geometry)
        })
        .onScrollPhaseChange { old, new in
            tracker.fingerDown = new == .interacting
            if old == .interacting, new != .interacting, tracker.refreshArmed {
                tracker.refreshArmed = false
                onRefresh()
            }
            if let geometry = tracker.geometry {
                onScrollChange(geometry.contentOffset.y + geometry.contentInsets.top, tracker.fingerDown)
            }
        }
        .onChange(of: items.count) {
            if let geometry = tracker.geometry { scrolled(geometry) }
        }
        .onChange(of: scrollToNewestToken) {
            // §2b: "It never jumps to the newest end on its own, only on a
            // `scrollToNewestToken` change (rule 4)."
            position.scrollTo(edge: .bottom)
        }
        .onAppear {
            guard !pillsShown else { return }
            withAnimation(Token.Motion.menuFadeIn.delay(MediaBrowserMotion.crossfadeDuration)) {
                pillsShown = true
            }
        }
    }

    // MARK: Scroll bookkeeping

    private func scrolled(_ geometry: ScrollGeometry) {
        tracker.geometry = geometry
        tracker.geometryLevel = level

        let visible = metrics.visibleRows(top: geometry.visibleRect.minY, bottom: geometry.visibleRect.maxY)
        if visible.lowerBound < window.lowerBound || visible.upperBound > window.upperBound
            || window.upperBound > metrics.rowCount {
            window = metrics.window(visibleTop: geometry.visibleRect.minY, viewport: geometry.visibleRect.height)
        }

        // C-129 §4 `onVisibleRangeChange`: the visible indices plus a prefetch margin of one
        // viewport each way (the same margin the window mounts).
        let range = metrics.itemRange(rows: metrics.window(visibleTop: geometry.visibleRect.minY, viewport: geometry.visibleRect.height))
        if range != tracker.lastReportedRange {
            tracker.lastReportedRange = range
            onVisibleRangeChange(range)
        }
        let onScreen = metrics.itemRange(rows: visible)
        if onScreen != tracker.lastReportedVisible {
            tracker.lastReportedVisible = onScreen
            onVisibleItemsChange(onScreen)
        }

        onScrollChange(geometry.contentOffset.y + geometry.contentInsets.top, tracker.fingerDown)

        // §2b Refresh: a pull past the newest end beyond a threshold, then released.
        let overscroll = geometry.contentOffset.y + geometry.containerSize.height
            - geometry.contentInsets.bottom - geometry.contentSize.height
        if tracker.fingerDown, !refreshing, overscroll > MediaBrowserMotion.refreshPullDistance {
            tracker.refreshArmed = true
        }
    }

    // MARK: Tiles

    private func tileRow(_ row: Int) -> some View {
        let first = min(row * metrics.columns, items.count)
        let last = min(first + metrics.columns, items.count)
        return HStack(spacing: metrics.gutter) {
            ForEach(Array(first..<last), id: \.self) { index in
                tile(index)
            }
        }
        .frame(width: size.width, height: metrics.side, alignment: .leading)
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let item = items[index]
        let face = tileFace(item, index: index)
        if level.tappable && !frozen {
            // `SwiftUI.` because this module declares its own C-0xx `Button`.
            SwiftUI.Button {
                onTap(item.id, globalFrame(of: index))
            } label: {
                face
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.label(for: item))
            .accessibilityAddTraits(.isButton)
        } else {
            face
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.label(for: item))
                .accessibilityAddTraits(.isImage)
        }
    }

    private func tileFace(_ item: MediaBrowser.Item, index: Int) -> some View {
        // `hiddenItemID`: "drawn blank in the same placeholder fill" (§2). The image is not
        // even asked for, so the viewer's fly-back lands on an empty cell.
        let picture = item.id == hiddenItemID ? nil : image(item.id)
        return ZStack {
            if let picture {
                // Rule 5: square, aspect-fill, centre-cropped.
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: metrics.side, height: metrics.side)
                    .clipped()
            } else {
                // Rule 9: a dark placeholder, never white.
                Rectangle()
                    .fill(MediaBrowserStyle.placeholderFill)
            }
        }
        .frame(width: metrics.side, height: metrics.side)
        .overlay(alignment: .bottomTrailing) {
            if level.showsBadges, let duration = item.duration {
                // §2 Badges: "Video duration: bottom-right, white, small semibold, with a soft shadow."
                Text(duration)
                    .designTextStyle(Token.TypeStyle.captionSemibold)
                    .foregroundStyle(Token.textPrimary)
                    .designShadow(Token.Elevation.thumbnail)
                    .padding(Token.Space.metaGap)
                    .ui2Element("Video duration")
            }
        }
        .overlay(alignment: .bottomLeading) {
            if level.showsBadges, item.favorite {
                // §2 Badges: "Favourite: bottom-left `heart` glyph (template, white)."
                Glyph(.heart, size: .sm, tint: Token.textPrimary)
                    .designShadow(Token.Elevation.thumbnail)
                    .padding(Token.Space.metaGap)
                    .ui2Element("Favourite")
            }
        }
        .ui2Element("Tile \(index + 1)")
    }

    /// §2b Accessibility: "Badges add their meaning to the tile label ('video, 0:35', 'favourite')."
    private static func label(for item: MediaBrowser.Item) -> String {
        var parts = [item.accessibilityLabel]
        if let duration = item.duration { parts.append("video, \(duration)") }
        if item.favorite { parts.append("favourite") }
        return parts.joined(separator: ", ")
    }

    /// C-129 §4 `onTap`: the tile's GLOBAL frame, which the viewer grows from.
    private func globalFrame(of index: Int) -> CGRect {
        let origin = tracker.globalFrame.origin
        let visibleTop = tracker.geometry?.visibleRect.minY ?? 0
        let column = index % metrics.columns
        let row = index / metrics.columns
        return CGRect(
            x: origin.x + CGFloat(column) * metrics.pitch,
            y: origin.y + CGFloat(row) * metrics.pitch - visibleTop,
            width: metrics.side,
            height: metrics.side
        )
    }

    // MARK: Pills

    /// §2b "Pills: sticky with push-off." Each section's pill sits at the left of the row that
    /// holds the section's first item. The top section's pill pins just under the top edge, and
    /// the next pill pushes it up and out. Each pill is placed by layout (so its element rect is
    /// true) and pinned by a visual effect that reads its own frame in the scroll view, which
    /// costs no state and no re-render while scrolling.
    private var pills: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(sections.enumerated()), id: \.offset) { ordinal, section in
                let flowY = metrics.rowTop(ofItem: section.firstIndex) + MediaBrowserStyle.pillPinInset
                let nextFlowY = ordinal + 1 < sections.count
                    ? metrics.rowTop(ofItem: sections[ordinal + 1].firstIndex) + MediaBrowserStyle.pillPinInset
                    : CGFloat.greatestFiniteMagnitude
                let pushLimit = nextFlowY - flowY - MediaBrowserStyle.pillHeight
                MediaBrowserPill(text: section.label)
                    .ui2Element("Pill \(ordinal + 1)")
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        let pin = max(0, MediaBrowserStyle.pillPinInset - minY)
                        return content.offset(y: min(pin, pushLimit))
                    }
                    .padding(.leading, Token.Space.pageMargin)
                    .padding(.top, flowY)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Refresh

    /// OQ-C-129-003 (owner): "a C-076 ActivitySpinner centred in the bottom content inset,
    /// below the last row, while `refreshing` is true."
    // STUB — C-076, not a linked component. §5 Consumes lists no registry rows, so this build
    // draws the spinner's 24 pt slot only. Linking C-076 in §5 (a /d2m:component:spec re-run)
    // makes it real.
    private var refreshIndicator: some View {
        Rectangle()
            .strokeBorder(Token.textPrimary, style: StrokeStyle(lineWidth: 1, dash: [3]))
            .frame(width: MediaBrowserStyle.spinnerSize, height: MediaBrowserStyle.spinnerSize)
            .padding(.vertical, Token.Space.cardPadding)
            .frame(width: size.width)
            .accessibilityLabel("Refreshing")
            .ui2Element("Refresh indicator")
    }
}

// MARK: - Pill

/// §2 Pill: a capsule with a translucent dark fill and white semibold text, overlaying the tiles.
private struct MediaBrowserPill: View {
    let text: String

    var body: some View {
        Text(text)
            .designTextStyle(MediaBrowserStyle.pillType)
            .frame(height: MediaBrowserStyle.pillType.lineHeight)
            .foregroundStyle(Token.textPrimary)
            .padding(.vertical, MediaBrowserStyle.pillPaddingY)
            .padding(.horizontal, MediaBrowserStyle.pillPaddingX)
            // `radius-circle` does not parse ("50%"), so the capsule is the shape itself.
            .background(Capsule().fill(MediaBrowserStyle.pillFill))
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Style values

private enum MediaBrowserStyle {
    // GAP — C-129 OQ-C-129-004: `color-media-placeholder` ("a dark grey just above the page
    // ground"), ruled to be minted but not yet a token row.
    static let placeholderFill = Color(red: 0.102, green: 0.110, blue: 0.122, opacity: 1)
    // GAP — C-129 OQ-C-129-004: `color-media-pill` ("black at 50% opacity"), not yet a token row.
    static let pillFill = Color(red: 0, green: 0, blue: 0, opacity: 0.5)
    // GAP — C-129 OQ-C-129-004: `type-media-pill` ("SF Pro Semibold 15/20"), not yet a token row.
    static let pillType = DesignTextStyle(weight: .semibold, size: 15, lineHeight: 20, tracking: 0)
    // GAP — C-129 OQ-C-129-004: "Pill padding is 6 × 12", no spacing token.
    static let pillPaddingY: CGFloat = 6
    static let pillPaddingX: CGFloat = 12
    static let pillHeight: CGFloat = (pillType.lineHeight ?? pillType.size) + 2 * pillPaddingY
    /// §2b "The top section's pill pins just under the top content inset" (no measure given).
    static let pillPinInset: CGFloat = Token.Space.elementGap
    /// C-076 §4 `size` default (24).
    static let spinnerSize: CGFloat = 24
}

private enum MediaBrowserMotion {
    // GAP — C-129 §2b: "a ~0.4–0.5 s crossfade", no motion token.
    static let crossfadeDuration: Double = 0.45
    static let crossfade = Animation.easeInOut(duration: crossfadeDuration)
    /// §2b: "passes ×0.7 (out) or ×1.4 (in) from the current base".
    static let pinchOutThreshold: CGFloat = 0.7
    static let pinchInThreshold: CGFloat = 1.4
    // GAP — C-129 §2b: "Pulling past the newest end beyond a threshold" (no distance given).
    static let refreshPullDistance: CGFloat = 64
}

// MARK: - Geometry

/// One level's layout on one width. §2: side = (width − (columns − 1) × gutter) ÷ columns.
private struct MediaBrowserMetrics {
    let columns: Int
    let gutter: CGFloat
    let side: CGFloat
    let pitch: CGFloat
    let rowCount: Int
    let gridHeight: CGFloat
    let contentHeight: CGFloat
    let count: Int

    init(level: MediaBrowser.Level, width: CGFloat, count: Int, refreshing: Bool) {
        columns = level.columns
        gutter = level.gutter
        side = max(0, (width - CGFloat(columns - 1) * gutter) / CGFloat(columns))
        pitch = side + gutter
        self.count = count
        rowCount = (count + columns - 1) / columns
        gridHeight = rowCount == 0 ? 0 : CGFloat(rowCount) * pitch - gutter
        let footer = refreshing ? MediaBrowserStyle.spinnerSize + 2 * Token.Space.cardPadding : 0
        contentHeight = gridHeight + footer
    }

    func maxOffset(viewport: CGFloat) -> CGFloat { max(0, contentHeight - viewport) }

    func rowTop(ofItem index: Int) -> CGFloat { CGFloat(index / columns) * pitch }

    func visibleRows(top: CGFloat, bottom: CGFloat) -> Range<Int> {
        guard pitch > 0, rowCount > 0 else { return 0..<0 }
        let first = min(rowCount, max(0, Int((top / pitch).rounded(.down))))
        let last = min(rowCount, Int((bottom / pitch).rounded(.up)))
        return first..<max(first, last)
    }

    /// The visible rows plus one viewport of rows above and below.
    func window(visibleTop: CGFloat, viewport: CGFloat) -> Range<Int> {
        guard pitch > 0, rowCount > 0 else { return 0..<0 }
        let margin = viewport
        let first = min(rowCount, max(0, Int(((visibleTop - margin) / pitch).rounded(.down))))
        let last = min(rowCount, Int(((visibleTop + viewport + margin) / pitch).rounded(.up)))
        return first..<max(first, last)
    }

    func itemRange(rows: Range<Int>) -> Range<Int> {
        let lower = min(count, rows.lowerBound * columns)
        let upper = min(count, rows.upperBound * columns)
        return lower..<max(lower, upper)
    }
}

// MARK: - Sections

struct MediaBrowserSection: Equatable {
    let label: String
    let firstIndex: Int
}

// MARK: - Tracker

/// Ephemeral scroll and pinch bookkeeping, shared by the grids of every level. It is deliberately
/// NOT observable: it is written from scroll and gesture callbacks, and an observed write there
/// would re-render on every frame (rule 17a).
final class MediaBrowserTracker {
    var geometry: ScrollGeometry?
    var geometryLevel: MediaBrowser.Level?
    var globalFrame: CGRect = .zero
    var fingerDown = false
    var refreshArmed = false
    var lastReportedRange: Range<Int>?
    var lastReportedVisible: Range<Int>?

    var pinching = false
    var pinchBase: CGFloat = 1
    var pinchLevel: MediaBrowser.Level = .five
    /// The item under the pinch midpoint and its y on screen (rule 13), and the level it targets.
    var anchorIndex = 0
    var anchorScreenY: CGFloat = 0
    var anchorTarget: MediaBrowser.Level?
    var anchorUnit: UnitPoint = .center
    var outgoingScale: CGFloat = 1

    private var cachedItems: [MediaBrowser.Item]?
    private var cachedByYear = false
    private var cachedTimeZone: TimeZone?
    private var cachedSections: [MediaBrowserSection] = []

    func beginPinch(at location: CGPoint, level: MediaBrowser.Level, size: CGSize, count: Int) {
        pinching = true
        pinchBase = 1
        pinchLevel = level
        let metrics = MediaBrowserMetrics(level: level, width: size.width, count: count, refreshing: false)
        let top = geometry?.visibleRect.minY ?? 0
        let row = metrics.pitch > 0 ? Int(((top + location.y) / metrics.pitch).rounded(.down)) : 0
        let column = metrics.pitch > 0 ? min(metrics.columns - 1, Int((location.x / metrics.pitch).rounded(.down))) : 0
        anchorIndex = max(0, min(count - 1, row * metrics.columns + column))
        anchorScreenY = location.y
        anchorUnit = UnitPoint(
            x: size.width > 0 ? location.x / size.width : 0.5,
            y: size.height > 0 ? location.y / size.height : 0.5
        )
    }

    func step(from current: MediaBrowser.Level, to next: MediaBrowser.Level, base: CGFloat, width: CGFloat) {
        let old = MediaBrowserMetrics(level: current, width: width, count: 0, refreshing: false)
        let new = MediaBrowserMetrics(level: next, width: width, count: 0, refreshing: false)
        outgoingScale = old.side > 0 ? new.side / old.side : 1
        pinchLevel = next
        pinchBase = base
        anchorTarget = next
    }

    /// Where a level's new grid starts. On the first appearance the answer is nil, so the grid
    /// rests at the newest end (rule 2). After a level change, the anchored item keeps its screen y
    /// (rule 13). The anchor is the pinch midpoint, or the item at the viewport centre when the
    /// caller changed the level itself (rule 4).
    func initialOffset(for level: MediaBrowser.Level, size: CGSize, count: Int, refreshing: Bool) -> CGFloat? {
        guard let geometry, let oldLevel = geometryLevel, oldLevel != level, count > 0 else { return nil }
        let index: Int
        let screenY: CGFloat
        if anchorTarget == level {
            index = anchorIndex
            screenY = anchorScreenY
        } else {
            let old = MediaBrowserMetrics(level: oldLevel, width: size.width, count: count, refreshing: false)
            let centreY = geometry.visibleRect.midY
            let row = old.pitch > 0 ? Int((centreY / old.pitch).rounded(.down)) : 0
            index = max(0, min(count - 1, row * old.columns + old.columns / 2))
            screenY = centreY - geometry.visibleRect.minY
        }
        let new = MediaBrowserMetrics(level: level, width: size.width, count: count, refreshing: refreshing)
        let target = new.rowTop(ofItem: index) + new.side / 2 - screenY
        return min(max(0, target), new.maxOffset(viewport: size.height))
    }

    /// Month (or year) sections cut from `Item.date` in `timeZone` (§2b, D5). Cached on the
    /// items themselves (an O(n) compare, far cheaper than re-walking 37k dates through a
    /// calendar), so a library whose ends match but whose middle changed is re-sectioned.
    func sections(items: [MediaBrowser.Item], byYear: Bool, timeZone: TimeZone) -> [MediaBrowserSection] {
        if byYear == cachedByYear, timeZone == cachedTimeZone, items == cachedItems { return cachedSections }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // §2 Pill: "MMM yyyy" ("Oct 2026"). The month names come from a fixed English locale,
        // because a process with no locale data (the capture runner) gets "M10" from the current one.
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let months = calendar.shortMonthSymbols
        var result: [MediaBrowserSection] = []
        var previous = -1
        for (index, item) in items.enumerated() {
            let parts = calendar.dateComponents([.year, .month], from: item.date)
            let year = parts.year ?? 0
            let month = parts.month ?? 1
            let section = byYear ? year : year * 100 + month
            if section != previous {
                previous = section
                let label = byYear ? String(year) : "\(months[month - 1]) \(year)"
                result.append(MediaBrowserSection(label: label, firstIndex: index))
            }
        }
        cachedItems = items
        cachedByYear = byYear
        cachedTimeZone = timeZone
        cachedSections = result
        return result
    }
}

// MARK: - Crossfade

/// §2b: "the outgoing grid scales toward the new tile size while the incoming one fades in."
/// The scale and its anchor are read from the tracker when the transition runs, because they are
/// only known once the pinch has stepped.
private struct MediaBrowserCrossfade: Transition {
    let tracker: MediaBrowserTracker

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase == .didDisappear ? tracker.outgoingScale : 1, anchor: tracker.anchorUnit)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
