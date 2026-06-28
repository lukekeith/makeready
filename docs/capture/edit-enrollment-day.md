# Edit Enrollment Day

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/EditEnrollmentDay.swift`
**Type:** screen (push-style; hosted in a `SlideStack`, primary = day editor, detail = per-activity editor)
**Screen states:** populated / adding-activity (skeleton ghost card) / per-card loading (spinner overlay while saving/deleting/clearing) / title-editing (header swaps to Cancel/Save)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | item-driven (`$editingActivityId`) | Primary day content → activity edit pane. (Layout primitive, not in the card inventory but the page's structural driver.) |
| `PageTitle` | `.iconTitleLink` (xmark + "Done") and `.linkTitleLink` (Cancel/Save) | Header swaps to the Cancel/Save link variant when `hasTitleChanges`. |
| `FieldGroup` | default | Wraps the lesson-title `TextInput` (and the activity-title field in the inline edit sub-views). |
| `TextInput` | `floatingLabel:` init ("Lesson title", "Activity title", "Help title") | Floating-label single-line variant. |
| `DragulaView` | reorder init (`items:` binding, card builder, `dropView:`, `dropCompleted:`) | Drag-to-reorder list of activity cards. |
| `ReorderDropIndicator` | default | Drop placeholder shown by Dragula between rows. |
| `SwipeableCard` | default (`slideButtons:` + `onTap:` + content) | Each activity row; slide buttons vary per activity (see SlideButton). |
| `SlideButton` | `.reschedule` (eye preview, xmark.circle clear), `.delete` (trash) | Buttons built conditionally in `buildSlideButtons` — preview only for configured VIDEO, clear only for configured activities, delete always. |
| `CardLessonActivity` | `size: .small`, `showAnimatedBorder: !isReady`; status `.confirmed`/`.new`; `isVideo: true` for video cards | Compact two-line activity card; animated border while unconfigured. |
| `CardSpinnerOverlay` | default | Overlaid on a card while saving/deleting/clearing that activity. |
| `SkeletonCardStudy` | default | Ghost card shown while a new activity is being added. |
| `BoxButton` | `.secondary` + `.solid`, `.lg`, `iconPosition: .right` (plus icon), `fullWidth`, `iconOpacity: 0.5`; also `.secondary`/`.solid`/`.lg` "Preview" (eye) in the USER_INPUT edit pane | Add-activity button and inline-edit Preview button. |
| `ToggleGroup` / `ToggleControl` | default | "Show help" toggle in the USER_INPUT inline edit pane. |
| `MultilineTextInput` | placeholder init ("Help description") | Help description field in the USER_INPUT edit pane. |

## Detail pane (activity editors)
The SlideStack detail pane delegates to other pages, not custom components in the inventory:
- `EditReadActivityPage` (`actions: .enrollment`) for READ activities.
- `EditScheduledUserInputView` — a **private** sub-view local to this file (uses `PageTitle.iconTitleLink`, `FieldGroup`, `TextInput`, `ToggleGroup`/`ToggleControl`, `MultilineTextInput`, `BoxButton`).
- `EditScheduledReadView` — a private sub-view defined in this file (currently uses `PageTitle.iconTitleLink`, `FieldGroup`, `TextInput`); not reached by the live switch (READ routes to `EditReadActivityPage`).

## Notes
- Full-screen covers (hardware/video): `VideoActivityPicker`, `VideoActivityManager`, `ReadActivityPreviewModal` — modal pages, not inventory components.
- Native `.alert` used for Delete and Clear confirmations (not `DialogOverlay`).
- Activity card type branches: VIDEO vs READ/USER_INPUT decide tap target and the card's `isVideo`/description.
