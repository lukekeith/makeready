# Guest Contributor — UI/UX Spec

← [README](README.md) · [Architecture](01-architecture.md) · [UX flows](02-ux-flows.md) · [Delivery plan](03-delivery-plan.md) · [Design-system delta →](05-design-system.md)

This is the build-ready UI spec: every screen mapped to concrete **design-system components** (with paths), the **scoped contributor shell** architecture, the **video capture** UI, and all states. It is grounded in a full read of the web design system on `main` @ `776a4ab`. The companion [05-design-system.md](05-design-system.md) is the pure component ledger (EXISTS / WIRE / BUILD / MODIFY).

> **Headline:** almost every surface has a ready component. The web `components/invite/` kit was *already scaffolded* for exactly this (role selector, scope picker, scope badge, accept card), the editors reuse cleanly in a scoped shell, and the notification feed has a pluggable action seam. The genuinely net-new UI is **one component — in-browser video capture** — plus a small **number stepper** and the **wiring** of the pre-built invite kit to real APIs.

---

## 0. Design-system contract (read before building any screen)

The member/leader web surface is a **dark-theme Vue 3 + reka-ui** system — **not PrimeVue** (PrimeVue is admin-SPA only; don't use it here). Everything the contributor feature touches lives in this system. Authoritative docs: `docs/ui/DESIGN_SYSTEM.md`, `docs/ui/COMPONENT_INVENTORY.md` (the canonical catalog), `docs/ui/DESIGN_SYSTEM_PRD.md`.

Every new component **must** follow the existing contract:
- **Tokens are the contract.** Consume semantic (`--bg-*`, `--fg-*`, `--border-*`, `--badge-*`) and structural (`--space-*`, `--radius-*`, `--text-*`, `--icon-*`, `--motion-*`) CSS custom properties. **No raw hex/px** — `npm run guard` blocks them.
- **BEM + CVA 1:1.** The `.vue` emits BEM classes only; SCSS is global (`client/resources/css/components/<category>/<name>.scss`, `@use`'d in `app.scss`). Variant keys in the `cva()` object map 1:1 to `.Block--modifier` SCSS names. Pattern: a plain `<script lang="ts">` exports the `XCva` object, `<script setup>` consumes it (see `components/primitive/button/button.vue`).
- **Overlays** go through the leader-app overlay manager (`islands/leader-app/overlay/overlay.store.ts` `present()`), not ad-hoc `v-if` modals.
- **Every component ships a Histoire `.story.vue`** (the workbench is Histoire, not Storybook) rendering on the real `#0d101a` canvas.
- **Icons** are inline SVG passed into `components/primitive/icon/icon.vue` (no name registry; Lucide-style paths inline).

Token quick-reference: spacing 4px base (`--space-xs`4…`--space-3xl`48); radius sm4/md8/lg16/full; text xs11…display32; control heights 32/40/48/64; brand `#6c47ff`; canvas `#0d101a`, surface `#252936`.

---

## 1. Flow A — Leader issues an invite

### A1 · Entry point — "Invite contributor"
Add an **Invite contributor** row to the study's add/managed menu. The menu family already exists: `islands/leader-app/components/add-menu-sheet.vue` (the two-pane AddMenu) and the managed-menu system. **MODIFY:** add one row that presents the invite sheet (A2).

### A2 · Invite contributor sheet
Compose the **already-built (but unwired) `components/invite/` kit** — this is the single biggest reuse win.

| UI element | Component (reuse) | Notes |
|---|---|---|
| Sheet container | `components/invite/invite-sheet/invite-sheet.vue` | Has a documented **`#scope` slot** "so the invite can be scoped before sharing" — the intended seam. |
| Invitee email | `components/form/text-input/text-input.vue` (`type=email`, state Error) | Email-lock target (D2). |
| Scope choice (lesson / activity / write-N) | `components/invite/role-selector` + `components/invite/invite-scope-selector/invite-scope-selector.vue` | `invite-scope-selector` **already picks a program → lesson**; extend it to also drill program → lesson → **activity**, and add a "write new lessons" mode. |
| "Write N lessons" count | **BUILD** `components/form/number-stepper` | The one primitive gap (see [05](05-design-system.md)). |
| Topic direction | `components/form/textarea/textarea.vue` (autosize) | `topicDirection`. |
| Expiry (optional) | `components/form/date-picker-field` **or** a `MenuInput` preset ("14 days") | Reuse existing. |
| Submit | `PageTitle` right-side text link ("Send invite"), validate-on-tap | Follow the **create-program** form pattern (`components/card/create-program/create-program.vue`): always-enabled link, red-border + animated "Required" badge on invalid, full-screen creating overlay on submit. |
| Result: copy link | `components/invite/copy-link-field/copy-link-field.vue` | Tri-state Copy→"Copied!"; writes clipboard + toast. |
| Result: QR (optional) | `components/invite/qr-code-display` + `share-button` | Reuse; secondary to the email-locked link. |

**Copy requirement (D2):** the result view states *"This link only works for {email} — it can't be used by anyone else."*

**WIRE:** a new store action `createContributionInvite(programId, {email, scope, count, topic, expiresAt})` → `POST /programs/:id/contribution-invites`. Model it on the existing `createInvite`/`generateQr` calls in `islands/leader-app/components/share-invite-sheet.vue` (which today does QR+copy only, group-scoped).

### A3 · Contributors / tracking section (on Program Home)
A new section listing outstanding invites + their status.

| UI element | Component (reuse) | Notes |
|---|---|---|
| Section container | `components/layout/section` + `sectioned-list` | |
| Per-invite row | `components/card/card-member`-style row **or** a light custom row | Show invitee email + scope. |
| Scope chip | `components/invite/scope-badge/scope-badge.vue` | Already renders "Contributor · Lesson". |
| Status chip | `components/data/status-badge/status-badge.vue` | `pending→Warning`, `active/approved→Success`, `revoked→Destructive`, `expired→Default` — maps to contribution lifecycle ~1:1. |
| Row actions | `components/primitive/button` (Ghost) — Revoke / Resend | Confirm via `components/overlay/confirmation-overlay`. |

This section doubles as the **review-queue entry** (Flow C): a `Submitted` row's primary action is **Review**.

---

## 2. Flow B — Contributor authors on the web (the scoped shell)

### B1 · Landing + Google sign-in (branded, logged-out)
A new **public Blade page** extending the existing branded shell — no Vue island required for the landing itself.

| UI element | Reuse | Notes |
|---|---|---|
| Page shell | `resources/views/layouts/auth.blade.php` | Dark `#0d101a`, PWA meta, mounts `ModalProvider`. |
| Invite summary | new Blade partial | "{Leader} invited you to contribute to {study}" + the **topic direction** + what's asked. |
| Sign-in button | reuse `pages/leader-login.blade.php` `.google-btn` markup / `components/primitive/social-button.blade.php` | "Continue with Google" (4-color SVG). Points at the **redemption-aware** OAuth entry (`/auth/google?invite=:token`). |
| Email-lock mismatch | new Blade state | "This invite is for {masked email} — sign in with that account." **Not** a generic error. |

**BUILD (small):** a `ContributorController` + Blade view mirroring `LeaderController.php` / `leader.blade.php`.

### B2 · The scoped editor shell — *reuse the leader-app island in "contributor mode"*
This is the architectural crux, and the research verdict is favorable: **the editors are coupled to the _shape_ of `useLeaderProgram().program` (a program whose `lessons[]` contains the target lesson), not to the whole study loading.** So we host the *unmodified* editor components in a minimal shell.

**Architecture (recommended — option 1 of the shell research):**
- **New Blade view + `ContributorController`**, mounting the **same `LeaderApp` island** with an island prop `mode: 'contributor'` + the target `grantId`/`lessonId`/`activityId`.
- `islands/leader-app/leader-app.vue` gets a `v-if` on `mode`: in contributor mode it renders a **minimal shell** — a slim header with the study name + a "Contributor" badge — and **omits the `NavBar` tab bar** (`components/card/nav-bar`) entirely. It still mounts `OverlayHost` + `ConfirmDialogHost` (needed by the Read/Exegesis editors' pickers and confirm dialogs) and the axios/CSRF setup.
- **New router route** `/admin/contribute/:grantId` → a `ContributorView` that seeds the scoped store (below) and renders `EditDayPane` (whole-lesson / write-N) or a single activity pane (activity scope) directly, wrapped in the existing `SlideStack`.

**Three concrete modifications (the only editor-side work):**
1. **Scoped loader — MODIFY `stores/leader-program.store.ts`:** add `loadContributorAssignment(grantId)` → `GET /contributor/assignments/:grantId`, populating `program.value` with a **single-lesson program object** (the store's `patchLesson` optimistic-write machinery then works unchanged — every write endpoint is already per-activity/per-block and never needs the full program).
2. **Relax the `canEdit` gate — MODIFY `edit-day-pane.vue:50` and `program-home-modal.vue:41`:** today `canEdit = memberId === store.program.creatorId`. Replace with an injected **capability** (`canEdit` provided by the shell: `true` for a contributor on their granted target, `false` in review-preview mode). This is the one small refactor — thread `canEdit` out instead of hardcoding creator-equality.
3. **Assignment panel — BUILD (small):** a pinned panel above the editor showing the leader's **topic direction** + a checklist ("Lesson 1 of 2 · Lesson 2 of 2" or "Activity: Video"). Compose from `components/layout/panel` + `text` + `badge`.

**What does NOT need changing:** the Write / YouTube / Read / Exegesis panes themselves (they operate on a single lesson/activity), the SlideStack, add-activity (needs only `programId`+`lessonId`, both props), and all write APIs.

**Editor reuse map:**
| Scope | Screen | Reused component |
|---|---|---|
| Whole lesson / write-N | Lesson editor | `islands/leader-app/components/edit-day-pane.vue` (+ its activity panes) |
| Write activity | text editor | `components/.../edit-user-input-activity-pane.vue` (loose coupling; emits `save`) |
| YouTube activity | url editor | `edit-youtube-activity-pane.vue` |
| Read activity | blocks editor | `edit-read-activity-pane.vue` (uses store directly, keyed by lessonId — works with the one-lesson program) |
| Exegesis activity | passage/highlights | `edit-exegesis-activity-pane.vue` |
| Video activity | picker + **record** | `video-activity-picker-modal.vue` + **BUILD `<VideoCapture>`** (B3) |

### B3 · In-browser video recording — the one net-new component
See [01 § 6](01-architecture.md#6-web-video-recording) for the pipeline. UI slots into the **existing** video picker.

- **MODIFY `video-activity-picker-modal.vue`:** add a **"Record"** tile alongside the "my videos" grid (the slot the iPhone reserves for camera).
- **BUILD `components/domain/video-capture/video-capture.vue`** (`<VideoCapture>`):
  - **Record mode:** permission prompt → live `getUserMedia` preview → Record / Stop (`MediaRecorder`) → playback → **Use this / Re-record**.
  - **Upload mode (required fallback):** file `<input accept="video/*" capture="user">` — on mobile Safari (unreliable `MediaRecorder`) this is the primary path.
  - Upload progress (reuse `components/primitive/progress-bar`), "Processing…" state (reuse `spinner`/`skeleton`), error/retry (reuse `overlay/alert`).
- **WIRE:** new store action `uploadContributorVideo(blobOrFile)` → `POST /admin/api/videos/upload-url` → Cloudflare TUS/direct upload → poll `/videos/:id/refresh` → then the **existing** `updateActivityVideo(lessonId, activityId, videoId, playbackUrl)` links it. Only capture+upload is new; the link step exists.
- **Shared:** the same "Record" tile lands in the leader video picker too — closing parity gap `docs/parity/manifest.md:131`. Build `<VideoCapture>` in the shared `components/` layer, not contributor-only.

### B4 · Submit for review
- Persistent **Submit for review** button (`components/primitive/button` Primary, Block) enabled when required items exist.
- On submit: confirmation via `components/overlay/confirmation-overlay` → success toast ("Sent to {leader} for review") → the shell shows a submitted/locked state (v1 **locks** editing until the leader acts).
- Returning via the same link before approval → back into the editor; after approval/revoke → a friendly "This contribution is complete" state (reuse `components/primitive/empty-state`).

---

## 3. Flow C — Leader reviews

### C1 · Review queue
Entry: the Program Home **Contributors** section (A3), a `Submitted` row → **Review**. Also a notification (C3).

Compose the **existing join-request review pattern**: `components/card/group-members-page/group-members-page.vue` renders a **"Requests" section** of rows each with a purple **"Respond"** action — structurally a review queue. Reuse that sectioned pending-vs-settled shape, with `status-badge` per row.

### C2 · Review a contribution (decision + preview)
| UI element | Reuse | Notes |
|---|---|---|
| Decision card | `components/invite/accept-invite-card/accept-invite-card.vue` | Already has inviter avatar + `ScopeBadge` + **Accept (Primary) / Decline (Ghost)** — repurpose to Accept/Reject. Its story already uses `role="contributor"`. |
| Attribution | `components/primitive/avatar` + `text` | "Guest author: {name}". |
| **Content preview** | reuse the **read-only editor panes** (`canEdit=false`) **or** the member lesson renderers | Cleanest "see what a member sees": render the produced lesson via the same renderers. The `canEdit=false` path already yields read-only editors (the capability we thread in B2·2). |
| Accept action | → `POST /contributions/:id/approve` | Clears the quarantine gate; offer "Publish updates now?" if the study is live (reuse `enrollment-sync-pane`/`review-changes-pane` flow). |
| Reject action | → `POST /contributions/:id/reject` | v1 simple reject; v2 adds `feedbackNotes` + resubmit. |

### C3 · Notification
The feed is **fully built**: `islands/leader-app/components/notifications-modal.vue` + `stores/leader-notifications.store.ts`. `NotificationAction = { label, view, params }`; today only `view:'enrollment-sync'` is wired. **WIRE:** add a `view:'contribution-review'` handler that opens C2 in the modal's in-place `SlideStack`. The feed UI, unread handling, action buttons, and relative-time are all done.

---

## 4. Flow D — Member view
**No member-side UI changes.** Approved+published content flows through the existing lesson player. The only optional addition (open product decision) is a member-facing "Guest teacher: {name}" line on the lesson header — a trivial `text` addition if enabled per-invite.

---

## 5. Screen → component reuse summary

| Screen | Verdict | Primary components |
|--------|---------|--------------------|
| Invite entry (menu row) | MODIFY | `add-menu-sheet` |
| Invite sheet | WIRE + build stepper | `invite/invite-sheet` (+`#scope`), `role-selector`, `invite-scope-selector`, `text-input`, `textarea`, `copy-link-field`; BUILD `number-stepper` |
| Contributors/tracking section | WIRE | `section`, `sectioned-list`, `scope-badge`, `status-badge`, `button` |
| Contributor landing + Google | BUILD (Blade) | `layouts/auth.blade.php`, `leader-login` `.google-btn` |
| Scoped editor shell | MODIFY (island mode) | `leader-app.vue` (contributor `v-if`), `router.ts`, scoped store loader, `canEdit` relax |
| Editors (write/read/youtube/exegesis) | REUSE as-is | existing `edit-*-activity-pane.vue` |
| Video record | BUILD | `<VideoCapture>` + modify `video-activity-picker-modal` |
| Submit / complete states | REUSE | `button`, `confirmation-overlay`, `empty-state`, toast |
| Review queue | REUSE pattern | `group-members-page` Requests shape, `status-badge` |
| Review decision + preview | REUSE | `accept-invite-card`, read-only editor panes / lesson renderers |
| Notification | WIRE | `notifications-modal` + new `action.view` handler |

**Net-new components: 2** (`<VideoCapture>`, `number-stepper`). **Everything else is reuse, wiring, or a small island-mode modification.** Full ledger in [05-design-system.md](05-design-system.md).
