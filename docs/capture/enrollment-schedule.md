# Enrollment Schedule

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/EnrollmentSchedulePage.swift`
**Type:** screen (push or modal; hosted in a `SlideStack`, primary = lesson list, detail = Edit Enrollment Day)
**Screen states:** loading (10 skeleton lesson cards) / populated / empty ("No lessons scheduled") / error / adding-lesson (ghost skeleton card) / per-card deleting (collapse animation)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | item-driven (`$editingScheduleId`) | Schedule list → `EditEnrollmentDay` detail pane (see `edit-enrollment-day.md`). |
| `PageTitle` | `.iconTitle` (leftIcon `chevron.left` or `xmark`) | Header; leftIcon is `xmark` when presented as a modal, else `chevron.left`. |
| `SwipeableScrollView` | default | Scroll container for both the skeleton and the loaded list. |
| `SkeletonCardLesson` | default | 10 shown while loading / not-yet-ready; one shown as the "adding lesson" ghost. |
| `SwipeableCard` | default (`slideButtons:` + `onTap:`) | Each lesson row. |
| `SlideButton` | `.reschedule` (share `square.and.arrow.up`, calendar `calendar`), `.delete` (trash) | Three swipe actions per lesson: share invite, reschedule, delete. |
| `CardLesson` | `mode: .lesson`, with per-activity `status` `.percentComplete(...)` / `.incomplete`, `isReleased` true once scheduled date ≤ today | Lesson card with day badge + activity blocks; fill opacity driven by completion stats. |
| `BoxButton` | `.secondary` + `.solid`, `.lg`, `iconPosition: .right` (plus icon), `fullWidth`, `iconOpacity: 0.5` (`label: nil`) | "Add lesson" button at list bottom. |
| `DialogOverlay` | default, with `DialogButtonConfig` `.primary` ("Add lesson"/"Adding…") + `.secondary` ("Cancel") | Add-lesson confirmation dialog. |
| `LessonActionMenu` | default | Presented via `overlayManager` on lesson tap (overlay component; edit/open/share/add/delete actions). |
| `AddActivityMenu` | default | Presented via `overlayManager` when the Edit-Day pane requests the add-activity menu. |
| `StudyInvitePage` | (preview-data variant when in `#Preview`) | Presented via `.fullScreenCover` for the selected lesson. See `study-invite.md`. |

## Notes
- Native `.alert` used for "Delete Lesson?" confirmation (not `DialogOverlay`).
- Completion analytics (`completionStats`) are loaded concurrently with details; until loaded, activity blocks render `.incomplete` (empty outlined).
- Deleting a card animates a height/scale collapse via `deletingScheduleId` before the list refreshes.
- `EditEnrollmentDay` (detail pane) is documented separately.
