import express from 'express'
import request from 'supertest'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  faqItem: { findMany: vi.fn() },
  user: { findFirst: vi.fn() },
  $transaction: vi.fn(),
  $queryRaw: vi.fn(),
  $connect: vi.fn(),
}))
const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))
vi.mock('pg', () => ({
  default: { Pool: vi.fn().mockImplementation(() => ({ connect: vi.fn().mockResolvedValue(pgMock) })) },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/analytics-scope.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/analytics-scope.js')>()),
  deriveAnalyticsScope: vi.fn(),
}))
vi.mock('../../services/home-dashboard.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-dashboard.js')>()),
  getHomeSessions: vi.fn(),
  getHomeDays: vi.fn(),
  getHomeEngagement: vi.fn(),
}))
vi.mock('../../services/home-following.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-following.js')>()),
  getHomeFollowing: vi.fn(),
}))

import { deriveAnalyticsScope } from '../../services/analytics-scope.js'
import { getHomeDays, getHomeEngagement, getHomeSessions } from '../../services/home-dashboard.js'
import { getHomeFollowing } from '../../services/home-following.js'
import homeRoutes from '../home.js'

const SCOPE = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
const SESSIONS = { averageSeconds: 840, sessionCount: 12, hourly: Array(24).fill(0), bins: Array(88).fill(0), ticks: [0, 15, 30, 45], axisMinutes: 45 }
const ENGAGEMENT = { currentCount: 10, enrolledCount: 24, groupCount: 3, percent: 42, activeCount: 18 }

/** requireAuth passes when req.user and req.apiKeyId are set (middleware/auth.ts:27). */
function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/home', homeRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(deriveAnalyticsScope).mockResolvedValue(SCOPE)
  vi.mocked(getHomeSessions).mockResolvedValue(SESSIONS)
  vi.mocked(getHomeDays).mockResolvedValue({ days: [{ day: '2026-10-25', sessionSeconds: 60, blocks: [60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] }] })
  vi.mocked(getHomeEngagement).mockResolvedValue(ENGAGEMENT)
  vi.mocked(getHomeFollowing).mockResolvedValue({ programs: [] })
})

describe('GET /api/home/sessions', () => {
  it('returns the contract body for a valid range, scoped by organizationId', async () => {
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&tz=America%2FChicago&organizationId=org-1')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(SESSIONS)
    expect(deriveAnalyticsScope).toHaveBeenCalledWith({ userId: 'u1', apiKeyId: 'test-key' }, { organizationId: 'org-1' })
    expect(getHomeSessions).toHaveBeenCalledWith(SCOPE, 'week', 'America/Chicago', expect.any(Date))
  })

  it('accepts Etc/GMT+5 (percent-encoded +) and defaults tz to UTC', async () => {
    expect((await request(appAs('u1')).get('/api/home/sessions?range=all&tz=Etc%2FGMT%2B5')).status).toBe(200)
    await request(appAs('u1')).get('/api/home/sessions?range=year')
    expect(getHomeSessions).toHaveBeenLastCalledWith(SCOPE, 'year', 'UTC', expect.any(Date))
  })

  it('400s a bad or missing range', async () => {
    expect((await request(appAs('u1')).get('/api/home/sessions?range=decade')).status).toBe(400)
    expect((await request(appAs('u1')).get('/api/home/sessions')).status).toBe(400)
    expect(getHomeSessions).not.toHaveBeenCalled()
  })

  it('400s a bad timezone', async () => {
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&tz=Mars%2FBase')
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Invalid timezone: Mars/Base' })
  })

  it('401s without auth', async () => {
    expect((await request(appAs()).get('/api/home/sessions?range=week')).status).toBe(401)
  })

  it('404s an empty scope', async () => {
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    const res = await request(appAs('u1')).get('/api/home/sessions?range=week&organizationId=foreign')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
  })
})

describe('GET /api/home/days', () => {
  it('returns every day for a valid range', async () => {
    const res = await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-31')
    expect(res.status).toBe(200)
    expect(res.body.days).toHaveLength(1)
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-10-01', '2026-10-31', 'UTC')
  })

  it.each([
    ['more than 62 days', 'from=2026-10-01&to=2026-12-15'],
    ['to before from', 'from=2026-10-10&to=2026-10-01'],
    ['a malformed date', 'from=2026-10-1&to=2026-10-02'],
    ['a missing bound', 'from=2026-10-01'],
  ])('400s %s', async (_label, qs) => {
    expect((await request(appAs('u1')).get(`/api/home/days?${qs}`)).status).toBe(400)
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s a bad tz and 401s without auth', async () => {
    expect((await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-02&tz=Nope')).status).toBe(400)
    expect((await request(appAs()).get('/api/home/days?from=2026-10-01&to=2026-10-02')).status).toBe(401)
  })
})

describe('GET /api/home/engagement', () => {
  it('returns the contract body', async () => {
    const res = await request(appAs('u1')).get('/api/home/engagement?tz=America%2FChicago')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(ENGAGEMENT)
    expect(getHomeEngagement).toHaveBeenCalledWith(SCOPE, 'America/Chicago', expect.any(Date))
  })

  it('400s a bad tz, 401s without auth, 404s an empty scope', async () => {
    expect((await request(appAs('u1')).get('/api/home/engagement?tz=Nope')).status).toBe(400)
    expect((await request(appAs()).get('/api/home/engagement')).status).toBe(401)
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    expect((await request(appAs('u1')).get('/api/home/engagement')).status).toBe(404)
  })
})

describe('GET /api/home/following', () => {
  it('reads the caller’s follows within scope', async () => {
    const res = await request(appAs('u1')).get('/api/home/following?organizationId=org-1')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ programs: [] })
    expect(getHomeFollowing).toHaveBeenCalledWith(SCOPE, 'u1', expect.any(Date))
  })

  it('401s without auth and 404s an empty scope', async () => {
    expect((await request(appAs()).get('/api/home/following')).status).toBe(401)
    vi.mocked(deriveAnalyticsScope).mockResolvedValue({ all: false, orgIds: [], groupIds: [] })
    expect((await request(appAs('u1')).get('/api/home/following')).status).toBe(404)
  })
})

describe('mounting', () => {
  let app: Awaited<typeof import('../../index.js')>['app']
  beforeAll(async () => {
    process.env.MICROSOFT_CLIENT_ID = 'test-microsoft-client-id'
    process.env.MICROSOFT_TENANT_ID = 'test-tenant-id'
    ;({ app } = await import('../../index.js'))
  })

  it('serves /api/home behind requireAuth', async () => {
    const res = await request(app).get('/api/home/engagement').set('User-Agent', 'Mozilla/5.0 MakeReadyTest')
    expect(res.status).toBe(401)
  })
})
