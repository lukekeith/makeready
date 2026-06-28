# Member Request Respond

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberRequestRespondModal.swift`
**Type:** overlay/modal (full-screen fade-in, `.raw` chrome + `.topLevel` priority)
**Screen states:** populated only

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none)_ | — | No custom MakeReady components used |

## Notes
- Self-contained confirmation-style modal; mirrors `ConfirmationOverlay` pattern.
- Owns its own full-screen `Color.appBackground` fade-in and content scale/opacity animation via `ModalAnimations.animateContentAppear` / `animateContentDismiss`.
- Buttons are hand-rolled full-width rows (Approve = `brandPrimary`, Reject = white 10%, Cancel = white 5%) — NOT `ActionButton`. Parity should match this three-tier button styling.
- Title block = member name (`s24Bold`) + a request sentence with formatted date/time.
- Dismissal is via the buttons only (taps on background are swallowed).
