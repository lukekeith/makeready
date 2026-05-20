//
//  BackgroundSwatch.swift
//  MakeReady
//
//  Compact 40×40 button that displays the currently-selected background for a
//  read block — image underneath + color overlay on top (if both set), image
//  alone, solid color, or the app's default dark blue when nothing is set.
//  Tapping invokes the supplied closure (typically to present a
//  EditBlockBackgroundPage as a slide-in pane of EditReadActivityPage).
//

import SwiftUI

struct BackgroundSwatch: View {
    let imageUrl: String?
    let color: String?
    /// Opacity (0–1) of the color overlay when both `imageUrl` and `color`
    /// are set. Nil → default 0.8. Ignored when there's no image.
    var overlayOpacity: Double? = nil
    var size: CGFloat = 40
    /// Explicit corner radius override. When `nil`, derives from `size`
    /// (40 → 8, 56+ → 12). Pass `0` for a flush-edge tile.
    var cornerRadiusOverride: CGFloat? = nil
    let onTap: () -> Void

    private var cornerRadius: CGFloat {
        if let override = cornerRadiusOverride { return override }
        return size >= 56 ? 12 : 8
    }

    private var effectiveOverlayOpacity: Double {
        overlayOpacity ?? 0.8
    }

    var body: some View {
        Button(action: onTap) {
            fill
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Background")
    }

    @ViewBuilder
    private var fill: some View {
        // Image underneath, color on top as an overlay at `overlayOpacity`.
        // - image + color: image + translucent color layer
        // - image only:    image
        // - color only:    solid color
        // - neither:       app default dark blue
        ZStack {
            if let url = imageUrl, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.appBackground
                    }
                }
            } else if color == nil {
                Color.appBackground
            }

            if let hex = color, !hex.isEmpty {
                Color(hex: hex)
                    .opacity(imageUrl == nil ? 1.0 : effectiveOverlayOpacity)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            BackgroundSwatch(imageUrl: nil, color: nil) {}
            BackgroundSwatch(imageUrl: nil, color: "#1E3A8A") {}
            BackgroundSwatch(imageUrl: "https://picsum.photos/200", color: nil) {}
        }
        HStack(spacing: 12) {
            BackgroundSwatch(imageUrl: "https://picsum.photos/200", color: "#1E3A8A", overlayOpacity: 0.8) {}
            BackgroundSwatch(imageUrl: "https://picsum.photos/200", color: "#1E3A8A", overlayOpacity: 0.4) {}
            BackgroundSwatch(imageUrl: "https://picsum.photos/200", color: "#701A75", overlayOpacity: 0.6) {}
        }
    }
    .padding()
    .background(Color.appBackground)
}
