# Read Activity Preview Modal

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/ReadActivityPreviewModal.swift`
**Type:** overlay/modal (full-screen web preview)
**Screen states:** loading (WKWebView fetching token + page) / loaded (web `ActivityPreviewPlayer.vue`) / fallback (tokenless load on token failure)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from inventory)_ | — | screen is built entirely from a header HStack + `PreviewWebView` (a `UIViewRepresentable` WKWebView wrapper defined in-file) |

## Notes
- Header bar = raw HStack (xmark close button + centered "Preview" text + invisible balance spacer); not a `PageTitle`.
- `PreviewWebView` loads `\(clientBaseURL)/preview/activity/{id}` with a short-lived `preview_token` query param (no cookie planting).
- Rendering/playback/scrubbing all handled by the web client — iPhone side has no custom UI components here.
- No `#Preview`.
