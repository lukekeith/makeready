//
//  CameraPreview.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-152-camerapreview in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import AVFoundation
import SwiftUI
import UIKit

/// C-152 CameraPreview — the recorder's live camera surface.
///
/// Three layers, back to front (§2): the `color-layout-background` surface, the feed
/// (aspect-fill, centred) and the one designed `overlay` slot, all clipped to the rect and its
/// corners. Width-driven (R-16): it fills the width it is given and its intrinsic height is
/// width × 781 / 440 (OQ-C-152-3). It owns no capture session, starts nothing and runs no async
/// work (R-04, R-19): the caller's capture engine owns the display layer (OQ-C-152-1).
struct CameraPreview<Overlay: View>: View {

    /// §4 `feed` — what fills the rect (OQ-C-152-1).
    enum Feed {
        /// A display layer the capture engine owns (an `AVCaptureVideoPreviewLayer`, or a
        /// sample-buffer layer carrying the live filter, SPEC D6). The view only sets its frame
        /// and `resizeAspectFill` gravity.
        case layer(CALayer)
        /// A still image, aspect-filled — captures, fixtures and posters.
        case still(Image)
        /// Nothing yet: the `color-layout-background` surface alone (OQ-C-152-4).
        case none
    }

    /// §4 `corners` — the clip (§2 Corners).
    enum Corners {
        /// No radius (Figma, lessonInline).
        case square
        /// `radius-card`, continuous (video-recorder §2b fullScreen).
        case rounded
    }

    /// §4 `feed`. Required (R-07).
    let feed: Feed
    /// §4 `corners`. Required (R-07).
    let corners: Corners
    /// §4 `overlay` — the designed slot (R-08), laid over the feed and clipped to the rect
    /// (OQ-C-152-2). Required (R-07).
    @ViewBuilder let overlay: () -> Overlay

    // MARK: - Body

    var body: some View {
        CameraPreviewFrame {
            // §2 Surface + Feed: one non-interactive image element (R-17). The surface shows only
            // with `.none`, or before the feed's first frame arrives.
            ZStack {
                Token.layoutBackground
                    .ui2Element("Surface")
                feedContent
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Camera preview")
            .accessibilityAddTraits(.isImage)

            // §2 Slot `overlay`: the full rect, laid out by the caller; its content keeps its own
            // accessibility elements, which follow the surface in reading order.
            overlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ui2Element("Overlay")
        }
        // §2 Corners: the clip takes the feed and the slot alike.
        .clipShape(clip)
        .ui2Element("CameraPreview")
    }

    // MARK: - Feed

    /// §2 Feed: the full rect, aspect-fill, centred, cropped to the rect.
    @ViewBuilder private var feedContent: some View {
        switch feed {
        case .layer(let layer):
            CameraPreviewLayerHost(layer: layer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ui2Element("Feed")
        case .still(let image):
            Color.clear
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ui2Element("Feed")
        case .none:
            EmptyView()
        }
    }

    // MARK: - Corners

    private var clip: AnyShape {
        switch corners {
        case .square: AnyShape(Rectangle())
        case .rounded: AnyShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        }
    }
}

// MARK: - Frame

/// §2 sizing (R-16): takes the width it is offered and states its own height, width × 781 / 440
/// (OQ-C-152-3); every layer is placed over the full rect. A custom layout because
/// `aspectRatio(contentMode: .fit)` falls back to a zero ideal height when no height is proposed.
private struct CameraPreviewFrame: Layout {
    /// C-152 §2 / OQ-C-152-3 ruling: height ÷ width = 781 / 440, the Figma node's own ratio (a
    /// ratio, not a colour, size or radius — no token family holds it).
    private static let heightPerWidth: CGFloat = 781.0 / 440.0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let width = proposal.width, width.isFinite else { return .zero }
        return CGSize(width: width, height: width * Self.heightPerWidth)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }
}

// MARK: - Layer host

/// Hosts the caller's display layer (OQ-C-152-1): sets its frame to the view's bounds and its
/// gravity to aspect-fill, and nothing else — no session, no permission, no async work (R-04).
private struct CameraPreviewLayerHost: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.host(layer)
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        view.host(layer)
    }

    final class HostView: UIView {
        private var hosted: CALayer?

        func host(_ layer: CALayer) {
            guard hosted !== layer else { return }
            hosted?.removeFromSuperlayer()
            hosted = layer
            switch layer {
            case let preview as AVCaptureVideoPreviewLayer:
                preview.videoGravity = .resizeAspectFill
            case let sampleBuffer as AVSampleBufferDisplayLayer:
                sampleBuffer.videoGravity = .resizeAspectFill
            default:
                layer.contentsGravity = .resizeAspectFill
            }
            self.layer.addSublayer(layer)
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hosted?.frame = bounds
        }
    }
}
