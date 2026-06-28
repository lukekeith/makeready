# Exegesis Highlight Modal

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/ExegesisHighlightModal.swift`
**Type:** overlay/modal (full-screen takeover; presented via `overlayManager.present(.exegesisHighlightModal)`)
**Screen states:** populated (verse text with selectable highlights) / selection-active (existing highlight tapped) / role variants (`canEdit` enables selection + delete) / appear/dismiss animation

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `ExegesisVerseView` | `usePreviewHighlightStyle: false`, `fontSize: 16`, `selectedHighlightRange` | the only inventory component — renders the verse with system text selection; `isSelectionEnabled: canEdit` |

## Notes
- Header (title "Highlight Passage" + xmark close) and `highlightRow(_:)` rows (snippet + note state + trash + chevron) are raw HStack/Button layouts in-file, not inventory components.
- Highlights are derived to `[ReadBlockSelection]` (style "highlight") for the verse view.
- `pendingRange` change → either selects an existing highlight or fires `onHighlightCreated`.
- Trash button (delete) only rendered when `canEdit`.
- No `#Preview`.
