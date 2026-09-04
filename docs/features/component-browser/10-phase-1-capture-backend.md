# Phase 1 — Capture backend: fs index, retention, routes, MCP  ·  app: capture

> Part of docs/features/component-browser/. Preconditions: none — first phase.
> Signing this phase's VERIFIED block **freezes 03's contract**.

## Goal

The capture backend serves the full 03 contract: the fs-indexed component tree, viewport-scoped
detail with full version history, version-anchored comment support, the fixture write path, and
scope resolution over HTTP + MCP — with `/compare` behavior regression-free and the version
store retaining history. Provable by `npm test` green + the 08 §2 curls returning contract
shapes.

## Companion skills

None apply (no server/client/iphone scaffolding skills cover the capture app).

## Tasks (in order)

- [x] 1.1 Test harness: add `"test": "node --test test/"` to `capture/package.json` — files:
      `capture/package.json` · spec: 08 §1 · tests: the wiring itself (`npm test` runs, 0 files ok)
- [x] 1.2 DB retention + anchoring: DB-1 copy-forward (replace the re-parent move + drop
      `deleteMany`), DB-1b capturedAt bound on `versionShots()` fallback, DB-3
      `listVersions(comparisonId, {variantName, viewport, withScreenshots})` optional arg —
      files: `capture/db/index.mjs` · spec: 03 §1 (DB-1/1b/3), 01 D4/D5 · tests:
      `capture/test/versions.test.mjs` per 08 §1 (synthetic `__test-component-browser` rows,
      teardown deletes, NO captures — D19)
- [x] 1.3 fs index: `capture/lib/fs-index.mjs` — walk + kebab-join + wiring checks + collision
      flags + `resolveScope()` (D6 grammar incl. bare unique name) + cache policy (fs walk +
      ViewRegistry parse only; `fs.watch` recursive) — files: `capture/lib/fs-index.mjs` ·
      spec: 07 §1, 01 D3/D16/D17/D18, 03 §1 · tests: `capture/test/fs-index.test.mjs` +
      `capture/test/scope.test.mjs` per 08 §1 (temp tree; kebab pair; no-swift comparison;
      collision; helpers not-capturable; grammar incl. bare-name + ambiguity)
- [x] 1.4 Fixture write helper: `saveVariantShared(id, variantName, shared)` in
      `capture/runners/compare/lib.mjs` beside `saveComparisonShared` (explicit variant-name
      validation per CR16a; write via `updateComparisonRaw`) — files: lib.mjs · spec: 03 §2.4 ·
      tests: `capture/test/fixture-write.test.mjs` per 08 §1 (temp fixture file)
- [x] 1.5 Routes: `GET /api/components/tree`, `GET /api/components/detail` (viewport-scoped),
      `GET /api/components/version/:versionId` (screenshotId + variant+viewport comments +
      onThisVersion), `PUT /api/components/fixture` (dev-only gate), `GET /api/components/scope`
      — files: `capture/server.mjs` (new "── Components browser ──" section above the static
      serving block) · spec: 03 §2.1–2.5 exactly · tests: route-level assertions are covered by
      the unit tests of the pure logic (1.2–1.4) + the 08 §2 curls in this phase's gates
- [x] 1.6 MCP `resolve_scope`: describeComment-verbatim payload + `versionLabel` (CR14/CR15),
      iPhone-platform filter (CR11), collision error (CR21) — files: `capture/mcp/comments.mjs`
      · spec: 03 §2.5, §3 · tests: exercised via `resolveScope()` unit tests (1.3) — the tool is
      a thin wrapper; verify by invoking the tool once in the walk below

## Phase gates (run fresh, record output)

- [x] `cd capture && npm test` — all suites green
- [x] Restart the capture server, then: `curl -s localhost:5951/api/components/tree | jq '.tree | length'` (≥1),
      `curl -s "localhost:5951/api/components/detail?path=Card/CardEvent" | jq '.variants[0].versions'`,
      `curl -s "localhost:5951/api/components/scope?scope=Card/**" | jq .totals`,
      `curl -s "localhost:5951/api/components/scope?scope=CardEvent" | jq .totals` (bare name)
- [x] `curl -s localhost:5950/api/compare/manifest >/dev/null && echo ok` — /compare regression
- [x] `node capture/runners/compare/capture.mjs CardEvent pro-max iphone` — one real capture
      lands; then re-run the detail curl: the timeline has grown by one and prior versions remain

## Verification checklist

- [x] Detail response fields match 03 §2.2 field-for-field (trace in code, not by eye)
- [x] A second capture of the same variant leaves BOTH versions listed, and the older version's
      screenshots are intact in the DB (copy-forward, not move)
- [x] `addComment` with an old version's screenshotId → the Comment row's versionId = that old
      version (psql or a test)
- [x] `resolve_scope` on a scope containing an existing client-platform pin excludes it
- [x] CardStudy (kebab id) reports fully wired in the tree; a helper file (e.g.
      `Card/CardData.swift`) reports not-capturable
- [x] Spec-parity spot-check: 03 §2.5 versionLabel strings, 03 §2.4 unknown-variant 404, D17
      per-request fixture freshness (edit a fixture on disk → next tree fetch reflects it)

## VERIFIED

✅ 2026-09-04 — All gates green, run fresh this session:
- `npm test`: 30/30 (versions 7, fs-index 8, scope 10, fixture-write 5)
- Contract curls: tree (15 folders; CardEvent wired 2 variants; CardStudy kebab-joined; helper
  CardData unwired), detail (viewport-scoped timelines, screenshotId per version, resolve
  command), scope (`Card/**` → 35 components; bare `CardEvent`; unknown → 404), /compare
  manifest intact.
- Live verifications: iPhone-only comment filter (synthetic client pin excluded from scope,
  still visible to /compare; removed after), per-request fixture freshness (disk edit → next
  tree fetch reflects, restored byte-identical), addComment old-screenshot anchoring (test).
- Real-capture gate: `capture.mjs CardEvent pro-max iphone` → new version
  cmtmi90h90001v0dfbymocq64 landed AND the prior 2026-06-28 version cmqx21fwx004pslwihxj5sr05
  retained with its shot — retention + copy-forward proven with the real runner.
- MCP `resolve_scope`: verified via its HTTP twin (identical code path — buildScopePayload);
  the running MCP process picks it up on next Claude restart / /mcp reconnect.

**03's contract is now FROZEN.**
