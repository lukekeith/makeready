# Best-Practices Review — how the architecture stacks up

2026-07-29. Three parallel research passes (data modeling · metric/semantic layers · storage/pipelines) evaluated architecture.md against published industry practice. Verdict up front: **the design is a recognized, well-matched pattern for our scale** — a miniature Cube on top of an Activity-Schema-style union fact table — with two substantive deviations and a set of cheap robustness gaps, all adopted into the spec (marked ✅) or explicitly deferred (marked ⏳).

## What the design is, in industry terms

- The flat `analytics_events` relation is closest to the **Activity Schema** spec (Narrator) and Snowplow's `atomic.events`: a single time-series table, one row per event, heterogeneous event types, dimensions joined at query time. That school explicitly blesses deriving the stream from source tables by SQL transformation — our matview *is* that pattern.
- Denormalizing **keys but not attributes** makes it a "union fact table with virtual dimensions", not a true One-Big-Table — which sidesteps OBT's two documented failure modes (dimension drift, update anomalies) because names are joined live and the view recomputes from OLTP truth. Current consensus (Fivetran, dataarchitect.studio) endorses wide flat tables for small teams; our justification is simplicity, not columnar speed — correct at low volume.
- The `flow`/`snapshot` metric classes independently reinvent **Kimball's additive vs semi-additive measure rule**, enforced structurally (time windows rejected) rather than by analyst discipline — stronger than the convention-based norm.
- The query API shape (`{metrics, dimensions, filters, timezone, limit, orderBy}` + whitelist registry + server-side zero-fill) is essentially **Cube's REST query format**, the most-copied shape in the industry; zero-fill = MetricFlow's `join_to_timespine`.
- Matview-over-OLTP in one Postgres is the documented **starting rung** of the scale ladder (Crunchy Data, Xata); CONCURRENTLY + unique natural key + advisory lock + consumer-visible `freshAsOf` is the textbook stack, and surfacing freshness to API consumers is *ahead* of typical practice (stale-while-revalidate, RFC 5861 applied to a view).
- Storing raw `timestamptz` and bucketing at query time with named zones is exactly the endorsed timezone practice.

## The two substantive deviations

### 1. Mixed grain: cumulative snapshots inside the event stream ✅ addressed
The `VIDEO_WATCH` rows (cumulative watch-seconds, mutable, `occurred_at` = last watch) are the one element both schools would name an anti-pattern: under Kimball, periodic-snapshot-grain semi-additive facts sharing a `value` column with additive transaction facts ("custom application required" hazard); under Activity Schema, a violation of "an activity should never change". Our metric-class guard is a real mitigation but is convention, not structure.
**Adopted**: keep the snapshot rows for lifetime totals now, and commit to the orthodox fix — an **append-only watch-delta ledger** (`video_watch_progressed` events, `value` = seconds since last write, fed by `saveVideoProgress`) — promoted from a vague Phase-D idea to the named resolution. It also unlocks the only analytics class the design provably cannot serve (watch-time trends), and it only gets more expensive to retrofit as un-captured history accrues.

### 2. Tenancy by validation, not injection ✅ addressed
"Reject unscoped queries" makes authorization depend on the client sending the right filter, and cross-filter consistency (an entitled `groupId` + a foreign `memberId`) is where leaks happen. Industry standard (Cube `queryRewrite`, Looker `access_filter`) is **scope injection**: the server derives the caller's entitled org/group set and appends it to every query unconditionally; client filters only narrow.
**Adopted** in the spec. Postgres RLS under the matview is noted as optional defense-in-depth (⏳ — pooled-connection `SET LOCAL` complexity; only after injection lands).

## Adopted robustness/extensibility improvements

| Area | Change | Source of the recommendation |
|---|---|---|
| Registry | **Ratio/derived metric type** (numerator/denominator, server-side, div-by-zero-safe) — completion rate becomes a registry metric, not wrapper math | MetricFlow's 5 metric types; drift prevention |
| Query API | **`compareDateRange` / previous-period** + server-resolved relative ranges ("last 30 days" in query tz) | Cube first-class feature; kills client-side date math bugs |
| Query API | **Truncation signaling** on capped group-bys (`truncated: true` + optional "(other)" rollup) | Amplitude's top-N pruning model |
| Query API | **Echo the resolved query** (ranges, tz, applied scope) beside `freshAsOf` | Cube/GoodData convention |
| Catalog | **`GET /api/analytics/meta`** serializing the registry (+ `label`, `description`, `format` fields) — machine-readable metric catalog, doubles as docs | Cube `/meta`, dbt Discovery API |
| Identity | **Canonical `entity_id`** column (member_id ∪ user_id with a documented coalesce rule) — prerequisite for retention/funnel/per-entity metrics | Activity Schema one-identifier rule; Segment identity guidance |
| Naming | Event names locked to **past-tense object_action** (`LESSON_COMPLETED` style already conforms — convention now stated, renames are breaking) | Segment/Amplitude/Mixpanel object-action framework |
| Refresh ops | **Telemetry**: `last_duration_ms`, `last_error`, `consecutive_failures` on the freshness row; alert at staleness > 3× interval or duration > 50% of interval — the in-process timer's silent-death mode was the biggest reliability hole | dbt data-SLA practice; matview ops guides |
| Refresh ops | **Post-refresh quality checks** in plain SQL (per-source row-count reconciliation, NULL-key guard, event_type accepted-values), failing loudly | dbt tests ported to plain SQL |
| Refresh ops | **NULL-proof the unique key** (NULLs defeat CONCURRENTLY's duplicate detection and bloat the diff); advisory lock must be session/xact-scoped so a crashed instance self-releases; watch matview dead-tuple growth under the 10-min cadence | pgsql-hackers, matview ops guides |
| Governance | **Golden-result metric tests** in CI against a seeded fixture DB | semantic-layer testing practice |
| Scale plan | **Named migration triggers**: refresh duration > interval/2 or low tens of millions of rows → incremental table / recent-bucket upsert (or Timescale continuous aggregates); ~50–100M rows → consider columnar. pg_cron (Railway template) when the app timer becomes annoying | Postgres-analytics scale ladder |
| Framing | The cascade-delete "history rewriting" caveat is the design's **GDPR-erasure story** — deletion propagates automatically, which append-only pipelines struggle with; the delta ledger gets tombstones if delete-surviving history is ever needed | Snowplow GDPR tutorials |

## Explicitly deferred (evaluated, not needed at our scale)

- **Star-schema dimension tables / SCD Type 2 effective dating** — presentation-time name joins are a deliberate Type-1 (current-values) choice; add `valid_from`/`valid_to` only if "as-was curriculum" questions arise. ⏳
- **Cumulative/window metric types (WAU), conversion/funnel metrics, `activity_occurrence` ordinals** — add when retention/funnel views are requested. ⏳
- **Cursor pagination on grouped results** — not industry practice; limit/offset + truncation flag suffices. Rejected.
- **HTTP response cache** (key = canonical query JSON + `freshAsOf` for free invalidation) — only if identical dashboard queries measurably hammer Postgres. ⏳
- **pg_ivm** — struck from consideration: no UNION ALL support, not production-hardened, unavailable on managed images. Rejected.
- **Event sourcing / full append pipeline, CDC, warehouse** — over-engineering at this scale per the same sources; the ladder is documented in architecture.md. ⏳
- **Medallion/dbt layering** — the literature itself calls multi-hop layering for a small dashboard an anti-pattern; we adopt the discipline (idempotent transform, contract, tests) without the layers. Rejected as layers, adopted as discipline.
- **`feature_json` catch-all column** — typed columns are better for a domain-specific model on Postgres; revisit only if per-source attributes start sprawling. ⏳

## Bottom line

Storage: conformant, ahead on freshness transparency; gaps were observability, now specced. Modeling: one textbook anti-pattern (snapshot grain), resolved via the delta ledger; one spec gap (entity identity), resolved via `entity_id`. Metric layer: idiomatic Cube-shaped design; the material additions are scope injection, ratio metrics, and period comparison. Nothing in the research suggested the flat computed-view foundation is wrong — every source pointed to it as the correct starting architecture for this scale, with named, cheap upgrade paths.
