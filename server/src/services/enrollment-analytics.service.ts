import { prisma } from '../lib/prisma.js'

/**
 * Enrollment completion analytics.
 *
 * Reads are computed on-demand from the per-member completion records
 * (`activity_progress` and `lesson_progress`, each carrying a `completedAt`).
 * All queries are scoped to a single enrollment, so the row set is bounded by
 * one group's data. Response keys keep their 1.0 names: `lessonScheduleId` is the
 * ScheduledLesson id and `scheduledActivityId` the activity's `activityKey`.
 *
 * This is the shared join path for enrollment analytics. Future per-member
 * "who completed what & when" detail should be added here as
 * `getEnrollmentCompletionDetail(enrollmentId)` returning the same joins with
 * `completedAt` per member/activity — no new tables required.
 */

export interface ActivityCompletionStat {
  scheduledActivityId: string
  completedCount: number
}

export interface LessonCompletionStat {
  lessonScheduleId: string
  /** Distinct members who completed the whole lesson. */
  completedCount: number
  activities: ActivityCompletionStat[]
}

export interface EnrollmentCompletionStats {
  /** Active members in the enrollment's group — the denominator for fractions. */
  memberCount: number
  lessons: LessonCompletionStat[]
}

/**
 * Completion counts for one enrollment: active member count, plus per-lesson and
 * per-activity distinct-member completion counts. A "completed" activity is one a
 * member finished via either the activity-progress or video-progress table (video
 * activities complete through the latter), so the per-activity count UNIONs both.
 */
export async function getEnrollmentCompletionStats(
  enrollmentId: string
): Promise<EnrollmentCompletionStats> {
  // Active members in the enrollment's group (the fraction denominator).
  const memberRows = await prisma.$queryRawUnsafe<{ count: number }[]>(
    `SELECT COUNT(*)::int AS count
       FROM group_members gm
       JOIN enrollments e ON e."groupId" = gm."groupId"
      WHERE e.id = $1::uuid AND gm."isActive" = true`,
    enrollmentId
  )
  const memberCount = memberRows[0]?.count ?? 0

  // Per-activity distinct-member completion counts over the activities of each
  // scheduled lesson's current version. A LEFT JOIN keeps activities with zero
  // completions (COUNT DISTINCT NULL = 0).
  const activityRows = await prisma.$queryRawUnsafe<
    { lessonScheduleId: string; scheduledActivityId: string; completedCount: number }[]
  >(
    `SELECT sl.id AS "lessonScheduleId",
            ca."activityKey" AS "scheduledActivityId",
            COUNT(DISTINCT ap."memberId")::int AS "completedCount"
       FROM scheduled_lessons sl
       JOIN content_activities ca ON ca."lessonVersionId" = sl."currentVersionId"
       LEFT JOIN activity_progress ap
         ON ap."scheduledLessonId" = sl.id
        AND ap."activityKey" = ca."activityKey"
        AND ap."completedAt" IS NOT NULL
      WHERE sl."enrollmentId" = $1::uuid
        AND sl."removedAt" IS NULL
      GROUP BY sl.id, ca."activityKey"`,
    enrollmentId
  )

  // Per-lesson distinct-member completion counts.
  const lessonRows = await prisma.$queryRawUnsafe<
    { lessonScheduleId: string; completedCount: number }[]
  >(
    `SELECT sl.id AS "lessonScheduleId",
            COUNT(DISTINCT lp."memberId")::int AS "completedCount"
       FROM scheduled_lessons sl
       LEFT JOIN lesson_progress lp
         ON lp."scheduledLessonId" = sl.id AND lp."completedAt" IS NOT NULL
      WHERE sl."enrollmentId" = $1::uuid
        AND sl."removedAt" IS NULL
      GROUP BY sl.id`,
    enrollmentId
  )

  // Assemble lessons keyed by schedule id, attaching their activities.
  const byLesson = new Map<string, LessonCompletionStat>()
  for (const l of lessonRows) {
    byLesson.set(l.lessonScheduleId, {
      lessonScheduleId: l.lessonScheduleId,
      completedCount: l.completedCount,
      activities: [],
    })
  }
  for (const a of activityRows) {
    let lesson = byLesson.get(a.lessonScheduleId)
    if (!lesson) {
      lesson = { lessonScheduleId: a.lessonScheduleId, completedCount: 0, activities: [] }
      byLesson.set(a.lessonScheduleId, lesson)
    }
    lesson.activities.push({
      scheduledActivityId: a.scheduledActivityId,
      completedCount: a.completedCount,
    })
  }

  return { memberCount, lessons: Array.from(byLesson.values()) }
}
