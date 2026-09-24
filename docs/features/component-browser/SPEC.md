# component-browser — spec

> Converted to the builder layout 2026-09-24 from the numbered `/build-spec` suite. **The numbered
> docs are still on disk and are still the detail** — this file is the index the `/builder:*` pipeline
> reads, not a rewrite. See `plugins/builder/skills/resume/REFERENCE.md` §Condense, *Legacy layouts*.

## Overview

A four-column component browser at `/components` in the capture SPA: a filesystem tree of
`iphone/MakeReady/Components/` → variant list → pan/zoom render with full version history →
Comments/Data side panel. A **UI 1.0 ⇄ 2.0 switch** at the top of the tree column swaps the source:
1.0 = built Swift components, 2.0 = the specced components of `docs/ui2/` rendered from their frozen
Figma snapshots (phase 5). Comments feed a scoped `/component-resolve <scope>` command that edits the
Swift components, resolves the comments and recaptures. Built entirely on the existing `/compare`
substrate (fixtures, adapters, ViewRegistry, Postgres, runners) plus a filesystem index.

Full overview: [README.md](README.md) and [01-architecture.md](01-architecture.md).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server  | ⬜ | The production Express server is untouched — this feature lives entirely in the capture dev tool, which has its own Express (`capture/server.mjs`) | §Server |
| client  | ⬜ | No web-app change — the browser shows iPhone renders only; the `/compare` web-twin iframe flow is not part of this feature | §Client |
| iphone  | ⬜ | No app or test-harness code change. `iphone/MakeReady/Components/` is READ as the tree/scope source and `ViewRegistry.swift` is PARSED for wiring status — both read-only | §iPhone |
| capture | ✅ | Backend: fs index, ~6 new `/api/components/*` routes, fixture write route, version-pruning removal, MCP `resolve_scope` tool. Frontend: the `/components` route and its four-column UI. No Prisma schema change | §Capture |

Also in scope, outside the four apps: **one new command file**,
`.claude/commands/component-resolve.md` ([07-capture.md](07-capture.md) §6).

Detail: [02-app-impact.md](02-app-impact.md).

**Backward compatibility:** not applicable — nothing ships to a device or to production.

## Decisions

The decisions table is [01-architecture.md](01-architecture.md) §Decisions; rows settled during the
build are in [09-gaps-and-decisions.md](09-gaps-and-decisions.md). **No OPEN rows** at conversion.

<!-- The one place rulings live. Record the DECISION, not the conversation: a stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation. NEVER quote the user's prompt as the ruling — operationalize
     it into a closed list, a measured value, or an enumerated set of deviations.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

## Contract

The capture tool's own `/api/components/*` routes, produced and consumed **inside capture**. The
production contract is unchanged. Table: [03-data-and-api.md](03-data-and-api.md).

## Schema & API changes

No schema change (established 2026-09-04) — the production Postgres is untouched and the capture
Postgres is behavioural-only for this feature. [03-data-and-api.md](03-data-and-api.md).

## Server

Not affected — see §Apps. [04-server.md](04-server.md).

## Client

Not affected — see §Apps. [05-client.md](05-client.md).

## iPhone

Not affected (read-only source) — see §Apps. [06-iphone.md](06-iphone.md).

## Capture

See [07-capture.md](07-capture.md) for the backend routes, the fs index, the four-column UI and the
`/component-resolve` command.

## Testing

See [08-testing.md](08-testing.md).

## Findings & risks

The ledger is [09-gaps-and-decisions.md](09-gaps-and-decisions.md).

## Walk status (why `walk: none`)

All five phase docs carry `## VERIFIED ✅` and the README records `verify READY (2026-09-04 — built,
all gates green; **awaiting human sign-off**)`. Under the old pipeline that verdict came *before* the
walk; under this one the walk comes first and the deep pass after, so a pre-walk verdict is not one of
this pipeline's (`plugins/builder/skills/resume/REFERENCE.md` §Condense). The manifest therefore reads
`walk: none` and `verify: none`, and the next step is the human's walk.

## Plan

The plan is this folder's existing phase docs, left in place by the conversion:
[10-phase-1-capture-backend.md](10-phase-1-capture-backend.md) ·
[11-phase-2-capture-browser-shell.md](11-phase-2-capture-browser-shell.md) ·
[12-phase-3-capture-browser-detail.md](12-phase-3-capture-browser-detail.md) ·
[13-phase-4-command-and-e2e.md](13-phase-4-command-and-e2e.md) ·
[14-phase-5-ui2-era.md](14-phase-5-ui2-era.md) — all five carrying `## VERIFIED ✅`.
