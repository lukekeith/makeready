//
//  QRCodeImage.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-111-qrcodeimage in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-111 QRCodeImage — a caller-supplied QR bitmap on a white rounded plate.
///
/// Preamble: the component "generates nothing itself. The caller resolves the QR bitmap … and
/// passes it in. The component only presents it" (R-04, R-19).
///
/// §2 / R-16: fills the width it is given and its height equals its width (1:1); it paints
/// nothing outside the plate and adds no outer padding.
struct QRCodeImage: View {

    /// C-111 §4 `image` — the QR bitmap the caller has already resolved and decoded. Required
    /// with no default (R-07); `nil` selects the `empty` state (OQ-invite-qr-006).
    let image: Image?

    /// FLAGGED LITERAL — C-111 §2 FL-3: corner radius 16pt (`radius-modal` has the same value
    /// but names the modal container; carried from invite-qr §2).
    private static let cornerRadius: CGFloat = 16

    var body: some View {
        SquareLayout {
            // §2 "Plate: fill `color-white-100`" — a continuous-corner rounded rectangle that
            // clips its content. `empty` is the plate alone.
            Token.white100
                // OQ-C-111-001 (ruled 2026-10-20): the bitmap sits edge to edge on the plate;
                // its own margin is the quiet zone. Untinted, nearest-neighbour sampled so the
                // modules stay sharp.
                .overlay {
                    if let image {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .ui2Element("Bitmap")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
                .ui2Element("Plate")
        }
        // OQ-C-111-002 (ruled 2026-10-20): one element, fixed label "QR code", image trait, in
        // both states.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("QR code")
        .accessibilityAddTraits(.isImage)
        .ui2Element("QRCodeImage")
    }
}

/// Sizes its one subview as a square whose side is the proposed width (R-16: width-driven,
/// intrinsic height). An `.aspectRatio` would honour the harness's zero-height proposal and
/// collapse.
private struct SquareLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let side = proposal.width ?? subviews.first?.sizeThatFits(.unspecified).width ?? 0
        return CGSize(width: side, height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}
