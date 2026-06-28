# Program Home

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/ProgramHomePage.swift`
**Type:** screen (overlay-presented; hosts an inline `SlideStack` detail pane)
**Screen states:** loading (ProgressView) / error ("Program not found") / empty (no lessons / no enrollments) / populated / role variants (creator `canEdit` vs read-only viewer)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | item-driven (`DetailScreen?` enum) | primary = program home, detail = editProgram or `EditDay` |
| `PageTitle` | `iconIcon`, `iconTitle`, `iconTitleIcons`, `iconTitleLink` | loading uses iconIcon; error/read-only edit uses iconTitle; main header uses iconTitleIcons (share/eye/gear); edit-program header uses iconTitleLink ("Done") for creator |
| `CoverImagePicker` | `.display` (main), `.editable` default (edit-program) | edit-program copy is `.disabled(!canEdit)` |
| `CardSpinnerOverlay` | default | over cover while uploading image |
| `TabSlider` | default | tabs: Studies / Enrollments / Analytics |
| `BoxButton` | `.secondary` + `.solid` + `.lg`, fullWidth, icon `plus` | add-day (empty + list) and add-enrollment buttons |
| `SwipeableCard` | with `SlideButton` (creator) / no buttons (read-only) | wraps each lesson card; `isSwipeEnabled: canEdit` |
| `SlideButton` | `.delete` (trash) | swipe-to-delete lesson, creator only |
| `CardLesson` | `.lesson` mode, `showAnimatedBorder: true` | lesson rows; built from `CardLessonData` |
| `DragulaView` | default | reorder lessons (creator only; read-only uses bare ForEach) |
| `CardGroup` | `.photo` or `.icon` imageStyle | enrollment rows in Enrollments tab |
| `DialogOverlay` | buttons `.primary` + `.secondary` | publish/unpublish dialog, add-day dialog |
| `DialogButtonConfig` | `.primary`, `.secondary` | dialog button configs |
| `Kpi` | `.iconValue` variant, `.number` valueType | export-confirm overlay KPI grid |
| `ConfirmationOverlay` | `.success` style | export success confirmation |
| Skeleton: `SkeletonCardLesson` | default | studies-tab loading + add-day ghost |
| Skeleton: `SkeletonCardGroup` | default | enrollments-tab loading |

## Notes
- `canEdit` gates the gear-edit pane's "Done" link, the add-day/plus buttons, swipe-to-delete, and DragulaView reorder. Non-creators see a read-only "Program" header with back chevron only.
- Cover-image upload shows `CardSpinnerOverlay` over `CoverImagePicker`.
- `ExportConfirmOverlay`, `PublishBadge`, and `ExportPreviewData` are private in-file structs (not inventory components); the export overlay is built from `Kpi` (.iconValue) tiles.
- Presents (not rendered inline): `EnrollmentFlowModal`, `EnrollmentSchedulePage`, `LessonPreviewModal` (fullScreenCover), `ConfirmationOverlay` (via overlayManager).
- Analytics tab is a "Coming soon" placeholder.
