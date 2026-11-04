/** master-search C1: GET /api/search/ranked over a real database, through the mounted router. */
import type { Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { assertSearchLease } from './helpers/master-search-db.js'
import { seedMasterSearchWorld, type MasterSearchWorld } from './helpers/master-search-world.js'
import { Prisma, prisma } from '../src/lib/prisma.js'
import searchRoutes from '../src/routes/search.js'
import { buildArm, buildSearchScope, buildTextMatch, serializeSearchItem } from '../src/services/master-search.js'
import { SEARCH_TYPES, encodeCursor, type SearchType } from '../src/services/master-search-query.js'

const LEGACY_SEARCH_KEYS = ['counts', 'pagination', 'query', 'results', 'success']

const idsOf = (items: any[]) => new Set(items.map((i) => i.id))

/**
 * D6, D7, D37, closed: which of an org's `lampword` rows each filter reaches. `first` is the enrolled, tagged
 * program or lesson alone; a type missing from a row drops out.
 */
type MappedFilter = 'orgIds' | 'groupIds' | 'leaderIds' | 'tags'
const D7_ROWS: Record<MappedFilter, Partial<Record<SearchType, 'all' | 'first'>>> = {
  orgIds: { PROGRAM: 'all', TEMPLATE: 'all', GROUP: 'all', PHOTO: 'all', VIDEO: 'all', EVENT: 'all', POST: 'all', LESSON: 'all', MEMBER: 'all' },
  groupIds: { GROUP: 'all', EVENT: 'all', POST: 'all', PHOTO: 'all', VIDEO: 'all', MEMBER: 'all', PROGRAM: 'first', LESSON: 'first' },
  leaderIds: { GROUP: 'all', PROGRAM: 'all', LESSON: 'all', TEMPLATE: 'all', EVENT: 'all', POST: 'all', PHOTO: 'all', VIDEO: 'all' },
  tags: { PROGRAM: 'first', LESSON: 'first', PHOTO: 'all', VIDEO: 'all' },
}
const D7_CASES = (Object.keys(D7_ROWS) as MappedFilter[]).flatMap((filter) => SEARCH_TYPES.map((type) => [filter, type] as const))

/**
 * Each identity's own server, bound to 127.0.0.1. Supertest handed a bare app listens on the wildcard
 * address, where macOS can assign a port another process holds on loopback; its request to 127.0.0.1 then
 * reaches that process (an unexplained 404). A loopback bind refuses that port instead.
 */
const servers = new Map<string | null, Server>()

function listenAs(user: { id: string } | null): Promise<void> {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(
      req,
      user
        ? { user: { id: user.id, isActive: true }, apiKeyId: 'test-key', isAuthenticated: () => true }
        : { isAuthenticated: () => false },
    )
    next()
  })
  app.use('/api/search', searchRoutes)
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => resolve())
    servers.set(user?.id ?? null, server)
  })
}

const appFor = (user: { id: string } | null) => servers.get(user?.id ?? null) as Server

const rawSearch = (user: { id: string } | null, query: Record<string, string>) =>
  request(appFor(user)).get('/api/search/ranked').query(query)

async function search(user: { id: string }, query: Record<string, string>) {
  const res = await rawSearch(user, query)
  expect(res.status, JSON.stringify(res.body)).toBe(200)
  expect(res.body.success).toBe(true)
  return res.body
}

describe.skipIf(!process.env.TEST_DATABASE_URL)('GET /api/search/ranked', () => {
  let world: MasterSearchWorld

  beforeAll(async () => {
    assertSearchLease()
    world = await seedMasterSearchWorld(prisma)
    await Promise.all([world.owner, world.admin, world.leader, world.outsider, world.privateCreator, world.superAdmin, world.bridge, null].map(listenAs))
  }, 60_000)
  afterAll(async () => {
    for (const server of servers.values()) {
      server.closeAllConnections()
      server.close()
    }
    await world?.cleanup()
  })

  it('orders by tier across types', async () => {
    const { items } = await search(world.owner, { q: 'grace notes' })
    expect(items.map((i: any) => i.id).slice(0, 4)).toEqual([world.exactPostId, world.prefixProgramId, world.wordsGroupId, world.otherLessonId])
    expect(items[0].score).toBeGreaterThanOrEqual(4)
    expect(items[0].score).toBeLessThan(5)
    expect(typeof items[0].score).toBe('number')
    expect(new Set(items.map((i: any) => i.type)).size).toBeGreaterThan(2)
  })

  it('Owner, Admin and Group Leader see the org; an outsider sees only system templates', async () => {
    for (const u of [world.owner, world.admin, world.leader]) expect((await search(u, { q: 'grace', types: 'GROUP' })).items).not.toHaveLength(0)
    expect((await search(world.outsider, { q: 'grace', types: 'GROUP' })).items).toHaveLength(0)
    expect((await search(world.outsider, { q: 'video study' })).items.map((i: any) => i.type)).toEqual(['TEMPLATE'])
  })

  it('a set Orgs filter drops system templates and an empty overlap is empty', async () => {
    expect((await search(world.owner, { q: 'video study', orgIds: world.orgA })).items.filter((i: any) => i.type === 'TEMPLATE' && i.id === world.systemTemplateId)).toHaveLength(0)
    expect((await search(world.owner, { q: 'grace', orgIds: 'foreign,not-a-uuid' })).items).toHaveLength(0)
  })

  it.each([
    ['groupIds', () => world.groupA, ['GROUP', 'EVENT', 'POST', 'PHOTO', 'VIDEO', 'MEMBER', 'PROGRAM', 'LESSON']],
    ['leaderIds', () => world.nullLeaderProgramCreator, ['PROGRAM', 'LESSON']],
    ['tags', () => 'lent', ['PROGRAM', 'LESSON', 'PHOTO', 'VIDEO']],
  ] as const)('each filter maps as D7 rules, with drop-outs: %s', async (key, value, types) => {
    const { items } = await search(world.owner, { q: 'grace', limit: '50', [key]: value() })
    expect(new Set(items.map((i: any) => i.type))).toEqual(new Set(types))
  })

  it.each(D7_CASES)('D7: %s on %s reaches only its mapped rows', async (filter, type) => {
    const { items } = await search(world.bridge, { q: 'lampword', types: type, limit: '50', [filter]: world.mappedPicks[filter] })
    const rows = world.mappedA[type]
    const reach = D7_ROWS[filter][type]
    expect(idsOf(items)).toEqual(new Set(reach === 'all' ? rows : reach === 'first' ? rows.slice(0, 1) : []))
  })

  it('a two-org caller sees both orgs, and Orgs narrows to one, a member staying one row', async () => {
    const flat = (rows: Record<string, string[]>) => Object.values(rows).flat()
    const seen = async (orgIds?: string) => idsOf((await search(world.bridge, { q: 'lampword', limit: '50', ...(orgIds ? { orgIds } : {}) })).items)
    expect(await seen()).toEqual(new Set([...flat(world.mappedA), ...flat(world.mappedB)]))
    expect(await seen(`${world.orgA},${world.orgB}`)).toEqual(new Set([...flat(world.mappedA), ...flat(world.mappedB)]))
    expect(await seen(world.orgA)).toEqual(new Set(flat(world.mappedA)))
    expect(await seen(`${world.orgB},foreign`)).toEqual(new Set(flat(world.mappedB)))
    const members = (await search(world.bridge, { q: 'bothorgsword', types: 'MEMBER' })).items
    expect(members.map((i: any) => i.id)).toEqual([world.bothOrgsMemberId])
  })

  it.each(SEARCH_TYPES)('a retired %s, or one in a closed group, is out', async (type) => {
    const { items } = await search(world.owner, { q: 'vesperword', types: type, limit: '50' })
    expect(idsOf(items)).toEqual(new Set(world.vesperLive[type]))
  })

  it('D38: a closed group filters nothing in, and a lapsed membership does not count', async () => {
    expect((await search(world.owner, { q: 'vesperword', limit: '50', groupIds: world.vesperClosedGroupId })).items).toHaveLength(0)
    const members = (await search(world.owner, { q: 'vesperword', types: 'MEMBER', groupIds: world.groupA })).items
    expect(members.map((i: any) => i.id)).toEqual([world.vesperMemberId])
  })

  it('D30: a Group Leader misses retired members, lapsed memberships and closed groups', async () => {
    const { items } = await search(world.leader, { q: 'vesperword', types: 'MEMBER', limit: '50' })
    expect(items.map((i: any) => i.id)).toEqual([world.vesperMemberId])
  })

  it('D33, D38: a super admin sees private programs in their orgs and gets no wider scope', async () => {
    expect((await search(world.superAdmin, { q: 'secret', types: 'PROGRAM,LESSON' })).items).toHaveLength(2)
    const ids = idsOf((await search(world.superAdmin, { q: 'grace', types: 'GROUP,MEMBER,PROGRAM', limit: '50' })).items)
    expect(ids).toContain(world.groupA)
    expect(ids).toContain(world.leadersMemberId)
    expect(ids).not.toContain(world.foreignGroup)
    expect(ids).not.toContain(world.foreignMemberId)
    expect(ids).not.toContain(world.orglessProgramId)
  })

  it('D16: a media tag matches at tier 1', async () => {
    for (const [type, id] of [['PHOTO', world.tagOnlyPhotoId], ['VIDEO', world.tagOnlyVideoId]] as const) {
      const { items } = await search(world.owner, { q: 'tagonlyword', types: type })
      expect(items.map((i: any) => i.id)).toEqual([id])
      expect(items[0].score).toBeLessThan(2)
    }
  })

  it('D16, D39: a read block alone matches a lesson and sets its rank; an activity text sets it too', async () => {
    for (const [q, id] of [['blockonlyword', world.blockOnlyLessonId], ['lessontext', world.untitledLessonId]]) {
      const { items } = await search(world.owner, { q, types: 'LESSON' })
      expect(items.map((i: any) => i.id)).toEqual([id])
      expect(items[0].score).toBeGreaterThan(1)
      expect(items[0].score).toBeLessThan(2)
    }
  })

  it('D39: a title, an activity and a read block rank together, one row per lesson at its greatest rank', async () => {
    const { items } = await search(world.owner, { q: 'orchardword', types: 'LESSON' })
    expect(items.map((i: any) => i.id)).toEqual(world.orchardLessonIdsByRank)
    const [title, strong, block, weak] = items.map((i: any) => i.score)
    expect(title).toBeGreaterThan(2)
    expect(title).toBeLessThan(3)
    expect(strong).toBeGreaterThan(block)
    expect(block).toBeGreaterThan(weak)
    expect(weak).toBeGreaterThan(1)
    expect(strong).toBeLessThan(2)
  })

  it('F4: LESSON reads activities and read blocks once per query, never once per lesson', async () => {
    const scope = await buildSearchScope(world.owner.id)
    const [row] = await prisma.$queryRaw<any[]>(Prisma.sql`EXPLAIN (FORMAT JSON) ${buildArm('LESSON', scope, {}, buildTextMatch('orchardword'))}`)
    const read: { relation: string; perLesson: boolean }[] = []
    const walk = (node: any, inSubPlan: boolean) => {
      const perLesson = inSubPlan || node['Parent Relationship'] === 'SubPlan'
      if (node['Relation Name']) read.push({ relation: node['Relation Name'], perLesson })
      for (const child of node.Plans ?? []) walk(child, perLesson)
    }
    walk(row['QUERY PLAN'][0].Plan, false)
    const texts = read.filter((r) => r.relation === 'lesson_activities' || r.relation === 'activity_read_blocks')
    expect(new Set(texts.map((r) => r.relation))).toEqual(new Set(['lesson_activities', 'activity_read_blocks']))
    expect(texts.filter((r) => r.perLesson)).toEqual([])
  })

  it('D16: a scheduled copy of a read block does not match', async () => {
    expect((await search(world.owner, { q: 'scheduledonlyword' })).items).toHaveLength(0)
  })

  it('D35: an email matches its stored form at tier 4 whatever the case', async () => {
    const asTyped = (await search(world.owner, { q: world.memberEmail.toUpperCase(), types: 'MEMBER' })).items
    expect(asTyped.map((i: any) => i.id)).toEqual([world.leadersMemberId])
    expect(asTyped[0].score).toBeGreaterThanOrEqual(4)
    const asStored = (await search(world.owner, { q: world.mixedCaseEmail.toLowerCase(), types: 'MEMBER' })).items
    expect(asStored.map((i: any) => i.id)).toEqual([world.mixedCaseEmailMemberId])
    expect(asStored[0].score).toBeGreaterThanOrEqual(4)
  })

  it.each([
    ['score', '1e-999'],
    ['score', '1e999'],
    ['createdAt', '0000-01-01 00:00:00'],
    ['createdAt', '2026-01-01 00:00:00+99'],
  ])('a forged cursor Postgres cannot cast answers 400: %s %s', async (field, value) => {
    const cursor = encodeCursor({ score: '1', createdAt: '2026-01-01 00:00:00', id: 'x', [field]: value })
    const res = await rawSearch(world.owner, { q: 'ab', cursor })
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(res.body.error).toBe('Invalid cursor')
  })

  it('D30: a Group Leader finds only members of their active groups; Owner finds a group-less member', async () => {
    const q = { q: world.grouplessPhone, types: 'MEMBER' }
    expect((await search(world.owner, q)).items.map((i: any) => i.id)).toEqual([world.grouplessMemberId])
    expect((await search(world.admin, q)).items.map((i: any) => i.id)).toEqual([world.grouplessMemberId])
    expect((await search(world.leader, q)).items).toHaveLength(0)
    expect((await search(world.leader, { q: 'gracie', types: 'MEMBER' })).items.map((i: any) => i.id)).toEqual([world.leadersMemberId])
  })

  it('D33: a private program and its lessons stay hidden from another leader', async () => {
    const q = { q: 'secret', types: 'PROGRAM,LESSON' }
    expect((await search(world.leader, q)).items).toHaveLength(0)
    expect((await search(world.admin, q)).items).toHaveLength(2)
    expect((await search(world.privateCreator, q)).items).toHaveLength(2)
  })

  it('D34 and D15: an auto-captured cover and a pending row are out', async () => {
    const ids = (await search(world.owner, { q: 'grace', types: 'PHOTO', limit: '50' })).items.map((i: any) => i.id)
    expect(ids).toContain(world.photoId)
    expect(ids).not.toContain(world.autoCaptureId)
    expect(ids).not.toContain(world.pendingPhotoId)
    const video = (await search(world.owner, { q: 'grace', types: 'VIDEO' })).items[0]
    expect(video.imageUrl).toBeNull()
    expect((await search(world.owner, { q: 'grace', types: 'PHOTO' })).items[0].imageUrl).toMatch(/^https:/)
  })

  it('D35: formatted and partial phones and any-case email find a member', async () => {
    const first = async (q: string) => (await search(world.owner, { q, types: 'MEMBER' })).items[0]
    expect((await first(world.memberPhoneFormatted)).score).toBeGreaterThanOrEqual(4)
    expect((await first(world.memberPhoneLast4)).score).toBeLessThan(2)
    expect((await first(world.memberEmail.toUpperCase())).id).toBe(world.leadersMemberId)
  })

  it('D29: one row per series, no generated lesson events', async () => {
    const { items } = await search(world.owner, { q: 'grace series', types: 'EVENT' })
    expect(items.map((i: any) => i.id)).toEqual([world.seriesFirstEventId])
    expect((await search(world.owner, { q: 'day 1 grace', types: 'EVENT' })).items).toHaveLength(0)
  })

  it('D28: fallback titles, scoring tier 1 at most', async () => {
    const post = (await search(world.owner, { q: 'untitled grace body', types: 'POST' })).items[0]
    expect(post.title).toBe(world.untitledPostFirstLine80)
    expect(post.score).toBeLessThan(2)
    expect((await search(world.owner, { q: 'lessontext', types: 'LESSON' })).items[0].title).toBe('Day 7')
  })

  it('parent, id and date shapes', async () => {
    const { items } = await search(world.owner, { q: 'grace', types: 'LESSON' })
    expect(items[0].parent).toEqual({ type: 'PROGRAM', id: world.programId, name: world.programName })
    expect(items[0].createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
    expect(typeof items[0].id).toBe('string')
  })

  it('pages with no repeats or gaps, including tied scores and microsecond dates', async () => {
    const seen: string[] = []
    let cursor: string | undefined
    do {
      const page = await search(world.owner, { q: 'tieword', limit: '3', ...(cursor ? { cursor } : {}) })
      seen.push(...page.items.map((i: any) => `${i.type}:${i.id}`))
      cursor = page.nextCursor ?? undefined
    } while (cursor)
    expect(new Set(seen).size).toBe(seen.length)
    expect(seen).toHaveLength(world.tiedRowCount)
  })

  it('a many-activity lesson and a many-enrollment program are one row', async () => {
    const { items } = await search(world.owner, { q: 'manyword', types: 'LESSON,PROGRAM', groupIds: `${world.groupA},${world.groupB}` })
    expect(items).toHaveLength(2)
  })

  it.each(["'%", '_:', '&!', 'the', 'gospel of j'])('answers 200 for %s', async (q) => {
    const res = await rawSearch(world.owner, { q })
    expect(res.status).toBe(200)
    expect(Array.isArray(res.body.items)).toBe(true)
  })

  it('finds an exact stop-word title and refuses NUL', async () => {
    expect((await search(world.owner, { q: 'the', types: 'GROUP' })).items.map((i: any) => i.id)).toEqual([world.groupTitledThe])
    expect((await rawSearch(world.owner, { q: 'ab\u0000' })).status).toBe(400)
  })

  it('400s and 401 use the error form', async () => {
    for (const q of [{ q: 'a' }, { q: 'ab', types: 'NOPE' }, { q: 'ab', cursor: 'nope' }]) {
      const res = await rawSearch(world.owner, q)
      expect(res.status).toBe(400)
      expect(res.body.success).toBe(false)
      expect(typeof res.body.error).toBe('string')
    }
    expect((await rawSearch(null, { q: 'ab' })).status).toBe(401)
  })

  it('GET /api/search keeps its grouped response', async () => {
    const res = await request(appFor(world.owner)).get('/api/search').query({ q: 'grace', types: 'GROUP' })
    expect(res.status).toBe(200)
    expect(Object.keys(res.body).sort()).toEqual(LEGACY_SEARCH_KEYS)
    expect(res.body.items).toBeUndefined()
  })

  it('D38: a foreign group id reveals no membership, and a foreign org stays out', async () => {
    expect((await search(world.owner, { q: 'grace', types: 'MEMBER', groupIds: world.foreignGroup })).items).toHaveLength(0)
    const ids = (await search(world.owner, { q: 'grace', types: 'MEMBER,GROUP', limit: '50' })).items.map((i: any) => i.id)
    expect(ids).toContain(world.leadersMemberId)
    expect(ids).not.toContain(world.foreignMemberId)
    expect(ids).not.toContain(world.foreignGroup)
  })

  it('D38: an org-less program is out, an empty list is no filter, and a member is one row', async () => {
    const programs = (await search(world.owner, { q: 'grace orphan', types: 'PROGRAM' })).items
    expect(programs.map((i: any) => i.id)).not.toContain(world.orglessProgramId)
    const members = (await search(world.owner, { q: 'gracie', types: 'MEMBER', orgIds: '', groupIds: ',', tags: ',' })).items
    expect(members.map((i: any) => i.id)).toEqual([world.leadersMemberId])
  })

  it('an event in an inactive group is out', async () => {
    expect((await search(world.owner, { q: 'grace shut', types: 'EVENT' })).items).toHaveLength(0)
  })

  it('D31: a pick matches a stored tag whatever its spacing', async () => {
    const { items } = await search(world.owner, { q: 'sunrise', tags: 'easterweek' })
    expect(items.map((i: any) => i.id)).toEqual([world.spacedTagPhotoId])
  })

  it('buildArm over a list of ids applies the same rules and carries no score', async () => {
    const scope = await buildSearchScope(world.owner.id, undefined)
    const rows = await prisma.$queryRaw<any[]>(buildArm('GROUP', scope, {}, { ids: [world.groupA, world.foreignGroup] }))
    expect(rows.map((r) => r.id)).toEqual([world.groupA])
    expect(serializeSearchItem(rows[0]).score).toBeNull()
  })
})
