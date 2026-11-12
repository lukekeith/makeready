/** bible-verse-picker SC4, SC5: smart-search `record` and per-query recent delete, over a real database. */
import { randomUUID } from 'node:crypto'
import type { Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertSearchLease } from './helpers/master-search-db.js'
import { prisma } from '../src/lib/prisma.js'
import searchRoutes from '../src/routes/search.js'

vi.mock('../src/services/bible-metadata.js', () => ({ resolveBibleId: vi.fn().mockResolvedValue('bib') }))
vi.mock('../src/services/bible-chapter.js', () => ({
  getChapterVerses: vi.fn().mockResolvedValue({ verses: [{ verse: 16, text: 'v16' }], copyright: 'PD', fumsToken: 't' }),
}))

const servers = new Map<string, Server>()
type Caller = { id: string }

function listenAs(user: Caller): Promise<void> {
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

const appFor = (user: Caller) => servers.get(user.id) as Server
const smart = (user: Caller, body: object) => request(appFor(user)).post('/api/search/smart').send(body)
const del = (user: Caller, id: string) => request(appFor(user)).delete(`/api/search/recent/${id}`)

/** The history write is fire-and-forget: poll briefly for it to land (or not). */
const flush = () => new Promise((resolve) => setTimeout(resolve, 300))

async function seed(user: Caller, queries: string[]) {
  const rows = []
  for (const [i, query] of queries.entries()) {
    rows.push(
      await prisma.searchHistory.create({
        data: { userId: user.id, query, searchType: 'bible', resultCount: 1, createdAt: new Date(Date.now() - 60_000 + i) },
      }),
    )
  }
  return rows
}

describe.skipIf(!process.env.TEST_DATABASE_URL)('bible search recents (SC4, SC5)', () => {
  let user: Caller
  let other: Caller

  beforeAll(async () => {
    assertSearchLease()
    const make = () => prisma.user.create({ data: { email: `bsr-${randomUUID()}@example.test`, name: 'bsr' } as any })
    user = await make()
    other = await make()
    await Promise.all([listenAs(user), listenAs(other)])
  }, 60_000)
  beforeEach(async () => {
    await prisma.searchHistory.deleteMany({ where: { userId: { in: [user.id, other.id] } } })
  })
  afterAll(async () => {
    await prisma.searchHistory.deleteMany({ where: { userId: { in: [user.id, other.id] } } })
    await prisma.user.deleteMany({ where: { id: { in: [user.id, other.id] } } })
    for (const server of servers.values()) {
      server.closeAllConnections()
      server.close()
    }
  })

  it('record:false writes no history', async () => {
    await smart(user, { query: 'john 3:16', translation: 'ENGKJV', record: false }).expect(200)
    await flush()
    expect(await prisma.searchHistory.count({ where: { userId: user.id } })).toBe(0)
  })
  it('record defaults to true', async () => {
    await smart(user, { query: 'john 3:16', translation: 'ENGKJV' }).expect(200)
    await flush()
    expect(await prisma.searchHistory.count({ where: { userId: user.id, searchType: 'bible' } })).toBe(1)
  })
  it('deleting one recent removes every row of that query, case-insensitively, and nothing else', async () => {
    const [a] = await seed(user, ['grace', 'Grace', 'GRACE', 'love'])
    await del(user, a.id).expect(200, { success: true })
    expect((await prisma.searchHistory.findMany({ where: { userId: user.id } })).map((r) => r.query)).toEqual(['love'])
  })
  it("another caller's or a malformed id is 404", async () => {
    const [a] = await seed(other, ['grace'])
    await del(user, a.id).expect(404)
    await del(user, 'not-an-id').expect(404)
    expect(await prisma.searchHistory.count({ where: { userId: other.id } })).toBe(1)
  })
})
