# Create Program

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/CreateProgramPage.swift`
**Type:** screen (overlay-presented; nested `SlideStack` form → program home → EditDay)
**Screen states:** form (default) / validation-errors (required name + template) / creating (loading overlay) / program-home (post-creation, with empty enrollments/analytics)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SlideStack` | isPresented-driven (outer) + item-driven (inner) | outer: form → program home; inner: program home → `EditDay` |
| `PageTitle` | `iconTitleLink`, `iconIcon` | form header = iconTitleLink ("Create"); program-home header = iconIcon (xmark/gear) |
| `CoverImagePicker` | default `.editable` (form), `.display` (program home) | hero cover image |
| `FieldGroup` | default | wraps name, description, template, days inputs |
| `TextInput` | `floatingLabel` | "Program name"; red-bordered overlay when validation fails |
| `MultilineTextInput` | default (`minHeight: 130`) | "Describe the purpose of this program" |
| `MenuInput` | `.menu` (template, default style), `.wheel` (days) | template uses `MenuInputOption` w/ descriptions; days is wheel picker 1–360 |
| `ToggleControl` (in `ToggleGroup`) | default | "Publish program" toggle |
| `TagInput` | default (no `onRequestSuggestions`) | "Add tag..." |
| `TabSlider` | default | tabs: Lessons / Enrollments / Analytics |
| `SwipeableCard` | with `SlideButton` | lesson rows in Lessons tab |
| `SlideButton` | `.delete` (trash) | swipe-to-delete day |
| `CardLesson` | `.lesson` mode (default border) | lesson rows; built from `CardLessonData` |
| `EditDay` | default | inner SlideStack detail pane (full screen documented separately) |
| `AddActivityMenu` | default | presented via overlayManager from EditDay's `onShowAddActivityMenu` |

## Notes
- Validation: empty name and unselected template each draw a red `RoundedRectangle` stroke + "Required" badge over the `FieldGroup`. `FieldGroupDivider` / `FieldGroupDescription` are layout sub-views inside the days FieldGroup.
- `isCreating` shows a centered "Creating Program" ProgressView overlay covering everything.
- Enrollments and Analytics tabs are static placeholders ("No enrollments yet" / "Coming soon").
- Lesson cards here use default border (not `showAnimatedBorder`), unlike ProgramHomePage.
