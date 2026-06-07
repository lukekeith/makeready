/**
 * Engagement Analytics Routes
 *
 * Powers the leader dashboard heatmap + weekly activity charts (web + iPhone).
 *
 * Unlike `/api/activity-logs/stats*` (which aggregates the request/audit log),
 * these endpoints aggregate REAL study engagement from member progress:
 *   - activity completions  (member_activity_progress.completedAt)
 *   - video completions      (member_video_progress.completedAt)
 *   - study notes created    (study_notes.createdAt)
 *
 * All events are scoped to the groups the requesting leader owns
 * (group.creatorId === userId), via lesson_schedules → enrollments → group.
 * API-key callers (server-to-server) see every active group.
 *
 * Response shapes intentionally mirror the iPhone decode models
 * (HeatmapResponse / WeeklyStatsResponse) so the client needs no model changes.
 */

import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'

const router = Router()

const querySchema = z.object({
  // IANA timezone (e.g. "America/Chicago"). Buckets are computed in this zone.
  timezone: z.string().min(1).max(64).default('UTC'),
  // Trailing window size in days (the chart's "last N days").
  days: z.coerce.number().int().min(1).max(366).default(7),
  // Optional: restrict to a single group the leader owns.
  groupId: z.string().uuid().optional(),
})

/**
 * Resolve the set of group IDs whose engagement the caller may see.
 * Returns null when the caller may see ALL groups (API key).
 * Returns [] when the caller owns no groups.
 */
async function resolveLeaderGroupIds(
  req: any,
  requestedGroupId?: string
): Promise<string[] | null> {
  const isApiKey = !!req.apiKeyId
  const userId = (req.user as any)?.id

  if (requestedGroupId) {
    // Single group requested — confirm ownership unless API key.
    if (isApiKey) return [requestedGroupId]
    const owned = await prisma.group.findFirst({
      where: { id: requestedGroupId, creatorId: userId, isActive: true },
      select: { id: true },
    })
    return owned ? [owned.id] : []
  }

  if (isApiKey) return null // all groups

  const groups = await prisma.group.findMany({
    where: { creatorId: userId, isActive: true },
    select: { id: true },
  })
  return groups.map((g) => g.id)
}

/**
 * SQL UNION of every engagement event with its timestamp, scoped to groups.
 * Placeholders: $2 = window start (Date), $3 = group-id filter mode.
 *
 * When `scopeAll` is true the group filter is omitted (API-key callers).
 * Otherwise events are constrained to enrollments in the given group IDs,
 * passed as a uuid[] in `$3`.
 */
function engagementEventsSQL(scopeAll: boolean): string {
  const groupFilter = scopeAll ? '' : `AND e."groupId" = ANY($3::uuid[])`
  const noteGroupFilter = scopeAll
    ? ''
    : `AND e."groupId" = ANY($3::uuid[])`

  return `
    SELECT map."completedAt" AS ts
    FROM member_activity_progress map
    JOIN lesson_schedules ls ON ls.id = map."lessonScheduleId"
    JOIN enrollments e ON e.id = ls."enrollmentId"
    WHERE map."completedAt" IS NOT NULL
      AND map."completedAt" >= $2
      ${groupFilter}

    UNION ALL

    SELECT mvp."completedAt" AS ts
    FROM member_video_progress mvp
    JOIN lesson_schedules ls2 ON ls2.id = mvp."lessonScheduleId"
    JOIN enrollments e ON e.id = ls2."enrollmentId"
    WHERE mvp."completedAt" IS NOT NULL
      AND mvp."completedAt" >= $2
      ${groupFilter}

    UNION ALL

    SELECT sn."createdAt" AS ts
    FROM study_notes sn
    JOIN note_links nl ON nl."noteId" = sn.id AND nl."refType" = 'ENROLLMENT'
    JOIN enrollments e ON e.id = nl."refId"::uuid
    WHERE sn."isActive" = true
      AND sn."createdAt" >= $2
      ${noteGroupFilter}
  `
}

/**
 * @openapi
 * /api/engagement/heatmap:
 *   get:
 *     tags: [Engagement]
 *     summary: Study engagement by day-of-week and hour (leader dashboard heatmap)
 *     parameters:
 *       - in: query
 *         name: timezone
 *         schema: { type: string, default: UTC }
 *       - in: query
 *         name: days
 *         schema: { type: integer, default: 7 }
 *       - in: query
 *         name: groupId
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Heatmap buckets
 */
router.get('/heatmap', requireAuth, async (req, res) => {
  try {
    const parsed = querySchema.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parsed.error.errors,
      })
    }
    const { timezone, days, groupId } = parsed.data

    const groupIds = await resolveLeaderGroupIds(req, groupId)
    if (groupIds !== null && groupIds.length === 0) {
      return res.json({ success: true, data: [] })
    }

    const scopeAll = groupIds === null
    const start = new Date(Date.now() - days * 24 * 60 * 60 * 1000)

    const sql = `
      SELECT
        EXTRACT(DOW FROM ev.ts AT TIME ZONE 'UTC' AT TIME ZONE $1)::int AS day,
        EXTRACT(HOUR FROM ev.ts AT TIME ZONE 'UTC' AT TIME ZONE $1)::int AS hour,
        COUNT(*)::int AS count
      FROM ( ${engagementEventsSQL(scopeAll)} ) ev
      GROUP BY day, hour
      ORDER BY day, hour
    `

    const params: (string | Date | string[])[] = scopeAll
      ? [timezone, start]
      : [timezone, start, groupIds as string[]]

    const data = await prisma.$queryRawUnsafe<
      { day: number; hour: number; count: number }[]
    >(sql, ...params)

    res.json({ success: true, data })
  } catch (error) {
    console.error('Error fetching engagement heatmap:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch heatmap' })
  }
})

/**
 * @openapi
 * /api/engagement/weekly:
 *   get:
 *     tags: [Engagement]
 *     summary: Study engagement per day for the trailing window (leader dashboard bar chart)
 *     parameters:
 *       - in: query
 *         name: timezone
 *         schema: { type: string, default: UTC }
 *       - in: query
 *         name: days
 *         schema: { type: integer, default: 7 }
 *       - in: query
 *         name: groupId
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: One entry per day in the window (zero-filled)
 */
router.get('/weekly', requireAuth, async (req, res) => {
  try {
    const parsed = querySchema.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parsed.error.errors,
      })
    }
    const { timezone, days, groupId } = parsed.data

    const groupIds = await resolveLeaderGroupIds(req, groupId)
    if (groupIds !== null && groupIds.length === 0) {
      return res.json({ success: true, data: [] })
    }

    const scopeAll = groupIds === null
    // Pad the data window by a day so events near the local-midnight boundary
    // still fall inside the generated date series.
    const start = new Date(Date.now() - (days + 1) * 24 * 60 * 60 * 1000)

    // $1 timezone, $2 start, ($3 groupIds), $last days
    const daysParamIndex = scopeAll ? 3 : 4
    const sql = `
      WITH series AS (
        SELECT to_char(d, 'YYYY-MM-DD') AS date
        FROM generate_series(
          (now() AT TIME ZONE $1)::date - ($${daysParamIndex}::int - 1),
          (now() AT TIME ZONE $1)::date,
          interval '1 day'
        ) d
      ),
      events AS (
        SELECT to_char(ev.ts AT TIME ZONE 'UTC' AT TIME ZONE $1, 'YYYY-MM-DD') AS date
        FROM ( ${engagementEventsSQL(scopeAll)} ) ev
      )
      SELECT series.date, COUNT(events.date)::int AS count
      FROM series
      LEFT JOIN events ON events.date = series.date
      GROUP BY series.date
      ORDER BY series.date
    `

    const params: (string | Date | string[] | number)[] = scopeAll
      ? [timezone, start, days]
      : [timezone, start, groupIds as string[], days]

    const data = await prisma.$queryRawUnsafe<{ date: string; count: number }[]>(
      sql,
      ...params
    )

    res.json({ success: true, data })
  } catch (error) {
    console.error('Error fetching engagement weekly stats:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch weekly stats' })
  }
})

export default router
