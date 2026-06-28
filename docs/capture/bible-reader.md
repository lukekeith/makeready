# Bible Reader

**iPhone source:** `iphone/MakeReady/Pages/Bible/BibleReaderOverlay.swift` (presented via `iphone/MakeReady/Pages/Bible/BibleReaderBridge.swift`)
**Type:** overlay/modal (bottom sheet, pure UIKit `UIView`)
**Screen states:** books grid / chapters grid / verses grid / reader (passage selection) / search (loading, recents, empty results, populated)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `BibleVerseTextLayout` | default (`serifFont`, `paragraphStyle`, `verseNumberFont`/`verseNumberColor`, `textInsets`) | Static layout helper used to render chapter heading + verse body in the reader `UITextView`, and to draw the left-gutter verse numbers. Drives all reader typography. |
| `BibleVersionMenu` (`BibleVersionDropdown`) | default | Translation picker popover anchored below the version button; documented separately in `bible-version-menu.md`. |

## Notes
- This is **not** a SwiftUI page. It is a hand-built UIKit `BibleReaderOverlayView` (collection views, a `UITextView`, a results table) bridged into SwiftUI via `BibleReaderViewBridge` (`UIViewRepresentable`). Almost all UI is bespoke UIKit, not MakeReady SwiftUI components.
- The only reusable MakeReady custom component is `BibleVerseTextLayout` (shared reader typography, also used by the read-activity verse views) plus the `BibleVersionDropdown` it presents.
- Five internal screens share one container: **books** grid (`BookCell`), **chapters**/**verses** number grids (`NumberCell`), **reader** (selectable verse text with gutter verse circles + Select button), and **search** (results `UITableView` with loading / recent-searches / empty / matched-books+verses states).
- Reader state nuances for parity: used passages render with a purple highlight + purple gutter numbers; the active selection turns the gutter number purple-bold; chapter swipe pre-renders adjacent chapters.
- Selected translation comes from `AppState.shared.selectedBibleTranslation`; verses load via `BibleCacheManager`, search via `BibleSearchService` (both session-optional endpoints).
