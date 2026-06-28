# Create Group

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/CreateGroupPage.swift`
**Type:** overlay/modal (presented via OverlayManager, route `.createGroup`)
**Screen states:** populated (form) / creating (full-screen "Creating Group" spinner overlay) / conditional welcome-message field (shown when "Send welcome message" toggle is on)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitleLink` | Header: xmark + "Create" link (`rightLinkDisabled` until name is non-empty). |
| `CoverImagePicker` | mode `.editable` (default) | No `existingImageUrl` — entire tile opens the photo picker. |
| `FieldGroup` | default | Wraps name, description, age range, max members, welcome message. |
| `TextInput` | `floatingLabel` init | Group name (focused/submit chaining). |
| `MultilineTextInput` | placeholder init (`minHeight: 130`) | Description and (conditionally) welcome message. |
| `ToggleGroup` | default | Wraps the four toggles. |
| `ToggleControl` | default | Private / Allow invites / Member directory / Send welcome message. |
| `AgeRangeInput` | default | Age range min/max. |
| `MenuInput` | style `.wheel` | Max members picker. |

## Notes
- Differs from Edit Group only by: `.editable` cover (vs `.display`), "Create" link, and the create-vs-update action.
- Welcome message `MultilineTextInput` is conditional on `sendWelcomeMessage`.
- `.keyboardManaged()` + tap-to-dismiss-focus are screen-level modifiers, not components.
