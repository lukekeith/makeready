import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-engagement.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-engagement.js')>()),
  getMemberEngagement: vi.fn(),
}))

import { getMemberEngagement } from '../../services/member-engagement.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const BODY = {
  programs: [
    { enrollmentId: 'e1', programId: 'p1', title: 'Walking Through John', coverImageUrl: null, completedCount: 30, totalCount: 30, hours: 9, percent: 100 },
  ],
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getMemberEngagement).mockResolvedValue(BODY)
})

describe('GET /api/members/:memberId/engagement (SC5)', () => {
  it('returns the D11 body for a scoped user, tz passed through', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement?tz=America%2FChicago')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(BODY)
    expect(getMemberEngagement).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' }, 'America/Chicago', expect.any(Date))
  })

  it('defaults tz to UTC and reads a member session’s own engagement unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1/engagement')
    expect(getMemberEngagement).toHaveBeenCalledWith('m1', { kind: 'self' }, 'UTC', expect.any(Date))
  })

  it('400s a bad timezone before reading anything', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement?tz=Mars%2FBase')
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Invalid timezone: Mars/Base' })
    expect(getMemberEngagement).not.toHaveBeenCalled()
  })

  it('404s a member outside the caller’s scope', async () => {
    vi.mocked(getMemberEngagement).mockResolvedValue(null)
    const res = await request(appAs({ userId: 'gl2' })).get('/api/members/m1/engagement')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
  })

  it('403s a caller that is neither the member nor a user, 500s a failure', async () => {
    expect((await request(appAs({ memberId: 'm-other' })).get('/api/members/m1/engagement')).status).toBe(403)
    vi.mocked(getMemberEngagement).mockRejectedValue(new Error('db down'))
    expect((await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement')).status).toBe(500)
  })
})
