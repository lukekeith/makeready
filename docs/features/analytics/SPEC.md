# analytics — spec

> Converted to the builder layout 2026-09-24 from the pre-numbered `/build-spec` suite (prose docs +
> `STATUS.md`). **Those docs are still on disk and are still the detail** — this file is the index the
> `/builder:*` pipeline reads, not a rewrite. See `plugins/builder/skills/resume/REFERENCE.md`
> §Condense, *Legacy layouts*.

## Overview

MakeReady's analytics layer and its first consumer, the **Program Home Analytics tab**
(monday#12661762474). Written 2026-07-29 from the codebase deep dive in
`docs/monday/tickets/12661762474.md`. A flat `analytics_events` materialized view over eight source
arms, a metric/dimension registry, a generic query endpoint with scope injection and zero-fill, an
ingestion route, and a 10-minute refresh job — then the iPhone tab and web instrumentation on top.

Full overview: [README.md](README.md). **Implementation status and the continuation notes are
[STATUS.md](STATUS.md)** — read it before resuming.

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server  | ✅ | `client_events` + `analytics_refresh_state` tables, the `analytics_events` matview and its indexes, the metric/dimension registry, the refresh + query services, and `POST /query` · `GET /meta` · `POST /events` · `POST /refresh` | §Server |
| client  | ✅ | Web instrumentation — the events the web app emits into `POST /events` (phase B) | §Client |
| iphone  | ✅ | The Program Home Analytics tab (phases B–C) and the member-profile surface (phase D) | §iPhone |
| capture | ⬜ | No `/compare` twin for the analytics tab today. A twin becomes owed if the tab is brought into `/compare`; until then nothing in `capture/` reads this feature | §Capture |

**Backward compatibility:** the ingestion contract is additive — an unregistered event type is
rejected with a "register it first" message rather than silently accepted, so a shipped iPhone build
emitting an old set keeps working.

**Blast radius:** the matview reads eight existing source arms; a schema change to any of them changes
what analytics reports.

## Decisions

[README.md](README.md) carries the locked decisions, including the 2026-07-29 owner ruling that members
are evaluated on **multiple axes, ranked per axis, with no single composite score**
([member-evaluation.md](member-evaluation.md)); the Program tab's "Top members" ranks by total activity
("Most active"), and the fuller multi-axis profile is a later surface. Time-in-app is **deferred**
pending instrumentation plus a privacy review. **No OPEN rows** at conversion.

<!-- The one place rulings live. Record the DECISION, not the conversation: a stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation. NEVER quote the user's prompt as the ruling — operationalize
     it into a closed list, a measured value, or an enumerated set of deviations.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

## Contract

| Contract | Producer | Consumers | Auth | Notes |
|---|---|---|---|---|
| `POST /api/analytics/query` | server | iphone, client | leader session (member sessions 401) | scope-injected; snapshot metrics 400 on time windows; high-cardinality dims 400 without `limit`+`orderBy` |
| `GET /api/analytics/meta` | server | iphone, client | leader session | the metric + dimension registry |
| `POST /api/analytics/events` | server | client, iphone | leader session | rate-limited; unregistered event types 400 |
| `POST /api/analytics/refresh` | server | server (the 10-min job) | internal | advisory-locked `REFRESH … CONCURRENTLY` |

Shapes and guardrails: [architecture.md](architecture.md) and
[program-analytics-tab.md](program-analytics-tab.md). Frozen 2026-07-30 when phase A verified; phases C
and D **extend** it, which re-opens it deliberately per `/builder:revise`.

## Schema & API changes

Landed in phase A (see [STATUS.md](STATUS.md) for the migration ids):

| # | Change | Object | Reason | Status |
|---|---|---|---|---|
| SC1 | ADD | `client_events`, `analytics_refresh_state` tables | ingestion + refresh telemetry | landed `20260730033138.sql` (normal `schema.yaml` flow) |
| SC2 | ADD | `analytics_events` materialized view + indexes | the flat fact layer, 8 arms | landed `20260730040000.sql` — 🔴 **hand-written; that file IS the schema of record for the view**, and `schema:diff` stays clean because Atlas community ignores the matview |

**Data plan:** additive only; no backfill of existing rows. The matview is derived and is rebuilt by
`REFRESH … CONCURRENTLY`.

## Server

See [architecture.md](architecture.md) (the layer, refresh strategy, query endpoint, expansion model),
[metrics-catalog.md](metrics-catalog.md) (event types, dimensions, the metric registry) and
[event-ingestion.md](event-ingestion.md).

## Client

Web instrumentation, phase B — see [event-ingestion.md](event-ingestion.md) and [STATUS.md](STATUS.md).

## iPhone

See [program-analytics-tab.md](program-analytics-tab.md) for the tab's sections, charts, data contracts
and phasing.

## Capture

Not affected — see §Apps.

## Testing

Per-phase verification is recorded in [STATUS.md](STATUS.md), including the reconciliation checks
against the prod-synced local DB. 🔴 **The server suite has 99 pre-existing environmental failures**
(no test DB on `:5433`, prod integration offline), identical with and without these changes — do not
chase them; judge the delta.

Review of the approach: [best-practices-review.md](best-practices-review.md).

## Out of scope

Time-in-app metrics, pending instrumentation and a privacy review.

## Findings & risks

- **build-time risk — phase B's iPhone tab has never been looked at in the simulator.** [STATUS.md](STATUS.md)
  records B as server+web verified end-to-end with the iPhone side compiling only. That visual check is
  part of the walk, not of a gate.
- **The matview migration is hand-written**, so a future `schema.yaml` change near those arms will not
  regenerate it — `20260730040000.sql` has to be edited deliberately.

## Plan

Phases are [README.md](README.md)'s phase table, tracked in [STATUS.md](STATUS.md):

- **A — analytics layer + ingestion** — ✅ built & verified locally (2026-07-30)
- **B — Program tab part 1 + web instrumentation** — ✅ built (2026-07-30); server+web verified
  end-to-end, iPhone compiles, **visual QA of the tab still pending**
- **C — Program tab part 2 + watch-delta ledger + iPhone scaffold** — ⬜ not started
- **D — Rollups, member profile, engagement-route migration** — ⬜ not started

🔴 **Phases C and D are not planned to this pipeline's shape** — they have no per-task `PLAN.md`. When
C starts, `/builder:resume --path docs/features/analytics` routes to `/builder:plan` to write one,
**one app per phase, server before its consumers**.
