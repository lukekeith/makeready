---
description: Port ONE iPhone leader screen to the web LeaderApp with pixel parity — analyze the Swift source, build/extend the shared Vue twin, register it in the /compare system, capture + diff both platforms, wire production, verify, and update the parity manifest. With no argument, takes the next item from the manifest's dependency-ordered build queue. Designed to run in a FRESH session.
argument-hint: [screen-id from docs/parity/manifest.md — omit to take the next queued item; "verify" to batch-verify all ready screens]
---

# Parity screen — $ARGUMENTS

Port the iPhone screen **$ARGUMENTS** to the mobile-web LeaderApp with pixel
parity, following the proven pipeline below. Work ONE screen at a time; each
phase ends with something verifiable. The iPhone render is always the design
reference; the web is what you build.

**Argument `verify`?** Skip the build pipeline entirely and run the **VERIFY
batch mode** at the bottom of this file. That mode is also the right response
when the user says they've finished testing a batch of `ready` screens.

**No screen id given?** Open `docs/parity/manifest.md` → **Build queue
(dependency-ordered)** → take the FIRST item that is neither done (`[x]`) nor
ready (`[~]`), tell the user which one you picked (and why it's next: its
prerequisites are done), and proceed with it as the screen id. Prerequisites
count as satisfied when `[x]` verified OR `[~]` ready — `ready` means built,
wired, diff-clean, and handed off for testing; only the user's live sign-off
is pending, and that never blocks downstream build work. If a prerequisite is
neither, stop and surface that instead of building out of order. If every
queue item is `[x]` or `[~]`, tell the user the build queue is drained and
suggest `/parity-screen verify`.

## Hard rules (re-read these before EVERY phase)

- Additive-only twin changes; never touch iPhone code except ViewRegistry
  capture cases; **never xcodebuild / commit without explicit user approval**.
- Match iOS mechanics, not just pixels: Motion tokens (standard 300ms
  ease-in-out slides, modal springs ≈ 400ms `cubic-bezier(0.32,0.72,0,1)` /
  300ms ease-in), dismiss-then-present sequencing via `dismissThen`, PageTitle
  carries only its own 8px inset, iOS VStack centers content-hugging children.
- Readiness/status logic must be ported from the actual Swift source (e.g.
  `StudyActivity.isConfigured`), not guessed.
- Every built screen must be previewable on the WEB side of /compare before
  the run ends (fixture + toClient + captured shot + `webBuilt` confirmed) —
  an iPhone-side seeding limitation is a note, never a reason to skip.
- One screen per BUILD run (the `verify` batch mode may sign off many `ready`
  screens at once). Finish by updating `docs/parity/manifest.md` — that file
  is how the next session continues.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per
item.** Do not advance with an ✗ — either fix it or surface why to the user.

## 0. Load context (always, especially in a fresh session)

1. Read `docs/parity/manifest.md` — find the screen's row: its iPhone source
   file, current status, compare id, notes, and its Build-queue entry's
   prerequisites (confirm they're checked). If it's not listed, add a row AND a
   queue entry first (pick the right section + queue position by dependencies).
   Skip phases the status says are done.
2. Read the memory index (auto-loaded) and open the relevant memories —
   at minimum `leader-app-study-management` (foundation architecture + traps)
   and `compare-twins-index` (per-twin traps). Check for a memory about this
   screen's area.
3. Confirm the environment is up: `docker compose ps` (client :8001, server
   :3010, postgres :5434), `curl -s localhost:5950/api/compare/manifest`
   (capture UI), and `curl -s -o /dev/null localhost:8002` (the HOST
   `/_capture` artisan that web captures MUST go through — see
   `capture-web-host-8002` memory). If missing, run `/dev-start`.

**Exit checklist 0:** manifest row found (or added) ✓ · prerequisites checked ✓
· relevant memories read ✓ · env up ✓

## 1. SPEC — analyze the iPhone screen

Launch an Explore agent over the iPhone source (path from the manifest row) and
its components. Its report MUST use this exact section skeleton — an empty
section means "verified none", never "didn't look":

```
## Layout        — exact top→bottom: spacings (pt), Typography tokens,
                   colors (from Colors.swift / ActivityStyle.swift), paddings,
                   corner radii, per-element
## States        — loading / empty / error / edit gating (isEditable) — how
                   each renders
## Presentation  — Route case → priority + chrome + dismissOnTapOutside (from
                   Services/Route.swift), OR SlideStack pane (parent + trigger)
## Transitions   — every Motion token used, entrance/exit choreography
## Data          — Actions called, endpoints + response fields consumed,
                   verified against server/src/routes/ (leader session reaches
                   them via the /admin/api/{path} proxy)
## Gating        — readiness/status logic ported verbatim from Swift (name the
                   source symbol, e.g. StudyActivity.isConfigured)
```

Write the spec's non-obvious findings into a memory file (`type: project`) so a
context clear doesn't lose it. Update the manifest row → `spec`.

**Exit checklist 1:** all 6 spec sections filled ✓ · endpoints verified against
server routes ✓ · memory file written ✓ · manifest → `spec` ✓

## 2. TWIN — build/extend the shared Vue component

- Leaf twins live in `client/resources/js/components/card/<kebab>/` + SCSS in
  `resources/css/components/card/<kebab>.scss` (register with `@use` in
  `app.scss`, alias if the BEM root could collide — check `compare-twins-index`
  for known collisions). Page/screen compositions are also card twins (e.g.
  `program-home`) so BOTH capture and production render the SAME component.
- **Twins change additively only**: new props default to the captured
  rendering; interactivity is added as emits (`select`, `toggle`) or an
  `interactive` prop — never alter existing markup/classes. Compare harnesses
  bind nothing.
- Register the component in
  `components/domain/component-capture/component-capture.vue` (import + map).
- Reuse the foundation: `islands/leader-app/overlay/` (routes/store/
  overlay-host/slide-stack), `styles/_animated-border.scss`. ALL FOUR chromes
  exist — `managed-modal.vue` (bottom sheet), `managed-menu.vue` (content-sized
  bottom card), `managed-page.vue` (horizontal push, built 2026-07-28 — see
  `parity-member-requests` memory), and `raw`. Register the route with the
  right chrome; never build new chrome or local scrims.
- SlideStack rule: detail panes must render from the SLOT's mounted item (not
  the live binding) so content survives slide-out.

Update the manifest row → `twin`.

**Exit checklist 2:** BEM root collision-checked ✓ · existing markup/classes
untouched (git diff shows additions only) ✓ · registered in component-capture ✓
· manifest → `twin` ✓

## 3. COMPARE — register + capture + diff

1. Fixture: `capture/fixtures/compare/<group>/$ARGUMENTS.json` — `{ id, type:
   "page"|"component", group, title, adapter, viewports: ["pro-max"], shared }`.
   Model the seed on an existing fixture; keep data deterministic (no live
   dates; see `compare-relative-time-base-epoch` / `compare-date-range-local-tz`
   memories). Omit remote image URLs (they never resolve in iPhone snapshots).
2. Adapter: `capture/runners/compare/adapters/$ARGUMENTS.mjs` with
   `toClient` (→ `pages.leader-twin`, `data:{component, componentProps}`) and
   `toIphone` (→ the ViewRegistry case + `auth` + `state`). Register in
   `adapters/index.mjs`.
3. iPhone side: check `iphone/MakeReadyCaptureTests/ViewRegistry.swift` for the
   case. If missing, add one (Swift edit) — but **NEVER run xcodebuild without
   the user's explicit approval**.
4. Capture web: `cd client && npm run build` (captures serve the BUILT bundle,
   not HMR!) then `cd capture && CAPTURE_BASE_URL=http://localhost:8002 node
   runners/compare/capture.mjs $ARGUMENTS pro-max '*' client`.
   **`CAPTURE_BASE_URL` is mandatory** — the default :8001 is the DOCKER
   client whose pages advertise a stale LAN VITE_ORIGIN and capture as
   silently BLANK shots (see `capture-web-host-8002` memory; the :8002 host
   artisan comes from `/capture-start`). **`'*'` captures every variant** —
   there is NO --variant flag; an unknown token silently falls back to the
   default variant only.
5. Capture iPhone (with user approval): `node runners/compare/capture.mjs
   $ARGUMENTS pro-max '*' iphone`.
6. **Diff programmatically first**: `cd capture && node
   runners/compare/diff.mjs $ARGUMENTS pro-max` — it prints a mismatch % per
   variant, the hottest vertical bands (in points), and writes a highlighted
   delta PNG to `_shots/$ARGUMENTS/pro-max/_diff/<variant>.png`. Read the
   delta PNG alongside BOTH platform PNGs
   (`capture/fixtures/compare/_shots/$ARGUMENTS/pro-max/*/`): solid red
   regions are real deltas to fix; faint speckle over text is cross-platform
   font antialiasing — ignore it. The % is advisory (fonts always differ),
   the band list tells you WHERE to look. Fix every real delta, re-capture
   the web side, and re-diff until the delta PNG shows no solid-red
   structural regions.
7. Known snapshot artifacts to NOT chase: blank remote images, invisible
   .ultraThinMaterial, entrance-animation-blank refs, status bar (twin gets a
   capture-only `statusBar` prop; production never passes it), animations
   frozen via `.capture-page`/`.capture-wrap` rules, height-only deltas from
   content-hugging tiles.
8. **The web side MUST be previewable in /compare — no exceptions.** The
   compare view is the user's review surface, not just a diff tool: every
   screen this pipeline builds gets a fixture + `toClient` + a captured web
   shot, even when the iPhone counterpart can't be seeded meaningfully (e.g.
   internal @State the harness can't reach, hardware-only panels). In that
   case still register/capture the web side, and record the iPhone-side
   limitation in the fixture (a `note` field) and the manifest — never skip
   the fixture entirely. If a wired state can't be reached by the existing
   variants (an open menu, an active filter, a populated tab), add a variant
   for it so the web rendering is visible, marking it web-only when the
   iPhone side can't match.
9. **Confirm visibility before leaving this phase**: after capturing, curl
   `localhost:5950/api/compare/manifest` and check the comparison's
   `completion.webBuilt` covers every variant. Remember: EDITED adapters need
   a capture-server restart to show up in the UI (added ones hot-reload).

Update the manifest row → `compare`.

**Exit checklist 3:** fixture deterministic (no live dates/remote URLs) ✓ ·
adapter registered in index.mjs ✓ · client rebuilt before web capture ✓ ·
diff.mjs run + delta PNG read ✓ · no solid-red structural regions left ✓ ·
every wired state has a variant ✓ · `webBuilt` covers all variants (curl) ✓ ·
capture server restarted if an adapter was EDITED ✓ · manifest → `compare` ✓

## 4. WIRE — production integration

- Store: extend/add a Pinia store in `islands/leader-app/stores/` (pattern:
  `leader-program.store.ts`) calling `/admin/api/*`. Note the proxy forwards
  JSON bodies on POST/PATCH/DELETE; file uploads for covers are base64 JSON.
- Presentation: register an overlay route in `overlay/overlay-routes.ts` if the
  iPhone presents it via OverlayManager (same route name + priority + chrome as
  `Route.swift`), or add it as a SlideStack pane if it's an in-page slide.
- Wire the entry point (the tap/button that opens it on iPhone) and the
  screen's own actions with iOS-exact strings for dialogs/labels.
- `cd client && npm run build` + `php artisan test` must be green.

Update the manifest row → `wired`.

**Exit checklist 4:** route/pane matches Route.swift (name + priority +
chrome) ✓ · entry point wired ✓ · dialog/label strings iOS-exact ✓ · build
green ✓ · `php artisan test` green ✓ · manifest → `wired` ✓

## 5. READY — hand off for verification (do NOT block on the user)

- Tell the user exactly what to test live (`/admin/...` path + gestures) and
  what to look at in `http://localhost:5950/compare/$ARGUMENTS`.
- Manifest row → `ready`, Build-queue item → `[~]` (ready — awaiting batch
  verify; satisfies prerequisites for dependent items).
- Update the area memory with anything non-obvious learned during the build.
- Name the next buildable queue item, then END the run. Verification happens
  later — in batch via `/parity-screen verify`, or whenever the user confirms
  directly. Never sit waiting for the user inside a build run.

**Exit checklist 5:** test script delivered ✓ · manifest → `ready` + queue
item `[~]` ✓ · area memory updated ✓ · next buildable queue item named ✓

## VERIFY batch mode — `/parity-screen verify` (user in the loop)

Signs off every `ready` screen in one pass instead of one per run.

1. Collect every manifest row at `ready` (queue items `[~]`). Confirm the env
   is up (same checks as phase 0) — the user is about to test live.
2. Print ONE consolidated test script, grouped by entry point so shared
   navigation is walked once (e.g. the group chain is a single walk: Groups
   tab → group card → Group Home → settings / invite / members panes), with
   each screen's checks condensed to its riskiest behaviors, plus the
   `http://localhost:5950/compare/<id>` links to review.
3. Process pins with `/compare-resolve <id>` until clean.
4. For each screen the user confirms: manifest row → ✅ `verified`, queue item
   `[~]` → `[x]`, area memory updated. A screen the user rejects drops back to
   the failing phase's status with a noted fix plan — fixes may run in this
   same session, then the screen returns to `ready`.
5. Name the next buildable queue item so the user knows what a bare
   `/parity-screen` picks up.

**Exit checklist V:** every confirmed screen → `verified` + `[x]` ✓ · every
rejected screen has a status rollback + fix plan ✓ · memories updated ✓ ·
next buildable queue item named ✓
