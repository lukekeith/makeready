# Event Detail

**iPhone source:** `iphone/MakeReady/Pages/Search/EventDetailPage.swift`
**Type:** overlay/modal (opened from a global-search result)
**Screen states:** populated (with/without cover image, with/without subtitle). No explicit loading/empty/error states — all data passed in via init props.

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` | Title "Event", left icon `chevron.left`, `onIconTap` dismisses. |

## Notes
- Everything else is inline: cover image via `AsyncImage` (200px, fallback to white 6% rectangle), bold title text, and an optional `mappin` + subtitle row.
- This is a thin read-only detail view; data comes entirely from the search result (`title`, `subtitle`, `imageURL`), not from AppState.
