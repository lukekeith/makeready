//
//  CardVideoMini.swift
//  MakeReady
//
//  Mini video card component (120×188px)
//

import SwiftUI


struct CardVideoMini: View {
    let data: CardVideoData

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top: Image (120×114) with play icon
                imageViewWithPlayIcon

                // Bottom: Content
                VStack(alignment: .leading, spacing: 8) {
                    // Category/Description (above title)
                    if let description = data.description {
                        Text(description)
                            .font(Typography.s13)
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // Title (12pt with 0.1px tracking, max 32px height)
                    Text(data.title)
                        .font(Typography.s12Bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(maxHeight: 32, alignment: .topLeading)
                        .tracking(0.1)

                    // Metadata row (only first item)
                    if let firstItem = data.metadata.first {
                        DataComponent(item: firstItem)
                    }
                }
                .padding(8)
            }
            .frame(width: 120, height: 188)
            .background(Color.cardBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image View with Play Icon

    @ViewBuilder
    private var imageViewWithPlayIcon: some View {
        ZStack {
            // Background image
            switch data.imageStyle {
            case .photo(let imageURL):
                if imageURL.hasPrefix("asset://") {
                    // Local asset image
                    let assetName = imageURL.replacingOccurrences(of: "asset://", with: "")
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 114)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    // Remote URL
                    CachedCardImage(
                        url: imageURL.mediumImageUrl,
                        fallbackUrl: imageURL,
                        width: 120,
                        height: 114,
                        fallback: { iconFallback.frame(width: 120, height: 114) }
                    )
                }

            case .icon(let systemName, _, _):
                iconView(systemName: systemName)
                    .frame(width: 120, height: 114)

            case .dateDisplay, .timeDisplay:
                // Videos don't use date/time display, but handle it gracefully
                iconFallback
                    .frame(width: 120, height: 114)
            }
        }
        .overlay(alignment: .bottom) {
            // Play icon overlay - 16px from bottom, centered horizontally
            playIcon
                .padding(.bottom, 16)
        }
    }

    private var iconFallback: some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(Typography.s24)
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String) -> some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: systemName)
                    .font(Typography.s24)
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    // MARK: - Play Icon

    private var playIcon: some View {
        // 24×24 play icon (decorative, non-interactive)
        Image("IconVideoPlay")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CardVideoMini(
                    data: CardVideoData(
                        id: "video-1",
                        title: "Worship Night",
                        description: "Worship",
                        imageStyle: .photo(imageURL: "https://picsum.photos/120/114"),
                        metadata: [
                            DataItem(icon: "eye", value: "856"),
                            DataItem(icon: "clock", value: "2 hours ago")
                        ],
                        onTap: nil
                    )
                )

                CardVideoMini(
                    data: CardVideoData(
                        id: "video-2",
                        title: "Sunday Service Highlights",
                        description: "Sermons",
                        imageStyle: .photo(imageURL: "https://picsum.photos/120/114"),
                        metadata: [
                            DataItem(icon: "eye", value: "1.2K")
                        ],
                        onTap: nil
                    )
                )
            }
            .padding(20)
        }
    }
}
