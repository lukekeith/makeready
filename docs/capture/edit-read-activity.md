# Edit Read Activity

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/EditReadActivityPage.swift`
**Type:** screen (inline SlideStack detail pane within EditDay; itself slides to a theme editor)
**Screen states:** single-block / multi-block (locked verse + editable text) / collapsed locked blocks / highlight-mode (dimmed siblings) / source menu / set-titles modal / theme editor (screen 2) / saving / role variants (creator vs read-only) / Done↔Save header swap

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | isPresented-driven (`showThemeEditor`) | primary = edit content, detail = theme editor |
| `PageTitle` | `linkTitleLink` (creator), `iconTitle` (read-only + theme editor back) | Cancel / Done↔Save; theme editor uses iconTitle "Edit Themes" |
| `FieldGroup` | default | wraps activity-title input |
| `TextInput` | `floatingLabel` ("Activity title") | `.disabled(!canEdit)` |
| `DragulaView` | default (via `DraggableReadBlock` wrapper, runtime `isDraggable`) | reorder blocks; suppressed in highlight mode; read-only uses bare ForEach |
| `SwipeableCard` | with `SlideButton` (locked blocks); `rasterizesContent: false`, `isTapEnabled` toggled | locked verse blocks; editable blocks are bare `MarkdownEditor` |
| `SlideButton` | `.delete` (trash) | delete locked block |
| `SelectableLockedBlockView` | default (`isSelectionEnabled` per highlight mode) | locked verse block content with tap-and-hold selection |
| `MarkdownEditor` | default (`autoGrow: true`, editable block); also static `markdownToAttributed`/`attributedToMarkdown` | editable text blocks |
| `CardActivityType` | `.list` mode | source-menu rows: "Bible verse" + "Custom text" |
| `BlockStyleEditor` | with `availableThemes` + `blockTitle` init | theme editor (screen 2) — one per block |
| `StylePickerMenu` | default (`currentStyle`, `onSelect`, `onDismiss`) | presented via overlayManager for a selected span |
| `BoxButton` | `.secondary` + `.solid` + `.lg` (add-block plus, Edit Themes paintbrush, Preview eye); set-titles modal: `.secondary` + `.primary` | |
| `CustomToggle` | default | toggles in set-titles modal rows |

## Notes
- Source menu and set-titles modal are inline ZStack bottom sheets driven by `ModalAnimations` (not overlayManager); set-titles uses `BoxButton` (.secondary "Do nothing" / .primary "Set title(s)") + `CustomToggle` rows.
- `ReadActivityActionProvider` (`.program` / `.enrollment`) swaps the backing Actions — same UI, two contexts.
- `LessonPreviewModal` presented via `.fullScreenCover`; `BibleReaderOverlayView` added to window for passage selection.
- Highlight mode dims non-active blocks to 0.3 and shows a `highlighter` toggle overlay per locked block.
- Two `#Preview`s: single read, multi-read (locked + editable + locked).
