/**
 * text-activity D5, D37, 05 s3 "Sync": applyProgramVersion moves an enrollment's scheduled lessons onto a program
 * version by pointer, copies nothing, and writes no sync run.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { prisma } from '../src/lib/prisma.js'
import { applyProgramVersion } from '../src/services/enrollment-sync.js'
import { computePendingChanges } from '../src/services/enrollment-sync-changes.js'
import {
  createContentWorld, customizeForEnrollment, destroyContentWorld, publishNewVersion, seedEnrolledProgram,
  type ContentWorld,
} from './helpers/content-world.js'

describe('sync core', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  it('sync moves pointers and copies nothing', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    const before = await prisma.contentActivity.count()
    const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
    expect(r.movedLessonIds).toEqual([s.lessonIds[0], s.lessonIds[1]])
    expect(await prisma.contentActivity.count()).toBe(before)
    expect((await prisma.enrollment.findUnique({ where: { id: s.enrollmentId } }))!.programVersionId).toBe(v2.id)
    const moved = await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[0] } })
    const target = await prisma.programVersionLesson.findUniqueOrThrow({
      where: { programVersionId_lessonId: { programVersionId: v2.id, lessonId: s.lessonIds[0] } },
    })
    expect(moved!.currentVersionId).toBe(target.lessonVersionId)
  })

  it('a removed lesson is deleted without progress and soft-removed with it', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[1] } })
    const v2 = await publishNewVersion(s, { dropLessons: [0, 1] })
    await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
    expect(await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[0] } })).toBeNull()
    expect((await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[1] } }))!.removedAt).not.toBeNull()
  })

  it('a customized lesson is skipped and reported', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const groupV = await customizeForEnrollment(s, 0)
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
    expect(r.skippedCustomizedLessonIds).toEqual([s.lessonIds[0]])
    expect((await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[0] } }))!.currentVersionId).toBe(groupV.id)
  })

  it('writes the scheduled lesson for a lesson the enrollment never had, after its last date', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const extra = await seedEnrolledProgram(w, { lessons: 1 })
    // A program version = the first seed's lesson plus the second seed's lesson (both PUBLISHED already).
    const v = await prisma.programVersion.create({
      data: {
        programId: w.programId, number: (await publishNewVersion(extra)).number + 1,
        lessons: { create: [
          { lessonId: s.lessonIds[0], lessonVersionId: s.versionIds[0], position: 1 },
          { lessonId: extra.lessonIds[0], lessonVersionId: extra.versionIds[0], position: 2 },
        ] },
      },
    })
    const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v.id))
    expect(r.addedLessonIds).toEqual([extra.lessonIds[0]])
    const added = await prisma.scheduledLesson.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId: s.enrollmentId, lessonId: extra.lessonIds[0] } },
    })
    const first = await prisma.scheduledLesson.findUniqueOrThrow({ where: { id: s.scheduledLessonIds[0] } })
    expect(added.scheduledDate.getTime()).toBeGreaterThan(first.scheduledDate.getTime())
    expect(added.currentVersionId).toBe(extra.versionIds[0])
  })

  it('reports pending changes between the enrollment version and the current one', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    expect((await computePendingChanges(s.enrollmentId)).hasPending).toBe(false)
    const v2 = await publishNewVersion(s, { changeLesson: 0, dropLessons: [1] })
    const pending = await computePendingChanges(s.enrollmentId)
    expect(pending.targetVersionNumber).toBe(v2.number)
    expect(pending.changes.map(c => [c.key, c.type])).toEqual([[s.lessonIds[0], 'updated'], [s.lessonIds[1], 'removed']])
    expect(pending.counts).toMatchObject({ lessonsUpdated: 1, lessonsRemoved: 1 })
  })
})
