# 02 — App impact

## Scope per app

| App | In scope | What changes | Owner doc |
|---|---|---|---|
| server | ⬜ | Production Express server untouched — this feature lives entirely in the capture dev tool, which has its own Express (`capture/server.mjs`). | 04-server.md |
| client | ⬜ | No web-app change — the browser shows iPhone renders only; the `/compare` web-twin iframe flow is not part of this feature. | 05-client.md |
| iphone | ⬜ | No app or test-harness code change. `iphone/MakeReady/Components/` is READ by the capture backend as the tree/scope source of truth, and `ViewRegistry.swift` is PARSED for wiring status — both read-only. (The `/component-resolve` command will later *edit* Swift components, but that is the command's runtime work on user comments, not part of building this feature.) | 06-iphone.md |
| capture | ✅ | Backend: fs index, ~6 new `/api/components/*` routes, fixture write route, version-pruning removal, MCP `resolve_scope` tool. Frontend: `/components` route with the 4-column UI (TreeView, variant list, ZoomPane + version timeline, Comments/Data panel). Prisma: no schema change (behavioral only). | 07-capture.md |
| root `.claude` | ✅ | One new command file: `.claude/commands/component-resolve.md` (specified in 07 §6; shipped in the capture phase). | 07-capture.md §6 |

Cross-check against `.claude/CLAUDE.md` §Cross-App Impact Guide: the closest listed change type
is "Screenshot fixtures → capture only", which this matches. No database-schema, API, auth, or
content-model rows apply — the only database touched is capture's own annotation store, with no
schema migration.

## The contract (who produces, who consumes)

| Contract | Producer | Consumers | Defined in |
|---|---|---|---|
| `GET /api/components/tree` | capture backend | capture SPA | 03 §2.1 |
| `GET /api/components/detail` | capture backend | capture SPA | 03 §2.2 |
| `GET /api/components/version/:versionId` | capture backend | capture SPA | 03 §2.3 |
| `PUT /api/components/fixture` | capture backend | capture SPA | 03 §2.4 |
| `GET /api/components/scope` + MCP `resolve_scope` | capture backend / MCP server | `/component-resolve` command only (corrected audit 2026-09-03 — tree badges come from `/tree`) | 03 §2.5, §3 |
| Existing: `POST /api/compare/capture`, `capture-batch`, SSE stream, socket events, comment CRUD routes, comment MCP tools | capture backend | capture SPA, `/component-resolve` command | 03 §4 (referenced, unchanged) |

## Cross-app sequencing

Single-app feature — sequencing is within the capture phase plan, not across apps:

1. `03` contract settled (this suite).
2. Backend units (fs index → routes → retention change → MCP tool) before frontend columns
   that consume them; the command file last (it depends on the MCP tool).
3. Contract freezes when the backend build phase verifies; the SPA and command build against it.

## Backward compatibility

- No production app in the field is affected; nothing deploys (capture is workspace-only, per
  root CLAUDE.md).
- `/compare` compatibility inside the tool: D4 removes version pruning globally — `/compare`'s
  "latest" reads already select newest-first, so retained history is invisible to it except as
  more rows/PNGs (risk tracked as X1 in 09). All other `/compare` behavior unchanged.
- Migration: none (no Prisma schema change). Existing Version/Comment rows remain valid.

## Blast radius (what else reads this data)

- `capture/db/index.mjs` `finalizeVariantVersion()` — shared by every capture path
  (`capture.mjs`, `capture-batch.mjs`); the D4 edit must preserve the cross-platform shot
  re-parenting `/compare` relies on. (X1) **Superseded by copy-forward (audit pass 3
  2026-09-04, CR2):** the re-parent MOVE would strip retained versions of their non-captured
  platform's shot, so DB-1 now duplicates the row onto the new version instead (same PNG),
  and DB-1b time-bounds `versionShots()`'s fallback (db/index.mjs:151-156) to the version's
  capturedAt. `/compare`'s reads (`getVariantLatest` server.mjs:839, `versionShots`) verified
  compatible against the code.
- `fixtures/compare/**/*.json` — written by the Data tab (D8); also read by `/compare`, the
  batch runner, and hand-edited in git. Concurrent hand-edit + UI-save is last-write-wins;
  the write is a formatted whole-file rewrite. (X2)
- `capture/mcp/comments.mjs` — the `makeready-capture` MCP server gains `resolve_scope`;
  existing tools and their payload shapes are unchanged (additive only).
- Disk: `fixtures/compare/_shots/<id>/<viewport>/<platform>/<versionId>.png` grows without
  bound under D4 (~100–500KB per capture; retention tooling explicitly out of scope).
