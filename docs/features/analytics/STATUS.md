# Analytics — Implementation Status

**The pick-up-here document.** A fresh session resuming this feature should read
[README.md](README.md) (phases + locked decisions), then this file (what's
actually built, verified, and decided along the way), then the doc for the
phase being worked ([architecture.md](architecture.md) /
[event-ingestion.md](event-ingestion.md) for A,
[program-analytics-tab.md](program-analytics-tab.md) for B/C).

| Phase | Status | Updated |
|---|---|---|
| **A — Analytics layer + ingestion** | ✅ **Built & verified locally** (2026-07-30) | 2026-07-30 |
| **B — Program tab part 1 + web instrumentation** | ✅ **Built** (2026-07-30) — server+web verified end-to-end, iPhone compiles; visual QA of the tab in the simulator still pending | 2026-07-30 |
| C — Program tab part 2 + watch-delta ledger + iPhone scaffold | ⬜ Not started | |
| D — Rollups, member profile, engagement-route migration | ⬜ Not started | |

---

## Phase A — done (2026-07-30, local only, uncommitted at time of writing)

### Deliverables → where they live

| Deliverable | Location |
|---|---|
| `client_events` + `analytics_refresh_state` tables | `schema/schema.yaml` → migration `server/atlas/migrations/20260730033138.sql` (normal `/schema` flow) |
| `analytics_events` materialized view + indexes | `server/atlas/migrations/20260730040000.sql` — **hand-written; this file IS the schema of record for the view** (8 arms: `ap: vc: vw: lc: nt: en: mj: ce:`) |
| Metric/dimension registry | `server/src/services/analytics-metrics.ts` — 14 metrics (class flow/snapshot + versionSemantics), 14 dimensions, event-type catalog. `LESSON_OPENED` / `ACTIVITY_STARTED` already registered for Phase B |
| Refresh service + telemetry + quality checks | `server/src/services/analytics.service.ts` — advisory-locked `REFRESH … CONCURRENTLY`, `analytics_refresh_state` singleton telemetry, staleness backstop (15 min) + alerts (30 min / slow-refresh), dbt-style post-refresh checks (per-arm row-count reconciliation, NULL-key guard, accepted event types) |
| Query engine (scope injection, zero-fill, snapshot guard) | same file — dedicated pg pool, 5s `statement_timeout`, lazy tz param |
| Routes: `POST /query`, `GET /meta`, `POST /events`, `POST /refresh` | `server/src/routes/analytics.ts` (rate-limited; OpenAPI blocks included) |
| Wiring + 10-min refresh job | `server/src/index.ts` (`/api/analytics` mount + `startAnalyticsRefreshJob()`) |

### Verified (against the 2026-07-29 prod-synced local DB)

- View totals reconcile with source arms exactly (17 `ACTIVITY_COMPLETED` + 5 `NOTE_CREATED` = 22 `engagement_events`, 4 `active_members`, `completion_rate` 0.375); `member_video_progress` is genuinely empty in prod, so zero video events is correct.
- Zero-filled day series cross-checked against direct SQL (America/Chicago bucketing); absolute ranges + `compareToPrevious` return the correct windows.
- Guardrails: snapshot metrics 400 on time windows; high-cardinality dims 400 without `limit`+`orderBy`; unregistered ingest event types 400 with a "register it first" message; member sessions rejected from `/query` (401).
- Ingestion: enrichment fills org/group/program/`dayNumber`/`activityType`/`scheduledDate` from the narrow ids; 2020 timestamp clamped to `received − 48h`; retried batch deduped (`accepted: 0`); `ce:` rows appear in the view after refresh.
- Server test suite: identical 99 pre-existing environmental failures with and without these changes (no test DB on :5433, prod integration offline) — **do not chase those**.
- `npm run schema:diff` stays clean (Atlas community ignores the matview — no DROP generated).

### Decisions & deviations made during the build (agreed rationale, don't re-litigate)

1. **`client_events` has NO foreign keys.** The database lives in two type universes: the live prod/dev DB has all-**text** ids (Prisma-era origin) while the atlas migration ledger + CI fresh-DB replay world is **uuid**. An FK to `members`/`users` cannot satisfy both (fails 42804 in one world — and prod runs `atlas migrate apply` on boot, so a bad migration = crash-looping deploy). GDPR-erasure semantics are preserved instead by the `ce:` view arm's `members`/`users` **existence joins** — deleting a member removes their instrumented events from analytics on the next refresh.
2. **All view SQL is dual-universe-safe**: every projected id column is cast `::text`; the only cross-table text↔uuid comparisons (`note_links.refId`, the `ce:` erasure joins) compare on the `::text` side. Any future arm/migration must follow the same rule.
3. **`en:` arm excludes enrollments with NULL `createdById`** — the layer's quality checks require provably non-NULL `entity_id`. The reconciliation check uses the same predicate, so counts stay consistent.
4. **`completion_rate` is classified `snapshot`** so time windows are rejected: its denominator (Σ per enrollment of active members × active schedules) measures the *current* curriculum, and a windowed numerator over an unwindowed denominator would be silently wrong. Its denominator reads transactional tables — allowed as a measure of expectation, not a re-derivation of event metrics. It also rejects dimensions and member/schedule-level filters.
5. **`nt:` event grain is the note↔enrollment LINK** (`nt:<note_links.id>`, not the note id) so a note linked to two enrollments can't collide on the unique `event_id`.
6. **Catalog footnote ¹ resolved:** YOUTUBE completions write `member_activity_progress` (only VIDEO type completes via `member_video_progress` — see `isActivityComplete` in `member-progress.service.ts`). The `ap:` arm therefore excludes only VIDEO-type scheduled activities.
7. **node-pg quirk:** a supplied-but-unreferenced query parameter fails with Postgres 42P18; the query builder allocates the timezone parameter lazily on first use. Keep it that way when adding metric aggregates.
8. **Grouped queries clamp the scan** to the union of the requested metrics' event types, so leaderboards/mix charts don't grow `{dim: null, metric: 0}` junk rows.

### Quick smoke test (after `docker restart makeready-server` — required to pick up server edits)

```bash
cd server && source .env
UA='User-Agent: MakeReadyDev/1.0'; AUTH="Authorization: Bearer $MAKEREADY_API_KEY"
curl -s -H "$UA" -H "$AUTH" http://localhost:3010/api/analytics/meta | head -c 300
curl -s -H "$UA" -H "$AUTH" -H 'Content-Type: application/json' \
  -X POST http://localhost:3010/api/analytics/query \
  -d '{"metrics":["engagement_events","active_members"],"dimensions":["day"],"filters":{"range":"last_30d"},"timezone":"America/Chicago"}'
```

---

## Phase B — done (2026-07-30, local only, uncommitted at time of writing)

### Deliverables → where they live

| Deliverable | Location |
|---|---|
| **B1** Wrapper `GET /api/programs/:id/analytics` | `server/src/routes/program-analytics.ts` (mounted in index.ts) + `programEngagementHeatmap()` and exported `todayInTimezone()` in `analytics.service.ts` |
| **Web tracker** | `client/resources/js/analytics.ts` — in-memory queue, flush at 10s / ≥20 / `visibilitychange`+`pagehide` (sendBeacon, keepalive-fetch fallback), idempotent retry with same UUIDs, 24h drop, 4xx batches dropped (retrying a client bug can't succeed) |
| Laravel proxy for the tracker | `POST /member/analytics/events` → `AnalyticsController@ingestEvents` → server `/api/analytics/events`. **CSRF-exempt via `withoutMiddleware` ON THE ROUTE** (routes/web.php) — NOT bootstrap/app.php, because the dev container bind-mounts `routes/` but not `bootstrap/` |
| Lesson island emits | `lesson-island.vue`: `LESSON_OPENED` on mount, `ACTIVITY_STARTED` via a single `watch(state.currentStep)` (deduped per activity id); previews (`isPreview` / `pvw-` groups) skipped |
| **B2** iPhone models | `iphone/MakeReady/State/Models/AnalyticsModels.swift` — HeatmapBucket/DayActivityCount MOVED here from MemberHomePage.swift + ProgramAnalytics* contract types (Phase-C fields modeled now, arrive empty). **Registered by hand in project.pbxproj** (STMM…009 ids — no synchronized groups in this project) |
| iPhone action + cache | `ProgramActions.getProgramAnalytics(programId:)` (in ProgramActions.swift) → `AppState.programAnalyticsById` (memory-first, no disk persistence) |
| iPhone tab UI | `ProgramHomePage.swift` — analyticsContent with KPI grid, Recent Activity (TabSlider Week/Month/Year + LineChart, no refetch on toggle), heatmap (bucket.day→week / bucket.hour→day transposition), loading skeletons, whole-tab empty state, error state, "As of …" freshness footer; `refreshCurrentTab` case 2 wired |

### Verified

- Wrapper against prod-synced data: exactly 7/30/12 series points (year = first-of-month 11 months back, avoiding the 13-bucket straddle of a naive 365-day window), KPIs match Phase-A queries (completionRate 0.375), heatmap matches at days=60, unknown program → 404.
- Full web path: browser `connect.sid` → Laravel proxy → server ingest returned `accepted: 1`; unauthenticated POST → 302 login (not 419, so the sendBeacon path works).
- Client bundle builds; iPhone `xcodebuild` **BUILD SUCCEEDED** (SwiftLint forbids NSLog in new code — use `Log.*` os.Logger wrappers).
- **Visual QA done via /compare (2026-07-30):** the tab is registered in the capture system as the `analytics` variant of the `program-home` comparison — preview at `http://localhost:5950/compare/program-home` (variant: analytics) without building in Xcode. The iPhone shot is a **full-page capture** (KPI grid, Week/Month/Year line, complete 7×24 heatmap, "Last 30 days" caption, "As of …" footer) rendering intentionally with sparse fixture data. Plumbing added for it: `ProgramHomePage(initialTab:)`, `CaptureState.selectedTab`/`analytics` (fixture JSON reuses the production `ProgramAnalytics` Codable — exactly the wrapper response shape), `AppState.programAnalyticsById` seeding in CaptureEnvironment, and a new capture-system capability: **`captureHeight` on a variant's `shared`** renders the iPhone page on a taller fixed canvas (`.fixed(width:height:)` + synthetic status-bar safe-area inset in CaptureRunner) — the iPhone analogue of the web runner's default fullPage screenshot, available to any scrolling page fixture. The `enrollments` variant remains client-only (pre-existing: `CaptureEnrollment` can't seed the tab's group/date data).

### Phase-B decisions

1. **KPI grid uses `Kpi` `.standard`, not the spec's `.compact`** — compact is a one-line HStack that drops the `description` field the spec itself requires ("of {total} total").
1a. **Top Groups table (owner-requested 2026-07-30, spec § 4b):** wrapper now returns `topGroups` (every enrolled group, top 10 ranked by completion %; pct = lesson completions ÷ Σ(active members × active schedules) per group — the completion_rate formula group-scoped; verified against prod data: single group ties out at 0.375 = the program rate). iPhone renders it as a divider-row table card below the heatmap (`analyticsTopGroupsSection`); model `ProgramTopGroup` in AnalyticsModels.swift; analytics fixture variant carries 3 rows, captureHeight 2110.
1c. **Per-section empty logic (owner rule 2026-07-30, spec § Empty/loading updated):** sections with zero data are HIDDEN, not shown as empty shells — Top Groups (no group with a completion), Recent Activity (all three series flat), heatmap (no non-zero bucket); enrollments-but-zero-activity collapses to the whole-tab empty state. Verified via the new `analytics-sparse` fixture variant (client+iphone captured), which also surfaced and fixed a real sparse-data bug: the heatmap's data-driven domain dropped empty day columns, so the client now zero-fills the full 7×24 grid before charting.
1b. **Owner design pass (2026-07-30, spec updated in program-analytics-tab.md):** Recent Activity is a **`VerticalBarChart`, not the originally-specced LineChart** (discrete counts must read exactly); `VerticalBarChart` gained an additive `xAxisValues` param to thin marks on the 30-bar month view (bar labels must stay unique — Swift Charts merges same-label categories). KPI grid is explicit rows of **116pt `Kpi(expand: true)` cells** (new additive Kpi param that stretches the card background to the proposed frame) — LazyVGrid let cards hug content, producing ragged cells.
2. `avgWatchPercent` is normalized to 0–1 **in the wrapper** (DB stores watchPercentage 0–100; contract mock shows 0.83). Client multiplies by 100 for `.percent` display.
3. The tracker posts through the Laravel member proxy (browser holds no server session cookie by itself); actor identity still comes from the server session server-side.
4. iPhone project has NO file-system-synchronized groups — every new Swift file needs 4 hand-added pbxproj entries (BuildFile, FileReference, group child, Sources phase).

## Phase C — next up (not started)

Per README + [program-analytics-tab.md](program-analytics-tab.md) build order:

1. **C1 (server)**: registry queries for funnel / content mix / top members / top enrollments (+ presentation joins for names/avatars) filling the wrapper's empty arrays; video KPIs already flow.
2. **Watch-delta ledger** (`video_watch_events` + `saveVideoProgress` tap + `VIDEO_WATCH_PROGRESSED` view arm) — build EARLY, un-captured history cannot be backfilled (architecture.md § Committed follow-up).
3. **C2 (iPhone)**: video KPI row (hide when no video activities), lesson funnel (VerticalBarChart), content mix (DonutChart, hide < 2 types), top members (top 5 → 10), top enrollments. iPhone models/decoding for all of these ALREADY EXIST (AnalyticsModels.swift) — the wrapper just needs to start returning data.
4. **iPhone tracker scaffold** (AnalyticsActions + buffered service, zero events).

## Phase D — see README phase table
