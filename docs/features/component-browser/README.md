# component-browser — iPhone component browser in the capture app

**Status: spec complete** (2026-09-03 — integrity SOUND, audit CLEAN pass 2, decisions closed)

A four-column component browser at `/components` in the capture SPA: a filesystem tree of
`iphone/MakeReady/Components/` → variant list → pan/zoom render with full version history →
Comments/Data side panel. Comments feed a scoped `/component-resolve <scope>` Claude command
that edits the Swift components, resolves the comments, and recaptures. Built entirely on the
existing `/compare` substrate (fixtures, adapters, ViewRegistry, Postgres, runners) plus a
filesystem index.

## Pipeline status (snapshot)

| Step | Status |
|---|---|
| spec | ✅ |
| audit | ✅ CLEAN (pass 4, 2026-09-04) |
| decisions | ✅ (no open rows) |
| plan | ✅ (4 phase docs, 2026-09-04) |
| build | 🔄 2/4 |
| verify | ⬜ |
| sign-off | ⬜ |

## Phase status

| Phase | App | Doc | Status |
|---|---|---|---|
| 1 — Backend (fs index, retention, routes, MCP) | capture | [10-phase-1-capture-backend.md](10-phase-1-capture-backend.md) | ✅ VERIFIED 2026-09-04 |
| 2 — Browser shell (viewer extraction, tree, variants) | capture | [11-phase-2-capture-browser-shell.md](11-phase-2-capture-browser-shell.md) | ✅ VERIFIED 2026-09-04 |
| 3 — Browser detail (render, versions, comments, data) | capture | [12-phase-3-capture-browser-detail.md](12-phase-3-capture-browser-detail.md) | ⬜ |
| 4 — Command + E2E | capture (+ root .claude) | [13-phase-4-command-and-e2e.md](13-phase-4-command-and-e2e.md) | ⬜ |

## Doc index

| Doc | Contents |
|---|---|
| [01-architecture.md](01-architecture.md) | Overview, Decisions table, Requirement provenance, baseline patterns, out of scope |
| [02-app-impact.md](02-app-impact.md) | Per-app scope, contract ownership, sequencing, blast radius |
| [03-data-and-api.md](03-data-and-api.md) | DB behavior changes + the capture API/MCP contract |
| [04-server.md](04-server.md) | Not affected |
| [05-client.md](05-client.md) | Not affected |
| [06-iphone.md](06-iphone.md) | Not affected (read-only source of truth) |
| [07-capture.md](07-capture.md) | The build: backend, SPA, component manifest, MCP, command |
| [08-testing.md](08-testing.md) | Tests, gates, E2E walk, human-verification script, traceability |
| [09-gaps-and-decisions.md](09-gaps-and-decisions.md) | G/D/O/C/X ledger |

## Governing rules

- Suite obeys `.claude/skills/build-spec/REFERENCE.md` (§3 cross-app rules, §3c language
  standard). Contract = 03; freezes when the (single) build phase covering the backend verifies.
- The `/compare` system keeps working unchanged throughout — the browser is an additive view
  over the same substrate (01 §Decisions D3).

## Resume

Run `/build-spec component-browser` — reads the ledger and continues from the current step.
