/**
 * text-activity Task 9 (SC2, SC10, D26, D35, D36): the program read and the lesson writes run on lesson
 * versions. Lessons list from their draft, else their latest published version; create, title edit,
 * delete and reorder go through the service and authorize by org (404 otherwise).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { randomUUID } from 'node:crypto'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, seedPublishedLesson, type ContentWorld } from './helpers/content-world.js'
import { copyLessonActivities } from '../src/services/lesson-copy.js'
import { sumEstimatedSeconds } from '../src/services/lesson-estimate.service.js'

describe('the program read and lesson writes', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  const lessonUrl = (lessonId: string, programId = w.programId) => `/api/programs/${programId}/lessons/${lessonId}`

  it('the program read lists lessons from the draft, else the published version', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    const r = await request(app).get(`/api/programs/${w.programId}`).set('Authorization', bearer(w.leader.token))
    const [l1, l2] = r.body.lessons
    expect(l1).toMatchObject({ id: w.lessonId, title: 'Day 1', draftVersionId: w.draftVersionId, publishedVersionId: null, activities: [] })
    expect(l2).toMatchObject({ id: pub.lessonId, draftVersionId: null, publishedVersionId: pub.versionId })
    expect(l2.activities[0]).toEqual(expect.objectContaining({ activityKey: 'k1', kind: 'text', document: expect.any(Object) }))
    expect(r.body.media).toEqual({})
  })

  it('create makes a lesson and its draft; a title edit lands in the draft', async () => {
    const c = await request(app).post(`/api/programs/${w.programId}/lessons`).set('Authorization', bearer(w.leader.token)).send({ title: 'Day 2' })
    const lessonId = c.body.lesson?.id ?? c.body.id
    await request(app).patch(lessonUrl(lessonId)).set('Authorization', bearer(w.leader.token)).send({ title: 'Renamed' })
    const d = await prisma.lessonVersion.findFirst({ where: { lessonId, status: 'DRAFT' } })
    expect(d!.title).toBe('Renamed')
  })

  it('delete soft-deletes a published lesson and hard-deletes a draft-only one', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    await prisma.lessonVersion.create({ data: { lessonId: pub.lessonId, number: 2, status: 'DRAFT', title: 'Edit' } })
    await request(app).delete(lessonUrl(pub.lessonId)).set('Authorization', bearer(w.leader.token))
    await request(app).delete(lessonUrl(w.lessonId)).set('Authorization', bearer(w.leader.token))
    expect((await prisma.lesson.findUnique({ where: { id: pub.lessonId } }))!.deletedAt).not.toBeNull()
    expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId, status: 'DRAFT' } })).toBe(0)
    expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId, status: 'PUBLISHED' } })).toBe(1)
    expect(await prisma.lesson.findUnique({ where: { id: w.lessonId } })).toBeNull()
  })

  it('lesson writes from another org are 404', async () => {
    const lesson = await prisma.lesson.create({ data: { programId: w.programId, position: 50 } })
    const patch = await request(app).patch(lessonUrl(lesson.id)).set('Authorization', bearer(w.outsider.token)).send({ title: 'x' })
    const del = await request(app).delete(lessonUrl(lesson.id)).set('Authorization', bearer(w.outsider.token))
    const create = await request(app).post(`/api/programs/${w.programId}/lessons`).set('Authorization', bearer(w.outsider.token)).send({})
    const reorder = await request(app).post(`/api/programs/${w.programId}/reorder-lessons`).set('Authorization', bearer(w.outsider.token)).send({ lessonOrder: [lesson.id] })
    expect([patch.status, del.status, create.status, reorder.status]).toEqual([404, 404, 404, 404])
    expect(await prisma.lesson.findUnique({ where: { id: lesson.id } })).not.toBeNull()
    await prisma.lesson.delete({ where: { id: lesson.id } })
  })

  it('a lesson id under another program is 404', async () => {
    const other = await prisma.studyProgram.create({ data: { name: 'Other', days: 0, creatorId: w.leader.userId, organizationId: w.orgId } })
    const r = await request(app).patch(lessonUrl(w.lessonId, other.id)).set('Authorization', bearer(w.leader.token)).send({ title: 'x' })
    expect(r.status).toBe(404)
    await prisma.studyProgram.delete({ where: { id: other.id } })
  })

  describe('positions and counts', () => {
    let programId: string
    const ids: string[] = []
    beforeAll(async () => {
      const p = await prisma.studyProgram.create({ data: { name: 'Positions', days: 0, creatorId: w.leader.userId, organizationId: w.orgId } })
      programId = p.id
      for (let i = 0; i < 3; i++) {
        const c = await request(app).post(`/api/programs/${programId}/lessons`).set('Authorization', bearer(w.leader.token)).send({ title: `L${i + 1}` })
        ids.push(c.body.lesson.id)
      }
    })
    afterAll(async () => {
      await prisma.lesson.deleteMany({ where: { programId } })
      await prisma.studyProgram.delete({ where: { id: programId } })
    })

    it('create appends at the next position and keeps days at the live count', async () => {
      const lessons = await prisma.lesson.findMany({ where: { programId }, orderBy: { position: 'asc' } })
      expect(lessons.map((l) => l.position)).toEqual([1, 2, 3])
      expect((await prisma.studyProgram.findUnique({ where: { id: programId } }))!.days).toBe(3)
    })

    it('reorder-lessons rewrites positions and rejects a partial set', async () => {
      const order = [ids[2], ids[0], ids[1]]
      const ok = await request(app).post(`/api/programs/${programId}/reorder-lessons`).set('Authorization', bearer(w.leader.token)).send({ lessonOrder: order })
      expect(ok.status).toBe(200)
      const got = await request(app).get(`/api/programs/${programId}`).set('Authorization', bearer(w.leader.token))
      expect(got.body.lessons.map((l: any) => l.id)).toEqual(order)
      const bad = await request(app).post(`/api/programs/${programId}/reorder-lessons`).set('Authorization', bearer(w.leader.token)).send({ lessonOrder: [ids[0]] })
      expect(bad.status).toBe(400)
    })

    it('delete closes the live positions up and a deleted lesson drops out of the read', async () => {
      const del = await request(app).delete(lessonUrl(ids[2], programId)).set('Authorization', bearer(w.leader.token))
      expect(del.status).toBe(200)
      const got = await request(app).get(`/api/programs/${programId}`).set('Authorization', bearer(w.leader.token))
      expect(got.body.lessons.map((l: any) => [l.id, l.position])).toEqual([[ids[0], 1], [ids[1], 2]])
      expect(got.body.program.days).toBe(2)
    })
  })

  it('a program created from a template gets a lesson and a draft per day holding the starter activities', async () => {
    const template = await prisma.lessonTemplate.create({
      data: {
        name: 'Starter', isSystem: false, creatorId: w.leader.userId, organizationId: w.orgId,
        activities: {
          create: [
            {
              orderNumber: 1, title: 'Intro', kind: 'text',
              document: {
                schemaVersion: 1, kind: 'text', background: { color: '#0E4A4D' },
                content: { type: 'canvas', verticalAnchor: 'center', objects: [] }, actions: [], chrome: { topAction: 'none' },
                fallback: { title: 'Intro', body: 'Welcome' },
              },
            },
            { orderNumber: 2, title: 'Legacy only' },
          ],
        },
      },
    })
    const r = await request(app).post('/api/programs').set('Authorization', bearer(w.leader.token)).send({ name: 'From template', templateId: template.id, days: 2 })
    expect(r.status).toBe(200)
    const programId = r.body.program.id
    const lessons = await prisma.lesson.findMany({
      where: { programId }, orderBy: { position: 'asc' },
      include: { versions: { include: { activities: true } } },
    })
    expect(lessons.map((l) => l.position)).toEqual([1, 2])
    for (const l of lessons) {
      expect(l.versions).toHaveLength(1)
      expect(l.versions[0]).toMatchObject({ number: 1, status: 'DRAFT', title: 'Starter' })
      expect(l.versions[0].activities.map((a) => [a.kind, a.title, a.position])).toEqual([['text', 'Intro', 0]])
    }
    expect(new Set(lessons.flatMap((l) => l.versions[0].activities.map((a) => a.activityKey))).size).toBe(2)
    expect(r.body.program.lessons).toHaveLength(2)
    await prisma.studyProgram.delete({ where: { id: programId } })
    await prisma.lessonTemplate.delete({ where: { id: template.id } })
  })

  it('copyLessonActivities copies the draft, else the latest published, with new keys', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'src-1' }, { activityKey: 'src-2' }])
    const target = await prisma.lesson.create({ data: { programId: w.programId, position: 60 } })
    const draft = await prisma.lessonVersion.create({ data: { lessonId: target.id, number: 1, status: 'DRAFT', title: 't' } })
    await prisma.$transaction((tx) => copyLessonActivities(tx, pub.lessonId, draft.id))
    const copied = await prisma.contentActivity.findMany({ where: { lessonVersionId: draft.id }, orderBy: { position: 'asc' } })
    expect(copied.map((a) => a.position)).toEqual([0, 1])
    expect(copied.map((a) => a.activityKey)).not.toContain('src-1')
    expect(copied.map((a) => a.activityKey)).not.toContain('src-2')
    expect(copied.every((a) => a.kind === 'text')).toBe(true)

    // A draft on the source wins over its published version.
    const srcDraft = await prisma.lessonVersion.create({ data: { lessonId: pub.lessonId, number: 2, status: 'DRAFT', title: 'd' } })
    await prisma.contentActivity.create({
      data: { lessonVersionId: srcDraft.id, activityKey: randomUUID(), position: 1, kind: 'text', title: 'Only in draft', document: {} },
    })
    const target2 = await prisma.lesson.create({ data: { programId: w.programId, position: 61 } })
    const draft2 = await prisma.lessonVersion.create({ data: { lessonId: target2.id, number: 1, status: 'DRAFT' } })
    await prisma.$transaction((tx) => copyLessonActivities(tx, pub.lessonId, draft2.id))
    const copied2 = await prisma.contentActivity.findMany({ where: { lessonVersionId: draft2.id } })
    expect(copied2.map((a) => a.title)).toEqual(['Only in draft'])
  })

  it('sumEstimatedSeconds adds the activities and is null when there is nothing to add', () => {
    expect(sumEstimatedSeconds([{ estimatedSeconds: 30 }, { estimatedSeconds: null }, { estimatedSeconds: 45 }])).toBe(75)
    expect(sumEstimatedSeconds([])).toBeNull()
    expect(sumEstimatedSeconds([{ estimatedSeconds: null }])).toBeNull()
  })
})
