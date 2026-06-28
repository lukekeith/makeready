# Global Search

**iPhone source:** `iphone/MakeReady/Pages/Search/GlobalSearchPage.swift`
**Type:** screen (presented as a modal from the hamburger menu)
**Screen states:** recents (query < 2 chars), loading (spinner), empty ("No results"), populated (filter badges + categorized results)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SearchField` | default (single form) | Top search bar; `placeholder: "Search everything"`, with `onClose`/`onClear` clearing text + category filter. Animates centered → left-aligned on focus. |
| `CardSearchResult` | `init(result:highlightQuery:onTap:)` convenience init | One row per result. Derived sub-variants by category: member → Avatar image (`isMember`), video → thumbnail + play icon (`isVideo`), program/group/etc. → cached circular image or SF-symbol fallback. `showChevron: false` for all search rows. Title highlights the query in brand purple. |

## Notes
- Filter badges (capsule chips) and category section headers are inline, hand-rolled UI in this page — not custom components.
- Recents empty state and no-results empty state are inline `VStack` + SF Symbol, not a shared component.
- Tapping a result presents a different detail surface per category (programHome, groupHome, SearchLessonDetail, VideoPlayerPage, MemberProfilePage, EnrollmentSchedulePage, PostDetailPage, EventDetailPage, NotificationFeedPage) via OverlayManager — those are separate screens.
