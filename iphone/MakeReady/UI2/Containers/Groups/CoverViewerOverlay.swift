import SwiftUI

/// group-cover-image D8 → image-viewer-zoom-dismiss (owner 2026-10-28): "View image" shows the whole
/// original in `ImageViewer` — pinch / double-tap zoom with pan, and Photos' drag-to-dismiss
/// back into the cover it opened from (reference docs/ui2/references/image-viewer-zoom-dismiss.md).
enum CoverViewerOverlay {
    static func viewerURL(group: UserGroup) -> String? {
        if let original = group.coverOriginalUrl, !original.isEmpty { return original }
        if let cover = group.coverImageUrl, !cover.isEmpty { return cover }
        return nil
    }
}

private struct ImageViewerPresentation: ViewModifier {
    let viewer: ImageViewer?
    @Environment(\.ui2HostsOverlays) private var hosted

    func body(content: Content) -> some View {
        if hosted {
            // The viewer animates its own open and close (rules 1 and 8): no host crossfade.
            content.hostedOverlay(viewer.map { UI2HostedOverlay(view: AnyView($0), transition: .identity) })
        } else {
            content.overlay { if let viewer { viewer } }
        }
    }
}

extension View {
    /// Presents the viewer while `url` is non-nil, through the shell's `.ui2OverlayHost()`. Present
    /// it only after any C-066 menu has finished sliding out — the host keeps the first presented
    /// overlay (`UI2HostedOverlayKey` and `hostedOverlay(_:)` in FilterMenuOverlay.swift).
    /// `sourceFrame` (global) is what the image grows from and flies back into; nil = in place.
    /// image-framing-editor D13: the image's accessibility label is the caller's.
    func coverViewerPresentation(url: String?, sourceFrame: CGRect? = nil, accessibilityLabel: String,
                                 placeholder: UIImage? = nil, onClose: @escaping () -> Void) -> some View {
        imageViewerPresentation(url.map {
            ImageViewer(url: $0, sourceFrame: sourceFrame, accessibilityLabel: accessibilityLabel, onClose: onClose, placeholder: placeholder)
        })
    }

    /// media-viewer-paging: presents `viewer` (any form, the paging one included) while non-nil, the
    /// same way as `coverViewerPresentation`.
    func imageViewerPresentation(_ viewer: ImageViewer?) -> some View {
        modifier(ImageViewerPresentation(viewer: viewer))
    }
}
