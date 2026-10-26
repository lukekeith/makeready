# home-dashboard-data — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every section of the UI 2.0 iPhone Home dashboard shows real, non-zero data from the real API for the Fixtures identity after `npm run fixtures:reset`.

**Architecture:** The server adds one additive analytics metric (`scheduled_lessons`, a new `ls:` arm of the hand-written `analytics_events` matview) and four iPhone-only `GET /api/home/*` endpoints backed by `services/home-*.ts` (a per-request sessionizer over recorded activity, day minutes, engagement, following), scoped exactly as `/api/analytics/query` is; the fixtures layer seeds every section. The iPhone grows `DashboardSnapshot`, fetches the new data in `DashboardActions.refresh()` (non-fatal, cache-first), and `HomeDashboardMapper` maps every section; the contract freezes when the server phases close.

**Tech Stack:** server — Express, Prisma, PostgreSQL (Atlas migrations), zod, vitest · iphone — Swift/SwiftUI, `@Observable` + Actions, XCTest (`MakeReadyCaptureTests`).

**Spec:** `docs/features/home-dashboard-data/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(home-dashboard-data): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1 | `scheduled_lessons` is queryable through `/api/analytics/query`, from a new `ls:` matview arm | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run migrate:status` |
| 2 | server | 2–6 | `/api/home/{sessions,days,engagement,following}` answer per §Contract, scoped like analytics | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run migrate:status` |
| 3 | server | 7, 13, 15, 16, 17 | `fixtures:reset` makes every Home section non-zero; the contract freezes (re-closes after Task 13) | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run migrate:status` |
| 4 | iphone | 8–9 | `DashboardSnapshot` carries and caches every new section; `refresh()` fetches them, non-fatally | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 10–12, 14, 18 | `HomeDashboardMapper` fills Activity, day cards, Sessions (per range), Engagement and Following; Task 14 lands D18–D20 on the device build | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: `scheduled_lessons` metric + the `ls:` matview arm
App: server
Phase: 1
Recipe: server/.claude/CLAUDE.md §Database Management - Schema-First Approach (this task is the recorded exception: a HAND-WRITTEN matview migration, SPEC §Data plan — never `schema:diff` for it)
Build-time risk (F7): `analytics_events` is a hand-written materialized view, not YAML-modelled — there is no `CREATE OR REPLACE`, so the migration drops and recreates it and must recreate the unique `event_id` index (REFRESH … CONCURRENTLY needs it) plus the six secondary indexes. The new arm's `event_id` and `entity_id` must be provably non-NULL (`'ls:' || ls.id`, `ls."enrollmentId"`), and the arm needs its `ls` entry in the post-refresh quality check or every refresh logs a reconciliation failure.
Build-time risk (F8): bucketing `occurred_at AT TIME ZONE tz` shifts a UTC-midnight schedule a day early in every US timezone, and the fixtures (Chicago noon) hide it — `scheduled_lessons` must bucket and window by the stored date (`scheduled_date`), and the DB test's UTC-midnight case is the proof.

**Files:**
- Modify: `server/src/services/analytics-metrics.ts:21-29` (add `LESSON_SCHEDULED`), `:77-106` (add `dateBucket` to `MetricDef`), `:279-292` (register `scheduled_lessons` after `members_joined`)
- Modify: `server/src/services/analytics.service.ts:206-276` (add the `ls` quality-check arm), `:524` (insert the mixing check after it), `:681-684` (range filter), `:714` (bucket expression), plus one new line at the top of `executeQuery` (`:645`)
- Create: `server/atlas/migrations/20261025120000.sql`
- Modify: `server/atlas/migrations/atlas.sum` (regenerated by `atlas migrate hash`, never by hand)
- Test: `server/src/services/__tests__/analytics-metrics.test.ts` (unit, always runs)
- Test: `server/fixtures/__tests__/scheduled-lessons.db.test.ts` (DB-gated on `FIXTURES_TEST_DATABASE_URL` through `fixtures/__tests__/db-harness.ts` — the real-SQL proof; it lives under `fixtures/` because `server/tsconfig.json` has `rootDir: ./src`, so a `src/` test cannot import the harness)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `DERIVED_EVENT_TYPES` now includes `'LESSON_SCHEDULED'`.
  - `MetricDef.dateBucket?: 'local' | 'stored_date'` (absent = `'local'`).
  - Registry metric `scheduled_lessons` (`POST /api/analytics/query` with `{metrics:["scheduled_lessons"], dimensions:["day"], filters:{organizationId, from, to}, timezone}` → rows `{ day: 'YYYY-MM-DD', scheduled_lessons: number }`, zero-filled; a future `to` is accepted).
  - `runAnalyticsQuery` throws `AnalyticsQueryError(400, …)` when a query mixes a `stored_date` metric with `local` metrics.
  - The `analytics_events` view carries `ls:` rows: `event_type = 'LESSON_SCHEDULED'`, `entity_id = enrollment id`, `member_id = NULL`, `scheduled_date = ls."scheduledDate"::date`.

Which harness: the bucketing and the arm are SQL, so the real proof is the **DB-gated** fixtures harness (it seeds the fixture world, refreshes the matview and runs `runAnalyticsQuery` against a throwaway Postgres). The registry entry and the mixing rejection are pure and get an always-on **unit** test, which is this task's red/green when `FIXTURES_TEST_DATABASE_URL` is unset (the DB suite then prints `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` and is skipped, never silently).

- [ ] **Step 1: Write the failing unit test** — create `server/src/services/__tests__/analytics-metrics.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { DERIVED_EVENT_TYPES, METRICS_BY_NAME } from '../analytics-metrics.js'
import { AnalyticsQueryError, runAnalyticsQuery } from '../analytics.service.js'

describe('scheduled_lessons registry entry (home-dashboard-data D10, D14)', () => {
  it('is a derived event type', () => {
    expect(DERIVED_EVENT_TYPES).toContain('LESSON_SCHEDULED')
  })

  it('is registered as a current-only flow count bucketed by stored date', () => {
    const m = METRICS_BY_NAME.get('scheduled_lessons')
    expect(m).toMatchObject({
      name: 'scheduled_lessons',
      format: 'count',
      type: 'simple',
      class: 'flow',
      versionSemantics: 'current-only',
      eventTypes: ['LESSON_SCHEDULED'],
      agg: 'count',
      dimensionsAllowed: true,
      dateBucket: 'stored_date',
    })
  })

  it('leaves every existing metric on local (event-time) bucketing', () => {
    for (const [name, m] of METRICS_BY_NAME) {
      if (name !== 'scheduled_lessons') expect(m.dateBucket ?? 'local').toBe('local')
    }
  })

  it('refuses to mix stored-date and event-time metrics in one query (400, before any DB access)', async () => {
    const query = runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons', 'lesson_completions'],
        dimensions: ['day'],
        filters: { from: '2026-10-01', to: '2026-10-07' },
        timezone: 'UTC',
      },
      { all: true }
    )
    await expect(query).rejects.toBeInstanceOf(AnalyticsQueryError)
    await expect(query).rejects.toMatchObject({
      status: 400,
      message: 'Metric(s) scheduled_lessons bucket by stored date and cannot be combined with event-time metrics',
    })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/analytics-metrics.test.ts` → FAIL: `expected [ 'ACTIVITY_COMPLETED', … ] to include 'LESSON_SCHEDULED'`, `expected undefined to match object`, and the mixing case fails its message assertion (today it rejects with `Unknown metric 'scheduled_lessons'`).

- [ ] **Step 3: Write the failing DB test** — create `server/fixtures/__tests__/scheduled-lessons.db.test.ts`

```ts
/**
 * scheduled_lessons against a real analytics_events (home-dashboard-data D10, D14, F7, F8).
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, fixtureId } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const MIDNIGHT_ID = fixtureId('schedule', 9_000_001)
const REMOVED_ID = fixtureId('schedule', 9_000_002)
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
const total = (rows: Record<string, unknown>[], key: string) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0)

describe.skipIf(!TEST_DB_URL)('scheduled_lessons metric against the test database', () => {
  let db: FixturesDb
  let today: string
  let target: string

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
    const { refreshAnalytics, todayInTimezone } = await import('../../src/services/analytics.service.js')
    today = todayInTimezone(TZ)
    target = addDays(today, 10) // clear of every base schedule (the latest is today + 7)
    // Under the fixture enrollment 4, so reset's cascade removes them too. lessonId stays null
    // (@@unique([enrollmentId, lessonId]) admits several nulls).
    await db.prisma.lessonSchedule.createMany({
      data: [
        // Production writes UTC midnight (routes/enrollments.ts:197-198) — AT TIME ZONE Chicago would call it target − 1.
        { id: MIDNIGHT_ID, enrollmentId: FIXTURE_ENROLLMENT_IDS[3], scheduledDate: new Date(`${target}T00:00:00.000Z`), title: 'UTC midnight' },
        { id: REMOVED_ID, enrollmentId: FIXTURE_ENROLLMENT_IDS[3], scheduledDate: new Date(`${target}T12:00:00.000Z`), title: 'Removed', removedAt: new Date() },
      ],
    })
    const refreshed = await refreshAnalytics()
    expect(refreshed.refreshed).toBe(true)
  }, 180_000)

  afterAll(async () => {
    if (!db) return
    await db.prisma.lessonSchedule.deleteMany({ where: { id: { in: [MIDNIGHT_ID, REMOVED_ID] } } })
    await db.close()
  })

  it('counts a UTC-midnight schedule on its stored date under America/Chicago, and skips a removed one (F8)', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(target, -1), to: target },
        timezone: TZ,
      },
      scope
    )
    expect(result.rows).toEqual([
      { day: addDays(target, -1), scheduled_lessons: 0 },
      { day: target, scheduled_lessons: 1 },
    ])
  })

  it('counts every non-removed fixture schedule exactly once over the base span', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -48), to: addDays(today, 7) },
        timezone: TZ,
      },
      scope
    )
    const expected = await db.prisma.lessonSchedule.count({
      where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS }, removedAt: null, id: { not: MIDNIGHT_ID } },
    })
    expect(expected).toBe(102) // 30 + 30 + 21 + 21 (base.ts ENROLLMENT_PLAN)
    expect(total(result.rows, 'scheduled_lessons')).toBe(expected)
  })

  it('leaves lesson_completions totals unchanged by the new arm', async () => {
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const result = await runAnalyticsQuery(
      { metrics: ['lesson_completions'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const source = await db.prisma.memberLessonProgress.count({
      where: { memberId: { in: FIXTURE_MEMBER_IDS }, completedAt: { not: null } },
    })
    expect(Number(result.rows[0]?.lesson_completions)).toBe(source)
  })

  it('reconciles the ls: arm with its source rows (the quality-check predicate, F7)', async () => {
    const [view] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n FROM analytics_events WHERE event_id LIKE 'ls:%'`
    const [source] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n
        FROM lesson_schedules ls
        JOIN enrollments e ON e.id = ls."enrollmentId"
        JOIN groups g ON g.id = e."groupId"`
    expect(view.n).toBe(source.n)
    const [nulls] = await db.prisma.$queryRaw<{ n: number }[]>`
      SELECT COUNT(*)::int AS n FROM analytics_events
       WHERE event_type = 'LESSON_SCHEDULED' AND (event_id IS NULL OR entity_id IS NULL OR member_id IS NOT NULL)`
    expect(nulls.n).toBe(0)
  })
})
```

- [ ] **Step 4: Run it and watch it fail (when a test DB is available)** — `cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/<throwaway_db> npx vitest run fixtures/__tests__/scheduled-lessons.db.test.ts` → FAIL: `Unknown metric 'scheduled_lessons'` and `expected 0 to be 102` on the arm reconciliation. Without the variable it prints `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` — record that and rely on Step 2's red. Also `cd server && npx tsc --noEmit -p fixtures` → PASS (the test only references existing names).

- [ ] **Step 5: Register the event type and the date-bucket option** — in `server/src/services/analytics-metrics.ts`

At `:21-29` the array becomes:

```ts
export const DERIVED_EVENT_TYPES = [
  'ACTIVITY_COMPLETED',
  'VIDEO_COMPLETED',
  'VIDEO_WATCH',
  'LESSON_COMPLETED',
  'NOTE_CREATED',
  'ENROLLMENT_CREATED',
  'MEMBER_JOINED',
  // ls: arm — one row per lesson schedule on its scheduled date (home-dashboard-data D10).
  'LESSON_SCHEDULED',
] as const
```

In `interface MetricDef` (`:77-106`), after `dimensionsAllowed: boolean` add:

```ts
  /**
   * How time windows and time dimensions bucket this metric (home-dashboard-data D14).
   * 'local'       — occurred_at in the query timezone (the default; every event metric).
   * 'stored_date' — the row's stored calendar date (`scheduled_date`, the UTC date part of
   *                 lesson_schedules.scheduledDate), never shifted by the query timezone.
   * A query cannot mix the two (400).
   */
  dateBucket?: 'local' | 'stored_date'
```

After the `members_joined` entry (before the closing `]` at `:292`) add:

```ts
  {
    name: 'scheduled_lessons',
    label: 'Lessons scheduled',
    description:
      'Lesson schedules (one per enrollment × lesson) on their scheduled calendar date — the scheduled side of Home Activity. Buckets by the stored date, not the query timezone.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'current-only',
    eventTypes: ['LESSON_SCHEDULED'],
    agg: 'count',
    dimensionsAllowed: true,
    dateBucket: 'stored_date',
  },
```

- [ ] **Step 6: Teach the query engine the stored-date bucket** — in `server/src/services/analytics.service.ts`

Insert after `if (metrics.length === 0) throw new AnalyticsQueryError(400, 'At least one metric is required')` (`:524`):

```ts
  // home-dashboard-data D14: stored-date metrics window and bucket by the row's
  // stored calendar date, event metrics by occurred_at in the query timezone —
  // one query cannot do both.
  const storedDateMetrics = metrics.filter((m) => m.dateBucket === 'stored_date')
  if (storedDateMetrics.length > 0 && storedDateMetrics.length < metrics.length) {
    throw new AnalyticsQueryError(
      400,
      `Metric(s) ${storedDateMetrics.map((m) => m.name).join(', ')} bucket by stored date and cannot be combined with event-time metrics`
    )
  }
```

In `executeQuery`, directly after `const p = new Params()` (`:645`) add:

```ts
  const storedDate = metrics.every((m) => m.dateBucket === 'stored_date')
```

Replace the range block at `:681-684`:

```ts
  if (range) {
    if (storedDate) {
      where.push(`scheduled_date >= ${p.add(range.fromDate)}::date`)
      where.push(`scheduled_date < ${p.add(range.toExclusiveDate)}::date`)
    } else {
      where.push(`occurred_at >= (${p.add(range.fromDate)}::date::timestamp AT TIME ZONE ${tz()})`)
      where.push(`occurred_at < (${p.add(range.toExclusiveDate)}::date::timestamp AT TIME ZONE ${tz()})`)
    }
  }
```

Replace the bucket expression at `:714`:

```ts
    const bucketExpr = storedDate
      ? `date_trunc('${unit}', scheduled_date::timestamp)::date`
      : `date_trunc('${unit}', occurred_at AT TIME ZONE ${tz()})::date`
```

(The timezone parameter stays lazily allocated, so a stored-date query never sends an unreferenced `$n` — the 42P18 trap the comment at `:646-648` describes.)

In `runQualityChecks`, append to the `arms` array after the `ce` entry (`:275`):

```ts
      {
        prefix: 'ls',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM lesson_schedules ls
          JOIN enrollments e ON e.id = ls."enrollmentId"
          JOIN groups g ON g.id = e."groupId"`,
      },
```

- [ ] **Step 7: Run the unit test and watch it pass** — `cd server && npx vitest run src/services/__tests__/analytics-metrics.test.ts` → PASS (4 tests). `cd server && npx tsc --noEmit` → PASS.

- [ ] **Step 8: Write the hand-written matview migration** — the view body is `20260730040000.sql` lines 39–283 copied **verbatim** (the eight existing arms, `ap:` … `ce:`), then the `ce:` arm's last line (284) without its `;`, then the new `ls:` arm and the `;`, then lines 286–297 verbatim (the unique index and the six secondary indexes). Assemble it with this exact command so nothing is retyped:

```bash
OLD=server/atlas/migrations/20260730040000.sql
NEW=server/atlas/migrations/20261025120000.sql
{
cat <<'SQL'
-- ============================================================================
-- analytics_events — recreate with the ls: arm (LESSON_SCHEDULED)
-- Feature home-dashboard-data, SPEC SC1 / D10 / D14. HAND-WRITTEN: the YAML
-- toolchain does not model materialized views (server/schema/schema.yaml:4405-4407),
-- so `schema:diff` cannot produce this. THIS FILE is now the schema of record
-- for the view; 20260730040000.sql stays untouched (never edit a committed
-- migration).
--
-- The view body is 20260730040000.sql lines 39-284 copied VERBATIM, with the
-- ce: arm's terminating ';' moved after the new arm:
--   ls: lesson_schedules — one row per enrollment × lesson schedule on its
--       scheduledDate. member_id is NULL; entity_id is the enrollment (provably
--       non-NULL, F7). The scheduled_lessons metric buckets by the stored
--       scheduled_date, never AT TIME ZONE (D14).
-- Matviews have no CREATE OR REPLACE: drop, recreate (which populates it), then
-- recreate the unique index REFRESH ... CONCURRENTLY needs and the six
-- secondary indexes (20260730040000.sql:289-297). No table or row changes.
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS "analytics_events";

SQL
sed -n '39,283p' "$OLD"
echo '  AND (ce."userId" IS NULL OR u.id IS NOT NULL)'
cat <<'SQL'

UNION ALL

-- ── LESSON_SCHEDULED (ls:) — a lesson schedule on its scheduled date ─────────
SELECT
  'ls:' || ls.id::text,
  'LESSON_SCHEDULED',
  (ls."scheduledDate" AT TIME ZONE 'UTC'),
  ls."enrollmentId"::text,
  NULL::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  ls."enrollmentId"::text,
  e."studyProgramId"::text,
  ls.id::text,
  ls."lessonId"::text,
  l."dayNumber",
  NULL::text,
  NULL::text,
  ls."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  (ls."removedAt" IS NOT NULL)
FROM lesson_schedules ls
JOIN enrollments e  ON e.id = ls."enrollmentId"
JOIN groups g       ON g.id = e."groupId"
LEFT JOIN lessons l ON l.id = ls."lessonId";

SQL
sed -n '286,297p' "$OLD"
} > "$NEW"
```

The `ls:` arm's columns, in the view's column order: `event_id`, `event_type`, `occurred_at`, `entity_id` (enrollment), `member_id` (NULL), `user_id` (NULL), `organization_id`, `group_id`, `enrollment_id`, `study_program_id`, `lesson_schedule_id`, `lesson_id`, `day_number`, `scheduled_activity_id` (NULL), `activity_type` (NULL), `scheduled_date`, `value` (1), `percent` (NULL), `is_current_version` (TRUE), `is_removed`.

- [ ] **Step 9: Check the assembled file** — `grep -c '^UNION ALL' server/atlas/migrations/20261025120000.sql` → `8` (seven old + one new); `grep -c '^CREATE .*INDEX' server/atlas/migrations/20261025120000.sql` → `7`; `grep -c 'analytics_refresh_state' server/atlas/migrations/20261025120000.sql` → `0` (the singleton is already seeded); `tail -12 server/atlas/migrations/20261025120000.sql` shows the index block ending in `idx_analytics_events_type_time`.

- [ ] **Step 10: Re-hash and apply** — `cd server/atlas && ../scripts/atlas.sh migrate hash --dir file://migrations` → `atlas.sum` gains the new file's line (`git diff --stat server/atlas/migrations/atlas.sum` shows it changed). Then `cd server && npm run migrate:apply` → applies `20261025120000` to the local DB. If a throwaway test DB is set: `cd server/atlas && ../scripts/atlas.sh migrate apply --dir file://migrations --url "$FIXTURES_TEST_DATABASE_URL"` (append `?sslmode=disable` to the URL if Atlas asks). (`server/bin/atlas` is absent in worktrees; `scripts/atlas.sh` falls back to the `atlas` on PATH.)

- [ ] **Step 11: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/analytics-metrics.test.ts` → PASS; with the test DB: `cd server && FIXTURES_TEST_DATABASE_URL=… npx vitest run fixtures/__tests__/scheduled-lessons.db.test.ts fixtures/__tests__/home-dashboard.db.test.ts` → PASS (the existing home-dashboard DB suite proves the other metrics did not move). Then `cd server && npx tsc --noEmit && npx tsc --noEmit -p fixtures && npm run test:run` → PASS. `docker restart makeready-server`.

- [ ] **Step 12: Commit** — `feat(home-dashboard-data): scheduled_lessons metric and the ls: analytics_events arm`

### Task 2: Shared analytics scope service
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/services/analytics-scope.ts`
- Modify: `server/src/routes/analytics.ts:25` (imports), `:64-82` (delete `deriveScope`), `:199` (call the service)
- Test: `server/src/services/__tests__/analytics-scope.test.ts`

**Interfaces:**
- Consumes: `isSuperAdmin(userId: string): Promise<boolean>` and `getManageableOrgIds(userId: string): Promise<string[]>` (`server/src/services/permission.ts:31,305`); `type AnalyticsScope = { all: true } | { all: false; orgIds: string[]; groupIds: string[] }` (`server/src/services/analytics.service.ts:369-371`).
- Produces:
  - `export interface AnalyticsCaller { userId?: string; apiKeyId?: string }`
  - `export async function deriveAnalyticsScope(caller: AnalyticsCaller, opts?: { organizationId?: string }): Promise<AnalyticsScope | null>` — `null` = unauthenticated; without `organizationId` it is exactly the old `deriveScope(req)`; with it, the scope only narrows (an org outside the caller's scope yields an empty scope).
  - `export function isEmptyScope(scope: AnalyticsScope): boolean`

The real `deriveScope` takes the Express `req` (it reads `req.apiKeyId` and `req.user.id`, `routes/analytics.ts:72-82`), so the service takes those two values as `AnalyticsCaller` — a service never sees `req`.

- [ ] **Step 1: Write the failing test** — create `server/src/services/__tests__/analytics-scope.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ group: { findMany: vi.fn() } }))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn(), getManageableOrgIds: vi.fn() }))

vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { deriveAnalyticsScope, isEmptyScope } from '../analytics-scope.js'

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  permissionMock.getManageableOrgIds.mockResolvedValue(['org-1', 'org-2'])
  prismaMock.group.findMany.mockResolvedValue([{ id: 'own-group' }])
})

describe('deriveAnalyticsScope — unchanged analytics behaviour', () => {
  it('gives an API key the whole platform', async () => {
    expect(await deriveAnalyticsScope({ apiKeyId: 'key-1', userId: 'u1' })).toEqual({ all: true })
    expect(permissionMock.isSuperAdmin).not.toHaveBeenCalled()
  })

  it('returns null with no user', async () => {
    expect(await deriveAnalyticsScope({})).toBeNull()
  })

  it('gives a super admin the whole platform', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    expect(await deriveAnalyticsScope({ userId: 'u1' })).toEqual({ all: true })
  })

  it('gives anyone else their manageable orgs plus the active groups they created', async () => {
    expect(await deriveAnalyticsScope({ userId: 'u1' })).toEqual({
      all: false,
      orgIds: ['org-1', 'org-2'],
      groupIds: ['own-group'],
    })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { creatorId: 'u1', isActive: true },
      select: { id: true },
    })
  })
})

describe('deriveAnalyticsScope — organizationId only narrows (D9)', () => {
  it('narrows an all-scope to the one org', async () => {
    expect(await deriveAnalyticsScope({ apiKeyId: 'k' }, { organizationId: 'org-9' })).toEqual({
      all: false,
      orgIds: ['org-9'],
      groupIds: [],
    })
  })

  it('narrows to an org the caller manages', async () => {
    expect(await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-2' })).toEqual({
      all: false,
      orgIds: ['org-2'],
      groupIds: [],
    })
  })

  it('keeps only the created groups inside a foreign org', async () => {
    prismaMock.group.findMany
      .mockResolvedValueOnce([{ id: 'own-group' }, { id: 'other-own' }])
      .mockResolvedValueOnce([{ id: 'other-own' }])
    expect(await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-x' })).toEqual({
      all: false,
      orgIds: [],
      groupIds: ['other-own'],
    })
    expect(prismaMock.group.findMany).toHaveBeenLastCalledWith({
      where: { id: { in: ['own-group', 'other-own'] }, organizationId: 'org-x' },
      select: { id: true },
    })
  })

  it('reads as an empty scope for an org wholly outside the caller', async () => {
    prismaMock.group.findMany.mockResolvedValueOnce([{ id: 'own-group' }]).mockResolvedValueOnce([])
    const scope = await deriveAnalyticsScope({ userId: 'u1' }, { organizationId: 'org-x' })
    expect(scope).not.toBeNull()
    expect(isEmptyScope(scope!)).toBe(true)
  })
})

describe('isEmptyScope', () => {
  it('is false for all, true for no orgs and no groups', () => {
    expect(isEmptyScope({ all: true })).toBe(false)
    expect(isEmptyScope({ all: false, orgIds: [], groupIds: [] })).toBe(true)
    expect(isEmptyScope({ all: false, orgIds: [], groupIds: ['g'] })).toBe(false)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/analytics-scope.test.ts` → FAIL: `Failed to load url ../analytics-scope.js` (module does not exist).

- [ ] **Step 3: Write the service** — create `server/src/services/analytics-scope.ts`

```ts
/**
 * The caller's entitled analytics scope — shared by POST /api/analytics/query
 * and /api/home/* (home-dashboard-data D9). Moved verbatim from
 * routes/analytics.ts deriveScope: API keys and super admins see all; everyone
 * else sees orgs they own/hold a role in (getManageableOrgIds) plus groups they
 * personally created. `organizationId` can only NARROW it; an org wholly
 * outside the caller's scope yields an empty scope, which callers read as 404.
 */
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'
import { getManageableOrgIds, isSuperAdmin } from './permission.js'

export interface AnalyticsCaller {
  userId?: string
  apiKeyId?: string
}

export function isEmptyScope(scope: AnalyticsScope): boolean {
  return !scope.all && scope.orgIds.length === 0 && scope.groupIds.length === 0
}

async function entitledScope(caller: AnalyticsCaller): Promise<AnalyticsScope | null> {
  if (caller.apiKeyId) return { all: true }
  if (!caller.userId) return null
  if (await isSuperAdmin(caller.userId)) return { all: true }
  const [orgIds, ownGroups] = await Promise.all([
    getManageableOrgIds(caller.userId),
    prisma.group.findMany({ where: { creatorId: caller.userId, isActive: true }, select: { id: true } }),
  ])
  return { all: false, orgIds, groupIds: ownGroups.map((g) => g.id) }
}

async function narrowToOrganization(scope: AnalyticsScope, organizationId: string): Promise<AnalyticsScope> {
  if (scope.all || scope.orgIds.includes(organizationId)) {
    return { all: false, orgIds: [organizationId], groupIds: [] }
  }
  if (scope.groupIds.length === 0) return { all: false, orgIds: [], groupIds: [] }
  const groups = await prisma.group.findMany({
    where: { id: { in: scope.groupIds }, organizationId },
    select: { id: true },
  })
  return { all: false, orgIds: [], groupIds: groups.map((g) => g.id) }
}

export async function deriveAnalyticsScope(
  caller: AnalyticsCaller,
  opts: { organizationId?: string } = {}
): Promise<AnalyticsScope | null> {
  const scope = await entitledScope(caller)
  if (!scope || !opts.organizationId) return scope
  return narrowToOrganization(scope, opts.organizationId)
}
```

- [ ] **Step 4: Point analytics at it** — in `server/src/routes/analytics.ts`

Line 25 becomes (getManageableOrgIds is no longer used here):

```ts
import { isSuperAdmin, canManageGroupId } from '../services/permission.js'
import { deriveAnalyticsScope } from '../services/analytics-scope.js'
```

Delete the `// ── Scope derivation` comment block and `async function deriveScope(req: Request) { … }` (`:64-82`); keep `filtersWithinScope` (`:84-115`) exactly as it is. At `:199` replace `const scope = await deriveScope(req)` with:

```ts
    const scope = await deriveAnalyticsScope({
      userId: (req.user as { id?: string } | undefined)?.id,
      apiKeyId: req.apiKeyId,
    })
```

(`type Request` stays imported — `requireAnySession` at `:275` uses it; `AnalyticsScope` stays — `filtersWithinScope` uses it.)

- [ ] **Step 5: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/analytics-scope.test.ts` → PASS (10 tests); `cd server && npx tsc --noEmit && npm run test:run` → PASS. `docker restart makeready-server`.

- [ ] **Step 6: Commit** — `feat(home-dashboard-data): share the analytics scope as a service`

### Task 3: Sessions service (sessionizer + moment loader)
App: server
Phase: 2
Recipe: /api
Build-time risk (F1): the sessionizer runs per request over a scope's raw moments; `client_events` has no org index (only `occurredAt`, `[eventType, occurredAt]`), `member_lesson_progress`/`member_video_progress` only `[memberId, completedAt]`. Every load is bounded by a time window (callers cap `all` at 730 days, D8), and the DB test measures the 730-day load on the fixtures. If it exceeds 2 s, STOP and report the measurement — an index goes through `server/schema/schema.yaml` + `/schema` in its own task, never here; a stored rollup is analytics phase D's.

**Files:**
- Create: `server/src/services/home-sessions.ts`
- Test: `server/src/services/__tests__/home-sessions.test.ts` (unit, mocked Prisma)
- Test: `server/fixtures/__tests__/home-sessions.db.test.ts` (DB-gated F1 measurement)

**Interfaces:**
- Consumes: `type AnalyticsScope` (`server/src/services/analytics.service.ts:369-371`); `prisma` (`server/src/lib/prisma.ts`).
- Produces:
  - `export type Moment = { memberId: string; at: Date }`
  - `export type Session = { memberId: string; start: Date; end: Date; seconds: number }`
  - `export const SESSION_GAP_MS = 30 * 60 * 1000`, `export const SESSION_FLOOR_SECONDS = 60`
  - `export function sessionize(moments: Moment[], gapMs = SESSION_GAP_MS, floorSeconds = SESSION_FLOOR_SECONDS): Session[]` — pure; sorted by `start`, then `memberId`.
  - `export function scopeGroupWhere(scope: AnalyticsScope): Prisma.GroupWhereInput` — `{}` for all, else `{ OR: [{ organizationId: { in: orgIds } }, { id: { in: groupIds } }] }`.
  - `export async function loadSessions(scope: AnalyticsScope, window: { from: Date; to: Date }): Promise<Session[]>` — sessions whose `start` ∈ [from, to).

D2's moments: `client_events.occurredAt` (non-null `memberId` only, scoped by the event's enriched `organizationId`/`groupId`, and only for members that still exist — the same erasure the `ce:` view arm applies), `member_lesson_progress.completedAt`, `member_video_progress.startedAt` and `.lastWatchedAt` (both scoped schedule → enrollment → group). Moments load from a window padded 6 h on both sides so a session that began just before `from` keeps its true start and is then dropped by the `start` filter rather than truncated.

- [ ] **Step 1: Write the failing unit test** — create `server/src/services/__tests__/home-sessions.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  clientEvent: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
  memberVideoProgress: { findMany: vi.fn() },
  member: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { loadSessions, scopeGroupWhere, sessionize, type Moment } from '../home-sessions.js'

const at = (iso: string) => new Date(iso)
const m = (memberId: string, iso: string): Moment => ({ memberId, at: at(iso) })

describe('sessionize (D2)', () => {
  it('splits at a gap of exactly 30:00', () => {
    const s = sessionize([m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:30:00Z')])
    expect(s).toHaveLength(2)
    expect(s.map((x) => x.seconds)).toEqual([60, 60])
  })

  it('joins a gap of 29:59', () => {
    const s = sessionize([m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:29:59Z')])
    expect(s).toEqual([{ memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:29:59Z'), seconds: 1799 }])
  })

  it('floors a single moment at 60 s', () => {
    expect(sessionize([m('a', '2026-10-20T10:00:00Z')])).toEqual([
      { memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:00:00Z'), seconds: 60 },
    ])
  })

  it('keeps members separate even when their moments interleave', () => {
    const s = sessionize([
      m('b', '2026-10-20T10:05:00Z'),
      m('a', '2026-10-20T10:00:00Z'),
      m('a', '2026-10-20T10:10:00Z'),
      m('b', '2026-10-20T10:20:00Z'),
    ])
    expect(s).toEqual([
      { memberId: 'a', start: at('2026-10-20T10:00:00Z'), end: at('2026-10-20T10:10:00Z'), seconds: 600 },
      { memberId: 'b', start: at('2026-10-20T10:05:00Z'), end: at('2026-10-20T10:20:00Z'), seconds: 900 },
    ])
  })

  it('sorts unsorted input and chains moments each under 30 min apart', () => {
    const s = sessionize([m('a', '2026-10-20T10:50:00Z'), m('a', '2026-10-20T10:00:00Z'), m('a', '2026-10-20T10:25:00Z')])
    expect(s).toHaveLength(1)
    expect(s[0].seconds).toBe(3000)
  })
})

describe('scopeGroupWhere', () => {
  it('is unconstrained for all, else orgs OR created groups', () => {
    expect(scopeGroupWhere({ all: true })).toEqual({})
    expect(scopeGroupWhere({ all: false, orgIds: ['o1'], groupIds: ['g1'] })).toEqual({
      OR: [{ organizationId: { in: ['o1'] } }, { id: { in: ['g1'] } }],
    })
  })
})

describe('loadSessions (D2 sources)', () => {
  const scope = { all: false as const, orgIds: ['o1'], groupIds: [] as string[] }
  const window = { from: at('2026-10-20T10:00:00Z'), to: at('2026-10-20T12:00:00Z') }

  beforeEach(() => {
    vi.clearAllMocks()
    prismaMock.clientEvent.findMany.mockResolvedValue([
      { memberId: 'm1', occurredAt: at('2026-10-20T10:05:00Z') },
      { memberId: 'ghost', occurredAt: at('2026-10-20T10:10:00Z') }, // deleted member: erased
    ])
    prismaMock.member.findMany.mockResolvedValue([{ id: 'm1' }])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { memberId: 'm1', completedAt: at('2026-10-20T10:20:00Z') },
      { memberId: 'm2', completedAt: at('2026-10-20T09:00:00Z') }, // starts before the window → dropped
    ])
    prismaMock.memberVideoProgress.findMany.mockResolvedValue([
      { memberId: 'm1', startedAt: at('2026-10-20T10:06:00Z'), lastWatchedAt: at('2026-10-20T10:15:00Z') },
    ])
  })

  it('merges every source per member and keeps sessions starting in the window', async () => {
    expect(await loadSessions(scope, window)).toEqual([
      { memberId: 'm1', start: at('2026-10-20T10:05:00Z'), end: at('2026-10-20T10:20:00Z'), seconds: 900 },
    ])
  })

  it('scopes client events by org/group and the progress tables through schedule → enrollment → group', async () => {
    await loadSessions(scope, window)
    const padded = { gte: at('2026-10-20T04:00:00Z'), lt: at('2026-10-20T18:00:00Z') }
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: {
        memberId: { not: null },
        occurredAt: padded,
        OR: [{ organizationId: { in: ['o1'] } }, { groupId: { in: [] } }],
      },
      select: { memberId: true, occurredAt: true },
    })
    const scheduleWhere = { enrollment: { group: { OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] } } }
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: padded, lessonSchedule: scheduleWhere },
      select: { memberId: true, completedAt: true },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { OR: [{ startedAt: padded }, { lastWatchedAt: padded }], lessonSchedule: scheduleWhere },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    })
    expect(prismaMock.member.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['m1', 'ghost'] } },
      select: { id: true },
    })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/home-sessions.test.ts` → FAIL: `Failed to load url ../home-sessions.js`.

- [ ] **Step 3: Write the service** — create `server/src/services/home-sessions.ts`

```ts
/**
 * Home dashboard sessions (home-dashboard-data D2): a member's activity moments
 * less than 30 min apart form one session; duration = last − first, floored at
 * 60 s. Derived per request from data already recorded — no stored table.
 * Shared by /api/home/sessions (D8), /days (D6) and engagement's active count (D3).
 */
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'

export type Moment = { memberId: string; at: Date }
export type Session = { memberId: string; start: Date; end: Date; seconds: number }

export const SESSION_GAP_MS = 30 * 60 * 1000
export const SESSION_FLOOR_SECONDS = 60
/** Moments load this far either side of the window so edge sessions keep their true start. */
const LOAD_PAD_MS = 6 * 60 * 60 * 1000

export function sessionize(
  moments: Moment[],
  gapMs = SESSION_GAP_MS,
  floorSeconds = SESSION_FLOOR_SECONDS
): Session[] {
  const byMember = new Map<string, number[]>()
  for (const moment of moments) {
    const list = byMember.get(moment.memberId) ?? []
    list.push(moment.at.getTime())
    byMember.set(moment.memberId, list)
  }
  const sessions: Session[] = []
  for (const [memberId, times] of byMember) {
    times.sort((a, b) => a - b)
    let start = times[0]
    let last = times[0]
    const close = () =>
      sessions.push({
        memberId,
        start: new Date(start),
        end: new Date(last),
        seconds: Math.max(floorSeconds, Math.round((last - start) / 1000)),
      })
    for (let i = 1; i < times.length; i++) {
      if (times[i] - last >= gapMs) {
        close()
        start = times[i]
      }
      last = times[i]
    }
    close()
  }
  return sessions.sort((a, b) => a.start.getTime() - b.start.getTime() || a.memberId.localeCompare(b.memberId))
}

export function scopeGroupWhere(scope: AnalyticsScope): Prisma.GroupWhereInput {
  if (scope.all) return {}
  return { OR: [{ organizationId: { in: scope.orgIds } }, { id: { in: scope.groupIds } }] }
}

function clientEventScope(scope: AnalyticsScope): Prisma.ClientEventWhereInput {
  if (scope.all) return {}
  return { OR: [{ organizationId: { in: scope.orgIds } }, { groupId: { in: scope.groupIds } }] }
}

export async function loadSessions(scope: AnalyticsScope, window: { from: Date; to: Date }): Promise<Session[]> {
  const from = new Date(window.from.getTime() - LOAD_PAD_MS)
  const to = new Date(window.to.getTime() + LOAD_PAD_MS)
  const range = { gte: from, lt: to }
  const inRange = (d: Date) => d >= from && d < to
  const scheduleWhere = { enrollment: { group: scopeGroupWhere(scope) } }

  const [events, lessons, videos] = await Promise.all([
    prisma.clientEvent.findMany({
      where: { memberId: { not: null }, occurredAt: range, ...clientEventScope(scope) },
      select: { memberId: true, occurredAt: true },
    }),
    prisma.memberLessonProgress.findMany({
      where: { completedAt: range, lessonSchedule: scheduleWhere },
      select: { memberId: true, completedAt: true },
    }),
    prisma.memberVideoProgress.findMany({
      where: { OR: [{ startedAt: range }, { lastWatchedAt: range }], lessonSchedule: scheduleWhere },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    }),
  ])

  // client_events has no FK: drop events of deleted members, as the ce: view arm does.
  const eventMemberIds = [...new Set(events.flatMap((e) => (e.memberId ? [e.memberId] : [])))]
  const existing =
    eventMemberIds.length > 0
      ? new Set(
          (await prisma.member.findMany({ where: { id: { in: eventMemberIds } }, select: { id: true } })).map((r) => r.id)
        )
      : new Set<string>()

  const moments: Moment[] = []
  for (const e of events) if (e.memberId && existing.has(e.memberId)) moments.push({ memberId: e.memberId, at: e.occurredAt })
  for (const l of lessons) if (l.completedAt) moments.push({ memberId: l.memberId, at: l.completedAt })
  for (const v of videos) {
    if (inRange(v.startedAt)) moments.push({ memberId: v.memberId, at: v.startedAt })
    if (inRange(v.lastWatchedAt)) moments.push({ memberId: v.memberId, at: v.lastWatchedAt })
  }
  return sessionize(moments).filter((s) => s.start >= window.from && s.start < window.to)
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/home-sessions.test.ts` → PASS (9 tests); `cd server && npx tsc --noEmit` → PASS.

- [ ] **Step 5: Write the F1 measurement** — create `server/fixtures/__tests__/home-sessions.db.test.ts`

```ts
/** F1: the per-request sessionizer over the fixture org's 730-day window (home-dashboard-data D8). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('loadSessions against the fixture world (F1)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('loads 730 days for the fixture org in under 2 s, only fixture members', async () => {
    const { loadSessions } = await import('../../src/services/home-sessions.js')
    const to = new Date()
    const from = new Date(to.getTime() - 730 * 86_400_000)
    const started = Date.now()
    const sessions = await loadSessions({ all: false, orgIds: [FIXTURE_ORG_ID], groupIds: [] }, { from, to })
    const elapsed = Date.now() - started
    console.log(`F1: loadSessions(730 d, fixture org) → ${sessions.length} sessions in ${elapsed} ms`)
    expect(sessions.length).toBeGreaterThan(0)
    expect(elapsed).toBeLessThan(2_000)
    for (const s of sessions) expect(FIXTURE_MEMBER_IDS).toContain(s.memberId)
  }, 60_000)
})
```

- [ ] **Step 6: Run it** — `cd server && npx tsc --noEmit -p fixtures` → PASS; with a test DB `cd server && FIXTURES_TEST_DATABASE_URL=… npx vitest run fixtures/__tests__/home-sessions.db.test.ts` → PASS, and copy the `F1:` log line (count + ms) into your report. Without the variable it prints the skip line — say so in the report. Then `cd server && npm run test:run` → PASS.

- [ ] **Step 7: Commit** — `feat(home-dashboard-data): sessions service (sessionizer + moment loader)`

### Task 4: Home dashboard service — sessions by range, day minutes, engagement
App: server
Phase: 2
Recipe: /api
Build-time risk (F1): `all` is capped at 730 days (D8) — never load an unbounded window here; every `loadSessions` call takes an explicit `{ from, to }`.

**Files:**
- Create: `server/src/services/home-dashboard.ts`
- Test: `server/src/services/__tests__/home-dashboard.test.ts`

**Interfaces:**
- Consumes: `loadSessions(scope: AnalyticsScope, window: { from: Date; to: Date }): Promise<Session[]>`, `scopeGroupWhere(scope: AnalyticsScope): Prisma.GroupWhereInput`, `type Session = { memberId: string; start: Date; end: Date; seconds: number }` (Task 3, `server/src/services/home-sessions.ts`); `type AnalyticsScope` (`analytics.service.ts:369`).
- Produces (all exported from `server/src/services/home-dashboard.ts`):
  - `type SessionRange = 'all' | 'year' | 'month' | 'week'`
  - `interface HomeSessions { averageSeconds: number; sessionCount: number; hourly: number[]; bins: number[]; ticks: string[] }`
  - `interface HomeDay { day: string; sessionSeconds: number; blocks: number[] }`
  - `interface HomeEngagement { currentCount: number; enrolledCount: number; groupCount: number; percent: number; activeCount: number }`
  - `interface EngagementGroup { id: string; memberIds: string[]; schedules: { id: string; date: string }[] }`
  - `localDateOf(instant: Date, tz: string): string`, `localHourOf(instant: Date, tz: string): number`, `addDays(date: string, days: number): string`, `zonedMidnight(date: string, tz: string): Date`, `storedDate(d: Date): string`, `pairKey(memberId: string, scheduleId: string): string`
  - `validateDayRange(from: string, to: string): string | null` (null = valid; else the 400 message)
  - `summarizeSessions(sessions: Session[], window: { from: Date; to: Date }, tz: string): HomeSessions`
  - `bucketDays(sessions: Session[], from: string, to: string, tz: string): HomeDay[]`
  - `computeEngagement(groups: EngagementGroup[], completed: Set<string>, activeMemberIds: Set<string>, today: string): HomeEngagement`
  - `activeWindow(now: Date, tz: string): { from: Date; to: Date }`, `activeMembers(sessions: Session[], window: { from: Date; to: Date }): Set<string>`
  - `getHomeSessions(scope: AnalyticsScope, range: SessionRange, tz: string, now?: Date): Promise<HomeSessions>`
  - `getHomeDays(scope: AnalyticsScope, from: string, to: string, tz: string): Promise<{ days: HomeDay[] }>`
  - `getHomeEngagement(scope: AnalyticsScope, tz: string, now?: Date): Promise<HomeEngagement>`
  - constants `RANGE_DAYS`, `ALL_TIME_CAP_DAYS = 730`, `STRIP_BINS = 88`, `TICK_BINS = [0, 29, 58, 87]`, `MAX_DAY_SPAN = 62`, `ACTIVE_DAYS = 7`

Rulings this implements: D8 (window = last 365/30/7 local days to `now`; `all` = since max(first session, today − 729 days); dial = mean session seconds per local start hour; strip = 88 equal bins of summed seconds normalised 0–1 by the largest bin; ticks = local dates at bins 0/29/58/87, D16); D6 (every day zero-filled, each session whole to the 2-hour block it starts in, Σ blocks = sessionSeconds); D3/D14/D15 (a schedule's day is its stored UTC date, compared with today in `tz`; enrolled = active member of an active in-scope group with ≥1 non-removed schedule dated before today; current = every such due schedule completed, across the member's in-scope groups; active = distinct members with a session starting since local midnight 6 days ago).

- [ ] **Step 1: Write the failing test** — create `server/src/services/__tests__/home-dashboard.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../home-sessions.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../home-sessions.js')>()),
  loadSessions: vi.fn(),
}))

import { loadSessions, type Session } from '../home-sessions.js'
import {
  activeMembers,
  activeWindow,
  bucketDays,
  computeEngagement,
  getHomeDays,
  getHomeEngagement,
  getHomeSessions,
  summarizeSessions,
  validateDayRange,
  zonedMidnight,
} from '../home-dashboard.js'

const CHI = 'America/Chicago'
const at = (iso: string) => new Date(iso)
const session = (memberId: string, iso: string, seconds: number): Session => ({
  memberId,
  start: at(iso),
  end: new Date(at(iso).getTime() + seconds * 1000),
  seconds,
})
const SCOPE = { all: false as const, orgIds: ['o1'], groupIds: [] as string[] }
const NOW = at('2026-10-25T15:00:00Z') // 10:00 CDT, today = 2026-10-25 in Chicago

beforeEach(() => vi.clearAllMocks())

describe('zonedMidnight', () => {
  it('finds local midnight on both sides of the 2026-11-01 DST change', () => {
    expect(zonedMidnight('2026-11-01', CHI)).toEqual(at('2026-11-01T05:00:00Z'))
    expect(zonedMidnight('2026-11-02', CHI)).toEqual(at('2026-11-02T06:00:00Z'))
    expect(zonedMidnight('2026-10-25', 'UTC')).toEqual(at('2026-10-25T00:00:00Z'))
  })
})

describe('validateDayRange (≤ 62 days)', () => {
  it('accepts 1 and 62 days, rejects 63, reversed and malformed', () => {
    expect(validateDayRange('2026-10-01', '2026-10-01')).toBeNull()
    expect(validateDayRange('2026-10-01', '2026-12-01')).toBeNull() // 62 days
    expect(validateDayRange('2026-10-01', '2026-12-02')).toBe('At most 62 days')
    expect(validateDayRange('2026-10-02', '2026-10-01')).toBe('to must not be before from')
    expect(validateDayRange('2026-10-1', '2026-10-02')).toBe('from/to must be YYYY-MM-DD')
    expect(validateDayRange('2026-02-30', '2026-03-01')).toBe('from/to must be YYYY-MM-DD')
  })
})

describe('bucketDays (D6)', () => {
  it('zero-fills every day with 12 blocks summing to sessionSeconds', () => {
    const days = bucketDays([], '2026-10-30', '2026-11-02', CHI)
    expect(days.map((d) => d.day)).toEqual(['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02'])
    for (const d of days) {
      expect(d.blocks).toEqual(Array(12).fill(0))
      expect(d.sessionSeconds).toBe(0)
    }
  })

  it('puts sessions in the caller-tz block they start in across the DST boundary', () => {
    const days = bucketDays(
      [
        session('a', '2026-11-01T05:30:00Z', 600), // 00:30 CDT → Nov 1 block 0
        session('b', '2026-11-01T07:30:00Z', 300), // 01:30 CST (the repeated hour) → block 0
        session('c', '2026-11-01T08:30:00Z', 120), // 02:30 CST → block 1
        session('d', '2026-11-02T05:30:00Z', 60), // 23:30 CST, still Nov 1 → block 11
        session('e', '2026-11-02T06:30:00Z', 90), // 00:30 CST Nov 2 → block 0
      ],
      '2026-11-01',
      '2026-11-02',
      CHI
    )
    expect(days[0]).toEqual({ day: '2026-11-01', sessionSeconds: 1080, blocks: [900, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60] })
    expect(days[1]).toEqual({ day: '2026-11-02', sessionSeconds: 90, blocks: [90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] })
  })
})

describe('getHomeDays', () => {
  it('loads exactly the local days [from 00:00, to + 1 00:00)', async () => {
    vi.mocked(loadSessions).mockResolvedValue([session('a', '2026-11-01T05:30:00Z', 600)])
    const result = await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') })
    expect(result.days).toHaveLength(2)
    expect(result.days[0].sessionSeconds).toBe(600)
  })
})

describe('summarizeSessions (D8, D16)', () => {
  const window = { from: at('2026-10-19T05:00:00Z'), to: NOW } // 154 h → 1.75 h per bin
  const sessions = [
    session('a', '2026-10-20T14:00:00Z', 600), // 09:00 CDT, bin 18
    session('b', '2026-10-20T14:30:00Z', 1200), // 09:30 CDT, bin 19
    session('c', '2026-10-24T23:00:00Z', 300), // 18:00 CDT, bin 78
    session('x', '2026-10-19T04:00:00Z', 9999), // before the window: ignored
  ]

  it('averages, counts, and builds the 24-hour dial from start hours', () => {
    const s = summarizeSessions(sessions, window, CHI)
    expect(s.averageSeconds).toBe(700)
    expect(s.sessionCount).toBe(3)
    expect(s.hourly).toHaveLength(24)
    expect(s.hourly[9]).toBe(900)
    expect(s.hourly[18]).toBe(300)
    expect(s.hourly.filter((v) => v > 0)).toHaveLength(2)
  })

  it('normalises 88 bins to the largest and ticks bins 0/29/58/87 as local dates', () => {
    const s = summarizeSessions(sessions, window, CHI)
    expect(s.bins).toHaveLength(88)
    expect(s.bins[18]).toBe(0.5)
    expect(s.bins[19]).toBe(1)
    expect(s.bins[78]).toBe(0.25)
    expect(s.bins.filter((v) => v > 0)).toHaveLength(3)
    expect(s.ticks).toEqual(['2026-10-19', '2026-10-21', '2026-10-23', '2026-10-25'])
  })

  it('is all zeros with no sessions', () => {
    const s = summarizeSessions([], window, CHI)
    expect(s).toMatchObject({ averageSeconds: 0, sessionCount: 0 })
    expect(s.hourly).toEqual(Array(24).fill(0))
    expect(s.bins).toEqual(Array(88).fill(0))
  })
})

describe('getHomeSessions windows (D8)', () => {
  it.each([
    ['week', '2026-10-19T05:00:00Z'],
    ['month', '2026-09-26T05:00:00Z'],
    ['year', '2025-10-26T05:00:00Z'],
  ] as const)('%s starts at local midnight N−1 days ago and ends now', async (range, from) => {
    vi.mocked(loadSessions).mockResolvedValue([])
    await getHomeSessions(SCOPE, range, CHI, NOW)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at(from), to: NOW })
  })

  it('all loads the 730-day cap and starts the strip at the first session', async () => {
    vi.mocked(loadSessions).mockResolvedValue([session('a', '2025-01-10T15:00:00Z', 600), session('a', '2026-10-20T15:00:00Z', 300)])
    const s = await getHomeSessions(SCOPE, 'all', CHI, NOW)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2024-10-26T05:00:00Z'), to: NOW })
    expect(s.ticks[0]).toBe('2025-01-10')
    expect(s.bins[0]).toBe(1)
    expect(s.sessionCount).toBe(2)
  })
})

describe('computeEngagement (D3, D14, D15)', () => {
  const today = '2026-10-25'
  const g1 = {
    id: 'g1',
    memberIds: ['m1', 'm2'],
    schedules: [
      { id: 's1', date: '2026-10-23' },
      { id: 's2', date: '2026-10-24' },
      { id: 's3', date: '2026-10-25' }, // today: not yet due
      { id: 's4', date: '2026-10-27' },
    ],
  }
  const future = { id: 'g2', memberIds: ['m3'], schedules: [{ id: 's9', date: '2026-10-26' }] }
  const g3 = { id: 'g3', memberIds: ['m4'], schedules: [{ id: 's5', date: '2026-10-20' }] }

  it('a member with one overdue lesson is not current; future-only groups are not enrolled', () => {
    const completed = new Set(['m1|s1', 'm1|s2', 'm2|s1', 'm4|s5'])
    expect(computeEngagement([g1, future, g3], completed, new Set(['m1', 'm9']), today)).toEqual({
      currentCount: 2, // m1, m4 — m2 still owes s2
      enrolledCount: 3, // m1, m2, m4 — m3's group has nothing due
      groupCount: 2,
      percent: 67,
      activeCount: 2,
    })
  })

  it('needs a member caught up in every in-scope group they belong to', () => {
    const shared = { id: 'g4', memberIds: ['m1'], schedules: [{ id: 's7', date: '2026-10-21' }] }
    const result = computeEngagement([g1, shared], new Set(['m1|s1', 'm1|s2']), new Set(), today)
    expect(result.currentCount).toBe(0)
    expect(result.enrolledCount).toBe(2)
  })

  it('is 0% with nobody enrolled', () => {
    expect(computeEngagement([future], new Set(), new Set(), today)).toEqual({
      currentCount: 0, enrolledCount: 0, groupCount: 0, percent: 0, activeCount: 0,
    })
  })
})

describe('active window (D3: last 7 days, today included)', () => {
  it('starts at local midnight six days ago', () => {
    expect(activeWindow(NOW, CHI)).toEqual({ from: at('2026-10-19T05:00:00Z'), to: NOW })
  })

  it('counts a session at the window start and drops one a second earlier', () => {
    const window = activeWindow(NOW, CHI)
    const active = activeMembers(
      [session('in', '2026-10-19T05:00:00Z', 60), session('out', '2026-10-19T04:59:59Z', 60), session('in', '2026-10-24T15:00:00Z', 60)],
      window
    )
    expect([...active]).toEqual(['in'])
  })
})

describe('getHomeEngagement', () => {
  it('reads stored dates (D14): a UTC-midnight schedule dated today is not overdue in Chicago', async () => {
    prismaMock.group.findMany.mockResolvedValue([
      {
        id: 'g1',
        members: [{ memberId: 'm1' }, { memberId: 'm2' }],
        enrollments: [
          {
            lessonSchedules: [
              { id: 's1', scheduledDate: at('2026-10-24T17:00:00Z') },
              { id: 's2', scheduledDate: at('2026-10-25T00:00:00Z') }, // = Oct 24 19:00 CDT, but stored date is today
            ],
          },
        ],
      },
    ])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([{ memberId: 'm1', lessonScheduleId: 's1' }])
    vi.mocked(loadSessions).mockResolvedValue([session('m1', '2026-10-24T15:00:00Z', 600)])

    expect(await getHomeEngagement(SCOPE, CHI, NOW)).toEqual({
      currentCount: 1, enrolledCount: 2, groupCount: 1, percent: 50, activeCount: 1,
    })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { isActive: true, OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] },
      select: {
        id: true,
        members: { where: { isActive: true, memberId: { not: null } }, select: { memberId: true } },
        enrollments: {
          select: { lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } } },
        },
      },
    })
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: { not: null }, lessonScheduleId: { in: ['s1'] }, memberId: { in: ['m1', 'm2'] } },
      select: { memberId: true, lessonScheduleId: true },
    })
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2026-10-19T05:00:00Z'), to: NOW })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/home-dashboard.test.ts` → FAIL: `Failed to load url ../home-dashboard.js`.

- [ ] **Step 3: Write the service** — create `server/src/services/home-dashboard.ts`

```ts
/**
 * Home dashboard computations (home-dashboard-data D3, D6, D8, D14, D15, D16):
 * Sessions by range, day-card minutes + 2-hour blocks, and Engagement. Every
 * local-time decision is made in the caller's IANA tz; a schedule's day is its
 * STORED calendar date (UTC date part, D14), never shifted by tz.
 */
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'
import { loadSessions, scopeGroupWhere, type Session } from './home-sessions.js'

export type SessionRange = 'all' | 'year' | 'month' | 'week'
export const RANGE_DAYS: Record<Exclude<SessionRange, 'all'>, number> = { year: 365, month: 30, week: 7 }
export const ALL_TIME_CAP_DAYS = 730
export const STRIP_BINS = 88
export const TICK_BINS = [0, 29, 58, 87] as const
export const DAY_BLOCKS = 12
export const MAX_DAY_SPAN = 62
export const ACTIVE_DAYS = 7

export interface HomeSessions {
  averageSeconds: number
  sessionCount: number
  hourly: number[]
  bins: number[]
  ticks: string[]
}
export interface HomeDay {
  day: string
  sessionSeconds: number
  blocks: number[]
}
export interface HomeEngagement {
  currentCount: number
  enrolledCount: number
  groupCount: number
  percent: number
  activeCount: number
}
export interface EngagementGroup {
  id: string
  memberIds: string[]
  /** Non-removed schedules, `date` = the stored calendar date (D14). */
  schedules: { id: string; date: string }[]
}

// ── Time helpers (formatters cached per tz — they are expensive to build) ────

const dateFormats = new Map<string, Intl.DateTimeFormat>()
const hourFormats = new Map<string, Intl.DateTimeFormat>()
const offsetFormats = new Map<string, Intl.DateTimeFormat>()

function cached(map: Map<string, Intl.DateTimeFormat>, tz: string, make: () => Intl.DateTimeFormat): Intl.DateTimeFormat {
  let f = map.get(tz)
  if (!f) {
    f = make()
    map.set(tz, f)
  }
  return f
}

/** Calendar date (YYYY-MM-DD) of an instant in tz. */
export function localDateOf(instant: Date, tz: string): string {
  return cached(dateFormats, tz, () =>
    new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' })
  ).format(instant)
}

/** Wall-clock hour 0–23 of an instant in tz. */
export function localHourOf(instant: Date, tz: string): number {
  const parts = cached(hourFormats, tz, () =>
    new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', hourCycle: 'h23' })
  ).formatToParts(instant)
  return Number(parts.find((p) => p.type === 'hour')?.value ?? '0') % 24
}

/** Date-only arithmetic on YYYY-MM-DD (UTC-noon anchor avoids DST edges). */
export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** Milliseconds tz is ahead of UTC at `instant` (as fixtures/context.ts tzOffsetMs). */
function tzOffsetMs(instant: Date, tz: string): number {
  const parts = cached(offsetFormats, tz, () =>
    new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
  ).formatToParts(instant)
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? '0')
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second'))
  return asUtc - (instant.getTime() - instant.getUTCMilliseconds())
}

/** The UTC instant of local 00:00 on `date` in tz. */
export function zonedMidnight(date: string, tz: string): Date {
  const [y, m, d] = date.split('-').map(Number)
  const wall = Date.UTC(y, m - 1, d)
  const first = wall - tzOffsetMs(new Date(wall), tz)
  return new Date(wall - tzOffsetMs(new Date(first), tz))
}

/** A schedule's day: the stored calendar date (D14). */
export function storedDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function pairKey(memberId: string, scheduleId: string): string {
  return `${memberId}|${scheduleId}`
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/
const isRealDate = (d: string) => DATE_RE.test(d) && !Number.isNaN(Date.parse(`${d}T00:00:00Z`)) && storedDate(new Date(`${d}T00:00:00Z`)) === d

/** null when valid; otherwise the 400 message (§Contract: yyyy-MM-dd, ≤ 62 days). */
export function validateDayRange(from: string, to: string): string | null {
  if (!isRealDate(from) || !isRealDate(to)) return 'from/to must be YYYY-MM-DD'
  if (to < from) return 'to must not be before from'
  const span = Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1
  if (span > MAX_DAY_SPAN) return `At most ${MAX_DAY_SPAN} days`
  return null
}

// ── Sessions by range (D8, D16) ──────────────────────────────────────────────

export function summarizeSessions(sessions: Session[], window: { from: Date; to: Date }, tz: string): HomeSessions {
  const inWindow = sessions.filter((s) => s.start >= window.from && s.start < window.to)
  const hourSums: number[] = Array(24).fill(0)
  const hourCounts: number[] = Array(24).fill(0)
  const binSums: number[] = Array(STRIP_BINS).fill(0)
  const fromMs = window.from.getTime()
  const span = Math.max(1, window.to.getTime() - fromMs)
  let total = 0
  for (const s of inWindow) {
    const hour = localHourOf(s.start, tz)
    hourSums[hour] += s.seconds
    hourCounts[hour] += 1
    const bin = Math.min(STRIP_BINS - 1, Math.floor(((s.start.getTime() - fromMs) / span) * STRIP_BINS))
    binSums[bin] += s.seconds
    total += s.seconds
  }
  const maxBin = Math.max(0, ...binSums)
  return {
    averageSeconds: inWindow.length > 0 ? Math.round(total / inWindow.length) : 0,
    sessionCount: inWindow.length,
    hourly: hourSums.map((sum, h) => (hourCounts[h] > 0 ? Math.round(sum / hourCounts[h]) : 0)),
    bins: binSums.map((v) => (maxBin > 0 ? Math.round((v / maxBin) * 1000) / 1000 : 0)),
    ticks: TICK_BINS.map((i) => localDateOf(new Date(fromMs + (i * span) / STRIP_BINS), tz)),
  }
}

export async function getHomeSessions(
  scope: AnalyticsScope,
  range: SessionRange,
  tz: string,
  now: Date = new Date()
): Promise<HomeSessions> {
  const today = localDateOf(now, tz)
  if (range === 'all') {
    const cap = { from: zonedMidnight(addDays(today, -(ALL_TIME_CAP_DAYS - 1)), tz), to: now }
    const sessions = await loadSessions(scope, cap)
    const first = sessions.reduce<Date | null>((min, s) => (min === null || s.start < min ? s.start : min), null)
    return summarizeSessions(sessions, { from: first ?? cap.from, to: now }, tz)
  }
  const window = { from: zonedMidnight(addDays(today, -(RANGE_DAYS[range] - 1)), tz), to: now }
  return summarizeSessions(await loadSessions(scope, window), window, tz)
}

// ── Day cards (D6) ───────────────────────────────────────────────────────────

export function bucketDays(sessions: Session[], from: string, to: string, tz: string): HomeDay[] {
  const days: HomeDay[] = []
  const byDay = new Map<string, HomeDay>()
  for (let d = from; d <= to; d = addDays(d, 1)) {
    const day: HomeDay = { day: d, sessionSeconds: 0, blocks: Array(DAY_BLOCKS).fill(0) }
    days.push(day)
    byDay.set(d, day)
  }
  for (const s of sessions) {
    const day = byDay.get(localDateOf(s.start, tz))
    if (!day) continue
    day.blocks[Math.floor(localHourOf(s.start, tz) / 2)] += s.seconds
    day.sessionSeconds += s.seconds
  }
  return days
}

export async function getHomeDays(
  scope: AnalyticsScope,
  from: string,
  to: string,
  tz: string
): Promise<{ days: HomeDay[] }> {
  const window = { from: zonedMidnight(from, tz), to: zonedMidnight(addDays(to, 1), tz) }
  return { days: bucketDays(await loadSessions(scope, window), from, to, tz) }
}

// ── Engagement (D3, D14, D15) ────────────────────────────────────────────────

export function computeEngagement(
  groups: EngagementGroup[],
  completed: Set<string>,
  activeMemberIds: Set<string>,
  today: string
): HomeEngagement {
  const dueByMember = new Map<string, Set<string>>()
  const enrolledGroups = new Set<string>()
  for (const group of groups) {
    const due = group.schedules.filter((s) => s.date < today)
    if (due.length === 0) continue
    enrolledGroups.add(group.id)
    for (const memberId of group.memberIds) {
      const set = dueByMember.get(memberId) ?? new Set<string>()
      for (const s of due) set.add(s.id)
      dueByMember.set(memberId, set)
    }
  }
  let current = 0
  for (const [memberId, due] of dueByMember) {
    if ([...due].every((scheduleId) => completed.has(pairKey(memberId, scheduleId)))) current += 1
  }
  const enrolled = dueByMember.size
  return {
    currentCount: current,
    enrolledCount: enrolled,
    groupCount: enrolledGroups.size,
    percent: enrolled > 0 ? Math.round((current / enrolled) * 100) : 0,
    activeCount: activeMemberIds.size,
  }
}

export function activeWindow(now: Date, tz: string): { from: Date; to: Date } {
  return { from: zonedMidnight(addDays(localDateOf(now, tz), -(ACTIVE_DAYS - 1)), tz), to: now }
}

export function activeMembers(sessions: Session[], window: { from: Date; to: Date }): Set<string> {
  return new Set(sessions.filter((s) => s.start >= window.from && s.start < window.to).map((s) => s.memberId))
}

export async function getHomeEngagement(
  scope: AnalyticsScope,
  tz: string,
  now: Date = new Date()
): Promise<HomeEngagement> {
  const today = localDateOf(now, tz)
  const rows = await prisma.group.findMany({
    where: { isActive: true, ...scopeGroupWhere(scope) },
    select: {
      id: true,
      members: { where: { isActive: true, memberId: { not: null } }, select: { memberId: true } },
      enrollments: {
        select: { lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } } },
      },
    },
  })
  const groups: EngagementGroup[] = rows.map((g) => ({
    id: g.id,
    memberIds: g.members.flatMap((m) => (m.memberId ? [m.memberId] : [])),
    schedules: g.enrollments.flatMap((e) =>
      e.lessonSchedules.map((s) => ({ id: s.id, date: storedDate(s.scheduledDate) }))
    ),
  }))
  const dueIds = [...new Set(groups.flatMap((g) => g.schedules.filter((s) => s.date < today).map((s) => s.id)))]
  const memberIds = [...new Set(groups.flatMap((g) => g.memberIds))]
  const progress =
    dueIds.length > 0 && memberIds.length > 0
      ? await prisma.memberLessonProgress.findMany({
          where: { completedAt: { not: null }, lessonScheduleId: { in: dueIds }, memberId: { in: memberIds } },
          select: { memberId: true, lessonScheduleId: true },
        })
      : []
  const completed = new Set(progress.map((p) => pairKey(p.memberId, p.lessonScheduleId)))
  const window = activeWindow(now, tz)
  const active = activeMembers(await loadSessions(scope, window), window)
  return computeEngagement(groups, completed, active, today)
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/home-dashboard.test.ts` → PASS; `cd server && npx tsc --noEmit && npm run test:run` → PASS.

- [ ] **Step 5: Commit** — `feat(home-dashboard-data): home sessions, day-card and engagement service`

### Task 5: Following service (preference parse + assembly)
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/services/home-following.ts`
- Test: `server/src/services/__tests__/home-following.test.ts`

**Interfaces:**
- Consumes: `getPreference(identity: { userId?: string; memberId?: string }, key: string): Promise<string | null>` (`server/src/services/preferences.ts:57`); `enrollmentManageFilter(userId: string): Promise<Prisma.EnrollmentWhereInput>` (`server/src/services/permission.ts:337`); `scopeGroupWhere(scope: AnalyticsScope): Prisma.GroupWhereInput` (Task 3, `home-sessions.ts`); `storedDate(d: Date): string`, `pairKey(memberId: string, scheduleId: string): string` (Task 4, `home-dashboard.ts`).
- Produces (exported from `server/src/services/home-following.ts`):
  - `FOLLOWED_ENROLLMENTS_KEY = 'dashboard.followedEnrollments'`, `MAX_FOLLOWED = 50`
  - `parseFollowedEnrollments(value: string | null | undefined): string[]`
  - `interface FollowingGroup { enrollmentId: string; groupName: string; photoUrl: string | null; memberCount: number; percent: number; synced: boolean }`
  - `interface FollowingProgram { id: string; title: string; author: string; createdAt: string; groups: FollowingGroup[] }`
  - `interface FollowedEnrollmentRow` (the Prisma select shape below)
  - `assembleFollowing(rows: FollowedEnrollmentRow[], completed: Set<string>, order: string[], today: string): { programs: FollowingProgram[] }`
  - `getHomeFollowing(scope: AnalyticsScope, userId: string, now?: Date): Promise<{ programs: FollowingProgram[] }>`

Rulings: D4 (the value is a JSON-encoded string; parse in try/catch, string entries only, dedupe, cap 50; unset / `''` / unparseable / non-array / empty → empty state; ids outside `enrollmentManageFilter` AND the D9 scope are dropped silently by the query). D11 (title = `StudyProgram.name`, author = `creator.name` or `""`, `createdAt` as an ISO-8601 **string** (§Contract, F5), group name, `Group.coverImageUrl` or null, member count = active group members with a member, percent = round(completed ÷ (members × non-removed schedules whose stored date ≤ today UTC) × 100), synced = `syncMode !== 'OFF'`; programs by title, groups by name). `/following` carries no `tz` in §Contract, so "to date" is today's UTC date. Ties on title/name keep the preference order — that is how the preference order shows in the output.

- [ ] **Step 1: Write the failing test** — create `server/src/services/__tests__/home-following.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  enrollment: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
}))
const preferencesMock = vi.hoisted(() => ({ getPreference: vi.fn() }))
const permissionMock = vi.hoisted(() => ({ enrollmentManageFilter: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../preferences.js', () => preferencesMock)
vi.mock('../permission.js', () => permissionMock)

import {
  FOLLOWED_ENROLLMENTS_KEY,
  assembleFollowing,
  getHomeFollowing,
  parseFollowedEnrollments,
  type FollowedEnrollmentRow,
} from '../home-following.js'

const at = (iso: string) => new Date(iso)
const row = (over: Partial<FollowedEnrollmentRow> & { id: string }): FollowedEnrollmentRow => ({
  syncMode: 'OFF',
  group: { name: 'Group', coverImageUrl: null, members: [] },
  studyProgram: { id: 'p', name: 'Program', createdAt: at('2026-08-01T10:00:00.123Z'), creator: null },
  lessonSchedules: [],
  ...over,
})

const r1 = row({
  id: 'e1',
  syncMode: 'AUTO',
  group: { name: 'Young Adults', coverImageUrl: 'https://img/ya.jpg', members: [{ memberId: 'm1' }, { memberId: 'm2' }] },
  studyProgram: { id: 'p2', name: 'Walking Through John', createdAt: at('2026-08-01T10:00:00.123Z'), creator: { name: 'Fixture Leader' } },
  lessonSchedules: [
    { id: 's1', scheduledDate: at('2026-10-20T17:00:00Z') },
    { id: 's2', scheduledDate: at('2026-10-24T17:00:00Z') },
    { id: 's3', scheduledDate: at('2026-10-30T17:00:00Z') }, // not yet due
  ],
})
const r2 = row({
  id: 'e2',
  group: { name: "Women's Bible Study", coverImageUrl: null, members: [{ memberId: 'm3' }] },
  studyProgram: { id: 'p1', name: 'Foundations of Faith', createdAt: at('2026-07-01T00:00:00Z'), creator: null },
  lessonSchedules: [{ id: 's4', scheduledDate: at('2026-10-22T17:00:00Z') }],
})
const r3 = row({
  id: 'e3',
  syncMode: 'APPROVAL',
  group: { name: "Tuesday Men's Group", coverImageUrl: null, members: [{ memberId: 'm4' }, { memberId: 'm5' }, { memberId: null }] },
  studyProgram: { id: 'p1', name: 'Foundations of Faith', createdAt: at('2026-07-01T00:00:00Z'), creator: null },
  lessonSchedules: [{ id: 's5', scheduledDate: at('2026-10-23T17:00:00Z') }],
})
const completed = new Set(['m1|s1', 'm1|s2', 'm2|s1', 'm3|s4', 'm4|s5'])

describe('parseFollowedEnrollments (D4)', () => {
  it.each([[null], [undefined], [''], ['not json'], ['{"a":1}'], ['"e1"'], ['42'], ['[]']])('reads %j as nothing followed', (value) => {
    expect(parseFollowedEnrollments(value)).toEqual([])
  })

  it('keeps non-empty strings in order, deduped', () => {
    expect(parseFollowedEnrollments('["e1", 2, null, "", {"id":"x"}, "e2", "e1"]')).toEqual(['e1', 'e2'])
  })

  it('caps at 50', () => {
    const ids = Array.from({ length: 60 }, (_, i) => `e${i}`)
    expect(parseFollowedEnrollments(JSON.stringify(ids))).toEqual(ids.slice(0, 50))
  })
})

describe('assembleFollowing (D11)', () => {
  it('groups by program, orders programs by title and groups by name, and computes each card', () => {
    expect(assembleFollowing([r1, r2, r3], completed, ['e1', 'e3', 'e2'], '2026-10-25')).toEqual({
      programs: [
        {
          id: 'p1',
          title: 'Foundations of Faith',
          author: '',
          createdAt: '2026-07-01T00:00:00.000Z',
          groups: [
            { enrollmentId: 'e3', groupName: "Tuesday Men's Group", photoUrl: null, memberCount: 2, percent: 50, synced: true },
            { enrollmentId: 'e2', groupName: "Women's Bible Study", photoUrl: null, memberCount: 1, percent: 100, synced: false },
          ],
        },
        {
          id: 'p2',
          title: 'Walking Through John',
          author: 'Fixture Leader',
          createdAt: '2026-08-01T10:00:00.123Z',
          groups: [
            { enrollmentId: 'e1', groupName: 'Young Adults', photoUrl: 'https://img/ya.jpg', memberCount: 2, percent: 75, synced: true },
          ],
        },
      ],
    })
  })

  it('breaks title/name ties by the preference order', () => {
    const a = row({ id: 'ea', group: { name: 'Alpha', coverImageUrl: null, members: [] } })
    const b = row({ id: 'eb', group: { name: 'Alpha', coverImageUrl: null, members: [] } })
    const out = assembleFollowing([a, b], new Set(), ['eb', 'ea'], '2026-10-25')
    expect(out.programs[0].groups.map((g) => g.enrollmentId)).toEqual(['eb', 'ea'])
  })

  it('is 0% when nothing is due or nobody is in the group', () => {
    const out = assembleFollowing([row({ id: 'e9' })], new Set(), ['e9'], '2026-10-25')
    expect(out.programs[0].groups[0].percent).toBe(0)
  })
})

describe('getHomeFollowing', () => {
  const scope = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
  const manage = { OR: [{ createdById: 'u1' }, { group: { OR: [{ creatorId: 'u1' }, { organizationId: { in: ['org-1'] } }] } }] }
  const NOW = at('2026-10-25T15:00:00Z')

  beforeEach(() => {
    vi.clearAllMocks()
    permissionMock.enrollmentManageFilter.mockResolvedValue(manage)
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { memberId: 'm1', lessonScheduleId: 's1' },
      { memberId: 'm1', lessonScheduleId: 's2' },
      { memberId: 'm2', lessonScheduleId: 's1' },
    ])
  })

  it('returns the empty state without querying when nothing is followed', async () => {
    preferencesMock.getPreference.mockResolvedValue(null)
    expect(await getHomeFollowing(scope, 'u1', NOW)).toEqual({ programs: [] })
    expect(preferencesMock.getPreference).toHaveBeenCalledWith({ userId: 'u1' }, FOLLOWED_ENROLLMENTS_KEY)
    expect(prismaMock.enrollment.findMany).not.toHaveBeenCalled()
  })

  it('drops an unknown id and a foreign-org id through the manage filter AND the scope', async () => {
    preferencesMock.getPreference.mockResolvedValue(JSON.stringify(['e1', 'ghost', 'foreign']))
    prismaMock.enrollment.findMany.mockResolvedValue([r1]) // the database returns only what passes the where
    const out = await getHomeFollowing(scope, 'u1', NOW)
    expect(out.programs.flatMap((p) => p.groups.map((g) => g.enrollmentId))).toEqual(['e1'])
    expect(permissionMock.enrollmentManageFilter).toHaveBeenCalledWith('u1')
    expect(prismaMock.enrollment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: [
            { id: { in: ['e1', 'ghost', 'foreign'] } },
            manage,
            { group: { isActive: true, OR: [{ organizationId: { in: ['org-1'] } }, { id: { in: [] } }] } },
          ],
        },
      })
    )
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: { not: null }, lessonScheduleId: { in: ['s1', 's2'] }, memberId: { in: ['m1', 'm2'] } },
      select: { memberId: true, lessonScheduleId: true },
    })
    expect(out.programs[0].groups[0].percent).toBe(75)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/home-following.test.ts` → FAIL: `Failed to load url ../home-following.js`.

- [ ] **Step 3: Write the service** — create `server/src/services/home-following.ts`

```ts
/**
 * Home Following (home-dashboard-data D4, D11): the caller's followed
 * enrollments — the `dashboard.followedEnrollments` preference, a JSON-encoded
 * string of enrollment ids — grouped by program. Ids the caller cannot manage
 * (enrollmentManageFilter) or outside the D9 scope are dropped silently.
 */
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'
import { pairKey, storedDate } from './home-dashboard.js'
import { scopeGroupWhere } from './home-sessions.js'
import { enrollmentManageFilter } from './permission.js'
import { getPreference } from './preferences.js'

export const FOLLOWED_ENROLLMENTS_KEY = 'dashboard.followedEnrollments'
export const MAX_FOLLOWED = 50

export interface FollowingGroup {
  enrollmentId: string
  groupName: string
  photoUrl: string | null
  memberCount: number
  percent: number
  synced: boolean
}
export interface FollowingProgram {
  id: string
  title: string
  author: string
  /** ISO 8601 string — the iPhone decodes it as String, not Date (F5). */
  createdAt: string
  groups: FollowingGroup[]
}
export interface FollowedEnrollmentRow {
  id: string
  syncMode: 'OFF' | 'AUTO' | 'APPROVAL'
  group: { name: string; coverImageUrl: string | null; members: { memberId: string | null }[] }
  studyProgram: { id: string; name: string; createdAt: Date; creator: { name: string } | null }
  lessonSchedules: { id: string; scheduledDate: Date }[]
}

export function parseFollowedEnrollments(value: string | null | undefined): string[] {
  if (!value) return []
  let parsed: unknown
  try {
    parsed = JSON.parse(value)
  } catch {
    return []
  }
  if (!Array.isArray(parsed)) return []
  const out: string[] = []
  const seen = new Set<string>()
  for (const entry of parsed) {
    if (typeof entry !== 'string' || entry.length === 0 || seen.has(entry)) continue
    seen.add(entry)
    out.push(entry)
    if (out.length === MAX_FOLLOWED) break
  }
  return out
}

const memberIdsOf = (row: FollowedEnrollmentRow) =>
  [...new Set(row.group.members.flatMap((m) => (m.memberId ? [m.memberId] : [])))]
const dueSchedulesOf = (row: FollowedEnrollmentRow, today: string) =>
  row.lessonSchedules.filter((s) => storedDate(s.scheduledDate) <= today)

export function assembleFollowing(
  rows: FollowedEnrollmentRow[],
  completed: Set<string>,
  order: string[],
  today: string
): { programs: FollowingProgram[] } {
  const rank = (id: string) => {
    const i = order.indexOf(id)
    return i === -1 ? order.length : i
  }
  const programs = new Map<string, { program: FollowingProgram; firstRank: number; ranks: Map<string, number> }>()
  for (const row of rows) {
    const members = memberIdsOf(row)
    const due = dueSchedulesOf(row, today)
    const expected = members.length * due.length
    let done = 0
    for (const memberId of members) for (const s of due) if (completed.has(pairKey(memberId, s.id))) done += 1
    const group: FollowingGroup = {
      enrollmentId: row.id,
      groupName: row.group.name,
      photoUrl: row.group.coverImageUrl,
      memberCount: members.length,
      percent: expected > 0 ? Math.min(100, Math.round((done / expected) * 100)) : 0,
      synced: row.syncMode !== 'OFF',
    }
    const entry = programs.get(row.studyProgram.id) ?? {
      program: {
        id: row.studyProgram.id,
        title: row.studyProgram.name,
        author: row.studyProgram.creator?.name ?? '',
        createdAt: row.studyProgram.createdAt.toISOString(),
        groups: [],
      },
      firstRank: rank(row.id),
      ranks: new Map<string, number>(),
    }
    entry.program.groups.push(group)
    entry.ranks.set(row.id, rank(row.id))
    entry.firstRank = Math.min(entry.firstRank, rank(row.id))
    programs.set(row.studyProgram.id, entry)
  }
  const sorted = [...programs.values()].sort(
    (a, b) => a.program.title.localeCompare(b.program.title) || a.firstRank - b.firstRank
  )
  for (const entry of sorted) {
    entry.program.groups.sort(
      (a, b) =>
        a.groupName.localeCompare(b.groupName) ||
        (entry.ranks.get(a.enrollmentId) ?? 0) - (entry.ranks.get(b.enrollmentId) ?? 0)
    )
  }
  return { programs: sorted.map((e) => e.program) }
}

export async function getHomeFollowing(
  scope: AnalyticsScope,
  userId: string,
  now: Date = new Date()
): Promise<{ programs: FollowingProgram[] }> {
  const ids = parseFollowedEnrollments(await getPreference({ userId }, FOLLOWED_ENROLLMENTS_KEY))
  if (ids.length === 0) return { programs: [] }

  const manage = await enrollmentManageFilter(userId)
  const rows: FollowedEnrollmentRow[] = await prisma.enrollment.findMany({
    where: { AND: [{ id: { in: ids } }, manage, { group: { isActive: true, ...scopeGroupWhere(scope) } }] },
    select: {
      id: true,
      syncMode: true,
      group: {
        select: {
          name: true,
          coverImageUrl: true,
          members: { where: { isActive: true, memberId: { not: null } }, select: { memberId: true } },
        },
      },
      studyProgram: { select: { id: true, name: true, createdAt: true, creator: { select: { name: true } } } },
      lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } },
    },
  })

  const today = storedDate(now) // §Contract gives /following no tz: "to date" is today's UTC date
  const dueIds = [...new Set(rows.flatMap((r) => dueSchedulesOf(r, today).map((s) => s.id)))]
  const memberIds = [...new Set(rows.flatMap(memberIdsOf))]
  const progress =
    dueIds.length > 0 && memberIds.length > 0
      ? await prisma.memberLessonProgress.findMany({
          where: { completedAt: { not: null }, lessonScheduleId: { in: dueIds }, memberId: { in: memberIds } },
          select: { memberId: true, lessonScheduleId: true },
        })
      : []
  const completed = new Set(progress.map((p) => pairKey(p.memberId, p.lessonScheduleId)))
  return assembleFollowing(rows, completed, ids, today)
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/home-following.test.ts` → PASS; `cd server && npx tsc --noEmit && npm run test:run` → PASS. (If tsc rejects the `rows: FollowedEnrollmentRow[]` annotation because Prisma types `syncMode` as `$Enums.EnrollmentSyncMode`, change the interface field to `syncMode: EnrollmentSyncMode` imported as `import type { EnrollmentSyncMode } from '../generated/prisma/index.js'` — the values are the same three, `prisma/schema.prisma:145-149`.)

- [ ] **Step 5: Commit** — `feat(home-dashboard-data): home following service`

### Task 6: `/api/home` routes
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/routes/home.ts`
- Modify: `server/src/index.ts:41` (import), `:481-484` (mount after the analytics routes)
- Modify: `server/src/services/analytics.service.ts:431` (export `assertValidTimezone`)
- Test: `server/src/routes/__tests__/home.test.ts`

**Interfaces:**
- Consumes: `deriveAnalyticsScope(caller: { userId?: string; apiKeyId?: string }, opts?: { organizationId?: string }): Promise<AnalyticsScope | null>`, `isEmptyScope(scope: AnalyticsScope): boolean` (Task 2); `getHomeSessions(scope, range: SessionRange, tz: string, now?: Date): Promise<HomeSessions>`, `getHomeDays(scope, from: string, to: string, tz: string): Promise<{ days: HomeDay[] }>`, `getHomeEngagement(scope, tz: string, now?: Date): Promise<HomeEngagement>`, `validateDayRange(from: string, to: string): string | null` (Task 4); `getHomeFollowing(scope, userId: string, now?: Date): Promise<{ programs: FollowingProgram[] }>` (Task 5); `requireAuth` (`server/src/middleware/auth.ts:21`); `AnalyticsQueryError` (`analytics.service.ts:360`).
- Produces: `export function assertValidTimezone(tz: string): void` (throws `AnalyticsQueryError(400, 'Invalid timezone: <tz>')`); the router mounted at `/api/home` with §Contract's four GETs — bodies exactly the contract shapes; errors `{ success: false, error }` with 400 (bad range / tz / day range / malformed query), 401 (`requireAuth`), 404 `Not found` (empty scope).

- [ ] **Step 1: Write the failing request test** — create `server/src/routes/__tests__/home.test.ts` (the router through a minimal Express app with mocked services for behaviour, plus the full `index.js` app — mocked Prisma/pg exactly as `beta.test.ts:5-32` — for the mount)

```ts
import express from 'express'
import request from 'supertest'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  faqItem: { findMany: vi.fn() },
  user: { findFirst: vi.fn() },
  $transaction: vi.fn(),
  $queryRaw: vi.fn(),
  $connect: vi.fn(),
}))
const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))
vi.mock('pg', () => ({
  default: { Pool: vi.fn().mockImplementation(() => ({ connect: vi.fn().mockResolvedValue(pgMock) })) },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/analytics-scope.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/analytics-scope.js')>()),
  deriveAnalyticsScope: vi.fn(),
}))
vi.mock('../../services/home-dashboard.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-dashboard.js')>()),
  getHomeSessions: vi.fn(),
  getHomeDays: vi.fn(),
  getHomeEngagement: vi.fn(),
}))
vi.mock('../../services/home-following.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-following.js')>()),
  getHomeFollowing: vi.fn(),
}))

import { deriveAnalyticsScope } from '../../services/analytics-scope.js'
import { getHomeDays, getHomeEngagement, getHomeSessions } from '../../services/home-dashboard.js'
import { getHomeFollowing } from '../../services/home-following.js'
import homeRoutes from '../home.js'

const SCOPE = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
const SESSIONS = { averageSeconds: 840, sessionCount: 12, hourly: Array(24).fill(0), bins: Array(88).fill(0), ticks: ['2026-10-19', '2026-10-21', '2026-10-23', '2026-10-25'] }
const ENGAGEMENT = { currentCount: 10, enrolledCount: 24, groupCount: 3, percent: 42, activeCount: 18 }

/** requireAuth passes when req.user and req.apiKeyId are set (middleware/auth.ts:27). */
function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/home', homeRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(deriveAnalyticsScope).mockResolvedValue(SCOPE)
  vi.mocked(getHomeSessions).mockResolvedValue(SESSIONS)
  vi.mocked(getHomeDays).mockResolvedValue({ days: [{ day: '2026-10-25', sessionSeconds: 60, blocks: [60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] }] })
  vi.mocked(getHomeEngagement).mockResolvedValue(ENGAGEMENT)
  vi.mocked(getHomeFollowing).mockResolvedValue({ programs: [] })
})

describe('GET /api/home/sessions', () => {
  it('returns the contract body for a valid range, scoped by organizationId', async () => {
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&tz=America%2FChicago&organizationId=org-1')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(SESSIONS)
    expect(deriveAnalyticsScope).toHaveBeenCalledWith({ userId: 'u1', apiKeyId: 'test-key' }, { organizationId: 'org-1' })
    expect(getHomeSessions).toHaveBeenCalledWith(SCOPE, 'week', 'America/Chicago', expect.any(Date))
  })

  it('accepts Etc/GMT+5 (percent-encoded +) and defaults tz to UTC', async () => {
    expect((await request(appAs('u1')).get('/api/home/sessions?range=all&tz=Etc%2FGMT%2B5')).status).toBe(200)
    await request(appAs('u1')).get('/api/home/sessions?range=year')
    expect(getHomeSessions).toHaveBeenLastCalledWith(SCOPE, 'year', 'UTC', expect.any(Date))
  })

  it('400s a bad or missing range', async () => {
    expect((await request(appAs('u1')).get('/api/home/sessions?range=decade')).status).toBe(400)
    expect((await request(appAs('u1')).get('/api/home/sessions')).status).toBe(400)
    expect(getHomeSessions).not.toHaveBeenCalled()
  })

  it('400s a bad timezone', async () => {
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&tz=Mars%2FBase')
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Invalid timezone: Mars/Base' })
  })

  it('401s without auth', async () => {
    expect((await request(appAs()).get('/api/home/sessions?range=week')).status).toBe(401)
  })

  it('404s an empty scope', async () => {
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&organizationId=foreign')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
  })
})

describe('GET /api/home/days', () => {
  it('returns every day for a valid range', async () => {
    const res = await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-31')
    expect(res.status).toBe(200)
    expect(res.body.days).toHaveLength(1)
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-10-01', '2026-10-31', 'UTC')
  })

  it.each([
    ['more than 62 days', 'from=2026-10-01&to=2026-12-15'],
    ['to before from', 'from=2026-10-10&to=2026-10-01'],
    ['a malformed date', 'from=2026-10-1&to=2026-10-02'],
    ['a missing bound', 'from=2026-10-01'],
  ])('400s %s', async (_label, qs) => {
    expect((await request(appAs('u1')).get(`/api/home/days?${qs}`)).status).toBe(400)
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s a bad tz and 401s without auth', async () => {
    expect((await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-02&tz=Nope')).status).toBe(400)
    expect((await request(appAs()).get('/api/home/days?from=2026-10-01&to=2026-10-02')).status).toBe(401)
  })
})

describe('GET /api/home/engagement', () => {
  it('returns the contract body', async () => {
    const res = await request(appAs('u1')).get('/api/home/engagement?tz=America%2FChicago')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(ENGAGEMENT)
    expect(getHomeEngagement).toHaveBeenCalledWith(SCOPE, 'America/Chicago', expect.any(Date))
  })

  it('400s a bad tz, 401s without auth, 404s an empty scope', async () => {
    expect((await request(appAs('u1')).get('/api/home/engagement?tz=Nope')).status).toBe(400)
    expect((await request(appAs()).get('/api/home/engagement')).status).toBe(401)
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    expect((await request(appAs('u1')).get('/api/home/engagement')).status).toBe(404)
  })
})

describe('GET /api/home/following', () => {
  it('reads the caller’s follows within scope', async () => {
    const res = await request(appAs('u1')).get('/api/home/following?organizationId=org-1')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ programs: [] })
    expect(getHomeFollowing).toHaveBeenCalledWith(SCOPE, 'u1', expect.any(Date))
  })

  it('401s without auth and 404s an empty scope', async () => {
    expect((await request(appAs()).get('/api/home/following')).status).toBe(401)
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    expect((await request(appAs('u1')).get('/api/home/following')).status).toBe(404)
  })
})

describe('mounting', () => {
  let app: Awaited<typeof import('../../index.js')>['app']
  beforeAll(async () => {
    process.env.MICROSOFT_CLIENT_ID = 'test-microsoft-client-id'
    process.env.MICROSOFT_TENANT_ID = 'test-tenant-id'
    ;({ app } = await import('../../index.js'))
  })

  it('serves /api/home behind requireAuth', async () => {
    const res = await request(app).get('/api/home/engagement').set('User-Agent', 'Mozilla/5.0 MakeReadyTest')
    expect(res.status).toBe(401)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/home.test.ts` → FAIL: `Failed to load url ../home.js`.

- [ ] **Step 3: Export the timezone check** — `server/src/services/analytics.service.ts:431`: change `function assertValidTimezone(tz: string): void {` to `export function assertValidTimezone(tz: string): void {` (body unchanged).

- [ ] **Step 4: Write the route module** — create `server/src/routes/home.ts`

```ts
/**
 * Home dashboard routes (docs/features/home-dashboard-data/SPEC.md §Contract) —
 * the iPhone UI 2.0 Home's per-member computations, beside the frozen
 * /api/analytics/query contract (D5). Thin: logic lives in services/home-*.ts.
 *
 *   GET /api/home/sessions?range=&tz=&organizationId=
 *   GET /api/home/days?from=&to=&tz=&organizationId=
 *   GET /api/home/engagement?tz=&organizationId=
 *   GET /api/home/following?organizationId=
 *
 * Scope = the analytics scope (D9), narrowed by organizationId; an empty scope
 * reads as 404, as analytics does.
 */
import { Router, type Request, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import { AnalyticsQueryError, assertValidTimezone, type AnalyticsScope } from '../services/analytics.service.js'
import { deriveAnalyticsScope, isEmptyScope } from '../services/analytics-scope.js'
import { getHomeDays, getHomeEngagement, getHomeSessions, validateDayRange } from '../services/home-dashboard.js'
import { getHomeFollowing } from '../services/home-following.js'

const router = Router()

const organizationId = z.string().min(1).max(64).optional()
const tz = z.string().min(1).max(64).default('UTC')
const sessionsQuery = z.object({ range: z.enum(['all', 'year', 'month', 'week']), tz, organizationId })
const daysQuery = z.object({ from: z.string().max(10), to: z.string().max(10), tz, organizationId })
const engagementQuery = z.object({ tz, organizationId })
const followingQuery = z.object({ organizationId })

const callerOf = (req: Request) => ({
  userId: (req.user as { id?: string } | undefined)?.id,
  apiKeyId: req.apiKeyId,
})

/** The D9 scope, or null after answering 401 / 404. */
async function scopeOrRespond(req: Request, res: Response, orgId: string | undefined): Promise<AnalyticsScope | null> {
  const scope = await deriveAnalyticsScope(callerOf(req), { organizationId: orgId })
  if (!scope) {
    res.status(401).json({ success: false, error: 'Not authenticated' })
    return null
  }
  if (isEmptyScope(scope)) {
    res.status(404).json({ success: false, error: 'Not found' })
    return null
  }
  return scope
}

function invalid(res: Response, error: z.ZodError) {
  return res.status(400).json({ success: false, error: 'Invalid query', details: error.errors })
}

function failed(res: Response, error: unknown, what: string) {
  if (error instanceof AnalyticsQueryError) {
    return res.status(error.status).json({ success: false, error: error.message })
  }
  console.error(`Error loading home ${what}:`, error)
  return res.status(500).json({ success: false, error: `Failed to load home ${what}` })
}

/**
 * @openapi
 * /api/home/sessions:
 *   get:
 *     tags: [Home]
 *     summary: Session stats for the UI 2.0 Home Sessions card (iPhone)
 *     parameters:
 *       - { in: query, name: range, required: true, schema: { type: string, enum: [all, year, month, week] } }
 *       - { in: query, name: tz, schema: { type: string, example: America/Chicago } }
 *       - { in: query, name: organizationId, schema: { type: string } }
 *     responses:
 *       200: { description: "{ averageSeconds, sessionCount, hourly[24], bins[88], ticks[4] }" }
 *       400: { description: Bad range or timezone }
 *       404: { description: Empty scope }
 */
router.get('/sessions', requireAuth, async (req, res) => {
  try {
    const parsed = sessionsQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    assertValidTimezone(parsed.data.tz)
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    res.json(await getHomeSessions(scope, parsed.data.range, parsed.data.tz, new Date()))
  } catch (error) {
    failed(res, error, 'sessions')
  }
})

/**
 * @openapi
 * /api/home/days:
 *   get:
 *     tags: [Home]
 *     summary: Per-day session seconds and 12 two-hour blocks for the Home day cards (iPhone)
 *     parameters:
 *       - { in: query, name: from, required: true, schema: { type: string, example: "2026-09-27" } }
 *       - { in: query, name: to, required: true, schema: { type: string, example: "2026-11-01" } }
 *       - { in: query, name: tz, schema: { type: string } }
 *       - { in: query, name: organizationId, schema: { type: string } }
 *     responses:
 *       200: { description: "{ days: [{ day, sessionSeconds, blocks[12] }] } — every day, zero-filled" }
 *       400: { description: Bad dates, more than 62 days, or bad timezone }
 *       404: { description: Empty scope }
 */
router.get('/days', requireAuth, async (req, res) => {
  try {
    const parsed = daysQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    const rangeError = validateDayRange(parsed.data.from, parsed.data.to)
    if (rangeError) return res.status(400).json({ success: false, error: rangeError })
    assertValidTimezone(parsed.data.tz)
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    res.json(await getHomeDays(scope, parsed.data.from, parsed.data.to, parsed.data.tz))
  } catch (error) {
    failed(res, error, 'days')
  }
})

/**
 * @openapi
 * /api/home/engagement:
 *   get:
 *     tags: [Home]
 *     summary: Caught-up and active member counts for the Home Engagement card (iPhone)
 *     parameters:
 *       - { in: query, name: tz, schema: { type: string } }
 *       - { in: query, name: organizationId, schema: { type: string } }
 *     responses:
 *       200: { description: "{ currentCount, enrolledCount, groupCount, percent, activeCount }" }
 *       400: { description: Bad timezone }
 *       404: { description: Empty scope }
 */
router.get('/engagement', requireAuth, async (req, res) => {
  try {
    const parsed = engagementQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    assertValidTimezone(parsed.data.tz)
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    res.json(await getHomeEngagement(scope, parsed.data.tz, new Date()))
  } catch (error) {
    failed(res, error, 'engagement')
  }
})

/**
 * @openapi
 * /api/home/following:
 *   get:
 *     tags: [Home]
 *     summary: The caller's followed enrollments (preference dashboard.followedEnrollments), grouped by program (iPhone)
 *     parameters:
 *       - { in: query, name: organizationId, schema: { type: string } }
 *     responses:
 *       200: { description: "{ programs: [{ id, title, author, createdAt, groups: [{ enrollmentId, groupName, photoUrl, memberCount, percent, synced }] }] }" }
 *       404: { description: Empty scope }
 */
router.get('/following', requireAuth, async (req, res) => {
  try {
    const parsed = followingQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    const userId = callerOf(req).userId
    if (!userId) return res.status(401).json({ success: false, error: 'Not authenticated' })
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    res.json(await getHomeFollowing(scope, userId, new Date()))
  } catch (error) {
    failed(res, error, 'following')
  }
})

export default router
```

- [ ] **Step 5: Mount it** — `server/src/index.ts`: after `import programAnalyticsRoutes from './routes/program-analytics.js'` (`:41`) add

```ts
import homeRoutes from './routes/home.js'
```

and after `app.use('/api', programAnalyticsRoutes)` (`:484`) add

```ts

// UI 2.0 Home dashboard (iPhone): sessions, day minutes, engagement, following
app.use('/api/home', homeRoutes)
```

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/routes/__tests__/home.test.ts` → PASS; `cd server && npx tsc --noEmit && npm run test:run` → PASS. Then `docker restart makeready-server` (it does not pick up host edits) and smoke it: `curl -s -o /dev/null -w '%{http_code}\n' -A 'Mozilla/5.0' 'http://localhost:3010/api/home/engagement'` → `401`.

- [ ] **Step 7: Commit** — `feat(home-dashboard-data): /api/home sessions, days, engagement and following routes`

### Task 7: Fixtures — every Home section populated, then freeze the contract
App: server
Phase: 3
Recipe: server/.claude/CLAUDE.md §Local Development Setup — and read `server/fixtures/README.md` in full first (layer rules, fixed IDs, `ctx` helpers)

**Files:**
- Modify: `server/fixtures/screens/home-dashboard.ts` (whole file — the construction is re-derived per D17)
- Modify: `server/fixtures/ids.ts:9-26` (add kind `userPreference: '0011'`)
- Modify: `server/fixtures/__tests__/home-dashboard.test.ts` (whole file — the old `dailyCompletionCounts` construction is gone)
- Modify: `server/fixtures/__tests__/home-dashboard.db.test.ts` (whole file — updated Overview expectations + the D1 assertions)
- Modify: `server/fixtures/README.md` (Fixed IDs kinds + a coverage note)

**Interfaces:**
- Consumes: `getHomeSessions`, `getHomeDays`, `getHomeEngagement` (Task 4, `src/services/home-dashboard.ts`); `getHomeFollowing`, `FOLLOWED_ENROLLMENTS_KEY` (Task 5, `src/services/home-following.ts`); `loadSessions` (Task 3); `scheduled_lessons` (Task 1); `runAnalyticsQuery`, `todayInTimezone` (`src/services/analytics.service.ts`); base fixtures (`fixtures/base.ts`: 24 members, 8 per group in 3 groups; enrollments E1 g0 days30 −48…−19, E2 g1 days30 −29…0, E3 g2 days21 −20…0, E4 g0 days21 −13…+7; schedules at Chicago noon).
- Produces: from `server/fixtures/screens/home-dashboard.ts` — `behindBy(memberIndex: number): number`, `CAUGHT_UP_INDICES`, `SITTING_MIN_MINUTES = 5`, `SITTING_MAX_MINUTES = 40`, `DAY_PARTS`, `FOLLOWED_ENROLLMENTS_PREFERENCE`, `FOLLOWED_ENROLLMENT_IDS`, `VIDEO_TOTAL_SECONDS`, `apportion` (unchanged); `FIXTURE_KIND.userPreference = '0011'`.

The re-derived construction (D12, D17): every member completes each of their group's due lessons ON its scheduled Chicago day, except that the 14 members not in `CAUGHT_UP_INDICES` stop 1–5 lessons short (`behindBy`), so 10 of 24 are caught up → D3 percent 42 (the D7 yellow band). Completions: 8·43 + 8·29 + 8·20 − 40 = 696 before today, plus one per caught-up member today when the clock allows. The previous Overview window (−47…−24) holds 240 of them and the current one (−23…0) ~448+, so the trend is positive by construction (no longer pinned at +15%). Each completion is one sitting of 5–40 min: `LESSON_OPENED` at t, video `startedAt` at t + 10%, `lastWatchedAt` at t + 60%, `completedAt` at t + 100% (gaps ≤ 20 min, so one D2 session), opened in a morning (07:00–09:30), midday (11:30–13:30) or evening (18:00–20:18) band so every moment stays in 07:00–21:00 Chicago. Today's sittings (D1 covers today's day card) end ≥ 5 min before `ctx.now` and are skipped before ~07:15 Chicago — a reset run before then leaves today's card empty. The preference row is fixed-ID kind `0011`, value `JSON.stringify` of enrollments 2, 3, 4 (two programs: Walking Through John ×1, Foundations of Faith ×2); it cascades with the fixture user, so `wipe.ts` needs nothing.

- [ ] **Step 1: Write the failing unit test** — replace `server/fixtures/__tests__/home-dashboard.test.ts` with

```ts
import { describe, expect, it } from 'vitest'
import { FIXTURES_DIR, availableScenarios, loadLayers } from '../runner.js'
import {
  DAY_PARTS,
  FOLLOWED_ENROLLMENT_IDS,
  SITTING_MAX_MINUTES,
  apportion,
  behindBy,
} from '../screens/home-dashboard.js'
import { FIXTURE_ENROLLMENT_IDS } from '../ids.js'

describe('apportion', () => {
  it('splits a total exactly, at least one per slot, within caps', () => {
    const out = apportion(100, [1, 2, 3, 4], [50, 50, 50, 20])
    expect(out.reduce((a, b) => a + b, 0)).toBe(100)
    expect(out[3]).toBeLessThanOrEqual(20)
    for (const n of out) expect(n).toBeGreaterThanOrEqual(1)
  })

  it('throws when the caps cannot hold the total', () => {
    expect(() => apportion(10, [1, 1], [3, 3])).toThrow('capacity')
  })
})

describe('behindBy (home-dashboard-data D12, D17)', () => {
  const indices = Array.from({ length: 24 }, (_, i) => i)

  it('keeps 10 of 24 members caught up — 42%, the D7 yellow band', () => {
    const caughtUp = indices.filter((i) => behindBy(i) === 0)
    expect(caughtUp).toHaveLength(10)
    expect(Math.round((caughtUp.length / 24) * 100)).toBe(42)
  })

  it('puts every other member 1–5 lessons behind', () => {
    for (const i of indices.filter((n) => behindBy(n) !== 0)) {
      expect(behindBy(i)).toBeGreaterThanOrEqual(1)
      expect(behindBy(i)).toBeLessThanOrEqual(5)
    }
  })

  it('has caught-up members in each of the three groups', () => {
    for (const g of [0, 1, 2]) {
      expect(indices.slice(g * 8, g * 8 + 8).some((i) => behindBy(i) === 0)).toBe(true)
    }
  })
})

describe('sittings stay in the 07:00–21:00 band (D11 of ui2-fixtures)', () => {
  it('opens no earlier than 07:00 and finishes by 21:00 even at the longest length', () => {
    for (const part of DAY_PARTS) {
      expect(part.start).toBeGreaterThanOrEqual(7)
      expect(part.end + SITTING_MAX_MINUTES / 60).toBeLessThanOrEqual(21)
    }
  })
})

describe('followed enrollments (D12)', () => {
  it('follows enrollments 2, 3 and 4', () => {
    expect(FOLLOWED_ENROLLMENT_IDS).toEqual([FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]])
  })
})

describe('layer discovery (D2, D6)', () => {
  it('finds base plus the home-dashboard layer, which offers full only', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual(['home-dashboard'])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'empty'])
  })
})
```

- [ ] **Step 2: Write the failing DB test** — replace `server/fixtures/__tests__/home-dashboard.db.test.ts` with (tests (b) and (d) keep their meaning with D17's updated numbers; (f) is new)

```ts
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const total = (rows: Record<string, unknown>[] | undefined, key: string) =>
  (rows ?? []).reduce((s, r) => s + Number(r[key] ?? 0), 0)
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
const chicagoHour = (d: Date) =>
  Number(new Intl.DateTimeFormat('en-US', { timeZone: TZ, hour: 'numeric', hourCycle: 'h23' }).format(d)) % 24

describe.skipIf(!TEST_DB_URL)('home-dashboard layer against the test database (D18)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
  }, 60_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('(b) reset full twice gives identical row counts', async () => {
    const first = await db.run('reset', 'full')
    const second = await db.run('reset', 'full')
    expect(second).toEqual(first)
    expect(first.member_lesson_progress).toBeGreaterThanOrEqual(696)
    expect(first.member_video_progress).toBe(first.member_lesson_progress)
    expect(first.client_events).toBe(first.member_lesson_progress)
    expect(first.membership_events).toBe(24)
  }, 180_000)

  it('(d) Home reads ≥ 18 non-empty days, a positive trend, and 40 h (±2 h) of video', async () => {
    const before = Date.now()
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const today = todayInTimezone(TZ)

    // Home's Overview query (DashboardActions.swift: from today−23 to today, compareToPrevious).
    const series = await runAnalyticsQuery(
      {
        metrics: ['lesson_completions'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -23), to: today },
        timezone: TZ,
        compareToPrevious: true,
      },
      scope
    )
    expect(series.rows).toHaveLength(24)
    const nonEmpty = series.rows.filter((r) => Number(r.lesson_completions) > 0).length
    expect(nonEmpty).toBeGreaterThanOrEqual(18)
    const current = total(series.rows, 'lesson_completions')
    const previous = total(series.previousRows, 'lesson_completions')
    expect(previous).toBe(240) // D17: E1 −47…−24 (8 × 24) + E2 −29…−24 (8 × 6), every member done
    expect(current).toBeGreaterThan(previous)

    // watch_seconds is a snapshot metric: no range (the service 400s on one), as Home queries it.
    const watch = await runAnalyticsQuery(
      { metrics: ['watch_seconds'], dimensions: [], filters: { organizationId: FIXTURE_ORG_ID }, timezone: TZ },
      scope
    )
    const seconds = Number(watch.rows[0]?.watch_seconds)
    expect(seconds).toBeGreaterThanOrEqual(144_000 - 7_200)
    expect(seconds).toBeLessThanOrEqual(144_000 + 7_200)

    // F15: the explicit lastWatchedAt survived @updatedAt — every watch ends ≥ 5 min before the run.
    const watched = await db.prisma.memberVideoProgress.aggregate({
      where: { memberId: { in: FIXTURE_MEMBER_IDS } },
      _max: { lastWatchedAt: true },
    })
    expect(watched._max.lastWatchedAt).not.toBeNull()
    expect(watched._max.lastWatchedAt!.getTime()).toBeLessThan(before - 60_000)

    // D11: completions, watches and opens all sit in the 07:00–21:00 Chicago band.
    const progress = await db.prisma.memberLessonProgress.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    for (const p of progress) {
      const date = localDate(p.completedAt!)
      expect(p.completedAt!.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(p.completedAt!.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
      expect(p.pinnedVersionId).toBeNull()
    }
    const opens = await db.prisma.clientEvent.findMany({ where: { organizationId: FIXTURE_ORG_ID } })
    for (const e of opens) {
      expect(e.eventType).toBe('LESSON_OPENED')
      const date = localDate(e.occurredAt)
      expect(e.occurredAt.getTime()).toBeGreaterThanOrEqual(zonedTime(date, 7).getTime())
      expect(e.occurredAt.getTime()).toBeLessThanOrEqual(zonedTime(date, 21).getTime())
    }
    const joins = await db.prisma.membershipEvent.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
    expect(joins).toHaveLength(24)
    for (const j of joins) {
      expect(j.action).toBe('ADDED')
      expect(j.organizationId).toBe(FIXTURE_ORG_ID)
    }
  }, 180_000)

  it('(f) every D1 field source is non-zero after full (home-dashboard-data D1, D12, D17)', async () => {
    const before = Date.now()
    await db.run('reset', 'full')
    const { runAnalyticsQuery, todayInTimezone } = await import('../../src/services/analytics.service.js')
    const { getHomeDays, getHomeEngagement, getHomeSessions } = await import('../../src/services/home-dashboard.js')
    const { FOLLOWED_ENROLLMENTS_KEY, getHomeFollowing } = await import('../../src/services/home-following.js')
    const { loadSessions } = await import('../../src/services/home-sessions.js')
    const today = todayInTimezone(TZ)
    // The layer places today's sittings only when ≥ 10 min fit between 07:00 and now − 5 min.
    const todayHasSittings = before - 5 * 60_000 - zonedTime(today, 7).getTime() >= 10 * 60_000

    // Activity: scheduled column over the chart's 36 days (today − 28 … today + 7).
    const scheduled = await runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -28), to: addDays(today, 7) },
        timezone: TZ,
      },
      scope
    )
    expect(scheduled.rows).toHaveLength(36)
    for (const r of scheduled.rows) expect(Number(r.scheduled_lessons)).toBeGreaterThan(0)

    // Activity + day cards: completed per day and session minutes/blocks for the past 7 days.
    const completed = await runAnalyticsQuery(
      {
        metrics: ['lesson_completions'],
        dimensions: ['day'],
        filters: { organizationId: FIXTURE_ORG_ID, from: addDays(today, -6), to: today },
        timezone: TZ,
      },
      scope
    )
    const { days } = await getHomeDays(scope, addDays(today, -6), today, TZ)
    expect(days).toHaveLength(7)
    days.forEach((d, i) => {
      expect(d.blocks).toHaveLength(12)
      expect(d.blocks.reduce((a, b) => a + b, 0)).toBe(d.sessionSeconds)
      if (i < 6 || todayHasSittings) {
        expect(d.sessionSeconds).toBeGreaterThan(0)
        expect(d.blocks.some((b) => b > 0)).toBe(true)
        expect(Number(completed.rows[i].lesson_completions)).toBeGreaterThan(0)
      }
    })

    // Sessions: every range maps (D13), each non-empty.
    for (const range of ['all', 'year', 'month', 'week'] as const) {
      const s = await getHomeSessions(scope, range, TZ, new Date())
      expect(s.sessionCount).toBeGreaterThan(0)
      expect(s.averageSeconds).toBeGreaterThanOrEqual(5 * 60)
      expect(s.averageSeconds).toBeLessThanOrEqual(40 * 60)
      expect(s.hourly).toHaveLength(24)
      expect(s.hourly.some((v) => v > 0)).toBe(true)
      expect(s.bins).toHaveLength(88)
      expect(Math.max(...s.bins)).toBe(1)
      expect(s.ticks).toHaveLength(4)
    }

    // D12: sittings last 5–40 min, across morning, midday and evening.
    const now = new Date()
    const sessions = await loadSessions(scope, { from: new Date(now.getTime() - 60 * 86_400_000), to: now })
    for (const s of sessions) {
      expect(s.seconds).toBeGreaterThanOrEqual(5 * 60)
      expect(s.seconds).toBeLessThanOrEqual(40 * 60)
    }
    const hours = sessions.map((s) => chicagoHour(s.start))
    expect(hours.some((h) => h < 10)).toBe(true)
    expect(hours.some((h) => h >= 11 && h < 14)).toBe(true)
    expect(hours.some((h) => h >= 18)).toBe(true)

    // Engagement (D3, D15, D17): 10 of 24 caught up across 3 groups.
    const engagement = await getHomeEngagement(scope, TZ, new Date())
    expect(engagement).toMatchObject({ currentCount: 10, enrolledCount: 24, groupCount: 3, percent: 42 })
    expect(engagement.activeCount).toBeGreaterThan(0)

    // Following (D4, D11, D12): 3 enrollments across 2 programs, from a JSON-encoded string.
    const pref = await db.prisma.userPreference.findUnique({
      where: { userId_key: { userId: FIXTURE_USER_ID, key: FOLLOWED_ENROLLMENTS_KEY } },
    })
    expect(JSON.parse(pref!.value)).toEqual([FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]])
    const following = await getHomeFollowing(scope, FIXTURE_USER_ID, new Date())
    expect(following.programs.map((p) => p.title)).toEqual(['Foundations of Faith', 'Walking Through John'])
    expect(following.programs.map((p) => p.groups.map((g) => g.groupName))).toEqual([
      ["Tuesday Men's Group", "Women's Bible Study"],
      ['Young Adults'],
    ])
    expect(following.programs[0].author).toBe('Fixture Leader')
    for (const g of following.programs.flatMap((p) => p.groups)) {
      expect(g.memberCount).toBe(8)
      expect(g.percent).toBeGreaterThan(0)
    }
  }, 180_000)
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run fixtures/__tests__/home-dashboard.test.ts` → FAIL: `does not provide an export named 'behindBy'` (and `DAY_PARTS`, `FOLLOWED_ENROLLMENT_IDS`). With a test DB: `cd server && FIXTURES_TEST_DATABASE_URL=… npx vitest run fixtures/__tests__/home-dashboard.db.test.ts` → FAIL on (b) `≥ 696` (today ~240) and (f) (no preference row, engagement 0 current). Without the variable the DB suite prints the skip line.

- [ ] **Step 4: Add the fixed-ID kind** — `server/fixtures/ids.ts`, in `FIXTURE_KIND` after `memberOrganization: '0010',` (`:25`):

```ts
  userPreference: '0011',
```

- [ ] **Step 5: Re-derive the layer** — replace `server/fixtures/screens/home-dashboard.ts` with

```ts
/**
 * home-dashboard layer (SPEC ui2-fixtures D1, D9, D11; home-dashboard-data D1, D12, D17): fills
 * every number Home reads — Overview's sparkline and trend, total video time, Activity's
 * scheduled/completed columns and day cards, Sessions, Engagement and Following. `full` only.
 *
 * Construction (D17): every member completes each of their group's due lessons ON its scheduled
 * Chicago day, except that the 14 members outside CAUGHT_UP_INDICES stop 1–5 lessons short of
 * today — 10 of 24 caught up (D3 → 42%, the D7 yellow band). The previous 24-day Overview window
 * holds only the early enrollments, so the current window is larger (a positive trend). Each
 * completion is one sitting, 5–40 min: LESSON_OPENED → video start (+10%) → last watch (+60%) →
 * completion (+100%), opened in a morning, midday or evening band inside 07:00–21:00 Chicago.
 * Caught-up members also finish today's lesson in a sitting ending ≥ 5 min before ctx.now (skipped
 * before ~07:15 Chicago). Video seconds are apportioned to exactly 40 h. The fixture user follows
 * enrollments 2–4 through the `dashboard.followedEnrollments` preference (D4, D12).
 */
import type { LessonSchedule } from '../../src/generated/prisma/index.js'
import { VIDEO_SECONDS } from '../base.js'
import { type FixtureContext, FixtureError, localDate, zonedTime } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const VIDEO_TOTAL_SECONDS = 40 * 3600
/** Member indices (into FIXTURE_MEMBER_IDS) who are caught up: 5 + 3 + 2 across the three groups. */
export const CAUGHT_UP_INDICES: ReadonlySet<number> = new Set([0, 1, 2, 3, 4, 8, 9, 10, 16, 17])
export const SITTING_MIN_MINUTES = 5
export const SITTING_MAX_MINUTES = 40
/** Opening-hour bands (Chicago). The latest open + the longest sitting ends by 21:00. */
export const DAY_PARTS = [
  { start: 7, end: 9.5 },
  { start: 11.5, end: 13.5 },
  { start: 18, end: 20.3 },
] as const
export const FOLLOWED_ENROLLMENTS_PREFERENCE = 'dashboard.followedEnrollments'
/** Enrollments 2, 3, 4: Walking Through John (Young Adults) + Foundations of Faith (Women's, Tuesday Men's). */
export const FOLLOWED_ENROLLMENT_IDS = [FIXTURE_ENROLLMENT_IDS[1], FIXTURE_ENROLLMENT_IDS[2], FIXTURE_ENROLLMENT_IDS[3]]
const TODAY_MARGIN_MS = 5 * 60_000
const TODAY_MIN_WINDOW_MS = 10 * 60_000

/** How many due lessons a member leaves undone: 0 when caught up, else 1–5. */
export function behindBy(memberIndex: number): number {
  return CAUGHT_UP_INDICES.has(memberIndex) ? 0 : 1 + (memberIndex % 5)
}

/** Largest-remainder apportionment of `total`: at least one per slot (cap permitting), never above its cap. */
export function apportion(total: number, weights: readonly number[], caps: readonly number[]): number[] {
  const out = caps.map((cap) => Math.min(1, cap))
  let remaining = total - out.reduce((s, n) => s + n, 0)
  if (remaining < 0) throw new FixtureError(`apportion: ${total} is less than one per slot`)
  while (remaining > 0) {
    const open = out.map((_, i) => i).filter((i) => out[i] < caps[i])
    if (open.length === 0) throw new FixtureError(`apportion: capacity exhausted with ${remaining} left`)
    const weightSum = open.reduce((s, i) => s + weights[i], 0)
    const shares = open.map((i) => ({
      i,
      exact: weightSum > 0 ? (remaining * weights[i]) / weightSum : remaining / open.length,
    }))
    let given = 0
    for (const s of shares) {
      const add = Math.min(Math.floor(s.exact), caps[s.i] - out[s.i])
      out[s.i] += add
      given += add
    }
    let left = remaining - given
    const byRemainder = shares
      .slice()
      .sort((a, b) => b.exact - Math.floor(b.exact) - (a.exact - Math.floor(a.exact)) || a.i - b.i)
    for (const s of byRemainder) {
      if (left === 0) break
      if (out[s.i] < caps[s.i]) {
        out[s.i] += 1
        left -= 1
      }
    }
    remaining = left
  }
  return out
}

interface Pair {
  memberId: string
  groupId: string
  enrollmentId: string
  studyProgramId: string
  schedule: LessonSchedule
}

interface Sitting {
  pair: Pair
  openedAt: Date
  minutes: number
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx

  // Every member's lessons (member × schedule pairs), oldest first.
  const enrollmentById = new Map(created.enrollments.map((e) => [e.id, e]))
  const pairsByMember = new Map<string, Pair[]>()
  for (const schedule of created.schedules) {
    const enrollment = enrollmentById.get(schedule.enrollmentId)
    if (!enrollment) throw new FixtureError(`schedule ${schedule.id} has no base enrollment`)
    for (const gm of created.groupMembers) {
      if (gm.groupId !== enrollment.groupId || !gm.memberId) continue
      const list = pairsByMember.get(gm.memberId) ?? []
      list.push({
        memberId: gm.memberId,
        groupId: enrollment.groupId,
        enrollmentId: enrollment.id,
        studyProgramId: enrollment.studyProgramId,
        schedule,
      })
      pairsByMember.set(gm.memberId, list)
    }
  }

  const sittingMinutes = () => SITTING_MIN_MINUTES + (SITTING_MAX_MINUTES - SITTING_MIN_MINUTES) * ctx.rand.next()
  const todayStart = ctx.at(0, 7).getTime()
  const todayEnd = Math.min(ctx.at(0, 21).getTime(), ctx.now.getTime() - TODAY_MARGIN_MS)

  const sittings: Sitting[] = []
  FIXTURE_MEMBER_IDS.forEach((memberId, index) => {
    const pairs = (pairsByMember.get(memberId) ?? [])
      .slice()
      .sort((a, b) => a.schedule.scheduledDate.getTime() - b.schedule.scheduledDate.getTime())
    const due = pairs.filter((p) => localDate(p.schedule.scheduledDate) < ctx.today)
    for (const pair of due.slice(0, Math.max(0, due.length - behindBy(index)))) {
      const date = localDate(pair.schedule.scheduledDate)
      const part = DAY_PARTS[ctx.rand.int(0, DAY_PARTS.length - 1)]
      const openedHour = part.start + (part.end - part.start) * ctx.rand.next()
      sittings.push({ pair, openedAt: zonedTime(date, openedHour), minutes: sittingMinutes() })
    }
    // D1: today's day card — caught-up members also finish today's lesson, before ctx.now.
    const todays = pairs.find((p) => localDate(p.schedule.scheduledDate) === ctx.today)
    if (behindBy(index) === 0 && todays && todayEnd - todayStart >= TODAY_MIN_WINDOW_MS) {
      const minutes = Math.min(sittingMinutes(), (todayEnd - todayStart) / 60_000)
      const openedAt = new Date(todayStart + (todayEnd - todayStart - minutes * 60_000) * ctx.rand.next())
      sittings.push({ pair: todays, openedAt, minutes })
    }
  })

  const along = (s: Sitting, fraction: number) => new Date(s.openedAt.getTime() + Math.round(s.minutes * 60_000 * fraction))

  const watched = apportion(
    VIDEO_TOTAL_SECONDS,
    sittings.map(() => 0.7 + 0.3 * ctx.rand.next()),
    sittings.map(() => VIDEO_SECONDS)
  )

  const lessonById = new Map(created.lessons.map((l) => [l.id, l]))
  const videoActivityByLesson = new Map(
    created.activities.filter((a) => a.activityType === 'VIDEO').map((a) => [a.lessonId, a.id])
  )

  await prisma.memberLessonProgress.createMany({
    data: sittings.map((s, i) => ({
      id: fixtureId('lessonProgress', i + 1),
      memberId: s.pair.memberId,
      lessonScheduleId: s.pair.schedule.id,
      startedAt: s.openedAt,
      completedAt: along(s, 1),
      lastUpdatedAt: along(s, 1),
    })),
  })

  await prisma.memberVideoProgress.createMany({
    data: sittings.map((s, i) => {
      const lessonId = s.pair.schedule.lessonId
      const lessonActivityId = lessonId ? videoActivityByLesson.get(lessonId) : undefined
      if (!lessonActivityId) throw new FixtureError(`schedule ${s.pair.schedule.id} has no VIDEO activity`)
      return {
        id: fixtureId('videoProgress', i + 1),
        memberId: s.pair.memberId,
        lessonScheduleId: s.pair.schedule.id,
        lessonActivityId,
        watchedSeconds: watched[i],
        totalDuration: VIDEO_SECONDS,
        watchPercentage: Math.round((watched[i] / VIDEO_SECONDS) * 1000) / 10,
        startedAt: along(s, 0.1),
        lastWatchedAt: along(s, 0.6),
        completedAt: null,
      }
    }),
  })

  await prisma.clientEvent.createMany({
    data: sittings.map((s, i) => {
      const lesson = s.pair.schedule.lessonId ? lessonById.get(s.pair.schedule.lessonId) : undefined
      return {
        id: fixtureId('clientEvent', i + 1),
        eventType: 'LESSON_OPENED',
        occurredAt: s.openedAt,
        receivedAt: s.openedAt,
        memberId: s.pair.memberId,
        organizationId: FIXTURE_ORG_ID,
        groupId: s.pair.groupId,
        enrollmentId: s.pair.enrollmentId,
        studyProgramId: s.pair.studyProgramId,
        lessonScheduleId: s.pair.schedule.id,
        lessonId: s.pair.schedule.lessonId,
        dayNumber: lesson?.dayNumber ?? null,
        scheduledDate: s.pair.schedule.scheduledDate,
      }
    }),
  })

  await prisma.membershipEvent.createMany({
    data: created.groupMembers.map((gm, i) => {
      if (!gm.memberId) throw new FixtureError(`group member ${gm.id} has no member`)
      return {
        id: fixtureId('membershipEvent', i + 1),
        memberId: gm.memberId,
        groupId: gm.groupId,
        organizationId: FIXTURE_ORG_ID,
        action: 'ADDED' as const,
        actorId: FIXTURE_USER_ID,
        actorType: 'user',
        createdAt: gm.joinedAt,
      }
    }),
  })

  // D4/D12: the preference column is a string — store the JSON-encoded id array.
  await prisma.userPreference.create({
    data: {
      id: fixtureId('userPreference', 1),
      userId: FIXTURE_USER_ID,
      key: FOLLOWED_ENROLLMENTS_PREFERENCE,
      value: JSON.stringify(FOLLOWED_ENROLLMENT_IDS),
      createdAt: ctx.now,
    },
  })
}
```

- [ ] **Step 6: Note the coverage in the README** — `server/fixtures/README.md`: in **Fixed IDs**, change `` `0010` member
orgs. `` to `` `0010` member orgs, `0011` user preferences. ``; and after the `## Scenarios` paragraph add:

```markdown
### What `full` makes non-empty on Home

`screens/home-dashboard.ts` (home-dashboard-data D1, D12, D17): Overview (~700 completions, the
current 24 days above the previous 24), Activity's scheduled and completed columns, every day card
for the past 7 days (5–40 min sittings in morning, midday and evening bands; today's only after
~07:15 Chicago), Sessions for every range, Engagement (10 of 24 members caught up → 42%, the rest
1–5 lessons behind) and Following (the fixture user's `dashboard.followedEnrollments` preference =
enrollments 2–4, two programs). The preference row cascades with the fixture user.
```

- [ ] **Step 7: Run the tests and watch them pass** — `cd server && npx vitest run fixtures/__tests__/home-dashboard.test.ts` → PASS; `cd server && npx tsc --noEmit -p fixtures && npx tsc --noEmit` → PASS; with a test DB `cd server && FIXTURES_TEST_DATABASE_URL=… npx vitest run fixtures/__tests__/` → PASS (home-dashboard.db (b)(d)(f), scheduled-lessons.db, home-sessions.db, base.db). Then `cd server && npm run test:run` → PASS, and on the local DB `docker exec makeready-server npm run fixtures:reset` → exit 0 with the row-count table (member_lesson_progress ≥ 696) — skipped when the build runs with `--no-dev-env`; the walk lane resets fixtures instead.

- [ ] **Step 8: Commit** — `feat(home-dashboard-data): fixtures fill every Home section`

- [ ] **Step 9: Freeze the contract (AFTER the Step 8 commit — the server phase is verified)** — run exactly:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/4.14.8/scripts/advance.mjs docs/features/home-dashboard-data --set "contract=frozen $(date +%F)" --head --commit "docs(home-dashboard-data): contract frozen"
```

### Task 8: DashboardSnapshot grows the /api/home sections (tolerant Codable types)
App: iphone
Phase: 4
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — "Where does this data live?" (the dashboard is an `AppState` property, cached and persisted; `clearAllData` already resets it to `DashboardSnapshot()` at `AppState.swift:809`)
Build-time risk (F11): `DashboardSnapshot` decoding is per-key by hand (`DashboardModels.swift:17-27`), and `PersistedState.swift:298` turns any decode failure into `DashboardSnapshot()` — one new key without a `decodeIfPresent … ?? default`, or one nested type with a synthesized (strict) decoder, drops the WHOLE cached dashboard for every user on upgrade. Every new key and every key of every new nested type below gets a defaulted `decodeIfPresent`; the old-snapshot test in Step 1 is the guard. Do not let Swift synthesize `init(from:)` for any of the new types.

**Files:**
- Modify: `iphone/MakeReady/State/Models/DashboardModels.swift:3-27` (the `DashboardSnapshot` struct + its decoder extension; new types appended after `DashboardPreferenceResponse`)
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift` (decode tests, appended to the class)
- Test: `iphone/MakeReadyCaptureTests/DashboardActionsTests.swift` (one persisted round-trip test, appended to the class)

**Interfaces:**
- Consumes: `AnalyticsQueryResponse` (unchanged — the `scheduled_lessons` rows decode through it; no new type for them), `JSONDecoder.apiDecoder` (`StudyModels.swift:1074`, `.iso8601` dates), `PersistedState(from: AppState)`.
- Produces (all `Codable, Equatable`, every stored property defaulted so the memberwise init takes any subset):
  - `struct HomeSessionsResponse { var averageSeconds: Int; var sessionCount: Int; var hourly: [Double]; var bins: [Double]; var ticks: [String] }` — `GET /api/home/sessions`
  - `struct HomeDay { var day: String; var sessionSeconds: Int; var blocks: [Int] }` and `struct HomeDaysResponse { var days: [HomeDay] }` — `GET /api/home/days`
  - `struct HomeEngagementResponse { var currentCount: Int; var enrolledCount: Int; var groupCount: Int; var percent: Int; var activeCount: Int }` — `GET /api/home/engagement`
  - `struct HomeFollowedGroup { var enrollmentId: String; var groupName: String; var photoUrl: String?; var memberCount: Int; var percent: Int; var synced: Bool }`, `struct HomeFollowedProgram { var id: String; var title: String; var author: String; var createdAt: String; var groups: [HomeFollowedGroup] }`, `struct HomeFollowingResponse { var programs: [HomeFollowedProgram] }` — `GET /api/home/following` (`createdAt` is a `String`, never `Date`: Prisma's fractional seconds fail `.iso8601`, SPEC F5)
  - `DashboardSnapshot` new fields: `scheduledDays: [String: Int]` (yyyy-MM-dd → scheduled_lessons), `dayMinutes: [String: Int]` (yyyy-MM-dd → rounded session minutes), `dayBlocks: [String: [Int]]` (yyyy-MM-dd → 12 two-hour blocks, **seconds**), `sessions: [String: HomeSessionsResponse]` (keys exactly `"all"`, `"year"`, `"month"`, `"week"`), `engagement: HomeEngagementResponse?`, `following: HomeFollowingResponse?` (nil = never fetched).

- [ ] **Step 1: Write the failing tests** — append to `final class HomeDashboardMapperTests` in `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`:

```swift
    // MARK: - Task 8: DashboardSnapshot decoding (SPEC F11)

    private func cacheDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601        // PersistedState's decoder
        return decoder
    }

    /// A snapshot cached by the build before this feature keeps every old field and
    /// defaults every new one — it is never a cache miss.
    func testOldSnapshotWithoutTheNewKeysKeepsItsFields() throws {
        let json = #"{"completedSeries":{"2026-10-24":3},"completedTotal":3,"completedPrevious":2,"watchSeconds":120,"activityDays":{"2026-10-24":3},"kpiNames":["lesson_completions"],"refreshedAt":"2026-10-25T18:00:00Z"}"#
        let s = try cacheDecoder().decode(DashboardSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(s.completedSeries, ["2026-10-24": 3])
        XCTAssertEqual(s.completedTotal, 3)
        XCTAssertEqual(s.completedPrevious, 2)
        XCTAssertEqual(s.watchSeconds, 120)
        XCTAssertEqual(s.activityDays, ["2026-10-24": 3])
        XCTAssertEqual(s.kpiNames, ["lesson_completions"])
        XCTAssertNotNil(s.refreshedAt)
        XCTAssertEqual(s.scheduledDays, [:])
        XCTAssertEqual(s.dayMinutes, [:])
        XCTAssertEqual(s.dayBlocks, [:])
        XCTAssertEqual(s.sessions, [:])
        XCTAssertNil(s.engagement)
        XCTAssertNil(s.following)
    }

    func testNewFieldsRoundTrip() throws {
        var s = DashboardSnapshot()
        s.scheduledDays = ["2026-10-24": 5]
        s.dayMinutes = ["2026-10-24": 26]
        s.dayBlocks = ["2026-10-24": [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0]]
        s.sessions = ["week": HomeSessionsResponse(averageSeconds: 600, sessionCount: 2, hourly: [1, 2],
                                                   bins: [0.5, 1], ticks: ["2026-10-19"])]
        s.engagement = HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9)
        s.following = HomeFollowingResponse(programs: [
            HomeFollowedProgram(id: "p1", title: "Romans in 30 days", author: "", createdAt: "2026-07-08T18:00:00.000Z",
                                groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "The kids", photoUrl: nil,
                                                           memberCount: 2, percent: 13, synced: false)])
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try cacheDecoder().decode(DashboardSnapshot.self, from: try encoder.encode(s))
        XCTAssertEqual(decoded, s)
    }

    /// Every nested type is tolerant too: a missing key inside a cached section defaults
    /// instead of throwing (which would drop the whole dashboard).
    func testNestedTypesDefaultTheirMissingKeys() throws {
        let json = #"{"sessions":{"week":{"averageSeconds":600}},"engagement":{"percent":40},"following":{"programs":[{"title":"Romans","createdAt":"2026-07-08T18:00:00.123Z","groups":[{"groupName":"Kids","photoUrl":null}]}]}}"#
        let s = try cacheDecoder().decode(DashboardSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(s.sessions["week"]?.averageSeconds, 600)
        XCTAssertEqual(s.sessions["week"]?.hourly, [])
        XCTAssertEqual(s.sessions["week"]?.ticks, [])
        XCTAssertEqual(s.engagement?.percent, 40)
        XCTAssertEqual(s.engagement?.currentCount, 0)
        let program = try XCTUnwrap(s.following?.programs.first)
        XCTAssertEqual(program.id, "")
        XCTAssertEqual(program.author, "")
        XCTAssertEqual(program.createdAt, "2026-07-08T18:00:00.123Z")
        XCTAssertEqual(program.groups.first?.groupName, "Kids")
        XCTAssertNil(program.groups.first?.photoUrl)
        XCTAssertEqual(program.groups.first?.memberCount, 0)
        XCTAssertEqual(program.groups.first?.synced, false)
        XCTAssertEqual(s.completedTotal, 0)
    }

    /// The wire shapes of SPEC §Contract decode through the app's API decoder.
    func testHomeResponsesDecodeFromTheContractShapes() throws {
        let following = #"{"programs":[{"id":"p1","title":"Daily inspiration","author":"Scott Stickane","createdAt":"2026-04-13T15:02:11.123Z","groups":[{"enrollmentId":"e1","groupName":"Young professionals","photoUrl":"https://cdn.example/g.jpg","memberCount":9,"percent":55,"synced":true}]}]}"#
        let f = try JSONDecoder.apiDecoder.decode(HomeFollowingResponse.self, from: Data(following.utf8))
        XCTAssertEqual(f.programs.first?.createdAt, "2026-04-13T15:02:11.123Z")
        XCTAssertEqual(f.programs.first?.groups.first?.photoUrl, "https://cdn.example/g.jpg")
        XCTAssertEqual(f.programs.first?.groups.first?.synced, true)

        let days = #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]}]}"#
        let d = try JSONDecoder.apiDecoder.decode(HomeDaysResponse.self, from: Data(days.utf8))
        XCTAssertEqual(d.days, [HomeDay(day: "2026-10-24", sessionSeconds: 1530, blocks: [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0])])

        let engagement = #"{"currentCount":52,"enrolledCount":178,"groupCount":15,"percent":29,"activeCount":15}"#
        let e = try JSONDecoder.apiDecoder.decode(HomeEngagementResponse.self, from: Data(engagement.utf8))
        XCTAssertEqual(e, HomeEngagementResponse(currentCount: 52, enrolledCount: 178, groupCount: 15, percent: 29, activeCount: 15))

        let sessions = #"{"averageSeconds":1920,"sessionCount":40,"hourly":[0,0,0,0,0,0,0,0,0,600.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"bins":[0,0.25,1],"ticks":["2025-10-26","2026-02-23","2026-06-24","2026-10-25"]}"#
        let r = try JSONDecoder.apiDecoder.decode(HomeSessionsResponse.self, from: Data(sessions.utf8))
        XCTAssertEqual(r.averageSeconds, 1920)
        XCTAssertEqual(r.hourly.count, 24)
        XCTAssertEqual(r.hourly[9], 600.5)
        XCTAssertEqual(r.bins, [0, 0.25, 1])
        XCTAssertEqual(r.ticks.count, 4)
    }
```

Append to `final class DashboardActionsTests` in `iphone/MakeReadyCaptureTests/DashboardActionsTests.swift`:

```swift
    /// The new sections persist with the rest of the app snapshot (cache-first, ui2-shell D20).
    func testNewDashboardSectionsPersist() throws {
        state.dashboard.scheduledDays = ["2026-10-24": 5]
        state.dashboard.sessions["all"] = HomeSessionsResponse(averageSeconds: 1920, sessionCount: 4, hourly: [], bins: [], ticks: [])
        state.dashboard.engagement = HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistedState.self, from: try encoder.encode(PersistedState(from: state)))
        XCTAssertEqual(decoded.dashboard, state.dashboard)
    }
```

- [ ] **Step 2: Run it and watch it fail** — from the repo root: `npm run ios:build-check -- --test` → FAIL (test target does not compile): "value of type 'DashboardSnapshot' has no member 'scheduledDays'" and "cannot find 'HomeSessionsResponse' in scope".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReady/State/Models/DashboardModels.swift`, replace the `DashboardSnapshot` struct and its `extension DashboardSnapshot { init(from:) }` (lines 3-27) with:

```swift
/// Home dashboard data cached in `AppState.dashboard` (SPEC D20, D25; home-dashboard-data §iphone).
struct DashboardSnapshot: Codable, Equatable {
    var completedSeries: [String: Int] = [:]      // yyyy-MM-dd → lesson_completions, last 24 days
    var completedTotal: Int = 0
    var completedPrevious: Int?                   // compareToPrevious total
    var watchSeconds: Int?                        // snapshot, lifetime
    var activityDays: [String: Int] = [:]         // yyyy-MM-dd → completions, 28 back + today
    var kpiNames: [String] = ["lesson_completions", "watch_seconds"]
    var refreshedAt: Date?
    // home-dashboard-data (SPEC §iphone)
    var scheduledDays: [String: Int] = [:]        // yyyy-MM-dd → scheduled_lessons, 28 back … 7 ahead (D10)
    var dayMinutes: [String: Int] = [:]           // yyyy-MM-dd → Σ session minutes, rounded (D6)
    var dayBlocks: [String: [Int]] = [:]          // yyyy-MM-dd → 12 two-hour blocks, in SECONDS (D6)
    var sessions: [String: HomeSessionsResponse] = [:]   // "all" | "year" | "month" | "week" (D8, D13)
    var engagement: HomeEngagementResponse?       // nil = never fetched (D3)
    var following: HomeFollowingResponse?         // nil = never fetched (D4, D11)
}

extension DashboardSnapshot {
    /// Tolerant: a key missing from an older snapshot keeps its default, so adding a field
    /// never wipes the cached dashboard (SPEC F11 — every new key below MUST stay defaulted).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let empty = DashboardSnapshot()
        completedSeries = try container.decodeIfPresent([String: Int].self, forKey: .completedSeries) ?? empty.completedSeries
        completedTotal = try container.decodeIfPresent(Int.self, forKey: .completedTotal) ?? empty.completedTotal
        completedPrevious = try container.decodeIfPresent(Int.self, forKey: .completedPrevious)
        watchSeconds = try container.decodeIfPresent(Int.self, forKey: .watchSeconds)
        activityDays = try container.decodeIfPresent([String: Int].self, forKey: .activityDays) ?? empty.activityDays
        kpiNames = try container.decodeIfPresent([String].self, forKey: .kpiNames) ?? empty.kpiNames
        refreshedAt = try container.decodeIfPresent(Date.self, forKey: .refreshedAt)
        scheduledDays = try container.decodeIfPresent([String: Int].self, forKey: .scheduledDays) ?? empty.scheduledDays
        dayMinutes = try container.decodeIfPresent([String: Int].self, forKey: .dayMinutes) ?? empty.dayMinutes
        dayBlocks = try container.decodeIfPresent([String: [Int]].self, forKey: .dayBlocks) ?? empty.dayBlocks
        sessions = try container.decodeIfPresent([String: HomeSessionsResponse].self, forKey: .sessions) ?? empty.sessions
        engagement = try container.decodeIfPresent(HomeEngagementResponse.self, forKey: .engagement)
        following = try container.decodeIfPresent(HomeFollowingResponse.self, forKey: .following)
    }
}
```

Then append to the end of the same file:

```swift
// MARK: - /api/home/* (home-dashboard-data SPEC §Contract — FROZEN shapes)
// Each type doubles as a cached snapshot section, so every key decodes with a default (F11).

/// `GET /api/home/sessions?range=` — one D8 range.
struct HomeSessionsResponse: Codable, Equatable {
    var averageSeconds: Int = 0
    var sessionCount: Int = 0          // unread by the mapper today (§Contract)
    var hourly: [Double] = []          // 24, index 0 = 12 AM, caller tz — mean session seconds per start hour
    var bins: [Double] = []            // 88, normalised 0–1, oldest first
    var ticks: [String] = []           // 4 × yyyy-MM-dd, at bins 0 / 29 / 58 / 87 (D16)
}

extension HomeSessionsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        averageSeconds = try c.decodeIfPresent(Int.self, forKey: .averageSeconds) ?? 0
        sessionCount = try c.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
        hourly = try c.decodeIfPresent([Double].self, forKey: .hourly) ?? []
        bins = try c.decodeIfPresent([Double].self, forKey: .bins) ?? []
        ticks = try c.decodeIfPresent([String].self, forKey: .ticks) ?? []
    }
}

/// One day of `GET /api/home/days` — Σ blocks = sessionSeconds (D6).
struct HomeDay: Codable, Equatable {
    var day: String = ""               // yyyy-MM-dd
    var sessionSeconds: Int = 0
    var blocks: [Int] = []             // 12 two-hour blocks, seconds, index 0 = 12–2 AM
}

extension HomeDay {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
        sessionSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionSeconds) ?? 0
        blocks = try c.decodeIfPresent([Int].self, forKey: .blocks) ?? []
    }
}

/// `GET /api/home/days?from=&to=` — every day in range, zero-filled.
struct HomeDaysResponse: Codable, Equatable {
    var days: [HomeDay] = []
}

extension HomeDaysResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([HomeDay].self, forKey: .days) ?? []
    }
}

/// `GET /api/home/engagement` (D3, D15).
struct HomeEngagementResponse: Codable, Equatable {
    var currentCount: Int = 0
    var enrolledCount: Int = 0
    var groupCount: Int = 0
    var percent: Int = 0
    var activeCount: Int = 0
}

extension HomeEngagementResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentCount = try c.decodeIfPresent(Int.self, forKey: .currentCount) ?? 0
        enrolledCount = try c.decodeIfPresent(Int.self, forKey: .enrolledCount) ?? 0
        groupCount = try c.decodeIfPresent(Int.self, forKey: .groupCount) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        activeCount = try c.decodeIfPresent(Int.self, forKey: .activeCount) ?? 0
    }
}

/// One followed enrollment's group card (D11). `enrollmentId` is unread today (no-op callbacks).
struct HomeFollowedGroup: Codable, Equatable {
    var enrollmentId: String = ""
    var groupName: String = ""
    var photoUrl: String?              // nil → C-038 initials
    var memberCount: Int = 0
    var percent: Int = 0
    var synced: Bool = false
}

extension HomeFollowedGroup {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enrollmentId = try c.decodeIfPresent(String.self, forKey: .enrollmentId) ?? ""
        groupName = try c.decodeIfPresent(String.self, forKey: .groupName) ?? ""
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        synced = try c.decodeIfPresent(Bool.self, forKey: .synced) ?? false
    }
}

/// One followed program (D11). `createdAt` stays an ISO 8601 STRING (SPEC F5).
struct HomeFollowedProgram: Codable, Equatable {
    var id: String = ""
    var title: String = ""
    var author: String = ""
    var createdAt: String = ""
    var groups: [HomeFollowedGroup] = []
}

extension HomeFollowedProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        groups = try c.decodeIfPresent([HomeFollowedGroup].self, forKey: .groups) ?? []
    }
}

/// `GET /api/home/following` — programs by title, groups by name (server-ordered, D11).
struct HomeFollowingResponse: Codable, Equatable {
    var programs: [HomeFollowedProgram] = []
}

extension HomeFollowingResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        programs = try c.decodeIfPresent([HomeFollowedProgram].self, forKey: .programs) ?? []
    }
}
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the five new tests plus every existing `DashboardActionsTests` / `HomeDashboardMapperTests` case, incl. `testDashboardMissingAFieldKeepsTheSnapshot`); then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — iPhone is `commit: manual`: `git add iphone/MakeReady/State/Models/DashboardModels.swift iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift iphone/MakeReadyCaptureTests/DashboardActionsTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(home-dashboard-data): DashboardSnapshot caches the /api/home sections`. Do not run `git commit`.

### Task 9: DashboardActions.refresh() fetches scheduled, days, engagement, following and four session ranges
App: iphone
Phase: 4
Recipe: /ios-error-surface
Build-time risk (§iphone tz encoding): `APIClient.get` takes a raw path string (`APIClient.swift:218`) and `CharacterSet.urlQueryAllowed` KEEPS `+`, so `Etc/GMT+5` would reach Express as `Etc/GMT 5` and 400. The helper below removes `+&=#` from the allowed set; the `queryValue` test pins it.

**Files:**
- Modify: `iphone/MakeReady/State/Actions/DashboardActions.swift:21-56` (`refresh()`), and add helpers in `// MARK: - Helpers` (after `kpiNames()`, ~line 72)
- Test: `iphone/MakeReadyCaptureTests/DashboardActionsTests.swift` (append to the class)

**Interfaces:**
- Consumes (Task 8): `HomeSessionsResponse`, `HomeDaysResponse` / `HomeDay`, `HomeEngagementResponse`, `HomeFollowingResponse`, `DashboardSnapshot.scheduledDays/dayMinutes/dayBlocks/sessions/engagement/following`; existing `AnalyticsQueryResponse`, `query(_:dimension:from:to:compare:)`, `byDay(_:metric:)`, `day(offset:)`, `AuthStatusPolicy.shouldSignOut(after:)`, `AppState.recordError(_:context:surface:)`, `APIClientProtocol.get(_:responseType:)`, `StubAPIClient` (`stub`, `errorFor`, `calls`).
- Produces:
  - `static let sessionRangeKeys: [String] = ["all", "year", "month", "week"]` on `DashboardActions`
  - `static func queryValue(_ value: String) -> String` on `DashboardActions` (percent-encodes one query value, `+` → `%2B`)
  - request paths, exact (param order is fixed): `/api/home/days?from=<today−28>&to=<today+7>&tz=<tz>[&organizationId=<org>]`, `/api/home/engagement?tz=<tz>[&organizationId=<org>]`, `/api/home/following[?organizationId=<org>]` (no tz — §Contract), `/api/home/sessions?range=<key>&tz=<tz>[&organizationId=<org>]`; `scheduled_lessons` via `POST /api/analytics/query` `{metrics:["scheduled_lessons"], dimensions:["day"], filters:{organizationId?, from: today−28, to: today+7}, timezone}`.
  - snapshot semantics: each extra call that fails (non-401) leaves its cached section untouched; `dayMinutes[day] = round(sessionSeconds / 60)`; `dayBlocks[day] = blocks` (seconds).

- [ ] **Step 1: Write the failing tests** — append to `final class DashboardActionsTests` in `iphone/MakeReadyCaptureTests/DashboardActionsTests.swift`:

```swift
    // MARK: - Task 9: the /api/home calls (home-dashboard-data §iphone)

    /// Canned /api/home + scheduled responses for now = 2026-10-25 (Denver): the 36-day window is
    /// 2026-09-27 … 2026-11-01.
    private func stubHome(org: String = "org1") {
        let q = "tz=America/Denver&organizationId=\(org)"
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":3,"scheduled_lessons":5},{"day":"2026-10-25","lesson_completions":2,"scheduled_lessons":4}],"previousRows":[{"lesson_completions":4}]}"#)
        api.stub("GET", "/api/home/days?from=2026-09-27&to=2026-11-01&\(q)", json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]},{"day":"2026-10-25","sessionSeconds":0,"blocks":[0,0,0,0,0,0,0,0,0,0,0,0]}]}"#)
        api.stub("GET", "/api/home/engagement?\(q)", json: #"{"currentCount":7,"enrolledCount":12,"groupCount":3,"percent":58,"activeCount":9}"#)
        api.stub("GET", "/api/home/following?organizationId=\(org)", json: #"{"programs":[{"id":"p1","title":"Romans in 30 days","author":"Luke Keith","createdAt":"2026-07-08T18:00:00.123Z","groups":[{"enrollmentId":"e1","groupName":"Young professionals","photoUrl":null,"memberCount":9,"percent":55,"synced":true}]}]}"#)
        for (range, average) in [("all", 1920), ("year", 1500), ("month", 900), ("week", 630)] {
            api.stub("GET", "/api/home/sessions?range=\(range)&\(q)", json: sessionsJSON(average))
        }
    }

    private func sessionsJSON(_ average: Int) -> String {
        let hourly = Array(repeating: "0", count: 24).joined(separator: ",")
        let bins = Array(repeating: "0", count: 88).joined(separator: ",")
        return "{\"averageSeconds\":\(average),\"sessionCount\":4,\"hourly\":[\(hourly)],\"bins\":[\(bins)],"
            + "\"ticks\":[\"2026-10-19\",\"2026-10-21\",\"2026-10-23\",\"2026-10-25\"]}"
    }

    func testRefreshFillsEveryHomeSection() async {
        state.organizationId = "org1"
        stubHome()
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let d = state.dashboard
        XCTAssertEqual(d.scheduledDays, ["2026-10-24": 5, "2026-10-25": 4])
        XCTAssertEqual(d.dayMinutes["2026-10-24"], 26)                       // 1530 s = 25.5 → 26
        XCTAssertEqual(d.dayMinutes["2026-10-25"], 0)
        XCTAssertEqual(d.dayBlocks["2026-10-24"], [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0])
        XCTAssertEqual(d.engagement, HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9))
        XCTAssertEqual(d.following?.programs.first?.groups.first?.groupName, "Young professionals")
        XCTAssertEqual(d.sessions.keys.sorted(), ["all", "month", "week", "year"])
        XCTAssertEqual(d.sessions["all"]?.averageSeconds, 1920)
        XCTAssertEqual(d.sessions["week"]?.averageSeconds, 630)
        XCTAssertEqual(d.activityDays["2026-10-24"], 3)                      // the old sections still land
        XCTAssertNotNil(d.refreshedAt)
    }

    func testScheduledQueryCoversTheChartWindow() async {
        state.organizationId = "org1"
        stubHome()
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let body = api.calls.compactMap(\.body).first { ($0["metrics"] as? [String]) == ["scheduled_lessons"] }
        let filters = body?["filters"] as? [String: Any]
        XCTAssertEqual(body?["dimensions"] as? [String], ["day"])
        XCTAssertEqual(filters?["from"] as? String, "2026-09-27")
        XCTAssertEqual(filters?["to"] as? String, "2026-11-01")
        XCTAssertEqual(filters?["organizationId"] as? String, "org1")
        XCTAssertEqual(body?["timezone"] as? String, "America/Denver")
        XCTAssertEqual(api.callCount("GET", "/api/home/days?from=2026-09-27&to=2026-11-01&tz=America/Denver&organizationId=org1"), 1)
        for range in DashboardActions.sessionRangeKeys {
            XCTAssertEqual(api.callCount("GET", "/api/home/sessions?range=\(range)&tz=America/Denver&organizationId=org1"), 1)
        }
    }

    /// A failed extra call is non-fatal: its cached section stays, everything else still lands.
    func testFailedExtraCallKeepsItsCachedSection() async {
        state.organizationId = "org1"
        stubHome()
        let cachedEngagement = HomeEngagementResponse(currentCount: 1, enrolledCount: 4, groupCount: 1, percent: 25, activeCount: 2)
        let cachedWeek = HomeSessionsResponse(averageSeconds: 42, sessionCount: 1, hourly: [], bins: [], ticks: [])
        state.dashboard.engagement = cachedEngagement
        state.dashboard.sessions["week"] = cachedWeek
        state.dashboard.scheduledDays = ["2026-10-20": 8]
        api.errorFor = { endpoint, body in
            if endpoint.hasPrefix("/api/home/engagement") || endpoint.hasPrefix("/api/home/sessions?range=week") {
                return APIError.serverError("boom")
            }
            if (body?["metrics"] as? [String]) == ["scheduled_lessons"] { return URLError(.timedOut) }
            return nil
        }
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.engagement, cachedEngagement)
        XCTAssertEqual(state.dashboard.sessions["week"], cachedWeek)
        XCTAssertEqual(state.dashboard.scheduledDays, ["2026-10-20": 8])
        XCTAssertEqual(state.dashboard.sessions["all"]?.averageSeconds, 1920)
        XCTAssertEqual(state.dashboard.following?.programs.count, 1)
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
        XCTAssertNotNil(state.dashboard.refreshedAt)
    }

    func testUnauthorizedExtraCallStillSignsOut() async {
        state.organizationId = "org1"
        stubHome()
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/home/following") ? APIError.unauthorized : nil }
        var signedOut = false
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: { signedOut = true }).refresh()
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.dashboard.refreshedAt)                            // nothing written
    }

    func testTimezoneIsPercentEncoded() async {
        XCTAssertEqual(DashboardActions.queryValue("Etc/GMT+5"), "Etc/GMT%2B5")
        XCTAssertEqual(DashboardActions.queryValue("America/Denver"), "America/Denver")
        XCTAssertEqual(DashboardActions.queryValue("a&b=c"), "a%26b%3Dc")
        state.organizationId = "org1"
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: TimeZone(identifier: "Etc/GMT+5")!).refresh()
        let engagement = api.calls.first { $0.endpoint.hasPrefix("/api/home/engagement") }?.endpoint
        XCTAssertEqual(engagement, "/api/home/engagement?tz=Etc/GMT%2B5&organizationId=org1")
    }

    func testNoOrganizationIdOnHomeCallsWhenOrgUnknown() async {
        state.organizationId = nil
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let home = api.calls.filter { $0.endpoint.hasPrefix("/api/home/") }.map(\.endpoint)
        XCTAssertEqual(home.count, 7)                                        // days, engagement, following, 4 × sessions
        XCTAssertTrue(home.allSatisfy { !$0.contains("organizationId") })
        XCTAssertTrue(home.contains("/api/home/following"))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: build error "type 'DashboardActions' has no member 'sessionRangeKeys'" / "has no member 'queryValue'".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReady/State/Actions/DashboardActions.swift`, change the doc comment on line 3 to `/// SPEC D8, D20–D22, D24–D27: Home's Overview + Activity data; home-dashboard-data adds Activity's scheduled side, day minutes, Sessions, Engagement and Following.` Add, directly under `@MainActor private var state: AppState { … }`:

```swift
    /// home-dashboard-data D8/D13: every Sessions range is fetched, so switching is a pure re-map.
    static let sessionRangeKeys = ["all", "year", "month", "week"]
```

Replace the whole `refresh()` (lines 21-56) with:

```swift
    @MainActor
    func refresh() async {
        let generation = state.initialLoad.generation
        do {
            var next = state.dashboard
            next.kpiNames = try await kpiNames()
            let today = day(now())
            let from24 = day(offset: -23), from28 = day(offset: -28), ahead7 = day(offset: 7)

            let series = try await query(["lesson_completions"], dimension: "day", from: from24, to: today, compare: true)
            next.completedSeries = byDay(series.rows, metric: "lesson_completions")
            next.completedTotal = next.completedSeries.values.reduce(0, +)
            next.completedPrevious = series.previousRows?.compactMap { $0["lesson_completions"]?.int }.reduce(0, +)

            let activity = try await query(["lesson_completions"], dimension: "day", from: from28, to: today, compare: false)
            next.activityDays = byDay(activity.rows, metric: "lesson_completions")

            if next.kpiNames.contains("watch_seconds") {
                do {
                    let watch = try await query(["watch_seconds"], dimension: nil, from: nil, to: nil, compare: false)
                    next.watchSeconds = watch.rows.first?["watch_seconds"]?.int
                } catch {
                    // A 401 still signs out; any other failure leaves watchSeconds as cached.
                    if AuthStatusPolicy.shouldSignOut(after: error) { throw error }
                    state.recordError(error, context: "DashboardActions.refresh.watchSeconds", surface: false)
                }
            }

            // home-dashboard-data: each call below is non-fatal — a failure keeps that cached section.
            let scheduled = try await nonFatal("scheduledLessons", {
                try await query(["scheduled_lessons"], dimension: "day", from: from28, to: ahead7, compare: false)
            })
            if let scheduled { next.scheduledDays = byDay(scheduled.rows, metric: "scheduled_lessons") }   // D10

            let days = try await nonFatal("days", {
                try await api.get(homePath("/api/home/days", [("from", from28), ("to", ahead7)]),
                                  responseType: HomeDaysResponse.self)
            })
            if let days {                                                                              // D6
                next.dayMinutes = Dictionary(days.days.map { ($0.day, Int((Double($0.sessionSeconds) / 60).rounded())) },
                                             uniquingKeysWith: { $1 })
                next.dayBlocks = Dictionary(days.days.map { ($0.day, $0.blocks) }, uniquingKeysWith: { $1 })
            }

            let engagement = try await nonFatal("engagement", {
                try await api.get(homePath("/api/home/engagement", []), responseType: HomeEngagementResponse.self)
            })
            if let engagement { next.engagement = engagement }                                         // D3

            let following = try await nonFatal("following", {
                try await api.get(homePath("/api/home/following", [], timezone: false), responseType: HomeFollowingResponse.self)
            })
            if let following { next.following = following }                                           // D4, D11

            for range in Self.sessionRangeKeys {                                                      // D8, D13
                let sessions = try await nonFatal("sessions.\(range)", {
                    try await api.get(homePath("/api/home/sessions", [("range", range)]), responseType: HomeSessionsResponse.self)
                })
                if let sessions { next.sessions[range] = sessions }
            }

            next.refreshedAt = now()
            // A sign-out during the awaits re-armed the load: this is the old session's data.
            guard state.initialLoad.isCurrent(generation) else { return }
            state.dashboard = next
            state.persist()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { await onUnauthorized(); return }
            state.recordError(error, context: "DashboardActions.refresh", surface: false)   // D28: logged, cache kept
        }
    }
```

Add to `// MARK: - Helpers`, after `kpiNames()`:

```swift
    /// A background section fetch: a 401 rethrows (the outer catch signs out, D27); anything else
    /// is recorded console-only (a background refresh never surfaces) and returns nil so the
    /// caller keeps the cached section.
    @MainActor
    private func nonFatal<T>(_ context: String, _ work: () async throws -> T) async throws -> T? {
        do {
            return try await work()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { throw error }
            state.recordError(error, context: "DashboardActions.refresh.\(context)", surface: false)
            return nil
        }
    }

    /// `/api/home/*` path with its query: the given params, then `tz` (unless `timezone: false`),
    /// then `organizationId` when known (D9: it can only narrow the scope).
    @MainActor
    private func homePath(_ path: String, _ params: [(String, String)], timezone: Bool = true) -> String {
        var items = params
        if timezone { items.append(("tz", timeZone.identifier)) }
        if let org = state.organizationId { items.append(("organizationId", org)) }
        guard !items.isEmpty else { return path }
        return path + "?" + items.map { "\($0.0)=\(Self.queryValue($0.1))" }.joined(separator: "&")
    }

    /// `APIClient.get` takes the raw path (APIClient.swift:218), so each value is encoded here.
    /// `urlQueryAllowed` keeps `+`, which a server reads as a space (`Etc/GMT+5`), so it is removed
    /// along with the separators `&`, `=` and `#`.
    static func queryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the six new tests and every existing `DashboardActionsTests` case: the existing tests have no `/api/home` stubs, so those calls fail non-fatally and the old assertions still hold); then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/State/Actions/DashboardActions.swift iphone/MakeReadyCaptureTests/DashboardActionsTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(home-dashboard-data): DashboardActions fetches the /api/home sections and scheduled lessons`. Do not run `git commit`.

### Task 10: HomeDashboardMapper fills Activity's scheduled columns and every day card
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — the mapper is a pure function of `AppState.dashboard`; nothing under `iphone/MakeReadyUI/` is edited

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift:36` (`chartScheduled`), `:43-46` (`daySeries`, `dayLine1s`, `dayLine2s`, `dayDetailsStates`), and add `blockMinutes(_:)` to `// MARK: - Helpers`
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift` (append to the class)

**Interfaces:**
- Consumes (Task 8): `DashboardSnapshot.scheduledDays: [String: Int]`, `.dayMinutes: [String: Int]`, `.dayBlocks: [String: [Int]]` (seconds), `.activityDays`; `HomeDashboardScreen.State.chartScheduled: [Int]`, `.daySeries: [[Double]]`, `.dayLine1s: [String]`, `.dayLine2s: [String]`, `.dayDetailsStates: [String]`, `.dayDates: [String]`.
- Produces: `static func blockMinutes(_ seconds: [Int]?) -> [Double]` on `HomeDashboardMapper` (always 12 values, minutes). Mapping, per D6/D10: `chartScheduled[i] = scheduledDays[key] ?? 0`; `dayLine1s = "<dayMinutes> mins"`; `dayLine2s = "<activityDays> complete"`; `daySeries = blockMinutes(dayBlocks[key])`; `dayDetailsStates = "default"` when the day has any session second or any completion, else `"nothing"`.

- [ ] **Step 1: Write the failing tests** — append to `final class HomeDashboardMapperTests`:

```swift
    // MARK: - Task 10: Activity + day cards (D6, D10)

    private func map(_ s: DashboardSnapshot, range: String = "All time") -> HomeDashboardScreen.State {
        HomeDashboardMapper.state(from: s, today: today, timeZone: tz, sessionRange: range)
    }

    func testScheduledColumnsComeFromTheSnapshot() {
        var s = snapshot()
        s.scheduledDays = ["2026-10-24": 5, "2026-11-01": 4]
        let st = map(s)
        XCTAssertEqual(st.chartScheduled.count, 36)
        XCTAssertEqual(st.chartScheduled[st.chartDates.firstIndex(of: "2026-10-24")!], 5)
        XCTAssertEqual(st.chartScheduled[st.chartDates.firstIndex(of: "2026-11-01")!], 4)   // today + 7
        XCTAssertEqual(st.chartScheduled.reduce(0, +), 9)
    }

    func testDayCardMinutesBarsAndCompletions() {
        var s = snapshot()
        s.dayMinutes = ["2026-10-24": 26]
        s.dayBlocks = ["2026-10-24": [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0]]
        let st = map(s)
        let i = st.dayDates.firstIndex(of: "2026-10-24")!
        XCTAssertEqual(st.dayLine1s[i], "26 mins")
        XCTAssertEqual(st.dayLine2s[i], "3 complete")
        XCTAssertEqual(st.daySeries[i], [0, 0, 0, 0, 10, 0, 15.5, 0, 0, 0, 0, 0])
        XCTAssertEqual(st.dayDetailsStates[i], "default")
    }

    func testEmptyDayIsNothing() {
        let st = map(snapshot())
        let i = st.dayDates.firstIndex(of: "2026-10-20")!
        XCTAssertEqual(st.dayLine1s[i], "0 mins")
        XCTAssertEqual(st.dayLine2s[i], "0 complete")
        XCTAssertEqual(st.daySeries[i], Array(repeating: 0, count: 12))
        XCTAssertEqual(st.dayDetailsStates[i], "nothing")
    }

    func testSessionOnlyDayIsDefault() {
        var s = snapshot()
        s.dayMinutes = ["2026-10-22": 1]
        s.dayBlocks = ["2026-10-22": [60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]
        let st = map(s)
        let i = st.dayDates.firstIndex(of: "2026-10-22")!
        XCTAssertEqual(st.dayLine2s[i], "0 complete")
        XCTAssertEqual(st.dayDetailsStates[i], "default")
    }

    func testBlockMinutesIsAlwaysTwelve() {
        XCTAssertEqual(HomeDashboardMapper.blockMinutes([120]), [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(HomeDashboardMapper.blockMinutes(nil), Array(repeating: 0, count: 12))
        XCTAssertEqual(HomeDashboardMapper.blockMinutes(Array(repeating: 60, count: 14)).count, 12)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: build error "type 'HomeDashboardMapper' has no member 'blockMinutes'" (and, once that compiles, `testScheduledColumnsComeFromTheSnapshot` / `testDayCardMinutesBarsAndCompletions` fail on 0 vs 5 and "3 lessons" vs "3 complete").

- [ ] **Step 3: Write the minimal implementation** — in `HomeDashboardMapper.swift`, replace line 36:

```swift
        st.chartScheduled = keys.map { s.scheduledDays[$0] ?? 0 }                    // D10
```

Replace lines 43-46 (`daySeries` … `dayDetailsStates`) with:

```swift
        // D6: minutes and bars are session time; line 2 is lesson completions.
        st.daySeries = keys.map { blockMinutes(s.dayBlocks[$0]) }
        st.dayLine1s = keys.map { "\(s.dayMinutes[$0] ?? 0) mins" }
        st.dayLine2s = keys.map { "\(s.activityDays[$0] ?? 0) complete" }
        st.dayDetailsStates = keys.map { key in
            let sessionSeconds = s.dayBlocks[key]?.reduce(0, +) ?? 0
            let hasActivity = sessionSeconds > 0 || (s.dayMinutes[key] ?? 0) > 0 || (s.activityDays[key] ?? 0) > 0
            return hasActivity ? "default" : "nothing"
        }
```

Add under `// MARK: - Helpers`:

```swift
    /// D6: the 12 two-hour blocks (server seconds) as minutes — always 12 long, zero-filled.
    static func blockMinutes(_ seconds: [Int]?) -> [Double] {
        let values = (seconds ?? []).prefix(12).map { Double($0) / 60 }
        return values + Array(repeating: 0, count: 12 - values.count)
    }
```

Update the type's doc comment (line 3-4) to `/// SPEC D8/D25 + home-dashboard-data D6–D16: every Home section from the snapshot; a section the snapshot has never held keeps `.empty`'s values.`

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (new tests plus the existing `testActivityWindowAndZeros`, whose snapshot has no scheduled/day data so its zero assertions still hold); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(home-dashboard-data): Home maps scheduled columns and day-card minutes`. Do not run `git commit`.

### Task 11: HomeDashboardMapper maps Sessions for the container's selected range
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — the range is pure UI state (`@State sessionRange` stays in the container); switching re-maps from `AppState.dashboard` with no Action call (D13)

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift` (Sessions block after the Activity block, before `return st`; `sessionKey(for:)`, `fixed(_:count:)`, `tickLabel(_:)`, `shortMonths` in `// MARK: - Helpers`)
- Modify: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift:27` (comment on `onSelectSessionRange` only — the call already passes `sessionRange: sessionRange`)
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`, `iphone/MakeReadyCaptureTests/HomeDashboardContainerTests.swift`

**Interfaces:**
- Consumes (Task 10): the test helper `private func map(_ s: DashboardSnapshot, range: String = "All time") -> HomeDashboardScreen.State` already in `HomeDashboardMapperTests` (and its `snapshot()`, `today`, `tz`).
- Consumes (Task 8): `DashboardSnapshot.sessions: [String: HomeSessionsResponse]` keyed `"all"/"year"/"month"/"week"`; `HomeSessionsResponse(averageSeconds:sessionCount:hourly:bins:ticks:)`; `HomeDashboardContainer.sessionRanges` (`["All time", "Year", "Month", "Week"]`); `HomeDashboardScreen.State.hourValues: [Double]`, `.centerValue: String`, `.centerUnit: String`, `.bins: [Double]`, `.sessionTickValues: [String]`, `.sessionTickUnits: [String]`, `.sessionRange: String`.
- Produces: `static func sessionKey(for label: String) -> String` ("All time"→"all", "Year"→"year", "Month"→"month", "Week"→"week", anything else → "all"); `static func tickLabel(_ day: String) -> String` ("2026-10-25" → "Oct 25"); `static func fixed(_ values: [Double], count: Int) -> [Double]`; `static let shortMonths: [String]` (`["Jan", …, "Dec"]`, also used by Task 12). The mapper signature is unchanged: `static func state(from: DashboardSnapshot, today: Date, timeZone: TimeZone, sessionRange: String) -> HomeDashboardScreen.State` with `sessionRange` the C-028 LABEL.

- [ ] **Step 1: Write the failing tests** — append to `final class HomeDashboardMapperTests`:

```swift
    // MARK: - Task 11: Sessions by range (D8, D13, D16)

    private func sessions(_ average: Int, peakHour: Int) -> HomeSessionsResponse {
        var hourly = Array(repeating: 0.0, count: 24)
        hourly[peakHour] = Double(average)
        var bins = Array(repeating: 0.0, count: 88)
        bins[87] = 1
        return HomeSessionsResponse(averageSeconds: average, sessionCount: 3, hourly: hourly, bins: bins,
                                    ticks: ["2025-10-26", "2026-02-23", "2026-06-24", "2026-10-25"])
    }

    private func sessionsSnapshot() -> DashboardSnapshot {
        var s = snapshot()
        s.sessions = ["all": sessions(1920, peakHour: 9), "year": sessions(1500, peakHour: 12),
                      "month": sessions(900, peakHour: 18), "week": sessions(630, peakHour: 20)]
        return s
    }

    func testSessionsFieldsForTheDefaultRange() {
        let st = map(sessionsSnapshot(), range: "All time")
        XCTAssertEqual(st.hourValues.count, 24)
        XCTAssertEqual(st.hourValues[9], 1920)
        XCTAssertEqual(st.centerValue, "32")                                      // 1920 s = 32 min
        XCTAssertEqual(st.centerUnit, "min")
        XCTAssertEqual(st.centerCaption, "Average session")                       // unchanged (D8)
        XCTAssertEqual(st.bins.count, 88)
        XCTAssertEqual(st.bins[87], 1)
        XCTAssertEqual(st.sessionTickValues, ["Oct 26", "Feb 23", "Jun 24", "Oct 25"])   // D16 "MMM d"
        XCTAssertEqual(st.sessionTickUnits, ["", "", "", ""])
    }

    /// D13: one snapshot holds all four ranges; changing the label is a pure re-map.
    func testFourRangesMapFromOneSnapshot() {
        let s = sessionsSnapshot()
        let expected: [(label: String, center: String, peak: Int)] = [
            ("All time", "32", 9), ("Year", "25", 12), ("Month", "15", 18), ("Week", "11", 20)   // 630 s = 10.5 → 11
        ]
        for row in expected {
            let st = map(s, range: row.label)
            XCTAssertEqual(st.sessionRange, row.label)
            XCTAssertEqual(st.centerValue, row.center, row.label)
            XCTAssertEqual(st.hourValues.firstIndex(where: { $0 > 0 }), row.peak, row.label)
        }
    }

    func testRangeNotYetFetchedKeepsTheEmptySection() {
        var s = snapshot()
        s.sessions = ["all": sessions(1920, peakHour: 9)]
        let st = map(s, range: "Week")
        XCTAssertEqual(st.centerValue, "0")
        XCTAssertEqual(st.hourValues, Array(repeating: 0, count: 24))
        XCTAssertEqual(st.sessionTickValues, HomeDashboardScreen.State.empty.sessionTickValues)
    }

    func testShortSessionArraysAreFixedLength() {
        var s = snapshot()
        s.sessions = ["all": HomeSessionsResponse(averageSeconds: 60, sessionCount: 1, hourly: [1, 2], bins: [0.5], ticks: [])]
        let st = map(s)
        XCTAssertEqual(st.hourValues.count, 24)
        XCTAssertEqual(Array(st.hourValues.prefix(2)), [1, 2])
        XCTAssertEqual(st.bins.count, 88)
        XCTAssertEqual(st.bins[0], 0.5)
        XCTAssertEqual(st.sessionTickValues, [])
        XCTAssertEqual(st.sessionTickUnits, [])
    }

    func testTickLabelFormatsAStoredDate() {
        XCTAssertEqual(HomeDashboardMapper.tickLabel("2026-01-05"), "Jan 5")
        XCTAssertEqual(HomeDashboardMapper.tickLabel("2026-12-31"), "Dec 31")
        XCTAssertEqual(HomeDashboardMapper.tickLabel("garbage"), "garbage")
    }
```

Append to `final class HomeDashboardContainerTests` in `iphone/MakeReadyCaptureTests/HomeDashboardContainerTests.swift`:

```swift
    /// D13: the container's labels map one-to-one onto the snapshot's session keys.
    func testEverySessionRangeLabelHasASnapshotKey() {
        XCTAssertEqual(HomeDashboardContainer.sessionRanges.map(HomeDashboardMapper.sessionKey(for:)),
                       DashboardActions.sessionRangeKeys)
        XCTAssertEqual(HomeDashboardMapper.sessionKey(for: "unknown"), "all")
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: build error "type 'HomeDashboardMapper' has no member 'tickLabel'" / "has no member 'sessionKey'".

- [ ] **Step 3: Write the minimal implementation** — in `HomeDashboardMapper.swift`, insert before `return st` in `state(from:today:timeZone:sessionRange:)`:

```swift
        // Sessions (D8/D13/D16): the container's selected range, re-mapped from the snapshot.
        // A range the snapshot has never held keeps `.empty`'s zeroed section.
        if let r = s.sessions[sessionKey(for: sessionRange)] {
            st.hourValues = fixed(r.hourly, count: 24)
            st.centerValue = "\(Int((Double(r.averageSeconds) / 60).rounded()))"
            st.centerUnit = "min"
            st.bins = fixed(r.bins, count: 88)
            st.sessionTickValues = r.ticks.map(tickLabel)
            st.sessionTickUnits = r.ticks.map { _ in "" }
        }
```

Add, next to `months` / `weekdays` at the top of the enum:

```swift
    static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
```

Add under `// MARK: - Helpers`:

```swift
    /// D13: the C-028 label → the snapshot's `sessions` key (`DashboardActions.sessionRangeKeys`).
    static func sessionKey(for label: String) -> String {
        switch label {
        case "Year": return "year"
        case "Month": return "month"
        case "Week": return "week"
        default: return "all"
        }
    }

    /// Pads with zeros or truncates to the length the component's prop contract states.
    static func fixed(_ values: [Double], count: Int) -> [Double] {
        let head = Array(values.prefix(count))
        return head + Array(repeating: 0, count: count - head.count)
    }

    /// D16: a server tick (yyyy-MM-dd, a calendar date — no tz shift) as "MMM d".
    static func tickLabel(_ day: String) -> String {
        let parts = day.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let date = Int(parts[2]), (1...12).contains(month)
        else { return day }
        return "\(shortMonths[month - 1]) \(date)"
    }
```

In `HomeDashboardContainer.swift`, change line 27's trailing comment so it reads:

```swift
            onSelectSessionRange: { sessionRange = $0 },         // D13: re-maps Sessions from the snapshot, no fetch
```

(Nothing on the screen calls it yet — wiring the C-036 dropdown is the design's, routed to `/ui2-resolve`; do not edit `iphone/MakeReadyUI/`.)

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (incl. the existing `testEmptySectionsStayEmpty`, whose snapshot has no sessions so `centerValue` stays "0"); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift iphone/MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift iphone/MakeReadyCaptureTests/HomeDashboardContainerTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(home-dashboard-data): Home maps Sessions for the selected range`. Do not run `git commit`.

### Task 12: HomeDashboardMapper maps Engagement and Following with the D7 colour bands
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — pure mapping from `AppState.dashboard`; nothing under `iphone/MakeReadyUI/` is edited

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift` (Engagement + Following blocks before `return st`; `bandColor(percent:)`, `createdLabel(_:tz:)`, two static ISO formatters in `// MARK: - Helpers`)
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`

**Interfaces:**
- Consumes (Task 10): the test helper `private func map(_ s: DashboardSnapshot, range: String = "All time") -> HomeDashboardScreen.State` already in `HomeDashboardMapperTests`.
- Consumes (Task 8): `DashboardSnapshot.engagement: HomeEngagementResponse?`, `.following: HomeFollowingResponse?`, `HomeFollowedProgram`, `HomeFollowedGroup` (memberwise inits); (Task 11) `HomeDashboardMapper.shortMonths`; `HomeDashboardScreen.State` fields `activeCount: String`, `engagementPercent: Int`, `engagementLabel: String`, `engagementCount: Int`, `engagementProgress: Double`, `engagementSubtitle: String`, `engagementColor: String`, `followedCount: String`, `programTitles/programAuthors/programCreatedLabels: [String]`, `groupProgramIndices: [Int]`, `groupTitles/groupPhotoURLs/groupMembers/groupPercents/groupColors: [String]`, `groupShowLinks: [Bool]`. The screen reads colours as the raw strings `"green"`/`"yellow"`/`"red"` (`EnrollmentStatusRow.StatusColor`, `HomeDashboardScreen.bandColor(_:)`) and `groupPhotoURLs` `""` as "no photo".
- Produces: `static func bandColor(percent: Int) -> String` (D7: ≥ 50 `"green"`, 20–49 `"yellow"`, < 20 `"red"`); `static func createdLabel(_ iso: String, tz: TimeZone) -> String` ("Created MMM d, yyyy" in the caller's tz, `""` when unparseable).

- [ ] **Step 1: Write the failing tests** — append to `final class HomeDashboardMapperTests`:

```swift
    // MARK: - Task 12: Engagement, Following, bands (D3, D7, D11)

    func testBandsAtTheirEdges() {
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 0), "red")
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 19), "red")
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 20), "yellow")
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 49), "yellow")
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 50), "green")
        XCTAssertEqual(HomeDashboardMapper.bandColor(percent: 100), "green")
    }

    func testEngagementFields() {
        var s = snapshot()
        s.engagement = HomeEngagementResponse(currentCount: 52, enrolledCount: 178, groupCount: 15, percent: 29, activeCount: 15)
        let st = map(s)
        XCTAssertEqual(st.engagementPercent, 29)
        XCTAssertEqual(st.engagementCount, 52)
        XCTAssertEqual(st.engagementProgress, 0.29, accuracy: 0.0001)
        XCTAssertEqual(st.engagementSubtitle, "178 total members enrolled across 15 groups")
        XCTAssertEqual(st.engagementColor, "yellow")
        XCTAssertEqual(st.engagementLabel, "Members current")
        XCTAssertEqual(st.activeCount, "15")
    }

    func testEngagementColourFollowsTheBand() {
        var s = snapshot()
        s.engagement = HomeEngagementResponse(currentCount: 1, enrolledCount: 10, groupCount: 1, percent: 10, activeCount: 0)
        XCTAssertEqual(map(s).engagementColor, "red")
        s.engagement?.percent = 50
        XCTAssertEqual(map(s).engagementColor, "green")
    }

    func testFollowingFields() {
        var s = snapshot()
        s.following = HomeFollowingResponse(programs: [
            HomeFollowedProgram(id: "p1", title: "Daily inspiration", author: "Scott Stickane",
                                createdAt: "2026-04-13T15:02:11.123Z", groups: [
                HomeFollowedGroup(enrollmentId: "e1", groupName: "Young professionals",
                                  photoUrl: "https://cdn.example/g.jpg", memberCount: 9, percent: 55, synced: true),
                HomeFollowedGroup(enrollmentId: "e2", groupName: "The kids", photoUrl: nil,
                                  memberCount: 2, percent: 13, synced: false)
            ]),
            HomeFollowedProgram(id: "p2", title: "Romans in 30 days", author: "",
                                createdAt: "2026-07-08T03:00:00Z", groups: [
                HomeFollowedGroup(enrollmentId: "e3", groupName: "Grandparents and their kids", photoUrl: nil,
                                  memberCount: 15, percent: 21, synced: true)
            ])
        ])
        let st = map(s)
        XCTAssertEqual(st.followedCount, "3")
        XCTAssertEqual(st.programTitles, ["Daily inspiration", "Romans in 30 days"])
        XCTAssertEqual(st.programAuthors, ["Scott Stickane", ""])
        // 2026-07-08T03:00Z is still July 7 in Denver — the label uses the caller's tz.
        XCTAssertEqual(st.programCreatedLabels, ["Created Apr 13, 2026", "Created Jul 7, 2026"])
        XCTAssertEqual(st.groupProgramIndices, [0, 0, 1])
        XCTAssertEqual(st.groupTitles, ["Young professionals", "The kids", "Grandparents and their kids"])
        XCTAssertEqual(st.groupPhotoURLs, ["https://cdn.example/g.jpg", "", ""])
        XCTAssertEqual(st.groupMembers, ["9", "2", "15"])
        XCTAssertEqual(st.groupPercents, ["55%", "13%", "21%"])
        XCTAssertEqual(st.groupColors, ["green", "red", "yellow"])
        XCTAssertEqual(st.groupShowLinks, [true, false, true])
    }

    func testNoFollowsIsTheEmptyState() {
        var s = snapshot()
        s.following = HomeFollowingResponse(programs: [])
        let st = map(s)
        XCTAssertEqual(st.followedCount, "0")
        XCTAssertEqual(st.programTitles, [])
        XCTAssertEqual(st.groupTitles, [])
    }

    func testCreatedLabelRejectsGarbage() {
        XCTAssertEqual(HomeDashboardMapper.createdLabel("not a date", tz: tz), "")
        XCTAssertEqual(HomeDashboardMapper.createdLabel("2026-04-13T15:02:11Z", tz: tz), "Created Apr 13, 2026")
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: build error "type 'HomeDashboardMapper' has no member 'bandColor'" / "has no member 'createdLabel'".

- [ ] **Step 3: Write the minimal implementation** — in `HomeDashboardMapper.swift`, insert before `return st` (after the Sessions block):

```swift
        // Engagement (D3/D7). Never fetched → `.empty`'s zeroed section.
        if let e = s.engagement {
            st.activeCount = "\(e.activeCount)"
            st.engagementPercent = e.percent
            st.engagementLabel = "Members current"
            st.engagementCount = e.currentCount
            st.engagementProgress = Double(e.percent) / 100
            st.engagementSubtitle = "\(e.enrolledCount) total members enrolled across \(e.groupCount) groups"
            st.engagementColor = bandColor(percent: e.percent)
        }

        // Following (D4/D11): program blocks in server order; group cards flattened, each pointing
        // back at its program by index.
        if let f = s.following {
            let cards: [(program: Int, group: HomeFollowedGroup)] = f.programs.enumerated().flatMap { index, program in
                program.groups.map { (program: index, group: $0) }
            }
            st.followedCount = "\(cards.count)"
            st.programTitles = f.programs.map { $0.title }
            st.programAuthors = f.programs.map { $0.author }
            st.programCreatedLabels = f.programs.map { createdLabel($0.createdAt, tz: timeZone) }
            st.groupProgramIndices = cards.map { $0.program }
            st.groupTitles = cards.map { $0.group.groupName }
            st.groupPhotoURLs = cards.map { $0.group.photoUrl ?? "" }
            st.groupMembers = cards.map { "\($0.group.memberCount)" }          // the card adds "members"
            st.groupPercents = cards.map { "\($0.group.percent)%" }
            st.groupColors = cards.map { bandColor(percent: $0.group.percent) }
            st.groupShowLinks = cards.map { $0.group.synced }
        }
```

Add under `// MARK: - Helpers`:

```swift
    /// D7: C-031 / C-033 colour bands — green ≥ 50, yellow 20–49, red < 20.
    static func bandColor(percent: Int) -> String {
        if percent >= 50 { return "green" }
        if percent >= 20 { return "yellow" }
        return "red"
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// D11: "Created MMM d, yyyy" in the caller's tz from the server's ISO 8601 string (Prisma
    /// writes fractional seconds); "" when it doesn't parse.
    static func createdLabel(_ iso: String, tz: TimeZone) -> String {
        guard let date = isoFractional.date(from: iso) ?? isoPlain.date(from: iso) else { return "" }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return "Created \(shortMonths[m - 1]) \(d), \(y)"
    }
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (new tests plus the existing `testEmptySectionsStayEmpty`: its snapshot has no engagement/following, so `followedCount` "0", `programTitles` [] and `engagementCount` 0 still hold); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (the ISO formatters are `static`).

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(home-dashboard-data): Home maps Engagement and Following with D7 bands`. Do not run `git commit`.

---

### Task 13: D10 corrected + D18 session-length strip (owner rulings 2026-10-25)
App: server
Phase: 3
Recipe: /api (server)

Owed rework on built producer code, per SPEC D10 (superseded), D18, SC3. Already written in the
worktree from the owner's on-device session; this block records it.

**Files:**
- Create: `server/atlas/migrations/20261025200000.sql` — recreate `analytics_events` with the `ls:` arm
  joined to `group_members` (active, `memberId` not null), `event_id = 'ls:' || ls.id || ':' || gm.id`;
  everything else copied verbatim from the prior definition; `atlas migrate hash` → `atlas.sum`.
- Modify: `server/src/services/analytics.service.ts` (the `ls` quality-check join), `server/src/services/home-dashboard.ts`
  (`TICK_STEPS_MINUTES`, `MAX_TICKS`, `sessionLengthAxis()`, `summarizeSessions` bins = sessions per length band,
  `ticks: number[]`, `axisMinutes`), `server/src/routes/home.ts` (OpenAPI line).
- Tests: `home-dashboard.test.ts` (`sessionLengthAxis` 40 → 0·20·40, 45 → 0·15·30·45; bins by length),
  `home.test.ts`, `scheduled-lessons.db.test.ts` (schedule × member counts), `home-dashboard.db.test.ts`.

**Done when:** server fast gates green for these files; `migrate:status` at `20261025200000`; the contract re-closes.

### Task 14: iPhone consumes D18 and lands D19–D20 (owner rulings 2026-10-25)
App: iphone
Phase: 5
Recipe: iphone (iphone/.claude/CLAUDE.md — HorizontalRail, AppState + Actions)

Owed rework on built consumer code, per SPEC D18, D19, D20 — re-checked against the re-opened
`/api/home/sessions` row. Already written in the worktree; this block records it.

**Files:**
- Modify: `DashboardModels.swift` (`HomeSessionsResponse.ticks: [Int]`, `axisMinutes`, tolerant decode of the
  pre-D18 cache), `DashboardActions.swift` (`historyDays = 182`, `daysPerCall = 62`, parallel day ranges),
  `HomeDashboardMapper.swift` (182-day window; ticks as minute values with unit "min").
- Modify: `MakeReadyUI/DualSeriesBarChart.swift` (scroll view over the whole timeline, timeline scale,
  completed inside scheduled), `MakeReadyUI/Screens/Home/HomeDashboardScreen.swift` (rail and chart unsynced,
  `LazyHStack` rail, chart re-created by Jump to today), `MakeReadyUI/UI2Element.swift` (bounds only under the
  capture map), `MakeReadyUI/HorizontalScrolling.swift`, `iphone/.swiftlint.yml`, `project.pbxproj`.
- Tests: `DashboardActionsTests` (history ranges), `HomeDashboardMapperTests` (minute ticks), `StubAPIClient`.

**Done when:** `npm run ios:build-check -- --test` green but the known `testPageHeaderDeclaresItsFrame`;
swiftlint clean; staged for the owner (`commit: manual`).

### Task 15: Realistic fixtures (D21, owner 2026-10-25)
App: server
Phase: 3
Recipe: /api (server) — fixtures layer

**Files:**
- Modify: `server/fixtures/base.ts` — `WEEKDAYS`, `ENROLLMENT_PLAN[].days` (E3 Mon–Fri), `lessonOffsets()`; schedules land on enabled days.
- Modify: `server/fixtures/screens/home-dashboard.ts` — one member-lesson model over base + history; D21 completion,
  lateness with per-day capacity, habits, log-normal lengths, resume opens every 20 min; history cadence + breaks.
- Tests: `fixtures/__tests__/home-dashboard.test.ts` (habit mix, POP_CURVE night share, rates, fatigue, bad weeks, cadence),
  `home-dashboard.db.test.ts` (breaks, scheduled heights, < 40% / ≥ 90% days, weekend sag, hour shares, session spread,
  Engagement 10/24), `base.db.test.ts` (E1–E4 on their enabled days), `scheduled-lessons.db.test.ts` (probe at +30).

**Done when:** `FIXTURES_TEST_DATABASE_URL=<throwaway> npx vitest run fixtures` green; walk env re-seeded.

### Task 16: Fixture images from d2m (D22, owner 2026-10-25)
App: server
Phase: 3
Recipe: /api (server) — fixtures layer

**Files:**
- Create: `server/fixtures/images.ts` — `selectImages()` (slots by preferred slug → tag pool; library round-robin by Book),
  d2m catalog fetch + cache, sharp resize to 1200/400 JPEG, `imageBaseUrl()`, `seedImages()` (media, media_usages, covers).
- Modify: `server/fixtures/base.ts` (calls `seedImages`), `ids.ts` (`media`, `mediaUsage` kinds), `counts.ts` +
  `__tests__/db-harness.ts` (media tables), `README.md`; root `.gitignore` (`server/public/fixture-images/`).
- Tests: `__tests__/images.test.ts` (preferred/pool picks, library spread, determinism, base URL); `base.db.test.ts` (e) media 0 under vitest.

**Done when:** fixtures suite green on a throwaway DB; a walk-env reset stores reachable covers (HTTP 200 via the Local host).

### Task 17: Sessions dial = activity concentration (D23, owner 2026-10-25)
App: server
Phase: 3

**Files:** `server/src/services/home-dashboard.ts` (`hoursActive()`, `summarizeSessions` hourly = sessions active per local hour),
`server/src/routes/home.ts` (OpenAPI line). Tests: `home-dashboard.test.ts` (two sessions in hour 9 → 2; 06:50–07:20 → hours 6 and 7).
Contract shape unchanged (`hourly: [24 number]`); its meaning changed — consumer iphone maps it straight to C-029 `hourValues`.

### Task 18: Pull-to-refresh on Home (D24, owner 2026-10-25)
App: iphone
Phase: 5

**Files:** `MakeReady/UI2/Shell/HomeSectionLayout.swift` (`SectionPageScroll` arms at 72 pt, haptic, ActivitySpinner, 48 pt gap while refreshing),
`MakeReady/UI2/Shell/UI2Shell.swift` (`refreshAction`, Home only), `MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift`
(`static refresh(authManager:)`), `MakeReady/State/Models/DashboardModels.swift` (D23 comment).

