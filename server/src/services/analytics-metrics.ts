/**
 * Analytics metric & dimension registry.
 *
 * The API contract for POST /api/analytics/query (docs/features/analytics/
 * metrics-catalog.md). Metrics and dimensions are REGISTRY ENTRIES, not routes:
 * adding a metric = one entry here, no new query plumbing. Names are
 * additive-only — never rename or remove (iPhone builds live for months).
 *
 * Every metric is an aggregate over the flat `analytics_events` materialized
 * view; every filter is a plain column. The registry is whitelist-only — the
 * client can never inject SQL; zod validates every name against this file.
 */

// ── Event types ──────────────────────────────────────────────────────────────

/**
 * Event types produced by the DERIVED view arms (projected from OLTP truth).
 * Never accepted from the ingestion endpoint — an event type lives in exactly
 * one arm, and these are already recorded by the transactional tables.
 */
export const DERIVED_EVENT_TYPES = [
  'ACTIVITY_COMPLETED',
  'VIDEO_COMPLETED',
  'VIDEO_WATCH',
  'LESSON_COMPLETED',
  'NOTE_CREATED',
  'ENROLLMENT_CREATED',
  'MEMBER_JOINED',
] as const

/**
 * Client-instrumented event types accepted by POST /api/analytics/events
 * (the `ce:` view arm). Registering a type HERE is how a feature "latches on"
 * to the engine — unknown types are rejected (400) at ingest, which is the
 * tracking-plan discipline. Naming convention (locked): past-tense
 * OBJECT_ACTION SCREAMING_SNAKE.
 *
 * Registration of member-behavior events beyond opens/starts requires owner
 * sign-off (event-ingestion.md § What this does NOT change).
 */
export const CLIENT_EVENT_TYPES = [
  // Emitted by the web lesson player from Phase B; registered now so the
  // ingestion pipe is complete end-to-end.
  'LESSON_OPENED',
  'ACTIVITY_STARTED',
] as const

/** Accepted values for the post-refresh quality check and /meta catalog. */
export const ALL_EVENT_TYPES = [...DERIVED_EVENT_TYPES, ...CLIENT_EVENT_TYPES]

// ── Metrics ──────────────────────────────────────────────────────────────────

/**
 * flow      = instant events; SUM/COUNT over a time window is meaningful.
 * snapshot  = cumulative state (one row per member×activity, value = lifetime
 *             total, occurred_at = last touch). Valid ONLY unwindowed — the
 *             query endpoint rejects from/to/range and time dimensions for
 *             snapshot metrics. Do not fake a time series from snapshots.
 */
export type MetricClass = 'flow' | 'snapshot'

/**
 * all          = full history, incl. old lesson versions and soft-removed
 *                schedules (history survives program syncs / study swaps).
 * current-only = is_current_version AND NOT is_removed (describes the current
 *                curriculum).
 */
export type VersionSemantics = 'all' | 'current-only'

export type MetricAgg =
  | 'count'
  | 'count_distinct_entity'
  | 'sum_value'
  | 'avg_percent'
  | 'count_distinct_day' // COUNT(DISTINCT local calendar date) — timezone-aware

export interface MetricDef {
  name: string
  label: string
  description: string
  /** Display hint for clients ('count' | 'seconds' | 'percent' | 'chars'). */
  format: 'count' | 'seconds' | 'percent' | 'chars'
  type: 'simple' | 'ratio'
  class: MetricClass
  versionSemantics: VersionSemantics
  /** Event types the aggregate runs over (empty = every event type). */
  eventTypes: string[]
  /** Aggregate for simple metrics, and the numerator of view-based ratios. */
  agg?: MetricAgg
  /**
   * Ratio metrics: how the ratio is computed. Ratios are first-class and
   * server-side with divide-by-zero handling — clients never divide two
   * metrics themselves (that's how definitions drift).
   *
   * 'on_time'     — numerator = events with occurred_at within 1 local day of
   *                 scheduled_date, denominator = all matching events. Both
   *                 sides window/group normally.
   * 'expected_lesson_completions' — denominator = Σ over in-scope enrollments
   *                 of (active group members × active lesson schedules),
   *                 computed against the transactional tables (a presentation
   *                 of curriculum size, not an event aggregate). Not groupable.
   */
  ratio?: 'on_time' | 'expected_lesson_completions'
  /** False for ratios whose denominator cannot be grouped (completion_rate). */
  dimensionsAllowed: boolean
}

/** The "total activity" event set — shared by engagement_events/active_members
 *  and the program heatmap (mirrors the Home dashboard's semantics). */
export const ENGAGEMENT_EVENT_TYPES = ['ACTIVITY_COMPLETED', 'VIDEO_COMPLETED', 'NOTE_CREATED']

export const METRICS: MetricDef[] = [
  {
    name: 'engagement_events',
    label: 'Total activity',
    description:
      'Every engagement event — activity completions, video completions, and notes. Matches the Home dashboard heatmap semantics.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ENGAGEMENT_EVENT_TYPES,
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'completions',
    label: 'Completions',
    description: 'Content completions (activities + videos) against the current curriculum.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'current-only',
    eventTypes: ['ACTIVITY_COMPLETED', 'VIDEO_COMPLETED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'lesson_completions',
    label: 'Lessons completed',
    description: 'Whole lessons completed (all activities done) against the current curriculum.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'current-only',
    eventTypes: ['LESSON_COMPLETED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'active_members',
    label: 'Active members',
    description:
      'Distinct people with any engagement event. "Members reached" when unbounded; "active members" when time-filtered.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ENGAGEMENT_EVENT_TYPES,
    agg: 'count_distinct_entity',
    dimensionsAllowed: true,
  },
  {
    name: 'completion_rate',
    label: 'Completion rate',
    description:
      'Lesson completions ÷ expected completions (per enrollment: active members × active lesson schedules, summed). Every surface shares this one definition.',
    format: 'percent',
    type: 'ratio',
    // Snapshot classification: the denominator is the CURRENT curriculum size,
    // so a time-windowed rate would divide windowed completions by an
    // unwindowed expectation — silently wrong. Windows are rejected.
    class: 'snapshot',
    versionSemantics: 'current-only',
    eventTypes: ['LESSON_COMPLETED'],
    agg: 'count',
    ratio: 'expected_lesson_completions',
    dimensionsAllowed: false,
  },
  {
    name: 'notes_written',
    label: 'Notes written',
    description: 'Study notes written against enrollments.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ['NOTE_CREATED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'content_chars',
    label: 'Characters written',
    description: 'Writing depth — total characters across study notes.',
    format: 'chars',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ['NOTE_CREATED'],
    agg: 'sum_value',
    dimensionsAllowed: true,
  },
  {
    name: 'active_days',
    label: 'Active days',
    description:
      'Distinct local calendar days with at least one engagement event — a consistency proxy.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ENGAGEMENT_EVENT_TYPES,
    agg: 'count_distinct_day',
    dimensionsAllowed: true,
  },
  {
    name: 'on_time_rate',
    label: 'On-time rate',
    description:
      'Share of lesson completions finished within one day of the scheduled date.',
    format: 'percent',
    type: 'ratio',
    class: 'flow',
    versionSemantics: 'current-only',
    eventTypes: ['LESSON_COMPLETED'],
    agg: 'count',
    ratio: 'on_time',
    dimensionsAllowed: true,
  },
  {
    name: 'video_completions',
    label: 'Video completions',
    description: 'Videos watched to completion (≥90%).',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'current-only',
    eventTypes: ['VIDEO_COMPLETED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'watch_seconds',
    label: 'Watch time',
    description:
      'Lifetime video watch time in seconds (cumulative snapshot — not windowable). Format h/m client-side.',
    format: 'seconds',
    type: 'simple',
    class: 'snapshot',
    versionSemantics: 'all',
    eventTypes: ['VIDEO_WATCH'],
    agg: 'sum_value',
    dimensionsAllowed: true,
  },
  {
    name: 'avg_watch_percent',
    label: 'Average watch depth',
    description: 'Average percentage watched across started videos (cumulative snapshot).',
    format: 'percent',
    type: 'simple',
    class: 'snapshot',
    versionSemantics: 'all',
    eventTypes: ['VIDEO_WATCH'],
    agg: 'avg_percent',
    dimensionsAllowed: true,
  },
  {
    name: 'enrollments_created',
    label: 'Enrollments created',
    description: 'Groups enrolled in a study program — the growth line.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ['ENROLLMENT_CREATED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
  {
    name: 'members_joined',
    label: 'Members joined',
    description: 'Members added to, approved into, or rejoining a group.',
    format: 'count',
    type: 'simple',
    class: 'flow',
    versionSemantics: 'all',
    eventTypes: ['MEMBER_JOINED'],
    agg: 'count',
    dimensionsAllowed: true,
  },
]

export const METRICS_BY_NAME = new Map(METRICS.map((m) => [m.name, m]))

// ── Dimensions ───────────────────────────────────────────────────────────────

export interface DimensionDef {
  name: string
  /** View column, or 'time' for query-time timezone-aware bucketing. */
  kind: 'column' | 'time'
  column?: string
  /** Time dimensions: the date_trunc unit. */
  unit?: 'day' | 'week' | 'month'
  /**
   * High-cardinality groupings require an explicit limit (max 500) and an
   * orderBy so a top-N never silently under-reports (results carry
   * `truncated: true` when capped).
   */
  highCardinality: boolean
}

export const DIMENSIONS: DimensionDef[] = [
  { name: 'day', kind: 'time', unit: 'day', highCardinality: false },
  { name: 'week', kind: 'time', unit: 'week', highCardinality: false },
  { name: 'month', kind: 'time', unit: 'month', highCardinality: false },
  { name: 'organization_id', kind: 'column', column: 'organization_id', highCardinality: false },
  { name: 'group_id', kind: 'column', column: 'group_id', highCardinality: false },
  { name: 'study_program_id', kind: 'column', column: 'study_program_id', highCardinality: false },
  { name: 'enrollment_id', kind: 'column', column: 'enrollment_id', highCardinality: true },
  { name: 'member_id', kind: 'column', column: 'member_id', highCardinality: true },
  { name: 'lesson_schedule_id', kind: 'column', column: 'lesson_schedule_id', highCardinality: true },
  { name: 'lesson_id', kind: 'column', column: 'lesson_id', highCardinality: true },
  { name: 'day_number', kind: 'column', column: 'day_number', highCardinality: false },
  { name: 'scheduled_activity_id', kind: 'column', column: 'scheduled_activity_id', highCardinality: true },
  { name: 'activity_type', kind: 'column', column: 'activity_type', highCardinality: false },
  { name: 'event_type', kind: 'column', column: 'event_type', highCardinality: false },
]

export const DIMENSIONS_BY_NAME = new Map(DIMENSIONS.map((d) => [d.name, d]))

// ── Relative ranges ──────────────────────────────────────────────────────────

/**
 * Server-resolved relative ranges, computed in the query timezone — clients
 * never do date math. Each spans N local calendar days ending today.
 */
export const RELATIVE_RANGES: Record<string, { days: number; label: string }> = {
  last_7d: { days: 7, label: 'Last 7 days' },
  last_30d: { days: 30, label: 'Last 30 days' },
  last_12mo: { days: 365, label: 'Last 12 months' },
}
