# Edit User-Input Activity

**iPhone source:** `iphone/MakeReady/Pages/Manage/Program/EditUserInputActivityPage.swift`
**Type:** screen (inline SlideStack detail pane within EditDay)
**Screen states:** default (title + placeholder) / help-enabled (help title + description revealed) / saving / role variants (creator vs read-only) / Done↔Save header swap / preview-available (programId non-nil)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `linkTitleLink` (creator), `iconTitle` (read-only) | creator: Cancel / Save↔Done; read-only: back chevron "Activity" |
| `FieldGroup` | default | groups title+placeholder; groups help title+description when enabled |
| `TextInput` | `floatingLabel` ("Activity title", "Placeholder text", "Help title") | `.disabled(!canEdit)` |
| `MultilineTextInput` | default (`minHeight: 130`) | "Help description" (only when help enabled) |
| `ToggleControl` (in `ToggleGroup`) | default | "Enable context help" |
| `BoxButton` | `.secondary` + `.solid` + `.lg`, fullWidth, icon `eye` | Preview button — only when `programId != nil` |

## Notes
- `FieldGroupDivider` separates the two TextInputs inside a single FieldGroup, and title/description in the help FieldGroup.
- Help title/description fields appear conditionally on `isHelpEnabled`.
- `LessonPreviewModal` presented via `.fullScreenCover`.
- `hasChanges` drives the Save↔Done right-link; saving persists in place without dismissing.
- Single `#Preview` (programId nil → no Preview button, read-only header path).
