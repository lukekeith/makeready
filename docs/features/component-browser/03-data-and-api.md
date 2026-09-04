# 03 — Data & API contract

The contract between the capture backend (producer) and its two consumers: the capture SPA and
the `/component-resolve` command (via MCP). Written to be implementable by a session that never
saw the spec conversation. Freezes when the backend build phase verifies.

## 1. Data model

**No Prisma schema changes.** `capture/prisma/schema.prisma` already has every field needed.
Three behavioral changes in `capture/db/index.mjs`:

| # | Change | Exact behavior |
|---|---|---|
| DB-1 | Version retention (D4, CR2) | `finalizeVariantVersion()` (db/index.mjs:122): the `deleteMany` goes away, and the re-parent **move** becomes a **copy-forward** — for each platform NOT captured this run, `prisma.screenshot.create` a new row on the new version duplicating the prior latest row's `{platform, device, path, width, height}` (same PNG file on disk). Retained versions keep every Screenshot row they ever had. DB-1b: `versionShots()`'s fallback query (db/index.mjs:151-156) gains `createdAt: { lte: version.capturedAt }` so a historical version pairs with its contemporaneous shot, matching the function's docstring. |
| DB-2 | Comment→version binding (D5, corrected CR3) | **No db change.** `addComment()` (db/index.mjs:249-283) already anchors: an explicit `screenshotId` wins; otherwise it falls back to the latest iPhone shot and derives `versionId` from the anchor. The browser always sends the **viewed version's `screenshotId`** (§2.2/§2.3 expose it) and `platform:"iphone"` (required — addComment throws otherwise); never-captured components post with no screenshotId → versionId null (allowed). `/compare`'s composer is unchanged. |
| DB-3 | Version listing (CR4) | The existing `listVersions(comparisonId)` (db/index.mjs:164, consumed by server.mjs:613) gains an OPTIONAL second arg: `listVersions(comparisonId, {variantName, viewport, withScreenshots})` — same shape plus `screenshots` when requested; the existing consumer's single-arg call is untouched. |

**The fs index** (D17) is runtime state, not persisted: `{ tree, byPath, byName }` built from
walking `iphone/MakeReady/Components/` (directories + `*.swift` basenames), joined against
loaded comparisons (basename === comparison id), adapter registry, and a cached ViewRegistry
parse (D16). Invalidation: `fs.watch` on the Components tree + existing adapter watcher +
ViewRegistry file mtime.

## 2. HTTP endpoints (capture backend, all new, dev-tool auth model: none; writes gated `!isProduction` like existing comment routes)

### 2.1 `GET /api/components/tree`

Response:
```jsonc
{
  "root": "iphone/MakeReady/Components",
  "tree": [ /* recursive */
    { "type": "folder", "name": "Card", "path": "Card", "children": [
      { "type": "component", "name": "CardEvent", "path": "Card/CardEvent",
        "file": "iphone/MakeReady/Components/Card/CardEvent.swift",
        "comparisonId": "CardEvent",          // null when unwired check (a) fails
        "wired": { "fixture": true, "adapter": true, "registry": true },
        "variantCount": 2,
        "unresolvedComments": 3,               // across ALL variants + versions
        "thumbnail": "/screenshots/compare/_shots/CardEvent/pro-max/iphone/<latestVersionId>.png", // null if never captured
        "collision": false                     // true per D17 basename collision
      } ] } ]
}
```
Errors: `500 {error}` if the Components dir is missing.

### 2.2 `GET /api/components/detail?path=Card/CardEvent&viewport=pro-max`

`viewport` optional, default `pro-max` (CR9): the per-variant `versions[]` timeline and every
`unresolvedComments` count in this response are scoped to the requested viewport (versions and
comments are keyed by (comparison, variant, viewport) — schema.prisma indexes). The D10
DevicePicker refetches this endpoint with the chosen viewport.

Response:
```jsonc
{
  "path": "Card/CardEvent", "name": "CardEvent", "comparisonId": "CardEvent",
  "wired": { "fixture": true, "adapter": true, "registry": true },
  "file": "iphone/MakeReady/Components/Card/CardEvent.swift",
  "fixtureFile": "capture/fixtures/compare/cards/CardEvent.json",   // null when unwired
  "viewports": ["pro-max", "se"],               // fixture's list; ["pro-max"] default
  "variants": [
    { "name": "DateDisplay",
      "shared": { /* the fixture variant's shared object, verbatim */ },
      "unresolvedComments": 2,
      "versions": [                              // newest first, per DB-3; [] if never captured
        { "versionId": "…", "capturedAt": "ISO", "viewport": "pro-max",
          "gitSha": "…", "gitDirty": false,
          "shot": "/screenshots/compare/_shots/CardEvent/pro-max/iphone/<versionId>.png",
          "screenshotId": "…",   // the iPhone Screenshot row id — the browser passes it to the
                                  // comment POST so addComment() anchors the pin to THIS version
                                  // (db/index.mjs:257 derives versionId from it) [G1, audit 2026-09-03]
          "unresolvedComments": 1 } ] } ],
  "commands": { "resolve": "/component-resolve Card/CardEvent" }
}
```
For an **unwired** component: `variants: []`, plus
`"wiring": { "missing": ["fixture"|"adapter"|"registry", …], "addCommand": "/capture-add CardStat" }`.
Errors: `404 {error:"unknown path"}`.

### 2.3 `GET /api/components/version/:versionId`

Response: `{ versionId, comparisonId, variantName, viewport, capturedAt, gitSha, shot,
screenshotId, sharedData, comments: [Comment] }` (`screenshotId` per G1, audit 2026-09-03) where `Comment` is the existing `/compare` comment shape
(`id, variantName, versionId, platform, viewport, x, y, resolved, messages[]`) filtered to
this comparison + variant + **this version's viewport**, across all versions (CR9); each
comment additionally carries `"onThisVersion": bool` so the UI can distinguish pins made on
this render. Errors: `404`.

### 2.4 `PUT /api/components/fixture`

Request: `{ "path": "Card/CardEvent", "variant": "DateDisplay", "shared": { … } }`.
Behavior: loads the fixture file (§2.2 `fixtureFile`), validates the variant name against
`getVariants()` names EXPLICITLY (the route 404s on an unknown name — it must NOT use
`getVariant()`'s silent first-variant fallback, lib.mjs:134-137; CR16a), replaces exactly that
variant's `shared` (or the top-level `shared` for the implicit `default`), and writes via the
existing `updateComparisonRaw()` (lib.mjs:94-102 — `JSON.stringify(raw, null, 2) + '\n'`,
preserving unrelated keys and key order; CR16b). Returns `{ ok: true, fixtureFile }`. The comparison cache reloads (existing
fixture loading is per-request via `loadComparisons()`; no extra invalidation needed).
Errors: `404` unknown path/variant · `409 {error:"unwired"}` when no fixture exists ·
`400` when `shared` is not an object. Gated `!isProduction`.

### 2.5 `GET /api/components/scope?scope=Card/**`

Scope grammar (D6, amended G3 audit 2026-09-03): `A/B/Name` exact component · `A/B/**` or bare
`A/B` (folder ⇒ recursive all) · `**` everything · bare `Name` resolves via the fs index's
byName map when the basename is unique (ambiguous → `409` listing the matching paths).
Matching is against fs-index paths; unknown scope → `404`. Response:

```jsonc
{ "scope": "Card/**",
  "components": [
    { "path": "Card/CardEvent", "comparisonId": "CardEvent",
      "swiftFile": "iphone/MakeReady/Components/Card/CardEvent.swift",
      "fixtureFile": "capture/fixtures/compare/cards/CardEvent.json",
      "viewports": ["pro-max","se"],
      "unresolvedComments": [
        { /* full existing MCP comment payload (capture/mcp/comments.mjs) … */
          "versionId": "…",
          "versionLabel": "current" | "old — captured 2026-08-30; current version is <id>",
          "pinnedScreenshot": "/abs/path/….png",       // the version the pin was made on
          "latestScreenshot": "/abs/path/….png" } ] } ],
  "totals": { "components": 12, "withComments": 3, "unresolvedComments": 7 } }
```
Rules (audit pass 3 2026-09-04): comments are filtered to `platform: "iphone"` (CR11 — web
pins belong to `/compare-resolve`; the two commands share the store but partition by platform).
Each comment is the MCP `describeComment()` payload verbatim (mcp/comments.mjs:32-71 —
`latestScreenshots` plural object, version nested; CR14) plus one added field: `versionLabel`,
computed as `"current"` when `comment.versionId` equals the newest version id for that
(comparison, variant, viewport), `"old — captured <date>; current version is <id>"` otherwise,
and `"unanchored (no version recorded)"` when versionId is null (CR15). A scope matching a
basename-collided node errors, listing the colliding paths (CR21). Components with zero
unresolved comments are included (empty array) so the command can report scope size honestly.
Unwired components appear with `comparisonId: null` and no comments. The HTTP route is the
MCP tool's twin (same code path) and exists for the 08 §2 curl gate; the SPA does not call it.

## 3. MCP additions (`capture/mcp/comments.mjs`, server `makeready-capture`)

| Tool | Input | Output |
|---|---|---|
| `resolve_scope` (new) | `{ scope: string }` | §2.5's response verbatim (absolute paths for all screenshots, as the existing tools do) |

Existing tools (`list_unresolved_comments`, `get_comment`, `reply_comment`, `resolve_comment`,
`get_latest_screenshots`) are unchanged and are what the command uses per-comment; their
payloads already include everything but `versionLabel`, which `resolve_scope` provides.

## 4. Existing endpoints consumed unchanged

| Endpoint | Used by | For |
|---|---|---|
| `POST /api/compare/capture` `{id, viewport, variant, platform:"iphone"}` | SPA (Recapture, Save & Recapture) | single component+variant capture — `platform` REQUIRED from the browser (omitting captures web too; CR10) |
| `node runners/compare/capture-batch.mjs <viewport> <ids…>` (CLI; viewport FIRST — capture-batch.mjs:74) or `POST /api/compare/capture-batch {ids[], viewport}` | `/component-resolve` command | one xcodebuild per viewport for all touched components; the command runs one batch per distinct viewport among the resolved comments (default `pro-max`) (CR12) |
| `GET /api/capture/stream/:runId` (SSE) | SPA | docked capture log |
| socket `compare:shot` / `compare:done` | SPA | live refresh of col 3 + tree thumbnails |
| `POST /api/compare/comparison/:id/comments` + replies/resolved/delete routes | SPA Comments tab | comment CRUD (request gains optional `versionId`, DB-2) |

## 5. Migration list

None. No `server/schema/` YAML, no Prisma migration, no Atlas step. DB-1/DB-2/DB-3 are code
changes in `capture/db/index.mjs` covered by the capture phase's tests (08 §1).
