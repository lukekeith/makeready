/**
 * Pending-change computation for the study-sync Review Changes screen.
 *
 * For one enrollment, diffs the enrolled schedules against the program's
 * latest published snapshot and reports PER-LESSON changes with
 * activity-level counts — the quantified summary leaders approve from
 * (selectively, per lesson) instead of an AI prose summary.
 *
 * Activity-level diffs compare canonical CURRICULUM snapshots (target version
 * vs the version the schedule currently reflects, found by matching the
 * schedule's sourceContentHash in older versions' lessonHashes). Enrolled
 * copies are never compared against snapshots directly — the copy transforms
 * scripture content, which would produce false drift (phase-1 gotcha).
 */

import { prisma } from '../lib/prisma.js'
import type { SnapshotLesson } from './study-program-publish.js'

export type PendingLessonChangeType = 'new' | 'updated' | 'removed'

export interface PendingLessonChange {
  /** Selection key for POST /sync/apply — curriculum lessonId, or
   *  `schedule:{id}` for orphaned schedules whose lesson was deleted. */
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

interface SnapshotActivityEntry {
  id: string
  content: unknown
}

/** Align activityIds with canonical content.activities into id→content. */
function activityEntries(lesson: SnapshotLesson): SnapshotActivityEntry[] {
  const contentActivities = ((lesson.content as any)?.activities ?? []) as unknown[]
  const ids = lesson.activityIds ?? []
  return ids.map((id, index) => ({ id, content: contentActivities[index] }))
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
      id: true,
      studyProgramId: true,
      studyProgram: { select: { currentVersionNumber: true } },
    },
  })

  const targetVersionNumber = enrollment.studyProgram.currentVersionNumber
  if (targetVersionNumber == null) return empty

  const target = await prisma.studyProgramVersion.findUnique({
    where: {
      studyProgramId_versionNumber: {
        studyProgramId: enrollment.studyProgramId,
        versionNumber: targetVersionNumber,
      },
    },
    select: { snapshot: true },
  })
  if (!target) return empty

  const snapshotLessons = (((target.snapshot as any)?.lessons ?? []) as SnapshotLesson[])
    .slice()
    .sort((a, b) => a.dayNumber - b.dayNumber)
  const snapshotByLessonId = new Map(snapshotLessons.map((l) => [l.id, l]))

  const schedules = await prisma.lessonSchedule.findMany({
    where: { enrollmentId },
    select: {
      id: true,
      lessonId: true,
      title: true,
      scheduledDate: true,
      removedAt: true,
      currentVersion: {
        select: {
          sourceContentHash: true,
          activities: { select: { id: true } },
        },
      },
    },
  })
  const scheduleByLessonId = new Map(
    schedules.filter((s) => s.lessonId !== null).map((s) => [s.lessonId as string, s])
  )

  // Older versions' lessonHashes locate which snapshot each schedule reflects
  // (no snapshots loaded yet — they can be large; fetched per needed version).
  const olderVersions = await prisma.studyProgramVersion.findMany({
    where: { studyProgramId: enrollment.studyProgramId },
    orderBy: { versionNumber: 'desc' },
    select: { versionNumber: true, lessonHashes: true },
  })
  const snapshotCache = new Map<number, Map<string, SnapshotLesson>>()
  async function findPreviousLesson(
    lessonId: string,
    currentHash: string | null
  ): Promise<SnapshotLesson | null> {
    if (!currentHash) return null
    const match = olderVersions.find(
      (v) => ((v.lessonHashes ?? {}) as Record<string, string>)[lessonId] === currentHash
    )
    if (!match) return null
    let lessons = snapshotCache.get(match.versionNumber)
    if (!lessons) {
      const row = await prisma.studyProgramVersion.findUnique({
        where: {
          studyProgramId_versionNumber: {
            studyProgramId: enrollment.studyProgramId,
            versionNumber: match.versionNumber,
          },
        },
        select: { snapshot: true },
      })
      lessons = new Map(
        ((((row?.snapshot as any)?.lessons ?? []) as SnapshotLesson[])).map((l) => [l.id, l])
      )
      snapshotCache.set(match.versionNumber, lessons)
    }
    return lessons.get(lessonId) ?? null
  }

  const changes: PendingLessonChange[] = []

  for (const lesson of snapshotLessons) {
    const schedule = scheduleByLessonId.get(lesson.id)

    if (!schedule) {
      changes.push({
        key: lesson.id,
        type: 'new',
        dayNumber: lesson.dayNumber,
        title: lesson.title,
        scheduledDate: null,
        titleChanged: false,
        activities: { added: (lesson.activityIds ?? []).length, updated: 0, removed: 0 },
      })
      continue
    }

    const upToDate =
      schedule.currentVersion?.sourceContentHash === lesson.contentHash &&
      schedule.removedAt === null
    if (upToDate) continue

    const previous = await findPreviousLesson(
      lesson.id,
      schedule.currentVersion?.sourceContentHash ?? null
    )

    let activities: PendingLessonChange['activities'] = null
    let titleChanged = false
    if (previous) {
      const before = activityEntries(previous)
      const after = activityEntries(lesson)
      const beforeById = new Map(before.map((a) => [a.id, a]))
      const afterIds = new Set(after.map((a) => a.id))
      activities = {
        added: after.filter((a) => !beforeById.has(a.id)).length,
        removed: before.filter((a) => !afterIds.has(a.id)).length,
        updated: after.filter((a) => {
          const b = beforeById.get(a.id)
          return b !== undefined && JSON.stringify(b.content) !== JSON.stringify(a.content)
        }).length,
      }
      titleChanged = (previous.title ?? null) !== (lesson.title ?? null)
    }

    changes.push({
      key: lesson.id,
      type: 'updated',
      dayNumber: lesson.dayNumber,
      title: lesson.title,
      scheduledDate: schedule.scheduledDate,
      titleChanged,
      activities,
    })
  }

  for (const schedule of schedules) {
    if (schedule.removedAt !== null) continue // already removed by an earlier sync
    if (schedule.lessonId !== null && snapshotByLessonId.has(schedule.lessonId)) continue

    changes.push({
      key: schedule.lessonId ?? `schedule:${schedule.id}`,
      type: 'removed',
      dayNumber: null,
      title: schedule.title,
      scheduledDate: schedule.scheduledDate,
      titleChanged: false,
      activities: {
        added: 0,
        updated: 0,
        removed: schedule.currentVersion?.activities.length ?? 0,
      },
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

  return {
    targetVersionNumber,
    hasPending: changes.length > 0,
    changes,
    counts,
  }
}
