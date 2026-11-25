//
//  AISuggestionsBlock.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-051-aisuggestions-block in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-051 AISuggestionsBlock — the AI-suggestions region under the edit screens' fields.
///
/// §2: "A vertical block, full container width (deviation 1) … it fills the width it is given,
/// states its own intrinsic height, paints **no background** and adds **no outer padding**. …
/// Exactly one of five bodies renders, selected by `state`." The block raises callbacks and
/// never transitions itself (§3, R-01 / R-02).
struct AISuggestionsBlock: View {

    /// C-051 §4 `state` — nested enum (R-06, R-36). "Raw values are the case names."
    enum State: String {
        case prompt, generating, list, regenerating, empty
    }

    /// C-051 §4: `state` — "which body renders (§3); the consumer owns it". Required.
    let state: State
    /// C-051 §4: `promptCopy` — "the paragraph drawn in `prompt` **and** `empty`
    /// (OQ-C-051-11); ignored elsewhere". Required.
    let promptCopy: String
    /// C-051 §4: `suggestions` — "title-only rows in order, drawn in `list` and
    /// `regenerating`, `prefix(3)`. Ignored when `pairs` is not empty." Required.
    let suggestions: [String]
    /// C-051 §4: `pairs` — "title and description pairs in order, drawn in `list` and
    /// `regenerating`, `prefix(3)`; when not empty they replace `suggestions`". Defaulted, so
    /// existing callers are unchanged (§4 R-07 note).
    var pairs: [SuggestionRows.Pair] = []
    /// C-051 §4: `onGenerate` — "raised by both links: "AI suggestions" in `prompt`, "Try
    /// again" in `list`". No-op default (R-03).
    var onGenerate: () -> Void = {}
    /// C-051 §4: `onPick` — "raised with the picked row's title". No-op default (R-03).
    var onPick: (String) -> Void = { _ in }
    /// C-051 §4: `onPickIndex` — "raised with the picked row's zero-based index, for title rows
    /// and pair rows alike. One pick raises both". No-op default (R-03).
    var onPickIndex: (Int) -> Void = { _ in }

    var body: some View {
        // OQ-C-051-4: "instant swap, the page reflows" — a plain switch with no transition.
        Group {
            switch state {
            case .prompt:
                // §2 `prompt`: "vertical stack, gap `space-element-gap` (8), items leading".
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    paragraph
                    LinkButton(label: Self.generateLabel, onTap: onGenerate)
                }
            case .generating:
                // §2 `generating`: "**C-160 AIProcessing**, no padding. Height 24."
                AIProcessing()
            case .list:
                // §2 `list`: "vertical stack, gap 0".
                VStack(spacing: 0) {
                    header
                    rows
                }
            case .regenerating:
                // §2 `regenerating`: "vertical stack, gap 0 … **C-160 AIProcessing** inside 16pt
                // vertical padding (`space-step-16`, this block's own) … No title, no link."
                VStack(spacing: 0) {
                    AIProcessing()
                        .padding(.vertical, Token.Space.step16)
                        .ui2Element("Padded status row")
                    rows
                }
            case .empty:
                // §2 `empty` (OQ-C-051-12): "the `prompt` paragraph alone … **No link and no
                // reserved link space.** Height 20n."
                paragraph
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("AISuggestionsBlock")                         // capture element map — UI2Element.swift
    }

    /// §2: "**Prompt paragraph** (`3771:6807`), `promptCopy`: `type-page-title` (Regular 14/20),
    /// `color-text-secondary`, full width, leading, word-wrapping, 20 per line."
    private var paragraph: some View {
        Text(promptCopy)
            .designTextStyle(Token.TypeStyle.pageTitle)
            .foregroundStyle(Token.textSecondary)
            // A MINIMUM, not a fixed box: one line is the designed 20pt, and the copy wraps.
            // `fixedSize` sits OUTSIDE it — the capture harness proposes a 0 height, which a
            // `minHeight` frame would clamp without asking the text (C-047 measured it).
            .frame(maxWidth: .infinity, minHeight: Self.lineBox(Token.TypeStyle.pageTitle), alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .ui2Element("Prompt paragraph")
    }

    /// §2 `list`: "**C-020 SectionHeader** `title` "AI suggestions" (deviation 5), `style:
    /// .block`, `accessory: .link(label: "Try again", style: default)`, inside **16pt vertical
    /// padding (`space-step-16`) that is this block's own** (OQ-C-020-001), horizontal 0."
    private var header: some View {
        SectionHeader(
            title: Self.headerTitle,
            style: .block,
            accessory: .link(label: Self.tryAgainLabel, style: .default),
            onAccessoryTap: onGenerate
        )
        .padding(.vertical, Token.Space.step16)
        .ui2Element("Header")
    }

    /// §4 "Passed to C-078": "`suggestions` → `prefix(3)`, `pairs` → `prefix(3)`, `onPick`,
    /// `onPickIndex`." The prefix keeps an index the caller's own. OQ-C-051-10: rows stay
    /// pickable while `regenerating`.
    private var rows: some View {
        SuggestionRows(
            suggestions: Array(suggestions.prefix(Self.rowCap)),
            pairs: Array(pairs.prefix(Self.rowCap)),
            onPick: onPick,
            onPickIndex: onPickIndex
        )
    }

    // MARK: - fixed chrome (§4 "Fixed, not props")

    private static let generateLabel = "AI suggestions"
    /// Deviation 5 / OQ-C-051-5: "unify on "AI suggestions" (sentence case)".
    private static let headerTitle = "AI suggestions"
    private static let tryAgainLabel = "Try again"

    /// OQ-C-051-3: "3 is a hard cap".
    private static let rowCap = 3

    /// The designed line box of a text style — its leading, or its size when none is designed.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
