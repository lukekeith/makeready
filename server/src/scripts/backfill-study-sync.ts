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
import { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { hashLessonContent, LESSON_CONTENT_INCLUDE } from '../services/lesson-content-hash.js'
import { buildSnapshotLessons } from '../services/study-program-publish.js'

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

  // Step 7: baseline StudyProgramVersion (v1) for every published program that
  // has none — programs published before versioning shipped. The baseline is
  // the CURRENT curriculum (no historical snapshot exists), changeSummary and
  // changedLessonIds null, publishedById null (system cut). Without this,
  // "Publish updates" has nothing to diff against and the publish modal can't
  // summarize pending changes.
  const unversionedPrograms = await prisma.studyProgram.findMany({
    where: { isPublished: true, versions: { none: {} } },
    include: {
      lessons: { orderBy: { dayNumber: 'asc' }, include: LESSON_CONTENT_INCLUDE },
    },
  })
  console.log(`   Step 7: ${unversionedPrograms.length} published programs need a baseline version`)

  const baselinedProgramIds: string[] = []
  for (const program of unversionedPrograms) {
    const snapshotLessons = buildSnapshotLessons(program.lessons as any[])
    const lessonHashes = Object.fromEntries(snapshotLessons.map((l) => [l.id, l.contentHash]))
    try {
      await prisma.$transaction([
        prisma.studyProgramVersion.create({
          data: {
            studyProgramId: program.id,
            versionNumber: 1,
            publishedById: null,
            changeSummary: null,
            snapshot: { lessons: snapshotLessons } as unknown as Prisma.InputJsonValue,
            lessonHashes: lessonHashes as unknown as Prisma.InputJsonValue,
            changedLessonIds: Prisma.JsonNull,
          },
        }),
        prisma.studyProgram.update({
          where: { id: program.id },
          data: { currentVersionNumber: 1 },
        }),
      ])
      baselinedProgramIds.push(program.id)
      console.log(`      baselined '${program.name}' at v1 (${snapshotLessons.length} lessons)`)
    } catch (error) {
      // Unique (studyProgramId, versionNumber) — a concurrent run won; fine.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') continue
      throw error
    }
  }

  // Step 8: stamp enrollments of freshly-baselined programs as in-sync at v1
  // — but ONLY where their enrolled content actually matches v1's hashes.
  // Curriculum edited after enrollment but before this backfill IS detectable
  // (schedule v1 hashes were cut earlier from the then-current curriculum), so
  // enrollments with real content drift stay unstamped: they show
  // "Updates available — version 1" and applying delivers the edits. No
  // notifications are sent either way (this is a backfill, not a publish).
  if (baselinedProgramIds.length > 0) {
    let inSync = 0
    let drifted = 0
    for (const programId of baselinedProgramIds) {
      const version = await prisma.studyProgramVersion.findFirst({
        where: { studyProgramId: programId, versionNumber: 1 },
        select: { lessonHashes: true },
      })
      const hashes = (version?.lessonHashes ?? {}) as Record<string, string>

      const enrollments = await prisma.enrollment.findMany({
        where: { studyProgramId: programId, syncedProgramVersionNumber: null },
        select: {
          id: true,
          lessonSchedules: {
            where: { removedAt: null },
            select: {
              lessonId: true,
              currentVersion: { select: { sourceContentHash: true } },
            },
          },
        },
      })

      for (const enrollment of enrollments) {
        const hasContentDrift = enrollment.lessonSchedules.some(
          (s) =>
            s.lessonId !== null &&
            hashes[s.lessonId] !== undefined &&
            s.currentVersion?.sourceContentHash != null &&
            s.currentVersion.sourceContentHash !== hashes[s.lessonId]
        )
        if (hasContentDrift) {
          drifted++
          continue
        }
        await prisma.enrollment.update({
          where: { id: enrollment.id },
          data: { syncedProgramVersionNumber: 1 },
        })
        inSync++
      }
    }
    console.log(`   Step 8: ${inSync} enrollments baselined at v1, ${drifted} left drifted (content differs from v1)`)
  }

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
