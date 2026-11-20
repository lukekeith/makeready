/** notes Task 4: leader :noteId routes: 404 scoping, strict PATCH, locked stomped (SC5, SC8, D6, D7, D23). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, type ContentUser, type ContentWorld } from './helpers/content-world.js'

describe('leader /api/notes/:noteId', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId: { in: [w.leader.userId, w.outsider.userId] } } })
    await destroyContentWorld(w)
  })

  async function post(user: ContentUser, content: string): Promise<string> {
    const r = await request(app).post('/api/notes').set('Authorization', bearer(user.token)).send({ type: 'NOTE', content })
    expect(r.status).toBe(201)
    return r.body.data.id
  }
  const get = (user: ContentUser, id: string) => request(app).get(`/api/notes/${id}`).set('Authorization', bearer(user.token))
  const patch = (user: ContentUser, id: string, body: object) => request(app).patch(`/api/notes/${id}`).set('Authorization', bearer(user.token)).send(body)
  const del = (user: ContentUser, id: string) => request(app).delete(`/api/notes/${id}`).set('Authorization', bearer(user.token))

  it('another user\'s or an inactive note is 404 on GET and PATCH', async () => {
    const id = await post(w.leader, 'mine')
    expect((await get(w.outsider, id)).status).toBe(404)
    expect((await patch(w.outsider, id, { content: 'x' })).status).toBe(404)
    await prisma.studyNote.update({ where: { id }, data: { isActive: false } })
    expect((await get(w.leader, id)).status).toBe(404)
    expect((await patch(w.leader, id, { content: 'revive' })).status).toBe(404)
    expect((await prisma.studyNote.findUnique({ where: { id } }))!.content).toBe('mine')
    expect((await get(w.leader, 'not-a-uuid')).status).toBe(404)
  })

  it.each([{ content: 'a', extra: 1 }, { content: 'a', baseUpdatedAt: 'yesterday' }, { content: 'a', baseUpdatedAt: '2026-11-20T10:00:00' }, { content: '' }])('%o is 400', async (body) => {
    const id = await post(w.leader, 'strict')
    expect((await patch(w.leader, id, body)).status).toBe(400)
  })

  it('stomped is false for the echoed updatedAt and true for an older base; both write', async () => {
    const created = await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: 'NOTE', content: 'v1' })
    const fresh = await patch(w.leader, created.body.data.id, { content: 'v2', baseUpdatedAt: created.body.data.updatedAt })
    expect(fresh.body).toMatchObject({ success: true, stomped: false, data: { content: 'v2', title: 'v2' } })
    const stale = await patch(w.leader, created.body.data.id, { content: 'v3', baseUpdatedAt: created.body.data.updatedAt })
    expect(stale.body).toMatchObject({ success: true, stomped: true, data: { content: 'v3' } })
    const none = await patch(w.leader, created.body.data.id, { content: 'v4' })
    expect(none.body.stomped).toBe(false)
  })

  it('DELETE is 404 for another user\'s and idempotent for the owner', async () => {
    const id = await post(w.leader, 'bye')
    expect((await del(w.outsider, id)).status).toBe(404)
    const first = await del(w.leader, id)
    expect(first.status).toBe(200)
    expect(first.body).toEqual({ success: true, message: 'Note deleted' })
    expect((await del(w.leader, id)).status).toBe(200)
    expect((await get(w.leader, id)).status).toBe(404)
  })

  it('a PATCH racing a DELETE is all-or-nothing', async () => {
    for (let i = 0; i < 5; i++) {
      const id = await post(w.leader, 'old')
      const [p] = await Promise.all([patch(w.leader, id, { content: 'new' }), del(w.leader, id)])
      const row = await prisma.studyNote.findUniqueOrThrow({ where: { id } })
      expect(row.isActive).toBe(false)
      expect(p.status === 200 ? row.content === 'new' : p.status === 404 && row.content === 'old').toBe(true)
    }
  })
})
