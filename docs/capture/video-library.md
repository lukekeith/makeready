# Video Library (My Videos)

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoLibraryPage.swift` (+ `iphone/MakeReady/Pages/Video/VideoLibraryGrid.swift`)
**Type:** screen (presented as a full-screen page; doubles as a picker via `isSelectionMode`)
**Screen states:** loading / empty / populated / upload-in-progress (overlay) / delete-confirm (alert) / error (alert)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `VideoThumbnailCard` | default (browse) and `isSelectionMode` (picker) | Local sub-view in this file (not in `Components/`). 2-column `LazyVGrid` cell: thumbnail, duration badge, status badge for non-ready, processing spinner, title + date. Context-menu Delete only in browse mode. |
| `VideoPlayerSheet` | default | Local sub-view; AVKit `VideoPlayer` sheet for tapped ready videos. |

## Notes
- `VideoLibraryPage` is the uploaded-server-video library (`state.orderedVideos`), distinct from `VideoLibraryGrid` (the device Photos grid used inside `SelectVideoPage`/`VideoActivityPicker`).
- No components from the shared `Components/` inventory are used here — the header (close/title/plus), empty state, loading, and upload overlay are all hand-rolled HStack/VStack with `Typography` tokens.
- `VideoLibraryGrid.swift` is a separate device-Photos grid built on UIKit `UICollectionView` via `UIViewRepresentable` (custom `VideoThumbnailCell`) plus a SwiftUI date scrubber; it is documented under `select-video.md` / `video-activity-picker.md` where it is actually mounted.
- Video playback (`VideoPlayer`/AVKit) and the upload progress are runtime/AVFoundation surfaces — the sheet and processing states may not be deterministically capturable.
- States worth capturing: loading (spinner + "Loading videos..."), empty (`video.badge.plus` + Upload button), populated grid, and the upload progress overlay.
