//
//  TaskDisc.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-123-task-disc in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-123 TaskDisc — "the 64pt circle that leads an enrollment checklist step: the step's glyph
/// while empty, a summary of the choice once done".
///
/// §2: a 64×64 circle, content clipped to it and centred both ways, in every look. It paints its
/// own ring or fill (part of the look) and adds no outer padding (R-16). Not interactive — the
/// C-124 ChecklistStepRow around it is the tap target — and hidden from accessibility (R-17).
struct TaskDisc: View {

    /// C-123 §4 `TaskDisc.Look` — one case per designed look, each carrying the content that
    /// look renders (R-06, nested per R-36).
    enum Look {
        /// The empty step: a library glyph on the 20% ring.
        case glyph(GlyphName)
        /// ✓ on a green ring.
        case check
        /// The group photo or the program image. Resolved by the caller (R-19).
        case photo(imageURL: URL?)
        /// The start date — pre-formatted strings rendered verbatim; `today` turns the month red.
        case date(weekday: String, month: String, day: String, today: Bool)
        /// The invite time — "7:30", "am", verbatim.
        case time(time: String, period: String)
        /// `syncMode` AUTO.
        case syncOn
        /// `syncMode` OFF.
        case syncOff
        /// `lessonAccess` all-at-once.
        case all
        /// `lessonAccess` one-at-a-time.
        case one
    }

    /// C-123 §4: `look` — selects the §3 row and carries its content. Required (R-07).
    let look: Look

    var body: some View {
        ZStack {
            surface
            content
        }
        .frame(width: Self.diameter, height: Self.diameter)
        // §2: "content clipped to the circle". `radius-circle` is "50%" and emits no member, so
        // the shape names it.
        .clipShape(Circle())
        // §2 (R-17): "hidden from accessibility in every look" — the row already says it.
        .accessibilityHidden(true)
        .ui2Element("TaskDisc")                   // capture element map — UI2Element.swift
    }

    // MARK: - §2 Surface per look

    @ViewBuilder
    private var surface: some View {
        switch look {
        case .glyph:
            ring(Token.white20)
        case .check:
            ring(Token.positive)
        case .photo:
            // §2: no ring — the image is the fill (drawn in `content`).
            EmptyView()
        case .date, .time:
            fill(Token.white10)
        case .syncOn, .syncOff, .all, .one:
            ring(Token.white50)
        }
    }

    /// §2: "rings are a 1pt inside stroke".
    private func ring(_ color: Color) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: Self.hairlineWidth)
            .ui2Element("Ring")
    }

    private func fill(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .ui2Element("Fill")
    }

    // MARK: - §2 Content per look

    @ViewBuilder
    private var content: some View {
        switch look {
        case .glyph(let name):
            // §2: "the library glyph at 44×44, tinted `color-white-50`".
            glyph(name, tint: Token.white50)
        case .check:
            // §2: "glyph `checkmark-carbon` at 44×44, tinted `color-positive`".
            glyph(.checkmarkCarbon, tint: Token.positive)
        case .photo(let imageURL):
            photo(imageURL)
        case let .date(weekday, month, day, today):
            dateStack(weekday: weekday, month: month, day: day, today: today)
        case let .time(time, period):
            // §2: "a vertical stack with no gap, centred: `time` … then `period`".
            VStack(spacing: 0) {
                valueText(time, color: Token.textPrimary)
                    .ui2Element("Time")
                captionText(period)
                    .ui2Element("Period")
            }
        case .syncOn:
            syncStack(value: Self.onLabel, color: Token.positive)
        case .syncOff:
            syncStack(value: Self.offLabel, color: Token.negative)
        case .all:
            // §2: "one centred label, \"all\" … Bold 18/18, `color-amber-500`".
            valueText(Self.allLabel, color: Token.amber500)
                .ui2Element("Value")
        case .one:
            // OQ-C-123-003 (closed): "one" in `color-amber-500`, the same paint as "all".
            valueText(Self.oneLabel, color: Token.amber500)
                .ui2Element("Value")
        }
    }

    /// Drawn from the imageset the way `Glyph` draws a template glyph, because `Glyph` only
    /// offers 16 / 24 / 32 and §2 sizes this one at 44 (the C-038 Avatar precedent).
    private func glyph(_ name: GlyphName, tint: Color) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .foregroundStyle(tint)
            .ui2Element("Glyph")
    }

    @ViewBuilder
    private func photo(_ imageURL: URL?) -> some View {
        if let url = imageURL {
            // Cache-first: a snapshot renders in one synchronous layout pass, so an `AsyncImage`
            // alone comes out empty in a capture (Ui2ImageCache.swift).
            if let cached = Ui2ImageCache.shared.image(for: url) {
                // §2: "the image fills the 64pt circle edge to edge", aspect-fill.
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
                    .ui2Element("Photo")
            } else {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .ui2Element("Photo")
                } placeholder: {
                    unresolvedPhoto
                }
            }
        } else {
            unresolvedPhoto
        }
    }

    /// OQ-C-123-001 (closed): "an unresolved photo renders the `color-white-10` filled disc with
    /// nothing on it" — nil or not yet loaded.
    private var unresolvedPhoto: some View {
        fill(Token.white10)
    }

    /// §2 `date`: "a vertical stack with gap `space-meta-gap` (4), centred".
    private func dateStack(weekday: String, month: String, day: String, today: Bool) -> some View {
        VStack(spacing: Token.Space.metaGap) {
            // §2: "Label row, 18pt tall, contents bottom-aligned and horizontally centred,
            // horizontal inset `space-element-gap` (8)"; weekday then month, gap `space-chip-gap`.
            HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
                Text(weekday)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    .foregroundColor(Token.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .ui2Element("Weekday")
                Text(month)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    // §2: `color-negative` when `today`; OQ-C-123-002 (closed): any other day's
                    // month is `color-text-secondary`, like the weekday beside it.
                    .foregroundColor(today ? Token.negative : Token.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .ui2Element("Month")
            }
            .padding(.horizontal, Token.Space.elementGap)
            .frame(height: Self.valueLineBox, alignment: .bottom)
            .ui2Element("Label row")
            valueText(day, color: Token.textPrimary)
                .ui2Element("Day")
        }
    }

    /// §2 `syncOn` / `syncOff`: "a vertical stack with no gap, centred: the fixed label \"SYNC\"
    /// … then \"on\" (`color-positive`) or \"off\" (`color-negative`), Bold 18/18".
    private func syncStack(value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            captionText(Self.syncLabel)
                .ui2Element("Label")
            valueText(value, color: color)
                .ui2Element("Value")
        }
    }

    /// The Bold 18/18 value run in its 18pt line box. Framed explicitly: SwiftUI has no
    /// line-height, so a single run otherwise sits in its own font box (the C-070 precedent).
    private func valueText(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(Self.valueStyle)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .frame(height: Self.valueLineBox)
    }

    /// §2: a `type-caption-bold` `color-text-secondary` run with inset 8 ("am", "SYNC").
    private func captionText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.captionBold)
            .foregroundColor(Token.textSecondary)
            .lineLimit(1)
            .fixedSize()
            .frame(height: Self.captionLineBox)
            .padding(.horizontal, Token.Space.elementGap)
    }

    // §2: "SYNC" / "on" / "off" / "all" / "one" are owned labels, not props (§4), rendered
    // verbatim with no case transform.
    private static let syncLabel = "SYNC"
    private static let onLabel = "on"
    private static let offLabel = "off"
    private static let allLabel = "all"
    private static let oneLabel = "one"

    // FLAGGED LITERAL — C-123 §2: "the disc states its own 64×64 size (flagged literal 64 —
    // every designed instance is 64pt and no size token exists)".
    private static let diameter: CGFloat = 64
    // FLAGGED LITERAL — C-123 §2: "the library glyph at 44×44 (flagged literal 44, designed in
    // 4670:43239 / 4673:44076)".
    private static let glyphSize: CGFloat = 44
    // FLAGGED LITERAL — C-123 §2: "rings are a 1pt inside stroke — a hairline literal, as
    // elsewhere in the program".
    private static let hairlineWidth: CGFloat = 1

    // `type-caption-bold`'s designed 12pt line box.
    private static let captionLineBox: CGFloat =
        Token.TypeStyle.captionBold.lineHeight ?? Token.TypeStyle.captionBold.size
    // §2: the 18pt line box of the Bold 18/18 value runs (and the date's 18pt label row).
    private static let valueLineBox: CGFloat = valueStyle.lineHeight ?? valueStyle.size

    // FLAGGED LITERAL — C-123 §2: "Bold 18 / 18. The only Bold 18 token is `type-value-emphasis`
    // 18/24, and this disc designs 18/18 — the same value C-070 DateBlock carries. Minting a
    // token for it is open as OQ-C-070-1 … The build renders 18/18 either way."
    private static let valueStyle = DesignTextStyle(
        weight: .bold, size: 18, lineHeight: 18, tracking: 0
    )
}
