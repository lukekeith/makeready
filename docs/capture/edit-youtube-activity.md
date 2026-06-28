# Edit YouTube Activity

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/EditYouTubeActivityPage.swift`
**Type:** screen (inline SlideStack detail pane within EditDay)
**Screen states:** empty (no URL) / URL-entered (thumbnail preview) / fetching-metadata (spinner row) / saving / role variants (creator vs read-only) / Done↔Save header swap / preview-available (programId non-nil)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `linkTitleLink` (creator), `iconTitle` (read-only) | "YouTube Video"; creator Cancel / Save↔Done; read-only back chevron |
| `FieldGroup` | default | wraps title input and URL input (separate groups) |
| `TextInput` | `floatingLabel` ("Activity title", "YouTube URL") | URL field `autocorrect: false`; `.disabled(!canEdit)` |
| `BoxButton` | `.secondary` + `.solid` + `.lg`, fullWidth, icon `eye` | Preview button — only when `programId != nil` |

## Notes
- `YouTubePreview` is a private in-file struct (AsyncImage thumbnail + play overlay; taps open YouTube app/Safari) — shown once a valid 11-char video id is parsed from the URL.
- Metadata fetch (`fetchMetadata`) auto-fills an empty title and shows a "Loading video info..." ProgressView row.
- `LessonPreviewModal` presented via `.fullScreenCover`.
- Single `#Preview` (default form).
