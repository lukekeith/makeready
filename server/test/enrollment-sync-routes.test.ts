/**
 * text-activity Task 12 (SC3, D5, §Contract sync row): the three sync routes run on program versions.
 * Version numbers are `ProgramVersion.number`, apply is `applyProgramVersion` to the program's current version,
 * and a customized lesson is skipped and reported. Each test gets a fresh world so version numbers start at 1.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import {
  createContentWorld, customizeForEnrollment, destroyContentWorld, publishNewVersion, seedEnrolledProgram,
  type ContentWorld,
} from './helpers/content-world.js'

describe('enrollment sync routes', () => {
  let w: ContentWorld
  beforeEach(async () => { w = await createContentWorld() })
  afterEach(async () => {
    // A hard delete takes the world's program; destroyContentWorld expects it, so stand a stub in.
    await prisma.studyProgram.createMany({
      data: [{ id: w.programId, name: 'stub', days: 1, creatorId: w.leader.userId }], skipDuplicates: true,
    })
    await destroyContentWorld(w)
  })

  const get = (path: string, token = w.leader.token) =>
    request(app).get(`/api/enrollments/${path}`).set('Authorization', bearer(token))
  const apply = (id: string, body: object = {}, token = w.leader.token) =>
    request(app).post(`/api/enrollments/${id}/sync/apply`).set('Authorization', bearer(token)).send(body)

  it('apply moves the enrollment and reports skipped customized lessons', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await customizeForEnrollment(s, 1)
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: v2.id } })
    const r = await request(app).post(`/api/enrollments/${s.enrollmentId}/sync/apply`).set('Authorization', bearer(w.leader.token)).send({})
    expect(r.status).toBe(200); expect(r.body.skippedCustomizedLessonIds).toEqual([s.lessonIds[1]])
  })

  it('apply returns today\'s outcome fields with the ProgramVersion number and moves the pointer', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    const r = await apply(s.enrollmentId)
    expect(r.status).toBe(200)
    expect(r.body).toMatchObject({
      success: true, alreadySynced: false, targetVersionNumber: v2.number,
      lessonsUpdated: 2, lessonsAdded: 0, lessonsRemoved: 0, skippedCustomizedLessonIds: [], fullySynced: true,
    })
    expect((await prisma.enrollment.findUniqueOrThrow({ where: { id: s.enrollmentId } })).programVersionId).toBe(v2.id)
    expect((await apply(s.enrollmentId)).body).toMatchObject({ alreadySynced: true, fullySynced: true })
  })

  it('apply with lessonKeys moves only the listed lessons and leaves the enrollment behind', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    await prisma.lessonVersion.create({
      data: { lessonId: s.lessonIds[1], number: 2, status: 'PUBLISHED', title: 'Second change', publishedAt: new Date() },
    }).then(async (lv) => {
      await prisma.programVersionLesson.update({
        where: { programVersionId_lessonId: { programVersionId: v2.id, lessonId: s.lessonIds[1] } },
        data: { lessonVersionId: lv.id },
      })
    })
    const r = await apply(s.enrollmentId, { lessonKeys: [s.lessonIds[0]] })
    expect(r.body).toMatchObject({ success: true, lessonsUpdated: 1, fullySynced: false })
    const rows = await prisma.scheduledLesson.findMany({ where: { enrollmentId: s.enrollmentId }, orderBy: { scheduledDate: 'asc' } })
    expect(rows[0].currentVersionId).not.toBe(s.versionIds[0])
    expect(rows[1].currentVersionId).toBe(s.versionIds[1])
    expect((await prisma.enrollment.findUniqueOrThrow({ where: { id: s.enrollmentId } })).programVersionId).toBe(s.programVersionId)
  })

  it('apply is 400 when the program has no published version', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: null } })
    expect((await apply(s.enrollmentId)).status).toBe(400)
  })

  it('sync status reports ProgramVersion numbers', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: v2.id } })
    const r = await request(app).get(`/api/enrollments/${s.enrollmentId}/sync`).set('Authorization', bearer(w.leader.token))
    expect(r.body).toMatchObject({ syncedProgramVersionNumber: 1, currentVersionNumber: 2 })
    expect(r.body.sync).toMatchObject({
      syncMode: 'OFF', syncedProgramVersionNumber: 1, currentVersionNumber: 2, hasDrift: true,
      pendingVersions: [expect.objectContaining({ versionNumber: 2, changedLessonIds: [s.lessonIds[0]] })],
    })
  })

  it('sync status has no drift once the enrollment is on the current version', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const r = await get(`${s.enrollmentId}/sync`)
    expect(r.body.sync).toMatchObject({ hasDrift: false, pendingVersions: [], syncedProgramVersionNumber: 1, currentVersionNumber: 1 })
  })

  it('sync changes lists the pending lesson with the target ProgramVersion number', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const v2 = await publishNewVersion(s, { changeLesson: 0 })
    const r = await get(`${s.enrollmentId}/sync/changes`)
    expect(r.body).toMatchObject({ success: true, targetVersionNumber: v2.number, hasPending: true })
    expect(r.body.changes[0]).toMatchObject({ key: s.lessonIds[0], type: 'updated' })
  })

  it('every sync route is 404 for a leader outside the organization', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const token = w.outsider.token
    expect((await get(`${s.enrollmentId}/sync`, token)).status).toBe(404)
    expect((await get(`${s.enrollmentId}/sync/changes`, token)).status).toBe(404)
    expect((await apply(s.enrollmentId, {}, token)).status).toBe(404)
  })

  it('sync after the program is deleted is 404', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    // The DB restricts a program delete while versions are scheduled, so the rows go in dependency order.
    await prisma.scheduledLesson.deleteMany({ where: { enrollmentId: s.enrollmentId } })
    await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: null } })
    await prisma.programVersionLesson.deleteMany({ where: { programVersion: { programId: s.programId } } })
    await prisma.studyProgram.delete({ where: { id: s.programId } })
    expect((await request(app).get(`/api/enrollments/${s.enrollmentId}/sync`).set('Authorization', bearer(w.leader.token))).status).toBe(404)
  })

  it('sync routes are 404 once the program is soft-deleted', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    await request(app).delete(`/api/programs/${s.programId}`).set('Authorization', bearer(w.leader.token))
    expect((await get(`${s.enrollmentId}/sync`)).status).toBe(404)
    expect((await get(`${s.enrollmentId}/sync/changes`)).status).toBe(404)
    expect((await apply(s.enrollmentId)).status).toBe(404)
  })
})
