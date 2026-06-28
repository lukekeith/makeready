# Media Detail

**iPhone source:** `iphone/MakeReady/Pages/Media/MediaDetailOverlay.swift`
**Type:** overlay/modal (full-screen, pure UIKit `UIView`; zoom-from-cell transition)
**Screen states:** loading (spinner while detail fetches) / populated (photo or video) / edit mode / paging between items

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from the custom inventory)_ | — | Entirely bespoke UIKit + private helper views. |

## Notes
- `MediaDetailOverlayView` is a hand-built UIKit `UIView` presented directly into the window — it does **not** use any MakeReady SwiftUI components. All sections (title row, info grid, description, tags, usage list) are built with `UILabel`/`UIStackView`/`NSLayoutConstraint`.
- Media area: `UIScrollView` pinch-to-zoom host with `thumbnailImageView`; for videos an `AVPlayerLayer`-backed `PlayerView` plus a center play/pause icon and a fullscreen button.
- Private helper views (not in the inventory, but the parity targets): `FlowLayoutView` + `PaddedLabel` render the wrapping read-only tag pills; `PassthroughTopScrollView` lets the info pane slide over the media.
- **Edit mode** swaps in a slide-up panel built from UIKit-native inputs that mirror SwiftUI components but are separate types: `FloatingLabelTextField` (title), `FloatingLabelTextView` (description), `UIKitTagInput` (tags — the UIKit twin of `TagInput`). Note these for parity even though they are not the SwiftUI inventory components.
- Info grid rows: Type, Duration, File Size, Dimensions, Format (MIME), Created, Uploaded by — rendered as two-up cells.
- Pager keeps a high-res image window of current ± 1; horizontal swipe pages between items, vertical swipe dismisses back to the source grid cell.
- Data via `MediaActions().loadDetail/loadUsages/updateMedia/syncTags`.
