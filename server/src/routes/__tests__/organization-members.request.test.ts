import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

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

function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/organizations', organizationsRoutes)
  return app
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
    const res = await request(appAs('gl')).get(
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
    await request(appAs('owner-1')).get('/api/organizations/org-1/members?groupId=&search=')
    expect(getOrganizationMembers).toHaveBeenCalledWith('org-1', 'owner-1', {
      search: undefined,
      groupId: undefined,
      leaderId: undefined,
      includeInactive: false,
    })
  })

  it('answers an empty result with 200 and count 0', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: true, data: [], viewerScope: { all: false, groupIds: [] } })
    const res = await request(appAs('gl')).get('/api/organizations/org-1/members?groupId=g-foreign')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: [], count: 0, viewerScope: { all: false, groupIds: [] } })
  })

  it('500s when the service fails, 401s without auth', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: false, error: 'Failed to fetch members' })
    expect((await request(appAs('gl')).get('/api/organizations/org-1/members')).status).toBe(500)
    expect((await request(appAs()).get('/api/organizations/org-1/members')).status).toBe(401)
  })
})
