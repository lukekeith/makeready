/**
 * The leader's enrollment directory (ui2-enrollments-browse SC4): the org-wide feed of enrollments and
 * drafts, sectioned by group. Raw-SQL aggregates, one query per concern over the kept enrollment ids
 * (no per-enrollment fan-out), as enrollment-analytics.service.ts does — but every id comparison is
 * `col::text = ANY($1::text[])`, which works on both the live text ids and migration-built uuid ids.
 */
import { z } from 'zod'
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { isValidTimezone, localDate, todayInTimezone } from '../utils/timezone.js'
import { DRAFT_SELECT, toDraftWire, type DraftWire } from './enrollment-draft.service.js'
import { getManageableOrgIds, isSuperAdmin } from './permission.js'

export const FEED_STATUSES = ['active', 'upcoming', 'completed', 'draft', 'all'] as const
export type FeedStatus = (typeof FEED_STATUSES)[number]
/** D25: the most items one response carries, across all sections. */
export const FEED_ITEM_CAP = 200

// Not .strict(): an unknown query param (e.g. a `q`) is ignored, never a 400 (D27).
export const feedQuerySchema = z.object({
  orgId: z.string().uuid().optional(),
  groupId: z.string().uuid().optional(),
  leaderId: z.string().uuid().optional(),
  status: z.enum(FEED_STATUSES).default('active'),
  tz: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).default('UTC'),
})
export type FeedQuery = z.infer<typeof feedQuerySchema>

export interface ProgramRef {
  id: string
  name: string
  coverImageUrl: string | null
}
export interface PersonRef {
  id: string
  name: string
}
export interface EnrollmentItem {
  kind: 'enrollment'
  id: string
  studyProgram: ProgramRef
  startDate: string
  endDate: string
  enrolledAt: string
  progress: number
  completedMembers: number
  memberCount: number
  plannedMinutes: number
  recencyAt: string
}
export interface DraftItem {
  kind: 'draft'
  draft: DraftWire
  studyProgram: ProgramRef
  recencyAt: string
}
export type FeedItem = EnrollmentItem | DraftItem
export interface FeedSection {
  group: { id: string; name: string; coverImageUrl: string | null; leader: PersonRef | null }
  items: FeedItem[]
}
export interface EnrollmentFeed {
  sections: FeedSection[]
  options: { groups: { id: string; name: string }[]; leaders: PersonRef[] }
}

export class DirectoryError extends Error {
  constructor(
    readonly status: 400 | 404,
    message: string,
  ) {
    super(message)
    this.name = 'DirectoryError'
  }
}

export type EnrollmentBucket = 'active' | 'upcoming' | 'completed'

/** D8: local start/end dates in the enrollment's own zone, against today in the request's zone. */
export function bucketOf(e: { startDate: Date; endDate: Date; timezone: string | null }, today: string): EnrollmentBucket {
  const tz = e.timezone ?? 'UTC'
  if (localDate(e.startDate, tz) > today) return 'upcoming'
  if (localDate(e.endDate, tz) < today) return 'completed'
  return 'active'
}

/** D15 + D25: the groups the feed may show. */
async function feedGroupScope(userId: string, orgId: string | undefined): Promise<Prisma.GroupWhereInput> {
  const orgIds = await getManageableOrgIds(userId)
  if (orgId) {
    const allowed =
      orgIds.includes(orgId) ||
      ((await isSuperAdmin(userId)) && (await prisma.organization.count({ where: { id: orgId } })) > 0)
    if (!allowed) throw new DirectoryError(400, 'orgId is not one of your organizations')
    return { isActive: true, organizationId: orgId }
  }
  return { isActive: true, OR: [{ organizationId: { in: orgIds } }, { creatorId: userId }] }
}

interface ScheduleTotals {
  plannedMinutes: number
  scheduleCount: number
}

/** D12: Σ estimatedMinutes (null = 0) and the count of non-removed schedules, per enrollment. */
async function scheduleTotals(ids: string[]): Promise<Map<string, ScheduleTotals>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; plannedMinutes: number; scheduleCount: number }[]>(
    `SELECT ls."enrollmentId"::text AS "enrollmentId",
            COALESCE(SUM(ls."estimatedMinutes"), 0)::int AS "plannedMinutes",
            COUNT(*)::int AS "scheduleCount"
       FROM lesson_schedules ls
      WHERE ls."enrollmentId"::text = ANY($1::text[])
        AND ls."removedAt" IS NULL
      GROUP BY ls."enrollmentId"`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, { plannedMinutes: r.plannedMinutes, scheduleCount: r.scheduleCount }]))
}

/** D16: active members of each enrollment's group. */
async function activeMemberCounts(ids: string[]): Promise<Map<string, number>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; memberCount: number }[]>(
    `SELECT e.id::text AS "enrollmentId", COUNT(DISTINCT gm."memberId")::int AS "memberCount"
       FROM enrollments e
       JOIN group_members gm
         ON gm."groupId" = e."groupId" AND gm."isActive" = true AND gm."memberId" IS NOT NULL
      WHERE e.id::text = ANY($1::text[])
      GROUP BY e.id`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, r.memberCount]))
}

/** D16: per enrollment, each ACTIVE member's count of completed non-removed lessons (not version-filtered). */
async function memberCompletions(ids: string[]): Promise<Map<string, number[]>> {
  const out = new Map<string, number[]>()
  if (ids.length === 0) return out
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; completed: number }[]>(
    `SELECT ls."enrollmentId"::text AS "enrollmentId", COUNT(DISTINCT ls.id)::int AS "completed"
       FROM lesson_schedules ls
       JOIN enrollments e ON e.id = ls."enrollmentId"
       JOIN member_lesson_progress mlp
         ON mlp."lessonScheduleId" = ls.id AND mlp."completedAt" IS NOT NULL
       JOIN group_members gm
         ON gm."groupId" = e."groupId" AND gm."memberId" = mlp."memberId" AND gm."isActive" = true
      WHERE ls."enrollmentId"::text = ANY($1::text[])
        AND ls."removedAt" IS NULL
      GROUP BY ls."enrollmentId", mlp."memberId"`,
    ids,
  )
  for (const r of rows) out.set(r.enrollmentId, [...(out.get(r.enrollmentId) ?? []), r.completed])
  return out
}

/** D17: the latest member progress touch on any of an enrollment's schedules. */
async function latestProgress(ids: string[]): Promise<Map<string, Date>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; lastAt: Date }[]>(
    `SELECT x."enrollmentId", MAX(x.at) AS "lastAt" FROM (
       SELECT ls."enrollmentId"::text AS "enrollmentId", MAX(p."lastUpdatedAt") AS at
         FROM lesson_schedules ls JOIN member_lesson_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
       UNION ALL
       SELECT ls."enrollmentId"::text, MAX(p."lastUpdatedAt")
         FROM lesson_schedules ls JOIN member_activity_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
       UNION ALL
       SELECT ls."enrollmentId"::text, MAX(p."lastWatchedAt")
         FROM lesson_schedules ls JOIN member_video_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
     ) x GROUP BY x."enrollmentId"`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, new Date(r.lastAt)]))
}

const byName = (a: { name: string }, b: { name: string }) => a.name.localeCompare(b.name)
const later = (a: Date, b: Date | undefined) => (b && b > a ? b : a)

export async function getEnrollmentFeed(userId: string, query: FeedQuery, now: Date = new Date()): Promise<EnrollmentFeed> {
  const groups = await prisma.group.findMany({
    where: await feedGroupScope(userId, query.orgId),
    select: { id: true, name: true, coverImageUrl: true, creatorId: true, creator: { select: { id: true, name: true } } },
  })
  const groupById = new Map(groups.map((g) => [g.id, g]))
  const groupIds = groups.map((g) => g.id)
  const today = todayInTimezone(query.tz, now)
  const programSelect = { select: { id: true, name: true, coverImageUrl: true } } as const

  const enrollments =
    query.status === 'draft' || groupIds.length === 0
      ? []
      : (
          await prisma.enrollment.findMany({
            where: { groupId: { in: groupIds }, studyProgram: { isActive: true } },
            select: { id: true, groupId: true, startDate: true, endDate: true, timezone: true, createdAt: true, studyProgram: programSelect },
          })
        ).filter((e) => query.status === 'all' || bucketOf(e, today) === query.status)
  const drafts =
    (query.status === 'draft' || query.status === 'all') && groupIds.length > 0
      ? await prisma.enrollmentDraft.findMany({
          where: { groupId: { in: groupIds }, studyProgram: { isActive: true } },
          select: { ...DRAFT_SELECT, studyProgram: programSelect },
        })
      : []

  // §Contract: options over scope + orgId + status — before the groupId / leaderId narrowing.
  const listed = new Set([...enrollments.map((e) => e.groupId), ...drafts.map((d) => d.groupId)])
  const optionGroups = groups.filter((g) => listed.has(g.id))
  const leaders = new Map(optionGroups.map((g) => [g.creator.id, { id: g.creator.id, name: g.creator.name }]))
  const options = {
    groups: optionGroups.map((g) => ({ id: g.id, name: g.name })).sort(byName),
    leaders: [...leaders.values()].sort(byName),
  }

  const keep = (groupId: string) =>
    (!query.groupId || groupId === query.groupId) && (!query.leaderId || groupById.get(groupId)?.creatorId === query.leaderId)
  const keptEnrollments = enrollments.filter((e) => keep(e.groupId))
  const latest = await latestProgress(keptEnrollments.map((e) => e.id))

  // D17 recency, newest first (id breaks ties); D25 cap before sectioning.
  const ranked = [
    ...keptEnrollments.map((row) => ({ kind: 'enrollment' as const, row, recency: later(row.createdAt, latest.get(row.id)) })),
    ...drafts.filter((d) => keep(d.groupId)).map((row) => ({ kind: 'draft' as const, row, recency: row.updatedAt })),
  ]
    .sort((a, b) => b.recency.getTime() - a.recency.getTime() || a.row.id.localeCompare(b.row.id))
    .slice(0, FEED_ITEM_CAP)

  const ids = ranked.flatMap((r) => (r.kind === 'enrollment' ? [r.row.id] : []))
  const [totals, members, completions] = await Promise.all([scheduleTotals(ids), activeMemberCounts(ids), memberCompletions(ids)])

  const sections = new Map<string, FeedSection>()
  for (const r of ranked) {
    let item: FeedItem
    if (r.kind === 'enrollment') {
      const e = r.row
      const tz = e.timezone ?? 'UTC'
      const t = totals.get(e.id) ?? { plannedMinutes: 0, scheduleCount: 0 }
      const memberCount = members.get(e.id) ?? 0
      const perMember = completions.get(e.id) ?? []
      const denominator = memberCount * t.scheduleCount
      const done = perMember.reduce((sum, c) => sum + c, 0)
      item = {
        kind: 'enrollment',
        id: e.id,
        studyProgram: e.studyProgram,
        startDate: localDate(e.startDate, tz),
        endDate: localDate(e.endDate, tz),
        enrolledAt: e.createdAt.toISOString(),
        progress: denominator === 0 ? 0 : Math.min(1, done / denominator),
        completedMembers: t.scheduleCount === 0 ? 0 : perMember.filter((c) => c >= t.scheduleCount).length,
        memberCount,
        plannedMinutes: t.plannedMinutes,
        recencyAt: r.recency.toISOString(),
      }
    } else {
      const { studyProgram, ...draftRow } = r.row
      item = { kind: 'draft', draft: toDraftWire(draftRow), studyProgram, recencyAt: r.recency.toISOString() }
    }
    const groupId = r.row.groupId
    let section = sections.get(groupId)
    if (!section) {
      const g = groupById.get(groupId)!
      section = {
        group: { id: g.id, name: g.name, coverImageUrl: g.coverImageUrl, leader: g.creator ? { id: g.creator.id, name: g.creator.name } : null },
        items: [],
      }
      sections.set(groupId, section)
    }
    section.items.push(item)
  }
  return { sections: [...sections.values()], options }
}
