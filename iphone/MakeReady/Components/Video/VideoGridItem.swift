//
//  VideoGridItem.swift
//  MakeReady
//
//  Grid cell component for video selection - camera button or video thumbnail
//

import SwiftUI
import Photos

// MARK: - Video Grid Item

struct VideoGridItem: View {
    enum ItemType {
        case camera
        case video(VideoAsset)
    }

    let type: ItemType
    let isSelected: Bool
    let size: CGFloat
    var onTap: () -> Void

    @StateObject private var photoLibrary = PhotoLibraryManager.shared
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                switch type {
                case .camera:
                    cameraView
                case .video(let videoAsset):
                    videoView(videoAsset)
                }

                // Selection overlay
                if isSelected {
                    Color.white.opacity(0.5)
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: size, height: size)
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            Color.white.opacity(0.2)

            Image(systemName: "camera.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }

    // MARK: - Video View

    private func videoView(_ videoAsset: VideoAsset) -> some View {
        ZStack {
            // Thumbnail
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.sectionBackground
                    .task {
                        await loadThumbnail(for: videoAsset)
                    }
            }

            // Play icon at bottom center
            VStack {
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail(for videoAsset: VideoAsset) async {
        let thumbnailSize = CGSize(width: size, height: size)
        if let image = await photoLibrary.thumbnail(for: videoAsset.asset, size: thumbnailSize) {
            thumbnail = image
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            Text("Camera Button")
                .foregroundColor(.white)

            VideoGridItem(
                type: .camera,
                isSelected: false,
                size: 100,
                onTap: {}
            )

            Text("Camera Button (Selected)")
                .foregroundColor(.white)

            VideoGridItem(
                type: .camera,
                isSelected: true,
                size: 100,
                onTap: {}
            )
        }
    }
}
