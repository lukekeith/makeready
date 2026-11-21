/** notes Task 7: one request test per §Contract row, the shape the iPhone decodes (frozen). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, type ContentWorld } from './helpers/content-world.js'

describe('notes §Contract', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId: w.leader.userId } })
    await destroyContentWorld(w)
  })

  it('every §Contract row answers the frozen shape', async () => {
    const auth = { Authorization: bearer(w.leader.token) }
    const c = await request(app).post('/api/notes').set(auth).send({ type: 'NOTE', content: '# Shape\nbody' })
    expect(c.status).toBe(201)
    expect(Object.keys(c.body.data).sort()).toEqual(['content', 'contextLabel', 'createdAt', 'id', 'isActive', 'links', 'memberId', 'preview', 'title', 'type', 'updatedAt', 'userId'])
    const l = await request(app).get('/api/notes?type=NOTE&orderBy=updatedAt&limit=100').set(auth)
    expect(Object.keys(l.body.pagination).sort()).toEqual(['hasMore', 'limit', 'offset', 'total'])
    const g = await request(app).get(`/api/notes/${c.body.data.id}`).set(auth)
    expect(g.body).toMatchObject({ success: true, data: { id: c.body.data.id, title: 'Shape', preview: 'body' } })
    const p = await request(app).patch(`/api/notes/${c.body.data.id}`).set(auth).send({ content: 'x', baseUpdatedAt: c.body.data.updatedAt })
    expect(typeof p.body.stomped).toBe('boolean')
    const d = await request(app).delete(`/api/notes/${c.body.data.id}`).set(auth)
    expect(d.body).toEqual({ success: true, message: 'Note deleted' })
    expect((await request(app).get('/api/notes')).status).toBe(401)
  })
})
