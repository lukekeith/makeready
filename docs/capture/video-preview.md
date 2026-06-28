# Video Preview Overlay

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoPreviewOverlay.swift`
**Type:** overlay/modal (pure UIKit zoom-to-fill preview)
**Screen states:** expanding (zoom-in animation) / expanded paused (play icon shown) / playing / scrubbing (progress bar visible) / swipe-to-dismiss (interpolating back to source frame)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from inventory)_ | — | Entirely UIKit (`VideoPreviewOverlayView: UIView` + private `PlayerView: UIView` over `AVPlayerLayer`); no SwiftUI MakeReady components. |

## Notes
- Not a SwiftUI screen — it's a UIKit overlay presented programmatically (`present(in: window)`) from `VideoLibraryGrid`/`VideoActivityPicker` when a Photos thumbnail is tapped. Animates from the tapped cell's frame to an aspect-ratio-aware expanded size (portrait top-aligned, landscape centered).
- Chrome is hand-built UIKit: black scrim, rounded content view, center play icon, 4px white progress track/fill, and a bottom Cancel / Select `UIButton` stack (Select uses brand purple #6C47FF).
- Interactions: tap to play/pause, horizontal pan to scrub, swipe-down to dismiss (interpolates frame/corner-radius/scrim/button opacity back to the source cell), scrim tap and Cancel to close.
- Video is AVFoundation (`AVPlayerLayer`) and depends on device Photos media — live frames won't render in static captures; the thumbnail still shows. There is no `#Preview` (UIKit). Capturable surfaces: expanded thumbnail with play icon, progress bar, and the Cancel/Select buttons.
