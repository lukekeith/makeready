# Phase 5 — The UI 1.0 ⇄ 2.0 era switch  ·  app: capture

> Part of docs/features/component-browser/. Preconditions: Phases 1–4 VERIFIED.
> Added 2026-09-04 (owner request: "the /components route needs a way to identify UI 1.0 and
> UI 2.0 components"), after the suite's original 4 phases shipped.

## Goal

`/components` browses BOTH component universes, with a segmented switch at the top of column 1:

- **UI 1.0** — the built Swift components under `iphone/MakeReady/Components/` (phases 1–4,
  unchanged). Render = simulator capture; second side-panel tab = fixture Data.
- **UI 2.0** — the specced components of the UI 2.0 program (`docs/ui2/`). Render = the frozen
  Figma snapshot; second side-panel tab = the normative Contract.

## Why a switch and not a filter or a badge

The two are not subsets of one list. They have different identity (fs path vs `C-###`),
different sources (a filesystem walk vs `design-system/registry.md` + contract docs), and
different render truth (a capture vs a frozen design snapshot). A filter implies one set; a
badge on a merged tree would force 2.0 rows into folders they do not have. The era is a route
segment (`/components/1.0/…`, `/components/2.0/…`) so links, bookmarks and
`/component-resolve` are unambiguous; a path without an era redirects to 1.0 (where every
pre-existing link pointed) and a bare `/components` restores the last era used.

## Decisions (this phase)

| # | Decision | Rationale |
|---|---|---|
| D22 | The 2.0 era's components are **registry rows**, its variants are the contract's **designed states**, and its render is the **frozen Figma snapshot** | The registry is the exhaustive 2.0 component universe (UI2 D6); the snapshot is the only rendering that exists before the build |
| D23 | Design snapshots are registered as `Version` + `Screenshot` rows with platform **`design`**, keyed on the PNG's sha | Full parity for free — the version timeline and pinned comments work unchanged, and a `/ui2-component` re-run that refreshes the snapshot appends a version instead of silently replacing what comments were drawn on |
| D24 | A registry row with no contract doc renders a **spec checklist** carrying `/ui2-component <id> <figma-url>` | The 2.0 analogue of 1.0's wiring checklist + `/capture-add`: the same "this exists but isn't ready to view, here's the command" shape |
| D25 | Recapture becomes **Refresh snapshot** in 2.0 (single button, no all-variants menu) | There is no 2.0 code to capture; one snapshot covers every state of a set, so per-state recapture is meaningless |
| D26 | The browser **never writes specs** — `docs/ui2/` is read-only to it | Specs are owned by `/ui2-screen` / `/ui2-component`; the browser is a viewer + comment surface |

## Tasks (in order)

- [x] 5.1 `capture/lib/ui2-index.mjs` — parse `registry.md` (sections → `C-###` rows, rename
      notes split off the name), the `C-###-<slug>.md` contracts (normative source, frozen
      snapshot, state matrix in all three table shapes, props, OQ table) and the assets dir;
      cache on input mtimes — tests: `capture/test/ui2-index.test.mjs`
- [x] 5.2 DB: allow platform `design` (`ALL_PLATFORMS`), include it in `latestScreenshots` /
      `versionShots`, keep capture copy-forward on the two capture platforms only, and add
      `findVersionBySourceHash` — files: `capture/db/index.mjs`
- [x] 5.3 Server: `GET /api/ui2/tree`, `GET /api/ui2/detail`, `GET /api/ui2/version/:vid`,
      `POST /api/ui2/refresh` (dev only), static `/ui2-assets`, and `syncUi2Row()` (sha-keyed,
      idempotent) — files: `capture/server.mjs`, `capture/vite.config.js` (dev proxy)
- [x] 5.4 UI: `EraSwitch`, `Ui2Tree`, `Ui2ContractTab`, `Ui2SpecChecklist`, `Ui2Layout`,
      `ComponentsRoute` (era parsing + redirects); `RenderPane` / `VariantList` / `SidePanel`
      made era-agnostic via props with 1.0 defaults — files: `capture/src/pages/components/*`,
      `capture/src/components/viewer/ZoomPane.jsx`, `capture/src/App.jsx`, `capture/src/styles.css`
- [x] 5.5 Docs: era-qualified browser URLs in `07-capture.md` §6 and
      `.claude/commands/component-resolve.md`

## Phase gates (run fresh, record output)

- [x] `cd capture && npm test` — 35/35 green (22 subtests incl. the new ui2-index suite)
- [x] `npm run build` — clean
- [x] 1.0 regression: tree → variant → render → versions → Data tab, and
      `/components/<path>` still resolves (redirects into 1.0)

## Verification checklist

- [x] Era switch round-trips and the era persists across a bare `/components` visit
- [x] A specced row (C-042, C-045) renders its frozen snapshot with the state list, version
      timeline, Contract tab (Figma link, props, consumed-by, open questions)
- [x] An unspecced row (C-021) renders the spec checklist with the `/ui2-component` command
- [x] Comment parity on a design snapshot: pin → thread → badges in column 2 and the tree
- [x] `Refresh snapshot` reports "unchanged (same sha)" when nothing moved

## VERIFIED

✅ 2026-09-04:
- Parser indexes the real registry: 68 rows across 8 sections, 7 specced, 7 with a frozen
  snapshot; state matrices parse in all three table shapes with consumption states
  (`consumed` / `designed-unconsumed` / `unconsumed` / `undesigned`).
- API verified with curl on a parallel stack (:5961/:5960, leaving the user's :5950/:5951
  untouched): tree, detail, version, refresh, `/ui2-assets` (200 image/png), and a
  comment posted + read back + deleted on `ui2-c-045`.
- UI verified in Chrome across both eras, including the 1.0 regression walk.

## Post-build fixes

- **2026-09-05 — snapshot rendered at a 1:2 aspect after a state switch** (`ZoomPane`).
  `natural` was only ever set from the `<img>`'s `load` event, which does not fire for an
  image the browser already holds. Every state of a 2.0 component shares ONE snapshot URL, so
  switching states cleared `natural` (RenderPane resets it per version) without any event to
  restore it, and `geom` fell back to its `nw=1, nh=2` default — measured 0.500 rendered vs
  0.694 natural, with `img.complete === true`. Fixed by reading the size off the element on
  every render (`imgRef.complete && naturalWidth`); `onNatural` is idempotent in both hosts, so
  it settles in one pass. Also latent on the 1.0 side wherever a version copies a prior
  platform's shot forward and two versions share a path.

## Follow-ups (not in this phase)

- No `existing` / `existing-modified` rows exist in the registry yet, so the 1.0↔2.0 mapping
  column (a Swift component's "replaced by C-###", and its absence = drop candidate) has no
  data to render. When those rows appear, that cross-link is the gap-analysis coverage view
  (`docs/ui2/gap-analysis.md`) and should be added to both trees.
- Element-targeted comments (the hidden web-twin hit-test, 12-phase-3) have no 2.0 equivalent
  until 2.0 components are built; 2.0 pins carry their fraction only.
