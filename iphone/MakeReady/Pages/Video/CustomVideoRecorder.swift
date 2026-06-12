//
//  CustomVideoRecorder.swift
//  MakeReady
//
//  Full AVFoundation-based camera with recording, teleprompter, and controls
//

import SwiftUI
import AVFoundation
import AVKit
import Photos

// MARK: - Custom Video Recorder 

struct CustomVideoRecorder: View {
    @Binding var isPresented: Bool
    var onVideoRecorded: ((URL) -> Void)?
    var onOpenLibrary: (() -> Void)?
    var onDismiss: (() -> Void)?
    /// Safe area top inset passed from parent when embedded inside .ignoresSafeArea() containers.
    /// When nil, reads from GeometryReader (works for standalone fullScreenCover usage).
    var topSafeArea: CGFloat?
    /// When false, the camera session is stopped to save power (e.g. when library grid is visible).
    var isCameraActive: Bool = true
    /// When true, the recorder's own Color.appBackground is removed so the parent can control
    /// the background (e.g. for fading during swipe-to-dismiss in VideoActivityPicker).
    var transparentBackground: Bool = false

    @StateObject private var cameraManager = CameraManager()
    @State private var showTeleprompterEditor = false
    @State private var showSettings = false
    @State private var lastRecordedThumbnail: UIImage?
    @State private var libraryThumbnail: UIImage?

    // Post-recording preview state
    @State private var showPostRecordingPreview = false
    @State private var previewVideoURL: URL?
    @State private var didPressNext = false  // Track if user confirmed with Next

    var body: some View {
        ZStack {
            if !transparentBackground {
                Color.appBackground
                    .ignoresSafeArea()
            }

            if showPostRecordingPreview, let videoURL = previewVideoURL {
                // Post-recording preview
                postRecordingPreview(videoURL: videoURL)
            } else if cameraManager.isExportingForPreview {
                // Processing video after recording
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Processing video...")
                        .font(Typography.s17)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                // Recording view
                VStack(spacing: 0) {
                    // Camera preview area
                    cameraPreviewArea

                    // Bottom controls (hidden while recording)
                    if !cameraManager.isRecording {
                        bottomControls
                    }
                }
            }
        }
        .task {
            await cameraManager.requestPermissions()
            if isCameraActive {
                cameraManager.startSession()
            }
        }
        .onChange(of: isCameraActive) { _, active in
            if active {
                cameraManager.startSession()
            } else {
                cameraManager.stopSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
            // Clean up temp file ONLY if user didn't press Next (dismissed or cancelled)
            // If Next was pressed, the file is needed for upload
            if !didPressNext, let tempURL = previewVideoURL {
                try? FileManager.default.removeItem(at: tempURL)
                NSLog("🎬 Cleaned up temp file (user cancelled)")
            }
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, newURL in
            if let url = newURL {
                previewVideoURL = url
                showPostRecordingPreview = true
            }
        }
        .sheet(isPresented: $showTeleprompterEditor) {
            teleprompterEditorSheet
        }
        .alert("Camera Access Required", isPresented: $cameraManager.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Please allow camera and microphone access to record videos.")
        }
    }

    // MARK: - Camera Preview Area

    /// Reliable safe area top inset — uses passed-in value, or reads from UIKit window.
    private var resolvedTopSafeArea: CGFloat {
        if let passed = topSafeArea, passed > 0 { return passed }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 59 }
        return window.safeAreaInsets.top
    }

    private var cameraPreviewArea: some View {
        GeometryReader { geometry in
            let safeTop = resolvedTopSafeArea

            ZStack {
                // Camera preview (disable hit testing so buttons work)
                CameraPreviewView(session: cameraManager.session)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, safeTop + 16)
                    .allowsHitTesting(false)

                // Overlay content
                VStack {
                    // Top controls (hidden while recording)
                    if !cameraManager.isRecording {
                        topControls
                            .padding(.horizontal, 32)
                            .padding(.top, safeTop + 16)
                    } else {
                        // Recording timer at top
                        recordingTimerBadge
                            .padding(.top, safeTop + 16)
                    }

                    Spacer()

                    // Teleprompter overlay (disable hit testing so buttons work)
                    if cameraManager.showTeleprompter && !cameraManager.teleprompterText.isEmpty {
                        TeleprompterOverlay(
                            text: cameraManager.teleprompterText,
                            isScrolling: cameraManager.isRecording && !cameraManager.isPaused,
                            scrollSpeed: cameraManager.teleprompterSpeed
                        )
                        .padding(.horizontal, 32)
                        .padding(.bottom, 120)
                        .allowsHitTesting(false)
                    }

                    // Bottom buttons - always show record/stop button, flanking buttons appear when recording
                    recordingButtonsRow
                        .padding(.bottom, cameraManager.isRecording ? 17 : 24)
                }
            }
        }
    }

    // MARK: - Recording Timer Badge

    private var recordingTimerBadge: some View {
        Text(formatTimeHHMMSS(cameraManager.elapsedTime))
            .font(Typography.s17Bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 1.0, green: 0.008, blue: 0.176)) // #FF022D
            .cornerRadius(4)
    }

    private func formatTimeHHMMSS(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, mins, secs)
    }

    // MARK: - Recording Buttons Row

    private var recordingButtonsRow: some View {
        HStack(spacing: 0) {
            // Pause button (left) - only shown when recording and iOS 18+
            if cameraManager.isRecording && cameraManager.canPause {
                blurButton(size: 48) {
                    Button {
                        if cameraManager.isPaused {
                            cameraManager.resumeRecording()
                        } else {
                            cameraManager.pauseRecording()
                        }
                    } label: {
                        Image(systemName: cameraManager.isPaused ? "play.fill" : "pause.fill")
                            .font(Typography.s24)
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            } else if cameraManager.isRecording {
                // Placeholder for layout balance on iOS 17 when recording
                Color.clear
                    .frame(width: 48, height: 48)
            }

            if cameraManager.isRecording {
                Spacer()
            }

            // Center record/stop button (always visible)
            recordStopButton

            if cameraManager.isRecording {
                Spacer()
            }

            // Flip camera button (right) - only shown when recording
            if cameraManager.isRecording {
                blurButton(size: 48) {
                    Button {
                        cameraManager.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(Typography.s24)
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, cameraManager.isRecording ? 56 : 0)
        .animation(Motion.standard, value: cameraManager.isRecording)
    }

    // MARK: - Blur Button Helper

    @ViewBuilder
    private func blurButton<Content: View>(size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
            content()
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }

    // MARK: - Top Controls (shown when NOT recording)

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(Typography.s20Semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Flash toggle (centered)
            Button {
                cameraManager.toggleFlash()
            } label: {
                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(Typography.s20)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Settings (placeholder)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(Typography.s20)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - Record/Stop Button (Animated)

    private var recordStopButton: some View {
        ZStack {
            // Background: stroke when not recording, blur material when recording
            if cameraManager.isRecording {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.001)) // Nearly invisible fill for hit testing
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
            }

            // Inner shape: circle when not recording, rounded square when recording
            if cameraManager.isRecording {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 1.0, green: 0.008, blue: 0.176)) // #FF022D
                    .frame(width: 36, height: 36)
            } else {
                Circle()
                    .fill(Color(red: 1.0, green: 0.008, blue: 0.176)) // #FF022D
                    .frame(width: 64, height: 64)
            }
        }
        .frame(width: 80, height: 80)
        .contentShape(Rectangle()) // Use Rectangle for more reliable hit testing
        .onTapGesture {
            NSLog("🎬 Record/Stop button tapped. isRecording: \(cameraManager.isRecording)")
            cameraManager.toggleRecording()
        }
        .animation(Motion.micro, value: cameraManager.isRecording)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Library thumbnail / recent recording thumbnail
            Button {
                onOpenLibrary?()
            } label: {
                if let thumbnail = lastRecordedThumbnail ?? libraryThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                }
            }
            .buttonStyle(.plain)
            .task {
                await loadLibraryThumbnail()
            }

            Spacer()

            // Teleprompter button
            Button {
                showTeleprompterEditor = true
            } label: {
                HStack(spacing: 4) {
                    Text("Teleprompter")
                        .font(Typography.s15Bold)
                        .foregroundColor(.white)

                    Image(systemName: "chevron.up")
                        .font(Typography.s12Semibold)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Camera flip button
            Button {
                cameraManager.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(Typography.s20)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .background(transparentBackground ? Color.clear : Color.appBackground)
    }

    // MARK: - Load Library Thumbnail

    private func loadLibraryThumbnail() async {
        let manager = PhotoLibraryManager.shared
        // Ensure authorized (fire-and-forget pattern — returns instantly if already authorized)
        await manager.ensureAuthorized()
        // Read first video reactively — store manages its own data
        if let firstAsset = manager.firstVideoAsset?.asset {
            let size = CGSize(width: 80, height: 80)
            libraryThumbnail = await manager.thumbnail(for: firstAsset, size: size)
        }
    }

    // MARK: - Post-Recording Preview

    private func postRecordingPreview(videoURL: URL) -> some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    // Re-record button
                    Button {
                        // Clear preview and restart
                        showPostRecordingPreview = false
                        previewVideoURL = nil
                        cameraManager.recordedVideoURL = nil
                        // Delete the temp file
                        try? FileManager.default.removeItem(at: videoURL)
                    } label: {
                        Text("Re-record")
                            .font(Typography.s17)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Preview")
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Spacer()

                    // Next button
                    Button {
                        // Mark that user confirmed - don't delete temp file in onDisappear
                        didPressNext = true

                        // Save to photo library on final confirmation
                        Task {
                            _ = await cameraManager.saveToPhotoLibrary(url: videoURL)
                        }
                        onVideoRecorded?(videoURL)
                        isPresented = false
                    } label: {
                        Text("Next")
                            .font(Typography.s17)
                            .foregroundColor(.brandPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .padding(.top, resolvedTopSafeArea)

                // Video player
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: - Teleprompter Editor Sheet

    private var teleprompterEditorSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Toggle
                    Toggle("Show Teleprompter", isOn: $cameraManager.showTeleprompter)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)

                    // Speed slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scroll Speed")
                            .font(Typography.s15)
                            .foregroundColor(.white.opacity(0.7))

                        Slider(value: $cameraManager.teleprompterSpeed, in: 0.5...3.0, step: 0.1)
                            .tint(.brandPrimary)
                    }
                    .padding(.horizontal, 16)

                    // Text editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Script")
                            .font(Typography.s15)
                            .foregroundColor(.white.opacity(0.7))

                        TextEditor(text: $cameraManager.teleprompterText)
                            .scrollContentBackground(.hidden)
                            .background(Color.sectionBackground)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .frame(minHeight: 200)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Teleprompter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showTeleprompterEditor = false
                    }
                    .foregroundColor(.brandPrimary)
                }
            }
        }
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var isFlashOn = false
    @Published var recordedVideoURL: URL?
    @Published var showPermissionAlert = false
    @Published var showTeleprompter = false
    @Published var teleprompterText = ""
    @Published var teleprompterSpeed: Double = 1.0
    @Published var isExportingForPreview = false

    // Time tracking
    @Published var elapsedTime: TimeInterval = 0
    @Published var maxDuration: TimeInterval = 300  // 5 minutes
    private var recordingTimer: Timer?
    private var pausedTime: TimeInterval = 0  // Track time when paused

    // AVFoundation objects are thread-safe, mark as nonisolated to allow background queue access
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private var currentCamera: AVCaptureDevice.Position = .front

    // iOS 17+ RotationCoordinator for proper video orientation
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var currentVideoRotationAngle: CGFloat = 90 // Default to portrait

    // MARK: - Permissions

    func requestPermissions() async {
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)

        if !videoGranted || !audioGranted {
            showPermissionAlert = true
        }
    }

    // MARK: - Session Management

    func startSession() {
        guard !session.isRunning else { return }

        // Prevent the screen from auto-locking while the recorder is active.
        // Without this, iOS sleeps mid-recording and AVCaptureMovieFileOutput
        // silently stops — QA reported no way to recover.
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            // Perform session setup on background
            await performSessionStart()

            // Setup rotation coordinator on main actor (we're back on MainActor here)
            setupRotationCoordinator()
        }
    }

    /// Performs session setup and start on background thread
    nonisolated private func performSessionStart() async {
        setupSession()
        session.startRunning()
    }

    func stopSession() {
        guard session.isRunning else { return }

        // Re-enable auto-lock now that the recorder is closing.
        UIApplication.shared.isIdleTimerDisabled = false

        // Clean up rotation observation
        rotationObservation?.invalidate()
        rotationObservation = nil
        rotationCoordinator = nil

        Task {
            await performSessionStop()
        }
    }

    /// Stops the session on background thread
    nonisolated private func performSessionStop() async {
        session.stopRunning()
    }

    // MARK: - Rotation Coordinator (iOS 17+)

    private func setupRotationCoordinator() {
        guard let videoDevice = videoDeviceInput?.device else {
            NSLog("🎬 No video device for rotation coordinator")
            return
        }

        // Create rotation coordinator - it monitors device orientation automatically
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: videoDevice, previewLayer: nil)

        // Get initial rotation angle
        if let coordinator = rotationCoordinator {
            currentVideoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
            NSLog("🎬 Initial rotation angle: \(currentVideoRotationAngle)")
        }

        // Observe rotation changes using KVO
        rotationObservation = rotationCoordinator?.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coordinator, change in
            Task { @MainActor in
                self?.currentVideoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
                NSLog("🎬 Rotation angle changed: \(coordinator.videoRotationAngleForHorizonLevelCapture)")
            }
        }
    }

    nonisolated private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera) {
            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    videoDeviceInput = input
                }
            } catch {
                print("Error creating video input: \(error)")
            }
        }

        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let input = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    audioDeviceInput = input
                }
            } catch {
                print("Error creating audio input: \(error)")
            }
        }

        // Add movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            // Update orientation on main thread since it accesses UIApplication
            Task { @MainActor [weak self] in
                self?.updateVideoOrientation()
            }
        }

        session.commitConfiguration()
    }

    /// Update video orientation using RotationCoordinator's angle
    private func updateVideoOrientation() {
        guard let connection = movieOutput.connection(with: .video) else {
            NSLog("🎬 No video connection available")
            return
        }

        // Use the angle from RotationCoordinator (iOS 17+ proper way)
        let rotationAngle = currentVideoRotationAngle

        // For front camera, enable mirroring so the video looks natural (like a mirror)
        if currentCamera == .front {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
                NSLog("🎬 Front camera: enabled video mirroring")
            }
        } else {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }

        NSLog("🎬 RotationCoordinator angle: \(rotationAngle)")
        NSLog("🎬 Camera: \(currentCamera == .front ? "front" : "back")")

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
            NSLog("🎬 ✅ Set video rotation angle to \(rotationAngle)")
        } else {
            NSLog("🎬 ⚠️ Rotation angle \(rotationAngle) not supported, trying nearest...")
            // Find the nearest supported angle
            let supportedAngles: [CGFloat] = [0, 90, 180, 270].filter { connection.isVideoRotationAngleSupported($0) }
            if let nearest = supportedAngles.min(by: { abs($0 - rotationAngle) < abs($1 - rotationAngle) }) {
                connection.videoRotationAngle = nearest
                NSLog("🎬 ✅ Set nearest supported angle: \(nearest)")
            }
        }

        // Verify the rotation was actually set
        NSLog("🎬 After setting, connection rotation is: \(connection.videoRotationAngle)")
    }

    // MARK: - Recording

    func toggleRecording() {
        NSLog("🎬 toggleRecording called. isRecording: \(isRecording), movieOutput.isRecording: \(movieOutput.isRecording)")
        if isRecording {
            NSLog("🎬 toggleRecording: isRecording=true, will call stopRecording()")
            stopRecording()
        } else {
            NSLog("🎬 toggleRecording: isRecording=false, will call startRecording()")
            startRecording()
        }
        NSLog("🎬 toggleRecording finished. isRecording is now: \(isRecording)")
    }

    private func startRecording() {
        NSLog("🎬 startRecording called. movieOutput.isRecording: \(movieOutput.isRecording)")
        guard !movieOutput.isRecording else {
            NSLog("🎬 startRecording: Already recording, returning")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let filename = UUID().uuidString + ".mov"
        let outputURL = tempDir.appendingPathComponent(filename)

        // Set hard limit as safety net
        movieOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 1)

        // Update orientation right before recording to capture current device position
        updateVideoOrientation()

        // Set state BEFORE starting (so UI updates immediately)
        isRecording = true
        startTimer()

        NSLog("🎬 Starting recording to: \(outputURL)")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        // Check if recording actually started (simulator might fail)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.isRecording && !self.movieOutput.isRecording {
                NSLog("🎬 Recording failed to start (simulator?). Keeping UI in recording state for testing.")
                // Don't reset state - let user test the stop button
            }
        }
    }

    private func stopRecording() {
        NSLog("🎬 stopRecording called. isRecording: \(isRecording), movieOutput.isRecording: \(movieOutput.isRecording)")

        // Always stop timer and reset pause state
        stopTimer()
        isPaused = false
        elapsedTime = 0  // Reset timer display

        if movieOutput.isRecording {
            // Normal case: actually recording
            NSLog("🎬 stopRecording: Calling movieOutput.stopRecording()")
            movieOutput.stopRecording()
            // isRecording will be set to false by the delegate
        } else {
            // Simulator case or recording failed: force state reset
            NSLog("🎬 stopRecording: movieOutput not recording. Resetting state to false.")
            isRecording = false
            NSLog("🎬 stopRecording: isRecording is now: \(isRecording)")
            // Note: No video file to show, so preview won't appear
            // The view will return to non-recording state
        }
    }

    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        if #available(iOS 18.0, *) {
            movieOutput.pauseRecording()
            isPaused = true
            pausedTime = elapsedTime
            stopTimer()
        }
    }

    func resumeRecording() {
        guard isRecording && isPaused else { return }
        if #available(iOS 18.0, *) {
            movieOutput.resumeRecording()
            isPaused = false
            startTimer(from: pausedTime)
        }
    }

    var canPause: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }

    // MARK: - Timer

    private func startTimer(from startTime: TimeInterval = 0) {
        elapsedTime = startTime
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.elapsedTime += 1
                if self.elapsedTime >= self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Flash

    func toggleFlash() {
        guard let device = videoDeviceInput?.device,
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error)")
        }
    }

    // MARK: - Save to Photo Library

    func saveToPhotoLibrary(url: URL) async -> Bool {
        // Request permission if needed
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            print("Photo library access not granted")
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            print("Video saved to photo library")
            return true
        } catch {
            print("Failed to save video to photo library: \(error)")
            return false
        }
    }

    // MARK: - Camera Flip

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = currentCamera == .back ? .front : .back

        Task {
            // Perform camera switch on background thread
            let newInput = await performCameraSwitch(to: newPosition)

            // Update state on main actor (we're already isolated to MainActor in this Task)
            currentCamera = newPosition
            videoDeviceInput = newInput
            isFlashOn = false
            rotationObservation?.invalidate()
            setupRotationCoordinator()
            updateVideoOrientation()
        }
    }

    /// Performs the actual camera switch on a background thread
    /// Returns the new video input device
    nonisolated private func performCameraSwitch(to position: AVCaptureDevice.Position) async -> AVCaptureDeviceInput? {
        session.beginConfiguration()

        // Remove current input
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }

        // Add new input
        var newInput: AVCaptureDeviceInput?
        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            do {
                let input = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    newInput = input
                }
            } catch {
                print("Error switching camera: \(error)")
            }
        }

        session.commitConfiguration()
        return newInput
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        NSLog("🎬 Delegate: Recording STARTED to \(fileURL)")
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        NSLog("🎬 Delegate: Recording FINISHED. Error: \(String(describing: error))")
        Task { @MainActor in
            isRecording = false
            NSLog("🎬 Delegate: Set isRecording = false")

            if let error = error {
                NSLog("🎬 Delegate: Recording error: \(error)")
                return
            }

            // Export video with orientation baked in before showing preview
            NSLog("🎬 Delegate: Exporting video with orientation correction...")
            isExportingForPreview = true

            do {
                let exportedURL = try await VideoActions().exportVideoWithOrientation(from: outputFileURL)
                NSLog("🎬 Delegate: Export complete, setting preview URL")

                // Delete the original raw recording
                try? FileManager.default.removeItem(at: outputFileURL)

                recordedVideoURL = exportedURL
            } catch {
                NSLog("🎬 Delegate: Export failed: \(error), using original file")
                // Fall back to original file if export fails
                recordedVideoURL = outputFileURL
            }

            isExportingForPreview = false
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Session is already set
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            (layer as? AVCaptureVideoPreviewLayer)?.session = session
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        (layer as? AVCaptureVideoPreviewLayer)?.videoGravity = .resizeAspectFill
    }
}

// MARK: - Preview

#Preview {
    CustomVideoRecorder(isPresented: .constant(true))
}
