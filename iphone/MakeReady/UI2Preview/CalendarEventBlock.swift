//
//  CalendarEventBlock.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-117-calendar-event-block in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-117 CalendarEventBlock — "one timed event drawn on the day timeline at its start and
/// duration".
///
/// §2: "The block **fills the frame its parent gives** (width and height): C-120 places it at
/// x 66 → trailing − 2, y = start, height = duration × 50 pt/h, min **20** … Clipped to its
/// shape." Position, height and overlap width are the parent's; the block never sees times.
struct CalendarEventBlock: View {

    // MARK: - Vocabulary

    /// §4 `CalendarEventBlock.DetailKind` — "picks the detail glyph (`map-pin` / `video-record`
    /// / `users`). **Owned here**; C-121 cites it". Raw values are the §4 case names, which are
    /// what the fixture sends.
    enum DetailKind: String, CaseIterable {
        case location
        case online
        case group

        /// §2 Detail line: "location → `map-pin`, online → `video-record`, group → `users`
        /// (OQ-C-117-002)".
        var glyph: GlyphName {
            switch self {
            case .location: .mapPin
            case .online: .videoRecord
            case .group: .users
            }
        }
    }

    // MARK: - Props (§4, in the contract's order — R-05)

    /// §4 `title` — "the event title".
    let title: String
    /// §4 `detail` — "the second line — location name, online source / link host, or group
    /// name, caller-formatted; nil = no line". Unrequired (R-07 call-out).
    var detail: String? = nil
    /// §4 `detailKind` — picks the detail glyph.
    let detailKind: DetailKind
    /// §4 `eventType` — "`C-112 EventType` … fill / bar / tint colour (02-design §8). Value set
    /// owned by C-112".
    let eventType: EventIndicator.EventType
    /// §4 `recurring` — "draws `repeat-arrows` top-right".
    let recurring: Bool
    /// §4 `timeRangeText` — "the spoken time range (\"1 PM to 2 PM\"), used only in the
    /// accessibility label — the block draws no times".
    let timeRangeText: String
    /// §4 `onTap` — "open the event (D7: no-op in the preview)". Unrequired (R-07 call-out).
    var onTap: () -> Void = {}

    // MARK: - Body

    var body: some View {
        // `SwiftUI.Button`: the module's own C-105 `Button` shadows SwiftUI's.
        SwiftUI.Button(action: onTap) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    // §2 Fill — "`eventType` token at opacity **0.25** … corner `radius-card-sm`".
                    shape.fill(eventType.color.opacity(Geometry.fillOpacity))
                        .ui2Element("Fill")

                    // §2 Left bar — "**3** wide, inset 3 from leading/top/bottom (height =
                    // block − 6), solid `eventType` token, radius 1.5".
                    RoundedRectangle(cornerRadius: Geometry.barRadius)
                        .fill(eventType.color)
                        .frame(width: Geometry.barWidth)
                        .padding([.leading, .top, .bottom], Geometry.barInset)
                        .ui2Element("Left bar")

                    content(showsDetail: detail != nil && proxy.size.height >= Geometry.detailMinHeight)
                }
            }
            .clipShape(shape)                                    // §2: "Clipped to its shape."
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        // §2 Accessibility (R-17): "one button, label \"<title>, <timeRangeText>[, <detail>]\" …
        // \"repeats\" appended when `recurring`."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .ui2Element("CalendarEventBlock")
    }

    /// The title row and, when it shows, the detail line — inset 11 leading, `space-chip-gap`
    /// top.
    private func content(showsDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Geometry.titleToRepeat) {
                // §2 Title — "Semibold 13 … one line, tail \"…\"".
                Text(title)
                    .designTextStyle(Self.titleStyle)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ui2Element("Title")

                // §2 Repeat glyph — "when `recurring`: `repeat-arrows`, 10 pt, same tint …
                // centred on the title line; the title stops 4 pt before it".
                if recurring {
                    glyph(.repeatArrows)
                        .ui2Element("Repeat glyph")
                }
            }

            if showsDetail, let detail {
                // §2 Detail line — "leading glyph (10 pt) + gap `space-chip-gap` (2) + text SF
                // Pro **Regular 11**, same tint at opacity 0.8 … Wraps onto as many lines as the
                // height holds, the last visible line tail-truncated (OQ-C-117-001)".
                HStack(alignment: .top, spacing: Token.Space.chipGap) {
                    glyph(detailKind.glyph)
                        // Centred on the first line: the glyph sits in a box one detail line tall.
                        .frame(height: Self.detailLineHeight)
                        .ui2Element("Detail glyph")
                    Text(detail)
                        .designTextStyle(Self.detailStyle)
                        .foregroundStyle(tint)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .ui2Element("Detail")
                }
                .opacity(Geometry.detailOpacity)
                .ui2Element("Detail line")
            }
        }
        .padding(.leading, Geometry.contentLeading)
        .padding(.top, Token.Space.chipGap)
        // A trailing inset of 6 on a non-recurring block too — the repeat glyph's inset, which
        // §2 states as the block's trailing edge (it names no other).
        .padding(.trailing, Geometry.trailingInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func glyph(_ name: GlyphName) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Geometry.glyph, height: Geometry.glyph)
            .foregroundStyle(tint)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Token.Radius.cardSm)      // §2: corner `radius-card-sm` (4)
    }

    private var accessibilityText: String {
        var parts = [title, timeRangeText]
        if let detail { parts.append(detail) }
        if recurring { parts.append("repeats") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Colour

    /// FLAGGED LITERAL — C-117 §2: text colour = "`mix(eventType token, white, 0.55)` (FLAGGED
    /// LITERAL formula)". Read back out of the C-112 token, so it cannot drift from it.
    private var tint: Color {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(eventType.color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = Geometry.whiteMix
        return Color(red: r + (1 - r) * t, green: g + (1 - g) * t, blue: b + (1 - b) * t)
    }

    // MARK: - Type

    /// FLAGGED LITERAL — C-117 §2: Title "SF Pro **Semibold 13** (FLAGGED LITERAL type)".
    private static let titleStyle = DesignTextStyle(weight: .semibold, size: 13, lineHeight: nil, tracking: 0)

    /// FLAGGED LITERAL — C-117 §2: Detail "SF Pro **Regular 11**" (same flag as the title).
    private static let detailStyle = DesignTextStyle(weight: .regular, size: 11, lineHeight: nil, tracking: 0)

    /// One detail line's height, derived from `detailStyle` (no new value).
    private static let detailLineHeight = UIFont.systemFont(ofSize: detailStyle.size).lineHeight

    // MARK: - Geometry

    private enum Geometry {
        static let fillOpacity: Double = 0.25                    // FLAGGED LITERAL — C-117 §2: fill opacity 0.25
        static let barWidth: CGFloat = 3                         // FLAGGED LITERAL — C-117 §2: bar 3 wide
        static let barInset: CGFloat = 3                         // FLAGGED LITERAL — C-117 §2: bar inset 3
        static let barRadius: CGFloat = 1.5                      // FLAGGED LITERAL — C-117 §2: bar radius 1.5
        static let contentLeading: CGFloat = 11                  // FLAGGED LITERAL — C-117 §2: title leading inset 11 (bar 6 + 5)
        static let trailingInset: CGFloat = 6                    // FLAGGED LITERAL — C-117 §2: repeat glyph trailing inset 6
        static let titleToRepeat: CGFloat = 4                    // FLAGGED LITERAL — C-117 §2: title stops 4 pt before the repeat glyph
        static let glyph: CGFloat = 10                           // FLAGGED LITERAL — C-117 §2: detail + repeat glyphs 10 pt
        static let detailMinHeight: CGFloat = 34                 // FLAGGED LITERAL — C-117 §2: detail shown only at height ≥ 34
        static let detailOpacity: Double = 0.8                   // FLAGGED LITERAL — C-117 §2: detail tint at opacity 0.8
        static let whiteMix: CGFloat = 0.55                      // FLAGGED LITERAL — C-117 §2: mix toward white 0.55
    }
}

/// §2 Pressed — "whole block opacity **0.6** while touched (ephemeral, R-02)".
private struct PressDimStyle: ButtonStyle {
    private static let pressedOpacity: Double = 0.6              // FLAGGED LITERAL — C-117 §2: pressed opacity 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }
}
