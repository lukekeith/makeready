//
//  SelectVideoPage.swift
//  MakeReady
//
//  Video selection screen with grid, source switching, and recording
//

import SwiftUI
import Photos
import AVKit

// MARK: - Selected Video Result

struct SelectedVideoResult {
    let asset: PHAsset?
    let recordedURL: URL?
    let mediaLibraryItem: MediaLibraryItem?

    init(asset: PHAsset? = nil, recordedURL: URL? = nil, mediaLibraryItem: MediaLibraryItem? = nil) {
        self.asset = asset
        self.recordedURL = recordedURL
        self.mediaLibraryItem = mediaLibraryItem
    }

    var isFromLibrary: Bool { asset != nil }
    var isRecorded: Bool { recordedURL != nil }
    var isFromMediaLibrary: Bool { mediaLibraryItem != nil }
}

// MARK: - Select Video Page

struct SelectVideoPage: View {
    @Binding var isPresented: Bool
    var onVideoSelected: ((SelectedVideoResult) -> Void)?

    @StateObject private var photoLibrary = PhotoLibraryManager.shared

    // Selection state
    @State private var selectedAsset: PHAsset?
    @State private var recordedVideoURL: URL?
    @State private var currentSource: VideoSource = .videos
    @State private var selectedAlbum: PhotoAlbum?

    // UI state
    @State private var showSourceMenu = false
    @State private var showRecorder = false
    @State private var showVideoPlayer = false
    @State private var showAlbumPicker = false
    @State private var showPermissionAlert = false
    @State private var videoPlayer: AVPlayer?

    // Grid layout - use fixed size to ensure precise tap areas
    private var columns: [GridItem] {
        let itemSize = gridItemSize
        return [
            GridItem(.fixed(itemSize), spacing: 2),
            GridItem(.fixed(itemSize), spacing: 2),
            GridItem(.fixed(itemSize), spacing: 2),
            GridItem(.fixed(itemSize), spacing: 2)
        ]
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Video Preview
                        VideoPreview(
                            selectedAsset: selectedAsset,
                            recordedVideoURL: recordedVideoURL,
                            onTap: handlePreviewTap
                        )
                        .frame(height: 440)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 55)

                        // Source Bar with menu below
                        VideoSourceBar(
                            currentSource: $currentSource,
                            onSourceTap: { showSourceMenu.toggle() },
                            onMakeReadyTap: { /* Future feature */ }
                        )
                        .zIndex(2) // Keep above backdrop so button stays tappable

                        if showSourceMenu {
                            VideoSourceMenu(
                                isPresented: $showSourceMenu,
                                selectedSource: $currentSource,
                                onAlbumsSelected: { showAlbumPicker = true },
                                anchorY: 0
                            )
                            .padding(.horizontal, 16)
                            .zIndex(1)
                        }

                        // Video Grid
                        videoGrid
                    }
                }
            }

            // Tap-to-dismiss backdrop for menu (below source bar via zIndex)
            if showSourceMenu {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .onTapGesture {
                        showSourceMenu = false
                    }
            }
        }
        .task {
            await requestAndLoadVideos()
        }
        .onChange(of: currentSource) { _, newSource in
            handleSourceChange(newSource)
        }
        .fullScreenCover(isPresented: $showRecorder) {
            CustomVideoRecorder(
                isPresented: $showRecorder,
                onVideoRecorded: { url in
                    recordedVideoURL = url
                    selectedAsset = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            videoPlayerView
        }
        .sheet(isPresented: $showAlbumPicker) {
            albumPickerSheet
        }
        .alert("Photo Library Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Please allow access to your photo library to select videos.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Close button
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Next button
            Button {
                handleNext()
            } label: {
                Text("Next")
                    .font(.system(size: 17))
                    .foregroundColor(hasSelection ? .brandPrimary : .white.opacity(0.3))
            }
            .disabled(!hasSelection)
        }
        .overlay {
            Text("Select video")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    // MARK: - Video Grid

    private var videoGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            // Camera button (always first)
            VideoGridItem(
                type: .camera,
                isSelected: false,
                size: gridItemSize,
                onTap: { showRecorder = true }
            )

            // Video items
            ForEach(0..<photoLibrary.videoCount, id: \.self) { index in
                if let videoAsset = photoLibrary.videoAsset(at: index) {
                    VideoGridItem(
                        type: .video(videoAsset),
                        isSelected: selectedAsset?.localIdentifier == videoAsset.id,
                        size: gridItemSize,
                        onTap: {
                            selectVideo(videoAsset)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 100) // Extra padding at bottom
    }

    private var gridItemSize: CGFloat {
        // Available width = screen width - horizontal padding (2+2) - column spacing (3 gaps × 2pt)
        (Screen.bounds.width - 4 - 6) / 4
    }

    // MARK: - Video Player View

    private var videoPlayerView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    Button {
                        showVideoPlayer = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)

                // Player
                if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear {
                            player.play()
                        }
                } else {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading video...")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 8)
                    }
                }
            }
        }
        .onDisappear {
            videoPlayer?.pause()
            videoPlayer = nil
        }
    }

    // MARK: - Album Picker Sheet

    private var albumPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(photoLibrary.albums) { album in
                            Button {
                                selectedAlbum = album
                                showAlbumPicker = false
                                photoLibrary.selectedAlbum = album
                            } label: {
                                HStack(spacing: 12) {
                                    // Album thumbnail
                                    ZStack {
                                        Color.sectionBackground

                                        if let asset = album.thumbnailAsset {
                                            AlbumThumbnail(asset: asset)
                                        } else {
                                            Image(systemName: "video.fill")
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }
                                    .frame(width: 56, height: 56)
                                    .cornerRadius(8)

                                    // Album info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(album.title)
                                            .font(.system(size: 17))
                                            .foregroundColor(.white)

                                        Text("\(album.count) videos")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            .navigationTitle("Select Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAlbumPicker = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await photoLibrary.ensureAuthorized()
        }
    }

    // MARK: - Helpers

    private var hasSelection: Bool {
        selectedAsset != nil || recordedVideoURL != nil
    }

    // MARK: - Actions

    private func requestAndLoadVideos() async {
        await photoLibrary.ensureAuthorized()
        if !photoLibrary.isAuthorized {
            showPermissionAlert = true
        }
    }

    private func handleSourceChange(_ source: VideoSource) {
        selectedAlbum = nil
        if source == .videos {
            photoLibrary.selectedAlbum = nil
        }
    }

    private func selectVideo(_ videoAsset: VideoAsset) {
        selectedAsset = videoAsset.asset
        recordedVideoURL = nil
    }

    private func handlePreviewTap() {
        guard hasSelection else { return }

        Task {
            let playerItem: AVPlayerItem?
            if let asset = selectedAsset {
                playerItem = await photoLibrary.playerItem(for: asset)
            } else if let url = recordedVideoURL {
                playerItem = AVPlayerItem(url: url)
            } else {
                playerItem = nil
            }

            if let item = playerItem {
                videoPlayer = AVPlayer(playerItem: item)
                showVideoPlayer = true
            }
        }
    }

    private func handleNext() {
        let result = SelectedVideoResult(
            asset: selectedAsset,
            recordedURL: recordedVideoURL
        )
        onVideoSelected?(result)
        isPresented = false
    }
}

// MARK: - Album Thumbnail

private struct AlbumThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.sectionBackground
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let size = CGSize(width: 56, height: 56)
        image = await PhotoLibraryManager.shared.thumbnail(for: asset, size: size)
    }
}

// MARK: - Preview

#Preview {
    SelectVideoPage(isPresented: .constant(true))
}
