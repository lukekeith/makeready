# Analytics Architecture — the flat computed layer

## Shape

One wide, flat **materialized view** — `analytics_events` — is the single read source for every analytics query in the product. One row = one engagement event, with every dimension denormalized onto the row so any metric is `SELECT agg(...) FROM analytics_events WHERE <dimension filters> GROUP BY <dimensions>`. No joins at query time, ever.

```
transactional tables ─┐
  member_*_progress   │
  study_notes         ├─(UNION ALL view definition)──▶ analytics_events (matview)
  enrollments         │                                      │
  membership_events   │                                      ├──▶ /api/analytics/query (generic)
client_events ────────┘   ◀── POST /api/analytics/events     ├──▶ /api/programs/:id/analytics (assembled)
  (append-only, instrumented — event-ingestion.md)           └──▶ (Phase D) /api/engagement/* re-pointed here
```

The layer is **hybrid**: derived arms for everything the OLTP schema already records (completions, notes, enrollments — never double-instrument those), plus the append-only `client_events` arm for engagement with no OLTP side effect (opens, starts, future interactions). Each event type lives in exactly one arm. The ingestion path, client trackers, and the extensibility recipe ("register type → emit → done") are specced in event-ingestion.md.

Why a materialized view (vs. a dual-written fact table): the write paths for progress live in several service functions and must never gain an analytics failure mode; the matview keeps the transactional tables authoritative, is rebuildable from scratch by definition (no backfill scripts), and at current data volumes refreshes in well under a second. If volume ever makes full refresh expensive, the *same schema* migrates to an incrementally-maintained table without consumers changing (the query layer only knows the relation name).

## `analytics_events` columns

| Column | Type | Notes |
|---|---|---|
| `event_id` | text, **unique** | Source-prefixed natural key, e.g. `ap:<memberActivityProgress.id>`, `vc:<memberVideoProgress.id>`, `vw:<memberVideoProgress.id>`, `lc:<memberLessonProgress.id>`, `nt:<studyNote.id>`, `en:<enrollment.id>`, `mj:<membershipEvent.id>`. Unique index required for `REFRESH … CONCURRENTLY`. |
| `event_type` | text | See metrics-catalog.md. `ACTIVITY_COMPLETED`, `VIDEO_COMPLETED`, `VIDEO_WATCH`, `LESSON_COMPLETED`, `NOTE_CREATED`, `ENROLLMENT_CREATED`, `MEMBER_JOINED` |
| `occurred_at` | timestamptz | The event instant (`completedAt`, `lastWatchedAt`, `createdAt` per source). **Stored raw; time bucketing happens at query time in the caller's timezone** (`date_trunc(... AT TIME ZONE $tz)`), same as `engagement.ts` today — never bake a timezone into the view. |
| `entity_id` | uuid | **Canonical actor** — `COALESCE(member_id, user_id)`. The one identifier per Activity-Schema practice; retention/funnel/per-entity metrics group on THIS, never on member_id/user_id directly |
| `member_id` | uuid null | Acting member |
| `user_id` | uuid null | Acting user (leader-side events) |
| `organization_id` | uuid null | Denormalized from the group |
| `group_id` | uuid null | |
| `enrollment_id` | uuid null | |
| `study_program_id` | uuid null | Denormalized from the enrollment |
| `lesson_schedule_id` | uuid null | |
| `lesson_id` | uuid null | Source curriculum lesson |
| `day_number` | int null | Curriculum day — powers the lesson funnel with zero joins |
| `scheduled_activity_id` | uuid null | |
| `activity_type` | text null | `USER_INPUT` / `READ` / `VIDEO` / `YOUTUBE` / `EXEGESIS` |
| `scheduled_date` | date null | The lesson schedule's planned date — powers on-time/consistency metrics (member-evaluation.md) flat |
| `value` | numeric, default 1 | Count events: 1. `VIDEO_WATCH`: cumulative `watchedSeconds`. `NOTE_CREATED`: `LENGTH(content)` (COUNT = notes, SUM = chars written). |
| `percent` | numeric null | `VIDEO_WATCH`: `watchPercentage`. Room for future ratio-type measures. |
| `is_current_version` | boolean | Progress row's schedule version is the schedule's current version |
| `is_removed` | boolean | Schedule is soft-removed (`removedAt` set — e.g. after a study swap) |

Every dimension is a plain column → every filter is a plain `WHERE`. Adding a dimension later (e.g. `template_id`, `lesson_version`) = add a column to the view definition + reindex; existing metrics/queries are untouched.

### Source mapping (view definition, `UNION ALL`)

| Source rows | event_type | occurred_at | value / percent |
|---|---|---|---|
| `member_activity_progress` where `completedAt IS NOT NULL` (excluding rows whose scheduled activity is VIDEO — video completion lives in the video table) | `ACTIVITY_COMPLETED` | `completedAt` | 1 |
| `member_video_progress` where `completedAt IS NOT NULL` | `VIDEO_COMPLETED` | `completedAt` | 1 |
| `member_video_progress` (all rows with `watchedSeconds > 0`) | `VIDEO_WATCH` | `lastWatchedAt` | `watchedSeconds` / `watchPercentage` |
| `member_lesson_progress` where `completedAt IS NOT NULL` | `LESSON_COMPLETED` | `completedAt` | 1 |
| `study_notes` joined via `note_links` (`refType='ENROLLMENT'`) | `NOTE_CREATED` | `createdAt` | 1 |
| `enrollments` | `ENROLLMENT_CREATED` | `createdAt` | 1 |
| `membership_events` where action in (`ADDED`,`APPROVED`,`REJOINED`) | `MEMBER_JOINED` | `createdAt` | 1 |

Dimension denormalization happens inside the view definition (`progress → lesson_schedule → enrollment → group`). **Version/removal filtering is NOT baked into the view** — it is per-metric semantics, carried as the `is_current_version`/`is_removed` flags. Rationale: `enrollment-analytics.service.ts:81` filters to the current version because *completion stats* describe the current curriculum, but a time-series layer that dropped old-version or soft-removed rows would retroactively erase history from the recent-activity chart every time a program syncs or a study is swapped. Completion-style metrics filter `is_current_version AND NOT is_removed`; engagement-history metrics take everything.

**Metric classes — `flow` vs `snapshot`.** `VIDEO_WATCH` is a snapshot measure (one row per member×activity, value = *cumulative* seconds, `occurred_at` = last watch): `SUM(value)` = total watch time, `AVG(percent)` = average watch depth — **valid only unwindowed**. A time-windowed snapshot aggregate is silently wrong (it returns lifetime seconds of recently-active members), so the registry marks every metric `flow` or `snapshot` and the query endpoint **rejects `from`/`to` on snapshot metrics**. Do not fake a time series from snapshots.

**Committed follow-up — the watch-delta ledger.** Mixing cumulative snapshots into the event stream is the design's one textbook anti-pattern (Kimball mixed-grain; Activity Schema immutability — see best-practices-review.md). Resolution: a small append-only `video_watch_events` table (`entity_id`, dims, `occurred_at`, `delta_seconds`) written by `saveVideoProgress` alongside its existing upsert, projected into the view as immutable flow events. This unlocks watch-time trends (the one analytics class the snapshot rows can never serve) and shrinks the snapshot class to `avg_watch_percent`. Capture starts only when the table ships — build it early (Phase C), since un-captured history cannot be backfilled.

**Deletion semantics — the GDPR-erasure story (by design):** the view reflects current DB state, so cascade deletes (e.g. removing a Member deletes their progress rows) propagate into analytics on the next refresh — totals can dip. Append-only pipelines need surgical erasure tooling for exactly this; we get right-to-erasure for free. Never promise immutable history; if a surface ever needs delete-surviving aggregates, that's tombstones on the watch-delta ledger, not event sourcing.

**Started-but-not-completed is invisible** in v1: only completion/creation instants project into the view (`startedAt` exists on the progress tables but has no arm). If in-progress funnels are ever wanted, add an `ACTIVITY_STARTED` arm — one migration, no consumer changes.

### Indexes

- `UNIQUE (event_id)` — required by concurrent refresh.
- `(study_program_id, occurred_at)` · `(group_id, occurred_at)` · `(organization_id, occurred_at)` · `(enrollment_id, occurred_at)` · `(member_id, occurred_at)` — one composite per primary filter axis, time-ordered.
- `(event_type, occurred_at)`.

## Refresh strategy

No job infra exists, so refresh is self-contained in the server process:

1. `REFRESH MATERIALIZED VIEW CONCURRENTLY analytics_events` wrapped in `refreshAnalytics()` (`server/src/services/analytics.service.ts`), guarded by a Postgres advisory lock (`pg_try_advisory_lock`) — the in-process single-flight guard is not enough because image-promotion deploys briefly run old+new instances, and two concurrent CONCURRENT refreshes of one matview error out.
2. **Interval**: `setInterval` in `index.ts` startup, every 10 minutes (skip if the advisory lock is held).
3. **Staleness backstop**: the query endpoint checks last-refresh age; if > 15 min (e.g. after a deploy/restart), it triggers a refresh in the background *and still serves current data immediately* — analytics may be minutes stale, never wrong.
4. **Freshness + telemetry**: a one-row `analytics_refresh_state` table (`last_refreshed_at`, `last_duration_ms`, `last_error`, `consecutive_failures`) updated by `refreshAnalytics()`; every query response includes `freshAsOf`. **Alerting**: log an error (server error channel) when staleness exceeds 3× the interval or duration exceeds 50% of the interval — the in-process timer's failure mode is silent, so staleness must be actively watched, not assumed.
5. **Post-refresh quality checks** (dbt-style tests in plain SQL, run after each refresh, failures logged loudly): per-source row-count reconciliation (view arm count = source count under the same predicates), zero NULL `event_id`/`entity_id`/`occurred_at`, `event_type` within the registry's accepted values.
6. Manual: `POST /api/analytics/refresh` (super-admin / API key) for ops.

Operational notes: the `event_id` expression must be provably non-NULL (NULLs defeat CONCURRENTLY's duplicate detection and bloat its diff); the advisory lock must be session- or transaction-scoped (`pg_try_advisory_xact_lock`) so a crashed instance self-releases; CONCURRENTLY's DELETE/INSERT diff creates dead tuples — watch `n_dead_tup` on the matview under the 10-min cadence. **Migration triggers** (defined now so nobody debates them later): refresh duration > interval/2 or view beyond low tens of millions of rows → incremental table / recent-bucket upsert; ~50–100M rows → consider a columnar store. pg_ivm is ruled out (no UNION ALL support, not production-grade). pg_cron (Railway template) replaces the app timer if it proves flaky.

## Query layer — `/api/analytics/query`

One generic endpoint; metrics and dimensions are **registry entries, not routes**. Adding a metric = one registry line.

```jsonc
POST /api/analytics/query
{
  "metrics":    ["completions", "active_members"],          // registry names
  "dimensions": ["day"],                                    // 0..2 of: day|week|month|group_id|enrollment_id|member_id|activity_type|event_type|day_number|study_program_id
  "filters":    { "studyProgramId": "…", "from": "2026-07-01", "to": "2026-07-29" },
  "timezone":   "America/Chicago",
  "limit":      100, "orderBy": { "metric": "completions", "dir": "desc" }   // for leaderboards
}
→ { "success": true, "freshAsOf": "…", "rows": [ { "day": "2026-07-28", "completions": 14, "active_members": 6 } ] }
```

- **Metric registry** (`analytics-metrics.ts`): `{ name, label, description, format, type: 'simple' | 'ratio', sql | {numerator, denominator}, eventTypes: [...], class: 'flow' | 'snapshot', versionSemantics: 'all' | 'current-only' }` — e.g. `completions = COUNT(*) over ACTIVITY_COMPLETED+VIDEO_COMPLETED`, `active_members = COUNT(DISTINCT entity_id)`, `watch_seconds = SUM(value) over VIDEO_WATCH (snapshot)`. **Ratio metrics** (e.g. completion rate) are first-class and computed server-side with divide-by-zero handling — clients never divide two metrics themselves (that's how definitions drift). Whitelist only — the client can never inject SQL; zod validates every name against the registry. Snapshot metrics reject time windows (see above). `GET /api/analytics/meta` serializes the registry (names, labels, formats, applicable dimensions, classes) — the machine-readable metric catalog, doubling as docs.
- **Dimension registry**: name → column, or time expression (`date_trunc('day', occurred_at AT TIME ZONE $tz)`); time dimensions are zero-filled server-side via `generate_series` (the `engagement.ts:222` pattern) so charts never interpolate gaps. High-cardinality groupings (`member_id`, `enrollment_id`, `scheduled_activity_id`) require an explicit `limit` (max 500) and an `orderBy`; capped results carry `truncated: true` (and optionally an "(other)" rollup row) so a top-N never silently under-reports totals.
- **Time ranges**: `from`/`to` absolute, or server-resolved relative ranges (`"last_7d" | "last_30d" | "last_12mo"`) computed in the query timezone — clients never do date math. `compareToPrevious: true` returns the immediately-preceding period's series alongside, for "vs last month" UI.
- **Response**: `{ freshAsOf, resolvedQuery: { metrics, range, timezone, appliedScope }, rows, truncated? }` — echoing what actually ran (Cube/GoodData convention) makes client debugging and audit trivial.
- **Authorization — scope injection, not validation** (Cube `queryRewrite` / Looker `access_filter` pattern): the server derives the caller's entitled org/group set (`canManageOrgContent` family, NOT creatorId-only — do not replicate the `resolveLeaderGroupIds` gap) and **appends it to every query unconditionally**; client-supplied filters can only narrow within that injected scope, never widen it. Correctness no longer depends on the client sending the right filter, and cross-filter holes (an entitled groupId + a foreign memberId) are closed by construction. Requests whose filters fall wholly outside the entitled scope → 404-style denial. Optional later hardening: Postgres RLS beneath the view (pooled-connection `SET LOCAL` caveats — see best-practices-review.md).
- Convenience wrapper `GET /api/programs/:id/analytics` assembles the Program tab payload (several registry queries in one round trip) — see program-analytics-tab.md. Wrappers MAY join entity tables for **presentation metadata** (member names/avatars, group names, lesson counts) — that is display enrichment of already-computed metrics, not sourcing analytics from transactional tables; the flat-layer rule applies to metric computation only.

## Migration workflow

Matviews aren't modeled by the YAML→Atlas→Prisma toolchain. Ship the **matview + its indexes** as a hand-written SQL migration in `server/atlas/migrations/`, then `atlas migrate hash` to update `atlas.sum`. `analytics_refresh_state` is a plain table — model it normally in `schema/schema.yaml` via the standard `/schema` flow, so only the view DDL lives outside the toolchain. Prisma never touches the view; all reads go through `$queryRaw` in the analytics service. Document the view definition in the migration file itself — it IS the schema of record for the layer.

## Expansion model (how this stays "any metric, any filter")

- **New metric** → one registry entry (aggregate over existing columns). No migration.
- **New filter/dimension** → if the column exists, one dimension-registry entry. No migration.
- **New event source** → add a `UNION ALL` arm to the view definition (one migration), stamp the shared dimension columns, register any new metric. Consumers unchanged.
- **Scale-out path** → same schema as an incrementally-maintained table (triggers or dual-write) and/or a `analytics_daily` rollup matview (`date × event_type × org × group × program × enrollment × activity_type` + `count`/`sum_value`) for year-scale queries; the query layer swaps relation names, clients never know.

## Consumers & migration path

| Consumer | Today | Target |
|---|---|---|
| Program Analytics tab (new) | — | Phase B/C, reads the new layer exclusively |
| iPhone Home dashboard + web LeaderApp dashboard | `/api/engagement/*` ad-hoc UNION | Phase D: re-point engagement routes at `analytics_events` (identical response shapes — the routes stay, only their SQL source changes) |
| `EnrollmentSchedulePage` card fill | `/api/enrollments/:id/completion-stats` | Phase D optional: same query expressible against the layer (`completions` × `distinct member` grouped by `scheduled_activity_id`) |
| Legacy admin dashboard | `/api/activity-logs/stats*` (audit noise; heatmap silently broken) | Out of scope; superseded by LeaderApp |
