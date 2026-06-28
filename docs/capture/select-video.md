# Select Video

**iPhone source:** `iphone/MakeReady/Pages/Video/SelectVideoPage.swift`
**Type:** screen (video picker over device Photos)
**Screen states:** loading/authorizing / populated grid / no-selection (preview placeholder) / selection made (Next enabled) / source-menu open / album-picker (sheet) / recorder (fullScreenCover) / player (fullScreenCover) / permission-denied (alert)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `VideoPreview` | default | Single form. Large 440pt preview area; shows placeholder (`video.fill` + "Select a video") when nothing selected, else the selected/recorded thumbnail. Tap to play. |
| `VideoSourceBar` | default | Single form. Source dropdown (current `VideoSource` label + chevron) and MR logo button. |
| `VideoSourceMenu` | default | Single form, driven by `VideoSource.allCases`. Inline popup below the source bar. See `video-source-menu.md`. |
| `VideoGridItem` | `.camera` and `.video(VideoAsset)` | Both `ItemType` cases used: first cell is `.camera` (opens recorder), the rest are `.video` thumbnails. `isSelected` toggled per tap. |
| `CustomVideoRecorder` | default | Presented via `.fullScreenCover` when the camera cell is tapped. See `video-recorder.md`. |
| `AlbumThumbnail` | default | Private sub-view in this file; renders a PHAsset thumbnail in the album-picker sheet rows. |

## Notes
- The header (close/Next/title), the album-picker sheet rows, and the inline video player (`fullScreenCover`) are hand-rolled, not from the shared component inventory.
- Grid is a 4-column SwiftUI `LazyVGrid` of `VideoGridItem` (distinct from `VideoLibraryGrid`'s UIKit collection view).
- Thumbnails come from the device Photos library (`PhotoLibraryManager`) — captures depend on simulator media being present; an empty or unauthorized library yields the permission alert / empty grid. Video playback is AVKit and won't render statically.
