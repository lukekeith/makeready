//
//  VideoCaptureEngine.swift
//  MakeReady
//
//  The recorder's camera (video-recorder D5, D6, D19, D26). Each `start` records one segment file
//  straight into the draft's folder; the draft lists it only once the file is finished. A phone call,
//  backgrounding or a session interruption ends the segment and pauses, and recording never resumes by
//  itself. The live filter is drawn on the preview frames only: the movie output records the raw camera.
//

import AVFoundation
import CoreImage
import Foundation
import UIKit

enum CapturePermission: Equatable {
    case camera, microphone
}

enum VideoCaptureError: Error, Equatable {
    /// Less than `VideoCaptureEngine.minimumFreeBytes` free.
    case lowDiskSpace
    case cameraUnavailable
    /// The segment could not be recorded; nothing of it is kept.
    case recordingFailed
}

/// The camera and its movie output, behind a seam so the engine runs without a camera.
@MainActor
protocol VideoCaptureSession: AnyObject {
    /// Shows the live, filtered preview.
    var displayLayer: CALayer { get }
    var previewFilter: CIFilter? { get set }
    /// Asks on first use; afterwards answers with the decision already made.
    func requestAccess(_ permission: CapturePermission) async -> Bool
    /// Starts the camera. Does nothing when it is already running.
    func open() async throws
    func close()
    /// `onFinish` runs once, when the file is closed, whoever ended the recording.
    func startRecording(to url: URL, onFinish: @escaping @MainActor (Result<TimeInterval, Error>) -> Void)
    func stopRecording()
    func flip()
}

// MARK: - Engine

@MainActor @Observable
final class VideoCaptureEngine {
    enum State: Equatable {
        /// The camera is off.
        case idle
        /// The preview is live and the draft has no segment.
        case ready
        case recording
        /// The preview is live between segments.
        case paused
        case denied(CapturePermission)
    }

    static let minimumFreeBytes: Int64 = 500_000_000

    private(set) var state: State = .idle
    /// The recording in progress, with its finished segments; nil until the first `start`.
    private(set) var draft: VideoDraft?
    private(set) var lastError: Error?
    /// Assign a new filter for every change (a filter's parameters are read when it is assigned).
    /// Preview only: it never reaches the recording (D6).
    var previewFilter: CIFilter? {
        didSet { session.previewFilter = previewFilter }
    }
    /// Called when something other than `stopSegment` or `close` ended a segment.
    @ObservationIgnored var onInterrupted: (() -> Void)?

    var displayLayer: CALayer { session.displayLayer }

    @ObservationIgnored private let session: VideoCaptureSession
    @ObservationIgnored private let drafts: VideoDraftStore
    @ObservationIgnored private let freeBytes: () -> Int64?
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var observers = ObserverBag()
    @ObservationIgnored private var isStarting = false
    /// Bumped by `close`, so a `start` still waiting (on a permission prompt) gives up.
    @ObservationIgnored private var generation = 0
    /// The segment whose file is not closed yet, and who waits for it.
    @ObservationIgnored private var unfinishedSegment: URL?
    @ObservationIgnored private var waiters: [CheckedContinuation<Void, Never>] = []

    /// `freeBytes` answers nil when the volume cannot say; recording then starts.
    init(session: VideoCaptureSession, drafts: VideoDraftStore,
         freeBytes: @escaping () -> Int64? = VideoCaptureEngine.availableBytes,
         notificationCenter: NotificationCenter = .default) {
        self.session = session
        self.drafts = drafts
        self.freeBytes = freeBytes
        self.notificationCenter = notificationCenter
    }

    // MARK: Lifecycle

    /// Opens the preview without recording, asking for the camera and the microphone if needed. A
    /// denial sets `.denied` and does not throw (D19).
    func prepare() async throws {
        _ = try await openSession()
    }

    /// Records the next segment, opening the preview first if needed. A denial sets `.denied` and does
    /// not throw.
    func start() async throws {
        guard state != .recording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        if let free = freeBytes(), free < Self.minimumFreeBytes { throw VideoCaptureError.lowDiskSpace }
        let started = generation
        guard try await openSession() else { return }
        await waitForUnfinishedSegment()
        guard started == generation else { return }

        let draft = currentDraft()
        let url = draft.folder.appendingPathComponent("\(UUID().uuidString).mov")
        lastError = nil
        unfinishedSegment = url
        state = .recording
        session.startRecording(to: url) { [weak self] result in
            self?.segmentFinished(result, url: url, in: draft)
        }
    }

    /// Ends the segment and returns once its file is in the draft. Also waits for a segment that an
    /// interruption is still closing.
    func stopSegment() async {
        endSegment()
        await waitForUnfinishedSegment()
    }

    /// Ends any segment and turns the camera off. The draft stays on disk.
    func close() async {
        generation += 1
        await stopSegment()
        observers = ObserverBag()
        session.close()
        state = .idle
    }

    /// Switches cameras. Ignored while recording, because changing the input would end the file.
    func flip() {
        guard state == .ready || state == .paused, unfinishedSegment == nil else { return }
        session.flip()
    }

    // MARK: Interruptions (D26)

    /// Ends the segment when an interruption begins; its end changes nothing.
    func handleInterruption(began: Bool) {
        guard began, state == .recording else { return }
        endSegment()
        onInterrupted?()
    }

    private func observeInterruptions() {
        let bag = ObserverBag()
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification,
                     UIApplication.didEnterBackgroundNotification] {
            bag.add(notificationCenter, name) { [weak self] _ in
                self?.handleInterruption(began: true)
            }
        }
        bag.add(notificationCenter, AVAudioSession.interruptionNotification) { [weak self] info in
            guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            self?.handleInterruption(began: type == .began)
        }
        observers = bag
    }

    // MARK: Helpers

    /// False when a permission is denied or `close` came meanwhile.
    private func openSession() async throws -> Bool {
        let opening = generation
        for permission in [CapturePermission.camera, .microphone] {
            let granted = await session.requestAccess(permission)
            guard opening == generation else { return false }
            guard granted else {
                state = .denied(permission)
                return false
            }
        }
        try await session.open()
        guard opening == generation else {
            session.close()
            return false
        }
        switch state {
        case .idle, .denied:
            state = hasSegments ? .paused : .ready
            observeInterruptions()
        case .ready, .recording, .paused:
            break
        }
        return true
    }

    private func endSegment() {
        guard state == .recording else { return }
        state = .paused
        session.stopRecording()
    }

    private func segmentFinished(_ result: Result<TimeInterval, Error>, url: URL, in segmentDraft: VideoDraft) {
        let endedBySystem = state == .recording
        do {
            let updated = try drafts.finalize(segment: url, duration: try result.get(), in: segmentDraft)
            if draft?.id == updated.id { draft = updated }
        } catch {
            lastError = error
            Log.media.error("video segment lost: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: url) // Silent: an unlisted file is deleted on salvage too
        }
        if state == .recording || state == .paused { state = hasSegments ? .paused : .ready }
        unfinishedSegment = nil
        let finished = waiters
        waiters = []
        finished.forEach { $0.resume() }
        if endedBySystem { onInterrupted?() }
    }

    private func waitForUnfinishedSegment() async {
        guard unfinishedSegment != nil else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private var hasSegments: Bool { draft?.segments.isEmpty == false }

    /// The draft in progress, or a new one when there is none or it was discarded (Retake).
    private func currentDraft() -> VideoDraft {
        if let draft, drafts.exists(draft) { return draft }
        let begun = drafts.begin()
        draft = begun
        return begun
    }

    nonisolated static func availableBytes() -> Int64? {
        do {
            return try URL(fileURLWithPath: NSHomeDirectory())
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage
        } catch {
            Log.media.error("free space unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - Live session

@MainActor
final class LiveVideoCaptureSession: VideoCaptureSession {
    var displayLayer: CALayer { sampleLayer }
    var previewFilter: CIFilter? {
        didSet { camera.preview.setFilter(previewFilter) }
    }

    private let sampleLayer = AVSampleBufferDisplayLayer()
    private let camera: CameraPipeline
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        camera = CameraPipeline(preview: FilteredPreview(renderer: sampleLayer.sampleBufferRenderer))
    }

    func requestAccess(_ permission: CapturePermission) async -> Bool {
        await AVCaptureDevice.requestAccess(for: permission == .camera ? .video : .audio)
    }

    func open() async throws {
        follow(try await camera.open())
        // Auto-lock mid-recording stops the movie output.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func close() {
        UIApplication.shared.isIdleTimerDisabled = false
        rotationObservations = []
        rotation = nil
        camera.close()
    }

    func startRecording(to url: URL, onFinish: @escaping @MainActor (Result<TimeInterval, Error>) -> Void) {
        camera.startRecording(to: url) { [weak self] result in
            onFinish(result)
            self?.endBackgroundTime()
        }
    }

    func stopRecording() {
        beginBackgroundTime()
        camera.stopRecording()
    }

    func flip() {
        Task {
            if let device = await camera.flip() { follow(device) }
        }
    }

    /// Keeps the app running until the segment is in the draft, when backgrounding ended it (D26).
    private func beginBackgroundTime() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "video-segment") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTime() }
        }
    }

    private func endBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// Tracks the device's rotation (iphone/.claude/VIDEO_RECORDING.md): one angle for the recording,
    /// one for the preview.
    private func follow(_ device: AVCaptureDevice) {
        guard rotation?.device !== device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: sampleLayer)
        rotation = coordinator
        let camera = camera
        rotationObservations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { coordinator, _ in
                camera.setRecordingAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { coordinator, _ in
                camera.setPreviewAngle(coordinator.videoRotationAngleForHorizonLevelPreview)
            }
        ]
    }
}

/// The capture session, off the main actor: everything below runs on `queue`.
private final class CameraPipeline: NSObject, @unchecked Sendable {
    let preview: FilteredPreview

    private struct Recording {
        let onFinish: @MainActor (Result<TimeInterval, Error>) -> Void
        var stopRequested = false
    }

    private let queue = DispatchQueue(label: "org.makeready.video-capture")
    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let previewOutput = AVCaptureVideoDataOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var recording: Recording?
    private var recordingAngle: CGFloat = 90
    private var previewAngle: CGFloat = 90

    init(preview: FilteredPreview) {
        self.preview = preview
    }

    func open() async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    let device = try self.configure()
                    if !self.session.isRunning { self.session.startRunning() }
                    return device
                })
            }
        }
    }

    func close() {
        queue.async { self.session.stopRunning() }
    }

    func setRecordingAngle(_ angle: CGFloat) {
        // Used by the next segment: a file's orientation is fixed once it starts.
        queue.async { self.recordingAngle = angle }
    }

    func setPreviewAngle(_ angle: CGFloat) {
        queue.async {
            self.previewAngle = angle
            self.orient(self.previewOutput, angle: angle)
        }
    }

    func startRecording(to url: URL, onFinish: @escaping @MainActor (Result<TimeInterval, Error>) -> Void) {
        queue.async {
            guard self.session.isRunning, self.recording == nil,
                  self.movieOutput.connection(with: .video)?.isActive == true else {
                Task { @MainActor in onFinish(.failure(VideoCaptureError.recordingFailed)) }
                return
            }
            self.orient(self.movieOutput, angle: self.recordingAngle)
            self.recording = Recording(onFinish: onFinish)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async {
            guard self.recording != nil else { return }
            // Repeated once recording begins, in case the output had not started yet.
            self.recording?.stopRequested = true
            self.movieOutput.stopRecording()
        }
    }

    /// The camera now in use, or nil when the other one is not available.
    func flip() async -> AVCaptureDevice? {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.switchCamera()) }
        }
    }

    // MARK: On the queue

    private func configure() throws -> AVCaptureDevice {
        if let videoInput { return videoInput.device }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let microphone = AVCaptureDevice.default(for: .audio) else {
            throw VideoCaptureError.cameraUnavailable
        }
        let cameraInput = try AVCaptureDeviceInput(device: camera)
        let microphoneInput = try AVCaptureDeviceInput(device: microphone)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        // A configuration that failed part-way is retried by the next open, from empty.
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        for input in [cameraInput, microphoneInput] {
            guard session.canAddInput(input) else { throw VideoCaptureError.cameraUnavailable }
            session.addInput(input)
        }
        for output in [movieOutput, previewOutput] as [AVCaptureOutput] {
            guard session.canAddOutput(output) else { throw VideoCaptureError.cameraUnavailable }
            session.addOutput(output)
        }
        previewOutput.setSampleBufferDelegate(preview, queue: preview.queue)
        videoInput = cameraInput
        orient(previewOutput, angle: previewAngle)
        return camera
    }

    private func switchCamera() -> AVCaptureDevice? {
        guard let current = videoInput, recording == nil,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video,
                                                   position: current.device.position == .front ? .back : .front)
        else { return nil }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            session.removeInput(current)
            guard session.canAddInput(input) else {
                session.addInput(current)
                orient(previewOutput, angle: previewAngle)
                return nil
            }
            session.addInput(input)
            videoInput = input
            orient(previewOutput, angle: previewAngle)
            return device
        } catch {
            Log.media.error("camera not switchable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Rotates an output and mirrors it on the front camera, so the file matches the preview.
    private func orient(_ output: AVCaptureOutput, angle: CGFloat) {
        guard let connection = output.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = videoInput?.device.position == .front
        }
    }
}

extension CameraPipeline: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        queue.async {
            if self.recording?.stopRequested == true { self.movieOutput.stopRecording() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        queue.async {
            guard let recording = self.recording else { return }
            self.recording = nil
            // An interrupted recording reports an error yet may have closed its file properly.
            let finished = (error as NSError?).map {
                $0.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
            } ?? true
            Task { @MainActor in
                guard finished else {
                    recording.onFinish(.failure(error ?? VideoCaptureError.recordingFailed))
                    return
                }
                do {
                    let seconds = try await AVURLAsset(url: outputFileURL).load(.duration).seconds
                    guard seconds.isFinite, seconds > 0 else { throw VideoCaptureError.recordingFailed }
                    recording.onFinish(.success(seconds))
                } catch {
                    recording.onFinish(.failure(error))
                }
            }
        }
    }
}

/// Draws camera frames, with the live filter, into the display layer (D6). Its output never goes back
/// to the capture session, so a dropped frame here cannot reach the file.
private final class FilteredPreview: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "org.makeready.video-preview", qos: .userInteractive)

    private let renderer: AVSampleBufferVideoRenderer
    private let context = CIContext()
    private let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)
    private var filter: CIFilter?
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero

    init(renderer: AVSampleBufferVideoRenderer) {
        self.renderer = renderer
    }

    /// Takes a copy, so the caller's filter is never shared with the preview queue.
    func setFilter(_ filter: CIFilter?) {
        let copy = filter?.copy() as? CIFilter
        queue.async { self.filter = copy }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if renderer.status == .failed || renderer.requiresFlushToResumeDecoding { renderer.flush() }
        guard renderer.isReadyForMoreMediaData else { return }
        let frame = filtered(sampleBuffer) ?? sampleBuffer
        showImmediately(frame)
        renderer.enqueue(frame)
    }

    /// The frame with the filter drawn in; nil with no filter, or when it cannot be drawn.
    private func filtered(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let filter, let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let image = CIImage(cvPixelBuffer: source)
        filter.setValue(image, forKey: kCIInputImageKey)
        guard let result = filter.outputImage, let target = pixelBuffer(size: image.extent.size) else { return nil }
        CVBufferPropagateAttachments(source, target)
        context.render(result, to: target, bounds: image.extent, colorSpace: colorSpace)

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: target, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer),
                                        presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                        decodeTimeStamp: .invalid)
        guard let format else { return nil }
        var frame: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: target, formatDescription: format,
                                                 sampleTiming: &timing, sampleBufferOut: &frame)
        return frame
    }

    private func pixelBuffer(size: CGSize) -> CVPixelBuffer? {
        if pool == nil || poolSize != size {
            let attributes: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: Int(size.width),
                kCVPixelBufferHeightKey: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]()
            ]
            pool = nil
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
            poolSize = size
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private func showImmediately(_ frame: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(frame, createIfNecessary: true) as? [NSMutableDictionary],
              let first = attachments.first else { return }
        first[kCMSampleAttachmentKey_DisplayImmediately] = true
    }
}
