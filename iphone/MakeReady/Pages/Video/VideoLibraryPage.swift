//
//  VideoLibraryPage.swift
//  MakeReady
//
//  Shows user's video library with upload capability
//

import SwiftUI
import PhotosUI
import AVKit

struct VideoLibraryPage: View {
    @Binding var isPresented: Bool
    var onVideoSelected: ((Video) -> Void)?

    private var state: AppState { AppState.shared }
    @State private var showVideoRecorder = false
    @State private var showVideoPicker = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedVideo: Video?
    @State private var showVideoPlayer = false
    @State private var showDeleteConfirmation = false
    @State private var videoToDelete: Video?
    @State private var showError = false
    @State private var errorMessage = ""

    // Refresh state - prevents stacking multiple refresh requests
    @State private var isRefreshing = false

    // Selection mode (when used as picker)
    let isSelectionMode: Bool

    init(isPresented: Binding<Bool>, isSelectionMode: Bool = false, onVideoSelected: ((Video) -> Void)? = nil) {
        self._isPresented = isPresented
        self.isSelectionMode = isSelectionMode
        self.onVideoSelected = onVideoSelected
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Content
                if state.loadingStates.isLoading(.videos) && state.orderedVideos.isEmpty {
                    loadingView
                } else if state.orderedVideos.isEmpty {
                    emptyStateView
                } else {
                    videoGrid
                }
            }

            // Upload progress overlay
            if state.loadingStates.isLoading("video-upload") {
                uploadProgressOverlay
            }
        }
        .task {
            await loadVideos()
        }
        .photosPicker(
            isPresented: $showVideoPicker,
            selection: $selectedVideoItem,
            matching: .videos
        )
        .onChange(of: selectedVideoItem) { _, newItem in
            if let item = newItem {
                Task {
                    await handleSelectedVideo(item)
                }
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let video = selectedVideo {
                VideoPlayerSheet(video: video, isPresented: $showVideoPlayer)
            }
        }
        .alert("Delete Video?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    Task {
                        await deleteVideo(video)
                    }
                }
            }
        } message: {
            Text("This will permanently delete this video.")
        }
        .alert("Video unavailable", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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
                    .font(Typography.s17Semibold)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(isSelectionMode ? "Select Video" : "My Videos")
                .font(Typography.s17Semibold)
                .foregroundColor(.white)

            Spacer()

            // Add video button
            Button {
                showVideoPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(Typography.s17Semibold)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color.sectionBackground)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading videos...")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 16)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "video.badge.plus")
                .font(Typography.s64)
                .foregroundColor(.white.opacity(0.3))

            Text("No Videos Yet")
                .font(Typography.s20Semibold)
                .foregroundColor(.white)

            Text("Record or upload your first video to get started")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showVideoPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Upload Video")
                }
                .font(Typography.s15Semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.purple)
                .cornerRadius(8)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Video Grid

    private var videoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(state.orderedVideos) { video in
                    VideoThumbnailCard(
                        video: video,
                        isSelectionMode: isSelectionMode,
                        onTap: {
                            handleVideoTap(video)
                        },
                        onDelete: {
                            videoToDelete = video
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(16)
        }
        .refreshable {
            guard !isRefreshing else { return }
            isRefreshing = true

            Task.detached { @MainActor in
                defer { isRefreshing = false }
                await loadVideos()
            }

            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Upload Progress Overlay

    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                if let progress = state.uploadProgress {
                    VStack(spacing: 8) {
                        ProgressView(value: progress.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            .frame(width: 200)

                        Text("Uploading... \(progress.percentage)%")
                            .font(Typography.s15)
                            .foregroundColor(.white)
                    }
                } else {
                    Text("Preparing upload...")
                        .font(Typography.s15)
                        .foregroundColor(.white)
                }

                Button {
                    VideoActions().cancelUpload()
                } label: {
                    Text("Cancel")
                        .font(Typography.s15Medium)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Actions

    private func loadVideos() async {
        do {
            try await VideoActions().loadVideos()
        } catch {
            state.recordError(
                error,
                context: "VideoLibraryPage.loadVideos",
                surface: true,
                operation: .loadVideos,
                retry: { Task { await loadVideos() } }
            )
        }
    }

    private func handleVideoTap(_ video: Video) {
        if isSelectionMode {
            // In selection mode, return the video
            if video.videoStatus == .ready {
                onVideoSelected?(video)
                isPresented = false
            } else {
                errorMessage = "This video is still processing. Please wait and try again."
                showError = true
            }
        } else {
            // In browse mode, play the video
            if video.videoStatus == .ready {
                selectedVideo = video
                showVideoPlayer = true
            } else {
                // Refresh status and show message
                Task {
                    do {
                        _ = try await VideoActions().refreshVideoStatus(id: video.id)
                    } catch {
                        // Background status refresh — console-only.
                        state.recordError(error, context: "VideoLibraryPage.handleVideoTap.refreshVideoStatus")
                    }
                }
                errorMessage = "This video is still processing. Please wait."
                showError = true
            }
        }
    }

    private func handleSelectedVideo(_ item: PhotosPickerItem) async {
        guard let videoData = try? await item.loadTransferable(type: VideoTransferable.self) else {
            await MainActor.run {
                errorMessage = UserFacingErrorFormatter.message(for: .openSelectedFile)
                showError = true
                selectedVideoItem = nil
            }
            return
        }

        do {
            let _ = try await VideoActions().uploadAndCreateVideo(
                from: videoData.url,
                title: nil,
                description: nil
            ) { progress in
                print("Upload progress: \(progress.percentage)%")
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: videoData.url)

            selectedVideoItem = nil
        } catch {
            await MainActor.run {
                state.recordError(
                    error,
                    context: "VideoLibraryPage.handleSelectedVideo",
                    surface: true,
                    operation: .uploadVideo
                )
                selectedVideoItem = nil
            }
        }
    }

    private func deleteVideo(_ video: Video) async {
        do {
            try await VideoActions().deleteVideo(id: video.id)
            videoToDelete = nil
        } catch {
            await MainActor.run {
                state.recordError(
                    error,
                    context: "VideoLibraryPage.deleteVideo",
                    surface: true,
                    operation: .deleteVideo,
                    retry: { Task { await deleteVideo(video) } }
                )
            }
        }
    }
}

// MARK: - Video Thumbnail Card

struct VideoThumbnailCard: View {
    let video: Video
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    /// Card displays at ~190pt wide; decode capped at 600px so Cloudflare's
    /// full-size stills don't hold full bitmaps in memory (Phase 4.7).
    private static let thumbnailMaxPixelSize: CGFloat = 600

    // Pre-populated from the synchronous cache so thumbnails are present
    // on first render after the first load (AsyncImage re-fetched every
    // cell appearance with no cross-cell cache).
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                ZStack {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(height: 100)
                .clipped()
                .task(id: video.thumbnailUrl) {
                    await loadThumbnail()
                }
                .overlay(alignment: .bottomTrailing) {
                    // Duration badge
                    if let duration = video.formattedDuration {
                        Text(duration)
                            .font(Typography.s11Medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(6)
                    }
                }
                .overlay(alignment: .center) {
                    // Ready videos are identified by the duration badge alone
                    // (no center play icon); non-ready ones show a spinner.
                    if video.videoStatus != .ready {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Status badge for non-ready videos
                    if video.videoStatus != .ready {
                        Text(video.videoStatus.displayName)
                            .font(Typography.s10Semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(video.videoStatus == .error ? Color.error : Color.orange)
                            .cornerRadius(4)
                            .padding(6)
                    }
                }

                // Info section
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.displayTitle)
                        .font(Typography.s13Medium)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(video.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(8)
            }
            .background(Color.cardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelectionMode {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func loadThumbnail() async {
        guard let urlString = video.thumbnailUrl, let url = URL(string: urlString) else {
            thumbnail = nil
            return
        }
        if let cached = ImageCache.shared.cachedImage(for: url, maxPixelSize: Self.thumbnailMaxPixelSize) {
            thumbnail = cached
            return
        }
        // Failure leaves the placeholder showing, same as AsyncImage's
        // .failure branch did.
        thumbnail = try? await ImageCache.shared.fetch(url: url, maxPixelSize: Self.thumbnailMaxPixelSize)
    }

    private var thumbnailPlaceholder: some View {
        Color.sectionBackground
            .overlay(
                Image(systemName: "video.fill")
                    .font(Typography.s24)
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - Video Player Sheet

struct VideoPlayerSheet: View {
    let video: Video
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    Button {
                        player?.pause()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(Typography.s17Semibold)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(video.displayTitle)
                        .font(Typography.s17Semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)

                // Video player
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading video...")
                            .font(Typography.s15)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 8)
                    }
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let url = URL(string: video.playbackUrl) else { return }
        player = AVPlayer(url: url)
        player?.play()
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let filename = UUID().uuidString + ".mov"
            let destURL = tempDir.appendingPathComponent(filename)

            try FileManager.default.copyItem(at: received.file, to: destURL)
            return VideoTransferable(url: destURL)
        }
    }
}

// MARK: - Preview

#Preview {
    VideoLibraryPage(isPresented: .constant(true))
}
