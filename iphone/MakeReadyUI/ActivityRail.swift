//
//  ActivityRail.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-133-activity-rail in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-133 ActivityRail — the stitched viewer's five-slot page rail.
///
/// A fixed 23 × 88 pill holding a column of at most five slots: one capsule (the active page)
/// and dots that taper with distance from it. Pure and controlled (R-01): the caller drives every
/// input per frame and owns the rule for `visible` (R-04). Indicator only: touches pass through
/// to the page beneath and pages announce their own position (§2).
struct ActivityRail: View {

    /// C-133 §4 `pageCount` — total pages in the stack, 1 or more.
    let pageCount: Int
    /// C-133 §4 `activePage` — zero-based index of the page covering the viewport's midline.
    let activePage: Int
    /// C-133 §4 `morphProgress` — the capsule's offset from `activePage` in pages, −1...1.
    let morphProgress: Double
    /// C-133 §4 `thumbFraction` — inner scroll over its maximum, 0...1; nil is a solid capsule.
    let thumbFraction: Double?
    /// C-133 §4 `visible` — whether the rail shows; the caller owns the delay rule.
    let visible: Bool

    /// C-133 §2's literal geometry and motion.
    private enum Geometry {
        /// FLAGGED LITERAL — C-133 §2: 23 × 88 pt pill, no token.
        static let pillWidth: CGFloat = 23
        static let pillHeight: CGFloat = 88
        /// FLAGGED LITERAL — C-133 §2: 1 pt stroke of white at 15 %, no token.
        static let strokeWidth: CGFloat = 1
        static let strokeOpacity: Double = 0.15
        /// FLAGGED LITERAL — C-133 §2 deviation 1: a constant 4 pt gap between neighbouring slots.
        static let slotGap: CGFloat = 4
        /// FLAGGED LITERAL — C-133 §2: 4 × 8 pt thumb, no token.
        static let thumbWidth: CGFloat = 4
        static let thumbHeight: CGFloat = 8
        /// FLAGGED LITERAL — C-133 §2, OQ-C-133-5: 2 pt inset, so 16 pt of travel.
        static let thumbInset: CGFloat = 2
        static let thumbTravel: CGFloat = 16
        /// FLAGGED LITERAL — C-133 §2, 01 §8: the three fades, no motion token.
        static let fadeIn: Double = 0.1
        static let fadeOut: Double = 0.3
        static let thumbFadeIn: Double = 0.1
        /// C-133 §2: at most five slots.
        static let maxSlots = 5

        /// FLAGGED LITERAL — C-133 §2: slot size by distance from the capsule. Index 0 is the
        /// 8 × 28 capsule; 1...4 are the 7, 6, 5 and 4 pt dots.
        static let widths: [CGFloat] = [8, 7, 6, 5, 4]
        static let heights: [CGFloat] = [28, 7, 6, 5, 4]
        /// C-133 §2's paint for the same five distances, read from the tokens so the morph can
        /// interpolate between them without restating a value.
        static let opacities: [Double] = [
            Token.white100, Token.white60, Token.white40, Token.white30, Token.white20
        ].map { Double($0.resolve(in: EnvironmentValues()).opacity) }
    }

    /// One slot, placed. `id` is its page index.
    private struct Slot: Identifiable {
        let id: Int
        let centerY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let opacity: Double
        let distance: Double
    }

    /// §2 Out-of-range values: clamped, drawing no state of their own.
    private var clampedCount: Int { max(pageCount, 1) }
    private var clampedActivePage: Int { min(max(activePage, 0), clampedCount - 1) }
    private var clampedMorph: Double { min(max(morphProgress, -1), 1) }

    /// §2 Motion: the thumb shows only at rest, and is gone at once when a morph starts.
    private var thumbShows: Bool { thumbFraction != nil && clampedMorph == 0 }

    /// §2 Window, Morph and Window shift: every slot's place, size and paint from `p`.
    private var slots: [Slot] {
        let position = min(max(Double(clampedActivePage) - clampedMorph, 0), Double(clampedCount - 1))
        let slotCount = min(Geometry.maxSlots, clampedCount)
        let start = min(max(position - 2, 0), Double(clampedCount - slotCount))
        let first = Int(start.rounded(.down))
        let fraction = start - Double(first)
        let drawn = fraction > 0 ? slotCount + 1 : slotCount

        struct Sized {
            let page: Int
            let distance: Double
            let width: CGFloat
            let height: CGFloat
            let weight: Double
        }
        let sized = (0..<drawn).map { index -> Sized in
            let page = first + index
            let distance = abs(Double(page) - position)
            var weight = 1.0
            if fraction > 0, index == 0 { weight = 1 - fraction }
            if fraction > 0, index == drawn - 1 { weight = fraction }
            return Sized(
                page: page,
                distance: distance,
                width: Self.interpolate(Geometry.widths.map(Double.init), at: distance),
                height: Self.interpolate(Geometry.heights.map(Double.init), at: distance),
                weight: weight
            )
        }

        // The leaving and entering slots count toward the column by their weight, so the column
        // stays centred and slides continuously rather than jumping when a sixth slot appears.
        let total = sized.enumerated().reduce(CGFloat.zero) { sum, item in
            let gap = item.offset == sized.count - 1 ? 0 : Geometry.slotGap
            return sum + (item.element.height + gap) * CGFloat(item.element.weight)
        }
        let leading = sized.first.map { (1 - CGFloat($0.weight)) * ($0.height + Geometry.slotGap) } ?? 0
        var top = (Geometry.pillHeight - total) / 2 - leading

        return sized.map { slot in
            defer { top += slot.height + Geometry.slotGap }
            return Slot(
                id: slot.page,
                centerY: top + slot.height / 2,
                width: slot.width,
                height: slot.height,
                opacity: Self.interpolate(Geometry.opacities, at: slot.distance) * slot.weight,
                distance: slot.distance
            )
        }
    }

    /// Reads a by-distance table between its entries; past the last entry holds the last value.
    private static func interpolate(_ table: [Double], at distance: Double) -> Double {
        let clamped = min(max(distance, 0), Double(table.count - 1))
        let lower = Int(clamped.rounded(.down))
        let upper = min(lower + 1, table.count - 1)
        return table[lower] + (table[upper] - table[lower]) * (clamped - Double(lower))
    }

    var body: some View {
        ZStack {
            Capsule(style: .circular)
                .fill(Token.black50)
                .overlay(
                    Capsule(style: .circular).strokeBorder(
                        Token.white100.opacity(Geometry.strokeOpacity),   // FLAGGED LITERAL — C-133 §2: white at 15 %, no token
                        lineWidth: Geometry.strokeWidth
                    )
                )
                .ui2Element("Pill")

            ForEach(slots) { slot in
                slotView(slot)
                    .position(x: Geometry.pillWidth / 2, y: slot.centerY)
            }
        }
        .frame(width: Geometry.pillWidth, height: Geometry.pillHeight)   // §2: fixed; departs from R-16 by contract
        .opacity(visible ? 1 : 0)
        .animation(.linear(duration: visible ? Geometry.fadeIn : Geometry.fadeOut), value: visible)
        .allowsHitTesting(false)                                         // §2: touches pass through
        .accessibilityHidden(true)                                       // §2: pages announce position
        .ui2Element("ActivityRail")
    }

    /// One slot. The slot at the capsule's position, or sharing it mid-morph, reads as the capsule.
    private func slotView(_ slot: Slot) -> some View {
        Capsule(style: .circular)
            .fill(Token.white100.opacity(slot.opacity))
            .frame(width: slot.width, height: slot.height)
            .overlay(alignment: .top) {
                if slot.distance == 0, let thumbFraction {
                    thumb(fraction: thumbFraction)
                }
            }
            .ui2Element(slot.distance <= 0.5 ? "Capsule" : "Dot \(slot.id + 1)")
    }

    /// §2 Thumb: top offset = 2 + fraction × 16. Fades in over 100 ms, leaves at once.
    private func thumb(fraction: Double) -> some View {
        Capsule(style: .circular)
            .fill(Token.black100)
            .frame(width: Geometry.thumbWidth, height: Geometry.thumbHeight)
            .ui2Element("Thumb")                                         // before the offset, so the map follows it
            .offset(y: Geometry.thumbInset + CGFloat(min(max(fraction, 0), 1)) * Geometry.thumbTravel)
            .opacity(thumbShows ? 1 : 0)
            .animation(thumbShows ? .linear(duration: Geometry.thumbFadeIn) : nil, value: thumbShows)
    }
}
