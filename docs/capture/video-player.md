# Video Player

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoPlayerPage.swift` (+ `iphone/MakeReady/Pages/Video/ActivityVideoPlayer.swift`)
**Type:** overlay/modal (full-screen player)
**Screen states:** loading (spinner) / playing / paused / scrubbing / remove-confirm (ActivityVideoPlayer only) / dragging-to-dismiss

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `ClippedVideoPlayer` | default (+ `videoGravity` param) | `UIViewRepresentable` over `AVPlayerLayer` in `ActivityVideoPlayer.swift`; applies UIKit `cornerRadius` that SwiftUI's `VideoPlayer` ignores. |

## Notes
- Two distinct players live here. `VideoPlayerPage` is a thin full-screen wrapper around AVKit's `VideoPlayer` with inline/modal swipe-dismiss (inline = swipe-right no close button; modal = swipe-down with xmark). `ActivityVideoPlayer` is the richer activity player: custom close/trash/mute overlay, center play button, a custom scrubber bar (Slider + time label), a hand-rolled remove-confirmation overlay, and swipe-down-to-dismiss with background fade.
- No shared `Components/` inventory components are used — all controls are hand-rolled with `Typography` tokens. The remove-confirmation overlay is a bespoke dialog (not `ConfirmationOverlay`/`DialogOverlay`).
- Video rendering is AVKit/AVFoundation; live playback frames will not appear in static captures. Capturable surfaces: loading spinner, the control overlay (play/trash/mute/close), the scrubber bar, and the remove-confirmation overlay.
- `ActivityVideoPlayer` ships two `#Preview` variants ("Portrait" 9:16, "Landscape" 16:9) that mock the chrome over a remote sample video — useful as parity references.
