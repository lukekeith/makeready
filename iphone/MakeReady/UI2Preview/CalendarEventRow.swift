//
//  CalendarEventRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-121-calendar-event-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  DEPENDENCIES: none. C-121 §5 consumes no registry row; it cites two value sets — C-117's
//  `CalendarEventBlock.DetailKind` (the detail glyph) and C-112's `EventIndicator.EventType`
//  (the bar colour) — and draws library glyphs `map-pin` / `video-record` / `users`.
//

import SwiftUI

/// C-121 CalendarEventRow — "one event in the calendar's search results: colour bar, title,
/// detail line and its times".
///
/// §2: "Width-driven (R-16), full screen width; fixed height **52** = 7 + 38 content + 7 …
/// No background, no separator (the screen draws day headers + hairlines)." The page margin is
/// inside the row (the bar sits at x 20, the times end at trailing − 20), so the capture call
/// site gives it the full width with no outer margin.
struct CalendarEventRow: View {

    // MARK: - Vocabulary

    /// §4 `CalendarEventRow.Timing` — "what the time column shows (§3)". Raw values are the §4
    /// case names, which are what the fixture sends.
    enum Timing: String, CaseIterable {
        /// "`startTime` over `endTime`"
        case timed
        /// "`startTime` only (the event runs past midnight; this is its start day)"
        case continues
        /// "\"Ends\" over `endTime` (the overnight continuation's day, D14)"
        case ends
        /// "\"all-day\""
        case allDay
    }

    // MARK: - Props (§4, in the contract's order — R-05)

    /// §4 `title` — "the event title".
    let title: String
    /// §4 `detail` — "location, online host or group name, caller-formatted; nil = no line".
    /// Unrequired (R-07 call-out).
    var detail: String? = nil
    /// §4 `detailKind` — "`C-117 detailKind` … the detail glyph; value set owned by C-117".
    let detailKind: CalendarEventBlock.DetailKind
    /// §4 `eventType` — "`C-112 EventType` … the bar colour; value set owned by C-112".
    let eventType: EventIndicator.EventType
    /// §4 `timing` — "what the time column shows (§3)".
    let timing: Timing
    /// §4 `startTime` — "caller-formatted start (\"3:50 PM\"); used by `timed`, `continues`".
    let startTime: String?
    /// §4 `endTime` — "caller-formatted end; used by `timed`, `ends`".
    let endTime: String?
    /// §4 `past` — "the event is before today → row at 0.5 opacity".
    let past: Bool
    /// §4 `onTap` — "the screen closes search and opens that day (§7.7)". No-op default;
    /// unrequired (R-07 call-out).
    var onTap: () -> Void = {}

    // MARK: - Body

    var body: some View {
        // `SwiftUI.Button`: the module's own C-105 `Button` shadows SwiftUI's.
        SwiftUI.Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                // §2 Bar — "3 × 38, radius 1.5, solid `eventType` token, at x **20**
                // (`space-page-margin` + `space-meta-gap`), top of the content box".
                RoundedRectangle(cornerRadius: Geometry.barRadius)
                    .fill(eventType.color)
                    .frame(width: Geometry.barWidth, height: Geometry.content)
                    .ui2Element("Bar")

                // §2 Text column — "leading x **30** (bar + 7, FLAGGED), trailing = time column
                // − `space-element-gap` (8); top-aligned in the 38 content box". Title and detail
                // scale with Dynamic Type up to XXL (§2).
                CalendarEventRowText(title: title, detail: detail, detailKind: detailKind)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.leading, Geometry.barToText)
                    .padding(.trailing, Token.Space.elementGap)
                    .ui2Element("Text column")

                timeColumn
                    .ui2Element("Time column")
            }
            .padding(.leading, Self.edgeInset)
            .padding(.trailing, Self.edgeInset)
            .padding(.vertical, Geometry.verticalInset)
            .frame(maxWidth: .infinity, minHeight: Geometry.height, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SystemHighlightStyle())
        // §2 Past — "whole row opacity **0.5** when `past`".
        .opacity(past ? Geometry.pastOpacity : 1)
        // §2 Accessibility (R-17): "one button, label \"<title>, <time text>[, <detail>]\"
        // (\"Lidon lunch, ends 12:30 AM\")".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .ui2Element("CalendarEventRow")             // capture element map — UI2Element.swift
    }

    /// §2 Time column — "right-aligned at trailing − 20, top-aligned, SF Pro **Regular 11**
    /// (FLAGGED), two lines max (line 14, gap 4). Content by `timing` (§3); top line
    /// `color-white-100`, bottom line `color-white-50`, \"all-day\" `color-white-50`"
    /// (OQ-C-121-001, answered: Regular 11 throughout, AM/PM same size). Times stay fixed under
    /// Dynamic Type (§2).
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: Token.Space.metaGap) {
            switch timing {
            case .timed:
                timeLine(startTime ?? "", color: Token.white100).ui2Element("Start time")
                timeLine(endTime ?? "", color: Token.white50).ui2Element("End time")
            case .continues:
                timeLine(startTime ?? "", color: Token.white100).ui2Element("Start time")
            case .ends:
                timeLine(Self.endsLabel, color: Token.white100).ui2Element("Ends")
                timeLine(endTime ?? "", color: Token.white50).ui2Element("End time")
            case .allDay:
                timeLine(Self.allDayLabel, color: Token.white50).ui2Element("All-day")
            }
        }
        .fixedSize()
    }

    private func timeLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Self.timeStyle.font)
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(height: Self.timeLineBox)
    }

    private var accessibilityText: String {
        var parts = [title, spokenTime]
        if let detail { parts.append(detail) }
        return parts.joined(separator: ", ")
    }

    private var spokenTime: String {
        switch timing {
        case .timed: "\(startTime ?? "") to \(endTime ?? "")"
        case .continues: startTime ?? ""
        case .ends: "ends \(endTime ?? "")"
        case .allDay: Self.allDayLabel
        }
    }

    // MARK: - Copy (§3)

    private static let endsLabel = "Ends"                   // §3 `ends`: "\"Ends\" over `endTime`"
    private static let allDayLabel = "all-day"              // §3 `allDay`: "\"all-day\""

    // MARK: - Type

    /// FLAGGED LITERAL — C-121 §2: Time column "SF Pro **Regular 11** (FLAGGED)", line 14.
    private static let timeStyle = DesignTextStyle(weight: .regular, size: 11, lineHeight: 14, tracking: 0)
    private static let timeLineBox: CGFloat = timeStyle.lineHeight ?? timeStyle.size

    // MARK: - Geometry

    /// §2: bar at x 20 and times at trailing − 20 — `space-page-margin` + `space-meta-gap`.
    private static let edgeInset: CGFloat = Token.Space.pageMargin + Token.Space.metaGap

    fileprivate enum Geometry {
        static let height: CGFloat = 52                     // FLAGGED LITERAL — C-121 §2: fixed height 52 (measured frame 12)
        static let verticalInset: CGFloat = 7               // FLAGGED LITERAL — C-121 §2: 52 = 7 + 38 + 7
        static let content: CGFloat = 38                    // FLAGGED LITERAL — C-121 §2: 38 content box
        static let barToText: CGFloat = 7                   // FLAGGED LITERAL — C-121 §2: text leading x 30 (bar + 7)
        static let barWidth: CGFloat = 3                    // FLAGGED LITERAL — C-121 §2: bar 3 wide (OQ-C-121-2)
        static let barRadius: CGFloat = 1.5                 // FLAGGED LITERAL — C-121 §2: bar radius 1.5 (OQ-C-121-2)
        static let pastOpacity: Double = 0.5                // FLAGGED LITERAL — C-121 §2: past opacity 0.5 (OQ-C-121-2)
    }
}

/// The title and the optional detail line. Its own view so that its `@ScaledMetric` sizes read
/// the Dynamic Type size the row caps at XXL (§2: "Title and detail scale with Dynamic Type up
/// to XXL (the row then grows — 52 is the default-size height)").
private struct CalendarEventRowText: View {
    let title: String
    let detail: String?
    let detailKind: CalendarEventBlock.DetailKind

    /// FLAGGED LITERAL — C-121 §2: Title "SF Pro **Regular 15** (FLAGGED type), line 20".
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var titleLine: CGFloat = 20
    /// FLAGGED LITERAL — C-121 §2: Detail "SF Pro **Regular 11** (line 14)" (the time column's flag).
    @ScaledMetric(relativeTo: .caption2) private var detailSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var detailLine: CGFloat = 14
    /// FLAGGED LITERAL — C-121 §2: detail glyph 11 pt (OQ-C-121-2).
    @ScaledMetric(relativeTo: .caption2) private var glyphSize: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.metaGap) {
            // §2 Title — "`color-white-100`, one line, tail \"…\"".
            Text(title)
                .font(DesignTextStyle(weight: .regular, size: titleSize, lineHeight: titleLine, tracking: 0).font)
                .foregroundStyle(Token.white100)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: titleLine)
                .ui2Element("Title")

            // §2 Detail line — "when `detail` ≠ nil, `space-meta-gap` (4) below the title: glyph
            // 11 pt (… by `detailKind`, as C-117) + `space-chip-gap` (2) + SF Pro **Regular 11**
            // (line 14) `color-white-50`, one line, tail \"…\"".
            if let detail {
                HStack(alignment: .center, spacing: Token.Space.chipGap) {
                    Image(detailKind.glyph.rawValue, bundle: .ui2Preview)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: glyphSize, height: glyphSize)
                        .ui2Element("Detail glyph")
                    Text(detail)
                        .font(DesignTextStyle(weight: .regular, size: detailSize, lineHeight: detailLine, tracking: 0).font)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .ui2Element("Detail")
                }
                .foregroundStyle(Token.white50)
                .frame(height: detailLine)
                .ui2Element("Detail line")
            }
        }
    }
}

/// §2 Pressed — "system highlight over the row (ephemeral, R-02)".
private struct SystemHighlightStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : Color.clear)
    }
}
