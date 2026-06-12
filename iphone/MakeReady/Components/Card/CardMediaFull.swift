//
//  CardMediaFull.swift
//  MakeReady
//
//  Thumbnail-only media grid card for library browse section.
//  Image fills entire card with usage count and duration overlaid in corners.
//

import SwiftUI

struct CardMediaFull: View {
    let item: MediaLibraryItem

    private var imageFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            if item.mediaType != .photo {
                Image(systemName: item.mediaType.icon)
                    .font(Typography.s28)
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-bleed thumbnail
                if let url = item.thumbnailUrl, !url.isEmpty {
                    CachedCardImage(
                        url: url,
                        width: geo.size.width,
                        height: geo.size.height,
                        cornerRadius: 0,
                        fallback: { imageFallback }
                    )
                } else if item.mediaType == .photo, !item.url.isEmpty {
                    CachedCardImage(
                        url: item.url.mediumImageUrl,
                        fallbackUrl: item.url,
                        width: geo.size.width,
                        height: geo.size.height,
                        cornerRadius: 0,
                        fallback: { imageFallback }
                    )
                } else {
                    imageFallback
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topLeading) {
                // Usage count
                if item.usageCount > 0 {
                    Text("\(item.usageCount)")
                        .font(Typography.s11Bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Duration for video/audio
                if let duration = item.formattedDuration {
                    Text(duration)
                        .font(Typography.s11Bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(6)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        LazyVGrid(columns: columns, spacing: 8) {
            CardMediaFull(item: MediaLibraryItem(
                id: "1",
                title: "Sunday Worship",
                description: nil,
                url: "https://example.com/video.mp4",
                type: "video",
                mimeType: "video/mp4",
                fileSize: nil,
                thumbnailUrl: nil,
                uploadStatus: "ready",
                duration: 1830,
                tags: [],
                usageCount: 5,
                uploader: nil,
                video: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))

            CardMediaFull(item: MediaLibraryItem(
                id: "2",
                title: "Banner",
                description: nil,
                url: "https://example.com/photo.jpg",
                type: "photo",
                mimeType: "image/jpeg",
                fileSize: nil,
                thumbnailUrl: nil,
                uploadStatus: "ready",
                duration: nil,
                tags: [],
                usageCount: 0,
                uploader: nil,
                video: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))

            CardMediaFull(item: MediaLibraryItem(
                id: "3",
                title: "Podcast",
                description: nil,
                url: "https://example.com/audio.mp3",
                type: "audio",
                mimeType: "audio/mpeg",
                fileSize: nil,
                thumbnailUrl: nil,
                uploadStatus: "ready",
                duration: 3600,
                tags: [],
                usageCount: 12,
                uploader: nil,
                video: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
        .padding(16)
    }
}
