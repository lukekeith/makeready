/**
 * Lesson Time Estimate Service
 *
 * text-activity: a lesson's estimate is the sum of its activities' `estimatedSeconds`, which are set at
 * save time from the document (`estimateDocumentSeconds`) or the video's duration. Stored on the
 * `LessonVersion` the activities belong to.
 */

import type { Prisma } from '../generated/prisma/index.js'
import { READING_WPM } from '../lib/reading-wpm.js'

export { READING_WPM }

/** The total of the activities' seconds; null when no activity has an estimate. */
export function sumEstimatedSeconds(activities: { estimatedSeconds: number | null }[]): number | null {
  const total = activities.reduce((sum, a) => sum + (a.estimatedSeconds ?? 0), 0)
  return total > 0 ? total : null
}

/** Stores the sum of a version's activities on the version and returns it. */
export async function recalculateVersionEstimate(tx: Prisma.TransactionClient, lessonVersionId: string): Promise<number | null> {
  const activities = await tx.contentActivity.findMany({ where: { lessonVersionId }, select: { estimatedSeconds: true } })
  const estimatedSeconds = sumEstimatedSeconds(activities)
  await tx.lessonVersion.update({ where: { id: lessonVersionId }, data: { estimatedSeconds } })
  return estimatedSeconds
}
