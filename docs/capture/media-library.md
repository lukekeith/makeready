# Media Library

**iPhone source:** `iphone/MakeReady/Pages/Main/MainLibrary.swift` (+ grid `iphone/MakeReady/Pages/Media/MediaLibraryGrid.swift`)
**Type:** tab
**Screen states:** loading (program / media skeletons) / empty / populated; two sub-tabs ("Programs", "Media")

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs=["Programs","Media"] + trailing import + add buttons | trailing slot has an import (square.and.arrow.down) button and a `+` that opens `ActionCardMenu` |
| `ActionCardMenu` | default (title "Create New", items Study Program / Media) | overlay-presented from header `+` |
| `SearchField` | default — Programs: "Search studies, tags, authors..."; Media: "Search media library" | fixed top overlay on both tabs (with `onClose`/`onClear`) |
| `FilterChipDropdownTrigger` | default — Programs: tags, leaders; Media: tags, leaders, type, time | horizontal filter row per tab |
| `FilterChipDropdownPanel` | default (multi-select for tags/leaders, `showClearAll: false` single-select for media type/time) | expanded dropdown panel over a dim scrim |
| `SkeletonCardProgramFull` | default | Programs tab initial-load placeholders (×2) |
| `CardStudyMini` | `imageStyle: .photo`/`.icon`, `status: .confirmed`, metadata clock+days | "Currently enrolled" horizontal scroller (Programs tab) |
| `SwipeableCard` | with `slideButtons: [SlideButton(.delete)]` when owned, empty otherwise; `isSwipeEnabled` gated on ownership | wraps each "Browse all" program card |
| `SlideButton` | `style: .delete` | trash action (owner-only) |
| `CardProgramFull` | default (title, description, tags, days, enrollment count, author byline, published/draft) | "Browse all" program rows |
| `SkeletonCardMediaFull` | default | Media tab initial-load grid placeholders (×9) |
| `MediaLibraryGrid` | default (`topInset: 116`, paging via `mediaGridBridge`) | Media tab 3-column grid; built on a `UICollectionView` representable |
| `CardMediaFull` | default | rendered inside `MediaLibraryGrid` cells |
| `Kpi` | `variant: .iconValue`, `valueType: .number` (Days/Activities/Read/Video/Write/Read Blocks/Scriptures) | inside `ImportConfirmOverlay` import-preview grid (conditional rows) |
| `ConfirmationOverlay` | `style: .success` | shown after a confirmed import (overlay-presented) |

## Notes
- Two tabs: Programs (enrolled scroller + browse list, search + tag/leader filters) and Media (3-col grid, search + tag/leader/type/time filters).
- `ImportConfirmOverlay` is a private struct in `MainLibrary.swift` (custom modal, not an inventory component) but contains `Kpi` rows; `ConfirmationOverlay` is the inventory success confirmation.
- `MediaLibraryGrid` is a `UIViewRepresentable`-backed collection view, not a SwiftUI `LazyVGrid`; its cells host `CardMediaFull`. Detail tap presents `MediaDetailOverlayView` (UIKit overlay) — capture separately.
- Filter dropdowns dim the page with a 0.5 black scrim; only one panel open at a time (shared `LibraryDropdown` enum).
- Program covers, media thumbnails, author info are remote — parity-sensitive.
- Empty states (`programsEmptyState`, `mediaEmptyState`) are plain SF Symbol + text, no inventory component.
