# 01 — Architecture

## Overview

The capture app gains a second top-level surface, `/components` — an iPhone component browser.
Where `/compare` organizes comparisons by display group for iPhone↔web parity work, the browser
organizes **the iPhone component universe by its real filesystem structure** and serves a
different loop: inspect a component's variants and render history, annotate renders with
comments (including old versions), edit the fixture data that drives the render, and hand the
annotations to Claude via a scoped command that edits the Swift component and recaptures.

Everything renders through the machinery that already exists: fixture JSONs
(`capture/fixtures/compare/<group>/<Id>.json`), adapters (`capture/runners/compare/adapters/`),
the iPhone capture harness (`iphone/MakeReadyCaptureTests/ViewRegistry.swift`, 97 `component.*`
cases), the Postgres annotation store (`capture/prisma/schema.prisma`: Comparison / Version /
Screenshot / Comment / Message), and the capture runners
(`capture/runners/compare/capture.mjs`, `capture-batch.mjs`). The feature adds: a filesystem
index (path ↔ comparison), full version retention, version-bound comments, a 4-column UI, a
fixture-file write path, scope resolution, and the `/component-resolve` command.

## Decisions table

| # | Decision | Ruling | Decided by |
|---|---|---|---|
| D1 | Tree source | The tree mirrors the real filesystem under `iphone/MakeReady/Components/` (today: 15 category folders, 123 `.swift` files). Folders = directories; leaves = component files; scope paths are relative to `Components/` (e.g. `Card/CardEvent`). Reorganizing components = moving Swift files; the tree follows. | user 2026-09-03 |
| D2 | Tree contents | Every component file appears. Components without full wiring (fixture + adapter + ViewRegistry case) render grayed with a "not capturable" badge; selecting one shows the wiring checklist (07 §3.4) instead of a render. | user 2026-09-03 |
| D3 | Substrate | Same substrate as `/compare`: same fixture files, adapters, DB rows, runners, MCP server. A runtime **fs index** joins `Components/<…>/<Name>.swift` ↔ a comparison whose id equals the basename OR its kebab-case (real data has both: `CardEvent` ↔ `CardEvent.json`, `CardStudy` ↔ `card-study.json` — CR1, audit pass 3 2026-09-04); the wiring registry check likewise accepts `component.<Name>` or `component.<kebab>`. The 5 component-type comparisons with no `Components/**` Swift file (`GroupCard`, `card-study` aside, `CalendarEventListContent`, `CalendarWeekdayHeader`, `exegesis-highlight-menu`) stay `/compare`-only and do not appear in the browser. `/compare` behavior is unchanged except D4. | user 2026-09-03 |
| D4 | Version retention | Every capture creates a permanent Version + PNG. The pruning in `finalizeVariantVersion()` (`capture/db/index.mjs`) is removed **globally** — `/compare` inherits history too. Re-parenting is replaced by **copy-forward** (CR2, audit pass 3 2026-09-04): the non-captured platform's latest Screenshot is duplicated as a NEW row (same PNG path) on the new version, so retained versions keep their own shot rows; and `versionShots()`'s cross-version fallback gets time-bounded to `createdAt <= version.capturedAt` (matching its existing docstring, db/index.mjs:141-145). | user 2026-09-03; CR2 mechanics *(default)* |
| D5 | Comment↔version binding | `addComment()` (db/index.mjs:249) ALREADY derives `versionId` from its anchor screenshot, defaulting to the latest iPhone shot (corrected CR3, audit pass 3 2026-09-04). The browser therefore passes the **viewed version's `screenshotId`** (from 03 §2.2/§2.3) and `platform:"iphone"` on every comment POST; an explicit `screenshotId` wins over the latest-shot default (existing precedence). Comments remain keyed by (comparisonId, variantName, viewport) for listing; the versionId labels which render the author was looking at. Old-version comments are included in scope resolution, labeled with capture date + "current version is <id>". | user 2026-09-03 (semantics), defaults for mechanics |
| D6 | Resolve command | `/component-resolve <scope>`. Scope = fs path relative to `Components/`: `Card/CardEvent` (one component) · `Card/**` or bare `Card` (all components under the folder, recursive) · `**` (everything); amended G3 (audit 2026-09-03): a bare unique component name also resolves (ambiguity → error listing paths). The command gathers ALL unresolved comments in scope across variants and versions, edits the **Swift component** (or the fixture JSON when the comment is about data), replies + resolves each, and ends with one batch recapture of touched components. Ambiguous comments get a reply with options and stay unresolved (same policy as `.claude/commands/compare-resolve.md`). | user 2026-09-03 |
| D7 | Command payload discipline | The copied command is the scope string only — no ids, no context. All context is fetched at run time via the capture MCP (`resolve_scope`, existing comment tools). | user 2026-09-03 |
| D8 | Fixture edits persist to disk | The Data tab writes the variant's `shared` object back into the fixture JSON file (`capture/fixtures/compare/<group>/<Id>.json`) — git-visible, and the next capture uses it. No DB-side fixture overrides. *(default)* |
| D9 | Data editor shape | Recursive key/value form over `shared`: string/number/boolean fields get typed inputs; objects/arrays render as collapsible groups of the same; a value that fails round-trip editing falls back to a raw-JSON textarea for that key. Keys are not addable/removable in v1 — values only (adding keys is a fixture-file edit). *(default)* |
| D10 | Devices | Renders default to viewport `pro-max` (440×956, `capture/runners/compare/viewports.mjs`). A device picker appears in column 3 only when the fixture declares >1 viewport. Comments carry the viewport they were made on (existing schema). *(default)* |
| D11 | Tree search | The filter matches case-insensitively by substring after stripping every non-alphanumeric character from both the query and the candidate relative path (so `cardev` matches `Card/CardEvent`) — defined here (CR8, audit pass 3: grid/SearchInput has no matching algorithm to borrow, it is a caller-fed combobox). Matching prunes the tree to matching leaves + their ancestor folders. *(default)* |
| D12 | TreeView implementation | New `TreeView` component in the capture SPA implementing the design of `~/www/fai-cd/packages/ui/src/components/primitive/tree-view/tree-view.tsx`: flat DOM (one row per visible node, single `<ul role="tree">`), roving tabindex + WAI-ARIA tree keyboard pattern, chevron-vs-row click split in select mode, internal expansion state. Ported to capture's React 18 + plain-CSS (`cmp-*`) idiom — not imported as a dependency. Search, comment badges, and wiring badges are host-level additions. *(default; reference designated by user)* |
| D13 | Command copy affordances | Column 1 rows expose copy via context/hover action: component row → `/component-resolve <path>`; folder row → `/component-resolve <folder-path>/**`. Copy mechanism = `copyToClipboard` as in `CompareDetail.jsx`. *(default)* |
| D14 | Comments UI | Column 4 Comments tab reuses the `/compare` comment machinery: pin layer counter-scaled inside the zoom canvas, draft composer, threads with replies, resolve toggle, resolved-dimmed listing (`CompareDetail.jsx` CommentLayer 118-195, Thread). The web-iframe hit-test (`capture-inspect`) lives in CompareDetail's host code (`inspectWeb` :415-440), NOT in CommentLayer (corrected CR6, audit pass 3 2026-09-04) — extraction moves the components verbatim; each page host owns view state, keybindings (`c`/`0`/`Esc`), and any inspect plumbing; the browser host has none. *(default)* |
| D15 | Recapture trigger | Column 3 "Recapture" button = `POST /api/compare/capture {id, viewport, variant, platform:"iphone"}` — the platform arg is REQUIRED here: omitting it captures the web side too (server.mjs:1068→capture.mjs; CR10, audit pass 3 2026-09-04) — with SSE log + socket refresh, exactly as `/compare` does. "Save & Recapture" in the Data tab = fixture write (D8) then the same call. *(default)* |
| D16 | Wiring detection | wired = all three: (a) fixture JSON whose id matches the basename exists under `fixtures/compare/`; (b) adapter registered in `runners/compare/adapters/index.mjs`; (c) `case "component.<Name>"` present in `iphone/MakeReadyCaptureTests/ViewRegistry.swift` (parsed with a regex, cached per process, invalidated by mtime). Partial wiring shows which checks fail. *(default)* |
| D17 | fs index lifecycle | Only the fs walk and the ViewRegistry parse are cached (`fs.watch(dir,{recursive:true})` + registry mtime); fixture/adapter-derived fields (comparisonId, wiring, variants, viewports) re-derive per request — `loadComparisons()` is already disk-fresh per request, so fixture writes and hand-edits are never stale (CR13, audit pass 3 2026-09-04). Basename collisions (none today; both spellings checked) surface as an error badge on both nodes; a scope that matches a collided node makes `resolve_scope` error listing the colliding paths (CR21). *(default)* |

| D18 | Non-View Swift files | D2 stands verbatim (user ruling: every file appears): helper files (`CardData`, `CalendarModels`, `FlowLayout`, gesture utilities, …) render as permanently not-capturable rows. No exclusion rule in v1; a hide-helpers toggle is parked as O3. *(default, audit pass 3 2026-09-04)* |
| D19 | Test DB strategy | `versions.test.mjs` runs against the dev `makeready_capture` DB using a synthetic comparison id (`__test-component-browser`), creating Version/Screenshot/Comment rows directly via `db/index.mjs` (NO capture runs, no xcodebuild) and deleting them in teardown. *(default, audit pass 3 2026-09-04)* |
| D20 | Wiring-checklist add command | `addCommand` emits `/capture-add <kebab-case(basename)>` — capture-add's argument is the manifest/comparison-id token (kebab), not the Swift struct name. *(default, audit pass 3 2026-09-04)* |

## Requirement provenance

| R# | User's words (verbatim, once) | Operationalized criteria |
|---|---|---|
| R1 | "multicolumn UI that allows me to drill into components and view variants" | 4 fixed columns at `/components` per 07 §3: tree · variants · render · tab panel. Selecting tree leaf loads variants (col 2); selecting variant loads render (col 3) + panel (col 4). Deep-linkable route `/components/<path>/<variant>`. |
| R2 | "component navigation in a file folder like structure with a search filter at the top … a tree view that only shows components in their folder structure" | Column 1 = TreeView per D12 over the D1 filesystem tree, filter field above per D11. Folders expand/collapse; leaves select. |
| R3 | "variant navigation, if there are no clearly defined variants … then it's just 'default'" | Column 2 lists `variants[].name` from the component's fixture; a fixture with no `variants` array lists exactly one entry named `default` (matching `runners/compare/lib.mjs` getVariants fallback). Unwired components list nothing (col 2 empty state per 07 §3.2). |
| R4 | "pan/zoom render of the selected component and variant" | Column 3 = the existing ZoomPane (wheel zoom-to-cursor 0.2–8×, drag pan, `0` = fit) rendering the selected version's PNG. |
| R5 | "side by side field editor … edit the data fixtures used in the render … make changes to the data then click a button to recapture" | Column 4 Data tab per D9; Save writes the fixture file per D8; "Save & Recapture" then triggers D15. The subsequent render uses the edited data (verified in 08 E2E). |
| R6 | "support the same comment system we built for migrating pages" | Comments use the same Postgres Comment/Message models, POST/PUT/DELETE routes, and MCP tools as `/compare`; UI per D14. |
| R7 | "copy a command … run in claude to resolve all the comments I made on the component, then mark them as resolved … Once all that is done, a new render should be generated" | D6/D13: copied command is `/component-resolve <scope>`; the command replies + resolves each addressed comment via MCP and ends with a batch recapture producing new Version rows for every touched component. |
| R8 | "All old renders should be saved so I can compare old versions. I should be able to leave comments on old renders, but all those comments will be pulled into the command" | D4 retention + D5 binding: column 3 has a version timeline (newest first); selecting an old version displays its PNG and accepts comments; scope resolution returns unresolved comments from all versions, old ones labeled per D5. |
| R9 | "scope should be structured like {folder}/{folder}/{component} … or {folder}/{folder}/** " | Scope grammar per D6, resolved by `resolve_scope` (03 §3) against the fs index. |
| R10 | "the command in claude should be simple without a lot of context … All it should be is a scope" | D7: the command file's body contains the procedure; the copied invocation is `<command> <scope>` and nothing else. |

## Baseline patterns (by file:line)

- Capture backend route + spawn pattern: `capture/server.mjs` (`POST /api/compare/capture` → spawn runner, SSE `GET /api/capture/stream/:runId`, socket `compare:shot`).
- DB access layer: `capture/db/index.mjs` (`createVersion`, `finalizeVariantVersion`, `replyComment` re-open behavior).
- Variant/fixture normalization: `capture/runners/compare/lib.mjs` (`loadComparisons`, `getVariants` default-variant fallback).
- Pan/zoom + comments UI: `capture/src/pages/compare/CompareDetail.jsx` (ZoomPane ≈212-380, CommentLayer ≈118-197, tab switch, command copy ≈680-694).
- Nav/layout + socket subscription: `capture/src/pages/compare/CompareLayout.jsx`.
- MCP tools: `capture/mcp/comments.mjs` (list_unresolved_comments, reply_comment, resolve_comment, get_latest_screenshots).
- Command precedent: `.claude/commands/compare-resolve.md` (per-comment loop, ambiguity policy, verification, summary shape).
- TreeView design reference: `~/www/fai-cd/packages/ui/src/components/primitive/tree-view/tree-view.tsx` + `TreeView.scss` (API + a11y pattern; see D12).
- iPhone harness (read-only for this feature): `iphone/MakeReadyCaptureTests/ViewRegistry.swift`, `CaptureFixture.swift`, `CaptureFixtureLoader`.

## Permissions / RBAC

None — the capture app is a local dev tool with no auth; write routes stay dev-only-gated
(`!isProduction`) like the existing comment routes. No production app or org data is touched.

## Out of scope (deliberate)

- Wiring the unwired components (≈24 by fixture-join today; the exact set is computed at runtime by the fs index — fixture/adapter/ViewRegistry work) — stays per-component
  content work via `/capture-add`; the browser only *shows* wiring status.
- A web/twin pane or live iframe in the browser — iPhone renders only. `/compare` remains the
  parity surface.
- Physically reorganizing fixture JSON files to mirror the fs tree (rejected alternative to D3).
- Version retention limits, pruning tools, or PNG garbage collection.
- Tree drag-and-drop, rename, multi-select, or creating components from the browser.
- Adding/removing keys in the Data editor (values only, D9).
- Any change to the production server, client, or iPhone app code.
