//
//  DayTimeline.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-120-day-timeline in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-120 DayTimeline — "one day's page: pinned all-day row over a scrolling 24-hour grid of
/// event blocks and the now line".
///
/// §2: "Fills the frame the parent gives (the day area under the subtitle hairline). Top: the
/// **all-day row**, pinned, only when `allDayEvents` is non-empty. Below: a vertical **scroll
/// view** of the hour canvas."
struct DayTimeline: View {

    // MARK: - Models (§4, nested — R-36)

    /// §4 `TimedEvent` — "`id` · `title` · `detail?` · `detailKind: C-117 detailKind` ·
    /// `eventType: C-112 EventType` · `recurring` · `startMinute` (0…1439) · `endMinute`
    /// (start+1…1440) · `timeRangeText`. Overnight events arrive already split per day (D14)".
    struct TimedEvent: Identifiable {
        let id: String
        let title: String
        let detail: String?
        let detailKind: CalendarEventBlock.DetailKind
        let eventType: EventIndicator.EventType
        let recurring: Bool
        let startMinute: Int
        let endMinute: Int
        let timeRangeText: String
    }

    /// §4 `AllDayEvent` — "`id` · `title` · `eventType: C-112 EventType`".
    struct AllDayEvent: Identifiable {
        let id: String
        let title: String
        let eventType: EventIndicator.EventType
    }

    // MARK: - Props (§4, in the contract's order — R-05)

    /// §4 `timedEvents` — each becomes a C-117 block packed into overlap columns.
    let timedEvents: [TimedEvent]
    /// §4 `allDayEvents` — "`[]` = no all-day row".
    let allDayEvents: [AllDayEvent]
    /// §4 `allDayExpanded` — "all chips shown (true) vs 3 + overflow (false)".
    let allDayExpanded: Bool
    /// §4 `onAllDayExpandedChange` — "the overflow chip's tap". Unrequired (R-07 call-out).
    var onAllDayExpandedChange: (Bool) -> Void = { _ in }
    /// §4 `nowMinute` — "minute of day for C-119 on today's page; nil on every other day".
    let nowMinute: Int?
    /// §4 `topMinute` — "the minute at the viewport's top".
    let topMinute: Int
    /// §4 `onTopMinuteChange` — "reports the user's scroll". Unrequired (R-07 call-out).
    var onTopMinuteChange: (Int) -> Void = { _ in }
    /// §4 `onOpenEvent` — "a block or chip tap, with its event `id` (D7)". Unrequired.
    var onOpenEvent: (String) -> Void = { _ in }
    /// §4 `onNextDay` — VoiceOver "Next day" custom action (§10). Unrequired.
    var onNextDay: () -> Void = {}
    /// §4 `onPreviousDay` — VoiceOver "Previous day" custom action (§10). Unrequired.
    var onPreviousDay: () -> Void = {}

    // MARK: - Ephemeral scroll mechanics (R-02)

    /// The scroll view's own position. Not a designed state: `topMinute` drives it (initial
    /// anchor + every prop change) and the user's scroll leaves through `onTopMinuteChange`
    /// (R-01). It only exists because SwiftUI's scroll API takes a binding.
    @SwiftUI.State private var position = ScrollPosition()
    /// The last minute this view reported, so an echo of it back through `topMinute` does not
    /// re-scroll mid-gesture.
    @SwiftUI.State private var reportedMinute: Int?

    @Environment(\.displayScale) private var displayScale

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                allDayRow
            }
            timeline
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ui2Element("DayTimeline")
        // §2 Accessibility (R-17): "custom actions \"Next day\" / \"Previous day\"".
        .accessibilityAction(named: "Next day", onNextDay)
        .accessibilityAction(named: "Previous day", onPreviousDay)
    }

    // MARK: - All-day row

    /// §2 All-day row — "padding `space-meta-gap` (4) top/bottom; label \"all-day\" … right-aligned
    /// at x 56 on the first chip's centre; C-118 chips x 66 → trailing − 2, stacked with
    /// `space-chip-gap` (2) … 1 px `color-white-10` hairline under the row" (OQ-C-120-001).
    private var allDayRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstChipCentre, spacing: 0) {
                Text(Self.allDayLabel)
                    .designTextStyle(Self.allDayLabelStyle)
                    .foregroundStyle(Token.white50)
                    .lineLimit(1)
                    .ui2Element("All-day label")
                    .frame(width: Geometry.labelTrailingX, alignment: .trailing)
                    .alignmentGuide(.firstChipCentre) { $0[VerticalAlignment.center] }

                VStack(spacing: Token.Space.chipGap) {
                    ForEach(Array(visibleAllDayChips.enumerated()), id: \.element.key) { index, chip in
                        // Only the first chip declares the guide, so the stack reports its centre.
                        if index == 0 {
                            chip.view
                                .alignmentGuide(.firstChipCentre) { $0[VerticalAlignment.center] }
                                .ui2Element(chip.isOverflow ? "Overflow chip" : "All-day chip \(index + 1)")
                        } else {
                            chip.view
                                .ui2Element(chip.isOverflow ? "Overflow chip" : "All-day chip \(index + 1)")
                        }
                    }
                }
                .padding(.leading, Geometry.blockLeadingX - Geometry.labelTrailingX)
                .padding(.trailing, Geometry.blockTrailingInset)
            }
            .padding(.vertical, Token.Space.metaGap)

            hairline
                .ui2Element("All-day hairline")
        }
        .ui2Element("All-day row")
    }

    /// "> 3 events and not expanded → first 3 + an overflow C-118 \"+N more\" (`.other`) whose
    /// tap calls `onAllDayExpandedChange(true)`; expanded → all." (OQ-C-120-001: no collapse chip.)
    private var visibleAllDayChips: [AllDayChipItem] {
        let collapses = !allDayExpanded && allDayEvents.count > Geometry.collapsedChipCount
        let shown = collapses ? Array(allDayEvents.prefix(Geometry.collapsedChipCount)) : allDayEvents
        var items = shown.map { event in
            AllDayChipItem(key: event.id, isOverflow: false, view: AnyView(
                AllDayEventChip(title: event.title, eventType: event.eventType, onTap: { onOpenEvent(event.id) })
            ))
        }
        if collapses {
            let hidden = allDayEvents.count - Geometry.collapsedChipCount
            items.append(AllDayChipItem(key: "__overflow", isOverflow: true, view: AnyView(
                AllDayEventChip(title: "+\(hidden) more", eventType: .other, onTap: { onAllDayExpandedChange(true) })
            )))
        }
        return items
    }

    private struct AllDayChipItem {
        let key: String
        let isOverflow: Bool
        let view: AnyView
    }

    // MARK: - Timeline

    /// §2 Canvas — "minute m at y = 8 + m × 50/60. Scroll offset = `topMinute` × 50/60 (clamped)".
    private var timeline: some View {
        GeometryReader { viewport in
            ScrollView(.vertical) {
                canvas(width: viewport.size.width)
            }
            .scrollIndicators(.hidden)
            .scrollPosition($position)
            // The initial offset is layout, not an effect: a fraction of the scrollable range
            // that puts `topMinute` at the viewport's top on the first pass.
            .defaultScrollAnchor(
                UnitPoint(x: 0, y: anchorFraction(minute: topMinute, viewportHeight: viewport.size.height)),
                for: .initialOffset
            )
            .onScrollGeometryChange(for: Int.self) { geometry in
                Int((geometry.contentOffset.y / Geometry.pointsPerMinute).rounded())
            } action: { _, minute in
                reportedMinute = minute
                if minute != topMinute { onTopMinuteChange(minute) }
            }
            .onChange(of: topMinute) { _, minute in
                guard minute != reportedMinute else { return }
                position.scrollTo(y: offset(minute: minute, viewportHeight: viewport.size.height))
            }
        }
        .ui2Element("Timeline")
    }

    private func canvas(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // §2 Hour hairline — "1 px `color-white-10`, x 64 → trailing edge, at each hour's y".
            ForEach(0...Geometry.hours, id: \.self) { hour in
                hairline
                    .frame(width: max(width - Geometry.hairlineX, 0))
                    .ui2Element("Hour hairline \(hour + 1)")
                    .position(x: Geometry.hairlineX + (width - Geometry.hairlineX) / 2, y: y(minute: hour * 60))
            }

            // §2 Hour label — "hours 0…24 (both 12 AMs labelled), right-aligned at x 56,
            // centred on the hour's y".
            ForEach(0...Geometry.hours, id: \.self) { hour in
                hourLabel(hour)
                    .lineLimit(1)
                    .fixedSize()
                    .ui2Element("Hour label \(hour + 1)")
                    .frame(width: Geometry.labelTrailingX, alignment: .trailing)
                    .position(x: Geometry.labelTrailingX / 2, y: y(minute: hour * 60))
            }

            // §2 Event blocks — "one C-117 per `timedEvents` item", packed into overlap columns.
            ForEach(Array(placedBlocks(width: width).enumerated()), id: \.element.event.id) { index, block in
                CalendarEventBlock(
                    title: block.event.title,
                    detail: block.event.detail,
                    detailKind: block.event.detailKind,
                    eventType: block.event.eventType,
                    recurring: block.event.recurring,
                    timeRangeText: block.event.timeRangeText,
                    onTap: { onOpenEvent(block.event.id) }
                )
                .frame(width: block.frame.width, height: block.frame.height)
                .ui2Element("Event block \(index + 1)")
                .position(x: block.frame.midX, y: block.frame.midY)
            }

            // §2 Now line — "C-119 at `nowMinute` (centred on its y), above the blocks; label =
            // `nowMinute` as h:mm".
            if let nowMinute {
                NowIndicator(label: Self.clockLabel(minute: nowMinute))
                    .frame(width: width)
                    .ui2Element("Now line")
                    .position(x: width / 2, y: y(minute: nowMinute))
            }
        }
        .frame(width: width, height: Geometry.canvasHeight, alignment: .topLeading)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Token.white10)
            .frame(height: 1 / displayScale)     // §2: "1 px"
    }

    // MARK: - Hour labels

    /// §2: numeral `type-footnote` (Regular 13) + space + "AM"/"PM" Regular 8 (FLAGGED), both
    /// `color-white-50`; 12 PM = "Noon", Semibold 10 `color-white-50` (FLAGGED, OQ-C-120-002).
    private func hourLabel(_ hour: Int) -> Text {
        if hour == 12 {
            return Text(Self.noonLabel)
                .font(Self.noonStyle.font)
                .foregroundStyle(Token.white50)
        }
        let numeral = hour % 12 == 0 ? 12 : hour % 12
        let meridiem = (hour % 24) < 12 ? "AM" : "PM"
        return Text("\(numeral) ")
            .font(Token.TypeStyle.footnote.font)
            .foregroundStyle(Token.white50)
        + Text(meridiem)
            .font(Self.meridiemStyle.font)
            .foregroundStyle(Token.white50)
    }

    /// §2 Now line label — "`nowMinute` as h:mm (\"10:42\")", no AM/PM (C-119 §4).
    private static func clockLabel(minute: Int) -> String {
        let hour = (minute / 60) % 12
        return String(format: "%d:%02d", hour == 0 ? 12 : hour, minute % 60)
    }

    // MARK: - Block placement (§2 Event blocks)

    private struct PlacedBlock {
        let event: TimedEvent
        let frame: CGRect
    }

    /// "y = start, height = max(20, (end − start) × 50/60) − 1 (the 1 pt inner gap). **Overlap:**
    /// events whose ranges intersect form a cluster; within it columns are assigned greedily by
    /// start (earliest leftmost, ties by longer first); each block's width = (W − 68 − (cols − 1)
    /// × 2) / cols, x = 66 + col × (width + 2)".
    private func placedBlocks(width: CGFloat) -> [PlacedBlock] {
        let ordered = timedEvents.sorted {
            if $0.startMinute != $1.startMinute { return $0.startMinute < $1.startMinute }
            return ($0.endMinute - $0.startMinute) > ($1.endMinute - $1.startMinute)
        }

        // Clusters of transitively intersecting ranges, each event with its greedy column.
        var clusters: [[(event: TimedEvent, column: Int)]] = []
        var columnEnds: [Int] = []
        var clusterEnd = Int.min
        for event in ordered {
            if clusters.isEmpty || event.startMinute >= clusterEnd {
                clusters.append([])
                columnEnds = []
                clusterEnd = event.endMinute
            }
            let column = columnEnds.firstIndex { $0 <= event.startMinute } ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(event.endMinute) } else { columnEnds[column] = event.endMinute }
            clusters[clusters.count - 1].append((event, column))
            clusterEnd = max(clusterEnd, event.endMinute)
        }

        return clusters.flatMap { cluster -> [PlacedBlock] in
            let columns = CGFloat((cluster.map(\.column).max() ?? 0) + 1)
            let available = width - Geometry.blockLeadingX - Geometry.blockTrailingInset
            let blockWidth = max((available - (columns - 1) * Geometry.columnGap) / columns, 0)
            return cluster.map { item in
                let top = y(minute: item.event.startMinute)
                let duration = CGFloat(item.event.endMinute - item.event.startMinute) * Geometry.pointsPerMinute
                let height = max(Geometry.minimumBlockHeight, duration) - Geometry.blockInnerGap
                let x = Geometry.blockLeadingX + CGFloat(item.column) * (blockWidth + Geometry.columnGap)
                return PlacedBlock(event: item.event, frame: CGRect(x: x, y: top, width: blockWidth, height: height))
            }
        }
    }

    // MARK: - Minute ↔ point

    private func y(minute: Int) -> CGFloat {
        Geometry.verticalPadding + CGFloat(minute) * Geometry.pointsPerMinute
    }

    /// "Scroll offset = `topMinute` × 50/60 (clamped)" — to the scrollable range.
    private func offset(minute: Int, viewportHeight: CGFloat) -> CGFloat {
        let range = max(Geometry.canvasHeight - viewportHeight, 0)
        return min(max(CGFloat(minute) * Geometry.pointsPerMinute, 0), range)
    }

    private func anchorFraction(minute: Int, viewportHeight: CGFloat) -> CGFloat {
        let range = Geometry.canvasHeight - viewportHeight
        guard range > 0 else { return 0 }
        return offset(minute: minute, viewportHeight: viewportHeight) / range
    }

    // MARK: - Strings

    private static let allDayLabel = "all-day"
    private static let noonLabel = "Noon"

    // MARK: - Type

    /// FLAGGED LITERAL — C-120 §2: "\"AM\"/\"PM\" Regular 8 (FLAGGED)".
    private static let meridiemStyle = DesignTextStyle(weight: .regular, size: 8, lineHeight: nil, tracking: 0)
    /// FLAGGED LITERAL — C-120 §2: "12 PM = \"Noon\", Semibold 10 (FLAGGED, OQ-C-120-002)".
    private static let noonStyle = DesignTextStyle(weight: .semibold, size: 10, lineHeight: nil, tracking: 0)
    /// FLAGGED LITERAL — C-120 §2: all-day "label \"all-day\" Regular 9 (FLAGGED)".
    private static let allDayLabelStyle = DesignTextStyle(weight: .regular, size: 9, lineHeight: nil, tracking: 0)

    // MARK: - Geometry

    /// §2: "Constants are **FLAGGED LITERALS** (02-design §5.3), no layout tokens".
    private enum Geometry {
        static let hours = 24                                    // FLAGGED LITERAL — C-120 §2: hours 0…24
        static let pointsPerHour: CGFloat = 50                   // FLAGGED LITERAL — C-120 §2: 50 pt/hour
        static let pointsPerMinute: CGFloat = pointsPerHour / 60
        static let verticalPadding: CGFloat = 8                  // FLAGGED LITERAL — C-120 §2: 8 pt top/bottom padding
        static let canvasHeight: CGFloat = verticalPadding * 2 + CGFloat(hours) * pointsPerHour   // §2: 1216
        static let labelTrailingX: CGFloat = 56                  // FLAGGED LITERAL — C-120 §2: label x 56
        static let hairlineX: CGFloat = 64                       // FLAGGED LITERAL — C-120 §2: hairline x 64
        static let blockLeadingX: CGFloat = 66                   // FLAGGED LITERAL — C-120 §2: block x 66
        static let blockTrailingInset: CGFloat = 2               // FLAGGED LITERAL — C-120 §2: "W − 68" = x 66 → trailing − 2
        static let columnGap: CGFloat = 2                        // FLAGGED LITERAL — C-120 §2: "(cols − 1) × 2"
        static let minimumBlockHeight: CGFloat = 20              // FLAGGED LITERAL — C-120 §2: "max(20, …)"
        static let blockInnerGap: CGFloat = 1                    // FLAGGED LITERAL — C-120 §2: "− 1 (the 1 pt inner gap)"
        static let collapsedChipCount = 3                        // FLAGGED LITERAL — C-120 §2: "first 3 + … \"+N more\""
    }
}

private extension VerticalAlignment {
    /// The all-day label sits "on the first chip's centre" (§2, OQ-C-120-001).
    enum FirstChipCentre: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.top] }
    }

    static let firstChipCentre = VerticalAlignment(FirstChipCentre.self)
}
