/**
 * text-activity D31/D35/D36: reading a lesson's draft (created from the latest published version, keys kept)
 * and a version, authorized in the service with 404 for no access.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, seedPublishedLesson, type ContentWorld } from './helpers/content-world.js'

describe('reading a draft and a version', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  it('the draft keeps every activityKey of the latest published version', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }, { activityKey: 'k2' }])
    const res = await request(app).get(`/api/lessons/${pub.lessonId}/draft`).set('Authorization', bearer(w.leader.token))
    expect(res.status).toBe(200)
    expect(res.body.version).toMatchObject({ status: 'DRAFT', number: 2, enrollmentId: null })
    expect(res.body.activities.map((a: any) => a.activityKey)).toEqual(['k1', 'k2'])
    expect(res.body.media).toEqual({})
  })

  it('ten concurrent draft reads create one draft', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    const res = await Promise.all(Array.from({ length: 10 }, () =>
      request(app).get(`/api/lessons/${pub.lessonId}/draft`).set('Authorization', bearer(w.leader.token))))
    expect(res.every(r => r.status === 200)).toBe(true)
    expect(new Set(res.map(r => r.body.version.id)).size).toBe(1)
    expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId, status: 'DRAFT' } })).toBe(1)
  })

  it("another org's leader gets 404 on both reads", async () => {
    const a = await request(app).get(`/api/lessons/${w.lessonId}/draft`).set('Authorization', bearer(w.outsider.token))
    const b = await request(app).get(`/api/lesson-versions/${w.draftVersionId}`).set('Authorization', bearer(w.outsider.token))
    expect([a.status, b.status]).toEqual([404, 404])
    expect(a.body).toMatchObject({ success: false, code: 'NOT_FOUND' })
  })

  it('a soft-deleted lesson has no draft', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    await prisma.lesson.update({ where: { id: pub.lessonId }, data: { deletedAt: new Date() } })
    const res = await request(app).get(`/api/lessons/${pub.lessonId}/draft`).set('Authorization', bearer(w.leader.token))
    expect(res.status).toBe(404)
  })

  it('a version read is read-only and returns the media map', async () => {
    const m = await createMedia(w.orgId)
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1', mediaId: m.id }])
    const res = await request(app).get(`/api/lesson-versions/${pub.versionId}`).set('Authorization', bearer(w.leader.token))
    expect(res.body.version.status).toBe('PUBLISHED')
    expect(Object.keys(res.body.media)).toEqual([m.id])
    expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId } })).toBe(1)
  })
})
