# Change Membership

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/ChangeMembershipModal.swift`
**Type:** overlay/modal (full-screen fade-in, `.raw` chrome + `.topLevel` priority)
**Screen states:** populated — internal panels: main / confirm / transfer; mode `.joined` vs `.removed`

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `CardGroup` | `.photo` and `.icon` image styles | Transfer panel: one card per candidate group (member not already in) |

## Notes
- Three internal panels with up/down slide+fade transitions: **main** (action choices), **confirm** (confirmation copy), **transfer** ("Select a group" list).
- `.joined` mode main panel shows "Transfer groups" (secondary) + "Remove from group" (destructive); `.removed` mode shows "Rejoin group" (primary).
- Action rows are hand-rolled full-width buttons (label left + SF Symbol right), tiered primary/destructive/secondary/muted — NOT `ActionButton`.
- Transfer panel: scrollable `CardGroup` list with top edge-fade mask, a pulsing top-center chevron-down affordance, and an interactive drag-down-to-go-back gesture; empty-state text when the member is already in every group.
- Fixed top-right close (xmark) button lives outside the panel stack so it never slides with transitions.
- Owns its own full-screen fade-in via `ModalAnimations`.
