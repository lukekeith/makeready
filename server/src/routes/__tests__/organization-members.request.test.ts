import { createServer, type Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // member.read itself is exercised by the existing permission tests; here it always passes.
  requirePermission: () => (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  getOrganizationMembers: vi.fn(),
}))

import { getOrganizationMembers } from '../../services/organization.js'
import organizationsRoutes from '../organizations.js'

// Each app listens on 127.0.0.1 itself. Handed a bare app, supertest calls listen(0) — the
// wildcard address — then dials 127.0.0.1:<port>; on macOS another process (a parallel suite in
// another worktree) can bind that exact 127.0.0.1:<port> and its server answers instead (seen as
// a 401 or a service that was never called). A server already bound to 127.0.0.1 can't be shadowed.
const servers: Server[] = []
afterEach(async () => {
  await Promise.all(servers.splice(0).map((s) => new Promise((done) => s.close(done))))
})

async function appAs(userId?: string): Promise<Server> {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/organizations', organizationsRoutes)
  const server = createServer(app)
  servers.push(server)
  await new Promise<void>((listening) => server.listen(0, '127.0.0.1', listening))
  return server
}

const ITEM = {
  id: 'm2',
  firstName: 'Ruth',
  lastName: 'Sullivan',
  profilePicture: null,
  googlePicture: null,
  joinedAt: new Date('2026-10-25T15:00:00.000Z'),
  groupCount: 2,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getOrganizationMembers).mockResolvedValue({
    success: true,
    data: [ITEM],
    viewerScope: { all: false, groupIds: ['g-led'] },
  })
})

describe('GET /api/organizations/:organizationId/members (SC4, SC9)', () => {
  it('passes the caller and every filter to the service and returns the contract body', async () => {
    const res = await request(await appAs('gl')).get(
      '/api/organizations/org-1/members?search=ru%20su&groupId=g-led&leaderId=gl&includeInactive=true'
    )
    expect(res.status).toBe(200)
    expect(getOrganizationMembers).toHaveBeenCalledWith('org-1', 'gl', {
      search: 'ru su',
      groupId: 'g-led',
      leaderId: 'gl',
      includeInactive: true,
    })
    expect(res.body).toEqual({
      success: true,
      data: [{ ...ITEM, joinedAt: '2026-10-25T15:00:00.000Z' }],
      count: 1,
      viewerScope: { all: false, groupIds: ['g-led'] },
    })
  })

  it('treats absent or empty filters as absent', async () => {
    const res = await request(await appAs('owner-1')).get('/api/organizations/org-1/members?groupId=&search=')
    expect(res.status).toBe(200)
    expect(getOrganizationMembers).toHaveBeenCalledWith('org-1', 'owner-1', {
      search: undefined,
      groupId: undefined,
      leaderId: undefined,
      includeInactive: false,
    })
  })

  it('answers an empty result with 200 and count 0', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: true, data: [], viewerScope: { all: false, groupIds: [] } })
    const res = await request(await appAs('gl')).get('/api/organizations/org-1/members?groupId=g-foreign')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: [], count: 0, viewerScope: { all: false, groupIds: [] } })
  })

  it('500s when the service fails, 401s without auth', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: false, error: 'Failed to fetch members' })
    expect((await request(await appAs('gl')).get('/api/organizations/org-1/members')).status).toBe(500)
    expect((await request(await appAs()).get('/api/organizations/org-1/members')).status).toBe(401)
  })
})

const G1 = '11111111-1111-4111-8111-111111111111'
const G2 = '22222222-2222-4222-8222-222222222222'
const U1 = '33333333-3333-4333-8333-333333333333'

describe('GET /api/organizations/:organizationId/members — lists (filter-multiselect D6, D11)', () => {
  const lastQuery = () => vi.mocked(getOrganizationMembers).mock.calls[0][2]

  it('splits comma lists into the service arrays', async () => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupIds=${G1},${G2}&leaderIds=${U1}`)
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupIds: [G1, G2], leaderIds: [U1] })
  })

  it('accepts the repeated form, trims, and drops duplicates', async () => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupIds=${G1}&groupIds=%20${G2}&groupIds=${G1}`)
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupIds: [G1, G2] })
  })

  it('treats a list with no ids left as absent (F7)', async () => {
    const res = await request(await appAs('owner-1')).get('/api/organizations/org-1/members?groupIds=,&leaderIds=')
    expect(res.status).toBe(200)
    expect(lastQuery()?.groupIds).toBeUndefined()
    expect(lastQuery()?.leaderIds).toBeUndefined()
  })

  it('unions a uuid single param into its list', async () => {
    await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupId=${G1}&groupIds=${G2}`)
    expect(lastQuery()).toMatchObject({ groupId: undefined, groupIds: [G1, G2] })
  })

  it('keeps a single groupId alone exactly as before, uuid or not', async () => {
    const res = await request(await appAs('gl')).get('/api/organizations/org-1/members?groupId=g-foreign')
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupId: 'g-foreign', groupIds: undefined })
  })

  it.each([
    ['a non-uuid in groupIds', `groupIds=${G1},not-a-uuid`],
    ['a non-uuid in leaderIds', 'leaderIds=nope'],
    ['an object shape', `groupIds[a]=${G1}`],
  ])('400s on %s', async (_label, qs) => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?${qs}`)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(getOrganizationMembers).not.toHaveBeenCalled()
  })
})
