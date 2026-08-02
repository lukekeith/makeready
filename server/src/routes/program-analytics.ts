/**
 * Program Analytics wrapper — GET /api/programs/:programId/analytics
 *
 * Assembles the iPhone Program Home Analytics tab payload in one round trip
 * (docs/features/analytics/program-analytics-tab.md § Data contract): several
 * registry queries + the engagement-shaped heatmap, all computed against the
 * flat analytics_events layer — never the transactional tables. The wrapper
 * only touches transactional tables for PRESENTATION metadata (enrollment
 * counts here; names/avatars in Phase C), which the architecture explicitly
 * allows.
 *
 * Phase B1 scope: kpis + recent (week/month/year) + heatmap. funnel /
 * contentMix / topMembers / topEnrollments return [] until Phase C1.
 *
 * Response keys are additive-only (mobile contract — iPhone builds live for
 * months).
 */

import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { canManageOrgContent } from '../services/permission.js'
import {
  runAnalyticsQuery,
  programEngagementHeatmap,
  todayInTimezone,
  AnalyticsQueryError,
} from '../services/analytics.service.js'

const router = Router()

const querySchema = z.object({
  timezone: z.string().min(1).max(64).default('UTC'),
  // Heatmap trailing window (the tab shows "Last 30 days" — denser than the
  // dashboard's 7 at program scale).
  days: z.coerce.number().int().min(1).max(366).default(30),
})

/** First day of the month `monthsBack` months before the given local date. */
function firstOfMonthBack(localDate: string, monthsBack: number): string {
  const [y, m] = localDate.split('-').map(Number)
  const index = y * 12 + (m - 1) - monthsBack
  const year = Math.floor(index / 12)
  const month = (index % 12) + 1
  return `${year}-${String(month).padStart(2, '0')}-01`
}

/**
 * @openapi
 * /api/programs/{programId}/analytics:
 *   get:
 *     tags: [Analytics]
 *     summary: Assembled analytics payload for the Program Home Analytics tab
 *     description: >
 *       One round trip bundling the KPI registry queries, the pre-zero-filled
 *       Week/Month/Year activity series, and the engagement heatmap, all
 *       program-scoped against the flat analytics layer. Org-scoped access
 *       (creator, org owner, org role-holder, super admin, or API key).
 *     parameters:
 *       - in: path
 *         name: programId
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: timezone
 *         schema: { type: string, default: UTC }
 *       - in: query
 *         name: days
 *         schema: { type: integer, default: 30 }
 *     responses:
 *       200:
 *         description: kpis, recent series, heatmap, freshAsOf (funnel/mix/tops empty until Phase C)
 *       404:
 *         description: Program not found or not accessible
 */
router.get('/programs/:programId/analytics', requireAuth, async (req, res) => {
  try {
    const { programId } = req.params
    const parsed = querySchema.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: parsed.error.errors,
      })
    }
    const { timezone, days } = parsed.data

    // Org-scoped access, same rule as the program's other nested resources:
    // creator, org owner, any org role-holder, super admin, or API key.
    // A program outside that reads as 404.
    const program = await prisma.studyProgram.findFirst({
      where: { id: programId, isActive: true },
      select: { id: true, organizationId: true, creatorId: true },
    })
    if (!program) {
      return res.status(404).json({ success: false, error: 'Program not found' })
    }
    if (!req.apiKeyId) {
      const userId = (req.user as { id?: string } | undefined)?.id
      if (!userId || !(await canManageOrgContent(userId, program.organizationId, program.creatorId))) {
        return res.status(404).json({ success: false, error: 'Program not found' })
      }
    }

    // Queries below run with all-scope: access to the WHOLE program was just
    // authorized, and every query is pinned to studyProgramId.
    const scope = { all: true } as const
    const filters = { studyProgramId: programId }

    // Exactly 12 monthly points: from the first of the month 11 months back
    // through today (a plain 365-day window would straddle 13 calendar months).
    const today = todayInTimezone(timezone)
    const yearFrom = firstOfMonthBack(today, 11)

    const [kpiQ, weekQ, monthQ, yearQ, heatmap, totalEnrollments, activeEnrollments, groupCompletionsQ, groupStats] =
      await Promise.all([
        runAnalyticsQuery(
          {
            metrics: [
              'active_members',
              'lesson_completions',
              'completion_rate',
              'video_completions',
              'watch_seconds',
              'avg_watch_percent',
            ],
            dimensions: [],
            filters,
            timezone,
          },
          scope
        ),
        runAnalyticsQuery(
          {
            metrics: ['engagement_events'],
            dimensions: ['day'],
            filters: { ...filters, range: 'last_7d' },
            timezone,
          },
          scope
        ),
        runAnalyticsQuery(
          {
            metrics: ['engagement_events'],
            dimensions: ['day'],
            filters: { ...filters, range: 'last_30d' },
            timezone,
          },
          scope
        ),
        runAnalyticsQuery(
          {
            metrics: ['engagement_events'],
            dimensions: ['month'],
            filters: { ...filters, from: yearFrom, to: today },
            timezone,
          },
          scope
        ),
        programEngagementHeatmap(programId, timezone, days),
        prisma.enrollment.count({ where: { studyProgramId: programId } }),
        prisma.enrollment.count({
          where: { studyProgramId: programId, endDate: { gte: new Date() } },
        }),
        // Top groups (owner-requested 2026-07-30): metric side — lesson
        // completions per group from the flat layer.
        runAnalyticsQuery(
          {
            metrics: ['lesson_completions'],
            dimensions: ['group_id'],
            filters,
            timezone,
            limit: 100,
            orderBy: { metric: 'lesson_completions', dir: 'desc' },
          },
          scope
        ),
        // Presentation + denominator side: every enrolled group's name, active
        // member count, and per-enrollment active schedule count. Same
        // expectation formula as completion_rate, scoped per group.
        prisma.$queryRawUnsafe<
          {
            enrollment_id: string
            group_id: string
            group_name: string
            member_count: number
            schedule_count: number
          }[]
        >(
          `SELECT e.id::text AS enrollment_id,
                  e."groupId"::text AS group_id,
                  g.name AS group_name,
                  (SELECT COUNT(*)::int FROM group_members gm
                    WHERE gm."groupId" = e."groupId" AND gm."isActive" = true) AS member_count,
                  (SELECT COUNT(*)::int FROM lesson_schedules ls
                    WHERE ls."enrollmentId" = e.id AND ls."removedAt" IS NULL) AS schedule_count
             FROM enrollments e
             JOIN groups g ON g.id = e."groupId"
            WHERE e."studyProgramId"::text = $1`,
          programId
        ),
      ])

    const kpis = kpiQ.rows[0] ?? {}
    const toSeries = (rows: Record<string, unknown>[], dim: string) =>
      rows.map((r) => ({ date: r[dim] as string, count: Number(r.engagement_events ?? 0) }))

    // Assemble topGroups: base list = every ENROLLED group (a group with zero
    // completions still belongs in the table), completions layered on from the
    // flat-layer query, completionPct = completions ÷ Σ(members × schedules)
    // over that group's enrollments — the completion_rate formula per group.
    const completionsByGroup = new Map<string, number>(
      groupCompletionsQ.rows
        .filter((r) => r.group_id)
        .map((r) => [String(r.group_id), Number(r.lesson_completions ?? 0)])
    )
    const groupAgg = new Map<
      string,
      { groupName: string; memberCount: number; expected: number }
    >()
    for (const row of groupStats) {
      const existing = groupAgg.get(row.group_id)
      const expected = Number(row.member_count) * Number(row.schedule_count)
      if (existing) {
        existing.expected += expected
      } else {
        groupAgg.set(row.group_id, {
          groupName: row.group_name,
          memberCount: Number(row.member_count),
          expected,
        })
      }
    }
    const topGroups = [...groupAgg.entries()]
      .map(([groupId, g]) => {
        const lessonCompletions = completionsByGroup.get(groupId) ?? 0
        const completionPct =
          g.expected > 0
            ? Math.min(1, Math.round((lessonCompletions / g.expected) * 10_000) / 10_000)
            : 0
        return {
          groupId,
          groupName: g.groupName,
          memberCount: g.memberCount,
          lessonCompletions,
          completionPct,
        }
      })
      .sort(
        (a, b) =>
          b.completionPct - a.completionPct ||
          b.lessonCompletions - a.lessonCompletions ||
          b.memberCount - a.memberCount
      )
      .slice(0, 10)

    res.json({
      success: true,
      freshAsOf: kpiQ.freshAsOf,
      kpis: {
        membersReached: Number(kpis.active_members ?? 0),
        activeEnrollments,
        totalEnrollments,
        lessonCompletions: Number(kpis.lesson_completions ?? 0),
        // Registry ratios are 0–1 already; avg_watch_percent is stored 0–100
        // (member_video_progress.watchPercentage) so normalize to 0–1 here to
        // match the contract's 0.83-style values.
        completionRate: kpis.completion_rate === null ? 0 : Number(kpis.completion_rate ?? 0),
        videoCompletions: Number(kpis.video_completions ?? 0),
        watchSeconds: Number(kpis.watch_seconds ?? 0),
        avgWatchPercent:
          kpis.avg_watch_percent === null || kpis.avg_watch_percent === undefined
            ? 0
            : Math.round((Number(kpis.avg_watch_percent) / 100) * 10_000) / 10_000,
      },
      recent: {
        week: toSeries(weekQ.rows, 'day'),
        month: toSeries(monthQ.rows, 'day'),
        year: toSeries(yearQ.rows, 'month'),
      },
      heatmap,
      // Top 10 groups by completion (owner-requested 2026-07-30): every
      // enrolled group with member count + completion percentage.
      topGroups,
      // Phase C1 fills these; empty arrays keep the response shape stable for
      // clients built against the full contract.
      funnel: [],
      contentMix: [],
      topMembers: [],
      topEnrollments: [],
    })
  } catch (error) {
    if (error instanceof AnalyticsQueryError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    console.error('Error assembling program analytics:', error)
    res.status(500).json({ success: false, error: 'Failed to load program analytics' })
  }
})

export default router
