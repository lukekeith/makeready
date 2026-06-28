# Group Invite

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/GroupInvitePage.swift`
**Type:** screen (right-pane push within GroupHomePage; also has self-contained header)
**Screen states:** loading (ProgressView, only when no cached invite) / populated / error (failed to load invite) / copied-toast overlay

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitle` | Header: "Group Invite" + chevron.left back icon. |
| `BoxButton` | `.secondary` size `.md` | "Try Again" in the error state. |
| `BoxButton` | `.primary` size `.lg` | "Share Invite" (fullWidth, icon `.left`). |
| `BoxButton` | `.secondary` size `.lg` | "Copy Invite Link" and "Invite friends" (fullWidth, icon `.left`). |

## Notes
- The group-code box, QR code (white card with decoded base64 `UIImage`), and the "Copied to clipboard" toast are all hand-rolled (no `InviteQRCodeView` / `ShareInviteSheet` component here — QR is pre-decoded from `GroupInviteData.qrCode`).
- Loads from `AppState.shared.groupInvitesByGroupId` cache so the slide-in animates with content already laid out.
