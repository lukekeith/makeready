# Teleprompter Overlay

**iPhone source:** `iphone/MakeReady/Pages/Video/TeleprompterOverlay.swift`
**Type:** overlay (in-recorder text overlay)
**Screen states:** static (not scrolling) / scrolling (during recording, when not paused)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from inventory)_ | — | Self-contained overlay; no custom MakeReady components nested. |

## Notes
- Single-form component (`text`, `isScrolling`, `scrollSpeed`). Fixed 200pt-tall rounded card: semi-transparent black background, centered scrolling `Text` (`Typography.s24Medium`), top + bottom gradient fades, manual scrolling disabled.
- Mounted by `CustomVideoRecorder` over the camera preview when `showTeleprompter` is on and the script is non-empty.
- Scroll is a linear animation driven by text/container height; for a static capture it shows the script at the top of the card. The `#Preview` mounts it standalone over `Color.appBackground` with a sample script (`isScrolling: true`) — the best parity reference since the camera feed behind it won't capture.
