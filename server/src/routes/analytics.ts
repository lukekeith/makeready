/**
 * Analytics Routes — the generic query layer + client event ingestion
 * (docs/features/analytics/architecture.md, event-ingestion.md).
 *
 *   POST /api/analytics/query    — registry-driven metric queries over the
 *                                  analytics_events matview (leaders/API key)
 *   GET  /api/analytics/meta     — machine-readable metric catalog
 *   POST /api/analytics/events   — batched client event ingestion (members on
 *                                  web, leaders on iPhone); fire-and-forget
 *                                  from the client's perspective
 *   POST /api/analytics/refresh  — manual refresh (super admin / API key)
 *
 * Authorization on /query is SCOPE INJECTION (Cube queryRewrite / Looker
 * access_filter pattern): the server derives the caller's entitled org/group
 * set via the canManageOrgContent family — NOT creatorId-only — and appends it
 * to every query; client filters can only narrow. Filters wholly outside the
 * entitled scope read as 404.
 */

import { Router, type Request, type Response, type NextFunction } from 'express'
import { z } from 'zod'
import rateLimit from 'express-rate-limit'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { getManageableOrgIds, isSuperAdmin, canManageGroupId } from '../services/permission.js'
import {
  AnalyticsQueryError,
  ensureFresh,
  getFreshness,
  refreshAnalytics,
  runAnalyticsQuery,
  type AnalyticsScope,
} from '../services/analytics.service.js'
import {
  CLIENT_EVENT_TYPES,
  DERIVED_EVENT_TYPES,
  DIMENSIONS,
  METRICS,
  RELATIVE_RANGES,
} from '../services/analytics-metrics.js'

const router = Router()

// Generous per-IP limits (README checklist 6): analytics must never be able to
// degrade OLTP, but normal dashboard/tab usage should never hit these.
const skipLimiter = () => process.env.NODE_ENV === 'test'
const queryLimiter = rateLimit({
  windowMs: 60_000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLimiter,
  message: { success: false, error: 'Too many analytics queries, please slow down' },
})
const ingestLimiter = rateLimit({
  windowMs: 60_000,
  max: 240,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipLimiter,
  message: { success: false, error: 'Too many event batches, please slow down' },
})

// ── Scope derivation ─────────────────────────────────────────────────────────

/**
 * The caller's entitled analytics scope. API keys and super admins see all;
 * everyone else sees orgs they own/hold a role in (getManageableOrgIds) plus
 * groups they personally created (creators can manage their own groups even
 * before an org role exists).
 */
async function deriveScope(req: Request): Promise<AnalyticsScope | null> {
  if (req.apiKeyId) return { all: true }
  const userId = (req.user as { id?: string } | undefined)?.id
  if (!userId) return null
  if (await isSuperAdmin(userId)) return { all: true }
  const [orgIds, ownGroups] = await Promise.all([
    getManageableOrgIds(userId),
    prisma.group.findMany({ where: { creatorId: userId, isActive: true }, select: { id: true } }),
  ])
  return { all: false, orgIds, groupIds: ownGroups.map((g) => g.id) }
}

/**
 * 404-style denial when an explicit org/group filter falls wholly outside the
 * entitled scope (existence must not leak). Filters INSIDE scope pass through;
 * the injected scope predicate still bounds everything else.
 */
async function filtersWithinScope(
  scope: AnalyticsScope,
  filters: { organizationId?: string; groupId?: string }
): Promise<boolean> {
  if (scope.all) return true
  if (filters.groupId) {
    if (!scope.groupIds.includes(filters.groupId)) {
      const group = await prisma.group.findFirst({
        where: { id: filters.groupId, organizationId: { in: scope.orgIds } },
        select: { id: true },
      })
      if (!group) return false
    }
  }
  if (filters.organizationId) {
    if (!scope.orgIds.includes(filters.organizationId)) {
      const entitledGroupInOrg =
        scope.groupIds.length > 0 &&
        (await prisma.group.findFirst({
          where: { id: { in: scope.groupIds }, organizationId: filters.organizationId },
          select: { id: true },
        }))
      if (!entitledGroupInOrg) return false
    }
  }
  return true
}

// ── POST /api/analytics/query ────────────────────────────────────────────────

const querySchema = z.object({
  metrics: z.array(z.string().min(1).max(64)).min(1).max(10),
  dimensions: z.array(z.string().min(1).max(64)).max(2).default([]),
  filters: z
    .object({
      organizationId: z.string().min(1).max(64).optional(),
      groupId: z.string().min(1).max(64).optional(),
      studyProgramId: z.string().min(1).max(64).optional(),
      enrollmentId: z.string().min(1).max(64).optional(),
      memberId: z.string().min(1).max(64).optional(),
      lessonScheduleId: z.string().min(1).max(64).optional(),
      activityType: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']).optional(),
      eventType: z.string().min(1).max(64).optional(),
      from: z.string().max(10).optional(),
      to: z.string().max(10).optional(),
      range: z.string().max(16).optional(),
    })
    .default({}),
  timezone: z.string().min(1).max(64).default('UTC'),
  limit: z.number().int().min(1).max(500).optional(),
  orderBy: z.object({ metric: z.string().min(1).max(64), dir: z.enum(['asc', 'desc']) }).optional(),
  compareToPrevious: z.boolean().optional(),
})

/**
 * @openapi
 * /api/analytics/query:
 *   post:
 *     tags: [Analytics]
 *     summary: Run registry metrics over the flat analytics layer
 *     description: >
 *       Generic analytics query — metrics and dimensions are registry entries
 *       (see GET /api/analytics/meta), never SQL. The caller's entitled
 *       org/group scope is injected server-side; filters can only narrow it.
 *       Snapshot-class metrics reject time windows. Response keys are
 *       additive-only (mobile contract).
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [metrics]
 *             properties:
 *               metrics: { type: array, items: { type: string }, example: ["engagement_events", "active_members"] }
 *               dimensions: { type: array, items: { type: string }, example: ["day"] }
 *               filters:
 *                 type: object
 *                 properties:
 *                   studyProgramId: { type: string }
 *                   groupId: { type: string }
 *                   organizationId: { type: string }
 *                   enrollmentId: { type: string }
 *                   memberId: { type: string }
 *                   from: { type: string, example: "2026-07-01" }
 *                   to: { type: string, example: "2026-07-29" }
 *                   range: { type: string, enum: [last_7d, last_30d, last_12mo] }
 *               timezone: { type: string, example: "America/Chicago" }
 *               limit: { type: integer, maximum: 500 }
 *               orderBy:
 *                 type: object
 *                 properties:
 *                   metric: { type: string }
 *                   dir: { type: string, enum: [asc, desc] }
 *               compareToPrevious: { type: boolean }
 *     responses:
 *       200:
 *         description: Rows plus freshAsOf and the resolved query echo
 */
router.post('/query', requireAuth, queryLimiter, async (req, res) => {
  try {
    const parsed = querySchema.safeParse(req.body)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query',
        details: parsed.error.errors,
      })
    }

    const scope = await deriveScope(req)
    if (!scope) {
      return res.status(401).json({ success: false, error: 'Not authenticated' })
    }
    if (!(await filtersWithinScope(scope, parsed.data.filters))) {
      return res.status(404).json({ success: false, error: 'Not found' })
    }

    const result = await runAnalyticsQuery(parsed.data, scope)
    res.json({ success: true, ...result })
  } catch (error) {
    if (error instanceof AnalyticsQueryError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    console.error('Error running analytics query:', error)
    res.status(500).json({ success: false, error: 'Failed to run analytics query' })
  }
})

// ── GET /api/analytics/meta ──────────────────────────────────────────────────

/**
 * @openapi
 * /api/analytics/meta:
 *   get:
 *     tags: [Analytics]
 *     summary: Machine-readable metric catalog (registry serialization)
 *     responses:
 *       200:
 *         description: Metrics, dimensions, event types, ranges, freshness
 */
router.get('/meta', requireAuth, async (_req, res) => {
  try {
    const freshness = await getFreshness()
    res.json({
      success: true,
      freshAsOf: freshness.freshAsOf,
      metrics: METRICS.map((m) => ({
        name: m.name,
        label: m.label,
        description: m.description,
        format: m.format,
        type: m.type,
        class: m.class,
        versionSemantics: m.versionSemantics,
        eventTypes: m.eventTypes,
        dimensionsAllowed: m.dimensionsAllowed,
      })),
      dimensions: DIMENSIONS.map((d) => ({
        name: d.name,
        kind: d.kind,
        ...(d.unit ? { unit: d.unit } : {}),
        highCardinality: d.highCardinality,
      })),
      eventTypes: {
        derived: DERIVED_EVENT_TYPES,
        client: CLIENT_EVENT_TYPES,
      },
      ranges: Object.entries(RELATIVE_RANGES).map(([name, r]) => ({
        name,
        days: r.days,
        label: r.label,
      })),
    })
  } catch (error) {
    console.error('Error serving analytics meta:', error)
    res.status(500).json({ success: false, error: 'Failed to load analytics meta' })
  }
})

// ── POST /api/analytics/events — client event ingestion ─────────────────────

/**
 * Accepts member phone-sessions (web lesson player), leader sessions (iPhone),
 * or API keys. Actor identity comes from the session, never the payload.
 */
function requireAnySession(req: Request, res: Response, next: NextFunction) {
  if (req.session?.memberId) return next()
  if (req.user && req.apiKeyId) return next()
  if (req.isAuthenticated && req.isAuthenticated()) return next()
  return res.status(401).json({ success: false, error: 'Not authenticated' })
}

const OCCURRED_AT_PAST_MS = 48 * 60 * 60 * 1000 // offline buffer replay allowed
const OCCURRED_AT_FUTURE_MS = 5 * 60 * 1000 // clock nonsense rejected

const ingestEventSchema = z.object({
  id: z.string().uuid(),
  eventType: z.string().min(1).max(64),
  occurredAt: z.coerce.date(),
  enrollmentId: z.string().min(1).max(64).optional(),
  lessonScheduleId: z.string().min(1).max(64).optional(),
  scheduledActivityId: z.string().min(1).max(64).optional(),
  value: z.number().finite().min(0).max(1e9).optional(),
  metadata: z.record(z.unknown()).optional(),
})

const ingestSchema = z.object({
  events: z.array(ingestEventSchema).min(1).max(50),
})

/**
 * @openapi
 * /api/analytics/events:
 *   post:
 *     tags: [Analytics]
 *     summary: Ingest a batch of client-instrumented analytics events
 *     description: >
 *       Batched (max 50), idempotent on the client-generated event id, and
 *       fire-and-forget from the client's perspective. Event types must be
 *       registered client-instrumented types; the server enriches
 *       org/group/program dimensions from the narrow ids and validates them
 *       against the session's scope.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [events]
 *             properties:
 *               events:
 *                 type: array
 *                 maxItems: 50
 *                 items:
 *                   type: object
 *                   required: [id, eventType, occurredAt]
 *                   properties:
 *                     id: { type: string, format: uuid }
 *                     eventType: { type: string, example: LESSON_OPENED }
 *                     occurredAt: { type: string, format: date-time }
 *                     enrollmentId: { type: string }
 *                     lessonScheduleId: { type: string }
 *                     scheduledActivityId: { type: string }
 *                     value: { type: number }
 *                     metadata: { type: object }
 *     responses:
 *       200:
 *         description: Accepted/rejected counts
 *       400:
 *         description: Invalid payload or unregistered event type
 */
router.post('/events', requireAnySession, ingestLimiter, async (req, res) => {
  try {
    const parsed = ingestSchema.safeParse(req.body)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid events payload',
        details: parsed.error.errors,
      })
    }
    const { events } = parsed.data

    // Registration enforcement — THE tracking-plan gate. Unknown types are a
    // 400 so a mis-instrumented client is loud in development, and derived
    // types are never accepted here (an event type lives in exactly one arm).
    const clientTypes = new Set<string>(CLIENT_EVENT_TYPES)
    const unknownTypes = [...new Set(events.map((e) => e.eventType))].filter(
      (t) => !clientTypes.has(t)
    )
    if (unknownTypes.length > 0) {
      return res.status(400).json({
        success: false,
        error: `Unregistered event type(s): ${unknownTypes.join(', ')}. Register the type in analytics-metrics.ts (CLIENT_EVENT_TYPES) first.`,
      })
    }

    // Actor from the session — spoof-proof by construction.
    const sessionMemberId = req.session?.memberId ?? null
    const sessionUserId = sessionMemberId
      ? null
      : ((req.user as { id?: string } | undefined)?.id ?? null)
    const isPrivileged =
      !!req.apiKeyId ||
      (sessionUserId ? await isSuperAdmin(sessionUserId) : false)
    if (!sessionMemberId && !sessionUserId) {
      return res.status(401).json({ success: false, error: 'Not authenticated' })
    }

    // Batch-resolve enrichment context from the narrow ids the client sent —
    // the client can never mislabel org/group/program dimensions.
    const saIds = [...new Set(events.map((e) => e.scheduledActivityId).filter(Boolean))] as string[]
    const activities =
      saIds.length > 0
        ? await prisma.scheduledLessonActivity.findMany({
            where: { id: { in: saIds } },
            select: { id: true, type: true, lessonScheduleId: true },
          })
        : []
    const activityById = new Map(activities.map((a) => [a.id, a]))

    const lsIds = [
      ...new Set(
        events
          .map((e) => e.lessonScheduleId ?? activityById.get(e.scheduledActivityId ?? '')?.lessonScheduleId)
          .filter(Boolean)
      ),
    ] as string[]
    const schedules =
      lsIds.length > 0
        ? await prisma.lessonSchedule.findMany({
            where: { id: { in: lsIds } },
            select: {
              id: true,
              enrollmentId: true,
              lessonId: true,
              scheduledDate: true,
              lesson: { select: { dayNumber: true } },
            },
          })
        : []
    const scheduleById = new Map(schedules.map((s) => [s.id, s]))

    const enrollmentIds = [
      ...new Set(
        events
          .map((e) => {
            const lsId =
              e.lessonScheduleId ?? activityById.get(e.scheduledActivityId ?? '')?.lessonScheduleId
            return e.enrollmentId ?? (lsId ? scheduleById.get(lsId)?.enrollmentId : undefined)
          })
          .filter(Boolean)
      ),
    ] as string[]
    const enrollments =
      enrollmentIds.length > 0
        ? await prisma.enrollment.findMany({
            where: { id: { in: enrollmentIds } },
            select: {
              id: true,
              groupId: true,
              studyProgramId: true,
              group: { select: { organizationId: true } },
            },
          })
        : []
    const enrollmentById = new Map(enrollments.map((e) => [e.id, e]))

    // Scope validation: which of the referenced groups may this session write
    // events against?
    const groupIds = [...new Set(enrollments.map((e) => e.groupId))]
    const allowedGroupIds = new Set<string>()
    if (isPrivileged) {
      groupIds.forEach((id) => allowedGroupIds.add(id))
    } else if (sessionMemberId && groupIds.length > 0) {
      const memberships = await prisma.groupMember.findMany({
        where: { memberId: sessionMemberId, groupId: { in: groupIds }, isActive: true },
        select: { groupId: true },
      })
      memberships.forEach((m) => allowedGroupIds.add(m.groupId))
    } else if (sessionUserId) {
      for (const groupId of groupIds) {
        if (await canManageGroupId(sessionUserId, groupId)) allowedGroupIds.add(groupId)
      }
    }

    const now = Date.now()
    const minOccurred = now - OCCURRED_AT_PAST_MS
    const maxOccurred = now + OCCURRED_AT_FUTURE_MS

    const rows: {
      id: string
      eventType: string
      occurredAt: Date
      memberId: string | null
      userId: string | null
      organizationId: string | null
      groupId: string | null
      enrollmentId: string | null
      studyProgramId: string | null
      lessonScheduleId: string | null
      lessonId: string | null
      dayNumber: number | null
      scheduledActivityId: string | null
      activityType: string | null
      scheduledDate: Date | null
      value: number
      metadata?: object
    }[] = []
    let rejected = 0

    for (const event of events) {
      // Oversized metadata is rejected rather than truncated (pressure valve,
      // not a dumping ground).
      if (event.metadata && JSON.stringify(event.metadata).length > 4000) {
        rejected++
        continue
      }

      const activity = event.scheduledActivityId
        ? activityById.get(event.scheduledActivityId)
        : undefined
      if (event.scheduledActivityId && !activity) {
        rejected++
        continue
      }

      const lessonScheduleId = event.lessonScheduleId ?? activity?.lessonScheduleId ?? null
      const schedule = lessonScheduleId ? scheduleById.get(lessonScheduleId) : undefined
      if (lessonScheduleId && !schedule) {
        rejected++
        continue
      }
      // The narrow ids must agree with each other.
      if (activity && event.lessonScheduleId && activity.lessonScheduleId !== event.lessonScheduleId) {
        rejected++
        continue
      }

      const enrollmentId = event.enrollmentId ?? schedule?.enrollmentId ?? null
      const enrollment = enrollmentId ? enrollmentById.get(enrollmentId) : undefined
      if (enrollmentId && !enrollment) {
        rejected++
        continue
      }
      if (schedule && event.enrollmentId && schedule.enrollmentId !== event.enrollmentId) {
        rejected++
        continue
      }

      // Events carrying enrollment context must belong to a group the session
      // may write against.
      if (enrollment && !allowedGroupIds.has(enrollment.groupId)) {
        rejected++
        continue
      }

      // Clamp the client clock into [received - 48h, received + 5min].
      const occurredMs = Math.min(Math.max(event.occurredAt.getTime(), minOccurred), maxOccurred)

      rows.push({
        id: event.id,
        eventType: event.eventType,
        occurredAt: new Date(occurredMs),
        memberId: sessionMemberId,
        userId: sessionUserId,
        organizationId: enrollment?.group.organizationId ?? null,
        groupId: enrollment?.groupId ?? null,
        enrollmentId,
        studyProgramId: enrollment?.studyProgramId ?? null,
        lessonScheduleId,
        lessonId: schedule?.lessonId ?? null,
        dayNumber: schedule?.lesson?.dayNumber ?? null,
        scheduledActivityId: event.scheduledActivityId ?? null,
        activityType: activity?.type ?? null,
        scheduledDate: schedule?.scheduledDate ?? null,
        value: event.value ?? 1,
        ...(event.metadata ? { metadata: event.metadata as object } : {}),
      })
    }

    // skipDuplicates makes retried batches (same client UUIDs) idempotent.
    let accepted = 0
    if (rows.length > 0) {
      const result = await prisma.clientEvent.createMany({ data: rows, skipDuplicates: true })
      accepted = result.count
    }

    res.json({ success: true, accepted, rejected })
  } catch (error) {
    console.error('Error ingesting analytics events:', error)
    res.status(500).json({ success: false, error: 'Failed to ingest events' })
  }
})

// ── POST /api/analytics/refresh — manual ops refresh ────────────────────────

/**
 * @openapi
 * /api/analytics/refresh:
 *   post:
 *     tags: [Analytics]
 *     summary: Manually refresh the analytics_events materialized view (super admin / API key)
 *     responses:
 *       200:
 *         description: Refresh result + freshness telemetry
 */
router.post('/refresh', requireAuth, async (req, res) => {
  try {
    const user = req.user as { id?: string; isSuperAdmin?: boolean } | undefined
    if (!user?.isSuperAdmin && !req.apiKeyId) {
      return res.status(403).json({ success: false, error: 'Forbidden' })
    }
    const result = await refreshAnalytics()
    const freshness = await ensureFresh()
    res.json({ success: true, result, freshness })
  } catch (error) {
    console.error('Error refreshing analytics:', error)
    res.status(500).json({ success: false, error: 'Failed to refresh analytics' })
  }
})

export default router
