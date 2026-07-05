---
description: Port ONE iPhone leader screen to the web LeaderApp with pixel parity — analyze the Swift source, build/extend the shared Vue twin, register it in the /compare system, capture + diff both platforms, wire production, verify, and update the parity manifest. With no argument, takes the next item from the manifest's dependency-ordered build queue. Designed to run in a FRESH session.
argument-hint: [screen-id from docs/parity/manifest.md — omit to take the next queued item]
---

# Parity screen — $ARGUMENTS

Port the iPhone screen **$ARGUMENTS** to the mobile-web LeaderApp with pixel
parity, following the proven pipeline below. Work ONE screen at a time; each
phase ends with something verifiable. The iPhone render is always the design
reference; the web is what you build.

**No screen id given?** Open `docs/parity/manifest.md` → **Build queue
(dependency-ordered)** → take the FIRST unchecked item, tell the user which one
you picked (and why it's next: its prerequisites are done), and proceed with it
as the screen id. If its listed prerequisites are NOT all checked, stop and
surface that instead of building out of order.

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
- One screen per run. Finish by updating `docs/parity/manifest.md` — that file
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
   :3010, postgres :5434) and `curl -s localhost:5950/api/compare/manifest`
   (capture UI). If missing, run `/dev-start`.

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
  managed-modal/slide-stack), `styles/_animated-border.scss`. If this screen
  needs the missing `.menu` or `.page` chrome, build `managed-menu.vue`
  (#111215, stroke #242937, content-sized bottom card) or `managed-page.vue`
  (translateX push, easeOut 300ms in / easeIn 250ms out) per the specs in
  `leader-app-study-management` memory.
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
   not HMR!) then `cd capture && node runners/compare/capture.mjs $ARGUMENTS
   pro-max client`.
5. Capture iPhone (with user approval): `node runners/compare/capture.mjs
   $ARGUMENTS pro-max iphone`.
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

## 5. VERIFY — user in the loop

- Tell the user exactly what to test live (`/admin/...` path + gestures) and
  what to look at in `http://localhost:5950/compare/$ARGUMENTS`.
- Process their pins with `/compare-resolve $ARGUMENTS` until clean.
- When they confirm: manifest row → ✅ `verified`, check off the item in the
  Build queue, update the area memory with anything non-obvious learned, and
  name the next queue item so the user knows what a bare `/parity-screen` will
  pick up.

**Exit checklist 5:** user confirmed ✓ · manifest → `verified` + queue item
checked off ✓ · area memory updated ✓ · next queue item named ✓
