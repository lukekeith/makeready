import { prisma } from '../lib/prisma.js'

/**
 * Enrollment completion analytics.
 *
 * Reads are computed on-demand from the existing per-member completion records
 * (`member_activity_progress`, `member_video_progress`, `member_lesson_progress`,
 * each carrying a `completedAt`). All queries are scoped to a single enrollment,
 * so the row set is bounded by one group's data and the new composite index
 * `(lessonScheduleId, scheduledActivityId, completedAt)` keeps them fast.
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

  // Per-activity distinct-member completion counts. Progress rows are scoped to
  // this enrollment's lesson schedules so the composite index is used; a LEFT
  // JOIN keeps activities with zero completions (COUNT DISTINCT NULL = 0).
  const activityRows = await prisma.$queryRawUnsafe<
    { lessonScheduleId: string; scheduledActivityId: string; completedCount: number }[]
  >(
    `SELECT sla."lessonScheduleId" AS "lessonScheduleId",
            sla.id                 AS "scheduledActivityId",
            COUNT(DISTINCT comp."memberId")::int AS "completedCount"
       FROM scheduled_lesson_activities sla
       JOIN lesson_schedules ls ON ls.id = sla."lessonScheduleId"
       LEFT JOIN (
         SELECT map."lessonScheduleId", map."scheduledActivityId", map."memberId"
           FROM member_activity_progress map
           JOIN lesson_schedules ls2 ON ls2.id = map."lessonScheduleId"
          WHERE ls2."enrollmentId" = $1::uuid AND map."completedAt" IS NOT NULL
         UNION
         SELECT mvp."lessonScheduleId", mvp."scheduledActivityId", mvp."memberId"
           FROM member_video_progress mvp
           JOIN lesson_schedules ls3 ON ls3.id = mvp."lessonScheduleId"
          WHERE ls3."enrollmentId" = $1::uuid AND mvp."completedAt" IS NOT NULL
       ) comp
         ON comp."scheduledActivityId" = sla.id
        AND comp."lessonScheduleId" = sla."lessonScheduleId"
      WHERE ls."enrollmentId" = $1::uuid
      GROUP BY sla."lessonScheduleId", sla.id`,
    enrollmentId
  )

  // Per-lesson distinct-member completion counts.
  const lessonRows = await prisma.$queryRawUnsafe<
    { lessonScheduleId: string; completedCount: number }[]
  >(
    `SELECT ls.id AS "lessonScheduleId",
            COUNT(DISTINCT mlp."memberId")::int AS "completedCount"
       FROM lesson_schedules ls
       LEFT JOIN member_lesson_progress mlp
         ON mlp."lessonScheduleId" = ls.id AND mlp."completedAt" IS NOT NULL
      WHERE ls."enrollmentId" = $1::uuid
      GROUP BY ls.id`,
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
