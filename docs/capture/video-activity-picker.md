# Video Activity Picker

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoActivityPicker.swift`
**Type:** overlay/modal (two-panel `fullScreenCover` from EditDay; vertical recorder ↔ library stack)
**Screen states:** recorder panel (camera) / library panel (Photos grid) / mid-transition (swipe up/down) / swipe-to-dismiss (background fade) / album menu open

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `CustomVideoRecorder` | `transparentBackground: true`, `isCameraActive: !showingLibrary`, with `onOpenLibrary`/`onDismiss`/`topSafeArea` | Panel 1. Camera session is stopped while the library panel is showing to save power. See `video-recorder.md`. |
| `VideoLibraryGrid` | default | Panel 2. The UIKit `UICollectionView`-backed device-Photos grid (custom `VideoThumbnailCell` + date scrubber) defined in `VideoLibraryGrid.swift`; tapping a cell opens the `VideoPreviewOverlay`. See `video-preview.md`. |

## Notes
- The library header (album-selection `Menu` + chevron) and the drag/transition choreography are hand-rolled in this file; no shared `Components/` inventory components are used directly.
- This is a gesture-heavy two-panel container: `@GestureState` drives jitter-free swipe-up (reveal library), pull-down on the library header (return to recorder), and swipe-down-to-dismiss with a fading background.
- The recorder panel is a live `AVCaptureSession` (won't render in static captures); the library panel depends on device Photos media. Tapping a library thumbnail presents `VideoPreviewOverlayView` (pure UIKit), documented in `video-preview.md`.
