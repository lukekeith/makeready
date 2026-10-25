//
//  ChecklistStepRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-124-checklist-step-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-124 ChecklistStepRow — "one step of a setup checklist": a C-123 TaskDisc, a title, a
/// description, and a trailing cue — a chevron while the step is to do, a green check once it is
/// done. Tapping the row opens that step's picker; a done row stays tappable.
///
/// Controlled (R-01 / R-02 / R-04): the row never decides which picker opens or whether a step is
/// done — the screen derives `status` and `disc` (R-25). Width-driven (R-16): it fills the width
/// it is given and states its own intrinsic height — 114 at a two-line description
/// (24 + 18 + 8 + 40 + 24), 134 at three — and paints no background and no horizontal padding.
/// The two hairlines are strokes, not layout (§2).
struct ChecklistStepRow: View {

    /// §4 `status` — "`enum Status { case todo, done }` (nested, R-06/R-36). Selects the trailing
    /// cue (§3)."
    enum Status: String {
        case todo
        case done
    }

    /// §4 `disc` — "C-123 TaskDisc content (its §4 content prop) … Passed through to C-123
    /// unchanged." Required.
    let disc: TaskDisc.Look
    /// §4 `title` — required. "Caller-formatted."
    let title: String
    /// §4 `description` — required. "Caller-formatted; wraps."
    let description: String
    /// §4 `status` — required.
    let status: Status
    /// §4 `disabled` — "Dims the row content to 50% and makes the row inert … Only meaningful with
    /// `status == .todo`; ignored when `.done`." R-03's `false` default.
    var disabled: Bool = false
    /// §4 `onTap` — "The row was tapped — the caller opens that step's picker. Never called while
    /// `disabled`." R-03's no-op default.
    var onTap: () -> Void = {}

    /// §3 Disabled: "`disabled` is ignored (treated false) when `status == .done`."
    private var isDisabled: Bool { disabled && status == .todo }

    var body: some View {
        // OQ-C-124-001 (closed): "The system highlight over the whole row, no geometry change; the
        // trailing cue has no separate pressed look" — ephemeral press feedback (R-02).
        SwiftUI.Button(action: onTap) {
            content
        }
        .buttonStyle(SystemHighlightStyle())
        // §3 Disabled: "No tap: no press highlight … `onTap` is never called" and "reported not
        // enabled (SwiftUI `.disabled(true)`), so VoiceOver reads it dimmed".
        .disabled(isDisabled)
        // §2 / R-17: "the whole row is one button: label = \"<title>, <description>\", value
        // \"Done\" / \"Not done\", trait `.isButton`".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(description)")
        .accessibilityValue(status == .done ? "Done" : "Not done")
        .accessibilityAddTraits(.isButton)
        .ui2Element("ChecklistStepRow")         // capture element map — UI2Element.swift
    }

    /// §2 Root: "HStack, centre-aligned, gap 16 (`space-card-padding`); vertical padding
    /// `space-row-gap` (24) top and bottom; horizontal 0."
    private var content: some View {
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            step
            trailingCue
        }
        // §3 Disabled: "disc, title, description and trailing chevron — renders at **50%
        // opacity**, applied once to the whole content group … The top and bottom hairlines are
        // not content and stay at full strength."
        .opacity(isDisabled ? Self.disabledOpacity : 1)
        .padding(.vertical, Token.Space.rowGap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // §2 Hairlines: "1px `color-layout-border` on the top edge, drawn **inside** the box
        // (y 0–1), and on the bottom edge, drawn **outside** it (y 114–115) — strokes, not layout."
        .overlay(alignment: .top) {
            hairline
                .ui2Element("Top hairline")
        }
        .overlay(alignment: .bottom) {
            hairline
                .offset(y: Self.hairlineWidth)
                .ui2Element("Bottom hairline")
        }
    }

    /// §2 Step: "HStack, **top-aligned**, gap 16 (`space-card-padding`)" — the disc pinned to the
    /// top, the text column flexing.
    private var step: some View {
        HStack(alignment: .top, spacing: Token.Space.cardPadding) {
            // §2 Disc: "C-123 TaskDisc, 64×64 … Its content is C-123's contract."
            TaskDisc(look: disc)
                .ui2Element("Disc")
            textColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Step")
    }

    /// §2 Text column: "VStack, leading, gap `space-element-gap` (8)".
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            // §2 Title: "`type-step-title` (SF Pro Text Regular 14/18, −0.1), `color-text-primary`,
            // one line, tail-truncated (Deviation 1)". The 18pt line box is pinned: a single
            // line's lineSpacing does nothing, so the box is framed (the C-037 precedent).
            Text(title)
                .designTextStyle(Token.TypeStyle.stepTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.lineBox(Token.TypeStyle.stepTitle))
                .ui2Element("Title")
            // §2 Description: "`type-step-description` (SF Pro Text Regular 14/20, −0.1),
            // `color-text-secondary`, wraps with **no line limit**". Not `designTextStyle`: its
            // lineSpacing (20 − 14) is added to SF Pro's natural ~16.7 line, a 22.7pt pitch. Spend
            // only the line box less the natural line height — between lines, and half above /
            // half below — so n lines are exactly n × 20 (the C-047 / C-023 construction).
            Text(description)
                .font(Token.TypeStyle.stepDescription.font)
                .tracking(Token.TypeStyle.stepDescription.tracking)
                .lineSpacing(Self.descriptionLeading)
                .padding(.vertical, Self.descriptionLeading / 2)
                .foregroundStyle(Token.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The capture harness measures with a NUMERIC height proposal; `fixedSize` makes
                // the text size to its own lines.
                .fixedSize(horizontal: false, vertical: true)
                .ui2Element("Description")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Text column")
    }

    /// §2 Trailing cue: "24×24, vertically centred on the whole row … Decorative: hidden from
    /// accessibility." Deviation 2: the library glyph painted with a token.
    @ViewBuilder
    private var trailingCue: some View {
        switch status {
        case .todo:
            // §2: "todo → `chevron-right-carbon`, `color-white-20`".
            Glyph(.chevronRightCarbon, size: .md, tint: Token.white20)
                .accessibilityHidden(true)
                .ui2Element("Chevron")
        case .done:
            // §2: "done → `checkmark-carbon`, `color-positive`".
            Glyph(.checkmarkCarbon, size: .md, tint: Token.positive)
                .accessibilityHidden(true)
                .ui2Element("Check")
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(height: Self.hairlineWidth)
            .frame(maxWidth: .infinity)
    }

    // FLAGGED LITERAL — C-124 §2: 1px, the program-wide hairline; no stroke token (OQ-C-124-2).
    private static let hairlineWidth: CGFloat = 1

    // FLAGGED LITERAL — C-124 §3 Disabled: "50% opacity" (owner ruling 2026-10-24); no opacity token.
    private static let disabledOpacity: Double = 0.5

    /// `type-step-description`'s 20pt line box less SF Pro's natural line height.
    private static let descriptionLeading: CGFloat = {
        let style = Token.TypeStyle.stepDescription
        let natural = UIFont.systemFont(ofSize: style.size, weight: .regular).lineHeight
        return max(lineBox(style) - natural, 0)
    }()

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}

/// OQ-C-124-001 — "the system highlight over the whole row (ephemeral, R-02)".
private struct SystemHighlightStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : Color.clear)
    }
}
