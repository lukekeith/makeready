# Post Detail

**iPhone source:** `iphone/MakeReady/Pages/Search/PostDetailPage.swift`
**Type:** overlay/modal (opened from a global-search result)
**Screen states:** populated (with/without cover image, with/without content body). No loading/empty/error states — data passed in via init props.

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` | Title "Post", left icon `chevron.left`, `onIconTap` dismisses. |

## Notes
- Structurally identical to Event Detail. Inline: cover image via `AsyncImage` (200px, white 6% fallback), bold title, optional content body text (`subtitle`) with line spacing.
- Read-only; data comes from the search result props, not AppState.
