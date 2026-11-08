/**
 * Lesson Copy Service
 *
 * text-activity: `copyLessonActivities` copies one lesson's current content (its draft, else its latest
 * published version) into another lesson's draft with new `activityKey`s.
 */

import type { Prisma } from '../generated/prisma/index.js'
import { randomUUID } from 'crypto'
import { syncActivityMediaUsage } from './content-media.service.js'
import { recalculateVersionEstimate } from './lesson-estimate.service.js'

/**
 * Copies the source lesson's draft (else its latest published version) activities onto the end of the
 * target draft with new `activityKey`s, in the source's order; returns how many were copied. The caller
 * holds the target draft's lock. Media usage and the version's estimate follow the copy.
 */
export async function copyLessonActivities(
  tx: Prisma.TransactionClient,
  sourceLessonId: string,
  targetVersionId: string
): Promise<number> {
  const source =
    (await tx.lessonVersion.findFirst({ where: { lessonId: sourceLessonId, enrollmentId: null, status: 'DRAFT' } })) ??
    (await tx.lessonVersion.findFirst({
      where: { lessonId: sourceLessonId, enrollmentId: null, status: 'PUBLISHED' },
      orderBy: { number: 'desc' },
    }))
  if (!source) return 0

  const activities = await tx.contentActivity.findMany({ where: { lessonVersionId: source.id }, orderBy: { position: 'asc' } })
  if (activities.length === 0) return 0

  const last = await tx.contentActivity.aggregate({ where: { lessonVersionId: targetVersionId }, _max: { position: true } })
  const offset = last._max.position ?? -1
  const rows = activities.map((a, index) => ({
    lessonVersionId: targetVersionId,
    activityKey: randomUUID(),
    position: offset + 1 + index,
    kind: a.kind,
    title: a.title,
    document: a.document as Prisma.InputJsonValue,
    estimatedSeconds: a.estimatedSeconds,
  }))
  await tx.contentActivity.createMany({ data: rows })
  for (const row of rows) await syncActivityMediaUsage(tx, row.activityKey)
  await recalculateVersionEstimate(tx, targetVersionId)
  return rows.length
}
