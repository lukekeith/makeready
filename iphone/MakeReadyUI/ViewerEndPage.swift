//
//  ViewerEndPage.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-136-viewer-end-page in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-136 ViewerEndPage — the last page of the stitched viewer's stack, with the lesson title and a
/// Close button.
///
/// Fills the width and height it is given and paints its own ground, the R-16 carve-out ruled by
/// OQ-C-136-002. Pure and controlled: it takes a title and emits a tap. Only the Close button takes
/// touches, so the pager keeps a drag that starts anywhere else on the page (§2, 01 §5).
struct ViewerEndPage: View {

    /// FLAGGED LITERAL — C-136 §2, OQ-C-136-004: the title group's top edge, 27.8 % of the page's height.
    private static let titleTopFraction: CGFloat = 0.278
    /// FLAGGED LITERAL — C-136 §2, OQ-C-136-001: the button's bottom edge sits `bottomInset` + 30
    /// above the page's bottom; no spacing token carries it.
    private static let closeAboveInset: CGFloat = 30
    /// C-136 §2 "up to 3 lines, then truncated at the tail" (OQ-C-136-005).
    private static let titleLineLimit = 3

    /// C-136 §4 `title` — the lesson's title.
    let title: String
    /// C-136 §4 `bottomInset` — the host's bottom safe-area inset; places the Close button.
    let bottomInset: CGFloat
    /// C-136 §4 `onClose` — the Close button was tapped; the host closes the experience.
    var onClose: () -> Void = {}

    var body: some View {
        GeometryReader { page in
            // §2 Layers, bottom to top: ground, title group, Close button.
            ZStack {
                Token.layoutBackground
                    .allowsHitTesting(false)
                    .ui2Element("Ground")

                titleGroup
                    .padding(.top, page.size.height * Self.titleTopFraction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ui2Element("ViewerEndPage")
    }

    /// §2 Title group: centred, page width less the margins, growing downward. Static on purpose:
    /// hit testing is off so the pager owns a drag that starts here.
    private var titleGroup: some View {
        VStack(spacing: Token.Space.stackGap) {
            Text(title)
                .designTextStyle(Token.TypeStyle.codeDisplay)
                .foregroundColor(Token.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(Self.titleLineLimit)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
                .ui2Element("Title")

            Text("End of lesson")
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .ui2Element("End of lesson")
        }
        .frame(maxWidth: .infinity)
        .ui2Element("Title group")
        .padding(.horizontal, Token.Space.pageMargin)
        .allowsHitTesting(false)
    }

    /// §2 Close button: C-048 at the page margins, its look, height and label traits its own (R-17).
    private var closeButton: some View {
        PageActionButton(label: "Close", role: .prominent, onTap: onClose)
            .ui2Element("Close button")
            .padding(.horizontal, Token.Space.pageMargin)
            .padding(.bottom, bottomInset + Self.closeAboveInset)
    }
}
