/** master-search C2, C3, C4: recently opened results over a real database, through the mounted router. */
import { randomUUID } from 'node:crypto'
import type { Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest'
import { assertSearchLease } from './helpers/master-search-db.js'
import { seedMasterSearchWorld, type MasterSearchWorld } from './helpers/master-search-world.js'
import { prisma } from '../src/lib/prisma.js'
import searchRoutes from '../src/routes/search.js'

/** Each identity's own server on 127.0.0.1, as master-search-ranked.test.ts does (see appFor there). */
const servers = new Map<string, Server>()

function listenAs(user: { id: string }): Promise<void> {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { user: { id: user.id, isActive: true }, apiKeyId: 'test-key', isAuthenticated: () => true })
    next()
  })
  app.use('/api/search', searchRoutes)
  return new Promise((resolve) => {
    servers.set(user.id, app.listen(0, '127.0.0.1', () => resolve()))
  })
}

const appFor = (user: { id: string }) => servers.get(user.id) as Server

const put = (user: { id: string }, type: string, id: string) =>
  request(appFor(user)).put('/api/search/recent-results').send({ type, id })
const list = (user: { id: string }, query: Record<string, string> = {}) =>
  request(appFor(user)).get('/api/search/recent-results').query(query)
const del = (user: { id: string }, type: string, id: string) =>
  request(appFor(user)).delete(`/api/search/recent-results/${type}/${id}`)

/** Rows older than anything `put` writes, so they fall off first. */
async function seedRecents(user: { id: string }, count: number, type: string) {
  await prisma.searchRecentResult.createMany({
    data: Array.from({ length: count }, (_, i) => ({
      userId: user.id,
      resourceType: type,
      resourceId: randomUUID(),
      openedAt: new Date(Date.now() - 60_000 - i * 1000),
    })),
  })
}

describe.skipIf(!process.env.TEST_DATABASE_URL)('recent results (C2, C3, C4)', () => {
  let world: MasterSearchWorld
  let everyone: { id: string }[]
  let removedRoles: { userId: string; roleId: string; organizationId: string | null }[] = []

  const removeRolesOf = async (user: { id: string }) => {
    removedRoles = await prisma.userRole.findMany({ where: { userId: user.id }, select: { userId: true, roleId: true, organizationId: true } })
    await prisma.userRole.deleteMany({ where: { userId: user.id } })
  }

  beforeAll(async () => {
    assertSearchLease()
    world = await seedMasterSearchWorld(prisma)
    everyone = [world.owner, world.admin, world.leader, world.outsider]
    await Promise.all(everyone.map(listenAs))
  }, 60_000)
  beforeEach(async () => {
    await prisma.searchRecentResult.deleteMany({ where: { userId: { in: everyone.map((u) => u.id) } } })
  })
  afterEach(async () => {
    if (removedRoles.length) await prisma.userRole.createMany({ data: removedRoles })
    removedRoles = []
  })
  afterAll(async () => {
    for (const server of servers.values()) {
      server.closeAllConnections()
      server.close()
    }
    await world?.cleanup()
  })

  it('C2 returns newest first with null score and openedAt', async () => {
    await put(world.owner, 'GROUP', world.groupA); await put(world.owner, 'PROGRAM', world.programId)
    const res = await list(world.owner)
    expect(res.body.items.map((i: any) => i.id)).toEqual([world.programId, world.groupA])
    expect(res.body.items[0].score).toBeNull()
    expect(res.body.items[0].openedAt).toMatch(/\.\d{3}Z$/)
  })

  it('re-opening moves an entry up without a second row, including concurrently', async () => {
    await put(world.owner, 'GROUP', world.groupA); await put(world.owner, 'PROGRAM', world.programId)
    const results = await Promise.all([put(world.owner, 'GROUP', world.groupA), put(world.owner, 'GROUP', world.groupA)])
    expect(results.map((r) => r.status)).toEqual([200, 200])
    const res = await list(world.owner)
    expect(res.body.items.map((i: any) => i.id)).toEqual([world.groupA, world.programId])
  })

  it('C2 drops deleted, inactive and no-longer-visible rows', async () => {
    await put(world.owner, 'GROUP', world.tempGroupId); await put(world.owner, 'POST', world.tempPostId); await put(world.leader, 'GROUP', world.groupA)
    await prisma.group.update({ where: { id: world.tempGroupId }, data: { isActive: false } })
    await prisma.post.delete({ where: { id: world.tempPostId } })
    await removeRolesOf(world.leader)
    const ownerIds = (await list(world.owner)).body.items.map((i: any) => i.id)
    expect(ownerIds).not.toContain(world.tempGroupId)
    expect(ownerIds).not.toContain(world.tempPostId)
    expect((await list(world.leader)).body.items).toHaveLength(0)
  })

  it('D43: a recent photo carries its thumbnail', async () => {
    await put(world.owner, 'PHOTO', world.photoId)
    const recent = (await list(world.owner, { types: 'PHOTO' })).body.items[0]
    expect(recent.thumbnailUrl).toMatch(/^https:\/\/images\.test\/thumb\//)
  })

  it("C2's filters match C1's", async () => {
    await put(world.owner, 'PHOTO', world.photoId); await put(world.owner, 'GROUP', world.groupA)
    expect((await list(world.owner, { tags: 'lent' })).body.items.map((i: any) => i.type)).toEqual(['PHOTO'])
    expect((await list(world.owner, { types: 'GROUP' })).body.items.map((i: any) => i.type)).toEqual(['GROUP'])
    expect((await list(world.owner, { types: 'NOPE' })).status).toBe(400)
  })

  it('C3 keeps the newest 100 and C2 returns at most 50', async () => {
    await seedRecents(world.owner, 100, 'GROUP')
    await put(world.owner, 'GROUP', world.groupA)
    expect(await prisma.searchRecentResult.count({ where: { userId: world.owner.id } })).toBe(100)
    expect((await list(world.owner)).body.items.length).toBeLessThanOrEqual(50)
    expect((await list(world.owner, { limit: '51' })).status).toBe(400)
  })

  it('a NUL in an id: C3 answers 400, C4 answers as for an unknown id', async () => {
    expect((await put(world.owner, 'GROUP', 'a\u0000b')).status).toBe(400)
    const res = await del(world.owner, 'GROUP', 'a%00b')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true })
  })

  it('C3 answers 404 per type, including a wrong type and an invisible member', async () => {
    expect((await put(world.owner, 'VIDEO', world.photoId)).status).toBe(404)
    expect((await put(world.owner, 'PROGRAM', 'missing')).status).toBe(404)
    expect((await put(world.outsider, 'GROUP', world.groupA)).status).toBe(404)
    expect((await put(world.leader, 'MEMBER', world.grouplessMemberId)).status).toBe(404)
    expect((await put(world.leader, 'PROGRAM', world.privateProgramId)).status).toBe(404)
  })

  it('C3 refuses a bad body rather than stripping it', async () => {
    for (const body of [{}, { type: 'NOPE', id: 'x' }, { type: 'GROUP', id: '' }, { type: 'GROUP', id: 'x', extra: 1 }]) {
      const res = await request(appFor(world.owner)).put('/api/search/recent-results').send(body)
      expect(res.status).toBe(400)
    }
  })

  it("C4 is idempotent, touches only the caller's entry, refuses a bad type", async () => {
    await put(world.owner, 'GROUP', world.groupA)
    expect((await del(world.admin, 'GROUP', world.groupA)).status).toBe(200)
    expect((await list(world.owner)).body.items).toHaveLength(1)
    expect((await del(world.owner, 'GROUP', world.groupA)).status).toBe(200)
    expect((await del(world.owner, 'GROUP', world.groupA)).body).toEqual({ success: true })
    expect((await list(world.owner)).body.items).toHaveLength(0)
    expect((await del(world.owner, 'NOPE', 'x')).status).toBe(400)
  })

  it('an EVENT recent on a non-first series row drops out', async () => {
    const later = await prisma.event.findFirstOrThrow({
      where: { recurrenceGroupId: { not: null }, isActive: true, groupId: world.groupA },
      orderBy: [{ date: 'desc' }, { id: 'desc' }],
    })
    expect(later.id).not.toBe(world.seriesFirstEventId)
    expect((await put(world.owner, 'EVENT', later.id)).status).toBe(404)
    expect((await put(world.owner, 'EVENT', world.seriesFirstEventId)).status).toBe(200)
  })
})
