# Member Profile

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberProfilePage.swift`
**Type:** overlay/modal (slide-up, swipe-to-dismiss)
**Screen states:** loading (spinner over seeded background) / populated / error — photo vs no-photo (initials) background

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `ActionButton` | `.circleBlur` (x3) | Text / Call / Add-contact action row |
| `InfoPanel` | `.keyValue` mode and `.data` mode | Key-value panel (Joined/Age); data panel (Phone/Email, tappable) |
| `CardGroup` | `.photo` and `.icon` image styles | One card per group the member belongs to; removed groups dimmed 0.5 + destructive border overlay |
| `DialogOverlay` | default (x3) | Call, Text, and Email confirmation dialogs |
| `ChangeMembershipModal` | `.joined` / `.removed` mode | Presented when a group card is tapped (remove / rejoin / transfer flow) |

## Notes
- Background is the member photo (cache-first, fades/slides in with modal) or a large initials circle when no photo.
- Name + background seeded from caller (`seedName` / `seedAvatarUrl`) so they animate in with the modal.
- Custom chevron-left close button (hand-rolled, only when `onDismiss != nil`).
- `AddContactView` (UIKit `CNContactViewController` wrapper) presented via `.sheet`, not a custom component.
- Loading and error overlays are hand-rolled VStacks layered over a stable background.
