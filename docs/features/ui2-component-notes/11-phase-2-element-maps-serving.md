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

- [ ] 2.1 `capture/lib/png-size.mjs` — `pngSize(abs)` moved out of `server.mjs:1190` verbatim;
      `server.mjs` imports it (09 §G-3) · tests: E-7
- [ ] 2.2 `buildUi2Screens()` records `{ width, height }` on each snapshot
      (`lib/ui2-index.mjs:853-859`) · tests: E-7
- [ ] 2.3 Map parse + aspect guard + attach in `buildUi2Screens()` — malformed / mismatched /
      absent all collapse to `null`; a map element missing `ref` makes the whole map malformed
      (03 §1.2) · tests: E-1, E-2, E-3, E-6, X-1
- [ ] 2.4 `screen-detail` attaches `variants[].elements` with one `Map<ref, resolved>` per screen,
      reused for the existing `components[]` array, which gains `built` (09 §X-3, 07 §3) ·
      tests: R-5, R-6, R-7, E-4
- [ ] 2.5 Confirm the cache stamp already invalidates on a map edit — `dirStamp(screenAssetsDir)`
      (`lib/ui2-index.mjs:821`) is unfiltered, so this is a **regression test, not new code**
      (09 §G-6) · tests: E-5
- [ ] 2.6 The real-export guard fixture (09 §G-2): a test map built from
      `edit-field-group-fields.png`'s true dimensions, so the guard is proven against a real Figma
      export and not only a synthetic one · tests: E-6

## Phase gates

- [ ] `cd capture && npm test` — no new failures against the baseline
- [ ] `curl -s 'localhost:5951/api/ui2/screen-detail?id=home-dashboard' | head -c 400` → 200 with
      every pre-existing key intact

## Verification checklist

- [ ] A screen with no map returns `elements: null` and every other key unchanged
- [ ] A deliberately mis-sized map is discarded (`null`), and the screen still renders everything
      else
- [ ] `elements[].resolved` and `components[]` agree on every ref, `built` present on both
- [ ] Editing a map file and re-requesting serves the new rects without a server restart
- [ ] Spec parity: 03 §1.2's field table matches the parser field-for-field, composite semantics
      included

## VERIFIED

⬜ Not yet — do not open the next phase doc.
