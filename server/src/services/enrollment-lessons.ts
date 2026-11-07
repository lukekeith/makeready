/**
 * An enrollment's lessons on the new model (text-activity §Contract, SC10): the `ScheduledLesson` read shape every
 * enrollment route shares, the `lessonSchedules[]` wire built from it with today's keys, and the group-owned
 * version a schedule title edit writes (D4, D5).
 */
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { hashLessonContent } from './activity-document.js'
import { buildMediaMap, type MediaMap } from './content-media.service.js'

/** `title` and `estimatedMinutes` of a lesson come from its current version: `ceil(estimatedSeconds / 60)` (§Contract). */
export const lessonMinutes = (estimatedSeconds: number | null | undefined): number | null =>
  estimatedSeconds == null ? null : Math.ceil(estimatedSeconds / 60)

/** One ScheduledLesson with its lesson, template name and current version's activities in order. */
export const scheduledLessonInclude = {
  lesson: { select: { id: true, position: true, programId: true, createdAt: true, updatedAt: true } },
  template: { select: { name: true } },
  currentVersion: {
    select: {
      id: true,
      title: true,
      estimatedSeconds: true,
      activities: {
        orderBy: { position: 'asc' },
        select: { id: true, activityKey: true, position: true, kind: true, title: true, document: true, estimatedSeconds: true },
      },
    },
  },
} satisfies Prisma.ScheduledLessonInclude

export type ScheduledLessonRow = Prisma.ScheduledLessonGetPayload<{ include: typeof scheduledLessonInclude }>
export type ScheduledActivityRow = ScheduledLessonRow['currentVersion']['activities'][number]

/** The `MediaMap` for every document the rows' current versions hold. */
export function mediaForScheduledLessons(rows: ScheduledLessonRow[]): Promise<MediaMap> {
  return buildMediaMap(prisma, rows.flatMap((r) => r.currentVersion.activities.map((a) => a.document)))
}

/** ActivitySummary (§Shapes) — the rail slide shape the iPhone reads from every version. */
export function activitySummary(a: ScheduledActivityRow) {
  return { id: a.id, activityKey: a.activityKey, position: a.position, kind: a.kind, title: a.title, document: a.document }
}

/**
 * One `lessonSchedules[]` row with every key it returned as a `LessonSchedule`, filled from the ScheduledLesson and
 * its current version: `lesson.dayNumber` is the lesson's position and the activities nested under `lesson` and
 * `scheduledActivities` are the version's.
 */
export function serializeScheduledLesson(row: ScheduledLessonRow) {
  const activities = row.currentVersion.activities.map(activitySummary)
  return {
    id: row.id,
    code: row.code,
    enrollmentId: row.enrollmentId,
    lessonId: row.lessonId,
    scheduledDate: row.scheduledDate,
    smsSentAt: row.smsSentAt,
    templateId: row.templateId,
    templateName: row.template?.name ?? null,
    title: row.currentVersion.title,
    estimatedMinutes: lessonMinutes(row.currentVersion.estimatedSeconds),
    currentVersionId: row.currentVersionId,
    removedAt: row.removedAt,
    scheduledActivities: activities,
    lesson: {
      ...(row.lesson
        ? {
            id: row.lesson.id,
            dayNumber: row.lesson.position,
            title: row.currentVersion.title,
            studyProgramId: row.lesson.programId,
            createdAt: row.lesson.createdAt,
            updatedAt: row.lesson.updatedAt,
          }
        : {}),
      activities,
    },
  }
}

/**
 * A schedule's title edit. Titles live on versions, so the group gets its own PUBLISHED version of the lesson (same
 * activity keys and documents) with the new title, and the scheduled lesson points at it; sync skips such lessons (D5).
 * A version the group already owns is retitled in place, since only this scheduled lesson reads it.
 */
export async function setScheduledLessonTitle(scheduledLessonId: string, title: string | null): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const schedule = await tx.scheduledLesson.findUniqueOrThrow({
      where: { id: scheduledLessonId },
      include: { currentVersion: { include: { activities: true } } },
    })
    const version = schedule.currentVersion
    const contentHash = hashLessonContent({ title: title ?? '', activities: version.activities })
    if (version.enrollmentId === schedule.enrollmentId) {
      await tx.lessonVersion.update({ where: { id: version.id }, data: { title, contentHash } })
      return
    }
    const max = await tx.lessonVersion.aggregate({ where: { lessonId: version.lessonId }, _max: { number: true } })
    const own = await tx.lessonVersion.create({
      data: {
        lessonId: version.lessonId,
        enrollmentId: schedule.enrollmentId,
        number: (max._max.number ?? 0) + 1,
        status: 'PUBLISHED',
        title,
        contentHash,
        estimatedSeconds: version.estimatedSeconds,
        basedOnVersionId: version.id,
        publishedAt: new Date(),
        activities: {
          create: version.activities.map((a) => ({
            activityKey: a.activityKey,
            position: a.position,
            kind: a.kind,
            title: a.title,
            document: a.document as Prisma.InputJsonValue,
            estimatedSeconds: a.estimatedSeconds,
          })),
        },
      },
    })
    await tx.scheduledLesson.update({ where: { id: scheduledLessonId }, data: { currentVersionId: own.id } })
  })
}
