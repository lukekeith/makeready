# Phase 2 — Browser shell: viewer extraction, route, tree, variants  ·  app: capture

> Part of docs/features/component-browser/. Preconditions: Phase 1 VERIFIED (contract frozen).

## Goal

`/components` exists in the SPA: the shared viewer components are extracted (with `/compare`
regression-free), the four-column layout mounts, column 1 (tree + search + badges + command
copy) and column 2 (variants) work end to end against the frozen contract, and deep links
resolve. Columns 3–4 render placeholders wired for Phase 3.

## Companion skills

None apply (capture SPA has no scaffolding skills; D12 names the fai-cd reference design).

## Tasks (in order)

- [x] 2.1 Viewer extraction: move `ZoomPane`, `CommentLayer`, `Thread` VERBATIM from
      `CompareDetail.jsx` (216-371, 118-195, 68-114) to `capture/src/components/viewer/`
      (+ `useElementSize`); CompareDetail imports from there; hosts keep view state,
      keybindings, and inspect plumbing (CR6) — files: `components/viewer/{ZoomPane,CommentLayer,Thread,useElementSize}.jsx`,
      `pages/compare/CompareDetail.jsx` · spec: 07 §2, §4 · tests: manual `/compare` walk in
      this phase's gates (capture has no component test rig; the extraction is import-moves)
- [x] 2.2 API client: `fetchComponentsTree`, `fetchComponentDetail(path, viewport)`,
      `fetchComponentVersion(versionId)`, `saveComponentFixture(path, variant, shared)` —
      files: `capture/src/api.js` · spec: 03 §2.1–2.4 · tests: exercised by the walk
- [x] 2.3 Route + layout: `/components/*` splat in `App.jsx` → `ComponentsLayout` (4-col grid,
      splat parsing per 07 §2, socket subscription per CompareLayout pattern, load-error states)
      — files: `App.jsx`, `pages/components/ComponentsLayout.jsx`, `src/styles.css`
      (`cmp-cols-*`) · spec: 07 §2, §3, G2 · tests: walk (deep-link paste)
- [x] 2.4 TreeView primitive per D12 (flat rows, roving tabindex, ARIA tree keys, chevron/row
      split, controlled `selectedId`) — files: `components/tree/TreeView.jsx`, `styles.css`
      (`cmp-tree-*`) · spec: 01 D12 · tests: walk (keyboard: arrows/Enter/Space)
- [x] 2.5 Column 1: `ComponentTree` (fetch, D11 filter, wiring/comment/collision badges, D13
      command-copy row actions) + `TreeSearchInput` — files:
      `pages/components/{ComponentTree,TreeSearchInput}.jsx` · spec: 07 §3.1, 01 D11/D13 ·
      tests: walk (filter `cardev`; copy both command forms)
- [x] 2.6 Column 2: `VariantList` (+ default-variant and unwired empty states) wiring selection
      into the route — files: `pages/components/VariantList.jsx` · spec: 07 §3.2 · tests: walk

## Phase gates (run fresh, record output)

- [x] `cd capture && npm test` — still green (no backend changes expected; catch accidents)
- [x] `/compare` regression walk: open an existing comparison + variant — zoom/pan/fit, comment
      pin place + reply + resolve, capture log dock — all behave as before the extraction
- [x] `/components` walk: tree renders 15 folders; filter `cardev` → `Card/CardEvent`; unwired
      + helper files gray-badged; `CardStudy` NOT gray (kebab join); collision badge absent
      (none today); copy row actions yield `/component-resolve Card/CardEvent` and
      `/component-resolve Card/**`; select variant → URL updates; paste that URL fresh → same
      selection restores

## Verification checklist

- [x] Contract parity: tree/detail consumption matches 03 §2.1/§2.2 field-for-field in code
- [x] Keyboard: tree follows the WAI-ARIA pattern (Up/Down/Left/Right/Enter/Space)
- [x] Spec-parity spot-check: D11 matching rule; D13 copy strings; 07 §2 splat parsing rule

## VERIFIED

✅ 2026-09-04 — gates run fresh in a live browser (Chrome via MCP):
- `npm test` 30/30 after all SPA changes; `vite build` clean.
- `/compare` regression: CardEvent/DateDisplay renders through the EXTRACTED viewer components
  (ZoomPane both panes, live web iframe, comment mode `c` → pin + draft composer with
  element-resolving chip + mirrored ghost cursor, Escape cancels); zero console errors.
- `/components` walk: 15 folders at depth 1; filter `cardev` → Card/CardEvent + CardEventMini
  (D11 matching); unwired components grayed (CardData, CalendarEventListView, …), CardStudy
  white (kebab join); selecting CardEvent auto-lands on first variant with URL
  `/components/Card/CardEvent/DateDisplay`; cold deep-link to `…/TimeDisplay` restores tree +
  variant selection and renders that variant; variant chips show version counts (2 after the
  Phase-1 recapture — retention visible in UI); unwired selection shows the not-capturable
  empty states; keyboard Down/Enter roving works.
- Copy affordance: handler + ✓-feedback shipped; the actual clipboard round-trip is exercised
  by Phase 4's E2E step 7 (hover-revealed button is hard to assert via screenshot).
- Cols 3–4 are the phase-planned placeholders (static shot / tab shell) — Phase 3 replaces them.
