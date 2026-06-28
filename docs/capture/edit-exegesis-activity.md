# Edit Exegesis Activity

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/EditExegesisActivityPage.swift`
**Type:** screen (inline SlideStack detail pane within EditDay)
**Screen states:** empty (no passage / "select passage") / verse (passage chip + inline preview) / styled (image+color+font) / highlights (selections present) / saving / role variants (creator vs read-only) / Done↔Save header swap

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `linkTitleLink` (creator), `iconTitle` (read-only) | creator: Cancel / Done↔Save; read-only: back chevron "Activity" |
| `FieldGroup` | default | wraps activity-title input |
| `TextInput` | `floatingLabel` ("Activity title") | `.disabled(!canEdit)` |
| `BlockStyleEditor` | image+color+font init (`activityId`, `blockId`, `onColorPickerOpened`) | only when `hasPassage`; `.disabled(!canEdit)` |
| `ExegesisVerseView` | `usePreviewHighlightStyle: false`, `usesNativeTextSelection: true` | inline preview container; native UITextView selection → highlight |
| `BoxButton` | `.secondary` + `.solid` + `.lg` (Preview, eye); `.secondary` + `.destructive` (highlight action menu) | Preview button; note/delete buttons in the highlight action menu |
| `DialogOverlay` | buttons `.secondary` + `.primary` | "Change passage?" confirm |
| `DialogButtonConfig` | `.secondary`, `.primary` | dialog buttons |
| `MarkdownEditor` | default (`autoGrow: false`, custom minHeight) | note editor inside `HighlightActionMenuContent` |
| `InlineFontSizePicker` | static `previewPointSize(_:)` only | used to map font-size key → point size (no view instance) |

## Notes
- `HighlightActionMenuContent` is a private in-file struct (presented via overlayManager as `.exegesisHighlightActionMenu`); it composes `BoxButton` (`.secondary` add/edit-note, `.destructive` delete) + `MarkdownEditor` + raw PREV/NEXT nav buttons.
- `LessonPreviewModal` presented via `.fullScreenCover` for member preview.
- `BibleReaderOverlayView` added directly to the window (passage selection) — not an inventory component.
- Four `#Preview` variants: empty, verse, image+color, highlights — match the screen states above.
- `canEdit` requires non-nil `programId`; nil programId (previews/read-only) disables every input.
