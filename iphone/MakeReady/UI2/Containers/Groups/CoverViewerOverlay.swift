import SwiftUI

/// group-cover-image D8: the whole original, aspect-fit over `color-layout-background` at 0.95;
/// tap anywhere or swipe down closes it; no zoom in v1. Build-made (no d2m design) — routed to
/// `/ui2-resolve` after the build (F3).
struct CoverViewerOverlay: View {
    let url: String
    let accessibilityLabel: String
    let onClose: () -> Void

    /// GAP — no design: a downward drag past this closes the viewer (the C-066 sheet's threshold).
    static let dismissDistance: CGFloat = 80

    @State private var image: UIImage?
    @State private var drag: CGFloat = 0

    static func viewerURL(group: UserGroup) -> String? {
        if let original = group.coverOriginalUrl, !original.isEmpty { return original }
        if let cover = group.coverImageUrl, !cover.isEmpty { return cover }
        return nil
    }

    static func closes(dragHeight: CGFloat) -> Bool { dragHeight > dismissDistance }

    var body: some View {
        ZStack {
            Token.layoutBackground.opacity(0.95).ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .offset(y: max(0, drag))
                    .accessibilityLabel(accessibilityLabel)
            } else {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { value in
                    if Self.closes(dragHeight: value.translation.height) { onClose() } else {
                        withAnimation(Token.Motion.menuFadeOut) { drag = 0 }
                    }
                }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .task(id: url) {
            guard let u = URL(string: url) else { return }
            if Ui2ImageCache.shared.image(for: u) == nil { _ = await UI2ImageLoader.seed([url], context: "CoverViewerOverlay") }
            image = Ui2ImageCache.shared.image(for: u)
        }
    }
}

private struct CoverViewerPresentation: ViewModifier {
    let url: String?
    let accessibilityLabel: String
    let onClose: () -> Void
    @Environment(\.ui2HostsOverlays) private var hosted

    func body(content: Content) -> some View {
        let layer = url.map { CoverViewerOverlay(url: $0, accessibilityLabel: accessibilityLabel, onClose: onClose) }
        if hosted {
            content.hostedOverlay(layer.map { UI2HostedOverlay(view: AnyView($0)) })
        } else {
            content.overlay { if let layer { layer } }
        }
    }
}

extension View {
    /// D8: presents the viewer while `url` is non-nil, through the shell's `.ui2OverlayHost()`
    /// (crossfade, the filter-menu default). Present it only after any C-066 menu has finished
    /// sliding out — the host keeps the first presented overlay (`UI2HostedOverlayKey` and
    /// `hostedOverlay(_:)` in FilterMenuOverlay.swift). image-framing-editor D13: the image's
    /// accessibility label is the caller's ("Group cover", "Profile photo").
    func coverViewerPresentation(url: String?, accessibilityLabel: String, onClose: @escaping () -> Void) -> some View {
        modifier(CoverViewerPresentation(url: url, accessibilityLabel: accessibilityLabel, onClose: onClose))
    }
}
