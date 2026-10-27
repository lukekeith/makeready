/**
 * /api/home/days?groupId (ui2-groups-browse D14): the group must pass groupManageFilter for the
 * caller; sessions narrow to its members. Scope, the dashboard service and the gate are stubbed.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))
vi.mock('pg', () => ({
  default: { Pool: vi.fn().mockImplementation(() => ({ connect: vi.fn().mockResolvedValue(pgMock) })) },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))
vi.mock('../../services/analytics-scope.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/analytics-scope.js')>()),
  deriveAnalyticsScope: vi.fn(),
}))
vi.mock('../../services/home-dashboard.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-dashboard.js')>()),
  getHomeDays: vi.fn(),
}))
vi.mock('../../services/member-access.js', () => ({ canViewMember: vi.fn(), visibleMemberOrgIds: vi.fn() }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))

import { deriveAnalyticsScope } from '../../services/analytics-scope.js'
import { getHomeDays } from '../../services/home-dashboard.js'
import { findManageableGroup } from '../../services/permission.js'
import homeRoutes from '../home.js'

const SCOPE = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
const DAYS = { days: [{ day: '2026-10-27', sessionSeconds: 600, blocks: Array(12).fill(0), lastActivityAt: null }] }

/** requireAuth passes when req.user and req.apiKeyId are set; `user` without an id = an API-key caller. */
function appAs(user: { id?: string; isActive: boolean }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { user, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/home', homeRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(deriveAnalyticsScope).mockResolvedValue(SCOPE)
  vi.mocked(getHomeDays).mockResolvedValue(DAYS as never)
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org-1' })
})

describe('GET /api/home/days?groupId (D14)', () => {
  it('reads the group’s days when the caller manages it', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get(
      '/api/home/days?from=2026-09-28&to=2026-10-27&tz=America%2FChicago&groupId=g1'
    )
    expect(res.status).toBe(200)
    expect(res.body).toEqual(DAYS)
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-09-28', '2026-10-27', 'America/Chicago', { groupId: 'g1' })
  })

  it('404s a group outside the caller’s manage scope, before reading sessions', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=g-other')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('404s a caller with no user id (API-key caller), as the memberId path', async () => {
    const res = await request(appAs({ isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=g1')
    expect(res.status).toBe(404)
    expect(findManageableGroup).not.toHaveBeenCalled()
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s memberId together with groupId', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get(
      '/api/home/days?from=2026-10-01&to=2026-10-02&memberId=m1&groupId=g1'
    )
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'memberId and groupId cannot be combined' })
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s an empty groupId (it is declared, never stripped)', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=')
    expect(res.status).toBe(400)
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('keeps Home’s call exactly as it was without groupId', async () => {
    await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-31&organizationId=org-1')
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-10-01', '2026-10-31', 'UTC')
    expect(vi.mocked(getHomeDays).mock.calls[0]).toHaveLength(4)
    expect(findManageableGroup).not.toHaveBeenCalled()
  })
})
