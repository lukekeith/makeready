# Edit Group

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/EditGroupPage.swift`
**Type:** overlay/modal (presented via OverlayManager, route `.editGroup`)
**Screen states:** populated (form pre-filled from `group`) / saving (full-screen "Saving Changes" spinner overlay) / conditional welcome-message field (shown when "Send welcome message" toggle is on)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitleLink` | Header: xmark + "Save" link (`rightLinkDisabled` until name is non-empty). |
| `CoverImagePicker` | mode `.editable` (default), with `existingImageUrl` | Pre-loads existing cover; default editable mode. |
| `FieldGroup` | default | Wraps name, description, age range, max members, welcome message. |
| `TextInput` | `floatingLabel` init | Group name. |
| `MultilineTextInput` | placeholder init (`minHeight: 130`) | Description and (conditionally) welcome message. |
| `ToggleGroup` | default | Wraps the four toggles. |
| `ToggleControl` | default | Private / Allow invites / Member directory / Send welcome message. |
| `AgeRangeInput` | default | Age range, pre-filled from `group.ageRange`. |
| `MenuInput` | style `.wheel` | Max members picker, pre-filled from `group.maxMembers`. |

## Notes
- Same form layout as Create Group; the differences are "Save" link, the `existingImageUrl` on the cover picker, and pre-populated state from the passed `group`.
- This standalone modal is distinct from the inline edit pane embedded in `GroupHomePage` (which uses `CoverImagePicker(mode: .display)`).
