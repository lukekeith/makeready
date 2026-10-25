//
//  AISuggestionsBlock.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-051-aisuggestions-block in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-051 AISuggestionsBlock — the AI-suggestions region under a single-field editor.
///
/// §2: "A vertical block, full container width (deviation 1) … it fills the width it is
/// given, states its own intrinsic height, paints **no background** … and adds **no outer
/// padding** — the consumer owns the `space-page-margin` inset". Exactly one of four
/// bodies renders, selected by `state`.
///
/// §3: "`state` is a **prop the consumer drives**; the block renders it and raises
/// `onGenerate` / `onPick` — it never transitions itself" (R-01 / R-02).
///
/// Chrome-free: the ViewRegistry call site supplies the master width, the outer margin
/// and the ground.
struct AISuggestionsBlock: View {

    /// C-051 §4 `state` — "nested enum `AISuggestionsBlock.State { case prompt, generating,
    /// list, regenerating }`" (R-06, R-36). Raw values are the §3 labels, which are also the
    /// fixture's prop values.
    enum State: String {
        case prompt, generating, list, regenerating
    }

    /// C-051 §4 `state` — "which body renders (§3) … **Required**".
    let state: State
    /// C-051 §4 `promptCopy` — "the `prompt` paragraph — per-field copy (deviation 2) …
    /// **Required** — the design shows two different strings (name / description)".
    let promptCopy: String
    /// C-051 §4 `suggestions` — "the rows' titles in order, rendered in `list` **and**
    /// `regenerating`; ≤ 3, the block renders `prefix(3)` (OQ-3 ruled) … **Required**; the
    /// caller passes `[]` in `prompt` / `generating`, where it is ignored".
    let suggestions: [String]
    /// C-051 §4 `onGenerate` — "raised by **both** links — “AI suggestions” in `prompt` and
    /// “Try again” in `list`; `regenerating` shows no link". No render effect; a defaulted
    /// no-op so the promoted view keeps its real signature (R-03).
    var onGenerate: () -> Void = {}
    /// C-051 §4 `onPick` — "raised with the chosen title when a C-050 row's `onAdd` fires
    /// (through C-078)". OQ-C-051-6 (ruled 2026-09-20): the block stays in `list` afterwards.
    /// OQ-C-051-10 (ruled 2026-09-20): rows stay pickable while `regenerating`. No-op
    /// default (R-03).
    var onPick: (String) -> Void = { _ in }

    var body: some View {
        // OQ-C-051-4 (ruled 2026-09-20): "instant swap, page reflows, no crossfade" — a plain
        // switch with no transition, so a state change is a re-layout and nothing else.
        Group {
            switch state {
            case .prompt:
                promptBody
            case .generating:
                // §2 `generating`: "one horizontal row `Processing` … **no vertical padding**
                // … Height 24."
                processingRow
            case .list:
                // §2 `list`: "vertical stack, gap 0, full width" — header + rows.
                VStack(spacing: 0) {
                    listHeader
                    suggestionRows
                }
            case .regenerating:
                // §2 `regenerating` (`4363:40478`): "vertical stack, gap 0, full width" —
                // the padded status row over "C-078 SuggestionRows exactly as in `list`".
                VStack(spacing: 0) {
                    processingRow
                        // §2: "**Padded status row** (`4363:40479`): vertical padding **16**
                        // (the same flagged literal as the `list` header), horizontal 0 …
                        // Height 56 = 16 + 24 + 16". The row is leaf content of this block,
                        // "not a C-020 variant".
                        .padding(.vertical, Self.rowPadding)
                        .ui2Element("Padded status row")
                    suggestionRows
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)   // §2: fills the width it is given
        .ui2Element("AISuggestionsBlock")                   // capture element map — UI2Element.swift
    }

    // MARK: - `prompt`

    /// §2 `prompt`: "vertical stack, gap `space-element-gap` (8), items leading" — the
    /// paragraph and the C-049 link. "Height 92.5 at the sample" (deviation 3: follows the copy).
    private var promptBody: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(promptCopy)
                // §2: "**Prompt paragraph** (`3771:6807`): `type-page-title` (SF Pro Regular
                // 14/20), `color-text-secondary`, full width, word-wrapping, 20 × lines tall".
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textSecondary)
                // A MINIMUM, not a fixed box: the designed 20pt line box is larger than SF
                // Pro's natural ~16.7 at 14pt, and the paragraph wraps (deviation 3).
                .frame(maxWidth: .infinity, minHeight: Self.lineBox(Token.TypeStyle.pageTitle), alignment: .leading)
                // `fixedSize` OUTSIDE the min-height frame — the capture harness proposes a
                // numeric 0 height, which a `minHeight` frame would clamp without asking the
                // text (C-047 RadioOptionRow measured it). Out here the frame sizes to the text.
                .fixedSize(horizontal: false, vertical: true)
                .ui2Element("Prompt paragraph")
            // §2: "**C-049 LinkButton**, label **“AI suggestions”**, its own geometry
            // (102×24.5 at this label), leading-aligned." §4: raises `onGenerate`.
            LinkButton(label: Self.generateLabel, onTap: onGenerate)
        }
    }

    // MARK: - `Processing` row (leaf content, `generating` + `regenerating`)

    /// §2 `generating`: "one horizontal row `Processing` (`3860:8330`), items top-aligned, gap
    /// **16** (flagged literal — the same step C-050 carries), full width, **no vertical
    /// padding**" — the C-076 spinner and the status label. Height 24.
    private var processingRow: some View {
        HStack(alignment: .top, spacing: Self.processingGap) {
            // §2: "**C-076 ActivitySpinner** 24×24, does not shrink."
            activitySpinner
                .fixedSize()
            Text(Self.generatingLabel)
                // §2: "**Status label** (`3860:8332`): **“Generating suggestions”** —
                // `type-label-emphasis` (SF Pro Semibold 14/24; the alias OQ-C-051-7 ruled),
                // `color-text-secondary`, single line, no wrap."
                .designTextStyle(Token.TypeStyle.labelEmphasis)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                // A FIXED 24pt box: SwiftUI has no line-height, and a single run would
                // otherwise sit in its ~17pt font box (C-049's construction).
                .frame(height: Self.lineBox(Token.TypeStyle.labelEmphasis))
                .ui2Element("Status label")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2 Accessibility (R-17): "The `Processing` row … is exposed as **one** accessibility
        // element labelled “Generating suggestions”, the spinner decorative inside it."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.generatingLabel)
        .ui2Element("Processing")
    }

    // MARK: - `list` header (C-020 SectionHeader stand-in)

    /// §2 `list`: "**Header: C-020 SectionHeader** (`3860:8342`) in the title-plus-link variant
    /// … horizontal, space-between, items centred, vertical padding **16** (flagged literal, as
    /// C-050's), horizontal 0. Leading title … `type-block-label` (SF Pro Regular 14/16),
    /// `color-text-secondary`; trailing **C-049 LinkButton** label **“Try again”** (64×24.5).
    /// Row height 56.5 = 16 + 24.5 + 16."
    ///
    /// STUB — C-020, no prop-level contract. C-020 has no contract of its own yet, and §5 says
    /// "the variant this block needs does not exist on it yet … `/d2m-component C-020` is where
    /// that variant gets written; §2's `list` header geometry is the target it must hit". This
    /// is the disclosed inline stand-in (R-15), built to §2's geometry so the `list` state can
    /// be diffed; it is replaced by the real C-020 once that variant is specced and built.
    private var listHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(Self.headerTitle)
                .designTextStyle(Token.TypeStyle.blockLabel)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                // §1 drift check: "label `8343` 99×16 at y 20.25" — a fixed 16pt line box,
                // centred against the 24.5pt link (16 + (24.5 − 16) / 2 = 20.25).
                .frame(height: Self.lineBox(Token.TypeStyle.blockLabel))
                .ui2Element("Title")
            Spacer(minLength: 0)
            // §4: "raised by **both** links — … “Try again” in `list`".
            LinkButton(label: Self.tryAgainLabel, onTap: onGenerate)
        }
        .padding(.vertical, Self.rowPadding)
        .ui2Element("SectionHeader")
    }

    // MARK: - rows (C-078 SuggestionRows stand-in)

    /// §2: "**C-078 SuggestionRows** — the whole region below the header … n ≤ 3 **C-050
    /// SuggestionRow**s (56 each at one title line) stacked with gap 0, each **topped** by a
    /// 1px `color-layout-border` hairline drawn as a 0-height vector centred on the boundary
    /// (inset −0.5) — header↔row 1, row 1↔row 2, row 2↔row 3 — and **none below the last
    /// row**." Owner's drawing note (§5): "the line is not part of the SuggestionRow, it's a
    /// divider this component produces".
    ///
    /// STUB — C-078, no prop-level contract. C-078 was minted 2026-09-20 and is unspecced
    /// (`/d2m-component C-078`); this is the disclosed inline stand-in (R-15), built to §2's
    /// geometry. Its own props are C-078's spec to write — "this block's `suggestions` and
    /// `onPick` are what it will be handed".
    private var suggestionRows: some View {
        VStack(spacing: 0) {
            // OQ-C-051-3 (ruled 2026-09-20): "3 is a hard cap; the block renders
            // suggestions.prefix(3)".
            ForEach(Array(suggestions.prefix(Self.rowCap).enumerated()), id: \.offset) { index, title in
                suggestionRow(title: title)
                    // Centred ON the boundary, occupying no layout height — the hairline is a
                    // top overlay on the row it precedes, offset by half its width so it
                    // straddles the edge exactly as Figma's centre-aligned 1px stroke does
                    // (the same construction C-066 ActionMenuOverlay measured).
                    .overlay(alignment: .top) {
                        hairline.ui2Element("Hairline \(index + 1)")
                    }
                    .ui2Element("Row \(index + 1)")
            }
        }
        .ui2Element("SuggestionRows")
    }

    /// §2: "a 1px `color-layout-border` hairline drawn as a 0-height vector centred on the
    /// boundary (inset −0.5)".
    private var hairline: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(height: Self.hairlineWidth)
            .offset(y: -Self.hairlineWidth / 2)
    }

    /// One C-050 SuggestionRow, built from C-050's own contract — the level-1 dependency
    /// reached "**through C-078**, not a direct edge" (§5). C-050 §2: "A horizontal row:
    /// **title** (leading, flexible) + **C-021 GlyphButton `add`** (trailing, fixed) … items
    /// centred vertically … Vertical padding **16** top and bottom; horizontal padding **0**
    /// … Gap title↔glyph **16** … **Height:** **56** at one title line (16 + 24 + 16); each
    /// additional wrapped line adds 24."
    ///
    /// Inline private stand-in for C-050 (R-15's disclosed fallback): C-050 is specced but
    /// unbuilt, and it is not a direct edge of this row — it is C-078's, and C-078 has no
    /// contract to build it under. Replaced by the real C-050 when C-078 is specced and built.
    private func suggestionRow(title: String) -> some View {
        HStack(alignment: .center, spacing: Self.rowGap) {
            Text(title)
                // C-050 §2: "**Title** (`3526:30717`): `type-input` — SF Pro Regular 14/24 …
                // colour `color-text-primary`. Flexible … word-wrapping, no line limit"
                // (OQ-C-050-2 ruled 2026-09-19: wraps, +24 per line, no cap).
                .designTextStyle(Token.TypeStyle.input)
                .foregroundStyle(Token.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Self.lineBox(Token.TypeStyle.input), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .ui2Element("Title")
            // C-050 §2: "**Add glyph:** C-021 GlyphButton, `glyph = add` … 24×24, does not
            // shrink, tint `color-accent`". C-050 §4: `onAdd` "forwarded to C-021 `action`".
            GlyphButton(glyph: .add) { onPick(title) }
                .fixedSize()
        }
        .padding(.vertical, Self.rowPadding)
        // OQ-C-050-1 (ruled 2026-09-17): "the whole row is the tap target and invokes onAdd;
        // the glyph is the affordance, not the only hit area."
        .contentShape(Rectangle())
        .onTapGesture { onPick(title) }
        // R-17: the row is the interactive element (OQ-C-050-1), so it carries the label and
        // the button trait; the glyph inside is the affordance, not a second control.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .ui2Element("SuggestionRow")
    }

    // MARK: - spinner (C-076 ActivitySpinner stand-in)

    /// STUB — C-076, no prop-level contract. The registry row (level 3) reads: "24pt ring, 2pt
    /// `color-white-10` track + `color-accent` angular-gradient arc (100%→0 over ~125°, masked
    /// to ~7/8 turn). Static in Figma — rotation is undesigned". Drawn to that description at
    /// the §2 slot size only; `/d2m-component C-076` is where its contract gets written, and
    /// this stand-in is replaced by the real C-076 once it is built.
    private var activitySpinner: some View {
        ZStack {
            Circle()
                .stroke(Token.white10, lineWidth: Self.spinnerStroke)
            Circle()
                .trim(from: 0, to: Self.spinnerArc)
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: Token.accent, location: 0),
                            .init(color: Token.accent.opacity(0), location: Self.spinnerFade),
                            .init(color: Token.accent.opacity(0), location: 1)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: Self.spinnerStroke, lineCap: .round)
                )
                // The Figma "Donut" puts the arc's solid end at the bottom-left; `Circle`
                // starts its trim at 3 o'clock, so the whole gradient turns to meet it.
                .rotationEffect(.degrees(Self.spinnerStart))
        }
        .frame(width: Self.spinnerSize, height: Self.spinnerSize)
        .accessibilityHidden(true)                          // §2: "the spinner decorative"
        .ui2Element("ActivitySpinner")
    }

    // MARK: - fixed chrome strings (§4 "Fixed, not props")

    /// §4: "“AI suggestions” for both the link and, per deviation 5, the header title".
    private static let generateLabel = "AI suggestions"
    /// Deviation 5 / OQ-C-051-5 (ruled 2026-09-20): "unify on “AI suggestions” (sentence
    /// case)" — Figma `3860:8343` still reads “AI Suggestions” until it is edited.
    private static let headerTitle = "AI suggestions"
    /// §2: "**“Generating suggestions”**".
    private static let generatingLabel = "Generating suggestions"
    /// §2: "**“Try again”**".
    private static let tryAgainLabel = "Try again"

    // MARK: - geometry

    /// OQ-C-051-3 (ruled 2026-09-20): "3 is a hard cap".
    private static let rowCap = 3

    // FLAGGED LITERAL — C-051 §2: "gap **16** (flagged literal — the same step C-050 carries)"
    // — the `Processing` row's spinner↔label gap.
    private static let processingGap: CGFloat = 16
    // FLAGGED LITERAL — C-051 §2: "vertical padding **16** (flagged literal, as C-050's)" — the
    // `list` header's and the `regenerating` status row's vertical padding; C-050 §2's own
    // "Vertical padding **16** top and bottom" is the same flagged literal on the row.
    private static let rowPadding: CGFloat = 16
    // FLAGGED LITERAL — C-050 §2: "Gap title↔glyph **16**" (one of C-050's "two flagged
    // literals: the 16pt padding and gap").
    private static let rowGap: CGFloat = 16
    /// §2: "a 1px `color-layout-border` hairline".
    private static let hairlineWidth: CGFloat = 1

    /// §2: "**C-076 ActivitySpinner** 24×24".
    private static let spinnerSize: CGFloat = 24
    // STUB — C-076, no prop-level contract: the registry row's "2pt … track", "~7/8 turn" arc
    // and "100%→0 over ~125°" fade, as read from that row rather than a contract line.
    private static let spinnerStroke: CGFloat = 2
    private static let spinnerArc: CGFloat = 0.875
    private static let spinnerFade: CGFloat = 125.0 / 360.0
    private static let spinnerStart: Double = 135

    /// The designed line box of a type token: SwiftUI has no line-height, so the box has to
    /// be spelled as a frame.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
