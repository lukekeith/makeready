# Guest Contributor — Design-System Delta

← [README](README.md) · [UI/UX spec](04-ui-ux-spec.md)

**The question this answers:** *what does the guest-contributor feature need from our design system, and what's missing?*

**The short answer:** very little is missing. The web DS already carries this feature — including a purpose-built `components/invite/` kit that appears to have been scaffolded for exactly this. Across ~25 UI surfaces the feature needs, **2 are net-new components**, the rest are **reuse**, **wiring** (presentational → production API), or a **small island-mode modification**. This doc is the component-by-component ledger, the specs for the new components, and the DS conventions any new code must follow.

Grounded in a full read of the design system on `main` @ `776a4ab`. Canonical DS catalog: `docs/ui/COMPONENT_INVENTORY.md`.

---

## 1. The four verdicts

- **REUSE** — a ready DS component exists; use it unchanged.
- **WIRE** — a presentational component exists (story-backed) but isn't connected to a production store/API; connect it.
- **BUILD** — net-new component; must be authored to the DS contract (§4).
- **MODIFY** — existing production code needs a change (a prop, a gate, a loader).

---

## 2. The ledger

### Primitives & form controls
| Need | Verdict | Component / path |
|------|:------:|------------------|
| Primary/secondary/ghost/destructive button | **REUSE** | `components/primitive/button/button.vue` (10 CVA variants, sizes, loading) |
| Email / text input (with error state) | **REUSE** | `components/form/text-input/text-input.vue` |
| Multiline textarea (autosize) | **REUSE** | `components/form/textarea/textarea.vue` |
| Status pill (pending/approved/rejected) | **REUSE** | `components/data/status-badge/status-badge.vue` (lifecycle→tone map ~1:1) |
| Base badge / dot | **REUSE** | `components/primitive/badge/badge.vue` |
| Copy-to-clipboard field | **REUSE** | `components/invite/copy-link-field/copy-link-field.vue` |
| Segmented control / radio group | **REUSE** | `components/navigation/tab-slider`, `components/primitive/radio` |
| Confirmation dialog | **REUSE** | `components/overlay/confirmation-overlay/confirmation-overlay.vue` |
| Empty / completion state | **REUSE** | `components/primitive/empty-state/empty-state.vue` |
| Progress bar (upload) | **REUSE** | `components/primitive/progress-bar` |
| Spinner / skeleton (processing) | **REUSE** | `components/primitive/spinner`, `components/primitive/skeleton` |
| Alert (error/retry) | **REUSE** | `components/overlay/alert` |
| **Number stepper ("write N lessons")** | **BUILD** | *gap* — the only missing primitive (§4.2) |

### Invite kit (pre-scaffolded, presentational — needs WIRING)
| Need | Verdict | Component / path |
|------|:------:|------------------|
| Invite sheet w/ scope slot | **WIRE** | `components/invite/invite-sheet/invite-sheet.vue` (documented `#scope` slot) |
| Contributor role selector | **WIRE** | `components/invite/role-selector/role-selector.vue` |
| Program→lesson scope picker | **WIRE + extend** | `components/invite/invite-scope-selector/invite-scope-selector.vue` (add activity drill-down + "write-N" mode) |
| Scope chip ("Contributor · Lesson") | **REUSE** | `components/invite/scope-badge/scope-badge.vue` |
| Accept/decline decision card | **WIRE** | `components/invite/accept-invite-card/accept-invite-card.vue` (repurpose to Accept/Reject) |
| QR + native share | **REUSE** | `components/invite/qr-code-display`, `share-button` |

> These live under `components/invite/` with Histoire stories but are **not connected** to the production leader-app (whose live `share-invite-sheet.vue` does group QR+copy only). Wiring them to the new contribution-invite APIs is the bulk of Flow A's UI work — and it's assembly, not authoring.

### Forms, pickers, menus (patterns to follow / reuse)
| Need | Verdict | Reference |
|------|:------:|-----------|
| Multi-field form (validation + submit) | **REUSE pattern** | `components/card/create-program/create-program.vue` (validate-on-tap, "Required" badge, creating overlay) |
| Inline edit form (optimistic) | **REUSE pattern** | `components/card/edit-group/edit-group.vue` |
| Item picker (grid/modal) | **REUSE** | `islands/leader-app/components/media-library-picker-modal.vue`, `video-activity-picker.vue` |
| Add/managed menu | **MODIFY** | `islands/leader-app/components/add-menu-sheet.vue` (add "Invite contributor" row) |

### Shell, editors, video
| Need | Verdict | Component / path |
|------|:------:|------------------|
| Branded logged-out page shell | **REUSE (Blade)** | `resources/views/layouts/auth.blade.php` |
| "Continue with Google" button | **REUSE (Blade)** | `pages/leader-login.blade.php` `.google-btn` / `components/primitive/social-button.blade.php` |
| Contributor landing page + controller | **BUILD (Blade)** | new `ContributorController` + view mirroring `LeaderController.php` |
| Scoped app shell (no nav) | **MODIFY** | `islands/leader-app/leader-app.vue` (contributor-`mode` `v-if`, omit `NavBar`); also `components/layout/scoped-app-shell` exists as a reference |
| Contributor route | **MODIFY** | `islands/leader-app/router.ts` (+ `web.php` route + gate) |
| Lesson editor | **REUSE** | `islands/leader-app/components/edit-day-pane.vue` |
| Activity editors (write/read/youtube/exegesis) | **REUSE** | `edit-*-activity-pane.vue` |
| Scoped store loader | **MODIFY** | `stores/leader-program.store.ts` (add `loadContributorAssignment`) |
| `canEdit` capability (not creator-equality) | **MODIFY** | `edit-day-pane.vue:50`, `program-home-modal.vue:41` |
| Assignment/instructions panel | **BUILD (small)** | compose `layout/panel` + `text` + `badge` |
| **In-browser video capture** | **BUILD** | `<VideoCapture>` (§4.1) |
| Video record entry tile | **MODIFY** | `video-activity-picker-modal.vue` (add "Record" tile) |
| Video upload store action | **WIRE** | new `uploadContributorVideo` → existing upload pipeline + `updateActivityVideo` |

### Review & notifications
| Need | Verdict | Component / path |
|------|:------:|------------------|
| Review queue (sectioned pending list) | **REUSE pattern** | `components/card/group-members-page/group-members-page.vue` (Requests + "Respond") |
| Content preview (read-only) | **REUSE** | read-only editor panes (`canEdit=false`) or member lesson renderers |
| Publish-after-approve flow | **REUSE** | `islands/leader-app/components/enrollment-sync-pane.vue` / `review-changes-pane.vue` |
| Notification feed | **REUSE** | `islands/leader-app/components/notifications-modal.vue` |
| Contribution notification action | **WIRE** | add `view:'contribution-review'` handler to `stores/leader-notifications.store.ts` |

**Tally:** BUILD = 4 (`<VideoCapture>`, `number-stepper`, contributor Blade landing, assignment panel) · WIRE = ~6 · MODIFY = ~6 · REUSE = the rest (~15+).

---

## 3. Design tokens — no new tokens required

Everything maps onto existing semantic + structural tokens:
- Contributor identity color → `scope-badge` already uses the **brand/Primary** tone for `role="contributor"`. No new badge token.
- Status colors → `status-badge` reuses `--badge-*` (warning/success/destructive/neutral). No new token.
- The scoped shell, landing, and editors all inherit the dark theme (`--bg-canvas` `#0d101a`, `--bg-surface` `#252936`, brand `#6c47ff`). No palette change.

**Confirm during build:** whether the `status-badge` lifecycle enum needs `submitted` / `approved` / `rejected` labels added (it currently has `pending/confirmed/active/completed/expired/revoked`). If so, that's a **small enum extension**, not a token change.

---

## 4. New component specs

Both must follow the DS contract in §5.

### 4.1 `<VideoCapture>` — `components/domain/video-capture/`
The one substantial net-new component; also closes leader parity gap `docs/parity/manifest.md:131`.

- **Purpose:** acquire a video (record in-browser or pick a file) and hand back an uploaded, ready `Video` id + playback URL.
- **Props:** `{ maxDurationSec?, onComplete: (videoId, playbackUrl) => void, onCancel }`.
- **Two acquisition modes (both feed one pipeline):**
  1. **Record** — `navigator.mediaDevices.getUserMedia({video,audio})` + `MediaRecorder` → `Blob`; live preview, Record/Stop, playback, **Use/Re-record**.
  2. **Upload** — `<input type="file" accept="video/*" capture="user">`. **Required fallback** (iOS Safari `MediaRecorder` is unreliable); on mobile this opens the native camera.
- **Upload:** `POST /admin/api/videos/upload-url` → Cloudflare TUS/direct upload (resumable) → poll `/videos/:id/refresh` until `ready`.
- **States (all reuse DS pieces):** permission-prompt, permission-denied (explain + offer upload), recording, preview, uploading (`progress-bar`), processing (`spinner`/`skeleton`), error/retry (`overlay/alert`), done.
- **CVA:** `mode: { Record, Upload }`, `state: { Idle, Recording, Preview, Uploading, Processing, Error }`.
- **Out of scope (v2):** teleprompter (iPhone parity).
- **Story:** `.story.vue` covering each state with mocked streams/uploads.

### 4.2 `<NumberStepper>` — `components/form/number-stepper/`
Small primitive for "ask them to write **N** lessons."

- **Purpose:** bounded integer input with −/+ controls.
- **Props:** `{ modelValue, min=1, max, step=1, label? }`.
- **Composition:** two `components/primitive/icon-button` (−/+) around a centered `text` value; or an editable `text-input` core with steppers as prefix/suffix.
- **CVA:** `size: { Sm, Default }`, `state: { Default, Disabled }`.
- **Reuses:** `--control-h-*`, `--space-*`, `--radius-md`; brand focus ring token.
- **Story:** min/max clamping, disabled, keyboard ↑/↓.

*(If the team prefers not to add a primitive, the count can be composed inline from two `icon-button`s + `text` in the invite sheet — but a reusable stepper is the cleaner DS citizen and is trivially small.)*

---

## 5. Conventions any new/changed component must follow

Non-negotiable, enforced by tooling and review:
1. **Tokens only** — semantic/structural CSS custom properties; **no raw hex/px** (`npm run guard` fails the build otherwise).
2. **BEM + global SCSS** — `.vue` emits BEM classes; styles live in `client/resources/css/components/<category>/<name>.scss` and are `@use`'d in `app.scss`. The `.vue` never imports its own `.scss`.
3. **CVA 1:1** — variant keys in the `cva()` object match `.Block--modifier` SCSS names exactly; dual-`<script>` SFC pattern (`<script lang="ts">` exports `XCva`, `<script setup>` consumes).
4. **reka-ui**, not PrimeVue, for any interactive primitive on this surface.
5. **Histoire story** — every component ships `<name>.story.vue` rendering on `#0d101a`.
6. **Overlays** via the leader-app overlay manager (`present()`), not ad-hoc modals.
7. **Icons** — inline SVG into `components/primitive/icon`.
8. **Responsive** — rely on the single root `max-width:360px` token-rescale; no per-component breakpoints.

---

## 6. Build sequencing (ties to [03 delivery plan](03-delivery-plan.md))

| Delivery phase | DS work |
|---|---|
| **Phase 1** (contributor MVP) | WIRE invite kit → `ContributorInviteSheet`; BUILD `number-stepper`; BUILD contributor Blade landing; MODIFY leader-app island (contributor mode) + `router.ts` + scoped store loader + `canEdit` capability; BUILD assignment panel. Reuse all editors. |
| **Phase 2** (review) | WIRE review queue from `group-members-page` pattern + `accept-invite-card`; read-only preview; WIRE notification `action.view`. |
| **Phase 3** (video) | BUILD `<VideoCapture>`; MODIFY `video-activity-picker-modal` ("Record" tile); WIRE `uploadContributorVideo`. Ship to leader app too (parity). |

---

## 7. Bottom line for design-system planning

- **Add to the DS:** `<VideoCapture>` (domain) and `<NumberStepper>` (form) — both authored to the existing contract; `<VideoCapture>` benefits the whole app.
- **Promote from presentational to production:** the `components/invite/` kit (role/scope/accept/copy) — wire it to real APIs.
- **One capability refactor:** thread `canEdit` out of the editors as an injected capability instead of hardcoded creator-equality — a clean improvement that also enables the read-only review preview.
- **No new tokens, no theme change, no PrimeVue.** The feature fits the design system as it stands; the DS was, in places, evidently anticipating it.
