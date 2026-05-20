//
//  VideoPreview.swift
//  MakeReady
//
//  Large preview area showing selected video thumbnail with tap-to-play
//

import SwiftUI
import Photos
import AVKit

// MARK: - Video Preview

struct VideoPreview: View {
    let selectedAsset: PHAsset?
    let recordedVideoURL: URL?
    var onTap: () -> Void

    @StateObject private var photoLibrary = PhotoLibraryManager.shared
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.sectionBackground

                    // Thumbnail content
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else if selectedAsset == nil && recordedVideoURL == nil {
                        // No video selected - show placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))

                            Text("Select a video")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task(id: selectedAsset?.localIdentifier ?? recordedVideoURL?.absoluteString ?? "") {
            await loadThumbnail()
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() async {
        thumbnail = nil

        if let asset = selectedAsset {
            // Load from photo library
            let size = CGSize(width: 330, height: 440)
            if let image = await photoLibrary.thumbnail(for: asset, size: size) {
                thumbnail = image
            }
        } else if let url = recordedVideoURL {
            // Load from recorded video URL
            thumbnail = await generateThumbnail(from: url)
        }
    }

    private func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 660, height: 880) // 2x for retina

        do {
            let (cgImage, _) = try await imageGenerator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            VideoPreview(
                selectedAsset: nil,
                recordedVideoURL: nil,
                onTap: { print("Preview tapped") }
            )
            .frame(width: 330, height: 440)

            Spacer()
        }
        .padding(.top, 56)
    }
}
