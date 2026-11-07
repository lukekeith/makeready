/**
 * The member-facing study enrollment reads (`/groups/:groupId/study-enrollment*`) on the new model: lessons come from
 * `ScheduledLesson` rows and their current versions, completion from `ActivityProgress` keyed by `activityKey`.
 * Every key the routes returned before is kept; nothing writes progress until a member rebuild (D8), so completion is empty.
 */
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { lessonMinutes } from './enrollment-lessons.js'

const DAY_NUMBERS: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }

const programSelect = { id: true, name: true, description: true, coverImageUrl: true, days: true } as const

const scheduleInclude = {
  lesson: { select: { position: true } },
  template: { select: { name: true } },
  currentVersion: {
    select: {
      title: true,
      estimatedSeconds: true,
      activities: { orderBy: { position: 'asc' }, select: { activityKey: true, kind: true, title: true, estimatedSeconds: true } },
    },
  },
} satisfies Prisma.ScheduledLessonInclude

const enrollmentInclude = {
  studyProgram: { select: programSelect },
  scheduledLessons: { orderBy: { scheduledDate: 'asc' }, include: scheduleInclude },
} satisfies Prisma.EnrollmentInclude

type EnrollmentRow = Prisma.EnrollmentGetPayload<{ include: typeof enrollmentInclude }>

/** Earliest completion per scheduled lesson, plus the set of completed `scheduledLessonId:activityKey` pairs. */
async function memberCompletion(memberId: string, scheduledLessonIds: string[]) {
  const rows = scheduledLessonIds.length
    ? await prisma.activityProgress.findMany({
        where: { memberId, scheduledLessonId: { in: scheduledLessonIds }, completedAt: { not: null } },
        select: { scheduledLessonId: true, activityKey: true, completedAt: true },
      })
    : []
  const completedActivities = new Set<string>()
  const lessonCompletedAt = new Map<string, Date>()
  for (const row of rows) {
    completedActivities.add(`${row.scheduledLessonId}:${row.activityKey}`)
    if (!row.completedAt) continue
    const existing = lessonCompletedAt.get(row.scheduledLessonId)
    if (!existing || row.completedAt < existing) lessonCompletedAt.set(row.scheduledLessonId, row.completedAt)
  }
  return { completedActivities, lessonCompletedAt }
}

function activeDays(enabledDays: string): number[] {
  try {
    const names = JSON.parse(enabledDays) as string[]
    return names.map((d) => DAY_NUMBERS[d]).filter((d) => d !== undefined)
  } catch {
    return [1, 2, 3, 4, 5]
  }
}

async function formatEnrollment(enrollment: EnrollmentRow, memberId: string) {
  const schedules = enrollment.scheduledLessons
  const { completedActivities, lessonCompletedAt } = await memberCompletion(memberId, schedules.map((s) => s.id))
  return {
    id: enrollment.id,
    studyId: enrollment.studyProgramId,
    studyTitle: enrollment.studyProgram.name,
    studyDescription: enrollment.studyProgram.description || '',
    coverImageUrl: enrollment.studyProgram.coverImageUrl,
    totalLessons: schedules.length,
    completedLessons: lessonCompletedAt.size,
    firstDate: enrollment.startDate.toISOString(),
    lastDate: enrollment.endDate.toISOString(),
    activeDays: activeDays(enrollment.enabledDays),
    lessons: schedules.map((ls) => {
      const dayNumber = ls.lesson?.position ?? 0
      const activities = ls.currentVersion.activities
      const totalSeconds = activities.reduce((sum, a) => sum + (a.estimatedSeconds || 0), 0)
      return {
        id: ls.id,
        dayNumber,
        title: ls.currentVersion.title || activities[0]?.title || `Day ${dayNumber}`,
        templateName: ls.template?.name ?? null,
        scheduledDate: ls.scheduledDate.toISOString(),
        estimatedMinutes: lessonMinutes(ls.currentVersion.estimatedSeconds) ?? (totalSeconds > 0 ? Math.max(1, Math.round(totalSeconds / 60)) : null),
        activities: activities.map((a) => ({ type: a.kind, completed: completedActivities.has(`${ls.id}:${a.activityKey}`) })),
        completedAt: lessonCompletedAt.get(ls.id)?.toISOString() || undefined,
      }
    }),
  }
}

/** The member must be an active member of the group; the route checks that. `where` picks the enrollment. */
export async function getStudyEnrollment(where: Prisma.EnrollmentWhereInput, memberId: string, newestFirst = false) {
  const enrollment = await prisma.enrollment.findFirst({
    where,
    ...(newestFirst ? { orderBy: { createdAt: 'desc' as const } } : {}),
    include: enrollmentInclude,
  })
  return enrollment ? formatEnrollment(enrollment, memberId) : null
}

/** Every study enrollment of the group, newest first, each lesson with its activity count. */
export async function listStudyEnrollments(groupId: string, memberId: string) {
  const enrollments = await prisma.enrollment.findMany({
    // A soft-deleted program stops rendering in the lists (monday#12415690223).
    where: { groupId, studyProgram: { isActive: true } },
    orderBy: { createdAt: 'desc' },
    include: enrollmentInclude,
  })
  return Promise.all(
    enrollments.map(async (enrollment) => {
      const schedules = enrollment.scheduledLessons
      const { lessonCompletedAt } = await memberCompletion(memberId, schedules.map((s) => s.id))
      return {
        id: enrollment.id,
        studyId: enrollment.studyProgramId,
        studyTitle: enrollment.studyProgram.name,
        studyDescription: enrollment.studyProgram.description || '',
        coverImageUrl: enrollment.studyProgram.coverImageUrl,
        totalLessons: schedules.length,
        completedLessons: lessonCompletedAt.size,
        lessons: schedules.map((ls) => {
          const dayNumber = ls.lesson?.position ?? 0
          return {
            id: ls.id,
            dayNumber,
            title: ls.currentVersion.title || `Day ${dayNumber}`,
            scheduledDate: ls.scheduledDate.toISOString(),
            completedAt: lessonCompletedAt.get(ls.id)?.toISOString() || undefined,
            activityCount: ls.currentVersion.activities.length,
          }
        }),
      }
    }),
  )
}
