//
//  ActivityVideoPlayer.swift
//  MakeReady
//
//  Full-screen player for video activities that already have a video.
//  Shows close/trash/play controls, scrubber, swipe-to-dismiss,
//  and removal confirmation overlay.
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - AVPlayerLayer UIView wrapper (respects cornerRadius)

/// UIViewRepresentable that renders video via AVPlayerLayer directly,
/// allowing UIKit-level cornerRadius clipping that SwiftUI's VideoPlayer ignores.
struct ClippedVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let cornerRadius: CGFloat
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
        uiView.layer.cornerRadius = cornerRadius
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

struct ActivityVideoPlayer: View {
    let activity: StudyActivity
    let onDismiss: () -> Void
    let onVideoRemoved: (StudyActivity) -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false
    @State private var isMuted = false
    @State private var timeObserver: Any?

    @State private var dragOffset: CGFloat = 0

    /// Safe area top inset read from UIKit window — reliable inside .ignoresSafeArea().
    private var topSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 59 }
        return window.safeAreaInsets.top
    }

    private var backgroundOpacity: Double {
        let screenHeight = Screen.bounds.height
        guard screenHeight > 0 else { return 1 }
        return max(0, 1 - Double(dragOffset) / Double(screenHeight) * 1.5)
    }

    var body: some View {
        ZStack {
            // Background — matches recorder's Color.appBackground so rounded corners are visible
            Color.appBackground.opacity(backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Video area — GeometryReader takes available space (matches recorder pattern)
                GeometryReader { geometry in
                    ZStack {
                        // Video player with same padding as recorder's camera preview
                        if let player = player {
                            ClippedVideoPlayer(player: player, cornerRadius: 16)
                                .padding(.horizontal, 16)
                                .padding(.top, topSafeArea + 16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .overlay(ProgressView().tint(.white))
                                .padding(.horizontal, 16)
                                .padding(.top, topSafeArea + 16)
                        }

                        // Overlay controls — same coordinate space as video
                        videoOverlayControls
                    }
                }

                // Scrubber bar below video (matches recorder's bottomControls position)
                scrubberBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 32)
            }
            .offset(y: dragOffset)

            // Removal confirmation overlay
            if showRemoveConfirmation {
                removeConfirmationOverlay
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .gesture(
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
                        // Dismiss — spring with initial velocity matching the flick
                        let remaining = screenHeight - dragOffset
                        let initialVelocity = remaining > 0 ? velocityPts / remaining : 1
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dragOffset = screenHeight
                        }
                        // Estimate settle time based on velocity
                        let settleTime = max(0.2, min(0.4, Double(remaining) / max(Double(velocityPts), 800)))
                        DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) {
                            cleanupPlayer()
                            onDismiss()
                        }
                    } else {
                        // Snap back — spring with velocity going upward
                        let initialVelocity = dragOffset > 0 ? -velocityPts / dragOffset : 0
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dragOffset = 0
                        }
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

    // MARK: - Video Overlay Controls

    private var videoOverlayControls: some View {
        ZStack {
            VStack {
                HStack {
                    // Close button (top-left)
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

                    // Trash button (top-right)
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

                // Mute toggle (bottom-right) — tap to toggle, two states only
                HStack {
                    Spacer()
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

            // Center play/pause button
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
        .onTapGesture {
            togglePlayPause()
        }
    }

    // MARK: - Scrubber Bar

    private var scrubberBar: some View {
        HStack(spacing: 12) {
            // Play/pause icon
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(Typography.s16)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            // Slider
            Slider(
                value: Binding(
                    get: { duration > 0 ? currentTime / duration : 0 },
                    set: { newValue in
                        let targetTime = newValue * duration
                        currentTime = targetTime
                        player?.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
                    }
                ),
                in: 0...1
            )
            .tint(.white)

            // Time label
            Text(formatTime(currentTime))
                .font(Typography.s13MediumMono)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 44)
    }

    // MARK: - Remove Confirmation Overlay

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
                        removeVideo()
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

    // MARK: - Actions

    private func setupPlayer() {
        guard let urlString = activity.videoUrl,
              let url = URL(string: urlString) else { return }

        // Activate playback audio session so audio plays regardless of mute switch
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Observe time
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            if let item = avPlayer.currentItem {
                let dur = item.duration.seconds
                if dur.isFinite && dur > 0 {
                    duration = dur
                }
            }
        }

        // Auto-play
        avPlayer.play()
        isPlaying = true

        // Loop when finished
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
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func removeVideo() {
        isRemoving = true
        Task {
            do {
                let updatedActivity = try await ProgramActions().removeActivityVideo(activityId: activity.id)
                await MainActor.run {
                    isRemoving = false
                    showRemoveConfirmation = false
                    cleanupPlayer()
                    onVideoRemoved(updatedActivity)
                }
            } catch {
                await MainActor.run {
                    isRemoving = false
                    // User just confirmed Remove — surface, retry re-runs the
                    // same idempotent remove-by-activity-id.
                    AppState.shared.recordError(
                        error,
                        context: "ActivityVideoPlayer.removeVideo",
                        surface: true,
                        friendlyMessage: "Couldn't remove the video",
                        retry: { removeVideo() }
                    )
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview("Portrait") {
    // Portrait 9:16 — waterfall between green hills (Mixkit, CC0)
    let url = URL(string: "https://assets.mixkit.co/active_storage/video_items/100174/1721166924/100174-video-720.mp4")!
    let player = AVPlayer(url: url)

    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 0) {
            GeometryReader { _ in
                ZStack {
                    ClippedVideoPlayer(player: player, cornerRadius: 16)
                        .padding(.horizontal, 16)
                        .padding(.top, 75)

                    VStack {
                        HStack {
                            Image(systemName: "xmark")
                                .font(Typography.s20Semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Image(systemName: "trash")
                                .font(Typography.s20)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 75)

                        Spacer()

                        HStack {
                            Spacer()
                            Image(systemName: "speaker.wave.2.fill")
                                .font(Typography.s20)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }

                    Image(systemName: "play.fill")
                        .font(Typography.s36)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(Typography.s16)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                Slider(value: .constant(0.35), in: 0...1).tint(.white)
                Text("0:10")
                    .font(Typography.s13MediumMono)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
    }
    .ignoresSafeArea()
}

#Preview("Landscape") {
    // Landscape 16:9 — waterfall in forest (Mixkit, CC0)
    let url = URL(string: "https://assets.mixkit.co/videos/2213/2213-720.mp4")!
    let player = AVPlayer(url: url)

    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 0) {
            GeometryReader { _ in
                ZStack {
                    ClippedVideoPlayer(player: player, cornerRadius: 16)
                        .padding(.horizontal, 16)
                        .padding(.top, 75)

                    VStack {
                        HStack {
                            Image(systemName: "xmark")
                                .font(Typography.s20Semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Image(systemName: "trash")
                                .font(Typography.s20)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 75)

                        Spacer()

                        HStack {
                            Spacer()
                            Image(systemName: "speaker.wave.2.fill")
                                .font(Typography.s20)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }

                    Image(systemName: "play.fill")
                        .font(Typography.s36)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(Typography.s16)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                Slider(value: .constant(0.65), in: 0...1).tint(.white)
                Text("0:10")
                    .font(Typography.s13MediumMono)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
    }
    .ignoresSafeArea()
}
