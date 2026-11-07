/**
 * Pending-change computation for the sync Review Changes screen (text-activity 05 s3).
 *
 * For one enrollment, diffs the lessons of the ProgramVersion it is on against the lessons of its program's
 * current ProgramVersion, by `lessonId` and `lessonVersionId`, and reports PER-LESSON changes with
 * activity-level counts (by `activityKey`). Two kinds of lesson never show as pending: one whose scheduled
 * lesson already points at the target's version (approved earlier), and one the group customized (sync skips it).
 */

import { prisma } from '../lib/prisma.js'

export type PendingLessonChangeType = 'new' | 'updated' | 'removed'

export interface PendingLessonChange {
  /** Selection key for POST /sync/apply: the lessonId, or `schedule:{id}` for a scheduled lesson whose lesson is gone. */
  key: string
  type: PendingLessonChangeType
  /** Target-version day number (new/updated) or the schedule's last-known
   *  day (removed). */
  dayNumber: number | null
  title: string | null
  /** The enrolled schedule's date (null for lessons not yet added). */
  scheduledDate: Date | null
  titleChanged: boolean
  /** Activity-level counts. Null when the previous snapshot can't be found
   *  (pre-versioning content) — the lesson is still known to have changed. */
  activities: { added: number; updated: number; removed: number } | null
}

export interface PendingChanges {
  targetVersionNumber: number | null
  hasPending: boolean
  changes: PendingLessonChange[]
  counts: {
    lessonsNew: number
    lessonsUpdated: number
    lessonsRemoved: number
    activitiesNew: number
    activitiesUpdated: number
    activitiesRemoved: number
  }
}


interface VersionedLesson {
  lessonVersionId: string
  position: number
  lessonVersion: {
    title: string | null
    activities: { activityKey: string; document: unknown }[]
  }
}

const VERSION_LESSONS = {
  select: {
    lessonId: true,
    lessonVersionId: true,
    position: true,
    lessonVersion: {
      select: { title: true, activities: { select: { activityKey: true, document: true } } },
    },
  },
} as const

async function versionLessons(programVersionId: string | null): Promise<Map<string, VersionedLesson>> {
  if (!programVersionId) return new Map()
  const rows = await prisma.programVersionLesson.findMany({ where: { programVersionId }, ...VERSION_LESSONS })
  return new Map(rows.map((r) => [r.lessonId, r]))
}

function activityCounts(before: VersionedLesson, after: VersionedLesson) {
  const beforeByKey = new Map(before.lessonVersion.activities.map((a) => [a.activityKey, a]))
  const afterKeys = new Set(after.lessonVersion.activities.map((a) => a.activityKey))
  return {
    added: after.lessonVersion.activities.filter((a) => !beforeByKey.has(a.activityKey)).length,
    removed: before.lessonVersion.activities.filter((a) => !afterKeys.has(a.activityKey)).length,
    updated: after.lessonVersion.activities.filter((a) => {
      const b = beforeByKey.get(a.activityKey)
      return b !== undefined && JSON.stringify(b.document) !== JSON.stringify(a.document)
    }).length,
  }
}

export async function computePendingChanges(enrollmentId: string): Promise<PendingChanges> {
  const empty: PendingChanges = {
    targetVersionNumber: null,
    hasPending: false,
    changes: [],
    counts: {
      lessonsNew: 0,
      lessonsUpdated: 0,
      lessonsRemoved: 0,
      activitiesNew: 0,
      activitiesUpdated: 0,
      activitiesRemoved: 0,
    },
  }

  const enrollment = await prisma.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: {
      programVersionId: true,
      studyProgram: { select: { currentVersion: { select: { id: true, number: true } } } },
    },
  })
  const target = enrollment.studyProgram.currentVersion
  if (!target) return empty

  const [targetLessons, baseLessons, schedules] = await Promise.all([
    versionLessons(target.id),
    versionLessons(enrollment.programVersionId),
    prisma.scheduledLesson.findMany({
      where: { enrollmentId, removedAt: null },
      select: {
        id: true,
        lessonId: true,
        scheduledDate: true,
        currentVersionId: true,
        currentVersion: { select: { enrollmentId: true, title: true, _count: { select: { activities: true } } } },
      },
    }),
  ])
  const scheduleByLessonId = new Map(
    schedules.filter((s) => s.lessonId !== null).map((s) => [s.lessonId as string, s]),
  )

  const changes: PendingLessonChange[] = []
  const ordered = [...targetLessons.entries()].sort((a, b) => a[1].position - b[1].position)
  for (const [lessonId, lesson] of ordered) {
    const schedule = scheduleByLessonId.get(lessonId)
    if (!schedule) {
      changes.push({
        key: lessonId,
        type: 'new',
        dayNumber: lesson.position,
        title: lesson.lessonVersion.title,
        scheduledDate: null,
        titleChanged: false,
        activities: { added: lesson.lessonVersion.activities.length, updated: 0, removed: 0 },
      })
      continue
    }
    if (schedule.currentVersion.enrollmentId !== null) continue // customized: sync skips it
    if (schedule.currentVersionId === lesson.lessonVersionId) continue // already on the target's version
    const base = baseLessons.get(lessonId)
    changes.push({
      key: lessonId,
      type: 'updated',
      dayNumber: lesson.position,
      title: lesson.lessonVersion.title,
      scheduledDate: schedule.scheduledDate,
      titleChanged: base !== undefined && (base.lessonVersion.title ?? null) !== (lesson.lessonVersion.title ?? null),
      activities: base ? activityCounts(base, lesson) : null,
    })
  }

  for (const schedule of schedules) {
    if (schedule.lessonId !== null && targetLessons.has(schedule.lessonId)) continue
    changes.push({
      key: schedule.lessonId ?? `schedule:${schedule.id}`,
      type: 'removed',
      dayNumber: schedule.lessonId ? (baseLessons.get(schedule.lessonId)?.position ?? null) : null,
      title: schedule.currentVersion.title,
      scheduledDate: schedule.scheduledDate,
      titleChanged: false,
      activities: { added: 0, updated: 0, removed: schedule.currentVersion._count.activities },
    })
  }

  const counts = changes.reduce(
    (acc, change) => {
      if (change.type === 'new') acc.lessonsNew++
      else if (change.type === 'updated') acc.lessonsUpdated++
      else acc.lessonsRemoved++
      acc.activitiesNew += change.activities?.added ?? 0
      acc.activitiesUpdated += change.activities?.updated ?? 0
      acc.activitiesRemoved += change.activities?.removed ?? 0
      return acc
    },
    { ...empty.counts }
  )

  return { targetVersionNumber: target.number, hasPending: changes.length > 0, changes, counts }
}
