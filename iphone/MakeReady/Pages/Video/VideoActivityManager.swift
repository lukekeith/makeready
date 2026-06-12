//
//  VideoActivityManager.swift
//  MakeReady
//
//  Full-screen view for managing a video activity that already has a video.
//  Shows the existing video in a preview pane with options to replace it:
//    - Record a new video (camera) via red record button on video overlay
//    - Select from MakeReady media library
//    - Select from phone library
//

import SwiftUI
import AVFoundation

struct VideoActivityManager: View {
    let videoUrl: String
    let videoThumbnailUrl: String?
    let onDismiss: () -> Void
    let onVideoSelected: (SelectedVideoResult) -> Void
    let onVideoRemoved: () -> Void

    // Video player state
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var timeObserver: Any?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isMuted = false

    // Recording state
    @State private var isRecording = false          // Camera has taken over video area
    @State private var showRecordConfirmation = false

    // Remove state
    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false

    // Sub-pickers
    @State private var showPhoneLibrary = false
    @State private var showMediaLibrary = false

    @State private var dragOffset: CGFloat = 0

    private var state: AppState { AppState.shared }

    private var topSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 59 }
        return window.safeAreaInsets.top
    }

    private var bottomSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 34 }
        return window.safeAreaInsets.bottom
    }

    private var backgroundOpacity: Double {
        let screenHeight = Screen.bounds.height
        guard screenHeight > 0 else { return 1 }
        return max(0, 1 - Double(dragOffset) / Double(screenHeight) * 1.5)
    }

    var body: some View {
        ZStack {
            Color.appBackground.opacity(backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Video / Camera area
                GeometryReader { geometry in
                    ZStack {
                        if isRecording {
                            // Camera has taken over the video area
                            CustomVideoRecorder(
                                isPresented: .constant(true),
                                onVideoRecorded: { url in
                                    let result = SelectedVideoResult(recordedURL: url)
                                    cleanupPlayer()
                                    onVideoSelected(result)
                                },
                                onDismiss: {
                                    // User cancelled recording — return to video preview
                                    withAnimation(Motion.standard) {
                                        isRecording = false
                                    }
                                    setupPlayer()
                                },
                                topSafeArea: topSafeArea,
                                isCameraActive: true,
                                transparentBackground: true
                            )
                        } else {
                            // Existing video preview
                            if let player = player {
                                ClippedVideoPlayer(player: player, cornerRadius: 16, videoGravity: .resizeAspectFill)
                                    .padding(.horizontal, 16)
                                    .padding(.top, topSafeArea + 16)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black)
                                    .overlay(ProgressView().tint(.white))
                                    .padding(.horizontal, 16)
                                    .padding(.top, topSafeArea + 16)
                            }

                            videoOverlayControls
                        }
                    }
                }

                // Source buttons below video (hidden when recording)
                if !isRecording {
                    sourceButtons
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, bottomSafeArea + 16)
                }
            }
            .offset(y: isRecording ? 0 : dragOffset)

            if showRemoveConfirmation {
                removeConfirmationOverlay
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .gesture(isRecording ? nil :
            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    let screenHeight = Screen.bounds.height
                    let velocityPts = value.predictedEndTranslation.height - value.translation.height
                    let pastThreshold = value.translation.height > screenHeight * 0.35
                    let flicked = velocityPts > 500

                    if pastThreshold || flicked {
                        let remaining = screenHeight - dragOffset
                        let initialVelocity = remaining > 0 ? velocityPts / remaining : 1
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dragOffset = screenHeight
                        }
                        let settleTime = max(0.2, min(0.4, Double(remaining) / max(Double(velocityPts), 800)))
                        DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) {
                            cleanupPlayer()
                            onDismiss()
                        }
                    } else {
                        let initialVelocity = dragOffset > 0 ? -velocityPts / dragOffset : 0
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear { setupPlayer() }
        .onDisappear { cleanupPlayer() }
        .alert("Record new video?", isPresented: $showRecordConfirmation) {
            Button("Record", role: .destructive) {
                player?.pause()
                isPlaying = false
                cleanupPlayer()
                withAnimation(Motion.standard) {
                    isRecording = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will open the camera. The existing video will only be replaced if you record a new one.")
        }
        .fullScreenCover(isPresented: $showPhoneLibrary) {
            VideoActivityPicker(
                onDismiss: { showPhoneLibrary = false },
                onVideoSelected: { result in
                    showPhoneLibrary = false
                    cleanupPlayer()
                    onVideoSelected(result)
                }
            )
        }
        .fullScreenCover(isPresented: $showMediaLibrary) {
            MediaLibraryPickerView(
                onDismiss: { showMediaLibrary = false },
                onItemSelected: { item in
                    showMediaLibrary = false
                    cleanupPlayer()
                    onVideoSelected(SelectedVideoResult(mediaLibraryItem: item))
                }
            )
        }
    }

    // MARK: - Video Overlay Controls

    private var videoOverlayControls: some View {
        ZStack {
            VStack {
                HStack {
                    // Close button
                    Button {
                        cleanupPlayer()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Typography.s20Semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Remove video button
                    Button {
                        withAnimation(Motion.micro) {
                            showRemoveConfirmation = true
                        }
                        player?.pause()
                        isPlaying = false
                    } label: {
                        Image(systemName: "trash")
                            .font(Typography.s20)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, topSafeArea + 16)

                Spacer()

                // Bottom row: record button (left), mute toggle (right)
                HStack {
                    // Record button — red circle
                    Button {
                        showRecordConfirmation = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 40, height: 40)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 28, height: 28)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 4)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Mute toggle
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(Typography.s20)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                            .frame(width: 40, height: 40)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            // Center play/pause
            if !isPlaying {
                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: "play.fill")
                        .font(Typography.s36)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { togglePlayPause() }
    }

    // MARK: - Source Buttons

    private var sourceButtons: some View {
        VStack(spacing: 12) {
            sourceButton(
                icon: "square.grid.2x2",
                label: "MakeReady library",
                action: {
                    player?.pause()
                    isPlaying = false
                    showMediaLibrary = true
                }
            )

            sourceButton(
                icon: "photo.on.rectangle",
                label: "Phone library",
                action: {
                    player?.pause()
                    isPlaying = false
                    showPhoneLibrary = true
                }
            )
        }
    }

    private func sourceButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(Typography.s18)
                    .frame(width: 24)
                Text(label)
                    .font(Typography.s16Medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Typography.s14Semibold)
                    .foregroundColor(.white.opacity(0.4))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remove Confirmation

    private var removeConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(Motion.micro) {
                        showRemoveConfirmation = false
                    }
                }

            VStack(spacing: 16) {
                Text("Remove video?")
                    .font(Typography.s20Bold)
                    .foregroundColor(.white)

                Text("This video will be removed from the activity but will not be deleted from your library.")
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Button {
                        isRemoving = true
                        cleanupPlayer()
                        onVideoRemoved()
                    } label: {
                        if isRemoving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red)
                                .cornerRadius(12)
                        } else {
                            Text("Remove video")
                                .font(Typography.s17Semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRemoving)

                    Button {
                        withAnimation(Motion.micro) {
                            showRemoveConfirmation = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(Typography.s17Semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRemoving)
                }
            }
            .padding(24)
            .background(Color.sectionBackground)
            .cornerRadius(20)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Player

    private func setupPlayer() {
        guard let url = URL(string: videoUrl) else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            if let item = avPlayer.currentItem {
                let dur = item.duration.seconds
                if dur.isFinite && dur > 0 { duration = dur }
            }
        }

        avPlayer.play()
        isPlaying = true

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }
}

// MARK: - Media Library Picker (videos only)

private struct MediaLibraryPickerView: View {
    let onDismiss: () -> Void
    let onItemSelected: (MediaLibraryItem) -> Void

    private var state: AppState { AppState.shared }

    private var videoItems: [MediaLibraryItem] {
        state.orderedMedia.filter { $0.type == "video" && $0.isReady }
    }

    @State private var isLoading = true

    private var topSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 59 }
        return window.safeAreaInsets.top
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Typography.s20Semibold)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("MakeReady Library")
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, topSafeArea)

                if isLoading && videoItems.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if videoItems.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(Typography.s40)
                            .foregroundColor(.white.opacity(0.3))
                        Text("No videos in library")
                            .font(Typography.s17)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    MediaLibraryGrid(
                        items: videoItems,
                        onItemSelected: { item, _, _ in
                            onItemSelected(item)
                        }
                    )
                }
            }
        }
        .task {
            do {
                try await MediaActions().loadLibrary(type: "video")
            } catch {
                NSLog("❌ Failed to load media library: \(error)")
            }
            isLoading = false
        }
    }
}
