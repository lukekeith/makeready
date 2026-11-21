/** notes Task 3: the validated leader list query: q, orderBy, bounds (D8, D25, SC4, SC6). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, type ContentUser, type ContentWorld } from './helpers/content-world.js'

describe('leader GET /api/notes query', () => {
  let w: ContentWorld
  const noteIds: string[] = []
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { id: { in: noteIds } } })
    await prisma.studyNote.deleteMany({ where: { userId: { in: [w.leader.userId, w.outsider.userId] } } })
    await destroyContentWorld(w)
  })

  async function post(user: ContentUser, content: string): Promise<string> {
    const r = await request(app).post('/api/notes').set('Authorization', bearer(user.token)).send({ type: 'NOTE', content })
    expect(r.status).toBe(201)
    noteIds.push(r.body.data.id)
    return r.body.data.id
  }
  const list = (user: ContentUser, qs: string) => request(app).get(`/api/notes${qs}`).set('Authorization', bearer(user.token))

  it('q matches case-insensitively and only the caller\'s notes', async () => {
    await post(w.leader, 'Morning GRACE here'); await post(w.leader, 'nothing'); await post(w.outsider, 'grace too')
    await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: 'JOURNAL', content: 'grace journal' })
    const r = await list(w.leader, '?type=NOTE&q=grace')
    expect(r.status).toBe(200)
    expect(r.body.data.map((n: any) => n.content)).toEqual(['Morning GRACE here'])
  })

  it('orderBy=updatedAt puts the last-edited first; the default stays createdAt', async () => {
    const a = await post(w.leader, 'order-a'); const b = await post(w.leader, 'order-b')
    await request(app).patch(`/api/notes/${a}`).set('Authorization', bearer(w.leader.token)).send({ content: 'order-a edited' })
    const byUpdated = await list(w.leader, '?type=NOTE&q=order-&orderBy=updatedAt')
    expect(byUpdated.body.data.map((n: any) => n.id)).toEqual([a, b])
    const byCreated = await list(w.leader, '?type=NOTE&q=order-')
    expect(byCreated.body.data.map((n: any) => n.id)).toEqual([b, a])
  })

  it.each(['limit=101', 'limit=0', 'limit=abc', 'offset=-1', 'orderBy=title', `q=${'x'.repeat(201)}`, 'startDate=notadate'])('%s is 400', async (qs) => {
    const r = await list(w.leader, `?${qs}`)
    expect(r.status).toBe(400)
    expect(r.body.success).toBe(false)
  })

  it('pagination pages with hasMore', async () => {
    for (const c of ['pg-1', 'pg-2', 'pg-3']) await post(w.leader, c)
    const p1 = await list(w.leader, '?type=NOTE&q=pg-&limit=2')
    expect(p1.body.pagination).toEqual({ total: 3, limit: 2, offset: 0, hasMore: true })
    const p2 = await list(w.leader, '?type=NOTE&q=pg-&limit=2&offset=2')
    expect(p2.body.pagination).toEqual({ total: 3, limit: 2, offset: 2, hasMore: false })
  })
})
