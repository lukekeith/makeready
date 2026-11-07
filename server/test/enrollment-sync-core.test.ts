/**
 * text-activity D5, D37, 05 s3 "Sync": applyProgramVersion moves an enrollment's scheduled lessons onto a program
 * version by pointer, copies nothing, and writes no sync run.
 */
import { randomUUID } from 'node:crypto'
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import { prisma } from '../src/lib/prisma.js'
import { applyProgramVersion, createScheduledLessons, sendSyncPushes } from '../src/services/enrollment-sync.js'
import { computePendingChanges } from '../src/services/enrollment-sync-changes.js'
import {
  createContentWorld, customizeForEnrollment, destroyContentWorld, publishNewVersion, seedEnrolledProgram,
  type ContentWorld, type EnrolledProgram,
} from './helpers/content-world.js'

const failing = vi.hoisted(() => ({ dedupeKeys: new Set<string>() }))
vi.mock('../src/services/notification.js', async (importActual) => {
  const actual = await importActual<typeof import('../src/services/notification.js')>()
  return {
    ...actual,
    upsertNotificationByDedupeKey: (params: Parameters<typeof actual.upsertNotificationByDedupeKey>[0]) => {
      if (failing.dedupeKeys.has(params.dedupeKey)) throw new Error('push failed')
      return actual.upsertNotificationByDedupeKey(params)
    },
  }
})

const DAY = 24 * 3600 * 1000
const sameDayNext = (d: Date) => { const n = new Date(d); n.setDate(n.getDate() + 1); return n.getTime() }

/** A program version over `rows` (lesson, lessonVersion) in the given order, made the program's current version. */
async function versionOf(s: EnrolledProgram, rows: { lessonId: string; lessonVersionId: string }[]) {
  const latest = await prisma.programVersion.aggregate({ where: { programId: s.w.programId }, _max: { number: true } })
  const version = await prisma.programVersion.create({
    data: {
      programId: s.w.programId, number: (latest._max.number ?? 0) + 1,
      lessons: { create: rows.map((r, i) => ({ ...r, position: i + 1 })) },
    },
  })
  await prisma.studyProgram.update({ where: { id: s.w.programId }, data: { currentVersionId: version.id } })
  return version
}
const dateOf = async (enrollmentId: string, lessonId: string) =>
  (await prisma.scheduledLesson.findUniqueOrThrow({ where: { enrollmentId_lessonId: { enrollmentId, lessonId } } })).scheduledDate

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

  it('a lesson inserted mid-program lands in curriculum order and later lessons shift', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 3 })
    const x = await seedEnrolledProgram(w, { lessons: 1 })
    const orig = await Promise.all(s.lessonIds.map(id => dateOf(s.enrollmentId, id)))
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: s.enrollmentId } })
    await prisma.event.create({
      data: {
        groupId: enrollment.groupId, type: 'LESSON', title: 'Day 3', date: orig[2], scheduledLessonId: s.scheduledLessonIds[2],
        enrollmentId: s.enrollmentId, dayNumber: 3,
      },
    })
    const v = await versionOf(s, [
      { lessonId: s.lessonIds[0], lessonVersionId: s.versionIds[0] },
      { lessonId: x.lessonIds[0], lessonVersionId: x.versionIds[0] },
      { lessonId: s.lessonIds[1], lessonVersionId: s.versionIds[1] },
      { lessonId: s.lessonIds[2], lessonVersionId: s.versionIds[2] },
    ])
    const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v.id))
    expect(r.addedLessonIds).toEqual([x.lessonIds[0]])
    expect(r.datesShifted).toBe(2)
    expect((await dateOf(s.enrollmentId, s.lessonIds[0])).getTime()).toBe(orig[0].getTime())
    expect((await dateOf(s.enrollmentId, x.lessonIds[0])).getTime()).toBe(orig[1].getTime())
    expect((await dateOf(s.enrollmentId, s.lessonIds[1])).getTime()).toBe(orig[2].getTime())
    expect((await dateOf(s.enrollmentId, s.lessonIds[2])).getTime()).toBe(sameDayNext(orig[2]))
    const event = await prisma.event.findFirstOrThrow({ where: { scheduledLesson: { enrollmentId: s.enrollmentId, lessonId: s.lessonIds[2] } } })
    expect(event.dayNumber).toBe(4)
    expect(event.date.getTime()).toBe(sameDayNext(orig[2]))
  })

  it('an added lesson reuses the slot a removed lesson freed', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 3 })
    const x = await seedEnrolledProgram(w, { lessons: 1 })
    const orig = await Promise.all(s.lessonIds.map(id => dateOf(s.enrollmentId, id)))
    const v = await versionOf(s, [
      { lessonId: s.lessonIds[0], lessonVersionId: s.versionIds[0] },
      { lessonId: x.lessonIds[0], lessonVersionId: x.versionIds[0] },
      { lessonId: s.lessonIds[2], lessonVersionId: s.versionIds[2] },
    ])
    const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v.id))
    expect(r.removedLessonIds).toEqual([s.lessonIds[1]])
    expect(r.datesShifted).toBe(0)
    expect((await dateOf(s.enrollmentId, x.lessonIds[0])).getTime()).toBe(orig[1].getTime())
    expect((await dateOf(s.enrollmentId, s.lessonIds[2])).getTime()).toBe(orig[2].getTime())
  })

  it('overflow dates fall only on enabled days', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const x = await seedEnrolledProgram(w, { lessons: 1 })
    await prisma.enrollment.update({ where: { id: s.enrollmentId }, data: { enabledDays: JSON.stringify(['Mon']) } })
    const v = await versionOf(s, [
      { lessonId: s.lessonIds[0], lessonVersionId: s.versionIds[0] },
      { lessonId: x.lessonIds[0], lessonVersionId: x.versionIds[0] },
    ])
    await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v.id))
    const first = await dateOf(s.enrollmentId, s.lessonIds[0])
    const added = await dateOf(s.enrollmentId, x.lessonIds[0])
    expect(added.getDay()).toBe(1)
    expect(added.getTime()).toBeGreaterThan(first.getTime())
    expect(added.getTime() - first.getTime()).toBeLessThanOrEqual(7 * DAY)
  })

  it('a selective apply moves only the approved lessons and leaves the enrollment version alone', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const v2 = await publishNewVersion(s, { changeLesson: 0, dropLessons: [1] })
    const r = await prisma.$transaction(tx =>
      applyProgramVersion(tx, s.enrollmentId, v2.id, { only: new Set([s.lessonIds[0]]) }))
    expect(r.movedLessonIds).toEqual([s.lessonIds[0]])
    expect(r.removedLessonIds).toEqual([])
    expect(await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[1] } })).not.toBeNull()
    expect((await prisma.enrollment.findUniqueOrThrow({ where: { id: s.enrollmentId } })).programVersionId).toBe(s.programVersionId)
  })

  it('a lesson back in the program revives its soft-removed scheduled lesson', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[1] } })
    const v2 = await publishNewVersion(s, { dropLessons: [1] })
    await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
    expect((await prisma.scheduledLesson.findUniqueOrThrow({ where: { id: s.scheduledLessonIds[1] } })).removedAt).not.toBeNull()
    const v3 = await publishNewVersion(s, { changeLesson: 1 })
    await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v3.id))
    const revived = await prisma.scheduledLesson.findUniqueOrThrow({ where: { id: s.scheduledLessonIds[1] } })
    const target = await prisma.programVersionLesson.findUniqueOrThrow({
      where: { programVersionId_lessonId: { programVersionId: v3.id, lessonId: s.lessonIds[1] } },
    })
    expect(revived.removedAt).toBeNull()
    expect(revived.currentVersionId).toBe(target.lessonVersionId)
  })

  it('writes no sync run', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const v2 = await publishNewVersion(s, { changeLesson: 0, dropLessons: [1] })
    await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
    expect(await prisma.enrollmentSyncRun.count({ where: { enrollmentId: s.enrollmentId } })).toBe(0)
  })

  it('createScheduledLessons writes the lesson and its LESSON event, and rejects a lesson not in the version', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const x = await seedEnrolledProgram(w, { lessons: 1 })
    const v = await versionOf(s, [
      { lessonId: s.lessonIds[0], lessonVersionId: s.versionIds[0] },
      { lessonId: x.lessonIds[0], lessonVersionId: x.versionIds[0] },
    ])
    const date = new Date(Date.now() + 10 * DAY)
    const ids = await prisma.$transaction(tx =>
      createScheduledLessons(tx, s.enrollmentId, v.id, new Map([[x.lessonIds[0], date]])))
    expect(ids).toEqual([x.lessonIds[0]])
    const scheduled = await prisma.scheduledLesson.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId: s.enrollmentId, lessonId: x.lessonIds[0] } },
    })
    const event = await prisma.event.findUniqueOrThrow({ where: { scheduledLessonId: scheduled.id } })
    expect(event).toMatchObject({ type: 'LESSON', enrollmentId: s.enrollmentId, dayNumber: 2 })
    expect(event.date.getTime()).toBe(date.getTime())

    const missingId = randomUUID()
    const before = await prisma.scheduledLesson.count({ where: { enrollmentId: s.enrollmentId } })
    await expect(prisma.$transaction(tx =>
      createScheduledLessons(tx, s.enrollmentId, v.id, new Map([[missingId, date]])))).rejects.toThrow(missingId)
    expect(await prisma.scheduledLesson.count({ where: { enrollmentId: s.enrollmentId } })).toBe(before)
  })

  describe('sendSyncPushes', () => {
    it('tells AUTO leaders it applied, APPROVAL and OFF leaders updates wait, and isolates a failure', async () => {
      const auto = await seedEnrolledProgram(w, { lessons: 1 })
      const approval = await seedEnrolledProgram(w, { lessons: 1 })
      const off = await seedEnrolledProgram(w, { lessons: 1 })
      const broken = await seedEnrolledProgram(w, { lessons: 1 })
      const set = (s: EnrolledProgram, syncMode: 'AUTO' | 'APPROVAL' | 'OFF') =>
        prisma.enrollment.update({ where: { id: s.enrollmentId }, data: { syncMode, createdById: w.leader.userId } })
      await set(broken, 'APPROVAL'); await set(auto, 'AUTO'); await set(approval, 'APPROVAL'); await set(off, 'OFF')
      failing.dedupeKeys = new Set([`study-sync-updates:${broken.enrollmentId}`])
      const err = vi.spyOn(console, 'error').mockImplementation(() => undefined)
      try {
        const version = await prisma.programVersion.findUniqueOrThrow({ where: { id: auto.programVersionId } })
        await sendSyncPushes(
          [broken, auto, approval, off].map(e => e.enrollmentId),
          { id: version.id, programId: version.programId, number: version.number, changeSummary: 'Fixed day 1' },
        )
        expect(err).toHaveBeenCalledTimes(1)
      } finally {
        err.mockRestore()
        failing.dedupeKeys = new Set()
      }
      const note = (key: string) => prisma.notification.findFirst({ where: { userId: w.leader.userId, dedupeKey: key } })
      expect((await note(`study-sync-applied:${auto.enrollmentId}`))!.type).toBe('STUDY_SYNC_APPLIED')
      expect(await note(`study-sync-updates:${auto.enrollmentId}`)).toBeNull()
      const waiting = await note(`study-sync-updates:${approval.enrollmentId}`)
      expect(waiting).toMatchObject({ type: 'STUDY_SYNC_UPDATES_AVAILABLE' })
      expect((waiting!.data as any).syncMode).toBe('APPROVAL')
      expect((await note(`study-sync-updates:${off.enrollmentId}`))!.data).toMatchObject({ syncMode: 'OFF' })
      expect(await note(`study-sync-updates:${broken.enrollmentId}`)).toBeNull()
      await prisma.notification.deleteMany({ where: { userId: w.leader.userId } })
    })
  })
})
