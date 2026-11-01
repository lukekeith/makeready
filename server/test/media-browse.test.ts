/** media-library D4/D16/D17: GET /api/media/sources and /api/media/browse. */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')
const { ensureMakeReadyOrg, MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } = await import('../src/services/makeready-library.js')

describe('media browse across sources (media-library D16)', () => {
  const stamp = Date.now()
  let leader: { userId: string; token: string }
  let stranger: { userId: string; token: string }
  let orgA: string // owned by leader
  let orgB: string // leader holds a permission-less role
  let orgC: string // not the leader's
  let roleId: string
  const made: string[] = []

  const photo = async (organizationId: string, uploadedBy: string, title: string, at: Date) => {
    const m = await prisma.media.create({ data: { title, url: `https://img.test/${title}.jpeg`, type: 'photo', organizationId, uploadedBy, createdAt: at } })
    made.push(m.id)
  }

  beforeAll(async () => {
    await ensureMakeReadyOrg()
    leader = await createUserWithApiKey({ email: `mb-l-${stamp}@cl.test`, name: 'Leader' })
    stranger = await createUserWithApiKey({ email: `mb-s-${stamp}@cl.test`, name: 'Stranger' })
    orgA = (await prisma.organization.create({ data: { name: `Alpha ${stamp}`, ownerId: leader.userId } })).id
    orgB = (await prisma.organization.create({ data: { name: `Beta ${stamp}`, ownerId: stranger.userId } })).id
    const third = await createUserWithApiKey({ email: `mb-t-${stamp}@cl.test`, name: 'Third' })
    orgC = (await prisma.organization.create({ data: { name: `Gamma ${stamp}`, ownerId: third.userId } })).id
    roleId = (await prisma.role.create({ data: { name: `Viewer ${stamp}`, organizationId: orgB } })).id
    await prisma.userRole.create({ data: { userId: leader.userId, roleId, organizationId: orgB } })
    const t = (n: number) => new Date(Date.UTC(2026, 0, 1, 0, 0, n))
    await photo(MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID, `mb-${stamp}-mr`, t(1))
    await photo(orgA, leader.userId, `mb-${stamp}-a`, t(2))
    await photo(orgB, stranger.userId, `mb-${stamp}-b`, t(3))
    await photo(orgC, third.userId, `mb-${stamp}-c`, t(4))
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { id: { in: made } } })
    await prisma.userRole.deleteMany({ where: { roleId } })
    await prisma.role.deleteMany({ where: { id: roleId } })
    await prisma.apiKey.deleteMany({ where: { user: { email: { contains: `-${stamp}@cl.test` } } } })
    await prisma.organization.deleteMany({ where: { id: { in: [orgA, orgB, orgC] } } })
    await prisma.user.deleteMany({ where: { email: { contains: `-${stamp}@cl.test` } } })
  })

  const mine = (body: any) => body.data.filter((m: any) => m.title.startsWith(`mb-${stamp}`)).map((m: any) => m.title)

  it('lists MakeReady first, then the caller orgs by name, with canUpload', async () => {
    const res = await request(app).get('/api/media/sources').set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.data).toEqual([
      { id: MAKEREADY_ORG_ID, name: 'MakeReady', isMakeReady: true, canUpload: false },
      { id: orgA, name: `Alpha ${stamp}`, isMakeReady: false, canUpload: true },
      { id: orgB, name: `Beta ${stamp}`, isMakeReady: false, canUpload: false },
    ])
  })

  it('browses MakeReady + the caller orgs, never another org, newest first, with source fields', async () => {
    const res = await request(app).get('/api/media/browse').set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(mine(res.body)).toEqual([`mb-${stamp}-b`, `mb-${stamp}-a`, `mb-${stamp}-mr`])
    const mr = res.body.data.find((m: any) => m.title === `mb-${stamp}-mr`)
    expect(mr).toMatchObject({ organizationId: MAKEREADY_ORG_ID, isMakeReady: true })
    expect(res.body).toHaveProperty('hasMore')
    expect(res.body).toHaveProperty('nextCursor')
  })

  it('narrows to the given sources and 403s a source that is not the caller', async () => {
    const a = await request(app).get(`/api/media/browse?sources=${orgA}`).set('Authorization', bearer(leader.token))
    expect(mine(a.body)).toEqual([`mb-${stamp}-a`])
    const c = await request(app).get(`/api/media/browse?sources=${orgC}`).set('Authorization', bearer(leader.token))
    expect(c.status).toBe(403)
  })

  it('400s a limit over 200 and pages with the cursor', async () => {
    expect((await request(app).get('/api/media/browse?limit=500').set('Authorization', bearer(leader.token))).status).toBe(400)
    const p1 = await request(app).get(`/api/media/browse?limit=1&sources=${orgA},${orgB}`).set('Authorization', bearer(leader.token))
    expect(p1.body.hasMore).toBe(true)
    const p2 = await request(app).get(`/api/media/browse?limit=1&sources=${orgA},${orgB}&cursor=${encodeURIComponent(p1.body.nextCursor)}`).set('Authorization', bearer(leader.token))
    expect(p2.body.data[0].id).not.toBe(p1.body.data[0].id)
  })
})
