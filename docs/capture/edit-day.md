# Edit Day

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/EditDay.swift`
**Type:** screen (SlideStack detail pane; hosts its own inline activity editor SlideStack)
**Screen states:** populated (activity list) / adding-activity (skeleton ghost) / per-card loading (spinner) / role variants (creator `canEdit` vs read-only) / title-edited header swap

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | item-driven (`editingActivityId`) | primary = day content, detail = inline activity editor (Read/Exegesis/UserInput/YouTube pages) |
| `PageTitle` | `iconTitle`, `linkTitleLink`, `iconTitleLink` | read-only = iconTitle; title-edited = linkTitleLink (Cancel/Save); default = iconTitleLink (back/Done) |
| `FieldGroup` | default | wraps lesson-title input |
| `TextInput` | `floatingLabel` ("Lesson title") | `.disabled(!canEdit)` |
| `DragulaView` | default | reorder activities (creator only; read-only uses bare ForEach) |
| `SwipeableCard` | with `SlideButton`s (creator) / none (read-only) | wraps every activity card; `isSwipeEnabled: canEdit`; locked block uses `rasterizesContent: false` indirectly elsewhere — here default |
| `SlideButton` | `.delete` (trash, reset arrow), `.reschedule` (eye preview, xmark.circle clear) | study cards: reset+clear+delete; video cards: preview+clear+delete |
| `CardLessonActivity` | `size: .small`, `showAnimatedBorder: !isReady`; `.confirmed`/`.new` status | study + video activity cards; video uses `isVideo: true` + `.photo`/`.icon` imageStyle |
| `CardSpinnerOverlay` | default | over a card during save/reset/delete/clear |
| `BoxButton` | `.secondary` + `.solid` + `.lg`, fullWidth | add-activity (`plus`, creator only) + Preview (`eye`) |
| `SkeletonCardLessonActivity` | default | ghost while adding an activity |
| `EditReadActivityPage` | default | inline detail for `.read` activities |
| `EditExegesisActivityPage` | default | inline detail for `.exegesis` |
| `EditUserInputActivityPage` | default | inline detail for `.userInput` |
| `EditYouTubeActivityPage` | default | inline detail for `.youtube` |

## Notes
- `LessonPreviewModal`, `LessonPreviewWebView` are defined in this file (WKWebView preview wrappers); presented via `.fullScreenCover`.
- Hardware/full-screen covers (not inventory components): `VideoActivityPicker`, `VideoActivityManager`, `BibleReaderOverlayView` (added to window directly).
- SOAP/OIA/DBS/HEAR and other non-Read/UserInput/YouTube/Exegesis types tap into the Bible reader overlay rather than an inline editor.
- `canEdit` gates plus button, swipe buttons, drag reorder, and the title input; Preview button is always shown.
