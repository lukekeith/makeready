/**
 * Backfill script for the study-sync versioning feature.
 *
 * Brings pre-versioning data up to the new invariants:
 *  1. Every ScheduledLessonActivity copied from curriculum gets its lineageKey
 *     (= sourceLessonActivityId at copy time).
 *  2. Every LessonSchedule gets a v1 LessonScheduleVersion whose
 *     sourceContentHash is the canonical hash of its *current* curriculum
 *     lesson (baseline: existing enrollments are treated as in-sync at
 *     backfill time; only forward drift is tracked).
 *  3. Schedules point at their v1 via currentVersionId, and their activity
 *     rows are stamped with versionId.
 *
 * Idempotent: every step only touches rows that are still missing the new
 * fields, so it can be re-run safely (including after a mid-run crash).
 *
 * Run: npm run backfill:study-sync
 */

import { randomUUID } from 'crypto'
import { prisma } from '../lib/prisma.js'
import { hashLessonContent, LESSON_CONTENT_INCLUDE } from '../services/lesson-content-hash.js'

const CHUNK = 500

async function main() {
  console.log('🔄 Study-sync backfill starting...')

  // Step 1: lineage keys (single statement, idempotent)
  const lineageCount = await prisma.$executeRaw`
    UPDATE scheduled_lesson_activities
    SET "lineageKey" = "sourceLessonActivityId"
    WHERE "lineageKey" IS NULL AND "sourceLessonActivityId" IS NOT NULL
  `
  console.log(`   Step 1: lineageKey stamped on ${lineageCount} activities`)

  // Step 2: find schedules that still need a v1 version
  const schedules = await prisma.lessonSchedule.findMany({
    where: { currentVersionId: null },
    select: { id: true, lessonId: true },
  })
  console.log(`   Step 2: ${schedules.length} schedules need a v1 version`)

  if (schedules.length > 0) {
    // Step 3: hash each distinct curriculum lesson once (orphaned schedules
    // whose curriculum lesson was deleted get a null hash)
    const lessonIds = [
      ...new Set(schedules.map((s) => s.lessonId).filter((id): id is string => id !== null)),
    ]
    const hashByLessonId = new Map<string, string>()
    for (let i = 0; i < lessonIds.length; i += CHUNK) {
      const lessons = await prisma.lesson.findMany({
        where: { id: { in: lessonIds.slice(i, i + CHUNK) } },
        include: LESSON_CONTENT_INCLUDE,
      })
      for (const lesson of lessons) {
        hashByLessonId.set(lesson.id, hashLessonContent(lesson as any))
      }
    }
    console.log(`   Step 3: hashed ${hashByLessonId.size} curriculum lessons`)

    // Step 4: create v1 versions (skipDuplicates + versionNumber unique makes
    // this safe against concurrent/partial prior runs)
    for (let i = 0; i < schedules.length; i += CHUNK) {
      await prisma.lessonScheduleVersion.createMany({
        data: schedules.slice(i, i + CHUNK).map((s) => ({
          id: randomUUID(),
          lessonScheduleId: s.id,
          versionNumber: 1,
          programVersionNumber: null,
          sourceContentHash: (s.lessonId ? hashByLessonId.get(s.lessonId) : null) ?? null,
        })),
        skipDuplicates: true,
      })
    }
    console.log(`   Step 4: v1 versions created`)
  }

  // Step 5: point schedules at their v1 (covers rows from any prior partial run)
  const pointedCount = await prisma.$executeRaw`
    UPDATE lesson_schedules ls
    SET "currentVersionId" = v.id
    FROM lesson_schedule_versions v
    WHERE v."lessonScheduleId" = ls.id
      AND v."versionNumber" = 1
      AND ls."currentVersionId" IS NULL
  `
  console.log(`   Step 5: currentVersionId set on ${pointedCount} schedules`)

  // Step 6: stamp existing activities with their schedule's v1
  const stampedCount = await prisma.$executeRaw`
    UPDATE scheduled_lesson_activities sa
    SET "versionId" = v.id
    FROM lesson_schedule_versions v
    WHERE v."lessonScheduleId" = sa."lessonScheduleId"
      AND v."versionNumber" = 1
      AND sa."versionId" IS NULL
  `
  console.log(`   Step 6: versionId stamped on ${stampedCount} activities`)

  // Verify invariants
  const [schedulesMissing, activitiesMissing] = await Promise.all([
    prisma.lessonSchedule.count({ where: { currentVersionId: null } }),
    prisma.scheduledLessonActivity.count({ where: { versionId: null } }),
  ])
  if (schedulesMissing > 0 || activitiesMissing > 0) {
    throw new Error(
      `Backfill incomplete: ${schedulesMissing} schedules and ${activitiesMissing} activities still unversioned`
    )
  }

  console.log('✅ Study-sync backfill complete — all schedules and activities versioned')
}

main()
  .catch((error) => {
    console.error('❌ Study-sync backfill failed:', error)
    process.exitCode = 1
  })
  .finally(() => prisma.$disconnect())
