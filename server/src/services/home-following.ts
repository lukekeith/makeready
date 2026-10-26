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
    (a, b) => a.program.title.localeCompare(b.program.title, 'en', { sensitivity: 'base' }) || a.firstRank - b.firstRank
  )
  for (const entry of sorted) {
    entry.program.groups.sort(
      (a, b) =>
        a.groupName.localeCompare(b.groupName, 'en', { sensitivity: 'base' }) ||
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
    where: {
      AND: [
        { id: { in: ids } },
        manage,
        { studyProgram: { isActive: true } },
        { group: { isActive: true, ...scopeGroupWhere(scope) } },
      ],
    },
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
