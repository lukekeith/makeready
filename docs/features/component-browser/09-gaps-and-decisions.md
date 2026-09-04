# 09 — Gaps & decisions ledger

Seeded by `/build-spec-draft` 2026-09-03. The audit appends G rows; the decisions gate closes
D/O/C rows; X rows track cross-app (here: cross-surface) risk.

## G — gaps (audit findings)

| # | Found | Status | Description | Resolution |
|---|---|---|---|---|
| G1 | 2026-09-03 audit | FIXED | 03 §2.2/§2.3 omitted per-version `screenshotId`, without which the browser cannot anchor a comment to the viewed (esp. old) version — `addComment()` derives `versionId` from the passed screenshot (db/index.mjs:257-270). | 03 amended (dated): both responses carry `screenshotId`. |
| G2 | 2026-09-03 audit | FIXED | 07 §2 used React Router v5 path syntax (`:path*/:variant?`); the app is on v6. | 07 amended: `/components/*` splat + fs-index-aware parsing rule. |
| G3 | 2026-09-03 audit | FIXED | D6 scope grammar rejected a bare component name (`/component-resolve CardEvent` → 404) — hostile ergonomics for the most common case. | Default adopted: unique basename resolves via byName; ambiguity → error listing paths. 01 D6 + 03 §2.5 + 08 scope tests amended. |
| G4 | 2026-09-03 audit | FIXED | D17 cited the adapter-watcher `fs.watch` pattern, which is single-dir; the Components tree is nested. | 07 amended: `fs.watch(dir, {recursive:true})` (darwin-local tool). |
| G5 | 2026-09-03 audit | FIXED | RenderPane manifest row omitted its comment-mode props (under-specified row invites mid-build invention). | 07 §4 row amended with the full comment prop set. |

## D — decisions needed

| # | Raised | Status | Question | Ruling |
|---|---|---|---|---|

## O — open questions (non-blocking)

| # | Raised | Status | Question | Notes |
|---|---|---|---|---|
| O1 | 2026-09-03 | OPEN | Tree thumbnails (03 §2.1) for 123 rows — render inline or lazy-load on scroll? Perf call for the build phase; either satisfies the contract. | |
| O3 | 2026-09-04 | OPEN | Hide-helpers toggle for non-View Swift files in the tree (D18 keeps them visible in v1 per the user's D2 ruling). | |
| O2 | 2026-09-03 | OPEN | Should the browser eventually surface `/compare` ratings or web-twin status per component? Explicitly out of scope now (01); note kept so the idea isn't lost. | |

## C — contract clarifications

| # | Raised | Status | Description | Resolution |
|---|---|---|---|---|

## X — cross-surface risks

| # | Raised | Status | Risk | Mitigation |
|---|---|---|---|---|
| X1 | 2026-09-03 | RESOLVED via CR2 copy-forward (pass 3, 2026-09-04) | DB-1 removes version pruning inside `finalizeVariantVersion()`, which every capture path shares — the other-platform shot re-parenting must survive the edit or `/compare` pairs stale shots. | `versions.test.mjs` covers re-parenting; E2E 8 regression walk. |
| X2 | 2026-09-03 | OPEN | Fixture files are now written by the UI (D8) AND hand-edited/git-managed. Concurrent edits are last-write-wins whole-file rewrites; a UI save can clobber an unsaved hand edit. | Accepted for a single-user dev tool; the write is formatted + git-visible so clobbers are recoverable. Revisit only if it bites. |
| X3 | 2026-09-03 | OPEN | The runtime command edits Swift components in scope-sized batches; a bad edit breaks the app build. | Command mandates `npm run ios:build-check` before batch recapture (07 §6). |

## Audit pass log

| Pass | Date | Findings | Result |
|---|---|---|---|
| 1 | 2026-09-03 | G1–G5 (all fixed in place, dated) + 1 contract-table correction (02 scope-endpoint consumers) + X1 verified safe in code | findings folded |
| 2 (delta over pass-1 amendments) | 2026-09-03 | re-read every amended section against the code already opened this session (db/index.mjs, server.mjs, App.jsx, lib.mjs, schema.prisma, CompareDetail.jsx) — zero new findings | **CLEAN** |

| 3 (cold-reader probe delta) | 2026-09-04 | CR1–CR21 from the fresh-context cold reader (21 findings; the load-bearing ones: kebab-case join CR1, copy-forward retention CR2, addComment-anchoring correction CR3, listVersions collision CR4, viewport-scoped detail CR9, platform:"iphone" on captures CR10, iphone-only scope comments CR11, batch CLI signature CR12, per-request fixture derivation CR13, MCP payload shape CR14, versionLabel semantics CR15, fixture-write validation CR16, /capture-add token CR17/D20, helper-files ruling CR18/D18, test-DB strategy CR19/D19, scope HTTP route consumer CR20, collision-scope error CR21; CR5≡G2 and CR-route overlaps already fixed in pass 1). ALL fixed in place (dated) across 01/02/03/07/08; new decisions D18–D20 recorded | findings folded |
| 4 (delta over pass-3 amendments) | 2026-09-04 | re-verified every amended claim against code opened this session (db/index.mjs, server.mjs, capture-batch.mjs:74, lib.mjs, mcp/comments.mjs, App.jsx) — zero new findings | **CLEAN** |

**Audit verdict: CLEAN (pass 4, 2026-09-04).** The pass-2 CLEAN was premature — the cold-reader
probe (draft phase 4) was still outstanding and returned 21 findings; the verdict stands only
as of pass 4. Cold-reader probe requirement: satisfied (its questions were all converted to
fixes/rulings; none remain unanswered).

*(superseded)* ~~**Audit verdict: CLEAN (pass 2, 2026-09-03).**~~ Phases A–F all ran; C/D collapsed into the direct
code reads (single-app feature, no consumer-parity surface); E's flow-walk produced G1–G5.

## Integrity check — 2026-09-03

**Verdict: SOUND** (0 corrections needed)

| # | Check | Result |
|---|---|---|
| 1 | Suite completeness | ✅ README + 01–09 present; 04/05/06 are explicit Not-affected docs |
| 2 | Citations (14 load-bearing) | ✅ all verified by opening: `finalizeVariantVersion` db/index.mjs:122 · `updateComparisonRaw` lib.mjs:94 · ZoomPane CompareDetail.jsx:216-371 · CommentLayer :118-195 · command copy :683-686 · comment routes gated `!isProduction` server.mjs:900-982 · `getVariants` default fallback lib.mjs:127-132 · viewports pro-max 440×956 (iphone-16-pro-max) viewports.mjs:15-20 · fai-cd tree-view.tsx exists · ViewRegistry/CaptureFixture files exist · compare-resolve.md + capture-add.md exist · grid/ + CompareContext.js exist |
| 3 | Counts re-run | ✅ 123 Swift files / 15 folders under Components/ · 97 `case "component.` in ViewRegistry (⇒ 26 unwired) · 135 comparison fixture JSONs · zero basename collisions today (D17 handling still specced) |
| 4 | Commands | ✅ `npm run ios:build-check` (root package.json:22), runner scripts, `/capture-add`, `/compare-resolve` all exist. `cd capture && npm test` does NOT exist yet — 08 §1 states the feature adds it (not a defect; build task) |
| 5 | Internal consistency | ✅ links resolve; ⬜ apps have no work in other docs; 05/06 consume nothing beyond 03; Decisions vs 09 consistent; no placeholders |
| 6 | Ledger ↔ artifacts | ✅ ledger says spec 🔄 all docs written; nothing built (no `/api/components` in server.mjs — grepped); progress 9% recomputed = recon 1 + design 3 + 10×0.6 − pending probe ≈ matches |
| 7 | Unverifiable claims | ✅ none marked; no bare-certainty claims found that lack a cited source |
| 8 | Language lint | ✅ banned-vagueness grep clean; R1–R10 present in 01 AND 08 traceability (both directions) |

Skipped: none. No live executions performed (existence + read verification only, per the skill).
