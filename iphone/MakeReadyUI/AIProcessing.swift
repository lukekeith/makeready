//
//  AIProcessing.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-160-aiprocessing in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-160 AIProcessing — the spinner-and-label row shown while AI suggestions are generated.
///
/// §4: "**No props.** … `AIProcessing()` renders the `processing` state." Being shown is the
/// consumer's decision. Chrome-free and width-driven (R-16): it fills the width it is given,
/// is 24 tall, and has no padding, background or divider.
struct AIProcessing: View {

    var body: some View {
        // §2: "One horizontal row, items top-aligned, gap `space-step-16`, content leading".
        HStack(alignment: .top, spacing: Token.Space.step16) {
            // §2: "**C-076 ActivitySpinner** at its defaults … does not shrink." C-076 states
            // its own fixed 24×24 footprint, so it never does.
            ActivitySpinner()
            // §2: "**Status label** … `type-label-emphasis` …, `color-text-secondary`, one
            // line, no wrap, 24pt line box."
            Text(Self.label)
                .designTextStyle(Token.TypeStyle.labelEmphasis)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                // A fixed box: SwiftUI has no line-height, so a single run would otherwise
                // sit in its ~17pt font box.
                .frame(height: Self.lineBox(Token.TypeStyle.labelEmphasis))
                .ui2Element("Status label")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2 Accessibility (R-17): "one accessibility element labelled "Generating
        // suggestions"; the spinner inside is hidden … no button trait."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label)
        .ui2Element("AIProcessing")                               // capture element map — UI2Element.swift
    }

    /// §4: "Fixed, not props: the label "Generating suggestions"".
    private static let label = "Generating suggestions"

    /// The designed line box of a text style — its leading, or its size when none is designed.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
