/**
 * The leader's enrollment directory (ui2-enrollments-browse SC4): the org-wide feed of enrollments and
 * drafts, sectioned by group. Raw-SQL aggregates, one query per concern over the kept enrollment ids
 * (no per-enrollment fan-out), as enrollment-analytics.service.ts does — but every id comparison is
 * `col::text = ANY($1::text[])`, which works on both the live text ids and migration-built uuid ids.
 */
import { z } from 'zod'
import type { LessonAccess, Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { isValidTimezone, localDate, todayInTimezone } from '../utils/timezone.js'
import { DRAFT_SELECT, toDraftWire, type DraftWire } from './enrollment-draft.service.js'
import { enrollmentManageFilter, getManageableOrgIds, isSuperAdmin } from './permission.js'
import { filterActivitiesToVersion } from './lesson-version-resolution.js'
import { activityThumbnailUrl } from './next-study-thumbnail.js'

export const FEED_STATUSES = ['active', 'upcoming', 'completed', 'draft', 'all'] as const
export type FeedStatus = (typeof FEED_STATUSES)[number]
/** D25: the most items one response carries, across all sections. */
export const FEED_ITEM_CAP = 200

// Not .strict(): an unknown query param (e.g. a `q`) is ignored, never a 400 (D27).
export const feedQuerySchema = z.object({
  orgId: z.string().uuid().optional(),
  groupId: z.string().uuid().optional(),
  leaderId: z.string().uuid().optional(),
  // owner 2026-10-29: a comma list (`active,draft`) — the iPhone status filter is multi-select;
  // `all` (or every status) is the whole feed. A single value still parses as before.
  status: z
    .preprocess((v) => (typeof v === 'string' ? v.split(',').map((s) => s.trim()).filter(Boolean) : v), z.array(z.enum(FEED_STATUSES)).min(1))
    .default(['active'])
    .transform((list) => new Set<FeedStatus>(list.includes('all') ? ['active', 'upcoming', 'completed', 'draft'] : list)),
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

  const wantsEnrollments = ['active', 'upcoming', 'completed'].some((b) => query.status.has(b as FeedStatus))
  const enrollments =
    !wantsEnrollments || groupIds.length === 0
      ? []
      : (
          await prisma.enrollment.findMany({
            where: { groupId: { in: groupIds }, studyProgram: { isActive: true } },
            select: { id: true, groupId: true, startDate: true, endDate: true, timezone: true, createdAt: true, studyProgram: programSelect },
          })
        ).filter((e) => query.status.has(bucketOf(e, today)))
  const drafts =
    query.status.has('draft') && groupIds.length > 0
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
  // Owner 2026-10-30: a group's drafts lead its list, then its enrollments — each kept in D17 order.
  for (const section of sections.values()) {
    section.items = [...section.items.filter((i) => i.kind === 'draft'), ...section.items.filter((i) => i.kind !== 'draft')]
  }
  return { sections: [...sections.values()], options }
}

// ── SC5: the enrollment home read (D20, §Contract Home) ──────────────────────

/** `tz` is validated but changes nothing: every Home date is in the enrollment's own zone (§Contract). */
export const homeQuerySchema = z.object({
  tz: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).optional(),
})

export interface HomeActivity {
  id: string
  type: string
  title: string
  thumbnailUrl: string | null
}
export interface HomeDay {
  scheduleId: string
  date: string
  percent: number
  lessonCount: number
  plannedMinutes: number
}
export interface HomeLesson {
  scheduleId: string
  dayNumber: number
  title: string
  date: string
  progress: number | null
  activities: HomeActivity[]
}
export interface EnrollmentHome {
  id: string
  studyProgram: { id: string; name: string; description: string | null; coverImageUrl: string | null; authorName: string }
  group: { id: string; name: string; leader: PersonRef | null }
  memberCount: number
  enrolledAt: string
  startDate: string
  endDate: string
  lessonAccess: LessonAccess
  smsTime: string | null
  timezone: string | null
  days: HomeDay[]
  lessons: HomeLesson[]
}

export async function getEnrollmentHome(userId: string, enrollmentId: string): Promise<EnrollmentHome | null> {
  const enrollment = await prisma.enrollment.findFirst({
    where: { id: enrollmentId, ...(await enrollmentManageFilter(userId)) },
    select: {
      id: true,
      groupId: true,
      createdAt: true,
      startDate: true,
      endDate: true,
      lessonAccess: true,
      smsTime: true,
      timezone: true,
      studyProgram: {
        select: { id: true, name: true, description: true, coverImageUrl: true, creator: { select: { name: true } } },
      },
      group: { select: { id: true, name: true, creator: { select: { id: true, name: true } } } },
      lessonSchedules: {
        where: { removedAt: null },
        orderBy: [{ scheduledDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          title: true,
          scheduledDate: true,
          estimatedMinutes: true,
          currentVersionId: true,
          scheduledActivities: {
            orderBy: { orderNumber: 'asc' },
            select: {
              id: true,
              type: true,
              title: true,
              versionId: true,
              youtubeThumbnailUrl: true,
              video: { select: { thumbnailUrl: true } },
              readBlocks: {
                where: { backgroundImageUrl: { not: null } },
                orderBy: { orderNumber: 'asc' },
                take: 1,
                select: { backgroundImageUrl: true },
              },
            },
          },
        },
      },
    },
  })
  if (!enrollment) return null
  const tz = enrollment.timezone ?? 'UTC'
  const schedules = enrollment.lessonSchedules

  // D16 / F5: active members only.
  const active = await prisma.groupMember.findMany({
    where: { groupId: enrollment.groupId, isActive: true, memberId: { not: null } },
    select: { memberId: true },
  })
  const activeIds = [...new Set(active.map((m) => m.memberId as string))]
  const memberCount = activeIds.length
  const completers = new Map<string, Set<string>>(schedules.map((s) => [s.id, new Set<string>()]))
  if (memberCount > 0 && schedules.length > 0) {
    const rows = await prisma.memberLessonProgress.findMany({
      where: { lessonScheduleId: { in: schedules.map((s) => s.id) }, memberId: { in: activeIds }, completedAt: { not: null } },
      select: { memberId: true, lessonScheduleId: true },
    })
    for (const r of rows) completers.get(r.lessonScheduleId)?.add(r.memberId)
  }

  const byDate = new Map<string, typeof schedules>()
  for (const s of schedules) {
    const date = localDate(s.scheduledDate, tz)
    byDate.set(date, [...(byDate.get(date) ?? []), s])
  }
  const days: HomeDay[] = [...byDate.entries()].map(([date, onDate]) => {
    const everyOne = activeIds.filter((m) => onDate.every((s) => completers.get(s.id)?.has(m))).length
    return {
      scheduleId: onDate[0].id,
      date,
      percent: memberCount === 0 ? 0 : Math.round((100 * everyOne) / memberCount),
      lessonCount: onDate.length,
      plannedMinutes: onDate.reduce((sum, s) => sum + (s.estimatedMinutes ?? 0), 0),
    }
  })

  const lessons: HomeLesson[] = schedules.map((s, index) => ({
    scheduleId: s.id,
    dayNumber: index + 1,
    title: s.title ?? '',
    date: localDate(s.scheduledDate, tz),
    progress: memberCount === 0 ? null : (completers.get(s.id)?.size ?? 0) / memberCount,
    activities: filterActivitiesToVersion(s.scheduledActivities, s.currentVersionId).map((a) => ({
      id: a.id,
      type: a.type,
      title: a.title,
      thumbnailUrl: activityThumbnailUrl({ type: a.type, youtubeThumbnailUrl: a.youtubeThumbnailUrl, video: a.video, readBlocks: a.readBlocks }),
    })),
  }))

  const leader = enrollment.group.creator
  return {
    id: enrollment.id,
    studyProgram: {
      id: enrollment.studyProgram.id,
      name: enrollment.studyProgram.name,
      description: enrollment.studyProgram.description,
      coverImageUrl: enrollment.studyProgram.coverImageUrl,
      authorName: enrollment.studyProgram.creator.name,
    },
    group: { id: enrollment.group.id, name: enrollment.group.name, leader: leader ? { id: leader.id, name: leader.name } : null },
    memberCount,
    enrolledAt: enrollment.createdAt.toISOString(),
    startDate: localDate(enrollment.startDate, tz),
    endDate: localDate(enrollment.endDate, tz),
    lessonAccess: enrollment.lessonAccess,
    smsTime: enrollment.smsTime,
    timezone: enrollment.timezone,
    days,
    lessons,
  }
}
