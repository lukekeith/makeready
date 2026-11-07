/**
 * Pending-change computation for the sync Review Changes screen (text-activity 05 s3).
 *
 * For one enrollment, diffs the lessons of the ProgramVersion it is on against the lessons of its program's
 * current ProgramVersion, by `lessonId` and `lessonVersionId`, and reports PER-LESSON changes with
 * activity-level counts (by `activityKey`). Two kinds of lesson never show as pending: one whose scheduled
 * lesson already points at the target's version (approved earlier), and one the group customized (sync skips it).
 */

import { prisma } from '../lib/prisma.js'
import type { Prisma } from '../generated/prisma/index.js'

type Db = Prisma.TransactionClient | typeof prisma

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

async function versionLessons(db: Db, programVersionId: string | null): Promise<Map<string, VersionedLesson>> {
  if (!programVersionId) return new Map()
  const rows = await db.programVersionLesson.findMany({ where: { programVersionId }, ...VERSION_LESSONS })
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

/** `db` is the caller's transaction when the diff must see its uncommitted pointer moves. */
export async function computePendingChanges(enrollmentId: string, db: Db = prisma): Promise<PendingChanges> {
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

  const enrollment = await db.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: {
      programVersionId: true,
      studyProgram: { select: { currentVersion: { select: { id: true, number: true } } } },
    },
  })
  const target = enrollment.studyProgram.currentVersion
  if (!target) return empty

  const [targetLessons, baseLessons, schedules] = await Promise.all([
    versionLessons(db, target.id),
    versionLessons(db, enrollment.programVersionId),
    db.scheduledLesson.findMany({
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

export interface EnrollmentSyncStatus {
  syncMode: string
  syncedProgramVersionNumber: number | null
  currentVersionNumber: number | null
  hasDrift: boolean
  /** Program versions newer than the enrollment's, newest first. */
  pendingVersions: { versionNumber: number; publishedAt: Date; changeSummary: string | null; changedLessonIds: string[] }[]
  /** Sync runs are no longer recorded (D37). */
  recentRuns: never[]
}

/**
 * Where an enrollment stands against its program: `ProgramVersion.number` for both ends, and the versions in
 * between with the lessons each one changed (a lesson whose version differs from the one before it).
 */
export async function getEnrollmentSyncStatus(enrollmentId: string): Promise<EnrollmentSyncStatus> {
  const enrollment = await prisma.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: {
      syncMode: true,
      programVersion: { select: { number: true } },
      studyProgram: { select: { id: true, currentVersion: { select: { number: true } } } },
    },
  })
  const synced = enrollment.programVersion?.number ?? null
  const current = enrollment.studyProgram.currentVersion?.number ?? null
  const hasDrift = current !== null && current > (synced ?? 0)

  const pendingVersions: EnrollmentSyncStatus['pendingVersions'] = []
  if (hasDrift) {
    // The version just before the oldest pending one is the base the first pending change is measured against.
    const versions = await prisma.programVersion.findMany({
      where: { programId: enrollment.studyProgram.id, number: { gte: synced ?? 0 } },
      orderBy: { number: 'asc' },
      select: {
        number: true, publishedAt: true, changeSummary: true,
        lessons: { select: { lessonId: true, lessonVersionId: true } },
      },
    })
    let previous = synced === null ? undefined : versions.find((v) => v.number === synced)
    for (const version of versions.filter((v) => v.number > (synced ?? 0))) {
      const before = new Map((previous?.lessons ?? []).map((l) => [l.lessonId, l.lessonVersionId]))
      pendingVersions.push({
        versionNumber: version.number,
        publishedAt: version.publishedAt,
        changeSummary: version.changeSummary,
        changedLessonIds: version.lessons.filter((l) => before.get(l.lessonId) !== l.lessonVersionId).map((l) => l.lessonId),
      })
      previous = version
    }
    pendingVersions.reverse()
  }
  return {
    syncMode: enrollment.syncMode,
    syncedProgramVersionNumber: synced,
    currentVersionNumber: current,
    hasDrift,
    pendingVersions,
    recentRuns: [],
  }
}
