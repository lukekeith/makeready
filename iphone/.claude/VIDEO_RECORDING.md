# Video Recording on iOS

## Video Orientation - The Correct Approach

### Problem
Videos recorded in portrait mode display sideways in preview and after export.

### Root Cause
iPhone camera sensors naturally record in landscape orientation (the raw pixels are landscape). The camera system writes rotation metadata (`preferredTransform`) to indicate how the video should be displayed.

**Common mistakes that DON'T work:**
- Using `UIDevice.current.orientation` - unreliable, doesn't update consistently
- Using `UIWindowScene.interfaceOrientation` - doesn't reflect actual device orientation
- Comparing `naturalSize.width > naturalSize.height` - always wrong because sensor is landscape
- Using CMMotion/accelerometer - overcomplicated and error-prone

### Solution: AVCaptureDevice.RotationCoordinator (iOS 17+)

The correct approach is to use `AVCaptureDevice.RotationCoordinator` with KVO observation on `videoRotationAngleForHorizonLevelCapture`.

#### 1. Recording with Correct Orientation

In your camera manager class:

```swift
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var currentVideoRotationAngle: CGFloat = 90 // Default to portrait

    private func setupRotationCoordinator() {
        guard let videoDevice = videoDeviceInput?.device else { return }

        // Create coordinator for the video device
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(
            device: videoDevice,
            previewLayer: nil
        )

        // Get initial rotation angle
        if let coordinator = rotationCoordinator {
            currentVideoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        }

        // Observe rotation changes
        rotationObservation = rotationCoordinator?.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] coordinator, _ in
            Task { @MainActor in
                self?.currentVideoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
            }
        }
    }

    func startRecording() {
        // Apply rotation angle to the video connection before recording
        if let connection = movieFileOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(currentVideoRotationAngle) {
                connection.videoRotationAngle = currentVideoRotationAngle
            }
        }

        // Start recording...
        movieFileOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    func cleanup() {
        rotationObservation?.invalidate()
        rotationObservation = nil
        rotationCoordinator = nil
    }
}
```

#### 2. Exporting with Correct Orientation

When exporting/uploading videos, apply `preferredTransform` directly:

```swift
private func exportAsset(_ asset: AVAsset, completion: @escaping (Result<URL, Error>) -> Void) {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".mov")

    Task {
        do {
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                completion(.failure(VideoError.uploadFailed("No video track found")))
                return
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)

            // Calculate render size by applying the transform
            let transformedSize = naturalSize.applying(preferredTransform)
            let renderSize = CGSize(
                width: abs(transformedSize.width),
                height: abs(transformedSize.height)
            )

            // Create video composition
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = renderSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            // Apply preferredTransform directly - it already has correct orientation
            layerInstruction.setTransform(preferredTransform, at: .zero)

            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]

            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                completion(.failure(VideoError.uploadFailed("Failed to create export session")))
                return
            }

            exportSession.outputURL = tempURL
            exportSession.outputFileType = .mov
            exportSession.videoComposition = videoComposition
            exportSession.shouldOptimizeForNetworkUse = true

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    completion(.success(tempURL))
                case .failed:
                    completion(.failure(VideoError.uploadFailed(
                        "Export failed: \(exportSession.error?.localizedDescription ?? "Unknown")"
                    )))
                default:
                    completion(.failure(VideoError.uploadFailed("Export ended unexpectedly")))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
```

### Key Points

1. **Use RotationCoordinator** - It automatically tracks device orientation and provides the correct rotation angle for video recording.

2. **Apply rotation before recording** - Set `connection.videoRotationAngle` on the AVCaptureConnection before starting to record.

3. **Trust preferredTransform** - When exporting, the video track's `preferredTransform` already contains the correct rotation. Just apply it directly.

4. **Don't try to detect orientation yourself** - The system handles this correctly. Manual detection (width/height comparisons, accelerometer, etc.) will fail.

### References

- [AVCaptureDevice.RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)
- [videoRotationAngleForHorizonLevelCapture](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelcapture)
