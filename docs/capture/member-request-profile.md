# Member Request Profile

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberRequestProfilePage.swift`
**Type:** overlay/modal (slide-up)
**Screen states:** loading (spinner) / populated / error — always initials background (never a photo)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `ActionButton` | `.circleBlur` (x3) | Text / Call / Add-contact action row |
| `InfoPanel` | `.keyValue` mode and `.data` mode | Key-value panel (Age/Gender/Requested); data panels for Message, Phone/Email, group info, and group "About" |
| `PageTitle` | `.iconTitleLink` (xmark + "Approve") | Top bar: close icon left, Approve link right |
| `DialogOverlay` | default (x3) | Call, Text, and Email confirmation dialogs |

## Notes
- Always shows initials-circle background (join requests have no photo).
- Multiple `InfoPanel` `.data` panels: optional request message, contact info, group info (members/visibility/ages), optional group description.
- Approve uses a native `.alert` confirmation, not a custom overlay.
- `AddContactView` presented via `.sheet` (UIKit wrapper, not a listed component).
- Reads `OverlayManager` from the environment (vs Member Profile which is passed one).
