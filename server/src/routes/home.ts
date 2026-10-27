/**
 * Home dashboard routes (docs/features/home-dashboard-data/SPEC.md §Contract) —
 * the iPhone UI 2.0 Home's per-member computations, beside the frozen
 * /api/analytics/query contract (D5). Thin: logic lives in services/home-*.ts.
 *
 *   GET /api/home/sessions?range=&tz=&organizationId=
 *   GET /api/home/days?from=&to=&tz=&organizationId=&memberId=
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
import { canViewMember, visibleMemberOrgIds } from '../services/member-access.js'
import { findManageableGroup } from '../services/permission.js'

const router = Router()

const organizationId = z.string().min(1).max(64).optional()
const tz = z.string().min(1).max(64).default('UTC')
const sessionsQuery = z.object({ range: z.enum(['all', 'year', 'month', 'week']), tz, organizationId })
const daysQuery = z.object({
  from: z.string().max(10),
  to: z.string().max(10),
  tz,
  organizationId,
  // ui2-members-browse D12: declared, or z.object strips it and the rail would read the whole org.
  memberId: z.string().min(1).max(64).optional(),
  // ui2-groups-browse D14: declared, or z.object strips it and the group rail would read the whole org.
  groupId: z.string().min(1).max(64).optional(),
})
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
 *       200: { description: "{ averageSeconds, sessionCount, hourly[24] (sessions active per local hour), bins[88] (sessions per length band), ticks[≤4 minutes], axisMinutes }" }
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
 *     summary: Per-day session seconds, 12 two-hour blocks and the last activity time, for the Home day cards and the member page's day rail (iPhone)
 *     parameters:
 *       - { in: query, name: from, required: true, schema: { type: string, example: "2026-09-27" } }
 *       - { in: query, name: to, required: true, schema: { type: string, example: "2026-11-01" } }
 *       - { in: query, name: tz, schema: { type: string } }
 *       - { in: query, name: organizationId, schema: { type: string } }
 *       - { in: query, name: memberId, schema: { type: string }, description: "Only this member's sessions; 404 outside the caller's member scope" }
 *       - { in: query, name: groupId, schema: { type: string }, description: "Only sessions of this group's active members; 404 unless the caller manages the group; 400 with memberId" }
 *     responses:
 *       200: { description: "{ days: [{ day, sessionSeconds, blocks[12], lastActivityAt (ISO|null) }] } — every day, zero-filled" }
 *       400: { description: Bad dates, more than 62 days, bad timezone or an empty memberId }
 *       404: { description: Empty scope, or memberId outside the caller's member scope }
 */
router.get('/days', requireAuth, async (req, res) => {
  try {
    const parsed = daysQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    const rangeError = validateDayRange(parsed.data.from, parsed.data.to)
    if (rangeError) return res.status(400).json({ success: false, error: rangeError })
    if (parsed.data.memberId && parsed.data.groupId) {
      return res.status(400).json({ success: false, error: 'memberId and groupId cannot be combined' })
    }
    assertValidTimezone(parsed.data.tz)
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    const { from, to, memberId, groupId, organizationId: orgId } = parsed.data
    if (groupId) {
      // D14: the caller must manage the group (groupManageFilter + isActive); an API-key caller has no user id.
      const groupUserId = callerOf(req).userId
      if (!groupUserId || !(await findManageableGroup(groupUserId, groupId))) {
        res.status(404).json({ success: false, error: 'Not found' })
        return
      }
      res.json(await getHomeDays(scope, from, to, parsed.data.tz, { groupId }))
      return
    }
    if (!memberId) {
      res.json(await getHomeDays(scope, from, to, parsed.data.tz))
      return
    }
    // D7 is checked here, not taken from the D9 scope (which gives a role-holding Group Leader the whole org).
    const userId = callerOf(req).userId
    if (!userId) {
      res.status(404).json({ success: false, error: 'Not found' })
      return
    }
    let readScope = scope
    if (orgId) {
      if (!(await canViewMember(userId, memberId, orgId))) {
        res.status(404).json({ success: false, error: 'Not found' })
        return
      }
    } else {
      // No organizationId: read only the orgs where the caller may see this member, never the whole D9 scope.
      const visibleOrgIds = await visibleMemberOrgIds({ kind: 'user', userId }, memberId)
      if (visibleOrgIds.length === 0) {
        res.status(404).json({ success: false, error: 'Not found' })
        return
      }
      readScope = { all: false, orgIds: visibleOrgIds, groupIds: [] }
    }
    res.json(await getHomeDays(readScope, from, to, parsed.data.tz, { memberId }))
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
