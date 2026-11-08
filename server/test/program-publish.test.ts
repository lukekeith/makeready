/**
 * text-activity D20, D32, D35, D37: publish freezes each changed lesson's draft into a PUBLISHED version, discards
 * unchanged drafts, writes one ProgramVersion, moves AUTO enrollments inside the transaction and rolls back whole.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import * as sync from '../src/services/enrollment-sync.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, seedEnrolledProgram, type ContentWorld } from './helpers/content-world.js'

const doc = (body: string) => ({
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D' },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body },
})
// Each test makes several HTTP calls and a publish transaction; the suite runs with the whole server suite beside it.
vi.setConfig({ testTimeout: 30_000, hookTimeout: 30_000 })

const EDITED_DOC = doc('edited')
const RACE_DOC = doc('raced')

let w: ContentWorld
beforeEach(async () => {
  w = await createContentWorld()
  // The world's own lesson has only an empty draft; drop it so seeded lessons take positions 1..n.
  await prisma.lessonVersion.delete({ where: { id: w.draftVersionId } })
  await prisma.lesson.delete({ where: { id: w.lessonId } })
})
afterEach(async () => {
  vi.restoreAllMocks()
  await destroyContentWorld(w)
})

const openDraft = async (lessonId: string) => {
  const r = await request(app).get(`/api/lessons/${lessonId}/draft`).set('Authorization', bearer(w.leader.token))
  expect(r.status).toBe(200)
  return r.body as { version: { id: string }; activities: { id: string }[] }
}
const editFirstActivity = async (lessonId: string) => {
  const draft = await openDraft(lessonId)
  const r = await request(app).put(`/api/content-activities/${draft.activities[0].id}`)
    .set('Authorization', bearer(w.leader.token)).send({ document: EDITED_DOC })
  expect(r.status).toBe(200)
}
const publish = (programId: string, body: unknown = {}, token = w.leader.token) =>
  request(app).post(`/api/programs/${programId}/publish`).set('Authorization', bearer(token)).send(body as object)

describe('publish', () => {
  it('publish freezes changed lessons and skips unchanged ones', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await openDraft(s.lessonIds[0]); await openDraft(s.lessonIds[1])
    await editFirstActivity(s.lessonIds[0])
    const r = await publish(w.programId)
    expect(r.status).toBe(200); expect(r.body.changedLessonIds).toEqual([s.lessonIds[0]])
    expect(await prisma.lessonVersion.count({ where: { lessonId: s.lessonIds[1], status: 'DRAFT' } })).toBe(0)
  })

  it('publish with no changes writes nothing and sends no push', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
    const push = vi.spyOn(sync, 'sendSyncPushes')
    const before = await prisma.programVersion.count()
    const r = await publish(w.programId)
    expect(r.body).toEqual({ programVersion: null, changedLessonIds: [] })
    expect(await prisma.programVersion.count()).toBe(before); expect(push).not.toHaveBeenCalled()
  })

  it('AUTO enrollments move inside the publish; a PUT racing publish leaves the frozen version unchanged', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
    const draft = await openDraft(s.lessonIds[0]); await editFirstActivity(s.lessonIds[0])
    const [pub, put] = await Promise.all([
      publish(w.programId),
      request(app).put(`/api/content-activities/${draft.activities[0].id}`).set('Authorization', bearer(w.leader.token)).send({ document: RACE_DOC }),
    ])
    expect(pub.status).toBe(200)
    const frozen = await prisma.contentActivity.findFirst({ where: { lessonVersionId: draft.version.id } })
    if (put.status === 409) expect(frozen!.document).not.toEqual(RACE_DOC)
    expect((await prisma.enrollment.findUnique({ where: { id: s.enrollmentId } }))!.programVersionId).toBe(pub.body.programVersion.id)
  })

  it('a failure inside publish rolls everything back', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
    await openDraft(s.lessonIds[0]); await editFirstActivity(s.lessonIds[0])
    vi.spyOn(sync, 'applyProgramVersion').mockRejectedValueOnce(new Error('boom'))
    await publish(w.programId)
    expect(await prisma.lessonVersion.count({ where: { lessonId: s.lessonIds[0], status: 'DRAFT' } })).toBe(1)
    expect((await prisma.studyProgram.findUnique({ where: { id: w.programId } }))!.currentVersionId).toBe(s.programVersionId)
  })

  it("another org's leader gets 404", async () => {
    const r = await publish(w.programId, {}, w.outsider.token)
    expect(r.status).toBe(404)
  })

  it('a changeSummary that is not a string is 400 VALIDATION', async () => {
    const r = await publish(w.programId, { changeSummary: 5 })
    expect(r.status).toBe(400); expect(r.body.code).toBe('VALIDATION')
  })

  it('the frozen version records number, hash, publisher and rows; APPROVAL enrollments stay behind', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2, syncMode: 'APPROVAL' })
    await editFirstActivity(s.lessonIds[0])
    const r = await publish(w.programId, { changeSummary: 'Reworded day 1' })
    expect(r.status).toBe(200)
    expect(r.body.programVersion).toMatchObject({ number: s.programVersionNumber + 1, changeSummary: 'Reworded day 1', publishedById: w.leader.userId })
    const rows = await prisma.programVersionLesson.findMany({ where: { programVersionId: r.body.programVersion.id }, orderBy: { position: 'asc' } })
    expect(rows.map(x => x.lessonId)).toEqual(s.lessonIds)
    expect(rows[1].lessonVersionId).toBe(s.versionIds[1])
    const frozen = await prisma.lessonVersion.findUniqueOrThrow({ where: { id: rows[0].lessonVersionId } })
    expect(frozen).toMatchObject({ status: 'PUBLISHED', publishedById: w.leader.userId })
    expect(frozen.contentHash).toMatch(/^[0-9a-f]{64}$/); expect(frozen.publishedAt).not.toBeNull()
    expect((await prisma.studyProgram.findUnique({ where: { id: w.programId } }))!.currentVersionId).toBe(r.body.programVersion.id)
    expect((await prisma.enrollment.findUnique({ where: { id: s.enrollmentId } }))!.programVersionId).toBe(s.programVersionId)
  })

  it('flipping isPublished on through PATCH publishes the program', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    await editFirstActivity(s.lessonIds[0])
    const r = await request(app).patch(`/api/programs/${w.programId}`).set('Authorization', bearer(w.leader.token)).send({ isPublished: true })
    expect(r.status).toBe(200)
    expect(await prisma.programVersion.count({ where: { programId: w.programId } })).toBe(2)
  })
})
