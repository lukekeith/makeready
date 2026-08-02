/**
 * Analytics service — refresh + generic query engine for the flat computed
 * layer (docs/features/analytics/architecture.md).
 *
 * `analytics_events` is a materialized view over the transactional tables
 * (schema of record: atlas/migrations/20260730040000.sql). This service:
 *
 *  - refreshAnalytics(): REFRESH MATERIALIZED VIEW CONCURRENTLY guarded by a
 *    Postgres advisory lock (image-promotion deploys briefly run old+new
 *    instances; two concurrent CONCURRENT refreshes of one matview error out).
 *    The lock is session-scoped on a dedicated connection, so a crashed
 *    instance self-releases when its connection drops.
 *  - Telemetry on the analytics_refresh_state singleton (last_refreshed_at,
 *    last_duration_ms, last_error, consecutive_failures) + loud alerts: the
 *    in-process timer's failure mode is silent, so staleness is actively
 *    watched, not assumed.
 *  - Post-refresh quality checks (dbt-style tests in plain SQL): per-arm
 *    row-count reconciliation, NULL-key guard, event_type accepted values.
 *  - runAnalyticsQuery(): the registry-driven query builder behind
 *    POST /api/analytics/query. Authorization is SCOPE INJECTION, not
 *    validation — the caller's entitled org/group set is appended to every
 *    query unconditionally; client filters can only narrow within it.
 *
 * All analytics SQL runs on a dedicated pg pool with a 5s statement_timeout
 * so a pathological group-by can never degrade OLTP.
 */

import pg from 'pg'
import { prisma } from '../lib/prisma.js'
import {
  ALL_EVENT_TYPES,
  DIMENSIONS_BY_NAME,
  ENGAGEMENT_EVENT_TYPES,
  METRICS_BY_NAME,
  RELATIVE_RANGES,
  type DimensionDef,
  type MetricDef,
} from './analytics-metrics.js'

// ── Tunables (architecture.md § Refresh strategy) ────────────────────────────

export const REFRESH_INTERVAL_MS = 10 * 60_000
/** Query-path staleness backstop: refresh in background past this age. */
const STALE_AFTER_MS = 15 * 60_000
/** Alert when staleness exceeds 3× the refresh interval. */
const ALERT_STALE_MS = 3 * REFRESH_INTERVAL_MS
/** Alert when refresh duration exceeds 50% of the interval. */
const ALERT_DURATION_MS = REFRESH_INTERVAL_MS / 2

/** Arbitrary app-unique advisory lock key for the analytics refresh. */
const REFRESH_LOCK_KEY = 727201001

const STATE_ID = 'singleton'

// ── Dedicated pool ───────────────────────────────────────────────────────────

let pool: pg.Pool | null = null

function getPool(): pg.Pool {
  if (!pool) {
    pool = new pg.Pool({
      connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
      max: 4,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      statement_timeout: 5_000,
    })
    pool.on('error', (err) => console.error('❌ [Analytics] pool error:', err.message))
  }
  return pool
}

// ── Refresh ──────────────────────────────────────────────────────────────────

export interface RefreshResult {
  refreshed: boolean
  /** True when another instance held the advisory lock. */
  skippedLockHeld?: boolean
  durationMs?: number
  error?: string
}

let refreshInFlight: Promise<RefreshResult> | null = null

/**
 * Refresh the analytics_events materialized view. Single-flighted in-process
 * AND cross-instance (advisory lock). Never throws — failures land in
 * analytics_refresh_state and the error log.
 */
export function refreshAnalytics(): Promise<RefreshResult> {
  if (refreshInFlight) return refreshInFlight
  refreshInFlight = doRefresh().finally(() => {
    refreshInFlight = null
  })
  return refreshInFlight
}

async function doRefresh(): Promise<RefreshResult> {
  let client: pg.PoolClient
  try {
    client = await getPool().connect()
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('❌ [Analytics] refresh could not obtain a connection:', message)
    return { refreshed: false, error: message }
  }

  try {
    const lock = await client.query<{ locked: boolean }>(
      'SELECT pg_try_advisory_lock($1) AS locked',
      [REFRESH_LOCK_KEY]
    )
    if (!lock.rows[0]?.locked) {
      return { refreshed: false, skippedLockHeld: true }
    }

    const startedAt = Date.now()
    try {
      // The refresh itself is exempt from the 5s analytics query timeout.
      await client.query('SET statement_timeout = 0')
      await client.query('REFRESH MATERIALIZED VIEW CONCURRENTLY analytics_events')
      const durationMs = Date.now() - startedAt

      await client.query(
        `INSERT INTO analytics_refresh_state
           ("id", "lastRefreshedAt", "lastDurationMs", "lastError", "consecutiveFailures", "updatedAt")
         VALUES ($1, now(), $2, NULL, 0, now())
         ON CONFLICT ("id") DO UPDATE SET
           "lastRefreshedAt" = now(),
           "lastDurationMs" = $2,
           "lastError" = NULL,
           "consecutiveFailures" = 0,
           "updatedAt" = now()`,
        [STATE_ID, durationMs]
      )

      if (durationMs > ALERT_DURATION_MS) {
        console.error(
          `🚨 [Analytics] refresh took ${durationMs}ms — over 50% of the ${REFRESH_INTERVAL_MS}ms interval. ` +
            'Migration trigger per architecture.md: consider the incremental-table path.'
        )
      }

      await runQualityChecks(client)
      return { refreshed: true, durationMs }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      console.error('🚨 [Analytics] refresh FAILED:', message)
      try {
        await client.query(
          `INSERT INTO analytics_refresh_state
             ("id", "lastError", "consecutiveFailures", "updatedAt")
           VALUES ($1, $2, 1, now())
           ON CONFLICT ("id") DO UPDATE SET
             "lastError" = $2,
             "consecutiveFailures" = analytics_refresh_state."consecutiveFailures" + 1,
             "updatedAt" = now()`,
          [STATE_ID, message.slice(0, 2000)]
        )
      } catch (stateErr) {
        console.error('❌ [Analytics] could not record refresh failure:', stateErr)
      }
      return { refreshed: false, error: message }
    } finally {
      try {
        await client.query('SET statement_timeout = 5000')
        await client.query('SELECT pg_advisory_unlock($1)', [REFRESH_LOCK_KEY])
      } catch {
        // Connection is broken — release() below discards it and the session
        // (and its advisory lock) dies with it.
      }
    }
  } finally {
    client.release()
  }
}

/**
 * Post-refresh quality checks. Failures are logged loudly but never throw —
 * analytics may be flagged, never taken down by its own tests.
 */
async function runQualityChecks(client: pg.PoolClient): Promise<void> {
  try {
    // 1. NULL-key guard: event_id/entity_id/occurred_at must be provably set.
    const nulls = await client.query<{ n: number }>(
      `SELECT COUNT(*)::int AS n FROM analytics_events
        WHERE event_id IS NULL OR entity_id IS NULL OR occurred_at IS NULL`
    )
    if ((nulls.rows[0]?.n ?? 0) > 0) {
      console.error(`🚨 [Analytics] quality check FAILED: ${nulls.rows[0].n} rows with NULL event_id/entity_id/occurred_at`)
    }

    // 2. event_type accepted values (the registry is the tracking plan).
    const badTypes = await client.query<{ event_type: string }>(
      `SELECT DISTINCT event_type FROM analytics_events WHERE event_type <> ALL($1::text[])`,
      [ALL_EVENT_TYPES]
    )
    if (badTypes.rows.length > 0) {
      console.error(
        `🚨 [Analytics] quality check FAILED: unregistered event_type(s) in view: ${badTypes.rows.map((r) => r.event_type).join(', ')}`
      )
    }

    // 3. Per-arm row-count reconciliation: view arm count = source count under
    //    the same predicates (join chains mirror the view definition).
    const arms: Array<{ prefix: string; sourceSql: string }> = [
      {
        prefix: 'ap',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM member_activity_progress map
          JOIN lesson_schedules ls ON ls.id = map."lessonScheduleId"
          JOIN enrollments e ON e.id = ls."enrollmentId"
          JOIN groups g ON g.id = e."groupId"
          LEFT JOIN scheduled_lesson_activities sa ON sa.id = map."scheduledActivityId"
          WHERE map."completedAt" IS NOT NULL AND (sa.type IS NULL OR sa.type <> 'VIDEO')`,
      },
      {
        prefix: 'vc',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM member_video_progress mvp
          JOIN lesson_schedules ls ON ls.id = mvp."lessonScheduleId"
          JOIN enrollments e ON e.id = ls."enrollmentId"
          JOIN groups g ON g.id = e."groupId"
          WHERE mvp."completedAt" IS NOT NULL`,
      },
      {
        prefix: 'vw',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM member_video_progress mvp
          JOIN lesson_schedules ls ON ls.id = mvp."lessonScheduleId"
          JOIN enrollments e ON e.id = ls."enrollmentId"
          JOIN groups g ON g.id = e."groupId"
          WHERE mvp."watchedSeconds" > 0`,
      },
      {
        prefix: 'lc',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM member_lesson_progress mlp
          JOIN lesson_schedules ls ON ls.id = mlp."lessonScheduleId"
          JOIN enrollments e ON e.id = ls."enrollmentId"
          JOIN groups g ON g.id = e."groupId"
          WHERE mlp."completedAt" IS NOT NULL`,
      },
      {
        prefix: 'nt',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM study_notes sn
          JOIN note_links nl ON nl."noteId" = sn.id AND nl."refType" = 'ENROLLMENT'
          JOIN enrollments e ON e.id::text = nl."refId"
          JOIN groups g ON g.id = e."groupId"
          WHERE sn."isActive" = true AND COALESCE(sn."memberId", sn."userId") IS NOT NULL`,
      },
      {
        prefix: 'en',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM enrollments e
          JOIN groups g ON g.id = e."groupId"
          WHERE e."createdById" IS NOT NULL`,
      },
      {
        prefix: 'mj',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM membership_events me
          WHERE me.action IN ('ADDED', 'APPROVED', 'REJOINED')`,
      },
      {
        prefix: 'ce',
        sourceSql: `SELECT COUNT(*)::int AS n
          FROM client_events ce
          LEFT JOIN members m ON m.id::text = ce."memberId"
          LEFT JOIN users u ON u.id::text = ce."userId"
          WHERE COALESCE(ce."memberId", ce."userId") IS NOT NULL
            AND (ce."memberId" IS NULL OR m.id IS NOT NULL)
            AND (ce."userId" IS NULL OR u.id IS NOT NULL)`,
      },
    ]

    for (const arm of arms) {
      const [viewCount, sourceCount] = await Promise.all([
        client.query<{ n: number }>(
          `SELECT COUNT(*)::int AS n FROM analytics_events WHERE event_id LIKE $1`,
          [`${arm.prefix}:%`]
        ),
        client.query<{ n: number }>(arm.sourceSql),
      ])
      const v = viewCount.rows[0]?.n ?? 0
      const s = sourceCount.rows[0]?.n ?? 0
      if (v !== s) {
        console.error(
          `🚨 [Analytics] quality check FAILED: arm '${arm.prefix}:' has ${v} view rows but ${s} source rows — view definition and source predicates have drifted`
        )
      }
    }
  } catch (err) {
    console.error('❌ [Analytics] quality checks errored:', err instanceof Error ? err.message : err)
  }
}

// ── Freshness ────────────────────────────────────────────────────────────────

export interface Freshness {
  /** Last successful refresh instant (ISO) — the `freshAsOf` on responses. */
  freshAsOf: string | null
  lastDurationMs: number | null
  lastError: string | null
  consecutiveFailures: number
}

export async function getFreshness(): Promise<Freshness> {
  const state = await prisma.analyticsRefreshState.findUnique({ where: { id: STATE_ID } })
  return {
    freshAsOf: state?.lastRefreshedAt?.toISOString() ?? null,
    lastDurationMs: state?.lastDurationMs ?? null,
    lastError: state?.lastError ?? null,
    consecutiveFailures: state?.consecutiveFailures ?? 0,
  }
}

/**
 * Query-path staleness backstop: if the view is older than 15 min (e.g. after
 * a deploy/restart), trigger a background refresh and STILL serve current data
 * immediately — analytics may be minutes stale, never wrong. Alerts loudly
 * past 3× the refresh interval.
 */
export async function ensureFresh(): Promise<Freshness> {
  const freshness = await getFreshness()
  const ageMs = freshness.freshAsOf
    ? Date.now() - new Date(freshness.freshAsOf).getTime()
    : Number.POSITIVE_INFINITY

  if (ageMs > ALERT_STALE_MS) {
    console.error(
      `🚨 [Analytics] view is ${freshness.freshAsOf ? Math.round(ageMs / 60_000) + ' min' : 'infinitely'} stale ` +
        `(alert threshold ${ALERT_STALE_MS / 60_000} min). lastError=${freshness.lastError ?? 'none'} ` +
        `consecutiveFailures=${freshness.consecutiveFailures}`
    )
  }
  if (ageMs > STALE_AFTER_MS) {
    void refreshAnalytics()
  }
  return freshness
}

/**
 * Start the in-process refresh loop (index.ts, non-test only). Kicks an
 * immediate refresh so a fresh deploy serves warm data, then every 10 min.
 */
export function startAnalyticsRefreshJob(): void {
  setTimeout(() => {
    void refreshAnalytics()
  }, 3_000).unref()
  setInterval(() => {
    void refreshAnalytics()
  }, REFRESH_INTERVAL_MS).unref()
  console.log(`📊 Analytics refresh job started (every ${REFRESH_INTERVAL_MS / 60_000} min)`)
}

// ── Query engine ─────────────────────────────────────────────────────────────

export class AnalyticsQueryError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

/** Caller entitlement, derived server-side — never from client input. */
export type AnalyticsScope =
  | { all: true }
  | { all: false; orgIds: string[]; groupIds: string[] }

export interface AnalyticsFilters {
  organizationId?: string
  groupId?: string
  studyProgramId?: string
  enrollmentId?: string
  memberId?: string
  lessonScheduleId?: string
  activityType?: string
  eventType?: string
  from?: string
  to?: string
  range?: string
}

export interface AnalyticsQueryInput {
  metrics: string[]
  dimensions: string[]
  filters: AnalyticsFilters
  timezone: string
  limit?: number
  orderBy?: { metric: string; dir: 'asc' | 'desc' }
  compareToPrevious?: boolean
}

export interface AnalyticsQueryResult {
  freshAsOf: string | null
  resolvedQuery: {
    metrics: string[]
    dimensions: string[]
    range: { from: string; to: string; label?: string } | null
    previousRange?: { from: string; to: string }
    timezone: string
    appliedScope: { all: boolean; organizationIds?: string[]; groupIds?: string[] }
  }
  rows: Record<string, unknown>[]
  previousRows?: Record<string, unknown>[]
  truncated?: boolean
}

interface ResolvedRange {
  /** Local calendar dates in the query timezone. `toExclusive` = day AFTER the last included day. */
  fromDate: string
  toExclusiveDate: string
  label?: string
}

/** Today's local calendar date (YYYY-MM-DD) in an IANA timezone. */
export function todayInTimezone(tz: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(new Date())
}

/** Date-only arithmetic on YYYY-MM-DD strings (UTC-noon anchor avoids DST edges). */
function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

function assertValidTimezone(tz: string): void {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz })
  } catch {
    throw new AnalyticsQueryError(400, `Invalid timezone: ${tz}`)
  }
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

function resolveRange(filters: AnalyticsFilters, tz: string): ResolvedRange | null {
  if (filters.range) {
    const rel = RELATIVE_RANGES[filters.range]
    if (!rel) {
      throw new AnalyticsQueryError(
        400,
        `Unknown range '${filters.range}'. Valid: ${Object.keys(RELATIVE_RANGES).join(', ')}`
      )
    }
    const today = todayInTimezone(tz)
    return { fromDate: addDays(today, -(rel.days - 1)), toExclusiveDate: addDays(today, 1), label: rel.label }
  }
  if (filters.from || filters.to) {
    if (!filters.from || !filters.to) {
      throw new AnalyticsQueryError(400, 'Provide both from and to (YYYY-MM-DD), or a relative range')
    }
    if (!DATE_RE.test(filters.from) || !DATE_RE.test(filters.to)) {
      throw new AnalyticsQueryError(400, 'from/to must be YYYY-MM-DD')
    }
    if (filters.to < filters.from) {
      throw new AnalyticsQueryError(400, 'to must not be before from')
    }
    return { fromDate: filters.from, toExclusiveDate: addDays(filters.to, 1) }
  }
  return null
}

/** Incrementing $n parameter collector. */
class Params {
  values: unknown[] = []
  add(value: unknown): string {
    this.values.push(value)
    return `$${this.values.length}`
  }
}

/** Per-metric FILTER predicate: event types + version semantics. */
function metricPredicate(m: MetricDef, p: Params): string {
  const parts: string[] = []
  if (m.eventTypes.length > 0) {
    parts.push(`event_type = ANY(${p.add(m.eventTypes)}::text[])`)
  }
  if (m.versionSemantics === 'current-only') {
    parts.push('is_current_version AND NOT is_removed')
  }
  return parts.length > 0 ? parts.join(' AND ') : 'TRUE'
}

function metricAggSql(m: MetricDef, pred: string, tz: () => string): string {
  switch (m.agg) {
    case 'count':
      return `COUNT(*) FILTER (WHERE ${pred})::int`
    case 'count_distinct_entity':
      return `COUNT(DISTINCT entity_id) FILTER (WHERE ${pred})::int`
    case 'sum_value':
      return `COALESCE(SUM(value) FILTER (WHERE ${pred}), 0)::float8`
    case 'avg_percent':
      return `AVG(percent) FILTER (WHERE ${pred})::float8`
    case 'count_distinct_day':
      return `COUNT(DISTINCT ((occurred_at AT TIME ZONE ${tz()})::date)) FILTER (WHERE ${pred})::int`
    default:
      throw new AnalyticsQueryError(500, `Metric ${m.name} has no aggregate`)
  }
}

const ident = (name: string) => `"${name.replace(/"/g, '')}"`

/**
 * Run a registry query against analytics_events with the caller's entitled
 * scope injected unconditionally.
 */
export async function runAnalyticsQuery(
  input: AnalyticsQueryInput,
  scope: AnalyticsScope
): Promise<AnalyticsQueryResult> {
  assertValidTimezone(input.timezone)

  // Resolve registry entries (whitelist-only).
  const metrics = input.metrics.map((name) => {
    const m = METRICS_BY_NAME.get(name)
    if (!m) throw new AnalyticsQueryError(400, `Unknown metric '${name}'`)
    return m
  })
  if (metrics.length === 0) throw new AnalyticsQueryError(400, 'At least one metric is required')

  const dimensions = input.dimensions.map((name) => {
    const d = DIMENSIONS_BY_NAME.get(name)
    if (!d) throw new AnalyticsQueryError(400, `Unknown dimension '${name}'`)
    return d
  })
  if (dimensions.length > 2) throw new AnalyticsQueryError(400, 'At most 2 dimensions')
  const timeDims = dimensions.filter((d) => d.kind === 'time')
  if (timeDims.length > 1) throw new AnalyticsQueryError(400, 'At most one time dimension')
  const timeDim = timeDims[0] ?? null
  const columnDims = dimensions.filter((d) => d.kind === 'column')

  const range = resolveRange(input.filters, input.timezone)

  // Snapshot metrics are cumulative state — a time-windowed snapshot aggregate
  // silently returns lifetime values of recently-active members. Reject.
  const snapshotMetrics = metrics.filter((m) => m.class === 'snapshot')
  if (snapshotMetrics.length > 0 && range) {
    throw new AnalyticsQueryError(
      400,
      `Snapshot metric(s) ${snapshotMetrics.map((m) => m.name).join(', ')} cannot be time-windowed (from/to/range)`
    )
  }
  if (snapshotMetrics.length > 0 && timeDim) {
    throw new AnalyticsQueryError(
      400,
      `Snapshot metric(s) ${snapshotMetrics.map((m) => m.name).join(', ')} cannot be grouped by a time dimension`
    )
  }

  for (const m of metrics) {
    if (!m.dimensionsAllowed && dimensions.length > 0) {
      throw new AnalyticsQueryError(400, `Metric '${m.name}' does not support dimensions`)
    }
    if (m.ratio === 'expected_lesson_completions') {
      const f = input.filters
      if (f.memberId || f.lessonScheduleId || f.activityType || f.eventType) {
        throw new AnalyticsQueryError(
          400,
          `Metric '${m.name}' only supports organization/group/program/enrollment filters`
        )
      }
    }
  }

  // Zero-fill needs bounds; a time dimension without a range has none.
  if (timeDim && !range) {
    throw new AnalyticsQueryError(400, `Dimension '${timeDim.name}' requires from/to or a relative range`)
  }

  // High-cardinality groupings must be explicitly capped and ordered so a
  // top-N never silently under-reports.
  const highCardDim = columnDims.find((d) => d.highCardinality)
  if (highCardDim) {
    if (!input.limit) {
      throw new AnalyticsQueryError(400, `Dimension '${highCardDim.name}' requires an explicit limit (max 500)`)
    }
    if (!input.orderBy) {
      throw new AnalyticsQueryError(400, `Dimension '${highCardDim.name}' requires an orderBy`)
    }
  }
  if (input.limit !== undefined && (input.limit < 1 || input.limit > 500)) {
    throw new AnalyticsQueryError(400, 'limit must be between 1 and 500')
  }
  if (input.orderBy && !input.metrics.includes(input.orderBy.metric)) {
    throw new AnalyticsQueryError(400, `orderBy.metric must be one of the requested metrics`)
  }

  if (!scope.all && scope.orgIds.length === 0 && scope.groupIds.length === 0) {
    throw new AnalyticsQueryError(404, 'Not found')
  }

  const freshness = await ensureFresh()

  const { rows, truncated } = await executeQuery(input, scope, metrics, timeDim, columnDims, range)

  let previousRows: Record<string, unknown>[] | undefined
  let previousRange: { from: string; to: string } | undefined
  if (input.compareToPrevious && range) {
    // The immediately-preceding period of identical length.
    const periodDays = Math.round(
      (Date.parse(`${range.toExclusiveDate}T00:00:00Z`) - Date.parse(`${range.fromDate}T00:00:00Z`)) / 86_400_000
    )
    const prev: ResolvedRange = {
      fromDate: addDays(range.fromDate, -periodDays),
      toExclusiveDate: range.fromDate,
    }
    const prevResult = await executeQuery(input, scope, metrics, timeDim, columnDims, prev)
    previousRows = prevResult.rows
    previousRange = { from: prev.fromDate, to: addDays(prev.toExclusiveDate, -1) }
  }

  return {
    freshAsOf: freshness.freshAsOf,
    resolvedQuery: {
      metrics: input.metrics,
      dimensions: input.dimensions,
      range: range
        ? { from: range.fromDate, to: addDays(range.toExclusiveDate, -1), label: range.label }
        : null,
      ...(previousRange ? { previousRange } : {}),
      timezone: input.timezone,
      appliedScope: scope.all
        ? { all: true }
        : { all: false, organizationIds: scope.orgIds, groupIds: scope.groupIds },
    },
    rows,
    ...(previousRows ? { previousRows } : {}),
    ...(truncated ? { truncated } : {}),
  }
}

async function executeQuery(
  input: AnalyticsQueryInput,
  scope: AnalyticsScope,
  metrics: MetricDef[],
  timeDim: DimensionDef | null,
  columnDims: DimensionDef[],
  range: ResolvedRange | null
): Promise<{ rows: Record<string, unknown>[]; truncated: boolean }> {
  const p = new Params()
  // The timezone parameter is allocated lazily on first use — a supplied-but-
  // unreferenced parameter makes Postgres fail with "could not determine data
  // type of parameter" (42P18).
  let tzParamName: string | null = null
  const tz = () => (tzParamName ??= `${p.add(input.timezone)}::text`)

  // WHERE: injected scope + client filters (narrowing only) + time range.
  const where: string[] = []
  if (!scope.all) {
    where.push(
      `(organization_id = ANY(${p.add(scope.orgIds)}::text[]) OR group_id = ANY(${p.add(scope.groupIds)}::text[]))`
    )
  }
  const f = input.filters
  const columnFilters: Array<[string, string | undefined]> = [
    ['organization_id', f.organizationId],
    ['group_id', f.groupId],
    ['study_program_id', f.studyProgramId],
    ['enrollment_id', f.enrollmentId],
    ['member_id', f.memberId],
    ['lesson_schedule_id', f.lessonScheduleId],
    ['activity_type', f.activityType],
    ['event_type', f.eventType],
  ]
  for (const [column, value] of columnFilters) {
    if (value !== undefined) where.push(`${column} = ${p.add(value)}`)
  }
  // Constrain the scan to the union of the requested metrics' event types —
  // rows outside every metric's set contribute nothing to any FILTER
  // aggregate, but would otherwise surface as zero-count group rows (e.g.
  // { member_id: null, completions: 0 } from ENROLLMENT_CREATED events).
  if (metrics.every((m) => m.eventTypes.length > 0)) {
    const typeUnion = [...new Set(metrics.flatMap((m) => m.eventTypes))]
    where.push(`event_type = ANY(${p.add(typeUnion)}::text[])`)
  }
  if (range) {
    where.push(`occurred_at >= (${p.add(range.fromDate)}::date::timestamp AT TIME ZONE ${tz()})`)
    where.push(`occurred_at < (${p.add(range.toExclusiveDate)}::date::timestamp AT TIME ZONE ${tz()})`)
  }
  const whereSql = where.length > 0 ? `WHERE ${where.join(' AND ')}` : ''

  // Aggregate select list. Ratio metrics emit hidden __num/__den columns that
  // are divided (divide-by-zero-safe) in post-processing.
  const aggCols: string[] = []
  const zeroFillCols: string[] = [] // outer COALESCE targets for zero-filled series
  for (const m of metrics) {
    const pred = metricPredicate(m, p)
    if (m.ratio === 'on_time') {
      const onTimePred = `${pred} AND scheduled_date IS NOT NULL AND (occurred_at AT TIME ZONE ${tz()})::date <= scheduled_date + 1`
      aggCols.push(`COUNT(*) FILTER (WHERE ${onTimePred})::int AS ${ident(`__num_${m.name}`)}`)
      aggCols.push(`COUNT(*) FILTER (WHERE ${pred})::int AS ${ident(`__den_${m.name}`)}`)
      zeroFillCols.push(`__num_${m.name}`, `__den_${m.name}`)
    } else if (m.ratio === 'expected_lesson_completions') {
      aggCols.push(`${metricAggSql(m, pred, tz)} AS ${ident(`__num_${m.name}`)}`)
      zeroFillCols.push(`__num_${m.name}`)
    } else {
      aggCols.push(`${metricAggSql(m, pred, tz)} AS ${ident(m.name)}`)
      if (m.agg !== 'avg_percent') zeroFillCols.push(m.name)
    }
  }

  const orderDir = input.orderBy?.dir === 'asc' ? 'ASC' : 'DESC'
  // Fetch one extra row to detect truncation.
  const limitSql = input.limit ? `LIMIT ${input.limit + 1}` : ''

  let sql: string
  if (timeDim && range) {
    const unit = timeDim.unit as string
    const bucketExpr = `date_trunc('${unit}', occurred_at AT TIME ZONE ${tz()})::date`
    const fromParam = p.add(range.fromDate)
    const toExParam = p.add(range.toExclusiveDate)
    const extraDim = columnDims[0]
    if (!extraDim) {
      // Single time series — zero-filled via generate_series (charts never
      // interpolate gaps).
      const outerCols = metrics
        .flatMap((m) => {
          const names =
            m.ratio === 'on_time'
              ? [`__num_${m.name}`, `__den_${m.name}`]
              : m.ratio === 'expected_lesson_completions'
                ? [`__num_${m.name}`]
                : [m.name]
          return names.map((n) =>
            zeroFillCols.includes(n)
              ? `COALESCE(agg.${ident(n)}, 0) AS ${ident(n)}`
              : `agg.${ident(n)} AS ${ident(n)}`
          )
        })
        .join(', ')
      sql = `
        WITH series AS (
          SELECT generate_series(
            date_trunc('${unit}', ${fromParam}::date::timestamp)::date,
            (${toExParam}::date - 1),
            interval '1 ${unit}'
          )::date AS bucket
        ),
        agg AS (
          SELECT ${bucketExpr} AS bucket, ${aggCols.join(', ')}
          FROM analytics_events
          ${whereSql}
          GROUP BY 1
        )
        SELECT to_char(series.bucket, 'YYYY-MM-DD') AS ${ident(timeDim.name)}, ${outerCols}
        FROM series
        LEFT JOIN agg USING (bucket)
        ORDER BY series.bucket`
    } else {
      // Time dim + a second dimension: plain grouped result, no zero-fill.
      sql = `
        SELECT to_char(${bucketExpr}, 'YYYY-MM-DD') AS ${ident(timeDim.name)},
               ${extraDim.column} AS ${ident(extraDim.name)},
               ${aggCols.join(', ')}
        FROM analytics_events
        ${whereSql}
        GROUP BY 1, 2
        ORDER BY 1, 2
        ${limitSql}`
    }
  } else if (columnDims.length > 0) {
    const dimCols = columnDims.map((d) => `${d.column} AS ${ident(d.name)}`)
    const groupBy = columnDims.map((_, i) => `${i + 1}`).join(', ')
    const orderBy = input.orderBy
      ? `ORDER BY ${ident(input.orderBy.metric)} ${orderDir} NULLS LAST`
      : `ORDER BY ${groupBy}`
    sql = `
      SELECT ${dimCols.join(', ')}, ${aggCols.join(', ')}
      FROM analytics_events
      ${whereSql}
      GROUP BY ${groupBy}
      ${orderBy}
      ${limitSql}`
  } else {
    sql = `SELECT ${aggCols.join(', ')} FROM analytics_events ${whereSql}`
  }

  let result: pg.QueryResult
  try {
    result = await getPool().query(sql, p.values)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    if (message.includes('canceling statement due to statement timeout')) {
      throw new AnalyticsQueryError(504, 'Analytics query timed out')
    }
    if (message.includes('time zone') && message.includes('not recognized')) {
      throw new AnalyticsQueryError(400, `Invalid timezone: ${input.timezone}`)
    }
    throw err
  }

  let rows = result.rows as Record<string, unknown>[]
  let truncated = false
  if (input.limit && rows.length > input.limit) {
    rows = rows.slice(0, input.limit)
    truncated = true
  }

  // Post-process ratio metrics (divide-by-zero → null, never Infinity/NaN).
  const externalRatios = metrics.filter((m) => m.ratio === 'expected_lesson_completions')
  const externalDenominators = new Map<string, number>()
  for (const m of externalRatios) {
    externalDenominators.set(m.name, await expectedLessonCompletions(input.filters, scope))
  }
  if (metrics.some((m) => m.type === 'ratio')) {
    rows = rows.map((row) => {
      const out: Record<string, unknown> = { ...row }
      for (const m of metrics) {
        if (m.ratio === 'on_time') {
          const num = Number(out[`__num_${m.name}`] ?? 0)
          const den = Number(out[`__den_${m.name}`] ?? 0)
          out[m.name] = den > 0 ? Math.round((num / den) * 10_000) / 10_000 : null
          delete out[`__num_${m.name}`]
          delete out[`__den_${m.name}`]
        } else if (m.ratio === 'expected_lesson_completions') {
          const num = Number(out[`__num_${m.name}`] ?? 0)
          const den = externalDenominators.get(m.name) ?? 0
          out[m.name] = den > 0 ? Math.round((num / den) * 10_000) / 10_000 : null
          delete out[`__num_${m.name}`]
        }
      }
      return out
    })
  }

  return { rows, truncated }
}

/**
 * Program-scoped engagement heatmap — the engagement.ts response shape
 * (day-of-week × hour buckets) computed against the flat layer. Used by the
 * Program Analytics tab wrapper; the caller must have already authorized
 * access to the program.
 */
export async function programEngagementHeatmap(
  studyProgramId: string,
  timezone: string,
  days: number
): Promise<{ day: number; hour: number; count: number }[]> {
  const start = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
  const result = await getPool().query<{ day: number; hour: number; count: number }>(
    `SELECT
       EXTRACT(DOW FROM occurred_at AT TIME ZONE $1)::int AS day,
       EXTRACT(HOUR FROM occurred_at AT TIME ZONE $1)::int AS hour,
       COUNT(*)::int AS count
     FROM analytics_events
     WHERE study_program_id = $2
       AND event_type = ANY($3::text[])
       AND occurred_at >= $4
     GROUP BY day, hour
     ORDER BY day, hour`,
    [timezone, studyProgramId, ENGAGEMENT_EVENT_TYPES, start]
  )
  return result.rows
}

/**
 * completion_rate denominator: Σ over in-scope enrollments of
 * (active group members × active lesson schedules). This reads transactional
 * tables — allowed, because it is a measure of CURRENT curriculum size
 * (presentation of expectation), not a re-derivation of event metrics.
 */
async function expectedLessonCompletions(
  filters: AnalyticsFilters,
  scope: AnalyticsScope
): Promise<number> {
  const p = new Params()
  const where: string[] = []
  if (!scope.all) {
    where.push(
      `(g."organizationId"::text = ANY(${p.add(scope.orgIds)}::text[]) OR e."groupId"::text = ANY(${p.add(scope.groupIds)}::text[]))`
    )
  }
  if (filters.organizationId) where.push(`g."organizationId"::text = ${p.add(filters.organizationId)}`)
  if (filters.groupId) where.push(`e."groupId"::text = ${p.add(filters.groupId)}`)
  if (filters.studyProgramId) where.push(`e."studyProgramId"::text = ${p.add(filters.studyProgramId)}`)
  if (filters.enrollmentId) where.push(`e.id::text = ${p.add(filters.enrollmentId)}`)

  const sql = `
    SELECT COALESCE(SUM(t.member_count * t.schedule_count), 0)::float8 AS expected
    FROM (
      SELECT
        (SELECT COUNT(*) FROM group_members gm
          WHERE gm."groupId" = e."groupId" AND gm."isActive" = true) AS member_count,
        (SELECT COUNT(*) FROM lesson_schedules ls
          WHERE ls."enrollmentId" = e.id AND ls."removedAt" IS NULL) AS schedule_count
      FROM enrollments e
      JOIN groups g ON g.id = e."groupId"
      ${where.length > 0 ? `WHERE ${where.join(' AND ')}` : ''}
    ) t`

  const result = await getPool().query<{ expected: number }>(sql, p.values)
  return result.rows[0]?.expected ?? 0
}
