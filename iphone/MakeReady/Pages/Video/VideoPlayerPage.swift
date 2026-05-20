//
//  VideoPlayerPage.swift
//  MakeReady
//
//  Full-screen video player with native iOS controls
//

import SwiftUI
import AVKit

struct VideoPlayerPage: View {
    let videoURL: URL
    let title: String?
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var dragOffset: CGSize = .zero

    /// When true, the player was opened inline (from search) — swipe right to go back, no close button.
    /// When false, presented as modal — swipe down to dismiss, show xmark button.
    private var isInline: Bool { onDismiss != nil }

    init(videoURL: URL, title: String? = nil, onDismiss: (() -> Void)? = nil) {
        self.videoURL = videoURL
        self.title = title
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Close button overlay (only when presented as modal)
            if !isInline {
                VStack {
                    HStack {
                        Button {
                            handleDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)

                        Spacer()
                    }

                    Spacer()
                }
            }
        }
        .offset(x: isInline ? dragOffset.width : 0, y: isInline ? 0 : dragOffset.height)
        .gesture(
            DragGesture(minimumDistance: isInline ? 20 : 5, coordinateSpace: .global)
                .onChanged { value in
                    if isInline {
                        // Horizontal: only allow rightward drag
                        if value.translation.width > 0 {
                            dragOffset = CGSize(width: value.translation.width, height: 0)
                        }
                    } else {
                        // Vertical: only allow downward drag
                        if value.translation.height > 0 {
                            dragOffset = CGSize(width: 0, height: value.translation.height)
                        }
                    }
                }
                .onEnded { value in
                    if isInline && value.translation.width > 100 {
                        handleDismiss()
                    } else if !isInline && value.translation.height > 100 {
                        handleDismiss()
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private func handleDismiss() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func setupPlayer() {
        let player = AVPlayer(url: videoURL)
        self.player = player
        player.play()
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
    }
}

#Preview {
    VideoPlayerPage(
        videoURL: URL(string: "https://example.com/video.mp4")!,
        title: "Sample Video"
    )
}
