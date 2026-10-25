//
//  ActivityTypeGrid.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-086-activitytypegrid in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  §5 Consumes C-080 ActivityTypeCard ×6 (built; composed directly). Rulings honoured:
//  • OQ-C-086-001 — Creating is `pendingType: ActivityType?` (nil = interactive). When set,
//    the whole grid takes no taps and no VoiceOver activation, and the grid draws that tile at
//    0.6 opacity (OQ-C-080-001's pressed look) by wrapping it. C-080 is unchanged.
//  • OQ-C-086-002 — no `types` prop: always the six cases, in the designed order.
//  • OQ-activity-new-1 / -8 — the six types are closed and every tile is always shown.
//

import SwiftUI

/// C-086 ActivityTypeGrid — the activity-type picker: a two-column grid of C-080 tiles.
///
/// Width-driven, intrinsic height (R-16, §2): two equal columns at
/// (width − `space-element-gap`) ÷ 2, gap `space-element-gap` on both axes. The grid paints
/// nothing of its own — no fill, no stroke, no padding; the page margin is the call site's.
struct ActivityTypeGrid: View {

    /// §4: the closed list of activity types, in the designed tile order (`allCases`).
    /// Nested (R-36) — the grid owns only this picker's presentation copy (§4). The raw value
    /// is the case name, so a fixture names a case as §3 spells it (`bibleVerse`).
    enum ActivityType: String, CaseIterable {
        case bibleVerse, text, video, youtube, write, poll

        /// §2 tile-content table: the C-080 `glyph`.
        var glyph: GlyphName {
            switch self {
            case .bibleVerse: return .cross
            case .text: return .textContent
            case .video: return .videoRecord
            case .youtube: return .youtube
            case .write: return .write
            case .poll: return .poll
            }
        }

        /// §2 tile-content table: the C-080 `title`.
        var title: String {
            switch self {
            case .bibleVerse: return "Bible verse"
            case .text: return "Text"
            case .video: return "Video"
            case .youtube: return "Youtube"
            case .write: return "Write"
            case .poll: return "Poll"
            }
        }

        /// §2 tile-content table: the C-080 `description`.
        var description: String {
            switch self {
            case .bibleVerse: return "Select one or more verses from the Bible for members to read"
            case .text: return "Write your own content for your members to read"
            case .video: return "Record or upload a video for members to watch"
            case .youtube: return "Paste a YouTube link for members to watch in your lesson"
            case .write: return "Give members the opportunity to write their thoughts"
            case .poll: return "Allow members to take a poll on anything you can imagine"
            }
        }
    }

    // C-086 §4's two rows, one parameter each, in the contract's order (R-05).

    /// C-086 §4: `pendingType` — the type whose create is in flight; `nil` = interactive.
    /// Required (R-07: the design shows no default).
    let pendingType: ActivityType?
    /// C-086 §4: `onSelect` — a tile was tapped; the caller creates the activity and sets
    /// `pendingType` (R-03 / R-04). No render effect; a defaulted no-op.
    var onSelect: (ActivityType) -> Void = { _ in }

    var body: some View {
        // §2: row-major, two columns, row gap `space-element-gap` (8). §1 deviation 1: the
        // Figma Row frames are layout, not components.
        VStack(spacing: Token.Space.elementGap) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                // §2: column gap `space-element-gap` (8); equal columns.
                HStack(alignment: .top, spacing: Token.Space.elementGap) {
                    ForEach(row, id: \.self) { type in
                        tile(type)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        // OQ-C-086-001 / §2 Accessibility: while Creating, no taps and every tile reports as
        // not enabled (dimmed trait), so VoiceOver cannot start a second create. C-080's
        // pressed style does not read `isEnabled`, so only the pending tile dims.
        .disabled(pendingType != nil)
        .ui2Element("ActivityTypeGrid")               // capture element map — UI2Element.swift
    }

    /// One C-080 cell at column width; `onTap` → `onSelect(case)` (§5).
    private func tile(_ type: ActivityType) -> some View {
        ActivityTypeCard(
            glyph: type.glyph,
            title: type.title,
            description: type.description,
            onTap: { onSelect(type) }
        )
        .frame(maxWidth: .infinity)
        // §2 Pending tile: "renders at 0.6 opacity … applied by the grid around that tile.
        // No geometry change."
        .opacity(type == pendingType ? Self.pendingOpacity : 1)
        .ui2Element("Tile \(Self.order[type] ?? 0)")
    }

    /// §2: the six cases paired into rows of two, in `allCases` order.
    private static let rows: [[ActivityType]] = stride(from: 0, to: ActivityType.allCases.count, by: 2).map {
        Array(ActivityType.allCases[$0 ..< min($0 + 2, ActivityType.allCases.count)])
    }

    /// The 1-based tile index for each case, for the element map's repeated-item names.
    private static let order: [ActivityType: Int] = Dictionary(
        uniqueKeysWithValues: ActivityType.allCases.enumerated().map { ($1, $0 + 1) }
    )

    /// OQ-C-080-001 / OQ-C-086-001: the ratified pressed look, "0.6 opacity" — a ruling value
    /// multiplying the tile's own paint, not a colour token.
    private static let pendingOpacity: Double = 0.6
}
