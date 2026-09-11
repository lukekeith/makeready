# Phase 2 — Element maps: parsing, guard, serving  ·  app: capture (backend)

> Preconditions: Phase 1 **VERIFIED**. The map format is [03](03-data-and-api.md) §1.2 as ruled at
> the decisions gate (09 §G-5): the map describes the exported image's own coordinate space.

## Goal

A `<stem>.elements.json` beside a screen snapshot is parsed, aspect-checked and served on
`screen-detail` with every `ref` resolved against the registry — or collapses to `null` without
drama. No UI yet: this phase is provable entirely with `curl` and unit tests.

## Companion skills

None. `server.mjs`'s `ui2ElementMap()` (`:1168-1187`) is the shape to follow; the screen path is
parallel to it, not a reuse (it is gated on `platform === 'iphone'` and reads from `compareRoot`).

## Tasks (in order)

- [x] 2.1 `capture/lib/png-size.mjs` — `pngSize(abs)` moved out of `server.mjs:1190` verbatim;
      `server.mjs` imports it (09 §G-3) · tests: E-7
- [x] 2.2 `buildUi2Screens()` records `{ width, height }` on each snapshot
      (`lib/ui2-index.mjs:853-859`) · tests: E-7
- [x] 2.3 Map parse + aspect guard + attach in `buildUi2Screens()` — malformed / mismatched /
      absent all collapse to `null`; a map element missing `ref` makes the whole map malformed
      (03 §1.2) · tests: E-1, E-2, E-3, E-6, X-1
- [x] 2.4 `screen-detail` attaches `variants[].elements` with one `Map<ref, resolved>` per screen,
      reused for the existing `components[]` array, which gains `built` (09 §X-3, 07 §3) ·
      tests: R-5, R-6, R-7, E-4
- [x] 2.5 Confirm the cache stamp already invalidates on a map edit — `dirStamp(screenAssetsDir)`
      (`lib/ui2-index.mjs:821`) is unfiltered, so this is a **regression test, not new code**
      (09 §G-6) · tests: E-5
- [x] 2.6 The real-export guard fixture (09 §G-2): a test map built from
      `edit-field-group-fields.png`'s true dimensions, so the guard is proven against a real Figma
      export and not only a synthetic one · tests: E-6

## Phase gates

- [x] `cd capture && npm test` — **92 tests, 91 pass, 1 fail** (the same pre-existing
      `parseContract` failure; +8 tests this phase, all green)
- [x] `curl 'localhost:5951/api/ui2/screen-detail?id=home-dashboard'` → 200, every pre-existing
      key (`spec`, `snapshot`, `viewports`, `commands`, `era`) intact

## Verification checklist

- [x] A screen with no map returns `elements: null` and every other key unchanged
- [x] A deliberately mis-sized map is discarded (`null`), and the screen still renders everything
      else
- [x] `elements[].resolved` and `components[]` agree on every ref, `built` present on both
- [x] Editing a map file and re-requesting serves the new rects without a server restart
- [x] Spec parity: 03 §1.2's field table matches the parser field-for-field, composite semantics
      included

## VERIFIED

✅ **2026-09-10**

**Gates.** `npm test` → 92 / 91 pass / 1 fail (the pre-existing `parseContract` case). Eight new
tests: E-1…E-7 and X-1.

**Walk.** Against the restarted server, with a temporary map on `home-dashboard` (removed
afterwards — phase 3 writes the real ones):

- **R-5** `variants[0].elements` carried four instances with `generatedBy` intact; `C-019`
  resolved `{ specced: true, built: true, hasSnapshot: true }`, the two `C-023` chips resolved
  identically from **one** cache entry, and the retired `C-899` came back `resolved: null`
  **without being dropped** — the rect and its stored name are the only things left to label it.
- **R-6** `groups-home`, which has no map, returned `elements: null` with `snapshotFile` and its
  version timeline unchanged.
- **R-7** `components[]` now carries `built` for all 16 rows and agrees with `elements[].resolved`
  by construction — they read the same `Map<ref, resolved>` (09 §X-3).
- **E-2 is the one that matters**: the draft's own worked example (440×2126 for a frame that is
  really 440×2730) is discarded by the guard at 28% divergence, while 440×2744 — export rounding —
  attaches. That is the G-4 mistake, now caught by a test rather than by a blank screen.
- **E-6** the composite case: `edit-field-group-fields.png` (1176×3286, a section of six frames)
  parses and passes the guard with rects as fractions of the whole sheet, which is what the G-5
  ruling promised.

**Cache invalidation needed no code** (E-5): `dirStamp(screenAssetsDir)` is unfiltered, so writing
a `.elements.json` already changes the stamp. The test stays as a regression guard.
