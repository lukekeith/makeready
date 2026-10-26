/**
 * Per-member program engagement for the UI 2.0 member page
 * (ui2-members-browse D11, D14, D16, D17) — GET /api/members/:id/engagement.
 *
 * Rows: every enrollment of an active group the member is active in, inside
 * the orgs the caller sees the member in (D16). Lessons = the enrollment's
 * LessonSchedule rows with removedAt null. percent is against lessons due
 * before today in tz (stored calendar date, as Home's engagement), so it can
 * read 100 mid-program; the iPhone's `Complete` comes from totalCount (D14).
 * hours (D17): only the member's moments tied to THAT enrollment, sessionized
 * with Home's rule — a Session carries no lesson link, so loadSessions cannot
 * be split by enrollment.
 */
import { prisma } from '../lib/prisma.js'
import { localDateOf, storedDate } from './home-dashboard.js'
import { sessionize } from './home-sessions.js'
import { type MemberViewer, visibleMemberOrgIds } from './member-access.js'

export interface EngagementProgram {
  enrollmentId: string
  programId: string
  title: string
  coverImageUrl: string | null
  completedCount: number
  totalCount: number
  hours: number
  percent: number
}

export interface MemberEngagement {
  programs: EngagementProgram[]
}

export type EnrollmentMoment = { enrollmentId: string; at: Date }

/**
 * D17: Σ session seconds per enrollment. sessionize groups by its `memberId`
 * slot; passing the ENROLLMENT id there keeps each enrollment's moments in
 * their own sessions, so interleaved programs never merge or double-count.
 */
export function enrollmentSeconds(moments: EnrollmentMoment[]): Map<string, number> {
  const totals = new Map<string, number>()
  for (const s of sessionize(moments.map((m) => ({ memberId: m.enrollmentId, at: m.at })))) {
    totals.set(s.memberId, (totals.get(s.memberId) ?? 0) + s.seconds)
  }
  return totals
}

export function summarizeEnrollment(
  schedules: { id: string; date: string }[],
  completedIds: ReadonlySet<string>,
  seconds: number,
  today: string
): { completedCount: number; totalCount: number; hours: number; percent: number } {
  const completedCount = schedules.filter((s) => completedIds.has(s.id)).length
  const due = schedules.filter((s) => s.date < today).length
  return {
    completedCount,
    totalCount: schedules.length,
    hours: Math.round(seconds / 3600),
    percent: due === 0 ? 0 : Math.min(100, Math.round((completedCount / due) * 100)),
  }
}

export async function getMemberEngagement(
  memberId: string,
  viewer: MemberViewer,
  tz: string,
  now: Date = new Date()
): Promise<MemberEngagement | null> {
  const orgIds = viewer.kind === 'user' ? await visibleMemberOrgIds(viewer, memberId) : null
  if (orgIds !== null && orgIds.length === 0) return null

  const enrollments = await prisma.enrollment.findMany({
    where: {
      group: {
        isActive: true,
        ...(orgIds !== null ? { organizationId: { in: orgIds } } : {}),
        members: { some: { memberId, isActive: true } },
      },
    },
    select: {
      id: true,
      studyProgramId: true,
      studyProgram: { select: { name: true, coverImageUrl: true } },
      lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } },
    },
    orderBy: [{ startDate: 'desc' }, { id: 'asc' }],
  })
  if (enrollments.length === 0) return { programs: [] }

  const enrollmentIds = enrollments.map((e) => e.id)
  const tied = { lessonSchedule: { enrollmentId: { in: enrollmentIds } } }
  const [lessons, videos, events] = await Promise.all([
    prisma.memberLessonProgress.findMany({
      where: { memberId, ...tied },
      select: { lessonScheduleId: true, completedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    }),
    prisma.memberVideoProgress.findMany({
      where: { memberId, ...tied },
      select: { startedAt: true, lastWatchedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    }),
    prisma.clientEvent.findMany({
      where: { memberId, enrollmentId: { in: enrollmentIds } },
      select: { enrollmentId: true, occurredAt: true },
    }),
  ])

  const completed = new Set<string>()
  const moments: EnrollmentMoment[] = []
  for (const l of lessons) {
    if (!l.completedAt) continue
    completed.add(l.lessonScheduleId)
    moments.push({ enrollmentId: l.lessonSchedule.enrollmentId, at: l.completedAt })
  }
  for (const v of videos) {
    moments.push({ enrollmentId: v.lessonSchedule.enrollmentId, at: v.startedAt })
    moments.push({ enrollmentId: v.lessonSchedule.enrollmentId, at: v.lastWatchedAt })
  }
  for (const e of events) if (e.enrollmentId) moments.push({ enrollmentId: e.enrollmentId, at: e.occurredAt })

  const seconds = enrollmentSeconds(moments)
  const today = localDateOf(now, tz)
  return {
    programs: enrollments.map((e) => ({
      enrollmentId: e.id,
      programId: e.studyProgramId,
      title: e.studyProgram.name,
      coverImageUrl: e.studyProgram.coverImageUrl ?? null,
      ...summarizeEnrollment(
        e.lessonSchedules.map((s) => ({ id: s.id, date: storedDate(s.scheduledDate) })),
        completed,
        seconds.get(e.id) ?? 0,
        today
      ),
    })),
  }
}
