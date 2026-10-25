//
//  AvatarProgressRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-054-avatar-progress-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-054 AvatarProgressRow — "avatar, one-line title, colour-ramped progress line and a
/// caller-supplied chip row".
///
/// A generic display row (OQ-C-054-1, owner ruling 2026-09-26): "No implicit meaning should be
/// built into the component." It knows nothing about groups, enrollments or members — every
/// string is the caller's, and the chips are whatever `metadata` holds.
///
/// Width-driven, intrinsic height (R-16): 88 with chips, 64 without (OQ-C-054-006). No
/// background, no border, no outer padding — those belong to the call site.
struct AvatarProgressRow: View {

    /// One entry of §4 `metadata` — "a C-043 MetaChip's own props (`value`, `label`, `state`,
    /// `labelPosition`), whose value sets C-043 owns". The fields therefore take C-043's own
    /// types rather than restating its sets here (C-043 §4 landed the OQ-C-043-1 rename to
    /// `labelPosition` on 2026-10-24).
    struct Chip {
        let value: String
        var label: String?
        var state: MetaChip.State = .default
        var labelPosition: MetaChip.LabelPosition = .trailing
    }

    /// §4 `title` — "the one-line heading; tail-ellipsized".
    let title: String
    /// §4 `imageURL` — "→ C-038 `imageURL` at size 64". Unrequired: C-038 designs the
    /// empty-avatar look (R-07 call-out).
    var imageURL: URL?
    /// §4 `initials` — "→ C-038 `initials`; both nil → C-038 `Unknown user`". Unrequired, as above.
    var initials: String?
    /// §4 `progress` — "(0…1, clamped) → C-057 `progress`; also selects the progress-text
    /// colour (deviation 4)".
    let progress: Double
    /// §4 `progressLabel` — "pre-formatted by the caller … The row never formats a number or
    /// appends a word".
    let progressLabel: String
    /// §4 `metadata` — "one chip per entry, in order"; required, may be empty (OQ-C-054-006).
    let metadata: [Chip]
    /// §4 `onTap` — "the row's one action". No render effect in a still capture.
    var onTap: () -> Void = {}

    var body: some View {
        // §4 R-17 / OQ-C-054-008: a Button, so the row is one element with the `.isButton`
        // trait and the ruled pressed look (0.6 opacity for the duration of the touch).
        SwiftUI.Button(action: onTap) {
            row
        }
        .buttonStyle(PressedOpacity())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPhrase)
        .accessibilityAddTraits(.isButton)
        .ui2Element("AvatarProgressRow")     // capture element map — UI2Element.swift
    }

    /// §2: "Horizontal row, top-aligned, gap `space-card-padding` (16), content clipped".
    /// OQ-C-054-009 (ruled): the 16pt gaps keep citing `space-card-padding`.
    private var row: some View {
        HStack(alignment: .top, spacing: Token.Space.cardPadding) {
            // §2.1 Avatar: C-038 at size 64; C-038's own chain picks the state (§1 deviation 6:
            // no row-local image treatment).
            Avatar(imageURL: imageURL, initials: initials, size: Self.avatarSize)
            details
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
    }

    /// §2.2 Details column: "fills the remaining width … vertical, gap `space-card-padding` (16)".
    private var details: some View {
        VStack(alignment: .leading, spacing: Token.Space.cardPadding) {
            // §2 Info block: "vertical, gap `space-element-gap` (8)".
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleText
                progressLine
            }
            .ui2Element("Info block")
            // OQ-C-054-006 (ruled): an empty `metadata` omits the chip row AND its 16 gap —
            // the row's height becomes the 64 avatar, with no phantom space.
            if !metadata.isEmpty {
                metadataRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Details")
    }

    /// §2 Title: `type-title-card` (Bold 14/20), `color-text-primary`, "single line, tail
    /// ellipsis, full width". The 20pt line box is pinned: SwiftUI's lineSpacing does nothing
    /// to a single line, so the leading has to be the frame for §2's 88 arithmetic to hold.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.titleCard)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
            .ui2Element("Title")
    }

    /// §2 Progress line: "horizontal, centre-aligned, gap `space-card-padding` (16)"; the label
    /// and the bar are each "flex 1" — they share the width equally.
    private var progressLine: some View {
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            Text(progressLabel)
                .designTextStyle(Token.TypeStyle.pageTitle)
                // §1 deviation 4 / OQ-C-054-2 (ruled): the text takes "exactly the colour C-057
                // computes for its solid fill at that progress" — read from C-057 itself, so the
                // two can never disagree. Figma's fixed `green` text is superseded.
                .foregroundStyle(PercentBar.solidFillColor(progress: progress))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Progress label")
            // §2: C-057 `size: lg` (16), `aligned: Right`, `fillStyle: solid`, `fillColor: nil`
            // (the ramp) and C-057's default thresholds — "No colour, band or threshold prop".
            PercentBar(progress: progress, fillColor: nil, size: .lg, aligned: .right, fillStyle: .solid)
                .frame(maxWidth: .infinity)
        }
        // §2: "20 (progress line; the 16 bar is centred in it)".
        .frame(height: Self.lineBox(Token.TypeStyle.pageTitle))
        .ui2Element("Progress line")
    }

    /// §2 Metadata row: "horizontal, single line, gap `space-chip-gap` (2). One C-043 MetaChip
    /// per `metadata` entry, in order, each at its intrinsic (hug) width."
    private var metadataRow: some View {
        ChipRowLayout(spacing: Token.Space.chipGap) {
            ForEach(Array(metadata.enumerated()), id: \.offset) { index, chip in
                MetaChip(value: chip.value, label: chip.label, state: chip.state, labelPosition: chip.labelPosition)
                    .ui2Element("Chip \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .ui2Element("Metadata row")
    }

    /// §4 R-17: `"\(title), \(progressLabel)"` followed by each chip's phrase in order — a chip
    /// reads its runs in display order, as C-043's own label does.
    private var accessibilityPhrase: String {
        let chips = metadata.map { chip -> String in
            guard let label = chip.label else { return chip.value }
            return chip.labelPosition == .leading ? "\(label) \(chip.value)" : "\(chip.value) \(label)"
        }
        return ([title, progressLabel] + chips).joined(separator: ", ")
    }

    /// §2's stated diameter — a component MEASUREMENT, not a spacing value: the spacing family
    /// has no vocabulary for a part's footprint (the same treatment C-033's 64 avatar gets).
    private static let avatarSize: CGFloat = 64

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}

/// OQ-C-054-008 (ruled): "The whole row at 0.6 opacity for the duration of the touch" —
/// C-059 StudyProgramRow's pressed treatment. No disabled look.
private struct PressedOpacity: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// OQ-C-054-007 (ruled): "Single line, never wrap: chips keep their order, the chip that
/// crosses the trailing edge truncates its value first (C-043's own value-priority
/// truncation), and any chip after it is dropped. The designed 88pt height stays fixed."
///
/// Each chip is placed at its hug width while it fits; the one that crosses the edge is
/// offered only the remaining width (so MetaChip truncates it); every later chip is parked
/// outside the bounds, where the row's clip drops it.
private struct ChipRowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = sizes.map(\.height).max() ?? 0
        let hugWidth = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
        return CGSize(width: proposal.width ?? hugWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var overflowed = false
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let remaining = bounds.maxX - x
            if overflowed || remaining <= 0 {
                subview.place(at: CGPoint(x: bounds.maxX + ideal.width, y: bounds.midY),
                              anchor: .leading, proposal: .unspecified)
                continue
            }
            let width = min(ideal.width, remaining)
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: ideal.height))
            if ideal.width > remaining { overflowed = true }
            x += width + spacing
        }
    }
}
