# Enrollments List

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/EnrollmentsListPage.swift`
**Type:** screen (push-style; hosted in a `SlideStack`, primary = list, detail = Enrollment Schedule)
**Screen states:** loading (spinner) / empty ("No enrollments yet") / populated (Active + Completed sections) / error / creating-enrollment (skeleton card at top)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | item-driven (`$selectedEnrollmentId`) | List → `EnrollmentSchedulePage` detail pane (see `enrollment-schedule.md`). |
| `PageTitle` | `.iconTitle` (leftIcon `chevron.left`) | Header "Enrollments". |
| `SkeletonEnrollmentCard` | default (programName / programImageUrl / programDays) | "Creating…" placeholder shown while a new enrollment is being created. |
| `SwipeableCard` | default (`slideButtons:` + `onTap:`) | Each enrollment row. |
| `SlideButton` | `.delete` (trash) | Single swipe action → present Unenroll Options modal. |
| `EnrollmentCard` | default | Enrollment summary card (single-form component). |
| `UnenrollOptionsModal` | default | Presented via `overlayManager` on swipe-delete. See `unenroll-options.md`. |
| `UnenrollConfirmation` | `.present(...)` (single-form helper) | Processing/confirmation overlay shown while the unenroll action runs; routes through `overlayManager` (`.confirmationOverlay`). |

## Notes
- List splits into an untitled "Active" section and a titled "Completed" section; the loading spinner is a raw `ProgressView`, empty/error states are bespoke icon+text blocks (not components).
- `swipeState` is injected via `.environment(\.swipeState, ...)` so card swipes disable scroll.
- `UnenrollConfirmation` is an enum with a static `present(...)` factory (not a view struct) — its only variant is the presented confirmation overlay parameterized by `UnenrollOption`.
