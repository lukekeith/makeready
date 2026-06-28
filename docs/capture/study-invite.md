# Study Invite

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/StudyInvitePage.swift`
**Type:** overlay/modal (presented via `.fullScreenCover` from the schedule page)
**Screen states:** loading (spinner) / populated (code + QR + actions) / error ("Failed to load invite", retry) / copied-toast (transient)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` (leftIcon `xmark`) | Header "Study Invite". |
| `BoxButton` | `.primary`, `.lg`, `iconPosition: .left` ("Share Invite", `square.and.arrow.up`), `fullWidth`; `.secondary`, `.lg`, `.left`, `fullWidth` ("Copy Invite Link" `link`, "Invite friends" `person.badge.plus`); `.secondary`, `.md` ("Try Again" in error state) | Action buttons + error retry. |

## Notes
- The invite code box, QR-code panel (white-background `RoundedRectangle` + decoded base64 `UIImage`), and "Use this code at <url>" instruction are bespoke layout, not custom components.
- QR image is decoded from a base64 data URL returned by the API; a raw `ProgressView` shows while it decodes. No `InviteQRCodeView`/`QRCodeGenerator` component is used here.
- Copied-toast is a bespoke transient `Text` pill (raw `DispatchQueue.asyncAfter` timer), not a component.
- Share / Invite-friends use `UIActivityViewController`.
- The `#Preview` mirrors the layout with mock data and an `Image(systemName: "qrcode")` placeholder.
