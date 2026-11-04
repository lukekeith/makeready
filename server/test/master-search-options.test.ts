/** master-search C5: GET /api/search/filter-options over a real database, through the mounted router. */
import type { Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { assertSearchLease } from './helpers/master-search-db.js'
import { seedMasterSearchWorld, type MasterSearchWorld } from './helpers/master-search-world.js'
import { prisma } from '../src/lib/prisma.js'
import searchRoutes from '../src/routes/search.js'

/** Each identity's own server on 127.0.0.1, as master-search-ranked.test.ts does (see appFor there). */
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
    servers.set(user?.id ?? null, app.listen(0, '127.0.0.1', () => resolve()))
  })
}

const appFor = (user: { id: string } | null) => servers.get(user?.id ?? null) as Server

async function options(user: { id: string }) {
  const res = await request(appFor(user)).get('/api/search/filter-options')
  expect(res.status).toBe(200)
  return res.body
}

async function search(user: { id: string }, query: Record<string, string>) {
  const res = await request(appFor(user)).get('/api/search/ranked').query(query)
  expect(res.status).toBe(200)
  return res.body
}

describe.skipIf(!process.env.TEST_DATABASE_URL)('filter options (C5)', () => {
  let base: MasterSearchWorld
  let world: MasterSearchWorld & {
    multiOrgLeader: { id: string }
    multiOrgIdsByName: string[]
    inactiveGroupId: string
    creatorInOrgA: string
    roleHolderInOrgB: string
    categoryName: string
    spacedSpellingProgramId: string
    joinedSpellingPhotoId: string
  }
  const extraUserIds: string[] = []
  const extraProgramIds: string[] = []
  const extraMediaIds: string[] = []
  const extraGroupIds: string[] = []

  beforeAll(async () => {
    assertSearchLease()
    base = await seedMasterSearchWorld(prisma)

    // D31: the seeded category member whose spellings are '1samuel' (migration data on a lease).
    const member = await prisma.tagCategoryTag.findUnique({ where: { tag: '1samuel' }, include: { category: true } })
    if (!member) throw new Error('the 1samuel category member is seeded by the tag_categories migration')

    const stamp = base.owner.id.slice(0, 8)
    const roleHolder = await prisma.user.create({ data: { email: `rolebholder-${stamp}@ms.test`, name: `rolebholder ${stamp}` } })
    extraUserIds.push(roleHolder.id)
    const groupLeaderRole = await prisma.role.findFirstOrThrow({ where: { name: 'Group Leader', isSystem: true, organizationId: null } })
    await prisma.userRole.create({ data: { userId: roleHolder.id, roleId: groupLeaderRole.id, organizationId: base.orgB } })

    const inactiveGroup = await prisma.group.create({
      data: { name: `Closed Options ${stamp}`, creatorId: base.owner.id, organizationId: base.orgA, isActive: false },
    })
    extraGroupIds.push(inactiveGroup.id)

    // The two stores, each with its own spelling of one category member, and tags the categories do not know.
    const program = await prisma.studyProgram.create({
      data: { name: 'Zzoptions Study', description: 'grace for the weary', creatorId: base.owner.id, leaderId: base.owner.id, organizationId: base.orgA },
    })
    extraProgramIds.push(program.id)
    await prisma.studyProgramTag.createMany({ data: [{ studyProgramId: program.id, tag: '1 samuel' }, { studyProgramId: program.id, tag: 'outreach' }] })
    const photo = await prisma.media.create({
      data: { title: 'Grace Zzoptions Photo', type: 'photo', url: 'https://images.test/photo/options.jpg', organizationId: base.orgA, uploadedBy: base.owner.id },
    })
    extraMediaIds.push(photo.id)
    await prisma.mediaTag.createMany({ data: [{ mediaId: photo.id, tag: '1samuel' }] })

    world = {
      ...base,
      multiOrgLeader: base.bridge,
      multiOrgIdsByName: [base.orgA, base.orgB],
      inactiveGroupId: inactiveGroup.id,
      creatorInOrgA: base.leader.id,
      roleHolderInOrgB: roleHolder.id,
      categoryName: member.category.name,
      spacedSpellingProgramId: program.id,
      joinedSpellingPhotoId: photo.id,
    }
    await Promise.all([world.owner, world.bridge, world.outsider, null].map(listenAs))
  }, 60_000)

  afterAll(async () => {
    for (const server of servers.values()) {
      server.closeAllConnections()
      server.close()
    }
    await prisma.mediaTag.deleteMany({ where: { mediaId: { in: extraMediaIds } } })
    await prisma.media.deleteMany({ where: { id: { in: extraMediaIds } } })
    await prisma.studyProgramTag.deleteMany({ where: { studyProgramId: { in: extraProgramIds } } })
    await prisma.studyProgram.deleteMany({ where: { id: { in: extraProgramIds } } })
    await prisma.group.deleteMany({ where: { id: { in: extraGroupIds } } })
    await prisma.userRole.deleteMany({ where: { userId: { in: extraUserIds } } })
    await prisma.user.deleteMany({ where: { id: { in: extraUserIds } } })
    await base?.cleanup()
  })

  it('lists every org, its groups and leaders across orgs, sorted, one row per user', async () => {
    const body = await options(world.multiOrgLeader)
    expect(body.organizations.map((o: any) => o.id)).toEqual(world.multiOrgIdsByName)
    expect(body.groups.every((g: any) => world.multiOrgIdsByName.includes(g.organizationId))).toBe(true)
    expect(body.groups.map((g: any) => g.id)).not.toContain(world.inactiveGroupId)
    const ids = body.leaders.map((l: any) => l.id)
    expect(new Set(ids).size).toBe(ids.length)
    expect(ids).toEqual(expect.arrayContaining([world.creatorInOrgA, world.roleHolderInOrgB]))
    expect(body.leaders.map((l: any) => l.name)).toEqual([...body.leaders.map((l: any) => l.name)].sort())
  })

  it('D31: one option per category member, in display order, then uncategorized by label', async () => {
    const { tags } = await options(world.owner)
    const samuel = tags.filter((t: any) => t.label === '1 Samuel')
    expect(samuel).toHaveLength(1)
    expect(samuel[0].category).toBe(world.categoryName)
    const firstUncategorized = tags.findIndex((t: any) => t.category === null)
    expect(tags.slice(firstUncategorized).every((t: any) => t.category === null)).toBe(true)
    expect(tags.slice(firstUncategorized).map((t: any) => t.label)).toEqual(expect.arrayContaining(['Lent', 'Outreach']))
  })

  it('two spellings of one member both match when one is picked', async () => {
    const { items } = await search(world.owner, { q: 'grace', tags: '1samuel', types: 'PROGRAM,PHOTO' })
    expect(items.map((i: any) => i.id).sort()).toEqual([world.spacedSpellingProgramId, world.joinedSpellingPhotoId].sort())
  })

  it('a caller with no orgs gets the normal shape; no session gets 401', async () => {
    const body = await options(world.outsider)
    expect(body).toMatchObject({ success: true, organizations: [], groups: [], leaders: [] })
    expect(Array.isArray(body.tags)).toBe(true)
    expect((await request(appFor(null)).get('/api/search/filter-options')).status).toBe(401)
  })
})
