# Analytics — Feature Spec

Spec for MakeReady's analytics layer and its first consumer, the **Program Home Analytics tab** (monday#12661762474). Written 2026-07-29 from the codebase deep dive recorded in `docs/monday/tickets/12661762474.md`.

## Documents

| Doc | Contents |
|---|---|
| [architecture.md](architecture.md) | The flat analytics layer: fact materialized view, refresh strategy, generic query endpoint, expansion model |
| [metrics-catalog.md](metrics-catalog.md) | Event types, dimensions, and the initial metric registry (incl. video watch time & completions) |
| [program-analytics-tab.md](program-analytics-tab.md) | The iPhone Program Home Analytics tab UI spec — sections, charts, data contracts, phasing |
| [best-practices-review.md](best-practices-review.md) | Industry research review (Kimball/Activity Schema/Cube/dbt/Postgres ops) — how the architecture stacks up, adopted fixes, deferred items |
| [member-evaluation.md](member-evaluation.md) | Multi-axis member engagement model — total activity, writing, lessons, watch time, consistency; layer additions it requires; presentation rules |
| [event-ingestion.md](event-ingestion.md) | Client instrumentation path — `client_events` table + batched ingest endpoint + web/iPhone trackers; how any future engagement latches onto the engine |

## Goals (owner direction, 2026-07-29)

1. **Flat structures.** Analytics are calculated and filtered against ONE wide, denormalized fact source — never re-derived at read time by joining the original transactional tables.
2. **Computed, not sourced live.** The analytics layer is a materialized/computed view over the transactional tables. Transactional tables stay authoritative; the analytics layer is derived and rebuildable at any time.
3. **Expandable.** New metrics, computations, and filters are added by registering them against the flat layer — no new query plumbing per metric. Filterable by member, group, org, timeframe, study program, lesson, activity (and any future dimension added as a column).
4. **First consumer**: the Program Analytics tab, unfiltered, program-scoped.

## Current state (what exists today — full inventory in the ticket dossier)

- **Real engagement signal** lives in `member_activity_progress`, `member_video_progress` (watch seconds / %, completes at ≥90%), `member_lesson_progress`, and study notes (`note_links.refType='ENROLLMENT'`). The `activities` ledger never writes COMPLETED/ENROLLED events; `activity_logs` is auth/audit noise.
- **Ad-hoc aggregation exists in two places** and queries the transactional tables directly each request — exactly the pattern this spec replaces:
  - `server/src/routes/engagement.ts` (`/api/engagement/heatmap`, `/weekly`) — 3-way UNION of the progress/notes tables, group-scoped, powers the Home dashboard heatmap + weekly bars on iPhone and the web LeaderApp dashboard.
  - `server/src/services/enrollment-analytics.service.ts` (`/api/enrollments/:id/completion-stats`) — per-enrollment per-lesson/activity distinct-member completion counts, powers `EnrollmentSchedulePage` card fill.
- **No scheduler/job infra** in the server; no materialized views anywhere yet. Migrations are hand-writable SQL under `server/atlas/migrations/` (the YAML schema toolchain doesn't model matviews — see architecture.md § Migration workflow).
- **iPhone chart library is complete and mostly idle**: `LineChart`, `DonutChart`, `HorizontalBarChart` have zero production uses; `HeatMapChart`/`VerticalBarChart`/`Kpi` are used only by `MainHome`.

## Delivery phases

| Phase | Scope | Depends on |
|---|---|---|
| **A — Analytics layer** | `analytics_events` materialized view + refresh + `/api/analytics/query` + `/meta` + freshness/telemetry; **plus the ingestion half**: `client_events` table, batched `POST /api/analytics/events`, `ce:` view arm, registration enforcement (event-ingestion.md) | — |
| **B — Program tab, part 1** | KPI row, Week/Month/Year activity line, 7×24 heatmap on the tab; **plus web instrumentation**: `analytics.ts` tracker + `LESSON_OPENED`/`ACTIVITY_STARTED` in the lesson player (members engage on WEB — this is where instrumentation lives) | A |
| **C — Program tab, part 2** | Lesson funnel, content mix donut, top members ("Most active"), top enrollments, video watch KPIs; watch-delta ledger; iPhone tracker scaffold (zero events) | A (B for layout) |
| **D — Later** | Daily rollup matview, member engagement profile (member-evaluation.md), web LeaderApp parity, migrate `/api/engagement/*` + dashboard onto the layer, dwell/funnel instrumentation through the ingestion pipe | A–C |

## Pre-implementation checklist (evaluated 2026-07-29)

1. **Data volume baseline — DONE.** Production (via local sync): ~60 total engagement events, 116 lesson schedules, 23 members, 8 enrollments. Consequences: refresh cost and query performance are non-issues for years (skip perf tuning beyond the specced indexes; golden-result correctness tests are where the effort goes), and **sparse-data presentation is the real launch risk** — every chart must be designed to look intentional with a handful of events (see program-analytics-tab.md § Empty/loading).
2. **Product review of member rankings — RESOLVED (owner, 2026-07-29).** Members are evaluated on **multiple axes**, ranked per axis, with no single composite score — see member-evaluation.md. The Program tab's "Top members" ranks by total activity ("Most active"); the fuller multi-axis profile is a later surface. Two of its axes add small Phase-A layer requirements (`scheduled_date` column, NOTE_CREATED value = char length); time-in-app is deferred pending instrumentation + privacy review.
3. **Mobile contract stability — policy set.** iPhone builds live for months (TestFlight/App Store lag): the query API, registry names, event types, and wrapper response keys are **additive-only** — never rename or remove; breaking shape changes require a new wrapper version, old one kept until fleet moves.
4. **Timezone decision — set.** Program charts bucket in the **caller's device timezone** (matches the Home dashboard precedent); passed per-request, never stored. Members spanning timezones see their own local bucketing — accepted.
5. **Offline/caching interplay — set.** iPhone caches the analytics payload memory-first (disk persistence optional, low value at this payload size); the "As of" caption renders the payload's `freshAsOf`, so offline/stale views are honestly labeled by construction.
6. **Query guardrails — set.** Rate-limit `/api/analytics/query` (per-session, generous) and run analytics SQL with a `statement_timeout` (e.g. 5s) so a pathological group-by can never degrade OLTP.

## Non-goals (this spec)

- Filters/controls on the Program tab beyond the Week/Month/Year time toggle (owner: "doesn't need to be filtered").
- Writing new event types into the `activities` ledger.
- Member-facing analytics, AI insights, dwell-time instrumentation (future roadmap epic 6).
- Fixing the legacy admin dashboard heatmap (`analytics.domain.ts` reads the wrong response key — separate ticket).
