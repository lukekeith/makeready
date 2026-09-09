# invite-home — Invite Home (single-invite detail)

Platform: iphone · Status: specced · Specced: 2026-09-02

The page opened by tapping an invite (owner, 2026-09-02): who was invited (phone), the
member account it linked to (when one exists), the group invitations riding on it, and the
invitation event timeline. Two designed content states in two frames.

## 1. Normative source

- Figma (state `unlinked`): https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3832-30788
  — node `3832:30788` ("Invite home", 440×1705); snapshot `assets/invite-home.png` (2026-09-02)
- Figma (state `linked`): https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3832-31138
  — node `3832:31138` ("Invite home multiple groups", 440×1705); snapshot
  `assets/invite-home-linked.png` (2026-09-02)
- Component-sheet sets consumed (D9): Header `3313:7615`, Detail `3499:27340`, Avatar
  `147:1513`, Search results `3668:7440` (+ new status-row symbols `3832:313xx`), Metadta
  `3518:29457` (incl. `state=Complete, type=Key value, align=Right` symbol `3832:31341`),
  History `3526:30939` (single state=Default), line `3526:31009`.

**Deviations (closed list):**
1. All names, phone numbers, dates, images, and event copy are sample content.
2. The status bar is the iOS system status bar.
3. The `unlinked` frame's group-invitation row carries a trailing 18pt chevron whose Figma
   slot is named "Close--outline" with a chevron-right asset swapped in — the glyph
   (chevron) is normative, the slot name is Figma hygiene (OQ-2 carries the semantics).
4. The timeline's two "User clicked invitation link / July 26" rows in the `linked` frame
   are duplicated sample rows, not a contract that identical events render twice.

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page: system status bar → **C-040 PageHeader** (`Two icons` + `showIcons=false`,
back + centered title "Invite") → vertical scroll content (p16, column gap
`space-section-gap` 32; hairlines `color-layout-border` between sections):

1. **Recipient hero** — "Invitation sent to" (Regular 14 `color-text-secondary`) over the
   phone number (`type-value-hero` SF Pro Regular 24/32 white, single-line ellipsis), 8 gap.
2. **Identity block — two designed content states:**
   - `unlinked` (frame 1): **C-041 DetailPair** ×2 in one row (16 gutter): "Invitation
     sent" (`Mon D, YYYY`) · "Invited by" (leader name).
   - `linked` (frame 2): member row (16 gap: **C-038 Avatar** 54 + C-041 "Existing
     member"/member name) → 32 → 2×2 C-041 grid (16 gaps): Age · Role · Birthday ·
     Joined. (The invitation-sent/invited-by pairs do not render in this frame.)
3. *hairline*
4. **Group invitations** — **C-020 SectionHeader** (`type-section-title`, accessory
   `none`) → 32 → one **C-037 ListResultRow** (type `Group+status`, 96pt incl. py16) per
   group invitation: 64pt circular group photo + group name (`type-title-card`,
   single-line ellipsis) + status **C-043 MetaChip** (Key value, align Right):
   "Sent «Mon D, YYYY»" (state Default) or "Accepted «Mon D, YYYY»" (state Complete,
   `color-positive` border); trailing 18pt chevron-right on the Sent row only (OQ-2).
5. *hairline*
6. **Invitation timeline** — C-020 (accessory `none`) → 32 → timeline block: a 1px
   vertical connector line (x-centered under the dots, inset 16 top / 28 bottom) behind
   stacked **C-065 TimelineEventRow** items (py8 each).

## 3. Behavior contract

**States (closed list):**
- `unlinked` — frame 1 composition (invite meta pairs; no member block).
- `linked` — frame 2 composition (member block + member meta; invite meta pairs absent).
- `loading` — hero renders from the tapped row's data; sections skeleton.
- `error` — section-level inline retry; page never blanks.
- Invite lifecycle rendering beyond Sent/Accepted chips (expired, revoked — `Invite.status`
  values exist server-side) is undesigned — proposed default: same chip anatomy, Default
  state, lifecycle word as label (OQ-5).

**Interactions (closed list):**
- Back → pop to the presenting screen.
- Group-invitation row (Sent, with chevron) → destination deferred (OQ-2); the Accepted
  row is designed without a chevron — proposed default: not tappable (OQ-2).
- Linked-member block tap → `members-profile` (proposed default per its universal-entry
  rule — the frame designs no explicit affordance; OQ-6).
- Timeline rows are display-only.
- Invite actions: none designed on these frames; Withdraw/Resend exist in C-066
  ActionMenuOverlay (2026-09-03) — the trigger on this screen pends frames (OQ-4).

**Motion:** system push/pop and scroll only.

## 4. Components

Closed list rendered: **C-020 SectionHeader** (×2, accessory none) · **C-037
ListResultRow** (`Group+status` — new consumed type) · **C-038 Avatar** (54 — new size) ·
**C-040 PageHeader** (Two icons, showIcons=false) · **C-041 DetailPair** (×2 / member
block + ×4) · **C-043 MetaChip** (Default and Complete, Key value, align Right) · **C-065
TimelineEventRow** *(introduced)*.

### C-065 TimelineEventRow (new)
Sheet set `3526:30939` ("History", single `state=Default`; the sheet's `line` `3526:31009`
is the connector). Row py8, 8 gap: 20pt dot glyph (tone `default` gray asset / `positive`
green asset — the two designed dot renders) + date (Regular 14/20 `color-text-secondary`,
fixed 100pt) + event text (Regular 14/20 white, flex, wraps — 36pt single-line / 56pt
two-line, content-driven). Event text may carry an inline `color-positive` span
("Accepted …"). Props: `dateLabel`, `text` (with optional highlighted range), `tone`.
**State coverage:** the set designs one state; the green dot + colored span are instance
overrides in the frame — contracted here as the closed `tone {default, positive}` axis;
further tones (negative/expired?) undesigned (OQ-3/OQ-5). The connector line is layout,
not part of the row.

### Amendments (dated 2026-09-02)
- **C-037 ListResultRow** — new consumed type **`Group+status`** (96pt: group photo 64 +
  name + status C-043 chip; optional trailing 18pt chevron — new symbols `3832:313xx`
  extend the set beyond the five types enumerated 2026-09-01). Closed change: this type
  joins the contract; existing types unchanged. Icon-swap hygiene per deviation 3.
- **C-038 Avatar** — size **54** joins the closed size list (32/40/54/64/164), evidenced
  by the linked-member block.
- **C-043 MetaChip** — first consumption of `Complete × Key value × Right` (sheet symbol
  `3832:31341`, added to the Metadta set after the 2026-09-01 probe). No prop change.
- **C-048 PageActionButton** *(not rendered here — sheet-accuracy note found during the
  probe)*: the color set `3517:29389` now shows **four** designed colors {Red, Green,
  White, Muted}; White and Muted are designed-unconsumed. Row note updated.

## 5. Data & API

Read-only screen. Verified against the makeready-api MCP + `server/prisma/schema.prisma`
2026-09-02:

| Need | Endpoint | Status |
|---|---|---|
| Invite record (recipient phone, sent date, inviter, per-group status + dates) | `GET /api/invites/{token}` (verified — public, token-addressed; `server/src/routes/invites.ts`) | **API-GAP: leader-facing invite detail** — the design aggregates MULTIPLE group invitations under one recipient phone, but `Invite` is one row per token with a single `groupId`; needs an assembled by-recipient payload (invites + statuses) with leader auth |
| Linked member (avatar, name, age, role, birthday, joined) | `Member.birthday`/`gender` verified earlier; member lookup by phone + `GET /api/members/{memberId}/profile` (verified) | ✅ pieces exist; linkage-by-phone rule belongs to the assembled payload |
| Invitation timeline (sent / link-clicked / invited / accepted events) | — (`Invite` has only `createdAt`/`acceptedAt`; no click tracking or event log) | **API-GAP: invite event history** — an event model (shape: invite ref, type from a closed taxonomy, timestamp, group ref) + capture of link-click events in the join flow (`server/src/routes/join.ts`) |

Writes: none.

## 6. Connections

- **Entry:** an invites list surface — `invites-home` (row added this run, pending-figma;
  the Invites nav tab evidenced on enrollments-home now has a confirmed detail page
  behind it, partially answering OQ-enrollments-home-4). Member-surface entries may be
  added by later specs.
- **Exits:** back → caller · Sent group-invitation row (chevron) → deferred (OQ-2) ·
  linked-member block → `members-profile` (proposed, OQ-6).
- **Overlays:** none.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

No legacy invite-detail screen exists on any platform — this page is new. Adjacent legacy
capabilities:

| Legacy element | Disposition |
|---|---|
| `ShareInviteSheet` (org-wide QR/join-code invite creation — `Components/`, per `leader-app-library-page` dossier) | **not this screen** — creation/sharing flow is unplaced in 2.0; gap-analysis candidate |
| Web join flows (`/join/{token}`, `server/src/routes/join.ts`) + `GET /api/invites/{token}` | **carried as the data source**; the join flow additionally must emit the timeline's click events (§5 gap) |
| Group join-requests review (`MemberRequestsPage`, Respond flows) | **distinct surface** — requests ≠ invites; stays with its own 2.0 screen when specced |
| `Route.swift` — no invite-related case exists (verified by grep 2026-09-02) | n/a (new screen) |

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-invite-home-1 | ~~Confirm `invites-home` is the Invites tab root~~ **RESOLVED 2026-09-05:** the C-019 TopNav contract closes the tab set at 8 including **Invites**, so `invites-home` is that tab's root; the `shell-tabs → invites-home` edge is recorded in the screen map | Closed | — |
| OQ-invite-home-2 | Sent-row chevron: destination (group invite management? resend surface?) and the rule that Accepted rows lose the chevron (proposed: rows tappable only while actionable) | No — deferred exit | owner |
| OQ-invite-home-3 | Timeline event taxonomy: closed list needed (observed: invitation sent · link clicked · invited to join · accepted); also whether other tones (e.g. negative for expired/revoked) exist | No for the spec; the API-GAP event model needs the closed list | owner + backend suite |
| OQ-invite-home-4 | No invite actions are designed on THESE frames — **partial answer 2026-09-03: Withdraw/Resend are designed in C-066 ActionMenuOverlay** (`design-system/components/C-066-action-menu-overlay.md`); the TRIGGER affordance on this screen is still undesigned (OQ-C-066-4) | No — trigger pends frames | owner |
| OQ-invite-home-5 | Undesigned lifecycle renderings: expired/revoked invite chips, empty timeline, `linked` member with hidden birthday/age. Proposed defaults in §3 | No | owner |
| OQ-invite-home-6 | Linked-member block tap → members-profile (proposed via its universal-entry rule; no designed affordance) | No — default proposed | owner |
