/**
 * Lesson Version Resolution (study-sync phase 4)
 *
 * A synced LessonSchedule carries the activity rows of EVERY version it has
 * ever had. What a viewer sees is resolved per member:
 *
 *   resolved version = member's pinnedVersionId ?? schedule.currentVersionId
 *
 * Members who completed a lesson are pinned to the version they finished and
 * render it forever; everyone else floats to the current version. Viewers
 * with no member context (leaders, share links) see the current version.
 *
 * Progress matching is lineage-aware: a member's progress row may point at a
 * previous version's copy of an activity — the shared lineageKey identifies
 * "the same activity" across versions until carry-forward copies the row.
 */

import { prisma } from '../lib/prisma.js'

interface VersionedActivity {
  id: string
  versionId?: string | null
  lineageKey?: string | null
}

interface ProgressRow {
  scheduledActivityId: string | null
  completedAt: Date | null
}

/** The version a member (or anonymous viewer) of this schedule should see. */
export function resolveVersionId(
  schedule: { currentVersionId: string | null },
  pinnedVersionId?: string | null
): string | null {
  return pinnedVersionId ?? schedule.currentVersionId
}

/**
 * Restrict a schedule's (multi-version) activity rows to one resolved
 * version. A null resolved version means pre-backfill legacy data — all rows
 * belong to the implicit single version. Null-versionId rows are always kept
 * as a legacy belt-and-suspenders.
 */
export function filterActivitiesToVersion<T extends VersionedActivity>(
  activities: T[],
  resolvedVersionId: string | null
): T[] {
  if (resolvedVersionId === null) return activities
  return activities.filter((a) => a.versionId === resolvedVersionId || a.versionId == null)
}

/**
 * Find the member's progress row for a resolved activity — directly, or via
 * lineage from a copy of the same activity in another version (progress made
 * before carry-forward ran). Completed rows win over partial ones.
 */
export function findProgressForActivity<P extends ProgressRow>(
  activity: VersionedActivity,
  progressRows: P[],
  lineageByActivityId: Map<string, string | null>
): P | null {
  const direct = progressRows.find((p) => p.scheduledActivityId === activity.id)
  if (direct) return direct

  const lineage = activity.lineageKey ?? null
  if (lineage === null) return null

  const candidates = progressRows.filter(
    (p) =>
      p.scheduledActivityId !== null &&
      lineageByActivityId.get(p.scheduledActivityId) === lineage
  )
  if (candidates.length === 0) return null
  return candidates.find((p) => p.completedAt !== null) ?? candidates[0]
}

/** Map of activity id -> lineageKey across every version of a schedule. */
export function buildLineageMap(
  activities: Array<{ id: string; lineageKey: string | null }>
): Map<string, string | null> {
  return new Map(activities.map((a) => [a.id, a.lineageKey]))
}

/**
 * Lazily copy a member's progress from prior-version activities onto the
 * resolved version's activities (matched by lineage). Copies, never moves —
 * historical rows stay untouched. Runs O(returning members), not
 * O(members × publish). Safe to re-run: the (member, schedule, activity)
 * uniques and skipDuplicates make it idempotent.
 */
export async function carryForwardMemberProgress(params: {
  memberId: string
  lessonScheduleId: string
  resolvedActivities: Array<{ id: string; lineageKey: string | null }>
  allActivities: Array<{ id: string; lineageKey: string | null }>
  memberProgress: Array<{
    scheduledActivityId: string | null
    startedAt: Date
    completedAt: Date | null
    exegesisVisitedHighlightIds: unknown
  }>
  videoProgress: Array<{
    scheduledActivityId: string | null
    watchedSeconds: number
    totalDuration: number | null
    watchPercentage: number
    startedAt: Date
    completedAt: Date | null
  }>
}): Promise<boolean> {
  const { memberId, lessonScheduleId, resolvedActivities, allActivities } = params

  const lineageById = buildLineageMap(allActivities)
  const resolvedIds = new Set(resolvedActivities.map((a) => a.id))

  const activityInserts: any[] = []
  const videoInserts: any[] = []

  for (const activity of resolvedActivities) {
    if (activity.lineageKey === null) continue

    const hasDirectActivity = params.memberProgress.some(
      (p) => p.scheduledActivityId === activity.id
    )
    if (!hasDirectActivity) {
      const source = findProgressForActivity(activity, params.memberProgress, lineageById)
      // Only rows from OTHER versions carry forward
      if (source && source.scheduledActivityId && !resolvedIds.has(source.scheduledActivityId)) {
        activityInserts.push({
          memberId,
          lessonScheduleId,
          scheduledActivityId: activity.id,
          startedAt: source.startedAt,
          completedAt: source.completedAt,
          exegesisVisitedHighlightIds: source.exegesisVisitedHighlightIds ?? undefined,
        })
      }
    }

    const hasDirectVideo = params.videoProgress.some(
      (p) => p.scheduledActivityId === activity.id
    )
    if (!hasDirectVideo) {
      const source = findProgressForActivity(activity, params.videoProgress, lineageById)
      if (source && source.scheduledActivityId && !resolvedIds.has(source.scheduledActivityId)) {
        videoInserts.push({
          memberId,
          lessonScheduleId,
          scheduledActivityId: activity.id,
          watchedSeconds: source.watchedSeconds,
          totalDuration: source.totalDuration,
          watchPercentage: source.watchPercentage,
          startedAt: source.startedAt,
          completedAt: source.completedAt,
        })
      }
    }
  }

  if (activityInserts.length > 0) {
    await prisma.memberActivityProgress.createMany({
      data: activityInserts,
      skipDuplicates: true,
    })
  }
  if (videoInserts.length > 0) {
    await prisma.memberVideoProgress.createMany({ data: videoInserts, skipDuplicates: true })
  }
  return activityInserts.length > 0 || videoInserts.length > 0
}
