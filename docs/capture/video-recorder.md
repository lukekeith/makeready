# Video Recorder

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoRecorderPage.swift` (+ `iphone/MakeReady/Pages/Video/CustomVideoRecorder.swift`)
**Type:** screen (camera capture, presented as `fullScreenCover`)
**Screen states:** idle/ready (not recording) / recording / paused (iOS 18+) / processing (exporting) / post-recording preview / permission-denied (alert) / teleprompter-editor (sheet)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `TeleprompterOverlay` | default | Mounted in `CustomVideoRecorder` over the camera preview when `showTeleprompter` is on and script is non-empty. See `teleprompter.md`. |
| `RecordButton` | default | Local sub-view in `VideoRecorderPage.swift` (outer ring + circle/square inner). Note: `CustomVideoRecorder` actually uses its own inline `recordStopButton`, not this component. |
| `CameraViewControllerRepresentable` | default | `UIImagePickerController` (system camera) wrapper in `VideoRecorderPage.swift`. |
| `CameraPreviewView` | default | `UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer` (used by `CustomVideoRecorder`). |

## Notes
- `VideoRecorderPage` is the lightweight system-camera (`UIImagePickerController`) recorder; `CustomVideoRecorder` is the full AVFoundation recorder with teleprompter, flash, flip, pause, and timer. They are separate implementations in the two files.
- No shared `Components/` inventory components are used — all chrome (top controls, record/stop button, blur buttons, timer badge, bottom controls, post-recording preview header) is hand-rolled in `CustomVideoRecorder`.
- This entire screen is camera/AVFoundation hardware (live `AVCaptureSession`); the camera preview will not render in the Simulator or a static capture. Capturable surfaces are limited to the chrome overlays and the "Processing video..." and post-recording preview states.
- The teleprompter editor is a system `.sheet` with `Toggle`, `Slider`, and `TextEditor` (raw SwiftUI primitives).
