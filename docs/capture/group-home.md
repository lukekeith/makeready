# Group Home

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/GroupHomePage.swift`
**Type:** screen (hosts nested `SlideStack` panes: settings/edit on the left, members/enrollments/invite on the right)
**Screen states:** loading (no cached group → ProgressView) / populated / cover-uploading (pending image + spinner) / posts: empty / posts-loading (skeletons) / pending-enrollment (skeleton post)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitleIcons` | Header with left icon + 5 right `IconAction`s (paperplane, person.2 w/ badge, calendar, book, gearshape). Used in both loading and main content. |
| `PageTitle` | `iconTitleLink` | Edit Group pane header (chevron.left + "Done" link). |
| `BoxButton` | `.secondary` size `.md`, `.primary` size `.md` | Invite / Enroll action row (fullWidth, icon `.left`). |
| `GroupActionButton` (via `GroupActionButtonRow`) | default row | Horizontally scrolling video / message / meeting actions. |
| `SkeletonPostCard` | default + program-seeded | Bare skeletons (3x) during initial post load; program-named skeleton during pending enrollment. |
| `GroupPostCard` | default | One per loaded post. |
| `CardLesson` | mode `.lesson` | "Next Lesson" section card (`CardLessonData(mode: .lesson)`). |
| `CoverImagePicker` | mode `.display` | Edit Group pane cover picker (with `existingImageUrl`). |
| `FieldGroup` | default | Wraps name, description, age range, max members in edit pane. |
| `TextInput` | `floatingLabel` init | Group name field (edit pane). |
| `MultilineTextInput` | placeholder init (`minHeight: 130`) | Description field (edit pane). |
| `ToggleGroup` | default | Wraps the three privacy toggles. |
| `ToggleControl` | default | Private / Allow invites / Member directory. |
| `AgeRangeInput` | default | Age range min/max. |
| `MenuInput` | style `.wheel` | Max members picker. |
| `DialogOverlay` | default, buttons: `DialogButtonConfig` `.primary` + `.secondary` | "Add a new lesson?" confirmation. |
| `ConfirmationOverlay` | style `.success` (with `isProcessing` binding) | Enrollment processing → success overlay. |
| `LessonActionMenu` | default | Presented via `overlayManager` on next-lesson tap. |

## Notes
- The Edit Group form here is an *inline* `SlideStack` detail pane (distinct from the modal `EditGroupPage` screen) but uses the same input components, so web parity should reuse the same field components.
- `person.2` header icon shows a badge when there are pending join requests (`showBadge:` on `IconAction`).
- Cover header is hand-rolled (`AsyncImage` + gradient), not a component.
- Sub-screens (`GroupMembersPage`, `EnrollmentsListPage`, `GroupInvitePage`) are mounted as right-pane content — documented separately.
