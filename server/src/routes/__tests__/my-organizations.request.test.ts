import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  getUserOrganizations: vi.fn(),
}))

import { getUserOrganizations } from '../../services/organization.js'
import organizationsRoutes from '../organizations.js'

/** requireAuth passes when req.user and req.apiKeyId are set (middleware/auth.ts:27). */
function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/organizations', organizationsRoutes)
  return app
}

const ORG = {
  id: 'o-a',
  name: 'Alpha',
  ownerId: 'x',
  isActive: true,
  twilioVerifyServiceSid: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getUserOrganizations).mockResolvedValue({ success: true, data: [ORG] })
})

describe('GET /api/organizations/my/organizations (D18, SC10)', () => {
  it('returns the caller’s orgs with the /my/organization fields', async () => {
    const res = await request(appAs('gl')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      data: [{ ...ORG, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-02T00:00:00.000Z' }],
    })
    expect(getUserOrganizations).toHaveBeenCalledWith('gl')
  })

  it('answers an empty list with 200, never 404', async () => {
    vi.mocked(getUserOrganizations).mockResolvedValue({ success: true, data: [] })
    const res = await request(appAs('nobody')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: [] })
  })

  it('401s without auth', async () => {
    const res = await request(appAs()).get('/api/organizations/my/organizations')
    expect(res.status).toBe(401)
    expect(getUserOrganizations).not.toHaveBeenCalled()
  })

  it('500s when the service fails', async () => {
    vi.mocked(getUserOrganizations).mockResolvedValue({ success: false, error: 'Failed to fetch organizations' })
    const res = await request(appAs('gl')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(500)
    expect(res.body).toEqual({ success: false, error: 'Internal server error' })
  })
})
